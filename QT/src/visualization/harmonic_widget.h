#pragma once
#include <QVector>
#include <QWidget>
namespace ch4::visualization {
class HarmonicWidget final:public QWidget{public:explicit HarmonicWidget(QWidget* parent=nullptr);void append(double a1,double a2,double ratio);void appendRaw(quint32 sampleIndex,double a1,double a2);void appendBreak();void clear();
protected:void paintEvent(QPaintEvent*)override;private:QVector<double>a1_,a2_,ratio_;QVector<double>raw1_,raw2_,rawRatio_,pendingRaw1_,pendingRaw2_,pendingRawRatio_;QVector<bool>breaks_,rawValid_,pendingValid_;};
}
