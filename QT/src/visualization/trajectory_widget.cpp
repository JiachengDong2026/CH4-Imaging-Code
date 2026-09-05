#include "visualization/trajectory_widget.h"

#include <QMouseEvent>
#include <QPainter>
#include <QPainterPath>
#include <QWheelEvent>

#include <cmath>

namespace ch4::visualization {
namespace {
QRectF plotRect(const QWidget* widget, double, double) {
    // A square canvas makes the equal X/Y view obvious and gives a stable
    // reference for circular or raster scan trajectories.
    QRectF plot = QRectF(widget->rect()).adjusted(46, 12, -14, -42);
    if (plot.isEmpty()) return {};
    const double side = qMin(plot.width(), plot.height());
    plot.setLeft(plot.center().x() - side / 2.0);
    plot.setTop(plot.center().y() - side / 2.0);
    plot.setSize(QSizeF(side, side));
    return plot;
}
}

TrajectoryWidget::TrajectoryWidget(QWidget* parent) : QWidget(parent) {
    setMinimumSize(420, 300);
    setMouseTracking(true);
}

void TrajectoryWidget::append(double x, double y) {
    points_.append({x, y});
    if (points_.size() > 12000) points_.remove(0, points_.size() - 12000);
}

void TrajectoryWidget::clear() {
    points_.clear(); zoom_ = 1.0;
    center_ = {(xMinimum_ + xMaximum_) / 2.0, (yMinimum_ + yMaximum_) / 2.0};
    update();
}

void TrajectoryWidget::configureRange(double xMinimum, double xMaximum, double yMinimum, double yMaximum) {
    const auto applyMargin = [](double minimum, double maximum, double& outMinimum, double& outMaximum) {
        const double margin = qMax(0.001, maximum - minimum) * 0.075;
        outMinimum = minimum - margin;
        outMaximum = maximum + margin;
    };
    applyMargin(xMinimum, xMaximum, xMinimum_, xMaximum_);
    applyMargin(yMinimum, yMaximum, yMinimum_, yMaximum_);
    // The view is intentionally square.  Expand the smaller display axis
    // around its configured centre; the actual FPGA scan limits are unchanged.
    const double squareSpan = qMax(xMaximum_ - xMinimum_, yMaximum_ - yMinimum_);
    const double xCenter = (xMinimum_ + xMaximum_) / 2.0;
    const double yCenter = (yMinimum_ + yMaximum_) / 2.0;
    xMinimum_ = xCenter - squareSpan / 2.0;
    xMaximum_ = xCenter + squareSpan / 2.0;
    yMinimum_ = yCenter - squareSpan / 2.0;
    yMaximum_ = yCenter + squareSpan / 2.0;
    clear();
}

void TrajectoryWidget::setDisplayMode(DisplayMode mode) {
    if (displayMode_ == mode) return;
    displayMode_ = mode;
    update();
}

void TrajectoryWidget::paintEvent(QPaintEvent*) {
    QPainter p(this); p.setRenderHint(QPainter::Antialiasing); p.fillRect(rect(), Qt::white);
    const double spanX = (xMaximum_ - xMinimum_) / zoom_;
    const double spanY = (yMaximum_ - yMinimum_) / zoom_;
    const QRectF plot = plotRect(this, spanX, spanY);
    if (plot.isEmpty()) return;
    const double left = center_.x() - spanX / 2.0;
    const double bottom = center_.y() - spanY / 2.0;
    const double top = center_.y() + spanY / 2.0;
    const auto map = [plot, left, bottom, spanX, spanY](QPointF value) {
        return QPointF(plot.left() + (value.x() - left) / spanX * plot.width(),
                       plot.bottom() - (value.y() - bottom) / spanY * plot.height());
    };
    p.save(); p.setClipRect(plot); p.setPen(QColor("#e9edf0"));
    for (int i = 1; i < 8; ++i) { const double f = i / 8.0;
        p.drawLine(QPointF(plot.left() + f * plot.width(), plot.top()), QPointF(plot.left() + f * plot.width(), plot.bottom()));
        p.drawLine(QPointF(plot.left(), plot.top() + f * plot.height()), QPointF(plot.right(), plot.top() + f * plot.height())); }
    if (displayMode_ == DisplayMode::Trajectory && points_.size() > 1) {
        QPainterPath path(map(points_.first()));
        for (int i = 1; i < points_.size(); ++i) path.lineTo(map(points_[i]));
        p.setPen(QPen(QColor("#1976d2"), 1.4));
        p.drawPath(path);
    } else if (displayMode_ == DisplayMode::Scatter) {
        p.setPen(Qt::NoPen);
        p.setBrush(QColor("#1976d2"));
        for (const QPointF& point : points_) p.drawEllipse(map(point), 1.7, 1.7);
    }
    p.restore(); p.setPen(QColor("#667085")); p.drawRect(plot);
    for (int i = 0; i <= 8; ++i) { const double f = i / 8.0; const double x = left + f * spanX; const double y = top - f * spanY;
        const double px = plot.left() + f * plot.width(), py = plot.top() + f * plot.height();
        p.drawLine(QPointF(px, plot.bottom()), QPointF(px, plot.bottom() + 4));
        p.drawText(QRectF(px - 30, plot.bottom() + 5, 60, 18), Qt::AlignHCenter | Qt::AlignTop, QString::number(x, 'f', 1));
        p.drawLine(QPointF(plot.left() - 4, py), QPointF(plot.left(), py));
        p.drawText(QRectF(2, py - 9, plot.left() - 8, 18), Qt::AlignRight | Qt::AlignVCenter, QString::number(y, 'f', 1)); }
    p.setPen(QColor("#475467"));
    p.drawText(QRectF(plot.left(), plot.bottom() + 28, plot.width(), 18), Qt::AlignHCenter, QStringLiteral("X angle (deg)"));
    p.save(); p.translate(16, plot.center().y()); p.rotate(-90);
    p.drawText(QRectF(-plot.height() / 2.0, -9, plot.height(), 18), Qt::AlignHCenter, QStringLiteral("Y angle (deg)")); p.restore();
    if (points_.isEmpty()) { p.setPen(QColor("#98a2b3")); p.drawText(plot, Qt::AlignCenter, QStringLiteral("Waiting for trajectory data")); }
    if (cursorInside_ && plot.contains(cursor_)) { const double x = left + (cursor_.x() - plot.left()) / plot.width() * spanX; const double y = top - (cursor_.y() - plot.top()) / plot.height() * spanY; const QString text = QStringLiteral("X %1°   Y %2°").arg(x, 0, 'f', 3).arg(y, 0, 'f', 3); QSizeF size=p.fontMetrics().size(Qt::TextSingleLine,text)+QSizeF(14,8); QPointF pos=QPointF(cursor_)+QPointF(14,14); if(pos.x()+size.width()>width()-4)pos.setX(cursor_.x()-size.width()-14); if(pos.y()+size.height()>height()-4)pos.setY(cursor_.y()-size.height()-14); const QRectF box(pos,size); p.setPen(QColor("#8795a1")); p.setBrush(QColor(255,255,255,235)); p.drawRoundedRect(box,3,3); p.setPen(QColor("#344054")); p.drawText(box, Qt::AlignCenter, text); }
}

void TrajectoryWidget::mousePressEvent(QMouseEvent* event) { const QRectF plot=plotRect(this,(xMaximum_-xMinimum_)/zoom_,(yMaximum_-yMinimum_)/zoom_); if(event->button()==Qt::LeftButton&&plot.contains(event->position())){dragging_=true;lastMouse_=event->position().toPoint();setCursor(Qt::ClosedHandCursor);} cursor_=event->position().toPoint();cursorInside_=true;update(); }
void TrajectoryWidget::mouseMoveEvent(QMouseEvent* event) { const QPoint current=event->position().toPoint(); const double spanX=(xMaximum_-xMinimum_)/zoom_,spanY=(yMaximum_-yMinimum_)/zoom_; const QRectF plot=plotRect(this,spanX,spanY); if(dragging_){center_.rx()-=(current.x()-lastMouse_.x())/plot.width()*spanX;center_.ry()+=(current.y()-lastMouse_.y())/plot.height()*spanY;lastMouse_=current;} cursor_=current;cursorInside_=plot.contains(current);update(); }
void TrajectoryWidget::mouseReleaseEvent(QMouseEvent* event) { if(event->button()==Qt::LeftButton){dragging_=false;unsetCursor();} }
void TrajectoryWidget::wheelEvent(QWheelEvent* event) { const double oldX=(xMaximum_-xMinimum_)/zoom_,oldY=(yMaximum_-yMinimum_)/zoom_; const QRectF plot=plotRect(this,oldX,oldY); if(!plot.contains(event->position())){event->ignore();return;} const QPointF pos=event->position(); const double anchorX=center_.x()+(pos.x()-plot.center().x())/plot.width()*oldX,anchorY=center_.y()-(pos.y()-plot.center().y())/plot.height()*oldY; zoom_=qBound(0.25,zoom_*std::pow(1.2,event->angleDelta().y()/120.0),20.0); const double newX=(xMaximum_-xMinimum_)/zoom_,newY=(yMaximum_-yMinimum_)/zoom_;center_.setX(anchorX-(pos.x()-plot.center().x())/plot.width()*newX);center_.setY(anchorY+(pos.y()-plot.center().y())/plot.height()*newY);cursor_=pos.toPoint();cursorInside_=true;update();event->accept(); }
void TrajectoryWidget::leaveEvent(QEvent*) { cursorInside_=false;dragging_=false;unsetCursor();update(); }
}  // namespace ch4::visualization
