#define _GNU_SOURCE
#include <signal.h>
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
int main(int argc,char **argv) {
    char bytes[64]={0};
    struct timespec wait={0,100000000};
    if (argc!=2) return 90;
    /* Apart from standard streams only the inherited resource lock survives exec. */
    DIR *directory=opendir("/proc/self/fd");
    if (!directory) return 95;
    unsigned extra=0;
    struct dirent *entry;
    while ((entry=readdir(directory))) {
        char *end;
        long fd=strtol(entry->d_name,&end,10);
        if (end!=entry->d_name && !*end && fd>2 && fd!=dirfd(directory)) extra++;
    }
    closedir(directory);
    if (extra!=1) return 96;
    if (read(0,bytes,sizeof bytes)!=11 || memcmp(bytes,"schoolbell\n",11)) { nanosleep(&wait,NULL); return 91; }
    if (!strcmp(argv[1],"hold")) wait.tv_sec=1;
    if (!strcmp(argv[1],"flood")) {
        char block[4096];memset(block,'x',sizeof block);
        for (unsigned i=0;i<128;i++) {
            if (write(1,block,sizeof block)!=(ssize_t)sizeof block) return 92;
            if (write(2,block,sizeof block)!=(ssize_t)sizeof block) return 93;
        }
    }
    nanosleep(&wait,NULL);
    if (!strcmp(argv[1],"signal")) {raise(SIGTERM);return 94;}
    return !strcmp(argv[1],"exit7")?7:0;
}
