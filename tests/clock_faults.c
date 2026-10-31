/* Test-only syscall failure shim. Production exports no fault controls. */
#define _GNU_SOURCE
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
static char target[32];static int countdown;
static int trip(const char *s){if(!strcmp(target,s)&&--countdown==0){errno=EIO;return 1;}return 0;}
static int test_openat(int d,const char *p,int f,...){mode_t m=0;if(f&O_CREAT){va_list a;va_start(a,f);m=(mode_t)va_arg(a,int);va_end(a);}if(trip("openat"))return -1;return openat(d,p,f,m);}
static int test_close(int fd){int rc=close(fd);if(trip("close"))return -1;return rc;}
static int test_fsync(int fd){if(trip("fsync"))return -1;return fsync(fd);}
static int test_flock(int fd,int op){if(trip("flock"))return -1;return flock(fd,op);}
static ssize_t test_read(int fd,void *b,size_t n){if(trip("read"))return -1;return read(fd,b,n);}
static ssize_t test_write(int fd,const void *b,size_t n){if(trip("write"))return -1;if(!strcmp(target,"partial")&&n>1)n=1;return write(fd,b,n);}
static int test_renameat(int a,const char *p,int b,const char *q){if(trip("renameat"))return -1;return renameat(a,p,b,q);}
static int test_clock_gettime(clockid_t id,struct timespec *t){if(trip("clock_gettime"))return -1;return clock_gettime(id,t);}
static int test_clock_getres(clockid_t id,struct timespec *t){if(trip("clock_getres"))return -1;int rc=clock_getres(id,t);if(!strcmp(target,"coarse"))t->tv_nsec=2000000;return rc;}
#define openat test_openat
#define close test_close
#define fsync test_fsync
#define flock test_flock
#define read test_read
#define write test_write
#define renameat test_renameat
#define clock_gettime test_clock_gettime
#define clock_getres test_clock_getres
#define luaopen_schoolbell_clock_linux fixture_open
#include "../src/native/clock_lua.c"
#undef luaopen_schoolbell_clock_linux
static int inject(lua_State *L){const char *p=luaL_checkstring(L,1);if(strlen(p)>=sizeof target)return luaL_error(L,"fault name");strcpy(target,p);countdown=luaL_optinteger(L,2,1);return 0;}
static int fd_count(lua_State *L){DIR *d=opendir("/proc/self/fd");int n=0;struct dirent *p;if(!d)return luaL_error(L,"proc");while((p=readdir(d)))if(p->d_name[0]!='.')n++;closedir(d);lua_pushinteger(L,n);return 1;}
int luaopen_schoolbell_clock_linux(lua_State *L){fixture_open(L);lua_pushcfunction(L,inject);lua_setfield(L,-2,"inject");lua_pushcfunction(L,fd_count);lua_setfield(L,-2,"fd_count");return 1;}
