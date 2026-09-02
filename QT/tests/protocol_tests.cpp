#include "protocol/frame_codec.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QtTest>

using namespace ch4::protocol;

class ProtocolTests final : public QObject {
    Q_OBJECT

private slots:
    void standardCrcVector() {
        QCOMPARE(crc16(QByteArrayView("123456789")), quint16(0x29B1));
    }

    void sharedFixedVectors() {
        QFile file(QStringLiteral(CH4_PROJECT_ROOT "/Shared/test_vectors/protocol_vectors.json"));
        QVERIFY2(file.open(QIODevice::ReadOnly), qPrintable(file.errorString()));
        const auto document = QJsonDocument::fromJson(file.readAll());
        QVERIFY(document.isObject());
        const auto vectors = document.object().value(QStringLiteral("vectors")).toArray();
        QCOMPARE(vectors.size(), 4);
        for (const auto& item : vectors) {
            const auto object = item.toObject();
            const auto bytes = QByteArray::fromHex(object.value(QStringLiteral("frame_hex")).toString().toLatin1());
            QString error;
            const auto frame = decode(bytes, &error);
            QCOMPARE(bool(frame), object.value(QStringLiteral("valid")).toBool());
        }
    }

    void roundTripAndLittleEndian() {
        Frame frame;
        frame.type = MessageType::WriteReg;
        frame.flags = quint8(Flag::AckRequired);
        frame.sequence = 0x1235;
        appendU32(frame.payload, 0x00000110);
        appendU32(frame.payload, 5000);
        const auto bytes = encode(frame);
        QCOMPARE(quint8(bytes[7]), quint8(0x35));
        QCOMPARE(quint8(bytes[8]), quint8(0x12));
        const auto decoded = decode(bytes);
        QVERIFY(decoded.has_value());
        QCOMPARE(decoded->sequence, frame.sequence);
        QCOMPARE(readU32(decoded->payload, 0), quint32(0x00000110));
        QCOMPARE(readU32(decoded->payload, 4), quint32(5000));
    }

    void fragmentedGarbageAndBackToBack() {
        Frame first;
        first.type = MessageType::Hello;
        first.sequence = 1;
        Frame second;
        second.type = MessageType::Heartbeat;
        second.sequence = 2;
        const QByteArray stream = QByteArray::fromHex("007EA5") + encode(first) + encode(second);
        FrameParser parser;
        QList<Frame> frames;
        for (const char byte : stream)
            frames += parser.push(QByteArrayView(&byte, 1));
        QCOMPARE(frames.size(), 2);
        QCOMPARE(frames[0].sequence, quint16(1));
        QCOMPARE(frames[1].sequence, quint16(2));
        QCOMPARE(parser.stats().frames, quint64(2));
        QVERIFY(parser.stats().discardedBytes >= 2);
    }

    void badCrcThenRecovery() {
        Frame bad;
        bad.type = MessageType::Hello;
        QByteArray corrupt = encode(bad);
        corrupt[5] ^= char(0x01);
        Frame good;
        good.type = MessageType::StatusQuery;
        good.sequence = 77;
        FrameParser parser;
        const auto frames = parser.push(corrupt + encode(good));
        QCOMPARE(frames.size(), 1);
        QCOMPARE(frames.first().sequence, quint16(77));
        QCOMPARE(parser.stats().crcErrors, quint64(1));
    }
};

QTEST_GUILESS_MAIN(ProtocolTests)
#include "protocol_tests.moc"

