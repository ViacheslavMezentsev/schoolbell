#include <QGuiApplication>
#include <QLocalSocket>
#include <QQmlContext>
#include "Backend.h"
#include "FirmwareBackend.h"
#include "FirmwareImages.h"
#ifdef Q_OS_WIN
#include <windows.h>
#endif
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QFile>
#include <QTextStream>
int main(int argc,char **argv){
 qInstallMessageHandler([](QtMsgType, const QMessageLogContext &, const QString &message){
  const auto path=qEnvironmentVariable("ROUTER_SETUP_LOG");
  if(!path.isEmpty()){QFile file(path); if(file.open(QIODevice::Append|QIODevice::Text)){QTextStream stream(&file);stream<<message<<Qt::endl;}}
 });
 // Headless resource check/export: no settings, GUI, helper or network.
 if(argc>1 && (QString::fromLocal8Bit(argv[1])=="--check-firmware" || QString::fromLocal8Bit(argv[1])=="--export-firmware")) {
  QCoreApplication core(argc,argv);auto a=core.arguments();
  if(a.size()==2 && a[1]=="--check-firmware")return FirmwareImages::available()?0:1;
  if(a.size()==4 && a[1]=="--export-firmware")return FirmwareImages::exportImage(a[2],a[3])?0:1;
  return 2;
 }
 QGuiApplication app(argc,argv);
 if(qEnvironmentVariable("SCHOOLBELL_ASKPASS")=="1" && argc>1) {
  // This mode is only the OpenSSH password helper. Never log the prompt or secret.
  if(!QString::fromLocal8Bit(argv[1]).contains("password",Qt::CaseInsensitive)) return 1;
  QLocalSocket socket;
  const auto pipe=qEnvironmentVariable("SCHOOLBELL_PASSWORD_PIPE");
  if(pipe.isEmpty())return 1;
  socket.connectToServer(pipe,QIODevice::ReadOnly);
  if(!socket.waitForConnected(10000))return 1;
  if(!socket.bytesAvailable() && !socket.waitForReadyRead(10000))return 1;
  auto bytes=socket.readAll();
  if(!bytes.endsWith('\n'))return 1;
#ifdef Q_OS_WIN
  DWORD written=0;WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),bytes.constData(),DWORD(bytes.size()),&written,nullptr);
#else
  fwrite(bytes.constData(),1,bytes.size(),stdout);fflush(stdout);
#endif
  bytes.fill(0);return 0;
 }
 QCoreApplication::setOrganizationName("Schoolbell");
 // Preserve the existing settings, backups and pending-write state during renaming.
 QCoreApplication::setApplicationName("RouterSetupPrototype");
 QCoreApplication::setApplicationVersion(SCHOOLBELL_WIZARD_VERSION);
 QGuiApplication::setApplicationDisplayName(QString::fromUtf8("Мастер установки ")+SCHOOLBELL_WIZARD_VERSION);
 QQuickStyle::setStyle("Basic");
 Backend backend; FirmwareBackend firmware;
 QQmlApplicationEngine engine;engine.rootContext()->setContextProperty("realBackend",&backend);engine.rootContext()->setContextProperty("firmwareBackend",&firmware);
 QObject::connect(&engine,&QQmlApplicationEngine::objectCreationFailed,&app,[]{QCoreApplication::exit(1);},Qt::QueuedConnection);
 engine.load(QUrl("qrc:/RouterSetup/qml/Main.qml"));
 return app.exec();
}
