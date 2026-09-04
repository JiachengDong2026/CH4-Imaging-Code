#pragma once
#include "processing/image_accumulator.h"
#include <QWidget>
#include <QPoint>

class QMouseEvent;
class QWheelEvent;
namespace ch4::visualization {
class MethaneImageWidget final : public QWidget {
public:
    explicit MethaneImageWidget(QWidget* parent = nullptr);
    bool add(const model::FusedPoint& p);
    void clear();
    void configure(int width, int height, double xMin, double xMax, double yMin, double yMax);
    int validCells() const { return image_.validCellCount(); }

protected:
    void paintEvent(QPaintEvent*) override;
    void mousePressEvent(QMouseEvent*) override;
    void mouseMoveEvent(QMouseEvent*) override;
    void mouseReleaseEvent(QMouseEvent*) override;
    void wheelEvent(QWheelEvent*) override;
    void leaveEvent(QEvent*) override;

private:
    processing::ImageAccumulator image_;
    double xMin_ = -4.0;
    double xMax_ = 4.0;
    double yMin_ = -4.0;
    double yMax_ = 4.0;
    double zoom_ = 1.0;
    QPointF center_{0.0, 0.0};
    QPoint lastMouse_;
    QPoint cursor_;
    bool dragging_ = false;
    bool cursorInside_ = false;
};
}
