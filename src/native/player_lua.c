#include "player.h"
#include <lua.h>
#include <lauxlib.h>
#include <errno.h>
#include <limits.h>
#include <math.h>
#include <string.h>

#define OWNER "schoolbell.player_linux.owner"
#define HANDLE "schoolbell.player_linux.handle"
typedef struct {
    sbp *native;
    int busy, refs[128];
    unsigned maximum, count;
    char resources[4][65];
} owner;
typedef struct { owner *parent; sbp_handle native; int released; } handle;
typedef struct { lua_State *L; int callback; } permission;
static void *userdata(lua_State *L,int index,const char *name) {
    void *p=lua_touserdata(L,index);
    if (lua_type(L,index)!=LUA_TUSERDATA || !lua_getmetatable(L,index)) return NULL;
    luaL_getmetatable(L,name);
    int match=lua_rawequal(L,-1,-2);lua_pop(L,2);
    return match?p:NULL;
}
static void field(lua_State *L,int table,const char *key) {
    lua_pushstring(L,key);lua_rawget(L,table);
}
static void stringfield(lua_State *L,const char *key,const char *s) {
    lua_pushstring(L,s);lua_setfield(L,-2,key);
}
static void numberfield(lua_State *L,const char *key,lua_Number n) {
    lua_pushnumber(L,n);lua_setfield(L,-2,key);
}
static void boolfield(lua_State *L,const char *key,int b) {
    lua_pushboolean(L,b);lua_setfield(L,-2,key);
}
static void error(lua_State *L,const char *code,const char *stage,int e) {
    lua_createtable(L,0,3);stringfield(L,"code",code);stringfield(L,"stage",stage);
    if (e) numberfield(L,"errno",e);
}
static int fail(lua_State *L,const char *code,const char *stage,int e) {
    lua_pushnil(L);error(L,code,stage,e);return 2;
}
static int plain(lua_State *L,int i) {
    if (lua_type(L,i)!=LUA_TTABLE) return 0;
    if (lua_getmetatable(L,i)) {lua_pop(L,1);return 0;}
    return 1;
}
static int integer(lua_State *L,int i,int low,int high,int *v) {
    if (lua_type(L,i)!=LUA_TNUMBER) return 0;
    lua_Number n=lua_tonumber(L,i);
    if (!(n>=low && n<=high) || floor(n)!=n) return 0;
    *v=(int)n;return 1;
}
static int text(lua_State *L,int i,size_t maximum,const char **s) {
    size_t n;
    if (lua_type(L,i)!=LUA_TSTRING) return 0;
    *s=lua_tolstring(L,i,&n);
    return n>0 && n<=maximum && !memchr(*s,0,n);
}
static int fields(lua_State *L,int i,const char *const *allowed) {
    lua_pushnil(L);
    while(lua_next(L,i)) {
        int ok=0;const char *key;
        if (text(L,-2,64,&key))
            for(unsigned k=0;allowed[k];k++) if(!strcmp(key,allowed[k])) ok=1;
        lua_pop(L,1);
        if(!ok){lua_pop(L,1);return 0;}
    }
    return 1;
}
static int array(lua_State *L,int i,unsigned maximum,unsigned *n) {
    if(!plain(L,i)) return 0;
    size_t length=lua_objlen(L,i);
    if(!length || length>maximum) return 0;
    unsigned count=0;int v;
    lua_pushnil(L);
    while(lua_next(L,i)) {
        if(!integer(L,-2,1,(int)length,&v)){lua_pop(L,2);return 0;}
        count++;lua_pop(L,1);
    }
    if(count!=length) return 0;
    *n=(unsigned)length;return 1;
}
static void stats(lua_State *L,unsigned calls) {
    lua_createtable(L,0,1);numberfield(L,"calls",calls);
}
static void snapshot(lua_State *L,const sbp_result *r) {
    const char *states[]={"launching","running","terminal","uncertain"};
    const char *execs[]={"pending","confirmed","failed","unknown"};
    const char *outcomes[]={NULL,"not_started","exit","signal","unknown"};
    lua_createtable(L,0,10);
    stringfield(L,"generation",r->generation);numberfield(L,"attempt_id",r->attempt);
    stringfield(L,"state",states[r->state]);stringfield(L,"exec_status",execs[r->exec_status]);
    if(r->outcome!=SBP_NO_OUTCOME)stringfield(L,"outcome",outcomes[r->outcome]);
    if(r->outcome==SBP_EXIT)numberfield(L,"exit_code",r->exit_code);
    if(r->outcome==SBP_SIGNAL)numberfield(L,"signal",r->signal);
    if(r->error){error(L,r->error,r->stage,r->error_number);lua_setfield(L,-2,"error");}
    boolfield(L,"launch_timeout",r->launch_timeout);
    boolfield(L,"cleanup_pending",r->cleanup_pending);
}
static int create(lua_State *L) {
    const char *const keys[]={"executable_fd","lock_directory_fd","argv","resources","max_records","launch_timeout_ms",NULL};
    sbp_options o;const char *argv[17]={0};
    unsigned n;int value;
    memset(&o,0,sizeof o);o.max_records=128;o.timeout_ms=2000;
    if(!plain(L,1)||!fields(L,1,keys))return fail(L,"invalid_argument","validate",0);
    field(L,1,"executable_fd");
    if(!integer(L,-1,0,INT_MAX,&value))return fail(L,"invalid_argument","validate",0);
    o.executable_fd=value;lua_pop(L,1);
    field(L,1,"lock_directory_fd");
    if(!integer(L,-1,0,INT_MAX,&value))return fail(L,"invalid_argument","validate",0);
    o.lock_directory_fd=value;lua_pop(L,1);
    field(L,1,"max_records");
    if(!lua_isnil(L,-1)) {
        if(!integer(L,-1,1,128,&value))return fail(L,"invalid_argument","validate",0);
        o.max_records=(unsigned)value;
    }lua_pop(L,1);
    field(L,1,"launch_timeout_ms");
    if(!lua_isnil(L,-1)) {
        if(!integer(L,-1,100,60000,&value))return fail(L,"invalid_argument","validate",0);
        o.timeout_ms=(unsigned)value;
    }lua_pop(L,1);
    field(L,1,"resources");int resources=lua_gettop(L);
    if(!array(L,resources,4,&n))return fail(L,"invalid_argument","validate",0);
    o.resource_count=n;
    for(unsigned i=0;i<n;i++){
        lua_rawgeti(L,resources,(int)i+1);
        if(!text(L,-1,64,&o.resources[i]))return fail(L,"invalid_argument","validate",0);
        lua_pop(L,1);
    }
    field(L,1,"argv");int arguments=lua_gettop(L);
    if(!array(L,arguments,16,&n))return fail(L,"invalid_argument","validate",0);
    for(unsigned i=0;i<n;i++){
        lua_rawgeti(L,arguments,(int)i+1);
        if(!text(L,-1,2047,&argv[i]))return fail(L,"invalid_argument","validate",0);
        lua_pop(L,1);
    }o.argv=argv;
    /* Allocate Lua ownership before acquiring any native resources. */
    owner *p=lua_newuserdata(L,sizeof *p);memset(p,0,sizeof *p);
    for(unsigned i=0;i<128;i++)p->refs[i]=LUA_NOREF;
    luaL_getmetatable(L,OWNER);lua_setmetatable(L,-2);
    p->maximum=o.max_records;p->count=o.resource_count;
    for(unsigned i=0;i<p->count;i++)strcpy(p->resources[i],o.resources[i]);
    p->native=sbp_create(&o);
    if(!p->native){int e=errno;return fail(L,(e==EINVAL||e==E2BIG)?"invalid_argument":"spawn_failed","validate",(e==EINVAL||e==E2BIG)?0:e); }
    return 1;
}
static int permit(void *arg) {
    permission *p=arg;lua_State *L=p->L;
    lua_pushvalue(L,p->callback);
    if(lua_pcall(L,0,1,0)!=0){lua_pop(L,1);return 0;}
    int ok=lua_type(L,-1)==LUA_TBOOLEAN && lua_toboolean(L,-1);
    lua_pop(L,1);return ok;
}
static int begin(lua_State *L) {
    const char *const keys[]={"resource",NULL};
    owner *p=userdata(L,1,OWNER);const char *name;int fd;unsigned resource,slot;
    if(!p||!p->native)return fail(L,"invalid_handle","validate",0);
    if(p->busy)return fail(L,"busy","validate",0);
    if(!plain(L,2)||!fields(L,2,keys)||!integer(L,3,0,INT_MAX,&fd)||lua_type(L,4)!=LUA_TFUNCTION ||
       (!lua_isnoneornil(L,5) && lua_type(L,5)!=LUA_TUSERDATA))
        return fail(L,"invalid_argument","validate",0);
    field(L,2,"resource");
    if(!text(L,-1,64,&name))return fail(L,"invalid_argument","validate",0);
    for(resource=0;resource<p->count;resource++)if(!strcmp(name,p->resources[resource]))break;
    lua_pop(L,1);
    if(resource==p->count)return fail(L,"invalid_argument","validate",0);
    for(slot=0;slot<p->maximum;slot++)if(p->refs[slot]==LUA_NOREF)break;
    if(slot==p->maximum)return fail(L,"limit","validate",0);
    lua_settop(L,5); /* keep optional retained media distinct from new userdata */
    handle *h=lua_newuserdata(L,sizeof *h);memset(h,0,sizeof *h);h->parent=p;
    luaL_getmetatable(L,HANDLE);lua_setmetatable(L,-2);
    lua_newtable(L);lua_pushvalue(L,1);lua_rawseti(L,-2,1);
    if(!lua_isnoneornil(L,5)){lua_pushvalue(L,5);lua_rawseti(L,-2,2);}
    lua_setfenv(L,-2);
    /* Pin both handle and owner BEFORE fork. Allocation failure later cannot
     * lose a child; pending() recovers every retained handle. */
    lua_pushvalue(L,-1);int ref=luaL_ref(L,LUA_REGISTRYINDEX);
    p->refs[slot]=ref;
    permission permission_arg={L,4};sbp_result r;
    p->busy=1;int result=sbp_begin(p->native,resource,fd,permit,&permission_arg,&h->native,&r);p->busy=0;
    if(result<0){
        h->released=1;p->refs[slot]=LUA_NOREF;luaL_unref(L,LUA_REGISTRYINDEX,ref);
        return fail(L,r.error,r.stage,r.error_number);
    }
    lua_pushnil(L);stats(L,r.calls);return 3;
}
static int checked(lua_State *L,owner **p,handle **h) {
    *p=userdata(L,1,OWNER);*h=userdata(L,2,HANDLE);
    if(!*p||!(*p)->native||!*h||(*h)->parent!=*p)return 0;
    return 1;
}
static int poll_player(lua_State *L) {
    owner *p;handle *h;sbp_result r;
    if(!checked(L,&p,&h))return fail(L,"invalid_handle","validate",0);
    if(p->busy)return fail(L,"busy","observe",0);
    if(h->released)return fail(L,"stale_handle","validate",0);
    int rc=sbp_poll(p->native,h->native,&r);
    if(rc<0)return fail(L,r.error,r.stage,r.error_number);
    snapshot(L,&r);lua_pushnil(L);stats(L,r.calls);return 3;
}
static int release(lua_State *L) {
    owner *p;handle *h;sbp_result r;
    if(!checked(L,&p,&h))return fail(L,"invalid_handle","validate",0);
    if(p->busy)return fail(L,"busy","cleanup",0);
    if(h->released)return fail(L,"stale_handle","validate",0);
    if(sbp_release(p->native,h->native,&r)<0)return fail(L,r.error,r.stage,r.error_number);
    h->released=1;
    for(unsigned i=0;i<p->maximum;i++){
        if(p->refs[i]==LUA_NOREF)continue;
        lua_rawgeti(L,LUA_REGISTRYINDEX,p->refs[i]);
        int same=lua_rawequal(L,2,-1);lua_pop(L,1);
        if(same){luaL_unref(L,LUA_REGISTRYINDEX,p->refs[i]);p->refs[i]=LUA_NOREF;break;}
    }
    lua_pushboolean(L,1);lua_pushnil(L);stats(L,r.calls);return 3;
}
static int pending(lua_State *L) {
    owner *p=userdata(L,1,OWNER);
    if(!p||!p->native)return fail(L,"invalid_handle","validate",0);
    if(p->busy)return fail(L,"busy","observe",0);
    lua_createtable(L,(int)p->maximum,0);int n=0;
    for(unsigned i=0;i<p->maximum;i++)if(p->refs[i]!=LUA_NOREF){
        lua_rawgeti(L,LUA_REGISTRYINDEX,p->refs[i]);lua_rawseti(L,-2,++n);
    }return 1;
}
static int close_player(lua_State *L) {
    owner *p=userdata(L,1,OWNER);
    if(!p||!p->native)return fail(L,"invalid_handle","validate",0);
    if(p->busy)return fail(L,"busy","cleanup",0);
    if(sbp_destroy(p->native)<0)return fail(L,"busy","cleanup",0);
    p->native=NULL;lua_pushboolean(L,1);return 1;
}
static int gc(lua_State *L) {
    owner *p=userdata(L,1,OWNER);
    if(p && p->native && !p->busy && sbp_destroy(p->native)==0)p->native=NULL;
    /* At lua_close an undrained instance deliberately stays fail-closed.
     * The embedding process must drain/release/close before closing its VM. */
    return 0;
}
int luaopen_schoolbell_player_linux(lua_State *L) {
    const luaL_Reg methods[]={{"begin",begin},{"poll",poll_player},{"release",release},
        {"pending",pending},{"close",close_player},{NULL,NULL}};
    luaL_newmetatable(L,HANDLE);lua_pushliteral(L,"protected");lua_setfield(L,-2,"__metatable");lua_pop(L,1);
    luaL_newmetatable(L,OWNER);
    lua_pushcfunction(L,gc);lua_setfield(L,-2,"__gc");
    lua_newtable(L);luaL_register(L,NULL,methods);lua_setfield(L,-2,"__index");
    lua_pushliteral(L,"protected");lua_setfield(L,-2,"__metatable");lua_pop(L,1);
    lua_newtable(L);lua_pushcfunction(L,create);lua_setfield(L,-2,"new");return 1;
}
