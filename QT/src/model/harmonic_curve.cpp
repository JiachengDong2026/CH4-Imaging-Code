#include "model/harmonic_curve.h"
#include "protocol/generated_protocol.h"

namespace ch4::model {
namespace {
qint32 readI32(QByteArrayView bytes, qsizetype offset) {
    return qint32(protocol::readU32(bytes, offset));
}
}

std::optional<HarmonicCurve> parseHarmonicCurve(QByteArrayView b) {
    if (b.size() != qsizetype(protocol::kHarmonicCurveSize))
        return {};
    HarmonicCurve c;
    c.measurementTime = protocol::readU32(b, 0) | (quint64(protocol::readU32(b, 4)) << 32);
    c.sampleIndex = protocol::readU32(b, 8);
    c.i1 = readI32(b, 12);
    c.q1 = readI32(b, 16);
    c.i2 = readI32(b, 20);
    c.q2 = readI32(b, 24);
    return c;
}
}
