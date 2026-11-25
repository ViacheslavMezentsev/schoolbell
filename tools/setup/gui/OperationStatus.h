#pragma once
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMap>
#include <QStringList>
namespace OperationStatus {
inline bool valid(const QJsonObject &o,const QString &id,const QString &session,const QString &action) {
 if(o.value("protocol").toDouble()!=1 || o.value("operation").toString()!=id || o.value("session").toString()!=session || o.value("action").toString()!=action)return false;
 const auto seq=o.value("sequence").toDouble();
 if(seq<1 || seq>100000 || seq!=int(seq))return false;
 const auto kind=o.value("kind").toString(),value=o.value("value").toString();
 if(kind=="phase")return QStringList{"starting","validating-zip","preparing","backup","installing","verifying","archiving"}.contains(value);
 if(kind=="failed")return QStringList{"operation-failed","timeout","transport-failed","validation-failed","authentication-failed"}.contains(value);
 if(kind=="cancelled")return value=="cancelled" && action!="install" && action!="new-session" && action!="recover-session";
 const QMap<QString,QStringList> outcomes={{"inspect-zip",{"idle"}},{"prepare",{"ready","current"}},{"install",{"done"}},{"verify",{"done","not-applied"}},{"backup",{"backedup"}},{"new-session",{"idle"}},{"recover-session",{"uncertain","error"}}};
 return kind=="completed" && outcomes.value(action).contains(value);
}
inline QJsonObject read(const QString &file,const QString &id,const QString &session,const QString &action) {
 QFile f(file);if(!f.open(QIODevice::ReadOnly) || f.size()>65536)return {};
 const auto o=QJsonDocument::fromJson(f.readAll()).object();
 return valid(o,id,session,action)?o:QJsonObject{};
}
}
