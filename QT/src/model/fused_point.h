#pragma once

#include <QByteArrayView>
#include <QMetaType>
#include <QtGlobal>
#include <cmath>
#include <optional>

namespace ch4::model {

struct FusedPoint {
    quint64 measurementTime = 0;
    quint32 imageId = 0;
    quint16 lineId = 0;
    quint16 pointId = 0;
    qint16 xAngleQ13 = 0;
    qint16 yAngleQ13 = 0;
    qint32 i1 = 0;
    qint32 q1 = 0;
    qint32 i2 = 0;
    qint32 q2 = 0;
    quint32 a1 = 0;
    quint32 a2 = 0;
    quint16 flags = 0;
    quint16 configRevision = 0;

    [[nodiscard]] double xDegrees() const { return double(xAngleQ13) / 8192.0; }
    [[nodiscard]] double yDegrees() const { return double(yAngleQ13) / 8192.0; }
    [[nodiscard]] double amplitude1f() const { return a1 != 0 ? double(a1) : std::hypot(double(i1), double(q1)); }
    [[nodiscard]] double amplitude2f() const { return a2 != 0 ? double(a2) : std::hypot(double(i2), double(q2)); }
    [[nodiscard]] double ratio() const { const double one = amplitude1f(); return one == 0.0 ? 0.0 : amplitude2f() / one; }
    [[nodiscard]] bool valid() const { return (flags & 0x00D8u) == 0x00D8u; }
};

std::optional<FusedPoint> parseFusedPoint(QByteArrayView payload);

}  // namespace ch4::model

Q_DECLARE_METATYPE(ch4::model::FusedPoint)
