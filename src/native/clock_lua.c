#define _GNU_SOURCE
#include <lua.h>
#include <lauxlib.h>
#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#define HANDLE "schoolbell.clock_linux.store"
#define MAIN "clock-reference.json"
#define TEMP "clock-reference.next"
#define LOCK ".clock-reference.lock"
#define LIMIT 1024
/* No clock mutation APIs, shell, network or automatic directory creation. */
typedef struct { int dir, lock; } handle;
static int fail(lua_State *L,const char *what) { return luaL_error(L,"clock: %s (errno %d)",what,errno); }
static handle *live(lua_State *L) {
    handle *h=luaL_checkudata(L,1,HANDLE);
    if(h->dir<0)luaL_error(L,"clock: closed");
    return h;
}
static const char *name(lua_State *L,int i) {
    size_t n;const char *p=luaL_checklstring(L,i,&n);
    if(n!=strlen(p)||(strcmp(p,MAIN)&&strcmp(p,TEMP)))luaL_error(L,"clock: filename");
    return p;
}
static int regular(int fd,off_t limit) {
    struct stat s;
    if(fstat(fd,&s)<0)return 0;
    if(!S_ISREG(s.st_mode)||s.st_uid!=geteuid()||s.st_nlink!=1||(s.st_mode&077)||s.st_size>limit){errno=EINVAL;return 0;}
    return 1;
}
static int close_handle(lua_State *L) {
    handle *h=luaL_checkudata(L,1,HANDLE);int e=0,fd;
    fd=h->lock;h->lock=-1;if(fd>=0&&close(fd)<0)e=errno;
    fd=h->dir;h->dir=-1;if(fd>=0&&close(fd)<0)e=errno;
    lua_pushboolean(L,e==0);return 1;
}
static int open_store(lua_State *L) {
    size_t n;const char *path=luaL_checklstring(L,1,&n);char copy[4096];
    if(!n||n>=sizeof copy||path[0]!='/'||n!=strlen(path)||path[n-1]=='/'||strstr(path,"//"))return luaL_error(L,"clock: absolute directory");
    memcpy(copy,path,n+1);
    handle *h=lua_newuserdata(L,sizeof *h);h->dir=-1;h->lock=-1;
    luaL_getmetatable(L,HANDLE);lua_setmetatable(L,-2);
    int fd=open("/",O_RDONLY|O_DIRECTORY|O_CLOEXEC);if(fd<0)return fail(L,"root");
    h->dir=fd;
    char *part=copy+1;
    while(*part){
        char *end=strchr(part,'/');if(end)*end=0;
        if(!strcmp(part,".")||!strcmp(part,"..")){close(h->dir);h->dir=-1;return luaL_error(L,"clock: path component");}
        int next=openat(h->dir,part,O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC);
        if(next<0){int e=errno;close(h->dir);h->dir=-1;errno=e;return fail(L,"directory");}
        fd=h->dir;h->dir=next;
        if(close(fd)<0){int e=errno;close(h->dir);h->dir=-1;errno=e;return fail(L,"directory close");}
        if(!end)break;
        part=end+1;
    }
    struct stat s;
    if(fstat(h->dir,&s)<0||s.st_uid!=geteuid()||(s.st_mode&077)){close(h->dir);h->dir=-1;return luaL_error(L,"clock: private owned directory required");}
    h->lock=openat(h->dir,LOCK,O_RDWR|O_CREAT|O_NOFOLLOW|O_NONBLOCK|O_CLOEXEC,0600);
    if(h->lock<0||!regular(h->lock,0)||flock(h->lock,LOCK_EX|LOCK_NB)<0){
        int e=errno;if(h->lock>=0)close(h->lock);close(h->dir);h->lock=h->dir=-1;errno=e;return fail(L,"lock");
    }
    return 1;
}
static int read_file(lua_State *L) {
    handle *h=live(L);const char *p=name(L,2);char b[LIMIT+1];size_t used=0;
    int fd=openat(h->dir,p,O_RDONLY|O_NOFOLLOW|O_NONBLOCK|O_CLOEXEC);
    if(fd<0){if(errno==ENOENT){lua_pushnil(L);return 1;}return fail(L,"read open");}
    if(!regular(fd,LIMIT)){int e=errno;close(fd);errno=e;return fail(L,"read file");}
    while(used<sizeof b){ssize_t n=read(fd,b+used,sizeof b-used);if(n<0&&errno==EINTR)continue;
        if(n<0){int e=errno;close(fd);errno=e;return fail(L,"read");}if(!n)break;used+=(size_t)n;}
    if(close(fd)<0)return fail(L,"read close");
    if(used>LIMIT)return luaL_error(L,"clock: size");
    lua_pushlstring(L,b,used);return 1;
}
static int stat_file(lua_State *L) {
    handle *h=live(L);const char *p=name(L,2);struct stat s;
    if(fstatat(h->dir,p,&s,AT_SYMLINK_NOFOLLOW)<0){if(errno==ENOENT){lua_pushnil(L);return 1;}return fail(L,"stat");}
    if(!S_ISREG(s.st_mode)||s.st_uid!=geteuid()||s.st_nlink!=1||(s.st_mode&077)||s.st_size>LIMIT)return luaL_error(L,"clock: unsafe file");
    lua_pushboolean(L,1);return 1;
}
static int unlink_file(lua_State *L) {
    handle *h=live(L);const char *p=name(L,2);
    if(strcmp(p,TEMP))return luaL_error(L,"clock: only temporary removal");
    if(unlinkat(h->dir,p,0)<0)return fail(L,"unlink");
    lua_pushboolean(L,1);return 1;
}
static int write_file(lua_State *L) {
    handle *h=live(L);const char *p=name(L,2);size_t n;const char *b=luaL_checklstring(L,3,&n);
    if(strcmp(p,TEMP)||n>LIMIT)return luaL_error(L,"clock: write limits");
    int fd=openat(h->dir,p,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC,0600);
    if(fd<0)return fail(L,"write open");
    size_t done=0;while(done<n){ssize_t k=write(fd,b+done,n-done);if(k<0&&errno==EINTR)continue;
        if(k<=0){int e=errno;close(fd);errno=e;return fail(L,"write");}done+=(size_t)k;}
    if(close(fd)<0)return fail(L,"write close");
    lua_pushboolean(L,1);return 1;
}
static int sync_file(lua_State *L) {
    handle *h=live(L);size_t n;const char *p=luaL_checklstring(L,2,&n);int fd=h->dir,owned=0;
    if(n){p=name(L,2);fd=openat(h->dir,p,O_RDONLY|O_NOFOLLOW|O_NONBLOCK|O_CLOEXEC);owned=1;
        if(fd<0)return fail(L,"sync open");
        if(!regular(fd,LIMIT)){int e=errno;close(fd);errno=e;return fail(L,"sync file");}}
    int rc=fsync(fd),e=errno;if(owned&&close(fd)<0&&rc==0){rc=-1;e=errno;}
    if(rc<0){errno=e;return fail(L,"sync");}lua_pushboolean(L,1);return 1;
}
static int rename_file(lua_State *L) {
    handle *h=live(L);const char *a=name(L,2),*b=name(L,3);
    if(strcmp(a,TEMP)||strcmp(b,MAIN))return luaL_error(L,"clock: rename names");
    if(renameat(h->dir,a,h->dir,b)<0)return fail(L,"rename");
    lua_pushboolean(L,1);return 1;
}
static double ms(struct timespec t) {return (double)t.tv_sec*1000.0+(double)t.tv_nsec/1000000.0;}
static int sample(lua_State *L) {
    struct timespec before,utc,after;
    if(clock_gettime(CLOCK_BOOTTIME,&before)||clock_gettime(CLOCK_REALTIME,&utc)||clock_gettime(CLOCK_BOOTTIME,&after))return fail(L,"sample");
    /* Outward integer rounding plus 1 ms resolution allowance on both clocks.
     * This bounds sampling quantization, NOT absolute UTC accuracy. */
    double a=floor(ms(before))-2,c=ceil(ms(after))+2,b=floor(ms(utc));
    if(a<0||c<a||c>9007199254740991.0||b<0||b>2147483647999.0)return luaL_error(L,"clock: range");
    lua_pushnumber(L,a);lua_pushnumber(L,b);lua_pushnumber(L,c);return 3;
}
static int info(lua_State *L) {
    struct timespec a,b;
    if(clock_getres(CLOCK_BOOTTIME,&a)||clock_getres(CLOCK_REALTIME,&b))return fail(L,"resolution");
    if(ms(a)<=0||ms(b)<=0||ms(a)>1||ms(b)>1)return luaL_error(L,"clock: unsupported resolution");
    lua_pushnumber(L,ms(a));lua_pushnumber(L,ms(b));return 2;
}
int luaopen_schoolbell_clock_linux(lua_State *L) {
    const luaL_Reg methods[]={{"read",read_file},{"stat",stat_file},{"unlink",unlink_file},{"write",write_file},
        {"sync",sync_file},{"rename",rename_file},{"close",close_handle},{NULL,NULL}};
    luaL_newmetatable(L,HANDLE);lua_pushcfunction(L,close_handle);lua_setfield(L,-2,"__gc");
    lua_newtable(L);luaL_register(L,NULL,methods);lua_setfield(L,-2,"__index");lua_pushliteral(L,"protected");lua_setfield(L,-2,"__metatable");lua_pop(L,1);
    const luaL_Reg api[]={{"open",open_store},{"sample",sample},{"resolution",info},{NULL,NULL}};
    lua_newtable(L);luaL_register(L,NULL,api);return 1;
}
