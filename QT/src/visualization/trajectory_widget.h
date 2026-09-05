#pragma once
#include <QPointF>
#include <QVector>
#include <QWidget>
#include <QPoint>

class QMouseEvent;
class QWheelEvent;

namespace ch4::visualization {
class TrajectoryWidget final : public QWidget {
public:
    enum class DisplayMode { Trajectory, Scatter };

    explicit TrajectoryWidget(QWidget* parent = nullptr);
    void append(double x, double y);
    void clear();
    void configureRange(double xMinimum, double xMaximum, double yMinimum, double yMaximum);
    void setDisplayMode(DisplayMode mode);
protected:
    void paintEvent(QPaintEvent*) override;
    void mousePressEvent(QMouseEvent*) override;
    void mouseMoveEvent(QMouseEvent*) override;
    void mouseReleaseEvent(QMouseEvent*) override;
    void wheelEvent(QWheelEvent*) override;
    void leaveEvent(QEvent*) override;
private:
    QVector<QPointF> points_;
    double xMinimum_ = -2.2;
    double xMaximum_ = 2.2;
    double yMinimum_ = -1.1;
    double yMaximum_ = 1.1;
    double zoom_ = 1.0;
    DisplayMode displayMode_ = DisplayMode::Trajectory;
    QPointF center_{0.0, 0.0};
    QPoint lastMouse_;
    QPoint cursor_;
    bool dragging_ = false;
    bool cursorInside_ = false;
};
}
