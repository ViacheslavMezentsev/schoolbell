# Isolated Linux schoolbell player adapter

[Русский](LINUX_PLAYER.md) · [Specification 1.13](../requirements/TECHNICAL_SPECIFICATION.md)

`packages/schoolbell/native/player.c` is a standalone Linux C library.
It really creates host processes, but is not bound to Lua, the queue, core or
IPK. Tests execute a substitute program without an audio device. Madplay,
OpenWrt/MIPS and audible playback are not tested at this stage.

## Build and tests

```sh
make -C packages/schoolbell/native
sh packages/schoolbell/tests/test-linux-player.sh
make test-schoolbell
make ci-schoolbell
```

Requires Linux /proc, a C99 compiler, libc headers, make and timeout. Library
output goes to out/native-schoolbell-player; test files/binaries use a separate
mktemp directory with cleanup. The runner disables core dumps. Nothing is
copied to the router. Schoolbell CI explicitly installs gcc/libc6-dev/make.

13 groups: 8 real-process and 5 injected syscall-failure groups. Coverage includes
stdin with unchanged original FD offset, exec identity, exit/signal, large output
to /dev/null, independent resources/quota, symlink locks, owner death with a live
child, repeated FD-clean lifecycles, pre-fork FD limits, random/pipe/clock/fork/
read/wait/close failures and damaged frames. This is host TC-68/69 coverage,
not hardware acceptance.

## C boundary

`player.h` defines create, begin, poll, release and destroy. Construction receives
trusted executable and lock-directory FDs plus an argv profile; timeout 100..60000,
record limit 1..128 and resources 1..4 are explicit. Caller retains immutable
executable/media. Requests cannot specify shell commands or profiles. Argv is
bounded to 16 arguments/2048 total bytes: a defensive C-backend limit, not an
editor limit.

Begin receives a resource index, regular media FD and pure bounded permit.
The adapter reopens media through /proc/self/fd with device/inode validation
for an independent offset. It does not reopen a user pathname. Revision storage
and path validation up to the supplied FD belong to the caller. The child reads
stdin; stdout/stderr use /dev/null.

Create returns NULL/errno on failure. Successful begin/poll/release return 0;
errors return -1 with sbp_result. Successful begin supplies a handle.
No Lua userdata/binding exists: C handles contain owner/slot/attempt checked
against the instance, not credentials. C enums/numeric fields must be translated
by a future binding to Lua snapshots with inapplicable fields omitted.
In C, errno=0 means absent; exit_code/signal are meaningful only for the
matching outcome.

Generation uses 16 bytes from getrandom(GRND_NONBLOCK), without fallback.
Attempt IDs are not reused. Poll uses CLOCK_MONOTONIC and one bounded pass.
Terminal may precede channel EOF: release returns busy until further poll
drains it. Final snapshots are stable. Release sends no signals; destroy refuses
while records exist. Lost wait ownership (ECHILD) retains uncertain, with no
further PID probing and no release permission.

## Preconditions and safety limits

Use a single-threaded process with no competing reaper, SIGCHLD=SIG_DFL and no
SA_NOCLDWAIT. Standard FDs 0/1/2 must be open. Signal handlers must not mutate
the FD table or reenter the adapter. The library does not enforce these
preconditions through thread locks.

Before fork, enumerate /proc/self/fd: at most 32 FDs, otherwise reject.
The child performs native-only stream/signal setup, closes extra FDs from the
prepared list and execves through the retained executable FD. After exec,
only the inherited lock FD remains beyond standard streams; the test program
verifies this. Preparation/exec errors use an SBPE frame.

The lock directory is private, owned by the effective user, with no group/other
write permission. Lock files are regular, with no symlink/hardlink or group/other
access. Never unlink/replace them during operation. The adapter never calls
LOCK_UN: closing the parent's copy does not unlock while the child retains its
copy. Owner-death tests verify this for the fixture, not for madplay.

Parent preparation/closing fits 64 calls; poll/release fit 8. The child's static
path stays under 64 with at most 32 inventoried FDs. OS/libc execution time is not
bounded by these counts; no real-time guarantee. Linux close is not retried
after EINTR to avoid closing a reused FD. Close failure remains diagnostic;
the client explicitly completes cleanup/record release.

## Still absent

Lua binding/queue integration; target build/IPK; actual media revision retention,
atomic publication/recovery; administrative recovery after lost wait ownership.
No madplay FD/stdin validation, audio device, audible output or MR3020 latency/RAM
measurements. This backend changes neither schedules nor UI.
