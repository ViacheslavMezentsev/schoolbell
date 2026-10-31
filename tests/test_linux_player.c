#define _GNU_SOURCE
#include "player.h"
#include <assert.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/prctl.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
static int directory, executable, media;
static int yes(void *unused) {(void)unused;return 1;}
static int no(void *unused) {(void)unused;return 0;}
static void delay(void) {struct timespec t={0,1000000};nanosleep(&t,NULL);}
static sbp *create(const char *mode,unsigned records) {
    const char *argv[]={"player-test-child",mode,NULL};
    sbp_options o={2000,records,2,{"speaker","other"},executable,directory,argv};
    sbp *p=sbp_create(&o);assert(p);return p;
}
static sbp_handle start(sbp *p,unsigned resource) {
    sbp_handle h;sbp_result r;
    assert(sbp_begin(p,resource,media,yes,NULL,&h,&r)==0);
    assert(r.state==SBP_LAUNCHING);assert(r.calls<=64);
    assert(strlen(r.generation)==32);return h;
}
static sbp_result finish(sbp *p,sbp_handle h) {
    sbp_result r;
    for (unsigned i=0;i<6000;i++) {
        assert(sbp_poll(p,h,&r)==0);assert(r.calls<=8);
        if (r.state==SBP_TERMINAL) {
            sbp_result released;
            if (sbp_release(p,h,&released)==0) {assert(released.calls<=8);return r;}
            assert(!strcmp(released.error,"busy"));
        }
        delay();
    }
    assert(!"child did not finish");return r;
}
static unsigned fd_count(void) {
    unsigned n=0;DIR *d=opendir("/proc/self/fd");struct dirent *entry;
    assert(d);while ((entry=readdir(d))) if (entry->d_name[0]!='.') n++;
    closedir(d);return n;
}
static void outcomes(void) {
    const char *modes[]={"ok","exit7","signal","flood"};
    for (unsigned i=0;i<4;i++) {
        sbp *p=create(modes[i],4);sbp_handle h=start(p,0);sbp_result r;
        int confirmed=0;
        for (unsigned k=0;k<100;k++) {
            assert(sbp_poll(p,h,&r)==0);
            if (r.exec_status==SBP_CONFIRMED) {confirmed=1;break;}
            delay();
        }
        assert(confirmed);assert(r.state==SBP_RUNNING);
        assert(sbp_release(p,h,&r)<0 && !strcmp(r.error,"not_terminal"));
        r=finish(p,h);
        if (i==2) {assert(r.outcome==SBP_SIGNAL && r.signal==SIGTERM);}
        else {assert(r.outcome==SBP_EXIT && r.exit_code==(i==1?7:0));}
        assert(sbp_poll(p,h,&r)<0 && !strcmp(r.error,"stale_handle"));
        assert(sbp_destroy(p)==0);
    }
    puts("PASS linux player: exec identity, stdin, exit, signal and discarded flood");
}
static void quotas_and_ownership(void) {
    sbp *a=create("ok",1),*b=create("ok",2);
    sbp_handle h=start(a,0),other;sbp_result r;
    assert(sbp_poll(b,h,&r)<0 && !strcmp(r.error,"invalid_handle"));
    assert(sbp_begin(a,1,media,yes,NULL,&other,&r)<0 && !strcmp(r.error,"limit"));
    assert(sbp_begin(b,0,media,yes,NULL,&other,&r)<0 && !strcmp(r.error,"busy"));
    assert(sbp_destroy(a)<0 && errno==EBUSY);
    other=start(b,1);finish(a,h);finish(b,other);
    assert(sbp_destroy(a)==0);assert(sbp_destroy(b)==0);
    puts("PASS linux player: per-resource flock, independent resource, record limits and foreign handles");
}
static void rejected(void) {
    sbp *p=create("ok",4);sbp_handle h;sbp_result r;
    unsigned baseline=fd_count();
    assert(sbp_begin(p,0,media,no,NULL,&h,&r)<0 && !strcmp(r.error,"permit_denied"));
    assert(r.outcome==SBP_NOT_STARTED);assert(fd_count()==baseline);
    assert(sbp_begin(p,0,directory,yes,NULL,&h,&r)<0 && !strcmp(r.error,"media_invalid"));
    assert(fd_count()==baseline);
    assert(sbp_destroy(p)==0);
    puts("PASS linux player: permit denial and non-regular media with complete cleanup");
}
static void lock_symlink(void) {
    const char *args[]={"fixture","ok",NULL};
    sbp_options o={2000,2,1,{"symlink-lock"},executable,directory,args};
    assert(symlinkat("media",directory,"symlink-lock")==0);
    sbp *p=sbp_create(&o);assert(p);
    sbp_handle h;sbp_result r;
    assert(sbp_begin(p,0,media,yes,NULL,&h,&r)<0);
    assert(r.error_number==ELOOP && r.outcome==SBP_NOT_STARTED);
    assert(sbp_destroy(p)==0);
    puts("PASS linux player: symlink lock rejected without following it");
}
static void bad_exec(void) {
    int saved=executable;
    executable=openat(directory,"invalid-exec",O_CREAT|O_RDWR|O_TRUNC,0700);assert(executable>=0);
    assert(write(executable,"not an executable",17)==17);close(executable);
    executable=openat(directory,"invalid-exec",O_RDONLY);assert(executable>=0);
    sbp *p=create("ok",2);sbp_handle h=start(p,0);
    sbp_result r=finish(p,h);
    assert(r.exec_status==SBP_FAILED && r.outcome==SBP_NOT_STARTED);
    assert(!strcmp(r.error,"exec_failed") && r.error_number==ENOEXEC);
    assert(sbp_destroy(p)==0);close(executable);executable=saved;
    puts("PASS linux player: actual exec failure frame and reaping");
}
static void inherited_lock(void) {
    pid_t owner;int status;
    /* Become the reaper of the fixture grandchild after owner exits. */
    assert(prctl(PR_SET_CHILD_SUBREAPER,1)==0);
    owner=fork();assert(owner>=0);
    if (!owner) {
        sbp *p=create("hold",2);sbp_handle h=start(p,0);sbp_result r;
        for (unsigned i=0;i<1000;i++) {
            assert(sbp_poll(p,h,&r)==0);
            if (r.exec_status==SBP_CONFIRMED) _exit(0); /* deliberate owner crash */
            delay();
        }
        _exit(99);
    }
    assert(waitpid(owner,&status,0)==owner && WIFEXITED(status) && WEXITSTATUS(status)==0);
    sbp *p=create("ok",2);sbp_handle h;sbp_result r;
    assert(sbp_begin(p,0,media,yes,NULL,&h,&r)<0 && !strcmp(r.error,"busy"));
    /* Only the orphan test child remains; no player-owned live child in this p. */
    assert(waitpid(-1,&status,0)>0 && WIFEXITED(status) && WEXITSTATUS(status)==0);
    h=start(p,0);finish(p,h);assert(sbp_destroy(p)==0);
    puts("PASS linux player: inherited lock survives owner death, new work after child exit");
}
static void leaked_descriptors(void) {
    unsigned before=fd_count();
    for (unsigned i=0;i<12;i++) {
        sbp *p=create("ok",2);sbp_handle h=start(p,0);finish(p,h);assert(sbp_destroy(p)==0);
    }
    assert(fd_count()==before);
    puts("PASS linux player: repeated lifecycle retains no descriptors");
}
static void inventory_limit(void) {
    int fds[40];sbp *p=create("ok",2);sbp_handle h;sbp_result r;
    for (unsigned i=0;i<40;i++) {fds[i]=open("/dev/null",O_RDONLY);assert(fds[i]>=0);}
    assert(sbp_begin(p,0,media,yes,NULL,&h,&r)<0 && !strcmp(r.error,"limit"));
    assert(r.calls<=64);
    for (unsigned i=0;i<40;i++) close(fds[i]);
    h=start(p,0);finish(p,h);assert(sbp_destroy(p)==0);
    puts("PASS linux player: inherited FD inventory rejected before fork when over bound");
}
int main(int argc,char **argv) {
    assert(argc==3);
    alarm(20);
    executable=open(argv[1],O_RDONLY|O_CLOEXEC);assert(executable>=0);
    directory=open(argv[2],O_RDONLY|O_DIRECTORY|O_CLOEXEC);assert(directory>=0);
    media=openat(directory,"media",O_CREAT|O_RDWR|O_TRUNC|O_CLOEXEC,0600);assert(media>=0);
    assert(write(media,"schoolbell\n",11)==11); /* original offset deliberately at EOF */
    outcomes();quotas_and_ownership();rejected();lock_symlink();bad_exec();inherited_lock();
    leaked_descriptors();inventory_limit();
    close(media);close(directory);close(executable);
    puts("PASS linux player: all host checks; no audio device");
    return 0;
}
