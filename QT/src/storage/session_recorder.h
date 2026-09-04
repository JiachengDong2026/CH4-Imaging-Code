#pragma once
#include "model/fused_point.h"
#include <QFile>
#include <QObject>
#include <QTextStream>
namespace ch4::storage {
class SessionRecorder final:public QObject{public:explicit SessionRecorder(QObject* parent=nullptr);bool start(const QString& mode);void append(const model::FusedPoint& point);void event(const QString& text);void stop();QString directory()const{return directory_;}
private:QString directory_;QFile pointsFile_,eventsFile_;QTextStream points_,events_;quint32 pendingRows_=0;};
}
