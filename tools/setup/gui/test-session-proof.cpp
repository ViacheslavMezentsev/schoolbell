#include "SessionProof.h"
#include <QTemporaryDir>
#include <cstdio>
int main(){
 QTemporaryDir dir; const auto base=dir.path(); int failures=0;
 auto put=[&](const char *name,QByteArray data){QFile f(base+"/"+name);if(!f.open(QIODevice::WriteOnly))abort();f.write(data);};
 auto check=[&](const char *expected){if(SessionProof::restored(base)!=expected){++failures;fprintf(stderr,"Expected %s\n",expected);}};
 check("uncertain");
 put("session.json",R"({"version":"5.1.127"})");put("prepared.json","prepared");put("write-started","attempt-1");
 auto receipt=[&](){return QJsonDocument(QJsonObject{{"version","5.1.127"},{"prepared_sha256",SessionProof::hash(base+"/prepared.json")},{"marker_sha256",SessionProof::hash(base+"/write-started")}}).toJson();};
 check("uncertain");put("verified.json",receipt());check("done");
 put("write-started","attempt-2");check("uncertain");
 put("verified.json",receipt());put("prepared.json","changed");check("uncertain");
 put("verified.json",receipt());put("session.json",R"({"version":"5.1.128"})");check("uncertain");
 put("session.json",R"({"version":"5.1.127"})");put("verified.json","broken");check("uncertain");
 QFile::remove(base+"/verified.json");put("unchanged.json",receipt());check("not-applied");
 put("verified.json","broken");check("uncertain");
 QFile::remove(base+"/prepared.json");check("uncertain");
 printf("Session proof: %s\n",failures?"FAIL":"PASS");return failures?1:0;
}
