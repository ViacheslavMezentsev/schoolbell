# System clock reference adapter

Current 5.0.25 stage: [executor integration and optional control](CLOCK_EXECUTOR.en.md). Earlier stage boundaries below are historical; isolated target adapter validation passed, deployment and confirmation UI remain pending.

[Русский](CLOCK_SYSTEM.md)

Isolated Linux-host implementation: clock_system.lua and clock_linux.so, excluded from schoolbell 5.0.14 IPK and executor integration. No clock or NTP changes.

## Clock source

clock_system.new(root, context_provider [, native]) returns clock_trust ports. root explicitly names an existing private directory. The mandatory context callback supplies the current observer/boot/timezone configuration epoch, before and after each sample. Integration must update it on relevant changes; it must use cached state, without per-poll file/network/process operations. Every new trust model starts unconfirmed; context is not a portable permission token.

Native sample uses three clock_gettime calls: CLOCK_BOOTTIME → CLOCK_REALTIME → CLOCK_BOOTTIME. BOOTTIME includes suspend, exposing observation gaps, and follows frequency correction: it is not RAW. Constructor checks clock_getres for both sources; resolution above 1 ms or failure rejects the adapter without fallback to os.time.

UTC is floored to integer milliseconds; BOOTTIME bounds round outward and expand by 2 ms on each side for UTC quantization/resolution allowance. Adjacent brackets may overlap; either bound moving backward still fails. Pair/gap budgets remain 100/3000 ms, conservatively consumed by rounding. This bounds sampling alignment under the Linux resolution assumption, not absolute UTC accuracy. clock_getres alone cannot establish hardware accuracy; target clocksource validation remains required.

The adapter accepts epoch 0…2147483647999 ms (1970…2038), without promising time64 on the target's 32-bit platform. The codec retains its full 53-bit range. Later dates require libc/kernel/calendar validation. No clock_settime, adjtimex, network or shell operations.

## Storage

Component-wise openat with O_DIRECTORY/O_NOFOLLOW pins the directory. The final root must belong to effective UID and have no group/other permissions. Ancestors and same-UID processes are trusted; this is not a sandbox against the directory owner/root. No automatic mkdir/chmod/chown. Other participants must not rename the directory or delete/replace its lock during use.

Each load/save uses a stable .clock-reference.lock inode, nonblocking flock, 0600 and CLOEXEC. Only clock-reference.json and clock-reference.next are accepted. Regular files must belong to effective UID, be private, have one hard link and at most 1024 bytes. Symlinks/FIFOs/directories/oversized files and I/O errors fail, never masquerading as absence.

Reads are bounded to 1025 bytes to detect excess. O_EXCL creates the temporary file; writes handle partial results and EINTR. The existing manager drives write → file fsync → renameat → directory fsync → readback relative to the pinned directory FD. Close/GC releases ownership; close failure prevents success. No automatic retry after uncertain failure. CAS/checksum/no-fallback semantics remain in clock_reference_store.

Storage is synchronous; fsync has no guaranteed deadline. The trust model observes again after persistence and revokes admission if continuity was lost. Executor/player-wait integration is not included.

## Checks and limits

TC-126 covers real host clocks and temporary directories, roundtrip/reopen, untrusted restart, CAS, process contention, close/GC, file types/links/limits. A separate test-only build injects openat/read/write/fsync/renameat/flock/close and clock failures, partial writes and counts descriptors. Production exports no injection API. TC-125 adds overlapping-bracket coverage.

Runner: packages/schoolbell/tests/test-media-manager.sh through make all/ci-schoolbell; also make -C packages/schoolbell/native lua. Tests never set system time or access the router. Power cuts, MIPS/time32, physical flash and router resources remain unverified. Next: separately authorized isolated target check, then context/player-wait/UI integration.

Clock semantics: [Linux clock_gettime](https://man7.org/linux/man-pages/man2/clock_gettime.2.html). RAW can estimate uncorrected clock frequency, but applying it to system time must account for existing NTP correction. This adapter applies no correction.
