#include "device/device_session.h"
#include "processing/image_accumulator.h"
#include "protocol/frame_codec.h"

#include <QSignalSpy>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QtTest>

using ch4::model::FusedPoint;

class Stage1Tests final:public QObject {
    Q_OBJECT
private slots:
 void fixedFusedPoint(){QFile f(QStringLiteral(CH4_PROJECT_ROOT "/Shared/test_vectors/protocol_vectors.json"));QVERIFY(f.open(QIODevice::ReadOnly));const auto doc=QJsonDocument::fromJson(f.readAll());const auto list=doc.object()["vectors"].toArray();QByteArray frame;
  for(const auto&v:list)if(v.toObject()["name"].toString()==QStringLiteral("fused_point_stream"))frame=QByteArray::fromHex(v.toObject()["frame_hex"].toString().toLatin1());auto decoded=ch4::protocol::decode(frame);QVERIFY(decoded);auto p=ch4::model::parseFusedPoint(decoded->payload);QVERIFY(p);QCOMPARE(p->measurementTime,quint64(0x0123456789ABCDEF));QCOMPARE(p->xAngleQ13,qint16(-8192));QCOMPARE(p->configRevision,quint16(9));}
 void rasterUsesActualCoordinates(){ch4::processing::ImageAccumulator image(128,64);FusedPoint p;p.flags=0x00D8;p.a1=100;p.a2=25;p.xAngleQ13=-32768;p.yAngleQ13=-32768;QVERIFY(image.add(p));QCOMPARE(image.count(0,0),quint32(1));p.xAngleQ13=32767;p.yAngleQ13=32767;QVERIFY(image.add(p));QCOMPARE(image.count(127,63),quint32(1));}
 void mockProducesCompleteValidZigzag(){ch4::device::DeviceSession session;QSignalSpy spy(&session,&ch4::device::DeviceSession::pointReceived);QVERIFY(session.connectDevice(ch4::device::DeviceSession::Mode::Mock));session.start();for(int i=0;i<640;++i)QVERIFY(QMetaObject::invokeMethod(&session,"generateMockBatch",Qt::DirectConnection));session.stop();QCOMPARE(spy.count(),3200);const auto first=qvariant_cast<FusedPoint>(spy[0][0]);const auto line1=qvariant_cast<FusedPoint>(spy[50][0]);const auto last=qvariant_cast<FusedPoint>(spy[3199][0]);QCOMPARE(first.lineId,quint16(0));QCOMPARE(line1.lineId,quint16(1));QCOMPARE(last.lineId,quint16(63));QVERIFY(first.xAngleQ13<line1.xAngleQ13);QVERIFY(first.valid());QVERIFY(last.valid());ch4::processing::ImageAccumulator image(50,64,-2.0,2.0,-1.0,1.0);for(int i=0;i<3200;++i)QVERIFY(image.add(qvariant_cast<FusedPoint>(spy[i][0])));QCOMPARE(image.validCellCount(),3200);}
 void mockStreamsAreIndependent(){ch4::device::DeviceSession session;QSignalSpy points(&session,&ch4::device::DeviceSession::pointReceived),angles(&session,&ch4::device::DeviceSession::angleSampleReceived),harmonics(&session,&ch4::device::DeviceSession::harmonicCurveReceived);QVERIFY(session.connectDevice(ch4::device::DeviceSession::Mode::Mock));session.setStreamSelection(true,false);session.start();QVERIFY(QMetaObject::invokeMethod(&session,"generateMockBatch",Qt::DirectConnection));session.stop();QCOMPARE(points.count(),0);QCOMPARE(angles.count(),5);QCOMPARE(harmonics.count(),0);session.setStreamSelection(false,true);session.start();QVERIFY(QMetaObject::invokeMethod(&session,"generateMockBatch",Qt::DirectConnection));session.stop();QCOMPARE(points.count(),0);QCOMPARE(angles.count(),5);QCOMPARE(harmonics.count(),5);}
};
QTEST_GUILESS_MAIN(Stage1Tests)
#include "stage1_tests.moc"
