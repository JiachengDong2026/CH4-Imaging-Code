#pragma once

#include "model/fused_point.h"
#include "model/angle_sample.h"
#include "model/harmonic_curve.h"
#include "protocol/frame_codec.h"

#include <QObject>
#include <QQueue>
#include <QTimer>

namespace ch4::device {
class NativeSerial;
class NativeUsbStream;

class DeviceSession final : public QObject {
    Q_OBJECT
public:
    enum class Mode { Mock, Serial, Usb };
    explicit DeviceSession(QObject* parent = nullptr);
    ~DeviceSession() override;
    static QStringList serialPorts();
    bool connectDevice(Mode mode, const QString& portName = {}, int baudRate = 921600);
    bool connectSerial(const QString& portName, int baudRate = 921600);
    bool connectUsb();
    void disconnectSerial();
    void disconnectUsb();
    void disconnectDevice();
    void start();
    void stop();
    void setStreamSelection(bool angles, bool harmonics);
    void writeRegister(quint32 address, quint32 value);
    void validateAndCommit();
    void staticPoint(qint16 xQ13, qint16 yQ13);
    void returnZero();
    void returnScanStart();
    void queryStatus();
    [[nodiscard]] bool connected() const { return connected_; }
    [[nodiscard]] bool running() const { return running_; }

signals:
    void connectionChanged(bool connected, const QString& description);
    void serialConnectionChanged(bool connected, const QString& description);
    void usbConnectionChanged(bool connected, const QString& description);
    void runningChanged(bool running);
    void pointReceived(const ch4::model::FusedPoint& point);
    void angleSampleReceived(const ch4::model::AngleSample& sample);
    void harmonicCurveReceived(const ch4::model::HarmonicCurve& curve);
    void mirrorConnectionChanged(bool connected);
    void logMessage(const QString& message);
    void protocolStatsChanged(quint64 frames, quint64 crcErrors, quint64 discardedBytes);

private slots:
    void generateMockBatch();
    void readSerial();
    void sendNextCommand();

private:
    void sendCommand(protocol::MessageType type, const QByteArray& payload = {});
    void handleFrame(const protocol::Frame& frame);
    model::FusedPoint makeMockPoint();
    NativeSerial* serial_ = nullptr;
    NativeUsbStream* usb_ = nullptr;
    QTimer mockTimer_;
    QTimer commandTimer_;
    QTimer dataStartTimer_;
    QTimer dataIdleTimer_;
    QQueue<QPair<protocol::MessageType, QByteArray>> commandQueue_;
    protocol::FrameParser serialParser_;
    protocol::FrameParser usbParser_;
    Mode mode_ = Mode::Mock;
    bool connected_ = false;
    bool serialConnected_ = false;
    bool usbConnected_ = false;
    bool running_ = false;
    bool dataFlowSeen_ = false;
    quint16 sequence_ = 1;
    quint64 mockTicks_ = 0;
    quint32 mockImage_ = 0;
    quint32 mockHarmonicSample_ = 0;
    int mockLine_ = 0;
    int mockColumn_ = 0;
    bool streamAngles_ = true;
    bool streamHarmonics_ = true;
};

}  // namespace ch4::device
