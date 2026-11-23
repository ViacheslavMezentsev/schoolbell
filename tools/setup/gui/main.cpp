#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QFile>
#include <QTextStream>
int main(int argc,char **argv){
 qInstallMessageHandler([](QtMsgType, const QMessageLogContext &, const QString &message){
  const auto path=qEnvironmentVariable("ROUTER_SETUP_LOG");
  if(!path.isEmpty()){QFile file(path); if(file.open(QIODevice::Append|QIODevice::Text)){QTextStream stream(&file);stream<<message<<Qt::endl;}}
 });
 QGuiApplication app(argc,argv);
 QCoreApplication::setOrganizationName("Schoolbell");
 QCoreApplication::setApplicationName("RouterSetupPrototype");
 QQuickStyle::setStyle("Basic");
 QQmlApplicationEngine engine;
 QObject::connect(&engine,&QQmlApplicationEngine::objectCreationFailed,&app,[]{QCoreApplication::exit(1);},Qt::QueuedConnection);
 engine.load(QUrl("qrc:/RouterSetup/qml/Main.qml"));
 return app.exec();
}
