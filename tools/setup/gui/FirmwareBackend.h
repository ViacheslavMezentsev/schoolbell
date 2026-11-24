#pragma once
#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QCoreApplication>
#include <QProcessEnvironment>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
class FirmwareBackend : public QObject {
 Q_OBJECT
 Q_PROPERTY(bool busy READ busy NOTIFY changed)
 Q_PROPERTY(QVariantList choices READ choices NOTIFY changed)
 Q_PROPERTY(QString message READ message NOTIFY changed)
 QProcess process; QTimer timeout; QByteArray bytes; QVariantList adapters; QString text; bool invalid=false;
public:
 FirmwareBackend(QObject *parent=nullptr):QObject(parent) {
  timeout.setSingleShot(true);timeout.setInterval(45000);
  connect(&timeout,&QTimer::timeout,this,[this]{invalid=true;process.kill();});
  connect(&process,&QProcess::readyReadStandardOutput,this,[this]{bytes+=process.readAllStandardOutput();if(bytes.size()>1024*1024){invalid=true;process.kill();}});
  connect(&process,&QProcess::errorOccurred,this,[this](QProcess::ProcessError e){if(e==QProcess::FailedToStart){timeout.stop();text="Не удалось запустить проверку сети.";emit changed();}});
  connect(&process,qOverload<int,QProcess::ExitStatus>(&QProcess::finished),this,[this](int code,QProcess::ExitStatus status){
   timeout.stop();auto o=QJsonDocument::fromJson(bytes).object();
   if(!invalid && code==0 && status==QProcess::NormalExit && o.value("choices").isArray() && o.value("message").isString()) {adapters=o.value("choices").toArray().toVariantList();text=o.value("message").toString();}
   else {adapters.clear();text="Не удалось прочитать настройки сети. Повторите проверку. Сеть не изменялась.";}
   emit changed();
  });
 }
 bool busy() const{return process.state()!=QProcess::NotRunning;}
 QVariantList choices() const{return adapters;}
 QString message() const{return text;}
 Q_INVOKABLE void clearResult(){if(!busy()){text.clear();emit changed();}}
 Q_INVOKABLE void inspect(QString guid="",QString profile="openwrt",bool confirmed=false){
  if(busy() || (profile!="openwrt" && profile!="factory") || (!guid.isEmpty() && !confirmed))return;
  auto base=QCoreApplication::applicationDirPath();
  auto env=QProcessEnvironment::systemEnvironment();env.insert("PYTHONIOENCODING","utf-8");process.setProcessEnvironment(env);
  bytes.clear();invalid=false;text="Читаются настройки сети компьютера…";
  QStringList args={base+"/network_worker.py","--profile",profile};
  if(!guid.isEmpty())args<<"--guid"<<guid<<"--model"<<"MR3020 EU V3.30";
  process.start(base+"/python/python.exe",args);timeout.start();emit changed();
 }
 signals:void changed();
};
