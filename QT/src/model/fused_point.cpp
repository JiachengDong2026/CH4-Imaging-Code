#include "model/fused_point.h"

#include "protocol/frame_codec.h"

namespace ch4::model {
namespace {
quint64 readU64(QByteArrayView bytes, qsizetype offset) {
    return protocol::readU32(bytes, offset) | (quint64(protocol::readU32(bytes, offset + 4)) << 32);
}
qint16 readI16(QByteArrayView bytes, qsizetype offset) {
    return qint16(protocol::readU16(bytes, offset));
}
qint32 readI32(QByteArrayView bytes, qsizetype offset) {
    return qint32(protocol::readU32(bytes, offset));
}
}

std::optional<FusedPoint> parseFusedPoint(QByteArrayView payload) {
    if (payload.size() != qsizetype(protocol::kFusedPointSize))
        return {};
    FusedPoint point;
    point.measurementTime = readU64(payload, 0);
    point.imageId = protocol::readU32(payload, 8);
    point.lineId = protocol::readU16(payload, 12);
    point.pointId = protocol::readU16(payload, 14);
    point.xAngleQ13 = readI16(payload, 16);
    point.yAngleQ13 = readI16(payload, 18);
    point.i1 = readI32(payload, 20);
    point.q1 = readI32(payload, 24);
    point.i2 = readI32(payload, 28);
    point.q2 = readI32(payload, 32);
    point.a1 = protocol::readU32(payload, 36);
    point.a2 = protocol::readU32(payload, 40);
    point.flags = protocol::readU16(payload, 44);
    point.configRevision = protocol::readU16(payload, 46);
    return point;
}
}  // namespace ch4::model

