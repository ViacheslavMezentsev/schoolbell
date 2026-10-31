#define _GNU_SOURCE
#include <lua.h>
#include <lauxlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <dirent.h>
#include <errno.h>
#include <stdint.h>
#include <string.h>
static int err(lua_State*L){lua_pushnil(L);lua_pushinteger(L,errno);return 2;}
static int statp(lua_State*L){struct stat s;if(lstat(luaL_checkstring(L,1),&s))return err(L);lua_newtable(L);
#define NUM(k,v) lua_pushnumber(L,(lua_Number)(v));lua_setfield(L,-2,k)
 NUM("size",s.st_size);NUM("uid",s.st_uid);NUM("mode",s.st_mode&0777);lua_pushstring(L,S_ISREG(s.st_mode)?"reg":S_ISDIR(s.st_mode)?"dir":"other");lua_setfield(L,-2,"type");return 1;}
static int mkdirp(lua_State*L){if(mkdir(luaL_checkstring(L,1),0700))return err(L);lua_pushboolean(L,1);return 1;}
static int renamep(lua_State*L){if(rename(luaL_checkstring(L,1),luaL_checkstring(L,2)))return err(L);lua_pushboolean(L,1);return 1;}
static int unlinkp(lua_State*L){if(unlink(luaL_checkstring(L,1)))return err(L);lua_pushboolean(L,1);return 1;}
static int rmdirp(lua_State*L){if(rmdir(luaL_checkstring(L,1)))return err(L);lua_pushboolean(L,1);return 1;}
static int list(lua_State*L){DIR*d=opendir(luaL_checkstring(L,1));if(!d)return err(L);struct dirent*e;int i=0;lua_newtable(L);while((e=readdir(d))){if(!strcmp(e->d_name,".")||!strcmp(e->d_name,".."))continue;if(i==512){closedir(d);return luaL_error(L,"directory quota");}lua_pushstring(L,e->d_name);lua_rawseti(L,-2,++i);}closedir(d);return 1;}
static int syncp(lua_State*L){int fd=open(luaL_checkstring(L,1),O_RDONLY|O_NOFOLLOW|O_CLOEXEC);if(fd<0)return err(L);int rc=fsync(fd),saved=errno;close(fd);errno=saved;if(rc)return err(L);lua_pushboolean(L,1);return 1;}
static int space(lua_State*L){struct statvfs s;if(statvfs(luaL_checkstring(L,1),&s))return err(L);lua_pushnumber(L,(lua_Number)s.f_bavail*s.f_frsize);lua_pushnumber(L,(lua_Number)s.f_blocks*s.f_frsize);return 2;}
static int lockp(lua_State*L){int fd=open(luaL_checkstring(L,1),O_RDWR|O_CREAT|O_NOFOLLOW|O_CLOEXEC,0600);if(fd<0)return err(L);if(lockf(fd,F_TLOCK,0)){close(fd);return err(L);}lua_pushinteger(L,fd);return 1;}
static int unlock(lua_State*L){int fd=luaL_checkint(L,1);if(close(fd))return err(L);lua_pushboolean(L,1);return 1;}
static int bxor(lua_State*L){lua_pushnumber(L,(uint32_t)luaL_checknumber(L,1)^(uint32_t)luaL_checknumber(L,2));return 1;}
static int band(lua_State*L){lua_pushnumber(L,(uint32_t)luaL_checknumber(L,1)&(uint32_t)luaL_checknumber(L,2));return 1;}
int luaopen_schoolbell_media_fs_host(lua_State*L){const luaL_Reg f[]={{"bxor",bxor},{"band",band},{"stat",statp},{"mkdir",mkdirp},{"rename",renamep},{"unlink",unlinkp},{"rmdir",rmdirp},{"list",list},{"sync",syncp},{"space",space},{"lock",lockp},{"unlock",unlock},{NULL,NULL}};lua_newtable(L);luaL_register(L,NULL,f);return 1;}
