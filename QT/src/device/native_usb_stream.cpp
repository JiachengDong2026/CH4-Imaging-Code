#include "device/native_usb_stream.h"

#include <QLibrary>
#include <QMutex>
#include <QMutexLocker>
#include <QWaitCondition>

#include <limits>

namespace ch4::device {
namespace {
constexpr quint32 kDeviceIndex = 0;
constexpr quint32 kInPipe = 1;  // CH375 pipe 1 maps to USB endpoint 0x81 IN.
constexpr quint32 kReadTimeoutMs = 250;

using OpenDeviceFn = void* (*)(quint32 index);
using CloseDeviceFn = void (*)(quint32 index);
using ReadEndPointFn = int (*)(quint32 index, quint32 pipe, void* buffer, quint32* length);
using SetTimeoutFn = int (*)(quint32 index, quint32 writeTimeoutMs, quint32 readTimeoutMs);

template <typename Function>
Function resolve(QLibrary& library, const char* name) {
    return reinterpret_cast<Function>(library.resolve(name));
}
}

NativeUsbStream::NativeUsbStream(QObject* parent)
    : QThread(parent), initMutex_(new QMutex), initCondition_(new QWaitCondition) {}

NativeUsbStream::~NativeUsbStream() {
    stopStream();
    delete initCondition_;
    delete initMutex_;
}

bool NativeUsbStream::startStream(QString* error) {
    if (isRunning())
        return true;

    {
        QMutexLocker lock(initMutex_);
        initializationFinished_ = false;
        initializationSucceeded_ = false;
        initializationError_.clear();
    }

    start();
    QMutexLocker lock(initMutex_);
    while (!initializationFinished_)
        initCondition_->wait(initMutex_);
    if (error)
        *error = initializationError_;
    if (!initializationSucceeded_) {
        lock.unlock();
        wait();
    }
    return initializationSucceeded_;
}

void NativeUsbStream::stopStream() {
    if (!isRunning())
        return;
    requestInterruption();
    wait(kReadTimeoutMs + 1000);
}

std::optional<QByteArray> NativeUsbStream::extractPayload(QByteArrayView block, QString* error) {
    const auto fail = [error](const QString& message) -> std::optional<QByteArray> {
        if (error)
            *error = message;
        return {};
    };
    if (block.size() != kBlockSize)
        return fail(QStringLiteral("USB 数据块长度为 %1，期望 %2 字节。")
                        .arg(block.size()).arg(kBlockSize));
    if (quint8(block[0]) != 0xA5 || quint8(block[1]) != 0x5A)
        return fail(QStringLiteral("USB 数据块没有有效的应用帧头。"));
    const qsizetype payloadSize = quint8(block[5]) == 0x71
        ? kHarmonicPayloadSize : kPayloadSize;
    for (qsizetype index = payloadSize; index < kBlockSize; ++index) {
        if (block[index] != 0)
            return fail(QStringLiteral("USB 数据块补零区偏移 0x%1 非零。")
                            .arg(index, 4, 16, QLatin1Char('0')));
    }
    return QByteArray(block.first(payloadSize));
}

void NativeUsbStream::reportInitialization(bool success, const QString& error) {
    QMutexLocker lock(initMutex_);
    initializationSucceeded_ = success;
    initializationError_ = error;
    initializationFinished_ = true;
    initCondition_->wakeAll();
}

void NativeUsbStream::run() {
    QLibrary library(QStringLiteral("C:/Windows/System32/CH375DLL64.DLL"));
    if (!library.load()) {
        reportInitialization(false, QStringLiteral("无法加载 CH375DLL64.DLL：%1").arg(library.errorString()));
        return;
    }

    const auto openDevice = resolve<OpenDeviceFn>(library, "CH375OpenDevice");
    const auto closeDevice = resolve<CloseDeviceFn>(library, "CH375CloseDevice");
    const auto readEndPoint = resolve<ReadEndPointFn>(library, "CH375ReadEndP");
    const auto setTimeout = resolve<SetTimeoutFn>(library, "CH375SetTimeout");
    if (!openDevice || !closeDevice || !readEndPoint || !setTimeout) {
        reportInitialization(false, QStringLiteral("CH375DLL64.DLL 缺少 USB 读取入口点。"));
        return;
    }

    void* handle = openDevice(kDeviceIndex);
    if (!handle || handle == reinterpret_cast<void*>(std::numeric_limits<quintptr>::max())) {
        reportInitialization(false,
                             QStringLiteral("无法打开 CH569 设备 0；请关闭其他 USB 测试程序并检查驱动。"));
        return;
    }

    if (!setTimeout(kDeviceIndex, kReadTimeoutMs, kReadTimeoutMs)) {
        closeDevice(kDeviceIndex);
        reportInitialization(false, QStringLiteral("CH375SetTimeout 设置读取超时失败。"));
        return;
    }
    reportInitialization(true);

    quint64 blockCount = 0;
    bool readFailed = false;
    while (!isInterruptionRequested()) {
        QByteArray block(kBlockSize, Qt::Uninitialized);
        qsizetype received = 0;
        while (received < kBlockSize && !isInterruptionRequested()) {
            quint32 length = quint32(kBlockSize - received);
            const int ok = readEndPoint(kDeviceIndex, kInPipe, block.data() + received, &length);
            if (!ok) {
                if (!isInterruptionRequested()) {
                    emit errorOccurred(QStringLiteral("CH375ReadEndP(pipe 1) 读取失败；请短按 USB_RST 后重连。"));
                    readFailed = true;
                }
                break;
            }
            if (length > quint32(kBlockSize - received)) {
                emit errorOccurred(QStringLiteral("USB 驱动返回了超出缓冲区的长度。"));
                readFailed = true;
                break;
            }
            received += qsizetype(length);
            if (length == 0)
                QThread::msleep(1);
        }
        if (readFailed || isInterruptionRequested())
            break;

        QString error;
        const auto payload = extractPayload(block, &error);
        if (!payload) {
            emit errorOccurred(error);
            continue;
        }
        ++blockCount;
        emit payloadReceived(*payload);
        emit blockReceived(blockCount, blockCount * quint64(kBlockSize));
    }

    closeDevice(kDeviceIndex);
}

}  // namespace ch4::device
