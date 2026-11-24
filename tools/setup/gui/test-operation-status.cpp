#include "OperationStatus.h"
#include <cstdio>
int main(){
 QJsonObject row{{"protocol",1},{"operation","op"},{"session","session"},{"action","install"},{"sequence",2},{"kind","completed"},{"value","done"}};
 int failures=0;
 auto check=[&](QJsonObject o,bool expected){if(OperationStatus::valid(o,"op","session","install")!=expected)++failures;};
 check(row,true);
 for(const auto &key:{"operation","session","action","kind","value"}){auto o=row;o[key]="stale";check(o,false);}
 for(const auto &key:{"protocol","sequence"}){auto o=row;o[key]=0;check(o,false);o[key]="2";check(o,false);}
 auto bad=row;bad["sequence"]=1.5;check(bad,false);
 bad=row;bad["kind"]="cancelled";bad["value"]="cancelled";check(bad,false);
 bad=row;bad["kind"]="phase";bad["value"]="installing";check(bad,true);
 bad=row;bad["kind"]="failed";bad["value"]="timeout";check(bad,true);
 printf("Operation status: %s\n",failures?"FAIL":"PASS");return failures?1:0;
}
