#define _GNU_SOURCE
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <assert.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
static int deny_alloc;
static int fixture_media=-1,fixture_directory=-1;
static int drop_media_source(lua_State *L){
    (void)L;assert(fixture_media>=0);close(fixture_media);fixture_media=-1;return 0;
}
static int replace_media_path(lua_State *L){
    (void)L;assert(unlinkat(fixture_directory,"media",0)==0);
    int fd=openat(fixture_directory,"media",O_WRONLY|O_CREAT|O_EXCL|O_CLOEXEC,0600);
    assert(fd>=0 && write(fd,"replacement\n",12)==12);close(fd);return 0;
}
static void *allocator(void *ud,void *ptr,size_t old,size_t n) {
    (void)ud;
    if(!n){free(ptr);return NULL;}
    if(deny_alloc && n>old)return NULL;
    return realloc(ptr,n);
}
static int allocation_off(lua_State *L){(void)L;deny_alloc=1;return 0;}
static int allocation_on(lua_State *L){(void)L;deny_alloc=0;return 0;}
static int delay(lua_State *L){(void)L;struct timespec t={0,10000000};nanosleep(&t,NULL);return 0;}
static int count_fds(void) {
    DIR *d=opendir("/proc/self/fd");assert(d);int n=0;struct dirent *e;
    while((e=readdir(d)))if(strcmp(e->d_name,".")&&strcmp(e->d_name,".."))n++;
    closedir(d);return n;
}
static int fds(lua_State *L){lua_pushinteger(L,count_fds());return 1;}
static void number(lua_State *L,const char *key,int n){lua_pushinteger(L,n);lua_setglobal(L,key);}
int main(int argc,char **argv) {
    assert(argc==4);alarm(30);
    int baseline=count_fds();
    int executable=open(argv[1],O_RDONLY|O_CLOEXEC);
    int directory=open(argv[2],O_RDONLY|O_DIRECTORY|O_CLOEXEC);
    int media=openat(directory,"media",O_RDWR|O_CREAT|O_TRUNC|O_CLOEXEC,0600);
    int broken=openat(directory,"invalid-executable",O_RDWR|O_CREAT|O_TRUNC|O_CLOEXEC,0700);
    assert(executable>=0 && directory>=0 && media>=0 && broken>=0);
    fixture_media=media;fixture_directory=directory;
    int second=openat(directory,"media-second",O_RDWR|O_CREAT|O_TRUNC|O_CLOEXEC,0600);
    assert(second>=0 && write(second,"schoolbell2\n",12)==12);
    assert(write(media,"schoolbell\n",11)==11); /* remains at EOF */
    assert(write(broken,"not executable\n",15)==15);close(broken);
    broken=openat(directory,"invalid-executable",O_RDONLY|O_CLOEXEC);assert(broken>=0);
    lua_State *L=lua_newstate(allocator,NULL);assert(L);luaL_openlibs(L);
    number(L,"executable_fd",executable);number(L,"directory_fd",directory);
    number(L,"second_media_fd",second);number(L,"media_fd",media);number(L,"broken_fd",broken);
    lua_register(L,"drop_media_source",drop_media_source);lua_register(L,"replace_media_path",replace_media_path);
    lua_register(L,"pause",delay);lua_register(L,"fd_count",fds);
    lua_register(L,"fail_allocations",allocation_off);lua_register(L,"allow_allocations",allocation_on);
    int result=luaL_dofile(L,argv[3]);deny_alloc=0;
    if(result)fprintf(stderr,"Lua test failed: %s\n",lua_tostring(L,-1));
    lua_close(L);
    close(executable);close(directory);if(fixture_media>=0)close(fixture_media);close(second);close(broken);
    assert(count_fds()==baseline);
    int status;assert(waitpid(-1,&status,WNOHANG)==-1 && errno==ECHILD);
    return result?1:0;
}
