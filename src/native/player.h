#ifndef SCHOOLBELL_PLAYER_H
#define SCHOOLBELL_PLAYER_H
#include <stdint.h>
#include <sys/types.h>
/* Host-only standalone C adapter. Single-threaded owner; no competing reaper.
 * Caller supplies a trusted immutable executable/profile, private lock directory,
 * and regular immutable media. No device path or shell command is accepted. */
typedef struct sbp sbp;
typedef struct { uint64_t owner; uint32_t attempt; unsigned slot; } sbp_handle;
typedef enum { SBP_LAUNCHING, SBP_RUNNING, SBP_TERMINAL, SBP_UNCERTAIN } sbp_state;
typedef enum { SBP_PENDING, SBP_CONFIRMED, SBP_FAILED, SBP_UNKNOWN } sbp_exec;
typedef enum { SBP_NO_OUTCOME, SBP_NOT_STARTED, SBP_EXIT, SBP_SIGNAL, SBP_OUTCOME_UNKNOWN } sbp_outcome;
typedef struct {
    char generation[33];
    uint32_t attempt;
    sbp_state state;
    sbp_exec exec_status;
    sbp_outcome outcome;
    int exit_code, signal; /* meaningful only for the matching outcome */
    const char *error, *stage;
    int error_number; /* 0 means absent */
    int launch_timeout, cleanup_pending;
    unsigned calls; /* operations in the most recent public call */
} sbp_result;
typedef struct {
    unsigned timeout_ms, max_records, resource_count;
    const char *resources[4];
    int executable_fd, lock_directory_fd;
    const char *const *argv; /* trusted profile, max 16 args, 2048 total bytes */
} sbp_options;
typedef int (*sbp_permit)(void *); /* pure, bounded, returns 1 to authorize */
/* init reports errno, never substitutes PID/time for random generation. */
sbp *sbp_create(const sbp_options *);
int sbp_begin(sbp *, unsigned resource, int media_fd, sbp_permit, void *,
              sbp_handle *, sbp_result *);
int sbp_poll(sbp *, sbp_handle, sbp_result *);
int sbp_release(sbp *, sbp_handle, sbp_result *);
int sbp_destroy(sbp *); /* refuses while a possible child/undrained result exists */
#endif
