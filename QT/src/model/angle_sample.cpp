#include "model/angle_sample.h"

#include "protocol/frame_codec.h"
#include "protocol/generated_protocol.h"

namespace ch4::model {
namespace {
quint64 readU64(QByteArrayView bytes, qsizetype offset) {
    return protocol::readU32(bytes, offset) | (quint64(protocol::readU32(bytes, offset + 4)) << 32);
}
}

std::optional<AngleSample> parseAngleSample(QByteArrayView payload) {
    if (payload.size() != qsizetype(protocol::kAngleSampleSize))
        return {};
    AngleSample sample;
    sample.measurementTime = readU64(payload, 0);
    sample.sampleIndex = protocol::readU32(payload, 8);
    sample.xAngleQ13 = qint16(protocol::readU16(payload, 12));
    sample.yAngleQ13 = qint16(protocol::readU16(payload, 14));
    return sample;
}
}  // namespace ch4::model
