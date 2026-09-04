#include "device/native_serial.h"
#ifdef Q_OS_WIN
#include <windows.h>
#endif
#include <algorithm>
namespace ch4::device {
NativeSerial::NativeSerial(QObject*p):QObject(p){poll_.setTimerType(Qt::PreciseTimer);poll_.setInterval(1);connect(&poll_,&QTimer::timeout,this,&NativeSerial::poll);}
NativeSerial::~NativeSerial(){close();}
bool NativeSerial::isOpen()const{
#ifdef Q_OS_WIN
 return handle_&&handle_!=INVALID_HANDLE_VALUE;
#else
 return false;
#endif
}
QStringList NativeSerial::availablePorts(){QStringList out;
#ifdef Q_OS_WIN
 wchar_t target[512];for(int i=1;i<=256;++i){const QString name=QStringLiteral("COM%1").arg(i);if(QueryDosDeviceW(reinterpret_cast<LPCWSTR>(name.utf16()),target,512))out<<name;}
#endif
 return out;}
bool NativeSerial::open(const QString&name,int baud){close();
#ifdef Q_OS_WIN
 const QString path=QStringLiteral("\\\\.\\")+name;HANDLE h=CreateFileW(reinterpret_cast<LPCWSTR>(path.utf16()),GENERIC_READ|GENERIC_WRITE,0,nullptr,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,nullptr);if(h==INVALID_HANDLE_VALUE){emit errorOccurred(QStringLiteral("无法打开 %1（错误 %2）").arg(name).arg(GetLastError()));return false;}
 DCB d{};d.DCBlength=sizeof(d);GetCommState(h,&d);d.BaudRate=DWORD(baud);d.ByteSize=8;d.Parity=NOPARITY;d.StopBits=ONESTOPBIT;d.fBinary=TRUE;d.fDtrControl=DTR_CONTROL_DISABLE;d.fRtsControl=RTS_CONTROL_DISABLE;if(!SetCommState(h,&d)){CloseHandle(h);emit errorOccurred(QStringLiteral("串口参数设置失败"));return false;}
 COMMTIMEOUTS t{};t.ReadIntervalTimeout=MAXDWORD;t.ReadTotalTimeoutMultiplier=0;t.ReadTotalTimeoutConstant=0;SetCommTimeouts(h,&t);SetupComm(h,1<<20,1<<20);PurgeComm(h,PURGE_RXCLEAR|PURGE_TXCLEAR);handle_=h;poll_.start();return true;
#else
 Q_UNUSED(name);Q_UNUSED(baud);emit errorOccurred(QStringLiteral("当前平台尚未实现原生串口"));return false;
#endif
}
void NativeSerial::close(){poll_.stop();
#ifdef Q_OS_WIN
 if(isOpen()){CloseHandle(static_cast<HANDLE>(handle_));handle_=nullptr;}
#endif
}
void NativeSerial::writeBytes(const QByteArray&bytes){
#ifdef Q_OS_WIN
 if(!isOpen())return;
 DWORD done=0;
 if(!WriteFile(static_cast<HANDLE>(handle_),bytes.constData(),DWORD(bytes.size()),&done,nullptr))
  emit errorOccurred(QStringLiteral("串口写失败（%1）").arg(GetLastError()));
 else if(done!=DWORD(bytes.size()))
  emit errorOccurred(QStringLiteral("串口发送不完整"));
#else
 Q_UNUSED(bytes);
#endif
}
void NativeSerial::poll(){
#ifdef Q_OS_WIN
 if(!isOpen())return;
 COMSTAT status{};DWORD errors=0;
 if(!ClearCommError(static_cast<HANDLE>(handle_),&errors,&status)){emit errorOccurred(QStringLiteral("串口状态读取失败"));close();return;}
 while(status.cbInQue){QByteArray bytes(int(std::min<DWORD>(status.cbInQue,65536)),Qt::Uninitialized);DWORD got=0;if(!ReadFile(static_cast<HANDLE>(handle_),bytes.data(),DWORD(bytes.size()),&got,nullptr)||!got)break;bytes.resize(int(got));emit bytesReceived(bytes);if(!ClearCommError(static_cast<HANDLE>(handle_),&errors,&status)){emit errorOccurred(QStringLiteral("串口状态读取失败"));close();return;}}
#endif
}
}  // namespace ch4::device
