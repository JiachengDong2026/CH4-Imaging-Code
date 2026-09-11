#pragma once
#include "protocol/frame_codec.h"
#include <QMetaType>

#include <cmath>
#include <optional>
namespace ch4::model {
struct HarmonicCurve {
    quint64 measurementTime = 0;
    quint32 sampleIndex = 0;
    qint32 i1 = 0;
    qint32 q1 = 0;
    qint32 i2 = 0;
    qint32 q2 = 0;

    [[nodiscard]] double amplitude1f() const { return std::hypot(double(i1), double(q1)); }
    [[nodiscard]] double amplitude2f() const { return std::hypot(double(i2), double(q2)); }
};
std::optional<HarmonicCurve> parseHarmonicCurve(QByteArrayView payload);
}
Q_DECLARE_METATYPE(ch4::model::HarmonicCurve)
