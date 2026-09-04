#pragma once
#include <QObject>
#include <QByteArray>
#include <QTimer>
#include <QStringList>
namespace ch4::device {
class NativeSerial final : public QObject {
    Q_OBJECT
public:
    explicit NativeSerial(QObject* parent = nullptr);
    ~NativeSerial() override;
    static QStringList availablePorts();
    bool open(const QString& name, int baud);
    void close();
    bool isOpen() const;
public slots:
    void writeBytes(const QByteArray& bytes);
signals:
    void bytesReceived(QByteArray bytes);
    void errorOccurred(QString message);
private slots:
    void poll();
private:
    void* handle_ = nullptr;
    QTimer poll_;
};
}
