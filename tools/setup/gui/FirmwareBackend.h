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
 Q_PROPERTY(QVariantList choices READ choices NOTIFY choicesChanged)
 Q_PROPERTY(bool canPrepare READ canPrepare NOTIFY changed)
 Q_PROPERTY(QString message READ message NOTIFY changed)
 QProcess process; QTimer timeout; QByteArray bytes; QVariantList adapters; QString text; bool invalid=false; bool mutation=false; bool eligible=false; QString checkedGuid,checkedProfile;
public:
 FirmwareBackend(QObject *parent=nullptr):QObject(parent) {
  timeout.setSingleShot(true);timeout.setInterval(45000);
  connect(&timeout,&QTimer::timeout,this,[this]{if(!mutation){invalid=true;process.kill();}});
  connect(&process,&QProcess::readyReadStandardOutput,this,[this]{bytes+=process.readAllStandardOutput();if(bytes.size()>1024*1024){invalid=true;bytes.truncate(1024*1024);if(!mutation)process.kill();}});
  connect(&process,&QProcess::errorOccurred,this,[this](QProcess::ProcessError e){if(e==QProcess::FailedToStart){timeout.stop();text="Не удалось запустить проверку сети.";emit changed();}});
  connect(&process,qOverload<int,QProcess::ExitStatus>(&QProcess::finished),this,[this](int code,QProcess::ExitStatus status){
   timeout.stop();auto o=QJsonDocument::fromJson(bytes).object();
   if(mutation){
    eligible=false;auto result=o.value("helper_result").toString();
    const bool accepted=!invalid && status==QProcess::NormalExit && ((code==0 && (result=="ok" || result=="cancelled")) || (code==1 && (result=="busy" || result=="failed")));
    text=accepted?o.value("message").toString():QString("Результат помощника неизвестен. Проверьте восстановление сети.");mutation=false;emit changed();return;
   }
   if(!invalid && code==0 && status==QProcess::NormalExit && o.value("choices").isArray() && o.value("message").isString()) {adapters=o.value("choices").toArray().toVariantList();text=o.value("message").toString();eligible=o.value("plan").toObject().value("eligible").toBool(false);emit choicesChanged();}
   else {eligible=false;adapters.clear();emit choicesChanged();text="Не удалось прочитать настройки сети. Повторите проверку. Эта проверка настройки не меняет.";}
   emit changed();
  });
 }
 bool canPrepare() const{return eligible && !busy();}
 bool busy() const{return process.state()!=QProcess::NotRunning;}
 QVariantList choices() const{return adapters;}
 QString message() const{return text;}
 Q_INVOKABLE void clearResult(){if(!busy()){text.clear();eligible=false;emit changed();}}
 Q_INVOKABLE void inspect(QString guid="",QString profile="openwrt",bool confirmed=false){
  if(busy() || (profile!="openwrt" && profile!="factory") || (!guid.isEmpty() && !confirmed))return;
  auto base=QCoreApplication::applicationDirPath();
  auto env=QProcessEnvironment::systemEnvironment();env.insert("PYTHONIOENCODING","utf-8");process.setProcessEnvironment(env);
  mutation=false;eligible=false;checkedGuid=guid;checkedProfile=profile;bytes.clear();invalid=false;text="Читаются настройки сети компьютера…";
  QStringList args={base+"/network_worker.py","--profile",profile};
  if(!guid.isEmpty())args<<"--guid"<<guid<<"--model"<<"MR3020 EU V3.30";
  process.start(base+"/python/python.exe",args);timeout.start();emit changed();
 }
 Q_INVOKABLE void changeNetwork(bool restore=false){
  if(busy() || (!restore && !canPrepare()))return;
  auto base=QCoreApplication::applicationDirPath();auto env=QProcessEnvironment::systemEnvironment();env.insert("PYTHONIOENCODING","utf-8");process.setProcessEnvironment(env);
  mutation=true;eligible=false;invalid=false;bytes.clear();timeout.stop();
  text="Подтвердите запрос Windows. Дождитесь завершения помощника.";
  QStringList args={base+"/network_elevate.py",restore?"restore":"prepare"};
  if(!restore)args<<"--guid"<<checkedGuid<<"--profile"<<checkedProfile;
  process.start(base+"/python/python.exe",args);emit changed();
 }
 signals:void changed();void choicesChanged();
};
