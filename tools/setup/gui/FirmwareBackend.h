#pragma once
#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QCoreApplication>
#include <QProcessEnvironment>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUuid>
#include <QFile>
#include <QDir>
#include "FirmwareImages.h"
class FirmwareBackend : public QObject {
 Q_OBJECT
 Q_PROPERTY(bool busy READ busy NOTIFY changed)
 Q_PROPERTY(QVariantList choices READ choices NOTIFY choicesChanged)
 Q_PROPERTY(bool canPrepare READ canPrepare NOTIFY changed)
 Q_PROPERTY(bool canFlash READ canFlash NOTIFY changed)
 Q_PROPERTY(bool canConfirm READ canConfirm NOTIFY changed)
 Q_PROPERTY(bool imagesAvailable READ imagesAvailable CONSTANT)
 Q_PROPERTY(double progress READ progress NOTIFY changed)
 Q_PROPERTY(QString message READ message NOTIFY changed)
 Q_PROPERTY(QString receiptLabel READ receiptLabel NOTIFY changed)
 QProcess process;QTimer timeout;QByteArray bytes,lineBuffer;QJsonObject finalResult,receipt;
 QVariantList adapters;QString text,checkedGuid,checkedProfile,operation,action;
 bool invalid=false,mutation=false,eligible=false,restoreAfterStop=false;double fraction=0;
 QString stateRoot() const{return QDir(qEnvironmentVariable("ProgramData")).filePath("SchoolbellNetworkHelper-v1");}
 void loadReceipt(){
  QFile f(QDir(stateRoot()).filePath("flash-session.json"));receipt={};
  if(f.exists()){
   if(!f.open(QIODevice::ReadOnly) || f.size()>8192){receipt.insert("possible_write",true);return;}
   receipt=QJsonDocument::fromJson(f.readAll()).object();
   if(receipt.value("schema").toInt()!=1)receipt.insert("possible_write",true);
  }
 }
 bool retryable()const{return receipt.value("phase").toString()=="unknown" && !receipt.value("transfer_complete").toBool() && !QFile::exists(QDir(stateRoot()).filePath("network.json"));}
 bool pending()const{return receipt.value("possible_write").toBool() && receipt.value("phase").toString()!="user-confirmed";}
 void event(const QJsonObject &e){
  if(e.value("schema").toInt()!=1 || e.value("operation").toString()!=operation || e.value("profile").toString()!=checkedProfile)return;
  const auto phase=e.value("phase").toString();int count=e.value("acknowledged").toInt(-1);
  if(count<0 || count>0x7c0000)return;
  if(phase=="preparing")text="Проверяются образ и выделенное подключение…";
  else if(phase=="ready")text="READY · Сервер готов. Отключите питание нужного роутера, зажмите Reset и подайте питание. Отпустите Reset после начала передачи. Ожидание — до 10 минут.";
  else if(phase=="transferring"){fraction=double(count)/0x7c0000;text=QString("Передача: %1 %. Отпустите Reset. Не отключайте питание.").arg(int(fraction*100));}
  else if(phase=="transferred" || phase=="boot-wait"){const bool complete=e.value("transfer_complete").toBool();fraction=double(count)/0x7c0000;text=complete?"Файл передан. Ожидается запись и загрузка (не менее 90 секунд). Питание не отключайте. Успех прошивки ещё не подтверждён.":"Передача прервана. Ожидается завершение работы роутера (90 секунд), затем мастер восстановит сеть. Питание пока не отключайте.";}
  else if(phase=="restoring")text="Восстанавливается сеть компьютера. Ожидается DHCP от роутера; это может занять несколько минут.";
  else if(phase=="needs-check")text="Передача завершена, сеть восстановлена. Откройте интерфейс роутера и проверьте версию.";
  else if(phase=="not-started")text="Передача не начиналась. Сервер остановлен. Проверьте результат восстановления сети.";
  else if(phase=="unknown" || phase=="recovery-required")text="Результат не подтверждён. Не повторяйте прошивку: восстановите сеть и проверьте загрузку роутера.";
  else return;
  emit changed();
 }
 void startHelper(const QString &what){
  auto base=QCoreApplication::applicationDirPath();auto env=QProcessEnvironment::systemEnvironment();env.insert("PYTHONIOENCODING","utf-8");process.setProcessEnvironment(env);
  action=what;mutation=true;eligible=false;invalid=false;bytes.clear();lineBuffer.clear();finalResult={};timeout.stop();fraction=0;
  text="Подтвердите запрос Windows. Дождитесь завершения помощника.";
  QStringList args={base+"/network_elevate.py",what};
  if(what=="prepare" || what=="flash")args<<"--guid"<<checkedGuid<<"--profile"<<checkedProfile;
  if(what=="flash"){operation=QUuid::createUuid().toString(QUuid::WithoutBraces);args<<"--operation"<<operation;}
  if(what=="confirm")args<<"--operation"<<receipt.value("operation").toString()<<"--profile"<<receipt.value("profile").toString();
  process.start(base+"/python/python.exe",args);emit changed();
 }
public:
 FirmwareBackend(QObject *parent=nullptr):QObject(parent){
  loadReceipt();if(pending())text="Сохранён результат прежней передачи. Восстановите сеть при необходимости и проверьте загрузку до нового запуска.";
  timeout.setSingleShot(true);timeout.setInterval(45000);
  connect(&timeout,&QTimer::timeout,this,[this]{if(!mutation){invalid=true;process.kill();}});
  connect(&process,&QProcess::readyReadStandardOutput,this,[this]{
   auto b=process.readAllStandardOutput();
   if(!mutation){bytes+=b;if(bytes.size()>1024*1024){invalid=true;process.kill();}return;}
   lineBuffer+=b;if(lineBuffer.size()>65536){invalid=true;lineBuffer.clear();return;}
   int nl;while((nl=lineBuffer.indexOf('\n'))>=0){auto o=QJsonDocument::fromJson(lineBuffer.left(nl)).object();lineBuffer.remove(0,nl+1);if(o.contains("flash_event"))event(o.value("flash_event").toObject());else if(o.contains("helper_result"))finalResult=o;else invalid=true;}
  });
  connect(&process,&QProcess::errorOccurred,this,[this](QProcess::ProcessError e){if(e==QProcess::FailedToStart){timeout.stop();eligible=false;text="Не удалось запустить помощник.";loadReceipt();emit changed();}});
  connect(&process,qOverload<int,QProcess::ExitStatus>(&QProcess::finished),this,[this](int code,QProcess::ExitStatus status){
   timeout.stop();
   if(mutation){
    eligible=false;auto result=finalResult.value("helper_result").toString();
    const bool accepted=!invalid && status==QProcess::NormalExit && ((code==0 && (result=="ok" || result=="cancelled")) || (code==1 && (result=="busy" || result=="failed")));
    text=accepted?finalResult.value("message").toString():QString("Результат помощника неизвестен. Проверьте восстановление сети.");
    mutation=false;loadReceipt();if(restoreAfterStop){restoreAfterStop=false;startHelper("restore");return;}if(retryable())text="Передача прервана, сеть восстановлена. Проверьте подключение и нажмите кнопку прошивки для новой попытки. Предыдущая попытка не считается успешной.";else if(pending())text+=" Не запускайте повторную передачу до проверки версии роутера.";emit changed();return;
   }
   auto o=QJsonDocument::fromJson(bytes).object();
   if(!invalid && code==0 && status==QProcess::NormalExit && o.value("choices").isArray() && o.value("message").isString()) {adapters=o.value("choices").toArray().toVariantList();text=o.value("message").toString();eligible=o.value("plan").toObject().value("eligible").toBool(false);emit choicesChanged();}
   else {eligible=false;adapters.clear();emit choicesChanged();text="Не удалось прочитать настройки сети. Повторите проверку. Эта проверка настройки не меняет.";}
   loadReceipt();emit changed();
  });
 }
 bool imagesAvailable()const{return FirmwareImages::available();}
 bool canPrepare()const{return eligible && !busy();}
 bool canFlash()const{return canPrepare() && imagesAvailable() && (!pending() || retryable());}
 bool canConfirm()const{return !busy() && pending() && !QFile::exists(QDir(stateRoot()).filePath("network.json")) && !receipt.value("operation").toString().isEmpty();}
 bool busy()const{return process.state()!=QProcess::NotRunning;}
 QVariantList choices()const{return adapters;}
 QString message()const{return text;}
 double progress()const{return fraction;}
 QString receiptLabel()const{return receipt.value("profile").toString()=="factory"?"TP-Link EU v3.30 · 1.8.0 Build250625 Rel.56805n":"OpenWrt 19.07.9 · TP-Link TL-MR3020 v3";}
 Q_INVOKABLE void clearResult(){if(!busy()){text.clear();eligible=false;loadReceipt();if(pending())text="Прежняя передача требует проверки результата перед новым запуском.";emit changed();}}
 Q_INVOKABLE void inspect(QString guid="",QString profile="openwrt",bool confirmed=false){
  if(busy() || (profile!="openwrt" && profile!="factory") || (!guid.isEmpty() && !confirmed))return;
  auto base=QCoreApplication::applicationDirPath();auto env=QProcessEnvironment::systemEnvironment();env.insert("PYTHONIOENCODING","utf-8");process.setProcessEnvironment(env);
  mutation=false;eligible=false;checkedGuid=guid;checkedProfile=profile;bytes.clear();invalid=false;text="Читаются настройки сети компьютера…";
  QStringList args={base+"/network_worker.py","--profile",profile};if(!guid.isEmpty())args<<"--guid"<<guid<<"--model"<<"MR3020 EU V3.30";
  process.start(base+"/python/python.exe",args);timeout.start();emit changed();
 }
 Q_INVOKABLE void requestStop(){
  if(!busy())return;
  if(!mutation){invalid=true;eligible=false;process.kill();text="Проверка остановлена.";emit changed();return;}
  if(action=="flash"){
   QFile request(QCoreApplication::applicationDirPath()+"/flash-stop-"+operation+".request");
   if(!request.open(QIODevice::WriteOnly)){text="Не удалось передать остановку. Дождитесь окончания операции; питание не отключайте.";emit changed();return;}
   request.write("stop\n");request.close();
   text="Остановка запрошена. Передача прекратится; после возможной записи мастер дождётся загрузки и восстановит сеть. Питание не отключайте.";
  }else if(action=="prepare") {restoreAfterStop=true;text="Остановка запрошена. После текущего сетевого шага мастер восстановит DHCP.";}
  else text="Завершается восстановление/подтверждение. Этот короткий шаг нужно закончить; новая передача не запускается.";
  emit changed();
 }
 Q_INVOKABLE void changeNetwork(bool restore=false){if(!busy() && (restore || canPrepare()))startHelper(restore?"restore":"prepare");}
 Q_INVOKABLE void flash(){if(canFlash())startHelper("flash");}
 Q_INVOKABLE void confirmResult(){if(canConfirm())startHelper("confirm");}
 signals:void changed();void choicesChanged();
};
