#define _GNU_SOURCE
#include "player.h"
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <signal.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/random.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define MAX_RECORDS 128
#define MAX_FDS 32
#define MAX_MS UINT64_C(9007199254740991)
typedef struct {
    int used, reaped, lost, eof, protocol, frame;
    int lock_fd, media_fd, null_fd, pipe_r, pipe_w;
    pid_t pid;
    uint64_t deadline;
    unsigned char bytes[16];
    unsigned length;
    sbp_outcome observed;
    int observed_code, observed_signal;
    sbp_result result;
} job;
struct sbp {
    uint64_t owner;
    uint32_t next_attempt;
    int executable_fd, directory_fd, busy;
    uint64_t last_clock;
    struct stat executable;
    unsigned timeout, maximum, resource_count;
    char resources[4][65], generation[33];
    int resource_slot[4];
    unsigned job_resource[MAX_RECORDS];
    char *argv[17], arg_storage[2048];
    char exec_path[64];
    job jobs[MAX_RECORDS];
};
static uint64_t owner_sequence;
struct linux_dirent64 {
    uint64_t ino;
    int64_t off;
    unsigned short reclen;
    unsigned char type;
    char name[];
};
static void error_result(sbp_result *r, const char *code, const char *stage, int e) {
    r->error=code; r->stage=stage; r->error_number=e;
}
static int reject(sbp_result *r, const char *code, const char *stage, int e) {
    error_result(r,code,stage,e); return -1;
}
static void uncertain(job *j, const char *code, const char *stage, int e) {
    j->result.state=SBP_UNCERTAIN;
    j->result.outcome=SBP_OUTCOME_UNKNOWN;
    error_result(&j->result,code,stage,e);
}
static int valid_id(const char *s) {
    size_t n;
    if (!s || !(n=strnlen(s,65)) || n>64) return 0;
    for (size_t i=0;i<n;i++)
        if (!((s[i]>='a'&&s[i]<='z')||(s[i]>='A'&&s[i]<='Z')||
              (s[i]>='0'&&s[i]<='9')||s[i]=='_'||s[i]=='-')) return 0;
    return 1;
}
static int mono(sbp *p, uint64_t *ms, unsigned *calls) {
    struct timespec ts;
    ++*calls;
    if (clock_gettime(CLOCK_MONOTONIC,&ts)<0) return -1;
    if (ts.tv_sec<0 || (uint64_t)ts.tv_sec>MAX_MS/1000) {errno=ERANGE;return -1;}
    *ms=(uint64_t)ts.tv_sec*1000+(unsigned long)ts.tv_nsec/1000000;
    if (*ms>MAX_MS || *ms<p->last_clock) {errno=ERANGE;return -1;}
    p->last_clock=*ms;return 0;
}
/* Linux close consumes ownership even on EINTR: never retry a reused fd. */
static int close_owned(int *fd, unsigned *calls) {
    int old=*fd;
    if (old<0) return 0;
    *fd=-1; ++*calls;return close(old);
}
static int clean(job *j, unsigned *calls, unsigned maximum) {
    int *fds[]={&j->pipe_w,&j->pipe_r,&j->media_fd,&j->null_fd,&j->lock_fd};
    int failed=0;
    for (unsigned i=0;i<5;i++) {
        if (*fds[i]>=0 && *calls<maximum)
            if (close_owned(fds[i],calls)<0) {
                error_result(&j->result,"cleanup_failed","cleanup",errno);failed=1;
            }
    }
    j->result.cleanup_pending=0;
    for (unsigned i=0;i<5;i++) if (*fds[i]>=0) j->result.cleanup_pending=1;
    return failed || j->result.cleanup_pending ? -1:0;
}
static int regular(int fd, struct stat *st, unsigned *calls) {
    ++*calls;
    if (fstat(fd,st)<0) return -1;
    if (!S_ISREG(st->st_mode)) {errno=EINVAL;return -1;}
    return 0;
}
sbp *sbp_create(const sbp_options *o) {
    sbp *p;
    unsigned char random[16];
    unsigned calls=0;
    size_t used=0;
    struct stat directory;
    if (!o || o->timeout_ms<100 || o->timeout_ms>60000 ||
        !o->max_records || o->max_records>128 ||
        !o->resource_count || o->resource_count>4 || !o->argv || !o->argv[0]) {
        errno=EINVAL;return NULL;
    }
    for (unsigned i=0;i<o->resource_count;i++) {
        if (!valid_id(o->resources[i])) {errno=EINVAL;return NULL;}
        for (unsigned k=0;k<i;k++)
            if (!strcmp(o->resources[i],o->resources[k])) {errno=EINVAL;return NULL;}
    }
    if (owner_sequence==UINT64_MAX) {errno=EOVERFLOW;return NULL;}
    p=calloc(1,sizeof *p);
    if (!p) return NULL;
    p->executable_fd=-1;p->directory_fd=-1;
    for (unsigned i=0;i<16;i++) {
        size_t n;
        if (!o->argv[i]) break;
        n=strnlen(o->argv[i],sizeof p->arg_storage)+1;
        if (n>sizeof p->arg_storage-used) {errno=E2BIG;goto bad;}
        p->argv[i]=p->arg_storage+used;memcpy(p->argv[i],o->argv[i],n);used+=n;
        if (i==15 && o->argv[16]) {errno=E2BIG;goto bad;}
    }
    {
        ssize_t n=getrandom(random,sizeof random,GRND_NONBLOCK);
        if (n!=(ssize_t)sizeof random) {if (n>=0) errno=EIO;goto bad;}
    }
    for (unsigned i=0;i<16;i++) snprintf(p->generation+i*2,3,"%02x",random[i]);
    if (regular(o->executable_fd,&p->executable,&calls)<0) goto bad;
    if (fstat(o->lock_directory_fd,&directory)<0) goto bad;
    if (!S_ISDIR(directory.st_mode) || directory.st_uid!=geteuid() ||
        (directory.st_mode&0022)) {errno=EACCES;goto bad;}
    p->executable_fd=fcntl(o->executable_fd,F_DUPFD_CLOEXEC,3);
    if (p->executable_fd<0) goto bad;
    p->directory_fd=fcntl(o->lock_directory_fd,F_DUPFD_CLOEXEC,3);
    if (p->directory_fd<0) goto bad;
    snprintf(p->exec_path,sizeof p->exec_path,"/proc/self/fd/%d",p->executable_fd);
    p->owner=++owner_sequence;
    p->timeout=o->timeout_ms;p->maximum=o->max_records;p->resource_count=o->resource_count;
    for (unsigned i=0;i<o->resource_count;i++) {
        strcpy(p->resources[i],o->resources[i]);p->resource_slot[i]=-1;
    }
    return p;
bad: {
    int e=errno;
    if (p->executable_fd>=0) close(p->executable_fd);
    if (p->directory_fd>=0) close(p->directory_fd);
    free(p);errno=e;return NULL;
}}
/* Bounded inventory before fork. Single-threaded caller must not open/close FDs
 * in signal handlers. All child closing work is planned, never scan to rlimit. */
static int inventory(int *fds, unsigned *count, unsigned *calls) {
    union { uint64_t alignment; char bytes[4096]; } buffer;
    char *data=buffer.bytes;
    int fd;
    ssize_t n,tail;
    ++*calls;fd=open("/proc/self/fd",O_RDONLY|O_DIRECTORY|O_CLOEXEC);
    if (fd<0) return -1;
    ++*calls;n=syscall(SYS_getdents64,fd,data,sizeof buffer.bytes);
    if (n<0) {int e=errno;close_owned(&fd,calls);errno=e;return -1;}
    *count=0;
    for (size_t at=0;at<(size_t)n;) {
        struct linux_dirent64 *d=(void *)(data+at);
        char *end;long v;
        if (n-(ssize_t)at<(ssize_t)offsetof(struct linux_dirent64,name)+1 ||
            d->reclen<offsetof(struct linux_dirent64,name)+1 ||
            d->reclen>(size_t)n-at ||
            !memchr(d->name,0,d->reclen - offsetof(struct linux_dirent64,name))) {
            close_owned(&fd,calls);errno=EPROTO;return -1;
        }
        v=strtol(d->name,&end,10);
        if (end!=d->name && !*end && v>=0 && v<=INT_MAX && v!=fd) {
            if (*count==MAX_FDS) {close_owned(&fd,calls);errno=EMFILE;return -1;}
            fds[(*count)++]=(int)v;
        }
        at+=d->reclen;
    }
    ++*calls;tail=syscall(SYS_getdents64,fd,data,sizeof buffer.bytes);
    {int e=errno;close_owned(&fd,calls);errno=e;}
    if (tail!=0) {if (tail>0) errno=EMFILE;return -1;}
    return 0;
}
static void child_error(int fd, unsigned stage, int e, unsigned *calls) {
    unsigned char frame[16]={'S','B','P','E',1,1,0,0,0,0,0,0,0,0,0,0};
    if (e>0 && e<=4095 && *calls<63) {
        frame[7]=(unsigned char)stage;frame[10]=(unsigned char)(e>>8);frame[11]=(unsigned char)e;
        ++*calls;
        if (write(fd,frame,sizeof frame)!=(ssize_t)sizeof frame) {
            /* Do not fabricate success or retry a partial control frame. */
        }
    }
    ++*calls;_exit(127);
}
static void child_run(sbp *p,job *j,const int *fds,unsigned nfds) {
    unsigned calls=0;
    struct sigaction action;
    sigset_t empty;
    char *env[]={"PATH=/usr/bin:/bin","LC_ALL=C",NULL};
    const int sigs[]={SIGPIPE,SIGINT,SIGTERM,SIGCHLD};
    memset(&action,0,sizeof action);action.sa_handler=SIG_DFL;
    sigemptyset(&action.sa_mask);sigemptyset(&empty);
    for (unsigned i=0;i<4;i++) {
        ++calls;if (sigaction(sigs[i],&action,NULL)<0) child_error(j->pipe_w,5,errno,&calls);
    }
    ++calls;if (sigprocmask(SIG_SETMASK,&empty,NULL)<0) child_error(j->pipe_w,5,errno,&calls);
    ++calls;if (dup2(j->media_fd,STDIN_FILENO)<0) child_error(j->pipe_w,5,errno,&calls);
    ++calls;if (dup2(j->null_fd,STDOUT_FILENO)<0) child_error(j->pipe_w,5,errno,&calls);
    ++calls;if (dup2(j->null_fd,STDERR_FILENO)<0) child_error(j->pipe_w,5,errno,&calls);
    ++calls;if (fcntl(j->lock_fd,F_SETFD,0)<0) child_error(j->pipe_w,5,errno,&calls);
    for (unsigned i=0;i<nfds;i++) {
        int fd=fds[i];
        if (fd<=2 || fd==j->lock_fd || fd==j->pipe_w || fd==p->executable_fd) continue;
        ++calls;if (close(fd)<0) child_error(j->pipe_w,10,errno,&calls);
    }
    ++calls;execve(p->exec_path,p->argv,env);
    child_error(j->pipe_w,8,errno,&calls);
}
static int lookup(sbp *p,sbp_handle h,job **out,sbp_result *r) {
    if (!p || h.owner!=p->owner || h.slot>=p->maximum)
        return reject(r,"invalid_handle","validate",0);
    job *j=&p->jobs[h.slot];
    if (!j->used || j->result.attempt!=h.attempt)
        return reject(r,"stale_handle","validate",0);
    *out=j;return 0;
}
int sbp_begin(sbp *p,unsigned resource,int media_fd,sbp_permit permit,void *arg,
              sbp_handle *h,sbp_result *out) {
    job *j;unsigned slot,calls=0,nfds=0;
    int fds[MAX_FDS],ends[2],e=0;
    const char *code="spawn_failed",*stage="media";
    struct stat media,opened,lock;
    struct sigaction action;
    uint64_t now;
    char path[64];
    if (!out) {errno=EINVAL;return -1;}
    memset(out,0,sizeof *out);
    if (!p || !h || !permit || resource>=p->resource_count)
        return reject(out,"invalid_argument","validate",0);
    if (p->busy) return reject(out,"busy","validate",0);
    if (p->resource_slot[resource]>=0) return reject(out,"busy","lock",0);
    for (slot=0;slot<p->maximum && p->jobs[slot].used;slot++) {}
    if (slot==p->maximum || p->next_attempt==UINT32_MAX)
        return reject(out,"limit","validate",0);
    j=&p->jobs[slot];memset(j,0,sizeof *j);
    j->lock_fd=j->media_fd=j->null_fd=j->pipe_r=j->pipe_w=-1;
    j->used=1;j->result.attempt=++p->next_attempt;
    memcpy(j->result.generation,p->generation,33);
    j->result.state=SBP_LAUNCHING;j->result.exec_status=SBP_PENDING;
    j->result.cleanup_pending=1;
    p->job_resource[slot]=resource;p->resource_slot[resource]=(int)slot;p->busy=1;
    h->owner=p->owner;h->attempt=j->result.attempt;h->slot=slot;
    code="media_invalid";
    if (regular(media_fd,&media,&calls)<0) goto failed;
    snprintf(path,sizeof path,"/proc/self/fd/%d",media_fd);
    ++calls;j->media_fd=open(path,O_RDONLY|O_CLOEXEC);
    if (j->media_fd<0 || regular(j->media_fd,&opened,&calls)<0) goto failed;
    if (opened.st_dev!=media.st_dev || opened.st_ino!=media.st_ino) {errno=ESTALE;goto failed;}
    stage="lock";code="spawn_failed";
    ++calls;j->lock_fd=openat(p->directory_fd,p->resources[resource],O_RDWR|O_CREAT|O_NOFOLLOW|O_CLOEXEC,0600);
    if (j->lock_fd<0 || regular(j->lock_fd,&lock,&calls)<0) goto failed;
    /* Private directory is the trust boundary; never unlink this inode. */
    if (lock.st_nlink!=1 || (lock.st_mode&0077)) {errno=EACCES;goto failed;}
    ++calls;if (flock(j->lock_fd,LOCK_EX|LOCK_NB)<0) {code="busy";goto failed;}
    stage="stdio";++calls;j->null_fd=open("/dev/null",O_RDWR|O_CLOEXEC);
    if (j->null_fd<0) goto failed;
    stage="pipe";++calls;if (pipe2(ends,O_CLOEXEC|O_NONBLOCK)<0) goto failed;
    j->pipe_r=ends[0];j->pipe_w=ends[1];
    /* Require standard descriptors to exist: prevents dup2/pipe aliasing. */
    if (j->media_fd<3 || j->lock_fd<3 || j->null_fd<3 || j->pipe_r<3 || j->pipe_w<3) {
        code="invalid_argument";errno=EBADF;goto failed;
    }
    ++calls;if (sigaction(SIGCHLD,NULL,&action)<0) goto failed;
    if (action.sa_handler!=SIG_DFL || (action.sa_flags&SA_NOCLDWAIT)) {errno=EINVAL;goto failed;}
    if (inventory(fds,&nfds,&calls)<0) {code="limit";goto failed;}
    /* Worst-case child: 9 setup + 32 closes + exec + error write + _exit < 64.
     * Parent preparation + fork and all five failure closes also fit 64. */
    if (calls+8>64) {code="limit";errno=E2BIG;goto failed;}
    stage="permit";code="clock_error";
    if (mono(p,&now,&calls)<0) goto failed;
    if (p->timeout>MAX_MS-now) {code="limit";errno=ERANGE;goto failed;}
    j->deadline=now+p->timeout;
    if (permit(arg)!=1) {code="permit_denied";errno=0;goto failed;}
    stage="fork";code="spawn_failed";++calls;j->pid=fork();
    if (j->pid<0) goto failed;
    if (!j->pid) child_run(p,j,fds,nfds);
    /* Drop only this parent's references. No LOCK_UN on the shared description. */
    close_owned(&j->pipe_w,&calls);
    close_owned(&j->media_fd,&calls);
    close_owned(&j->null_fd,&calls);
    p->busy=0;j->result.calls=calls;*out=j->result;return 0;
failed:
    e=errno;j->reaped=1;j->eof=1;
    j->result.state=SBP_TERMINAL;j->result.exec_status=SBP_FAILED;
    j->result.outcome=SBP_NOT_STARTED;error_result(&j->result,code,stage,e);
    clean(j,&calls,64);j->result.calls=calls;*out=j->result;
    p->busy=0;
    if (!j->result.cleanup_pending) {j->used=0;p->resource_slot[resource]=-1;return -1;}
    return 0; /* retained terminal handle if cleanup ever needs continuation */
}
static void protocol(job *j) {
    j->protocol=1;j->frame=0;
    if (j->result.exec_status==SBP_FAILED || j->result.exec_status==SBP_PENDING)
        j->result.exec_status=SBP_UNKNOWN;
    uncertain(j,"protocol_error","pipe",0);
}
static void parse(job *j) {
    const unsigned char *b=j->bytes;
    unsigned e=((unsigned)b[8]<<24)|((unsigned)b[9]<<16)|((unsigned)b[10]<<8)|b[11];
    if (memcmp(b,"SBPE",4)||b[4]!=1||b[5]!=1||b[6]||
        (b[7]!=5&&b[7]!=8&&b[7]!=10)||!e||e>4095||b[12]||b[13]||b[14]||b[15]||
        j->result.exec_status==SBP_CONFIRMED) {protocol(j);return;}
    j->frame=1;j->result.exec_status=SBP_FAILED;
    error_result(&j->result,b[7]==8?"exec_failed":"spawn_failed",
                 b[7]==8?"exec":b[7]==5?"stdio":"cleanup",(int)e);
}
int sbp_poll(sbp *p,sbp_handle h,sbp_result *out) {
    job *j;unsigned calls=0;uint64_t now=0;int timed=0,bad=0;
    if (!out) {errno=EINVAL;return -1;}memset(out,0,sizeof *out);
    if (lookup(p,h,&j,out)<0) return -1;
    if (p->busy) return reject(out,"busy","observe",0);
    if (j->reaped && (j->eof||j->protocol)) {*out=j->result;out->calls=0;return 0;}
    p->busy=1;
    if (mono(p,&now,&calls)<0) {uncertain(j,"clock_error","observe",errno);bad=1;}
    else timed=1;
    if (!j->eof&&!j->protocol) {
        unsigned char bytes[16];
        ssize_t n;
        ++calls;n=read(j->pipe_r,bytes,sizeof bytes);
        if (n>0) {
            if (j->length+(unsigned)n>16) protocol(j);
            else {
                memcpy(j->bytes+j->length,bytes,(size_t)n);j->length+=(unsigned)n;
                if (j->length==16) parse(j);
            }
        } else if (!n) {
            j->eof=1;if (j->length && j->length<16) protocol(j);
        } else if (errno!=EAGAIN && errno!=EWOULDBLOCK && errno!=EINTR) {
            uncertain(j,"observe_failed","pipe",errno);bad=1;
        }
    }
    if (!j->reaped&&!j->lost&&!j->frame&&!j->protocol&&j->result.exec_status!=SBP_CONFIRMED) {
        char path[64];int fd;struct stat st;
        snprintf(path,sizeof path,"/proc/%ld/exe",(long)j->pid);
        ++calls;fd=open(path,O_PATH|O_CLOEXEC);
        if (fd>=0) {
            ++calls;
            if (fstat(fd,&st)==0 && st.st_dev==p->executable.st_dev && st.st_ino==p->executable.st_ino)
                j->result.exec_status=SBP_CONFIRMED;
            if (close_owned(&fd,&calls)<0) {uncertain(j,"cleanup_failed","cleanup",errno);bad=1;}
        }
    }
    if (!j->reaped&&!j->lost) {
        int status;pid_t pid;
        ++calls;pid=waitpid(j->pid,&status,WNOHANG);
        if (pid==j->pid) {
            j->reaped=1;
            if (WIFEXITED(status)) {j->observed=SBP_EXIT;j->observed_code=WEXITSTATUS(status);}
            else if (WIFSIGNALED(status)) {j->observed=SBP_SIGNAL;j->observed_signal=WTERMSIG(status);}
            else {j->reaped=0;j->lost=1;uncertain(j,"observe_failed","observe",0);}
        } else if (pid<0&&errno!=EINTR) {
            j->lost=1;uncertain(j,"observe_failed","observe",errno);bad=1;
        }
    }
    if (timed&&now>=j->deadline&&j->result.exec_status==SBP_PENDING) {
        j->result.launch_timeout=1;j->result.exec_status=SBP_UNKNOWN;
        uncertain(j,"launch_timeout","observe",0);
    }
    if (j->reaped) {
        j->result.state=SBP_TERMINAL;
        if (j->result.exec_status==SBP_PENDING) j->result.exec_status=SBP_UNKNOWN;
        if (j->frame) {j->result.outcome=SBP_NOT_STARTED;j->result.exit_code=0;j->result.signal=0;}
        else {j->result.outcome=j->observed;j->result.exit_code=j->observed_code;j->result.signal=j->observed_signal;}
    } else if (j->result.exec_status==SBP_CONFIRMED&&!j->protocol&&!bad&&!j->lost) {
        j->result.state=SBP_RUNNING;j->result.outcome=SBP_NO_OUTCOME;
    }
    j->result.calls=calls;*out=j->result;p->busy=0;return 0;
}
int sbp_release(sbp *p,sbp_handle h,sbp_result *out) {
    job *j;unsigned calls=0;int result;
    if (!out) {errno=EINVAL;return -1;}memset(out,0,sizeof *out);
    if (lookup(p,h,&j,out)<0) return -1;
    if (p->busy) return reject(out,"busy","cleanup",0);
    if (!j->reaped) return reject(out,"not_terminal","cleanup",0);
    if (!j->eof&&!j->protocol) return reject(out,"busy","pipe",0);
    p->busy=1;result=clean(j,&calls,8);p->busy=0;
    j->result.calls=calls;*out=j->result;
    if (result<0) return -1;
    j->used=0;p->resource_slot[p->job_resource[h.slot]]=-1;return 0;
}
int sbp_destroy(sbp *p) {
    if (!p) {errno=EINVAL;return -1;}
    if (p->busy) {errno=EBUSY;return -1;}
    for (unsigned i=0;i<p->maximum;i++) if (p->jobs[i].used) {errno=EBUSY;return -1;}
    close(p->executable_fd);close(p->directory_fd);free(p);return 0;
}
