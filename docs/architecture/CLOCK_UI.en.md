# Time confirmation and native dependency

Installed 5.0.27 with native clock1.0.0: real mailbox contention and browser confirmation verified. Control enabled, time confirmed, automatic bells disabled; clocks/NTP unchanged.

5.0.27: clock-result lock contention is pending, not failure; bounded GET waiting, no POST replay. Storage errors are distinct from busy.

While the worker holds the mailbox lock through a commit, poll returns ok/pending/waiting=writer. The client also tolerates legacy busy GET responses within the same 18-second polling budget. A busy POST was not accepted and is never retried automatically. Real I/O/JSON failures return mailbox_storage, not busy.

[Русский](CLOCK_UI.md)

Schoolbell 5.0.26 is host-tested, not installed on the router. Settings now show a
time-review panel after timezone selection. Request a fresh snapshot, compare its
date/time and explicitly confirm within 15 seconds. An earlier reference requires
an additional rollback checkbox. This is a user assertion, not UTC measurement or
synchronization. Confirmation and policy changes disable automatic bells; activate
the saved plan separately. The worker performs a fresh admission check.

The explicit bypass persists with a warning. Re-enabling control or restarting the
worker requires new confirmation. The Russian button label is now «Без звука»;
Mute behavior and independent manual playback remain unchanged. No clock/NTP/mixer
configuration changes are made.

LuCI session cookie and form CSRF protect POST (1024 bytes). GET only polls results.
Actions are prepare/confirm/policy/enable; operation IDs are 32 hex and ownership is
the session SHA-256. The actual opaque token stays in the worker and dies on restart.
Private /tmp/schoolbell-clock-control holds one request and last result, each <=4096
bytes. Process at most one command per pass, including player waits; reject requests
older than 15 seconds. An outcome_unknown tombstone precedes side effects, preventing
replay after interruption. Another operation may evict the last result. HTTP requests
have an 8-second timeout, polling lasts 18 seconds plus its last request; POST is never
retried automatically. On unknown outcome, refresh state before another change.

/etc/schoolbell-editor/clock-policy.json holds only boolean enforced (<=256 bytes),
absent defaults true. Persist pending/fsync, next/fsync/rename/directory fsync/readback,
then remove pending and fsync. Errors block admission; remaining pending blocks bypass
on restart. Policy is excluded from SBB. The 5.0.25 pre-deployment path was revised;
unknown files at the former path are not silently imported. Disabling never advances
the watermark with untrusted time. The worker validates fresh admission, draft and
media before activation. Confirmation/policy changes are journaled.

Build with `scripts/build-schoolbell-clock.py --cc CC --include LUA_HEADERS --out OUT`
using the selected MIPS/musl cross-compiler and Lua 5.1 headers. Multiple include paths
are supported. Direct compilation does not build OpenWrt/SDK. Verify ELF32 LE MIPS;
ELF shape alone does not prove libc ABI compatibility. Debian headers may need their
multiarch macro header; never substitute host libc headers for target toolchain headers.

Output: modbus-schoolbell-clock_1.0.0_mipsel_24kc.ipk (libc/libgcc1/liblua5.1.5 dependencies),
/usr/lib/lua/schoolbell/clock_linux.so and SHA-256 manifest. The separate engineering
payload declares dependencies.json. No binary is committed. The normal schoolbell
IPK remains a media-only preview, not an installer for the whole engineering payload.
Other targets need their own ABI build/load verification.

Host tests cover token ownership/expiry/restart, separate activation, storage failures,
mailbox deduplication/interruption, HTTP session/CSRF/bounds and UI network recovery.
MIPS cross-build is verified on host, without router installation or sound. Next:
separately authorized dependency/payload installation and confirmation/restart/bypass
checks on hardware while automatic bells remain disabled.
