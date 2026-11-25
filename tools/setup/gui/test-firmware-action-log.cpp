#include "FirmwareActionLog.h"
#include <QCoreApplication>
#include <QTemporaryDir>
#include <cstdio>
int main(int argc,char **argv){
 QCoreApplication app(argc,argv);QTemporaryDir dir;
 FirmwareActionLog log(dir.path());int failures=0;
 auto check=[&](bool value){if(!value)++failures;};
 check(log.path().isEmpty());check(log.append("adapter selected"));
 const auto first=log.path();check(log.append("connection checked"));
 for(int i=0;i<5;i++)check(log.path()==first);
 check(QDir(dir.path()).entryList({"*.txt"},QDir::Files).size()==1);
 QFile file(first);check(file.open(QIODevice::ReadOnly));auto data=file.readAll();file.close();
 check(data.contains("adapter selected") && data.contains("connection checked"));
 log.reset();check(log.path().isEmpty());check(log.append("new session"));check(log.path()!=first);
 check(file.open(QIODevice::ReadOnly));check(file.readAll()==data);
 FirmwareActionLog invalid(first+"/not-a-directory");check(!invalid.append("must fail"));
 printf("Firmware action log: %s\n",failures?"FAIL":"PASS");return failures?1:0;
}
