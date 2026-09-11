#pragma once

#include <QByteArray>
#include <QByteArrayView>
#include <QThread>

#include <optional>

class QMutex;
class QWaitCondition;

namespace ch4::device {

class NativeUsbStream final : public QThread {
    Q_OBJECT
public:
    static constexpr qsizetype kBlockSize = 4096;
    static constexpr qsizetype kPayloadSize = 4087;
    static constexpr qsizetype kPaddingSize = kBlockSize - kPayloadSize;
    static constexpr qsizetype kHarmonicPayloadSize = 99 * 41;
    static constexpr qsizetype kHarmonicPaddingSize = kBlockSize - kHarmonicPayloadSize;

    explicit NativeUsbStream(QObject* parent = nullptr);
    ~NativeUsbStream() override;

    bool startStream(QString* error = nullptr);
    void stopStream();

    static std::optional<QByteArray> extractPayload(QByteArrayView block,
                                                    QString* error = nullptr);

signals:
    void payloadReceived(const QByteArray& payload);
    void errorOccurred(const QString& error);
    void blockReceived(quint64 blocks, quint64 bytes);

protected:
    void run() override;

private:
    void reportInitialization(bool success, const QString& error = {});

    QMutex* initMutex_ = nullptr;
    QWaitCondition* initCondition_ = nullptr;
    bool initializationFinished_ = false;
    bool initializationSucceeded_ = false;
    QString initializationError_;
};

}  // namespace ch4::device
