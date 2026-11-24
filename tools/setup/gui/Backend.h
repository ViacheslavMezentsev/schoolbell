#pragma once
#include <QObject>
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
 Q_PROPERTY(QString sourceIP READ sourceIP NOTIFY changed)
 Q_PROPERTY(int adapterIndex READ adapterIndex NOTIFY changed)
 Q_PROPERTY(bool busy READ busy NOTIFY changed)
 Q_PROPERTY(QString stage READ stage NOTIFY changed)
 Q_PROPERTY(QString report READ report NOTIFY changed)
 Q_PROPERTY(QString session READ session NOTIFY changed)
 Q_PROPERTY(bool fresh READ fresh NOTIFY changed)
 Q_PROPERTY(QVariantList connections READ connections NOTIFY changed)
 QVariantList choices;
 QProcess process;
 QLocalServer passwordServer;
 QString password;
 QString state="idle", output, folder;
 QString operationOutput;
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
  if(QFile::exists(folder+"/write-started")) state="uncertain";
  else if(QFile::exists(folder+"/prepared.json")) state="ready";
  process.setProcessChannelMode(QProcess::MergedChannels);
  connect(&process,&QProcess::readyReadStandardOutput,this,[this]{ auto bytes=process.readAllStandardOutput();output+=QString::fromUtf8(bytes);operationOutput+=QString::fromUtf8(bytes);QFile log(folder+"/operation.log");if(log.open(QIODevice::Append))log.write(bytes);emit changed(); });
  connect(&process,&QProcess::errorOccurred,this,[this](QProcess::ProcessError error){ if(error==QProcess::FailedToStart){password.fill(QChar(0));password.clear();passwordServer.close();state="error";output+="\nCannot start packaged worker: "+process.errorString();emit changed();} });
  connect(&process,qOverload<int,QProcess::ExitStatus>(&QProcess::finished),this,[this](int code,QProcess::ExitStatus status){
   password.fill(QChar(0));password.clear();passwordServer.close();
   if(code==0 && status==QProcess::NormalExit) {
    if(state=="new-session") {state="idle";source.clear();index=0;emit sessionReset();}
    else if(state=="backup")state="backedup";
    else state=state=="prepare"?(operationOutput.contains("ALREADY CURRENT.")?"current":"ready"):"done";
   }
   else state=QFile::exists(folder+"/write-started")?"uncertain":"error";
   emit changed();
  });
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
  if(busy() || state=="uncertain")return;
  auto base=QCoreApplication::applicationDirPath();
  auto env=QProcessEnvironment::systemEnvironment();env.insert("PYTHONIOENCODING","utf-8");
  process.setProcessEnvironment(env);process.setWorkingDirectory(base);
  output.clear();state="new-session";
  process.start(base+"/python/python.exe",{base+"/package_worker.py","new-session","--source",source,"--index",QString::number(index),"--session",folder});
  emit changed();
 }
 bool fresh() const {QFile f(folder+"/prepared.json");if(!f.open(QIODevice::ReadOnly))return false;return QJsonDocument::fromJson(f.readAll()).object().value("mode").toString()=="fresh";}
 QString sourceIP() const {return source;}
 int adapterIndex() const {return index;}
 bool busy() const {return process.state()!=QProcess::NotRunning;}
 QString stage() const {return state;}
 QString report() const {return output;}
 QString session() const {return folder;}
 Q_INVOKABLE void start(QString action,QString ip,int adapter,QString secret) {
  if(busy() || (action!="prepare" && action!="install" && action!="verify" && action!="backup")) return;
  if(action=="backup" && state!="current")return;
  if(action=="install" && state!="ready") return;
  if(action=="prepare" && QFile::exists(folder+"/write-started")) return;
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
  operationOutput.clear();output+="\n--- "+action+" ---\n";state=action;
  process.start(base+"/python/python.exe",{base+"/package_worker.py",action,"--source",ip,"--index",QString::number(adapter),"--session",folder});
  emit changed();
 }
 Q_INVOKABLE void openHistory(){ QDesktopServices::openUrl(QUrl::fromLocalFile(QFileInfo(folder).absolutePath()+"/session-history")); }
 Q_INVOKABLE void openBackup(){ QDesktopServices::openUrl(QUrl::fromLocalFile(folder)); }
 Q_INVOKABLE void openDevice(){if(state=="done" || state=="current") QDesktopServices::openUrl(QUrl("http://192.168.1.1/cgi-bin/luci/admin/schoolbell"));}
 signals: void changed(); void sessionReset();
};
