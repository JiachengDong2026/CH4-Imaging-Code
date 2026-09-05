#pragma once
#include "model/angle_sample.h"
#include "model/fused_point.h"
#include "model/harmonic_curve.h"
#include <QFile>
#include <QObject>
#include <QTextStream>
namespace ch4::storage {
class SessionRecorder final:public QObject{public:explicit SessionRecorder(QObject* parent=nullptr);bool start(const QString& rootDirectory,const QString& mode);void append(const model::FusedPoint& point);void append(const model::AngleSample& sample);void append(const model::HarmonicCurve& curve);void event(const QString& text);void stop();QString directory()const{return directory_;}
private:QString directory_;QFile pointsFile_,anglesFile_,harmonicsFile_,eventsFile_;QTextStream points_,angles_,harmonics_,events_;quint32 pendingRows_=0;};
}
