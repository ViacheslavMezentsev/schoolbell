# Linux player Lua binding

[Русский](LUA_PLAYER.md) · [C backend](LINUX_PLAYER.en.md) · [Spec 1.14](../requirements/TECHNICAL_SPECIFICATION.md)

The isolated Lua 5.1 module `schoolbell.player_linux` wraps `native/player.c`.
It is not connected to the queue, core, UI or IPK. Host tests run their own
fixture child only, without madplay or an audio device.

## Build and tests

Requires Linux /proc, Lua 5.1 headers/library (`liblua5.1-0-dev` on Ubuntu),
a C99 compiler, make and timeout.

```sh
make -C packages/schoolbell/native lua
sh packages/schoolbell/tests/test-lua-player.sh
make test-schoolbell
make ci-schoolbell
```

Output: `out/native-schoolbell-player/schoolbell/player_linux.so`.
Override `LUA_CFLAGS` for headers and `LUA_LIBS` for the test host link.
Missing dependencies fail rather than skip. CI installs development headers
on the host only.

## Trusted boundary

```lua
local native = require("schoolbell.player_linux")
local player = assert(native.new({
    executable_fd = trusted_executable_fd,
    lock_directory_fd = trusted_private_directory_fd,
    argv = {"fixture", "ok"},
    resources = {"speaker"},
    launch_timeout_ms = 2000, -- default; 100..60000
    max_records = 128,       -- default; 1..128
}))
local handle, err, stats = player:begin(
    {resource="speaker"}, trusted_regular_media_fd,
    function() return true end) -- pure bounded permit, no I/O/yield
local snapshot, poll_err, poll_stats = player:poll(handle)
-- Repeat poll from the owner's loop; no hidden waiting or active stop.
-- Release only after terminal and the control channel has been drained.
local ok, release_err, cleanup_stats = player:release(handle)
-- After every handle was released:
assert(player:close())
```

Use colon methods. This native boundary is not a drop-in replacement for
`player_model.new(sys,...)` or the existing queue interface.
A trusted host bootstrap supplies FDs; the module does not open user paths
or shell commands. Original FDs remain caller-owned; C obtains its own
references. The owner ensures immutable executable/media and a stable lock
inode. Full media handles and revision management are still absent.

Options/requests must be plain tables without metatables or unknown keys.
Resources form a dense array of 1..4; argv contains 1..16 nonempty NUL-free
strings within the C profile's total 2048-byte limit. Numeric strings,
fractions and NaN are rejected. FDs are integers 0..INT_MAX, not credentials.
The C backend's single-thread, SIGCHLD/reaper/FD prerequisites apply.
This is not a sandbox for untrusted Lua with debug/registry access.

## Results and ownership

Player and handles are userdata with protected metatables. Foreign/forged
handles fail; released handles are stale. Each snapshot is a fresh table
following the [result contract](PLAYER_RESULTS.en.md), omitting inapplicable
outcome/exit_code/signal/error fields. The additional third result stats.calls
counts C backend calls: begin ≤64, poll/release ≤8. Lua/GC/callback work is
outside that count; it is not a real-time guarantee.

Call errors return nil plus code/stage/optional errno. Permit exceptions or
any non-true result become permit_denied before fork; reentry from permit
returns busy. Callbacks must not modify FDs, block or yield. The child never
returns to Lua after fork.

Before fork, registry references retain both handle and owner. Losing a Lua
reference, GC or Lua allocation failure after fork cannot drop native ownership.
`player:pending()` returns a fresh list of retained handles for continued
poll/release; changing the list cannot modify state. Explicit release removes
the pin. Close refuses outstanding records; an empty owner's GC closes C state.

Retention is intentional, not automatic reap/kill. The owner must keep player,
drain pending handles and close before lua_close. Forced VM shutdown with live
records is not supported recovery: uncertain native resources remain until
process exit. ECHILD still needs separate administrative recovery.

## Verification and next step

TC-70: eight host groups cover exec/exit/signal/output flooding, snapshots/quotas,
foreign/stale handles, permit/reentry, GC/recovery, Lua OOM after fork, exec
failure, strict validation and repeated lifecycles. The C test host checks FD
balance and absence of unreaped children after VM shutdown.
This does not validate target ABI, madplay, sound, MR3020 resources or media recovery.

The next separate step is composing the Lua queue and binding with a fixture
process and trusted file storage, without core integration or sound.

Schoolbell spec 1.15: isolated bridge connects the Lua queue and Linux player; launching/finishing, signal outcomes and cleanup before the next start. Ten fixture-child host groups; no core, audio device, sound or router/IPK changes. [Queue/Linux bridge](QUEUE_LINUX.en.md).


The next isolated stage adds [exact revision retention at submit](MEDIA_ADMISSION.en.md). The optional retained_userdata argument of native begin is pinned with its handle. The old API remains compatible.
