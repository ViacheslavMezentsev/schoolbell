#define _GNU_SOURCE
#include "player.h"
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <sys/random.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
static const char *fault;
static pid_t launched;
static int hit(const char *name) {
    if (fault && !strcmp(fault,name)) {fault=NULL;errno=EIO;return 1;}
    return 0;
}
ssize_t __real_getrandom(void *,size_t,unsigned);
ssize_t __wrap_getrandom(void *p,size_t n,unsigned f) {
    if (hit("random")) return -1;
    if (hit("short_random")) return 3;
    return __real_getrandom(p,n,f);
}
int __real_pipe2(int *,int);
int __wrap_pipe2(int *p,int flags) {
    if (hit("pipe")) {errno=EMFILE;return -1;}
    return __real_pipe2(p,flags);
}
pid_t __real_fork(void);
pid_t __wrap_fork(void) {
    if (hit("fork")) {errno=EAGAIN;return -1;}
    pid_t p=__real_fork();if (p>0) launched=p;return p;
}
int __real_clock_gettime(clockid_t,struct timespec *);
int __wrap_clock_gettime(clockid_t id,struct timespec *t) {
    if (hit("clock")) return -1;
    return __real_clock_gettime(id,t);
}
ssize_t __real_read(int,void *,size_t);
ssize_t __wrap_read(int fd,void *buffer,size_t n) {
    if (hit("read")) return -1;
    if (hit("broken")) {assert(n>=3);memcpy(buffer,"BAD",3);return 3;}
    if (hit("eof")) return 0;
    return __real_read(fd,buffer,n);
}
pid_t __real_waitpid(pid_t,int *,int);
pid_t __wrap_waitpid(pid_t pid,int *status,int options) {
    if (hit("wait")) {errno=ECHILD;return -1;}
    return __real_waitpid(pid,status,options);
}
int __real_close(int);
int __wrap_close(int fd) {
    if (hit("close")) {int rc=__real_close(fd);assert(rc==0);errno=EINTR;return -1;}
    return __real_close(fd);
}
static int yes(void *unused) {(void)unused;return 1;}
static void pause_ms(void) {struct timespec t={0,1000000};nanosleep(&t,NULL);}
static sbp_result observe(sbp *p,sbp_handle h) {
    sbp_result r;
    for (unsigned i=0;i<3000;i++) {
        assert(sbp_poll(p,h,&r)==0);assert(r.calls<=8);
        if (r.state==SBP_TERMINAL) {
            sbp_result freed;
            if (sbp_release(p,h,&freed)==0) return r;
            assert(!strcmp(freed.error,"busy"));
        }
        pause_ms();
    }
    assert(!"timeout");return r;
}
int main(int argc,char **argv) {
    assert(argc==3);alarm(15);
    int exe=open(argv[1],O_RDONLY|O_CLOEXEC);
    int directory=open(argv[2],O_RDONLY|O_DIRECTORY|O_CLOEXEC);
    int media=openat(directory,"media",O_RDONLY|O_CLOEXEC);
    const char *args[]={"fixture","hold",NULL};
    sbp_options o={100,2,1,{"fault"},exe,directory,args};
    sbp_result r;sbp_handle h;
    fault="random";assert(sbp_create(&o)==NULL);
    fault="short_random";assert(sbp_create(&o)==NULL && errno==EIO);
    for (unsigned i=0;i<3;i++) {
        const char *failures[]={"pipe","clock","fork"};
        sbp *p=sbp_create(&o);assert(p);
        fault=failures[i];launched=0;
        assert(sbp_begin(p,0,media,yes,NULL,&h,&r)<0);
        assert(r.outcome==SBP_NOT_STARTED && launched==0 && r.calls<=64);
        assert(sbp_destroy(p)==0);
    }
    puts("PASS linux faults: random/pipe/clock/fork fail without child or retry");
    {
        sbp *p=sbp_create(&o);assert(p);
        assert(sbp_begin(p,0,media,yes,NULL,&h,&r)==0);
        fault="read";assert(sbp_poll(p,h,&r)==0);
        assert(r.state==SBP_UNCERTAIN && !strcmp(r.error,"observe_failed"));
        assert(sbp_release(p,h,&r)<0);
        r=observe(p,h);assert(r.outcome==SBP_EXIT);
        assert(sbp_destroy(p)==0);
    }
    puts("PASS linux faults: transient read failure cannot release live child");
    {
        sbp *p=sbp_create(&o);assert(p);
        assert(sbp_begin(p,0,media,yes,NULL,&h,&r)==0);
        fault="broken";assert(sbp_poll(p,h,&r)==0);
        fault="eof";assert(sbp_poll(p,h,&r)==0);
        assert(!strcmp(r.error,"protocol_error"));
        r=observe(p,h);assert(r.outcome==SBP_EXIT);
        assert(!strcmp(r.error,"protocol_error"));
        assert(sbp_destroy(p)==0);
    }
    puts("PASS linux faults: truncated frame preserves protocol failure through exit");
    {
        sbp *p=sbp_create(&o);assert(p);
        assert(sbp_begin(p,0,media,yes,NULL,&h,&r)==0);
        for (unsigned i=0;i<3000;i++) {
            assert(sbp_poll(p,h,&r)==0);
            if (r.state==SBP_TERMINAL) break;
            pause_ms();
        }
        assert(r.state==SBP_TERMINAL);
        /* Drain EOF before exercising consumed-descriptor close error. */
        assert(sbp_poll(p,h,&r)==0);
        fault="close";assert(sbp_release(p,h,&r)<0);
        assert(!strcmp(r.error,"cleanup_failed"));
        assert(sbp_release(p,h,&r)==0);assert(sbp_destroy(p)==0);
    }
    puts("PASS linux faults: close EINTR consumes FD, no retry on reused number");
    {
        /* Deliberately unverifiable ownership stays blocked; run in an isolated
         * test process so OS teardown can clean the quarantined instance. */
        pid_t tester=__real_fork();assert(tester>=0);
        if (!tester) {
            sbp *p=sbp_create(&o);assert(p);
            assert(sbp_begin(p,0,media,yes,NULL,&h,&r)==0);
            pid_t child=launched;
            fault="wait";assert(sbp_poll(p,h,&r)==0);
            assert(r.state==SBP_UNCERTAIN);
            assert(sbp_release(p,h,&r)<0);
            int status;
            assert(__real_waitpid(child,&status,0)==child);
            assert(sbp_poll(p,h,&r)==0 && r.state==SBP_UNCERTAIN);
            assert(sbp_destroy(p)<0);_exit(0);
        }
        int status;assert(__real_waitpid(tester,&status,0)==tester);
        assert(WIFEXITED(status)&&WEXITSTATUS(status)==0);
    }
    puts("PASS linux faults: lost wait ownership quarantines handle, no false release");
    close(media);close(directory);close(exe);
    return 0;
}
