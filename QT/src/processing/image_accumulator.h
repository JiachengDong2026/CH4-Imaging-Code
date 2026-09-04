#pragma once

#include "model/fused_point.h"

#include <QVector>

namespace ch4::processing {

class ImageAccumulator {
public:
    ImageAccumulator(int width = 128, int height = 64, double xMin = -4.0,
                     double xMax = 4.0, double yMin = -4.0, double yMax = 4.0);
    void configure(int width, int height, double xMin, double xMax, double yMin, double yMax);
    void reset();
    bool add(const model::FusedPoint& point);
    [[nodiscard]] int width() const { return width_; }
    [[nodiscard]] int height() const { return height_; }
    [[nodiscard]] double value(int x, int y) const;
    [[nodiscard]] quint32 count(int x, int y) const;
    [[nodiscard]] int validCellCount() const;

private:
    int index(int x, int y) const { return y * width_ + x; }
    int width_;
    int height_;
    double xMin_;
    double xMax_;
    double yMin_;
    double yMax_;
    QVector<double> sums_;
    QVector<quint32> counts_;
};

}  // namespace ch4::processing
