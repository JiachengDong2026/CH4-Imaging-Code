#include "device/device_session.h"
#include "device/native_serial.h"
#include "device/native_usb_stream.h"
#include "model/harmonic_curve.h"

#include <QDateTime>
#include <QtMath>

namespace ch4::device {

DeviceSession::DeviceSession(QObject* parent):QObject(parent),serial_(new NativeSerial(this)),usb_(new NativeUsbStream(this)){
    qRegisterMetaType<model::FusedPoint>();
    qRegisterMetaType<model::AngleSample>();
    qRegisterMetaType<model::HarmonicCurve>();
    mockTimer_.setInterval(10);
    mockTimer_.setTimerType(Qt::PreciseTimer);
    commandTimer_.setSingleShot(true);
    commandTimer_.setInterval(10);
    dataStartTimer_.setSingleShot(true);
    dataStartTimer_.setInterval(1500);
    dataIdleTimer_.setSingleShot(true);
    dataIdleTimer_.setInterval(600);
    connect(&mockTimer_,&QTimer::timeout,this,&DeviceSession::generateMockBatch);
    connect(&commandTimer_,&QTimer::timeout,this,&DeviceSession::sendNextCommand);
    connect(&dataStartTimer_,&QTimer::timeout,this,[this]{
        if(mode_!=Mode::Mock&&running_&&!dataFlowSeen_)
            emit logMessage(QStringLiteral("WARNING  Start command sent, but no selected data stream arrived within 1.5 s. Check STREAM_CONFIG and STREAM_START responses."));
    });
    connect(&dataIdleTimer_, &QTimer::timeout, this, [this] {
        if (mode_ == Mode::Serial && running_ && dataFlowSeen_) {
            // The FPGA gates output once its one-shot raster is complete.
            // Do not send STOP_SCAN here: it would move the mirror away from
            // the final endpoint that it is intentionally holding.
            running_ = false;
            emit runningChanged(false);
            emit logMessage(QStringLiteral("INFO  One scan frame completed; acquisition stopped automatically."));
        }
    });
    connect(serial_,&NativeSerial::bytesReceived,this,[this](const QByteArray& bytes){const auto frames=serialParser_.push(bytes);for(const auto& frame:frames)handleFrame(frame);if(mode_==Mode::Serial){const auto&s=serialParser_.stats();emit protocolStatsChanged(s.frames,s.crcErrors,s.discardedBytes);}});
    connect(serial_,&NativeSerial::errorOccurred,this,[this](const QString& error){emit logMessage(QStringLiteral("ERROR  Serial: %1").arg(error));});
    connect(usb_,&NativeUsbStream::payloadReceived,this,[this](const QByteArray& bytes){if(mode_!=Mode::Usb||!running_)return;const auto frames=usbParser_.push(bytes);for(const auto& frame:frames)handleFrame(frame);const auto&s=usbParser_.stats();emit protocolStatsChanged(s.frames,s.crcErrors,s.discardedBytes);});
    connect(usb_,&NativeUsbStream::errorOccurred,this,[this](const QString& error){emit logMessage(QStringLiteral("ERROR  USB3: %1").arg(error));});
    connect(usb_,&NativeUsbStream::blockReceived,this,[this](quint64 blocks,quint64 bytes){if(blocks==1||blocks%100==0)emit logMessage(QStringLiteral("INFO  USB3 received %1 blocks (%2 bytes).").arg(blocks).arg(bytes));});
}

DeviceSession::~DeviceSession(){disconnectDevice();}

bool DeviceSession::connectSerial(const QString& portName, int baudRate){
    mode_=Mode::Serial;
    disconnectSerial();
    if(!serial_->open(portName,baudRate)){emit serialConnectionChanged(false,QStringLiteral("串口连接失败"));return false;}
    serialConnected_=true; emit serialConnectionChanged(true,QStringLiteral("UART %1 · %2").arg(portName).arg(baudRate));
    if(!connected_){connected_=true;emit connectionChanged(true,QStringLiteral("UART %1").arg(portName));}
    sendCommand(protocol::MessageType::Hello); return true;
}
bool DeviceSession::connectUsb(){
    mode_=Mode::Usb;
    disconnectUsb(); QString error;
    if(!usb_->startStream(&error)){emit usbConnectionChanged(false,error);return false;}
    usbConnected_=true; emit usbConnectionChanged(true,QStringLiteral("USB3 EP 0x81"));
    if(!connected_){connected_=true;emit connectionChanged(true,QStringLiteral("USB3 EP 0x81"));} return true;
}
void DeviceSession::disconnectSerial(){if(serial_->isOpen())serial_->close();if(serialConnected_){serialConnected_=false;emit serialConnectionChanged(false,QStringLiteral("串口未连接"));}if(!usbConnected_&&connected_){connected_=false;emit connectionChanged(false,QStringLiteral("未连接"));}}
void DeviceSession::disconnectUsb(){usb_->stopStream();if(usbConnected_){usbConnected_=false;emit usbConnectionChanged(false,QStringLiteral("USB3未连接"));}if(!serialConnected_&&connected_){connected_=false;emit connectionChanged(false,QStringLiteral("未连接"));}}

QStringList DeviceSession::serialPorts(){return NativeSerial::availablePorts();}

bool DeviceSession::connectDevice(Mode mode,const QString& portName,int baudRate){disconnectDevice();serialParser_.reset();usbParser_.reset();mode_=mode;
    if(mode==Mode::Mock){connected_=true;emit connectionChanged(true,QStringLiteral("Mock mode"));emit logMessage(QStringLiteral("INFO  Mock mode connected; no FPGA is required."));return true;}
    if(mode==Mode::Usb){QString error;if(!usb_->startStream(&error)){emit logMessage(QStringLiteral("ERROR  USB3: %1").arg(error));return false;}connected_=true;emit connectionChanged(true,QStringLiteral("USB3 EP 0x81 (独立诊断)"));emit logMessage(QStringLiteral("INFO  USB3 data channel opened independently; UART is not required in this mode."));return true;}
    if(!serial_->open(portName,baudRate))return false;
    connected_=true;emit connectionChanged(true,QStringLiteral("UART %1 · %2").arg(portName).arg(baudRate));emit logMessage(QStringLiteral("INFO  Serial port opened; sending HELLO."));sendCommand(protocol::MessageType::Hello);return true;}

void DeviceSession::disconnectDevice(){stop();mockTimer_.stop();commandTimer_.stop();dataStartTimer_.stop();dataIdleTimer_.stop();commandQueue_.clear();disconnectSerial();disconnectUsb();if(connected_){connected_=false;emit connectionChanged(false,QStringLiteral("未连接"));}}

void DeviceSession::start(){
    if(!connected_||running_)return;
    serialParser_.reset(); usbParser_.reset(); running_=true; dataFlowSeen_=false; dataIdleTimer_.stop();
    if(mode_==Mode::Mock) mockTimer_.start();
    else {
        // UART is the control/configuration link for both acquisition sources;
        // USB3 carries only the high-rate data stream when selected.
        QByteArray mask; mask.append(char((streamAngles_?0x01:0x00)|(streamHarmonics_?0x02:0x00)));
        sendCommand(protocol::MessageType::StreamConfig,mask);
        sendCommand(protocol::MessageType::StartScan);
        sendCommand(protocol::MessageType::StartAcquisition);
        sendCommand(protocol::MessageType::StreamStart);
        dataStartTimer_.start();
        if(mode_==Mode::Usb) emit logMessage(QStringLiteral("INFO  USB3 data monitor started; UART control commands sent."));
    }
    emit runningChanged(true);
    emit logMessage(QStringLiteral("INFO  Acquisition started: trajectory %1, harmonic I/Q %2.").arg(streamAngles_?QStringLiteral("ON"):QStringLiteral("OFF")).arg(streamHarmonics_?QStringLiteral("ON"):QStringLiteral("OFF")));
}

void DeviceSession::stop(){if(!running_)return;dataStartTimer_.stop();dataIdleTimer_.stop();if(mode_==Mode::Mock)mockTimer_.stop();else{sendCommand(protocol::MessageType::StreamStop);sendCommand(protocol::MessageType::StopAcquisition);sendCommand(protocol::MessageType::StopScan);}running_=false;emit runningChanged(false);emit logMessage(QStringLiteral("INFO  Acquisition stopped."));}

void DeviceSession::setStreamSelection(bool angles, bool harmonics){streamAngles_=angles;streamHarmonics_=harmonics;if(mode_!=Mode::Mock&&connected_&&running_){QByteArray mask;mask.append(char((angles?0x01:0x00)|(harmonics?0x02:0x00)));sendCommand(protocol::MessageType::StreamConfig,mask);}emit logMessage(QStringLiteral("INFO  Data streams: trajectory %1, harmonic I/Q %2.").arg(angles?QStringLiteral("ON"):QStringLiteral("OFF")).arg(harmonics?QStringLiteral("ON"):QStringLiteral("OFF")));}

void DeviceSession::writeRegister(quint32 address,quint32 value){QByteArray payload;protocol::appendU32(payload,address);protocol::appendU32(payload,value);if(mode_==Mode::Mock)emit logMessage(QStringLiteral("INFO  Mock register write: 0x%1 = %2").arg(address,4,16,QChar('0')).arg(value));else sendCommand(protocol::MessageType::WriteReg,payload);}

void DeviceSession::validateAndCommit(){if(mode_==Mode::Mock){emit logMessage(QStringLiteral("INFO  Mock configuration validated and committed."));return;}sendCommand(protocol::MessageType::ValidateConfig);sendCommand(protocol::MessageType::CommitConfig);}

void DeviceSession::staticPoint(qint16 xQ13, qint16 yQ13){QByteArray payload;protocol::appendU16(payload,quint16(xQ13));protocol::appendU16(payload,quint16(yQ13));if(mode_==Mode::Mock){emit logMessage(QStringLiteral("INFO  Mock static offset: X %1° · Y %2°").arg(double(xQ13)/8192.0,0,'f',4).arg(double(yQ13)/8192.0,0,'f',4));}else sendCommand(protocol::MessageType::StaticPoint,payload);}
void DeviceSession::returnZero(){if(mode_==Mode::Mock){emit logMessage(QStringLiteral("INFO  Mock return-zero command executed."));}else sendCommand(protocol::MessageType::ReturnZero);}
void DeviceSession::returnScanStart(){if(mode_==Mode::Mock){emit logMessage(QStringLiteral("INFO  Mock return-to-origin command executed."));}else sendCommand(protocol::MessageType::ReturnScanStart);}
void DeviceSession::queryStatus(){if(mode_==Mode::Mock){emit logMessage(QStringLiteral("INFO  Mock status query: device ready."));}else sendCommand(protocol::MessageType::StatusQuery);}

void DeviceSession::sendCommand(protocol::MessageType type,const QByteArray& payload){if(mode_==Mode::Mock||!serial_->isOpen())return;commandQueue_.enqueue(qMakePair(type,payload));if(!commandTimer_.isActive())sendNextCommand();}

void DeviceSession::sendNextCommand(){if(commandQueue_.isEmpty()||!serial_->isOpen())return;const auto command=commandQueue_.dequeue();protocol::Frame frame;frame.type=command.first;frame.flags=quint8(protocol::Flag::AckRequired);frame.sequence=sequence_++;frame.payload=command.second;serial_->writeBytes(protocol::encode(frame));emit logMessage(QStringLiteral("TX    type=0x%1 seq=%2").arg(quint8(frame.type),2,16,QChar('0')).arg(frame.sequence));
    // The FPGA accepts a new request only after it has accepted the preceding
    // response for transmission.  Keep the pacing timer active even when the
    // queue is momentarily empty, so several same-event commands cannot be
    // written back-to-back and lost while a response is pending.
    commandTimer_.start();}

void DeviceSession::readSerial(){}

void DeviceSession::handleFrame(const protocol::Frame& frame){const auto noteDataFlow=[this]{const bool first=!dataFlowSeen_;dataFlowSeen_=true;dataStartTimer_.stop();dataIdleTimer_.start();if(first)emit logMessage(QStringLiteral("INFO  First selected data frame received; stream is active."));};if(frame.type==protocol::MessageType::AngleSample){if(!streamAngles_)return;const auto sample=model::parseAngleSample(frame.payload);if(sample){noteDataFlow();emit mirrorConnectionChanged(true);emit angleSampleReceived(*sample);}else emit logMessage(QStringLiteral("WARNING  Invalid angle-sample frame length."));return;}if(frame.type==protocol::MessageType::HarmonicCurve){if(!streamHarmonics_)return;const auto curve=model::parseHarmonicCurve(frame.payload);if(curve){noteDataFlow();emit harmonicCurveReceived(*curve);}else emit logMessage(QStringLiteral("WARNING  Invalid harmonic I/Q frame length."));return;}if(frame.type==protocol::MessageType::FusedPoint){const auto point=model::parseFusedPoint(frame.payload);if(point){emit mirrorConnectionChanged((point->flags&0x0010u)!=0);if(streamAngles_||streamHarmonics_){noteDataFlow();emit pointReceived(*point);}}else emit logMessage(QStringLiteral("WARNING  Invalid fused-point frame length."));return;}
    if(frame.flags&quint8(protocol::Flag::IsResponse)){const quint8 status=frame.payload.isEmpty()?0xff:quint8(frame.payload[0]);emit logMessage(QStringLiteral("RX    type=0x%1 seq=%2 status=%3").arg(quint8(frame.type),2,16,QChar('0')).arg(frame.sequence).arg(status));if(frame.type==protocol::MessageType::StreamStart&&status==0)emit logMessage(QStringLiteral("INFO  FPGA fused stream enabled."));}}

model::FusedPoint DeviceSession::makeMockPoint(){constexpr int width=50,height=64;const bool reverse=mockLine_&1;const int logicalX=reverse?(width-1-mockColumn_):mockColumn_;
    model::FusedPoint p;p.measurementTime=mockTicks_;p.imageId=mockImage_;p.lineId=quint16(mockLine_);p.pointId=quint16(mockColumn_);
    p.xAngleQ13=qint16(-16384+logicalX*32768/(width-1));p.yAngleQ13=qint16(-8192+mockLine_*16384/(height-1));
    const double dx1=(logicalX-34)/8.0,dy1=(mockLine_-28)/10.0,dx2=(logicalX-15)/6.0,dy2=(mockLine_-46)/7.0;
    const double plume=0.008+0.115*qExp(-(dx1*dx1+dy1*dy1))+0.055*qExp(-(dx2*dx2+dy2*dy2));
    p.a1=180000+quint32(12000*qSin(mockColumn_*0.13));p.a2=quint32(p.a1*plume);p.i1=qint32(p.a1);p.q1=qint32(p.a1/12);p.i2=qint32(p.a2*0.86);p.q2=qint32(p.a2*0.51);
    p.flags=0x00F8|(reverse?0x0001:0);p.configRevision=1;mockTicks_+=100000;
    if(++mockColumn_==width){mockColumn_=0;if(++mockLine_==height){mockLine_=0;++mockImage_;emit logMessage(QStringLiteral("INFO  Mock image %1 complete.").arg(mockImage_-1));}}
    return p;}

void DeviceSession::generateMockBatch(){if(!running_)return;for(int i=0;i<5;++i){const auto point=makeMockPoint();if(streamAngles_){model::AngleSample sample;sample.measurementTime=point.measurementTime;sample.sampleIndex=point.lineId;sample.xAngleQ13=point.xAngleQ13;sample.yAngleQ13=point.yAngleQ13;emit angleSampleReceived(sample);}if(streamHarmonics_){model::HarmonicCurve curve;curve.measurementTime=point.measurementTime;curve.sampleIndex=mockHarmonicSample_++%100;curve.i1=point.i1;curve.q1=point.q1;curve.i2=point.i2;curve.q2=point.q2;emit harmonicCurveReceived(curve);}if(streamAngles_&&streamHarmonics_)emit pointReceived(point);}}

}  // namespace ch4::device
