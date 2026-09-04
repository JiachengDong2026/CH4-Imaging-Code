#include "processing/image_accumulator.h"

#include <QtMath>

namespace ch4::processing {

ImageAccumulator::ImageAccumulator(int width, int height, double xMin, double xMax, double yMin, double yMax)
    : width_(2), height_(2), xMin_(-4.0), xMax_(4.0), yMin_(-4.0), yMax_(4.0) {
    configure(width, height, xMin, xMax, yMin, yMax);
}

void ImageAccumulator::configure(int width, int height, double xMin, double xMax, double yMin, double yMax) {
    width_ = qMax(2, width);
    height_ = qMax(2, height);
    xMin_ = qMin(xMin, xMax - 1e-9);
    xMax_ = qMax(xMax, xMin + 1e-9);
    yMin_ = qMin(yMin, yMax - 1e-9);
    yMax_ = qMax(yMax, yMin + 1e-9);
    sums_.fill(0.0, width_ * height_);
    counts_.fill(0, width_ * height_);
}

void ImageAccumulator::reset() {
    sums_.fill(0.0);
    counts_.fill(0);
}

bool ImageAccumulator::add(const model::FusedPoint& point) {
    if (!point.valid() || point.amplitude1f() == 0.0)
        return false;
    const int x = qBound(0, qRound((point.xDegrees() - xMin_) / (xMax_ - xMin_) * (width_ - 1)), width_ - 1);
    const int y = qBound(0, qRound((point.yDegrees() - yMin_) / (yMax_ - yMin_) * (height_ - 1)), height_ - 1);
    const int cell = index(x, y);
    sums_[cell] += point.ratio();
    ++counts_[cell];
    return true;
}

double ImageAccumulator::value(int x, int y) const {
    if (x < 0 || x >= width_ || y < 0 || y >= height_)
        return 0.0;
    const int cell = index(x, y);
    return counts_[cell] ? sums_[cell] / double(counts_[cell]) : 0.0;
}

quint32 ImageAccumulator::count(int x, int y) const {
    return (x < 0 || x >= width_ || y < 0 || y >= height_) ? 0 : counts_[index(x, y)];
}

int ImageAccumulator::validCellCount() const {
    int result = 0;
    for (const auto count : counts_)
        result += count != 0;
    return result;
}
}  // namespace ch4::processing
