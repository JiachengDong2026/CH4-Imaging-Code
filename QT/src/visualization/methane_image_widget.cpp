#include "visualization/methane_image_widget.h"

#include <QMouseEvent>
#include <QPainter>
#include <QWheelEvent>

#include <cmath>

namespace ch4::visualization {
namespace {
QRectF plotRect(const QWidget* widget) { return QRectF(widget->rect()).adjusted(52, 24, -72, -42); }
}

MethaneImageWidget::MethaneImageWidget(QWidget* parent) : QWidget(parent), image_(128, 64) {
    setMinimumSize(560, 320);
    setMouseTracking(true);
}
bool MethaneImageWidget::add(const model::FusedPoint& point) { return image_.add(point); }
void MethaneImageWidget::clear() { image_.reset(); zoom_ = 1.0; center_ = {(xMin_ + xMax_) / 2.0, (yMin_ + yMax_) / 2.0}; update(); }
void MethaneImageWidget::configure(int width, int height, double xMin, double xMax, double yMin, double yMax) { image_.configure(width, height, xMin, xMax, yMin, yMax); xMin_ = xMin; xMax_ = xMax; yMin_ = yMin; yMax_ = yMax; zoom_ = 1.0; center_ = {(xMin_ + xMax_) / 2.0, (yMin_ + yMax_) / 2.0}; update(); }

void MethaneImageWidget::paintEvent(QPaintEvent*) {
    QPainter p(this); p.fillRect(rect(), Qt::white);
    const QRectF plot = plotRect(this); const double baseW = xMax_ - xMin_, baseH = yMax_ - yMin_; const double spanX = baseW / zoom_, spanY = baseH / zoom_;
    const double left = center_.x() - spanX / 2.0, bottom = center_.y() - spanY / 2.0;
    const double right = left + spanX, top = bottom + spanY;
    double maxValue = 0.0; for (int y = 0; y < image_.height(); ++y) for (int x = 0; x < image_.width(); ++x) maxValue = qMax(maxValue, image_.value(x, y)); if (maxValue <= 0.0) maxValue = 1.0;
    const double cw = plot.width() / image_.width() * zoom_, ch = plot.height() / image_.height() * zoom_;
    p.save(); p.setClipRect(plot);
    for (int y = 0; y < image_.height(); ++y) for (int x = 0; x < image_.width(); ++x) {
        if (!image_.count(x, y)) continue;
        const double cellX = xMin_ + (x + 0.5) / image_.width() * baseW, cellY = yMin_ + (y + 0.5) / image_.height() * baseH;
        if (cellX < left || cellX > right || cellY < bottom || cellY > top) continue;
        const double px = plot.left() + (cellX - left) / spanX * plot.width(), py = plot.bottom() - (cellY - bottom) / spanY * plot.height();
        const double t = qBound(0.0, image_.value(x, y) / maxValue, 1.0); p.fillRect(QRectF(px - cw / 2.0, py - ch / 2.0, cw + 0.5, ch + 0.5), QColor::fromHsvF((1.0 - t) * 0.66, 0.92, 0.95));
    }
    p.setPen(QColor("#e6eaf0")); for (int i = 1; i < 8; ++i) { const double f = i / 8.0; p.drawLine(QPointF(plot.left() + f * plot.width(), plot.top()), QPointF(plot.left() + f * plot.width(), plot.bottom())); p.drawLine(QPointF(plot.left(), plot.top() + f * plot.height()), QPointF(plot.right(), plot.top() + f * plot.height())); }
    p.restore(); p.setPen(QColor("#667085")); p.drawRect(plot);
    for(int i=0;i<=8;++i){const double f=i/8.0,px=plot.left()+f*plot.width(),py=plot.top()+f*plot.height();p.drawLine(QPointF(px,plot.bottom()),QPointF(px,plot.bottom()+4));p.drawText(QRectF(px-28,plot.bottom()+5,56,18),Qt::AlignHCenter|Qt::AlignTop,QString::number(left+f*spanX,'f',1));p.drawLine(QPointF(plot.left()-4,py),QPointF(plot.left(),py));p.drawText(QRectF(2,py-9,plot.left()-8,18),Qt::AlignRight|Qt::AlignVCenter,QString::number(top-f*spanY,'f',1));}
    p.drawText(QRectF(plot.left(), plot.bottom() + 22, plot.width(), 20), Qt::AlignHCenter, QStringLiteral("X angle (deg)")); p.save(); p.translate(16, plot.center().y()); p.rotate(-90); p.drawText(QRectF(-plot.height() / 2.0, -9, plot.height(), 18), Qt::AlignHCenter, QStringLiteral("Y angle (deg)")); p.restore(); p.drawText(QRectF(plot.right() + 8, plot.top(), 58, 40), Qt::AlignLeft, QStringLiteral("Relative\nsignal"));
    if (image_.validCellCount() == 0) { p.setPen(QColor("#98a2b3")); p.drawText(plot, Qt::AlignCenter, QStringLiteral("Waiting for methane image data")); }
    if (cursorInside_ && plot.contains(cursor_)) { const double x = left + (cursor_.x() - plot.left()) / plot.width() * spanX; const double y = top - (cursor_.y() - plot.top()) / plot.height() * spanY; const QString text = QStringLiteral("X %1°   Y %2°").arg(x, 0, 'f', 3).arg(y, 0, 'f', 3); QSizeF size=p.fontMetrics().size(Qt::TextSingleLine,text)+QSizeF(14,8); QPointF pos=QPointF(cursor_)+QPointF(14,14); if(pos.x()+size.width()>width()-4)pos.setX(cursor_.x()-size.width()-14); if(pos.y()+size.height()>height()-4)pos.setY(cursor_.y()-size.height()-14); const QRectF box(pos,size); p.setPen(QColor("#8795a1")); p.setBrush(QColor(255,255,255,235)); p.drawRoundedRect(box,3,3); p.setPen(QColor("#344054")); p.drawText(box, Qt::AlignCenter, text); }
}

void MethaneImageWidget::mousePressEvent(QMouseEvent* event) { if (event->button() == Qt::LeftButton && plotRect(this).contains(event->position())) { dragging_ = true; lastMouse_ = event->position().toPoint(); setCursor(Qt::ClosedHandCursor); } cursor_ = event->position().toPoint(); cursorInside_ = true; update(); }
void MethaneImageWidget::mouseMoveEvent(QMouseEvent* event) { const QPoint current = event->position().toPoint(); const QRectF plot = plotRect(this); if (dragging_) { const double spanX = (xMax_ - xMin_) / zoom_, spanY = (yMax_ - yMin_) / zoom_; center_.rx() -= (current.x() - lastMouse_.x()) / plot.width() * spanX; center_.ry() += (current.y() - lastMouse_.y()) / plot.height() * spanY; lastMouse_ = current; } cursor_ = current; cursorInside_ = plot.contains(current); update(); }
void MethaneImageWidget::mouseReleaseEvent(QMouseEvent* event) { if (event->button() == Qt::LeftButton) { dragging_ = false; unsetCursor(); } }
void MethaneImageWidget::wheelEvent(QWheelEvent* event) { const QRectF plot = plotRect(this); if (!plot.contains(event->position())) { event->ignore(); return; } const double oldX = (xMax_ - xMin_) / zoom_, oldY = (yMax_ - yMin_) / zoom_; const QPointF pos = event->position(); const double anchorX = center_.x() + (pos.x() - plot.center().x()) / plot.width() * oldX, anchorY = center_.y() - (pos.y() - plot.center().y()) / plot.height() * oldY; const double steps = event->angleDelta().y() / 120.0; zoom_ = qBound(0.25, zoom_ * std::pow(1.2, steps), 20.0); const double newX = (xMax_ - xMin_) / zoom_, newY = (yMax_ - yMin_) / zoom_; center_.setX(anchorX - (pos.x() - plot.center().x()) / plot.width() * newX); center_.setY(anchorY + (pos.y() - plot.center().y()) / plot.height() * newY); cursor_ = pos.toPoint(); cursorInside_ = true; update(); event->accept(); }
void MethaneImageWidget::leaveEvent(QEvent*) { cursorInside_ = false; dragging_ = false; unsetCursor(); update(); }
}  // namespace ch4::visualization
