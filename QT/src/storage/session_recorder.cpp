#include "storage/session_recorder.h"
#include <QDateTime>
#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
namespace ch4::storage {
SessionRecorder::SessionRecorder(QObject*p):QObject(p){}
bool SessionRecorder::start(const QString& mode){stop();const QString stamp=QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd_HHmmss_zzz"));directory_=QStringLiteral(CH4_PROJECT_ROOT "/Data/session_%1").arg(stamp);QDir().mkpath(directory_);
 QFile meta(directory_+QStringLiteral("/session.json"));if(meta.open(QIODevice::WriteOnly)){QJsonObject o{{"mode",mode},{"started",QDateTime::currentDateTime().toString(Qt::ISODateWithMs)},{"signal_label","relative methane signal / simulated concentration"},{"protocol_version",1}};meta.write(QJsonDocument(o).toJson());}
 pointsFile_.setFileName(directory_+QStringLiteral("/fused_points.csv"));eventsFile_.setFileName(directory_+QStringLiteral("/events.csv"));if(!pointsFile_.open(QIODevice::WriteOnly|QIODevice::Text)||!eventsFile_.open(QIODevice::WriteOnly|QIODevice::Text))return false;
 points_.setDevice(&pointsFile_);events_.setDevice(&eventsFile_);pendingRows_=0;points_<<"measurement_ticks,image_id,line_id,point_id,x_q13,y_q13,x_deg,y_deg,i1,q1,i2,q2,a1,a2,a2_over_a1,flags,config_revision\n";events_<<"pc_time,event\n";event(QStringLiteral("session_start"));return true;}
void SessionRecorder::append(const model::FusedPoint&p){if(!pointsFile_.isOpen())return;points_<<p.measurementTime<<','<<p.imageId<<','<<p.lineId<<','<<p.pointId<<','<<p.xAngleQ13<<','<<p.yAngleQ13<<','<<QString::number(p.xDegrees(),'f',6)<<','<<QString::number(p.yDegrees(),'f',6)<<','<<p.i1<<','<<p.q1<<','<<p.i2<<','<<p.q2<<','<<p.a1<<','<<p.a2<<','<<QString::number(p.ratio(),'g',12)<<','<<QString::number(p.flags,16)<<','<<p.configRevision<<'\n';if(++pendingRows_>=100){points_.flush();pendingRows_=0;}}
void SessionRecorder::event(const QString&t){if(eventsFile_.isOpen()){events_<<QDateTime::currentDateTime().toString(Qt::ISODateWithMs)<<','<<t<<'\n';events_.flush();}}
void SessionRecorder::stop(){if(pointsFile_.isOpen()){event(QStringLiteral("session_stop"));points_.flush();events_.flush();pointsFile_.close();eventsFile_.close();}pendingRows_=0;points_.setDevice(nullptr);events_.setDevice(nullptr);}
}  // namespace ch4::storage
