#include "visualization/harmonic_widget.h"
#include <algorithm>
#include <cmath>
#include <QPainter>
#include <QPainterPath>
namespace ch4::visualization {
namespace {
struct AxisRange {
    double minimum = 0.0;
    double maximum = 1.0;
};

AxisRange automaticRange(const QVector<double>& values) {
    double maximum = 0.0;
    for (const double value : values) {
        if (std::isfinite(value))
            maximum = qMax(maximum, value);
    }

    if (maximum <= 0.0)
        return {};

    return {0.0, maximum * 1.08};
}
}
HarmonicWidget::HarmonicWidget(QWidget* p):QWidget(p){setMinimumSize(500,280);}
void HarmonicWidget::append(double a1,double a2,double r){a1_.append(a1);a2_.append(a2);ratio_.append(r);breaks_.append(false);while(a1_.size()>600){a1_.removeFirst();a2_.removeFirst();ratio_.removeFirst();breaks_.removeFirst();}}
void HarmonicWidget::appendRaw(quint32 sampleIndex,double a1,double a2){constexpr int curvePoints=100;if(sampleIndex>=curvePoints)return;if(raw1_.size()!=curvePoints){raw1_.fill(0.0,curvePoints);raw2_.fill(0.0,curvePoints);rawRatio_.fill(0.0,curvePoints);rawValid_.fill(false,curvePoints);pendingRaw1_.fill(0.0,curvePoints);pendingRaw2_.fill(0.0,curvePoints);pendingRawRatio_.fill(0.0,curvePoints);pendingValid_.fill(false,curvePoints);}if(sampleIndex==0){bool complete=true;for(const bool valid:pendingValid_)complete=complete&&valid;if(complete){QVector<double> references;for(int index=0;index<curvePoints;++index)if(pendingValid_[index]&&std::isfinite(pendingRaw1_[index])&&pendingRaw1_[index]>1e-12)references.append(pendingRaw1_[index]);if(!references.isEmpty()){std::sort(references.begin(),references.end());const int middle=references.size()/2;const double reference=references.size()%2?references[middle]:(references[middle-1]+references[middle])*0.5;for(int index=0;index<curvePoints;++index)pendingRawRatio_[index]=pendingValid_[index]?pendingRaw2_[index]/reference:0.0;}raw1_=pendingRaw1_;raw2_=pendingRaw2_;rawRatio_=pendingRawRatio_;rawValid_=pendingValid_;}pendingValid_.fill(false);}pendingRaw1_[int(sampleIndex)]=qMax(0.0,a1);pendingRaw2_[int(sampleIndex)]=qMax(0.0,a2);pendingValid_[int(sampleIndex)]=true;}
void HarmonicWidget::appendBreak(){if(!breaks_.isEmpty())breaks_.last()=true;}
void HarmonicWidget::clear(){a1_.clear();a2_.clear();ratio_.clear();raw1_.clear();raw2_.clear();rawRatio_.clear();pendingRaw1_.clear();pendingRaw2_.clear();pendingRawRatio_.clear();breaks_.clear();rawValid_.clear();pendingValid_.clear();update();}
void HarmonicWidget::paintEvent(QPaintEvent*){QPainter p(this);p.setRenderHint(QPainter::Antialiasing);p.fillRect(rect(),Qt::white);const double left=96.0,right=20.0,topMargin=34.0,bottomMargin=42.0,gap=34.0;const double plotHeight=qMax(40.0,(height()-topMargin-bottomMargin-gap)/2.0);const QRectF top(left,topMargin,qMax(40.0,width()-left-right),plotHeight);const QRectF bottom(left,top.bottom()+gap,top.width(),plotHeight);
 auto drawGrid=[&](const QRectF&r){p.save();p.setClipRect(r);p.setPen(QColor("#e6eaf0"));for(int i=1;i<8;++i){const double x=r.left()+i*r.width()/8.0;p.drawLine(QPointF(x,r.top()),QPointF(x,r.bottom()));}for(int i=1;i<5;++i){const double y=r.top()+i*r.height()/5.0;p.drawLine(QPointF(r.left(),y),QPointF(r.right(),y));}p.restore();p.setPen(QColor("#667085"));p.setBrush(Qt::NoBrush);p.drawRect(r);};
 auto draw=[&](const QVector<double>&v,const QVector<bool>&breaks,const QVector<bool>&present,const QRectF&r,QColor c,const AxisRange&range){if(v.size()<2)return;const double span=qMax(1e-12,range.maximum-range.minimum);QPainterPath path;bool hasPoint=false;for(int i=0;i<v.size();++i){if(!present.value(i,false)){hasPoint=false;continue;}const double normalized=qBound(0.0,(v[i]-range.minimum)/span,1.0);QPointF q(r.left()+i*r.width()/qMax(1,v.size()-1),r.bottom()-normalized*r.height());if(hasPoint&&i&&!breaks.value(i-1,false))path.lineTo(q);else path.moveTo(q);hasPoint=true;}p.setPen(QPen(c,1.4));p.drawPath(path);};
 auto drawYAxis=[&](const QRectF&r,const AxisRange&range){p.setPen(QColor("#667085"));for(int i=0;i<=5;++i){const double fraction=i/5.0;const double y=r.bottom()-fraction*r.height();p.drawLine(QPointF(r.left()-4,y),QPointF(r.left(),y));p.drawText(QRectF(0,y-9,left-8,18),Qt::AlignRight|Qt::AlignVCenter,QString::number(range.minimum+fraction*(range.maximum-range.minimum),'g',4));}};
  drawGrid(top);drawGrid(bottom);const bool hasRaw=!raw1_.isEmpty();const auto& top1=hasRaw?raw1_:a1_;const auto& top2=hasRaw?raw2_:a2_;const auto& bottomSeries=hasRaw?rawRatio_:ratio_;const QVector<bool> activeBreaks=hasRaw?QVector<bool>(top1.size(),false):breaks_;const QVector<bool> activePresent=hasRaw?rawValid_:QVector<bool>(top1.size(),true);QVector<double> topValues=top1;topValues += top2;const AxisRange topRange=automaticRange(topValues);const AxisRange bottomRange=automaticRange(bottomSeries);draw(top1,activeBreaks,activePresent,top,QColor("#1976d2"),topRange);draw(top2,activeBreaks,activePresent,top,QColor("#ef6c00"),topRange);draw(bottomSeries,activeBreaks,activePresent,bottom,QColor("#2e7d32"),bottomRange);drawYAxis(top,topRange);drawYAxis(bottom,bottomRange);p.setPen(QColor("#344054"));p.drawText(left,18,QStringLiteral("1f and 2f amplitudes"));p.drawText(left,bottom.top()-10,QStringLiteral("Normalized 2f (1f median reference)"));p.drawText(QRectF(bottom.left(),bottom.bottom()+8,bottom.width(),20),Qt::AlignHCenter,QStringLiteral("Sample"));p.save();p.translate(16,top.center().y());p.rotate(-90);p.drawText(QRectF(-top.height()/2.0,-9,top.height(),18),Qt::AlignHCenter,QStringLiteral("Amplitude"));p.restore();p.save();p.translate(16,bottom.center().y());p.rotate(-90);p.drawText(QRectF(-bottom.height()/2.0,-9,bottom.height(),18),Qt::AlignHCenter,QStringLiteral("Ratio"));p.restore();if(top1.isEmpty()){p.setPen(QColor("#98a2b3"));p.drawText(QRectF(top.left(),top.top(),top.width(),bottom.bottom()-top.top()),Qt::AlignCenter,QStringLiteral("Waiting for harmonic data"));}}
}
