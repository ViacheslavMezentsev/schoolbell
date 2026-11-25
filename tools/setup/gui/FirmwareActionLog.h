#pragma once
#include <QDir>
#include <QFile>
#include <QDateTime>
#include <QStandardPaths>
#include <QUuid>
class FirmwareActionLog {
 QString root, current;
public:
 explicit FirmwareActionLog(QString directory=QString()):root(directory.isEmpty()?QDir(QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation)).filePath("firmware-logs"):directory){}
 QString path()const{return current;}
 bool append(const QString &message){
  if(current.isEmpty()){
   if(!QDir().mkpath(root))return false;
   current=QDir(root).filePath("firmware-"+QUuid::createUuid().toString(QUuid::WithoutBraces)+".txt");
  }
  QFile file(current);
  if(!file.open(QIODevice::WriteOnly|QIODevice::Append))return false;
  const auto bytes=(QDateTime::currentDateTimeUtc().toString(Qt::ISODate)+" "+message+"\n").toUtf8();
  return file.write(bytes)==bytes.size() && file.flush();
 }
 void reset(){current.clear();}
};
