#pragma once

#include <QByteArrayView>
#include <QMetaType>
#include <QtGlobal>

#include <optional>

namespace ch4::model {

struct AngleSample {
    quint64 measurementTime = 0;
    quint32 sampleIndex = 0;
    qint16 xAngleQ13 = 0;
    qint16 yAngleQ13 = 0;

    [[nodiscard]] double xDegrees() const { return double(xAngleQ13) / 8192.0; }
    [[nodiscard]] double yDegrees() const { return double(yAngleQ13) / 8192.0; }
};

std::optional<AngleSample> parseAngleSample(QByteArrayView payload);

}  // namespace ch4::model

Q_DECLARE_METATYPE(ch4::model::AngleSample)
