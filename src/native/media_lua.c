#define _GNU_SOURCE
#include <lua.h>
#include <lauxlib.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define STORE "schoolbell.media_linux.store"
#define LEASE "schoolbell.media_linux.lease"
#define REVISIONS 16
#define LEASES 128
typedef struct { char id[65],rev[65]; int fd; unsigned refs; } entry;
typedef struct { entry entries[REVISIONS]; unsigned used,total; int closed; } store;
typedef struct { store *owner; unsigned slot; int released; } lease;
static void *object(lua_State *L,int i,const char *name) {
    if(lua_type(L,i)!=LUA_TUSERDATA || !lua_getmetatable(L,i))return NULL;
    luaL_getmetatable(L,name);int match=lua_rawequal(L,-1,-2);lua_pop(L,2);
    return match?lua_touserdata(L,i):NULL;
}
static int failure(lua_State *L,const char *code,int e) {
    lua_pushnil(L);lua_createtable(L,0,2);
    lua_pushstring(L,code);lua_setfield(L,-2,"code");
    if(e){lua_pushinteger(L,e);lua_setfield(L,-2,"errno");}return 2;
}
static int identifier(lua_State *L,int i,char *out) {
    size_t n;const char *s;
    if(lua_type(L,i)!=LUA_TSTRING)return 0;
    s=lua_tolstring(L,i,&n);if(!n||n>64)return 0;
    for(size_t k=0;k<n;k++)if(!((s[k]>='A'&&s[k]<='Z')||(s[k]>='a'&&s[k]<='z')||
        (s[k]>='0'&&s[k]<='9')||s[k]=='_'||s[k]=='-'))return 0;
    memcpy(out,s,n);out[n]=0;return 1;
}
static int find(store *s,const char *id,const char *rev) {
    for(unsigned i=0;i<s->used;i++)
        if(!strcmp(s->entries[i].id,id)&&!strcmp(s->entries[i].rev,rev))return (int)i;
    return -1;
}
static int create(lua_State *L) {
    store *s=lua_newuserdata(L,sizeof *s);memset(s,0,sizeof *s);
    for(unsigned i=0;i<REVISIONS;i++)s->entries[i].fd=-1;
    luaL_getmetatable(L,STORE);lua_setmetatable(L,-2);return 1;
}
static int publish(lua_State *L) {
    store *s=object(L,1,STORE);char id[65],rev[65],path[64];struct stat before,after;
    if(!s||s->closed)return failure(L,"closed",0);
    if(!identifier(L,2,id)||!identifier(L,3,rev)||lua_type(L,4)!=LUA_TNUMBER)return failure(L,"invalid_argument",0);
    lua_Number v=lua_tonumber(L,4);
    if(!(v>=0&&v<=INT_MAX)||floor(v)!=v)return failure(L,"invalid_argument",0);
    if(find(s,id,rev)>=0)return failure(L,"exists",0); /* tombstones prevent reuse */
    if(s->used==REVISIONS)return failure(L,"limit",0);
    int fd=(int)v;
    if(fstat(fd,&before)<0)return failure(L,"media_invalid",errno);
    if(!S_ISREG(before.st_mode))return failure(L,"media_invalid",0);
    snprintf(path,sizeof path,"/proc/self/fd/%d",fd);
    int owned=open(path,O_RDONLY|O_CLOEXEC);
    if(owned<0)return failure(L,"media_invalid",errno);
    if(fstat(owned,&after)<0){int e=errno;close(owned);return failure(L,"media_invalid",e);}
    if(after.st_dev!=before.st_dev||after.st_ino!=before.st_ino||!S_ISREG(after.st_mode)){
        close(owned);return failure(L,"media_invalid",0);
    }
    /* No allocation or callback between FD acquisition and owned entry commit. */
    entry *e=&s->entries[s->used++];
    strcpy(e->id,id);strcpy(e->rev,rev);e->fd=owned;
    lua_pushboolean(L,1);return 1;
}
static int acquire(lua_State *L) {
    store *s=object(L,1,STORE);char id[65],rev[65];
    if(!s||s->closed)return failure(L,"closed",0);
    if(!identifier(L,2,id)||!identifier(L,3,rev))return failure(L,"invalid_argument",0);
    /* Allocate and attach the owner before lookup/retention. GC during allocation
     * may run arbitrary finalizers, so recheck the live catalog afterwards. */
    lease *h=lua_newuserdata(L,sizeof *h);memset(h,0,sizeof *h);h->released=1;h->owner=s;
    luaL_getmetatable(L,LEASE);lua_setmetatable(L,-2);
    lua_newtable(L);lua_pushvalue(L,1);lua_rawseti(L,-2,1);lua_setfenv(L,-2);
    int slot=find(s,id,rev);
    if(s->closed)return failure(L,"closed",0);
    if(slot<0||s->entries[slot].fd<0)return failure(L,"missing",0);
    if(s->total==LEASES)return failure(L,"limit",0);
    h->slot=(unsigned)slot;h->released=0;s->entries[slot].refs++;s->total++;
    return 1; /* no allocation after retaining the exact revision */
}
static void drop(lease *h) {
    if(h && !h->released){
        h->released=1;h->owner->entries[h->slot].refs--;h->owner->total--;
    }
}
static int release(lua_State *L) {
    store *s=object(L,1,STORE);lease *h=object(L,2,LEASE);
    if(!s||!h||h->owner!=s)return failure(L,"invalid_handle",0);
    drop(h);lua_pushboolean(L,1);return 1; /* idempotent, no system call/allocation */
}
static int descriptor(lua_State *L) {
    lease *h=object(L,1,LEASE);
    if(!h||h->released)return failure(L,"stale_handle",0);
    lua_pushinteger(L,h->owner->entries[h->slot].fd);return 1;
}
static int remove_revision(lua_State *L) {
    store *s=object(L,1,STORE);char id[65],rev[65];
    if(!s||s->closed)return failure(L,"closed",0);
    if(!identifier(L,2,id)||!identifier(L,3,rev))return failure(L,"invalid_argument",0);
    int slot=find(s,id,rev);
    if(slot<0||s->entries[slot].fd<0)return failure(L,"missing",0);
    entry *e=&s->entries[slot];
    if(e->refs)return failure(L,"busy",0);
    int fd=e->fd;e->fd=-1; /* Linux close consumes ownership, including EINTR. */
    if(close(fd)<0)return failure(L,"close_failed",errno);
    lua_pushboolean(L,1);return 1;
}
static int close_store(lua_State *L) {
    store *s=object(L,1,STORE);int e=0;
    if(!s)return failure(L,"invalid_handle",0);
    if(s->total)return failure(L,"busy",0);
    for(unsigned i=0;i<s->used;i++)if(s->entries[i].fd>=0){
        int fd=s->entries[i].fd;s->entries[i].fd=-1;
        if(close(fd)<0)e=errno;
    }
    s->closed=1;
    if(e)return failure(L,"close_failed",e);
    lua_pushboolean(L,1);return 1;
}
static int lease_gc(lua_State *L){drop(object(L,1,LEASE));return 0;}
static int store_gc(lua_State *L){
    store *s=object(L,1,STORE);
    if(s && !s->total){
        for(unsigned i=0;i<s->used;i++)if(s->entries[i].fd>=0){
            int fd=s->entries[i].fd;s->entries[i].fd=-1;close(fd);
        }
        s->closed=1;
    }
    return 0;
}
int luaopen_schoolbell_media_linux(lua_State *L) {
    const luaL_Reg methods[]={{"publish",publish},{"acquire",acquire},{"release",release},
        {"remove",remove_revision},{"close",close_store},{NULL,NULL}};
    luaL_newmetatable(L,LEASE);lua_pushcfunction(L,lease_gc);lua_setfield(L,-2,"__gc");
    lua_newtable(L);lua_pushcfunction(L,descriptor);lua_setfield(L,-2,"fd");lua_setfield(L,-2,"__index");
    lua_pushliteral(L,"protected");lua_setfield(L,-2,"__metatable");lua_pop(L,1);
    luaL_newmetatable(L,STORE);lua_pushcfunction(L,store_gc);lua_setfield(L,-2,"__gc");
    lua_newtable(L);luaL_register(L,NULL,methods);lua_setfield(L,-2,"__index");
    lua_pushliteral(L,"protected");lua_setfield(L,-2,"__metatable");lua_pop(L,1);
    lua_newtable(L);lua_pushcfunction(L,create);lua_setfield(L,-2,"new");return 1;
}
