# Isolated player codec and API model

[Русский](PLAYER_MODEL.md) · [Specification 1.12](../requirements/TECHNICAL_SPECIFICATION.md)

`packages/schoolbell/lua/schoolbell/player_codec.lua` and `player_model.lua`
are pure Lua 5.1 modules with no default backend. They open no files, create no
processes, call no core API and are not connected to playback_queue.lua.
They are excluded from the media-only IPK. `make test-schoolbell` runs 32
TC-66/67 groups in `packages/schoolbell/tests/test_player_model.lua`.

## Codec

`encode(stage, errno)` returns 16 bytes or nil/error.
`decode(bytes)` returns {stage, errno} or nil/error.
Only stdio/exec/cleanup and errno 1..4095 are allowed; other frame fields are fixed.
`decoder().feed(chunk, eof)` buffers at most 16 bytes and returns
{frame=..., eof=...}, with no frame until complete. Errors are sticky.
Feed after EOF, extra bytes and truncated/invalid frames are rejected.
A complete frame is visible before EOF but later extra bytes invalidate it.

## Model

`model.new(sys, options)` requires resources and accepts max_records and
launch_timeout_ms under the [range contract](PLAYER_WIRE.en.md). Functions and
configuration are captured at construction. There is no random-source fallback.

Begin accepts only {resource=...}, a trusted media_handle and pure permit().
Handles are tables with private identity, simulating native userdata.
Table fields do not control private state. Foreign handles are rejected;
released handles are stale. Generation text is not authorization.

```lua
local model = require("schoolbell.player_model")
local player = assert(model.new(fake_sys, {
    resources={"speaker"}, max_records=128, launch_timeout_ms=2000
}))
local handle, err = player.begin({resource="speaker"}, fake_media, permit)
local snapshot, poll_err, stats = player.poll(handle)
local ok, release_err, cleanup_stats = player.release(handle)
```

Stats is a model-only diagnostic extension with calls, not a native API claim.
Snapshots follow the [result contract](PLAYER_RESULTS.en.md).

## Injected boundary

| sys function | Injected result |
| --- | --- |
| random(16) | Exactly 16 bytes; exception/wrong length rejects construction |
| prepare(call, token, media, resource) | Expected executable {dev, ino}, or rejection |
| fork(token) | Positive PID; false, errno means proven rejection; exception/malformed result means possible/uncertain |
| clock() | Monotonic integer milliseconds |
| read(token, 16) | String; empty means EOF; nil, "again" means no data |
| open_exe(token, pid) | Temporary FD or no result |
| fstat(fd) | {dev, ino} |
| wait(pid) | "running", {kind="exit",code=N}, {kind="signal",signal=N}; otherwise observation failure |
| close(fd) | One close operation |
| cleanup(call, token) | true only after complete cleanup; false retains record |
| valid_signal(n) | Pure predicate for the modeled platform |

Prepare/cleanup are trusted test procedures: all simulated system operations
must use call(name,...). Preparation permits open/fstat/flock/pipe/fcntl/dup/close;
cleanup permits close. Token exists before preparation, allowing the backend to
track partial resources. Backend also tracks temporary open_exe FDs through
token for later cleanup. Do not hide multiple calls or real side effects inside
one primitive. The model counts boundary calls, not callback internals.

Preparation gets at most 62 operations, reserving clock/fork within begin's 64.
Failure cleanup uses only remaining budget, at most 8. Incomplete cleanup returns
a terminal not_started handle instead of losing resources. Subsequent release
calls perform at most 8 operations. There is no automatic kill. Fork exceptions
retain the record even without a known PID; the model cannot recover this lost
outcome.

Poll reads once and observes executable before wait. After ambiguous wait it
does not probe /proc by PID again. Confirmed exec is not rechecked. Frames can
still drain after reap; release waits for EOF or protocol failure. The final
snapshot after termination and protocol closure is stable; further poll calls
perform no sys operations. Clock/channel errors never authorize replay.

`model.child_setup(sys, routine, token)` separately simulates the 64-operation
child budget for dup/fcntl/close/exec/write/exit. It creates no child and is not
called by begin. `model.counter(last)` is a pure UINT32 boundary-test helper,
not a way to modify an existing instance's counter. Saved call functions become
invalid after the procedure returns. Reentrant begin/poll/release returns busy.

## Limits

32 groups verify a model, not Linux. Native FD ownership, flock, fork/exec,
madplay behavior, clock/random sources, media retention/recovery and reboot
behavior still need implementation and verification. Table handles are not a
security boundary against Lua debug access; callbacks are trusted.
Hung callbacks cannot be interrupted. Audible latency, real-time behavior and
target RAM are not measured. Native portions of TC-50–65 remain planned.
