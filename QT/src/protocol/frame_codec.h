#pragma once

#include "protocol/generated_protocol.h"

#include <QByteArray>
#include <QList>
#include <QString>
#include <QtGlobal>
#include <optional>

namespace ch4::protocol {

struct Frame {
    quint8 version = kVersion;
    quint8 dst = static_cast<quint8>(Address::Fpga);
    quint8 src = static_cast<quint8>(Address::Host);
    MessageType type = MessageType::Hello;
    quint8 flags = 0;
    quint16 sequence = 0;
    QByteArray payload;
};

struct ParserStats {
    quint64 bytes = 0;
    quint64 frames = 0;
    quint64 crcErrors = 0;
    quint64 lengthErrors = 0;
    quint64 discardedBytes = 0;
};

quint16 crc16(QByteArrayView data, quint16 initial = 0xFFFF);
void appendU16(QByteArray& output, quint16 value);
void appendU32(QByteArray& output, quint32 value);
quint16 readU16(QByteArrayView input, qsizetype offset);
quint32 readU32(QByteArrayView input, qsizetype offset);
QByteArray encode(const Frame& frame);
std::optional<Frame> decode(QByteArrayView bytes, QString* error = nullptr);

class FrameParser {
public:
    QList<Frame> push(QByteArrayView bytes);
    void reset();
    [[nodiscard]] const ParserStats& stats() const { return stats_; }

private:
    QByteArray buffer_;
    ParserStats stats_;
};

QString hexDump(QByteArrayView bytes, int maxBytes = 96);

}  // namespace ch4::protocol

