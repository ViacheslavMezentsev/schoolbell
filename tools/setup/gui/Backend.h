#pragma once
#include <QObject>
#include <QProcess>
#include <QDir>
#include <QStandardPaths>
#include <QDateTime>
#include <QCoreApplication>
#include <QFile>
#include <QSettings>
#include <QLocalServer>
#include <QLocalSocket>
#include <QUuid>
#include <QDesktopServices>
#include <QUrl>
class Backend : public QObject {
 Q_OBJECT
 Q_PROPERTY(QString sourceIP READ sourceIP NOTIFY changed)
 Q_PROPERTY(int adapterIndex READ adapterIndex NOTIFY changed)
 Q_PROPERTY(bool busy READ busy NOTIFY changed)
 Q_PROPERTY(QString stage READ stage NOTIFY changed)
 Q_PROPERTY(QString report READ report NOTIFY changed)
 Q_PROPERTY(QString session READ session NOTIFY changed)
 QProcess process;
 QLocalServer passwordServer;
 QString password;
 QString state="idle", output, folder;
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
  connect(&process,&QProcess::readyReadStandardOutput,this,[this]{ auto bytes=process.readAllStandardOutput();output+=QString::fromUtf8(bytes);QFile log(folder+"/operation.log");if(log.open(QIODevice::Append))log.write(bytes);emit changed(); });
  connect(&process,&QProcess::errorOccurred,this,[this](QProcess::ProcessError error){ if(error==QProcess::FailedToStart){password.fill(QChar(0));password.clear();passwordServer.close();state="error";output+="\nCannot start packaged worker: "+process.errorString();emit changed();} });
  connect(&process,qOverload<int,QProcess::ExitStatus>(&QProcess::finished),this,[this](int code,QProcess::ExitStatus status){
   password.fill(QChar(0));password.clear();passwordServer.close();
   if(code==0 && status==QProcess::NormalExit) state=state=="prepare"?"ready":"done";
   else state=QFile::exists(folder+"/write-started")?"uncertain":"error";
   emit changed();
  });
 }
 QString sourceIP() const {return source;}
 int adapterIndex() const {return index;}
 bool busy() const {return process.state()!=QProcess::NotRunning;}
 QString stage() const {return state;}
 QString report() const {return output;}
 QString session() const {return folder;}
 Q_INVOKABLE void start(QString action,QString ip,int adapter,QString secret) {
  if(busy() || (action!="prepare" && action!="install" && action!="verify")) return;
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
  output+="\n--- "+action+" ---\n";state=action;
  process.start(base+"/python/python.exe",{base+"/package_worker.py",action,"--source",ip,"--index",QString::number(adapter),"--session",folder});
  emit changed();
 }
 Q_INVOKABLE void openBackup(){ QDesktopServices::openUrl(QUrl::fromLocalFile(folder)); }
 Q_INVOKABLE void openDevice(){if(state=="done") QDesktopServices::openUrl(QUrl("http://192.168.1.1/cgi-bin/luci/admin/schoolbell"));}
 signals: void changed();
};
