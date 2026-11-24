#pragma once
#include <QObject>
#include "SessionProof.h"
#include "OperationStatus.h"
#include <QTimer>
#include <QProcess>
#include <QDir>
#include <QStandardPaths>
#include <QDateTime>
#include <QCoreApplication>
#include <QFile>
#include <QFileInfo>
#include <QSettings>
#include <QLocalServer>
#include <QLocalSocket>
#include <QUuid>
#include <QDesktopServices>
#include <QUrl>
#include <QNetworkInterface>
#include <QHostAddress>
#include <QVariantList>
#include <QJsonDocument>
#include <QJsonObject>
#include <QGuiApplication>
#include <QClipboard>
#ifdef Q_OS_WIN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <iphlpapi.h>
#include <netioapi.h>
#endif
class Backend : public QObject {
 Q_OBJECT
 Q_PROPERTY(bool interrupted READ interrupted NOTIFY changed)
 Q_PROPERTY(bool canCancel READ canCancel NOTIFY changed)
 Q_PROPERTY(QString operationMessage READ operationMessage NOTIFY changed)
 Q_PROPERTY(QString sourceIP READ sourceIP NOTIFY changed)
 Q_PROPERTY(int adapterIndex READ adapterIndex NOTIFY changed)
 Q_PROPERTY(bool busy READ busy NOTIFY changed)
 Q_PROPERTY(QString stage READ stage NOTIFY changed)
 Q_PROPERTY(QString report READ report NOTIFY changed)
 Q_PROPERTY(QString session READ session NOTIFY changed)
 Q_PROPERTY(bool fresh READ fresh NOTIFY changed)
 Q_PROPERTY(QVariantList connections READ connections NOTIFY changed)
 Q_PROPERTY(QVariantList bundleChoices READ bundleChoices NOTIFY changed)
 Q_PROPERTY(QString bundlePath READ bundlePath NOTIFY changed)
 Q_PROPERTY(QString bundleVersion READ bundleVersion NOTIFY changed)
 Q_PROPERTY(bool zipMode READ zipMode NOTIFY changed)
 Q_PROPERTY(bool bundleReady READ bundleReady NOTIFY changed)
 Q_PROPERTY(bool bundleLocked READ bundleLocked NOTIFY changed)
 QVariantList bundles;
 QString zipFile,zipVersion;
 bool zipReady=false;
 QVariantList choices;
 QProcess process;
 QLocalServer passwordServer;
 QString password;
 QString state="idle", output, folder;
 QString activeOperation,activeAction,sessionToken,eventFile,eventPhase;
 QJsonObject lastEvent;
 QTimer eventTimer;
 bool cancelRequested=false,protocolInvalid=false;

 QString source; int index=0;
public:
 Backend(QObject *parent=nullptr):QObject(parent) {
  QSettings settings;source=settings.value("Device/source").toString();index=settings.value("Device/index",1).toInt();
  auto args=QCoreApplication::arguments();int pos=args.indexOf("--source");if(pos>=0 && pos+1<args.size())source=args[pos+1];pos=args.indexOf("--adapter");if(pos>=0 && pos+1<args.size())index=args[pos+1].toInt();
  passwordServer.setSocketOptions(QLocalServer::UserAccessOption);
  connect(&passwordServer,&QLocalServer::newConnection,this,[this]{
   while(auto socket=passwordServer.nextPendingConnection()) {
    if(busy() && !password.isEmpty()) socket->write(password.toUtf8()+"\n");
    socket->disconnectFromServer();connect(socket,&QLocalSocket::disconnected,socket,&QObject::deleteLater);
   }
  });
  folder=QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation)+"/package-session";
  QDir().mkpath(folder);
  auto selection=readObject(folder+"/zip-selection.json");
  zipFile=selection.value("path").toString();zipVersion=selection.value("version").toString();
  auto binding=readObject(folder+"/zip-binding.json");
  if(!binding.isEmpty()){source=binding.value("source").toString();index=binding.value("index").toInt();}
  if(writeStarted()) {
   state=QFile::exists(folder+"/write-started")?"uncertain":SessionProof::restored(folder+"/zip-session");
   if(state=="done")output="Сохранённый результат: установка проверена в предыдущем сеансе. Текущее состояние роутера не запрашивалось.\n";
   else if(state=="not-applied")output="Сохранённый результат: установка не выполнена, исходное состояние подтверждено.\n";
  }
  else if(QFile::exists(folder+"/zip-session/session.json") || QFile::exists(folder+"/prepared.json")) state="ready";
  else if(bundleLocked())state="error";
  zipReady=bundleLocked();
  refreshBundles();
  eventTimer.setInterval(200);
  connect(&eventTimer,&QTimer::timeout,this,[this]{readEvent();emit changed();});
  process.setProcessChannelMode(QProcess::MergedChannels);
  connect(&process,&QProcess::readyReadStandardOutput,this,[this]{ auto bytes=process.readAllStandardOutput();output+=QString::fromUtf8(bytes);QFile log(folder+"/operation.log");if(log.open(QIODevice::Append))log.write(bytes);emit changed(); });
  connect(&process,&QProcess::errorOccurred,this,[this](QProcess::ProcessError error){ if(error==QProcess::FailedToStart){eventTimer.stop();password.fill(QChar(0));password.clear();passwordServer.close();state=writeStarted()?"uncertain":"error";zipReady=false;output+="\nCannot start packaged worker: "+process.errorString();emit changed();} });
  connect(&process,qOverload<int,QProcess::ExitStatus>(&QProcess::finished),this,[this](int code,QProcess::ExitStatus status){
   eventTimer.stop();readEvent(true);
   password.fill(QChar(0));password.clear();passwordServer.close();
   auto result=lastEvent.value("value").toString();
   if(!protocolInvalid && code==0 && status==QProcess::NormalExit && lastEvent.value("kind").toString()=="completed") {
    if(activeAction=="new-session") {state="idle";source.clear();index=0;zipFile.clear();zipVersion.clear();zipReady=false;refreshBundles();emit sessionReset();}
    else if(activeAction=="inspect-zip") {auto selected=readObject(folder+"/zip-selection.json");zipVersion=selected.value("version").toString();zipReady=!zipVersion.isEmpty() && sameFile(selected.value("path").toString(),zipFile);state=zipReady?"idle":"error";if(!zipReady)output+="\nZIP receipt does not match the selected file. Select the archive again.";}
    else state=result;
   } else {
    if(activeAction=="inspect-zip")zipReady=false;
    state=writeStarted()?"uncertain":"error";
    if(!protocolInvalid && code==2 && lastEvent.value("kind").toString()=="cancelled")output+="\nОтмена завершена. Сохранённые материалы остаются на ПК.\n";
    else if(code==0)output+="\nРезультат worker не подтверждён протоколом. Автоматическое повторение запрещено.\n";
   }
   emit changed();
  });
 }
 void readEvent(bool final=false) {
  auto record=OperationStatus::read(eventFile,activeOperation,sessionToken,activeAction);
  if(record.isEmpty()){if(final)protocolInvalid=true;return;}
  if(!lastEvent.isEmpty()) {
   const auto before=lastEvent.value("sequence").toInt(),after=record.value("sequence").toInt();
   if(after<before || (after==before && record!=lastEvent) || (after>before && lastEvent.value("kind").toString()!="phase")){protocolInvalid=true;return;}
  }
  lastEvent=record;
  if(record.value("kind").toString()=="phase")eventPhase=record.value("value").toString();
 }
 bool interrupted() const {return QFile::exists(folder+".guard") || QFile::exists(folder+"/operation.lock");}
 Q_INVOKABLE void recoverSession() {
  if(busy())return;
  auto base=QCoreApplication::applicationDirPath();
  auto env=QProcessEnvironment::systemEnvironment();env.insert("PYTHONIOENCODING","utf-8");
  process.setProcessEnvironment(env);process.setWorkingDirectory(base);
  state="recover-session";
  launch({base+"/package_worker.py",state,"--source","192.0.2.2","--index","1","--session",folder});
  emit changed();
 }
 bool canCancel() const {return busy() && activeAction!="install" && activeAction!="new-session" && activeAction!="recover-session" && !cancelRequested;}
 QString operationMessage() const {
  if(cancelRequested && busy())return "Отмена запрошена. Ожидаем завершения текущего запроса; питание и кабель оставьте подключёнными.";
  const QMap<QString,QString> labels={{"starting","Запускается операция…"},{"validating-zip","Проверяется архив на компьютере…"},{"preparing","Проверяется устройство и сохраняется копия…"},{"backup","Читается и проверяется полная копия…"},{"installing","Устанавливаются и проверяются пакеты. Не отключайте питание и кабель."},{"verifying","Проверяется результат без повторной установки…"},{"archiving","Сохраняются материалы предыдущего сеанса…"}};
  return labels.value(eventPhase,"Выполняется операция…");
 }
 Q_INVOKABLE void requestCancel() {
  if(!canCancel())return;
  QFile file(QFileInfo(eventFile).path()+"/"+activeOperation+".cancel");
  if(!file.open(QIODevice::WriteOnly|QIODevice::NewOnly)){output+="\nНе удалось передать запрос отмены.\n";emit changed();return;}
  file.write("cancel\n");file.close();cancelRequested=true;emit changed();
 }
 void launch(QStringList args) {
  activeAction=state;activeOperation=QUuid::createUuid().toString(QUuid::Id128);
  sessionToken=QString::fromLatin1(QCryptographicHash::hash(QDir(folder).canonicalPath().toUtf8(),QCryptographicHash::Sha256).toHex());
  eventFile=QFileInfo(folder).absolutePath()+"/operations/"+activeOperation+".json";
  QDir().mkpath(QFileInfo(eventFile).path());
  lastEvent={};eventPhase="starting";cancelRequested=false;protocolInvalid=false;
  args << "--operation-id" << activeOperation << "--session-id" << sessionToken;
  process.start(QCoreApplication::applicationDirPath()+"/python/python.exe",args);
  eventTimer.start();
 }
 bool sameFile(const QString &a,const QString &b) const {
  const auto left=QFileInfo(QDir::fromNativeSeparators(a)).canonicalFilePath();
  const auto right=QFileInfo(QDir::fromNativeSeparators(b)).canonicalFilePath();
#ifdef Q_OS_WIN
  return !left.isEmpty() && !right.isEmpty() && left.compare(right,Qt::CaseInsensitive)==0;
#else
  return !left.isEmpty() && left==right;
#endif
 }
 QJsonObject readObject(const QString &path) const {QFile f(path);if(!f.open(QIODevice::ReadOnly))return {};return QJsonDocument::fromJson(f.readAll()).object();}
 bool writeStarted() const {return QFile::exists(folder+"/write-started") || QFile::exists(folder+"/zip-session/write-started");}
 bool bundleLocked() const {return QFile::exists(folder+"/prepared.json") || writeStarted() || QFile::exists(folder+"/zip-binding.json") || QDir(folder+"/zip-session").exists();}
 QVariantList bundleChoices() const {return bundles;}
 QString bundlePath() const {return zipFile;}
 QString bundleVersion() const {return zipVersion;}
 bool zipMode() const {return !zipFile.isEmpty() || QDir(folder+"/zip-session").exists();}
 bool bundleReady() const {return zipMode() && zipReady;}
 Q_INVOKABLE void refreshBundles() {
  if(busy())return;
  bundles.clear();
  QDir base(QCoreApplication::applicationDirPath());
  for(const auto &file:base.entryList({"schoolbell-v*-openwrt-*.zip"},QDir::Files,QDir::Name)){
   QVariantMap row;row["label"]=file;row["path"]=QFileInfo(base.filePath(file)).canonicalFilePath();bundles.append(row);
  }
  emit changed();
 }
 Q_INVOKABLE void selectBundle(QString path) {
  if(busy() || bundleLocked())return;
  zipFile=path;zipReady=false;zipVersion.clear();
  if(path.isEmpty()){QFile::remove(folder+"/zip-selection.json");state="idle";emit changed();return;}
  auto base=QCoreApplication::applicationDirPath();
  auto env=QProcessEnvironment::systemEnvironment();env.insert("PYTHONIOENCODING","utf-8");
  process.setProcessEnvironment(env);process.setWorkingDirectory(base);
  output+="\n--- inspect-zip (local) ---\n";state="inspect-zip";
  launch({base+"/package_worker.py","inspect-zip","--zip",path,"--source",source,"--index",QString::number(index),"--session",folder});
  emit changed();
 }
 QVariantList connections() const {return choices;}
 Q_INVOKABLE void copyReport() {if(!output.isEmpty())QGuiApplication::clipboard()->setText(output);}
 Q_INVOKABLE QString connectionLabel(QString ip,int adapter) const {
  for(const auto &item:choices){const auto row=item.toMap();if(row.value("source").toString()==ip && row.value("index").toInt()==adapter)return row.value("label").toString();}
  return ip;
 }
 QString adapterDescription(int adapter) const {
#ifdef Q_OS_WIN
  MIB_IF_ROW2 row{};row.InterfaceIndex=ULONG(adapter);
  if(GetIfEntry2(&row)==NO_ERROR)return QString::fromWCharArray(row.Description);
#else
  Q_UNUSED(adapter);
#endif
  return {};
 }
 Q_INVOKABLE void refreshConnections() {
  if(busy())return;
  choices.clear();
  for(const auto &nic:QNetworkInterface::allInterfaces()) {
   if(nic.type()!=QNetworkInterface::Ethernet || !(nic.flags()&QNetworkInterface::IsUp) || !(nic.flags()&QNetworkInterface::IsRunning))continue;
   for(const auto &entry:nic.addressEntries()) {
    if(entry.ip().protocol()!=QAbstractSocket::IPv4Protocol || entry.ip().isLoopback())continue;
    if(entry.prefixLength()<1 || !QHostAddress("192.168.1.1").isInSubnet(entry.ip(),entry.prefixLength()))continue;
    if(entry.ip()==QHostAddress("192.168.1.1"))continue;
    const auto description=adapterDescription(nic.index());
    auto shortName=description;
    for(const auto &suffix:{QStringLiteral(" Family Controller"),QStringLiteral(" Controller")})
     if(shortName.endsWith(suffix)){shortName.chop(suffix.size());break;}
    QVariantMap row;row["label"]=nic.humanReadableName()+(shortName.isEmpty() || shortName==nic.humanReadableName()?QString():" · "+shortName)+" · "+entry.ip().toString();
    row["description"]=description;
    row["source"]=entry.ip().toString();row["index"]=nic.index();choices.append(row);
   }
  }
  emit changed();
 }
 Q_INVOKABLE void newSession() {
  if(busy() || interrupted() || state=="uncertain")return;
  auto base=QCoreApplication::applicationDirPath();
  auto env=QProcessEnvironment::systemEnvironment();env.insert("PYTHONIOENCODING","utf-8");
  process.setProcessEnvironment(env);process.setWorkingDirectory(base);
  output.clear();state="new-session";
  launch({base+"/package_worker.py","new-session","--source",source,"--index",QString::number(index),"--session",folder});
  emit changed();
 }
 bool fresh() const {QFile f(folder+(zipMode()?"/zip-session/prepared.json":"/prepared.json"));if(!f.open(QIODevice::ReadOnly))return false;return QJsonDocument::fromJson(f.readAll()).object().value("mode").toString()=="fresh";}
 QString sourceIP() const {return source;}
 int adapterIndex() const {return index;}
 bool busy() const {return process.state()!=QProcess::NotRunning;}
 QString stage() const {return state;}
 QString report() const {return output;}
 QString session() const {return folder;}
 Q_INVOKABLE void start(QString action,QString ip,int adapter,QString secret) {
  if(busy() || interrupted() || (action!="prepare" && action!="install" && action!="verify" && action!="backup")) return;
  if(action=="backup" && (writeStarted() || bundleLocked()))return;
  if(action=="prepare" && (!bundleReady() || (zipMode() && bundleLocked())))return;
  if(action=="install" && (state!="ready" || !zipMode())) return;
  if(action=="prepare" && writeStarted()) return;
  if(action=="install" && (source!=ip || index!=adapter)) return;
  if(secret.isEmpty() || secret.contains('\n') || secret.contains('\r')) return;
  password=secret;secret.fill(QChar(0));
  passwordServer.close();
  auto pipe="schoolbell-"+QUuid::createUuid().toString(QUuid::WithoutBraces);
  if(!passwordServer.listen(pipe)){password.fill(QChar(0));password.clear();state="error";output+="\nCannot create private password channel";emit changed();return;}
  source=ip;index=adapter;QSettings settings;settings.setValue("Device/source",source);settings.setValue("Device/index",index);
  auto base=QCoreApplication::applicationDirPath();
  auto env=QProcessEnvironment::systemEnvironment();
  env.insert("SSH_ASKPASS",QCoreApplication::applicationFilePath());
  env.insert("SSH_ASKPASS_REQUIRE","force");env.insert("SCHOOLBELL_PASSWORD_PIPE",pipe);env.insert("DISPLAY","schoolbell-setup");
  env.insert("SCHOOLBELL_ASKPASS","1");env.insert("PYTHONIOENCODING","utf-8");
  process.setProcessEnvironment(env);
  process.setWorkingDirectory(base);
  output+="\n--- "+action+" ---\n";state=action;
  QStringList workerArgs={base+"/package_worker.py",action,"--source",ip,"--index",QString::number(adapter),"--session",folder};
  if(zipMode() && action!="backup")workerArgs << "--zip" << zipFile;
  launch(workerArgs);
  emit changed();
 }
 Q_INVOKABLE void openHistory(){ QDesktopServices::openUrl(QUrl::fromLocalFile(QFileInfo(folder).absolutePath()+"/session-history")); }
 Q_INVOKABLE void openBackup(){ QDesktopServices::openUrl(QUrl::fromLocalFile(folder)); }
 Q_INVOKABLE void openDevice(){if(state=="done" || state=="current") QDesktopServices::openUrl(QUrl("http://192.168.1.1/cgi-bin/luci/admin/schoolbell"));}
 signals: void changed(); void sessionReset();
};
