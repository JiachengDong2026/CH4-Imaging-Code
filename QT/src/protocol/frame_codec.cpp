#include "protocol/frame_codec.h"

#include <QStringList>

namespace ch4::protocol {

quint16 crc16(QByteArrayView data, quint16 crc) {
    for (const char byte : data) {
        crc ^= quint16(quint8(byte)) << 8;
        for (int bit = 0; bit < 8; ++bit)
            crc = (crc & 0x8000) ? quint16((crc << 1) ^ 0x1021) : quint16(crc << 1);
    }
    return crc;
}

void appendU16(QByteArray& output, quint16 value) {
    output += char(value);
    output += char(value >> 8);
}

void appendU32(QByteArray& output, quint32 value) {
    appendU16(output, quint16(value));
    appendU16(output, quint16(value >> 16));
}

quint16 readU16(QByteArrayView input, qsizetype offset) {
    return quint16(quint8(input[offset])) | (quint16(quint8(input[offset + 1])) << 8);
}

quint32 readU32(QByteArrayView input, qsizetype offset) {
    return readU16(input, offset) | (quint32(readU16(input, offset + 2)) << 16);
}

QByteArray encode(const Frame& frame) {
    if (frame.payload.size() > kMaxPayload)
        return {};
    QByteArray bytes;
    bytes.reserve(qsizetype(kFrameOverhead) + frame.payload.size());
    bytes += char(kSof0);
    bytes += char(kSof1);
    bytes += char(frame.version);
    bytes += char(frame.dst);
    bytes += char(frame.src);
    bytes += char(frame.type);
    bytes += char(frame.flags);
    appendU16(bytes, frame.sequence);
    appendU16(bytes, quint16(frame.payload.size()));
    bytes += frame.payload;
    appendU16(bytes, crc16(QByteArrayView(bytes).sliced(2)));
    return bytes;
}

std::optional<Frame> decode(QByteArrayView bytes, QString* error) {
    const auto fail = [error](const QString& reason) -> std::optional<Frame> {
        if (error)
            *error = reason;
        return {};
    };
    if (bytes.size() < qsizetype(kFrameOverhead))
        return fail(QStringLiteral("帧太短"));
    if (quint8(bytes[0]) != kSof0 || quint8(bytes[1]) != kSof1)
        return fail(QStringLiteral("帧头错误"));
    const quint16 payloadLength = readU16(bytes, 9);
    if (payloadLength > kMaxPayload)
        return fail(QStringLiteral("载荷长度超过上限"));
    if (bytes.size() != qsizetype(kFrameOverhead + payloadLength))
        return fail(QStringLiteral("帧长度不匹配"));
    if (readU16(bytes, 11 + payloadLength) != crc16(bytes.sliced(2, 9 + payloadLength)))
        return fail(QStringLiteral("CRC 校验失败"));
    if (quint8(bytes[2]) != kVersion)
        return fail(QStringLiteral("协议版本不支持"));

    Frame frame;
    frame.version = quint8(bytes[2]);
    frame.dst = quint8(bytes[3]);
    frame.src = quint8(bytes[4]);
    frame.type = static_cast<MessageType>(quint8(bytes[5]));
    frame.flags = quint8(bytes[6]);
    frame.sequence = readU16(bytes, 7);
    frame.payload = QByteArray(bytes.sliced(11, payloadLength));
    return frame;
}

QList<Frame> FrameParser::push(QByteArrayView input) {
    stats_.bytes += quint64(input.size());
    buffer_ += input;
    QList<Frame> frames;
    const QByteArray sof = QByteArray::fromHex("A55A");
    for (;;) {
        const qsizetype offset = buffer_.indexOf(sof);
        if (offset < 0) {
            const bool keepA5 = !buffer_.isEmpty() && quint8(buffer_.back()) == kSof0;
            const qsizetype discard = buffer_.size() - (keepA5 ? 1 : 0);
            stats_.discardedBytes += quint64(discard);
            buffer_.remove(0, discard);
            break;
        }
        if (offset > 0) {
            stats_.discardedBytes += quint64(offset);
            buffer_.remove(0, offset);
        }
        if (buffer_.size() < 11)
            break;
        const quint16 payloadLength = readU16(buffer_, 9);
        if (payloadLength > kMaxPayload) {
            ++stats_.lengthErrors;
            ++stats_.discardedBytes;
            buffer_.remove(0, 1);
            continue;
        }
        const qsizetype frameSize = qsizetype(kFrameOverhead + payloadLength);
        if (buffer_.size() < frameSize)
            break;
        QString error;
        const auto frame = decode(QByteArrayView(buffer_).first(frameSize), &error);
        if (frame) {
            frames += *frame;
            ++stats_.frames;
            buffer_.remove(0, frameSize);
        } else {
            if (error.contains(QStringLiteral("CRC")))
                ++stats_.crcErrors;
            else
                ++stats_.lengthErrors;
            ++stats_.discardedBytes;
            buffer_.remove(0, 1);
        }
    }
    return frames;
}

void FrameParser::reset() {
    buffer_.clear();
    stats_ = {};
}

QString hexDump(QByteArrayView bytes, int maxBytes) {
    QStringList values;
    const int count = qMin(int(bytes.size()), maxBytes);
    for (int index = 0; index < count; ++index)
        values << QStringLiteral("%1").arg(quint8(bytes[index]), 2, 16, QChar('0')).toUpper();
    if (bytes.size() > maxBytes)
        values << QStringLiteral("...");
    return values.join(QLatin1Char(' '));
}

}  // namespace ch4::protocol

