# Player system mechanisms and asynchronous API

[Русский](PLAYER_SYSTEM_API.md) · [Specification 1.9](../requirements/TECHNICAL_SPECIFICATION.md)

Requirements are accepted; implementation is absent. Normative references:
3.6.6/3.6.8 and 3.6.11–3.6.20; TC-50–55 are planned. The existing
[queue API](PLAYBACK_QUEUE.en.md) remains unchanged.

## Mechanisms

A separate schoolbell native module for Lua 5.1 performs fork, descriptor
preparation and execve with separate arguments. The child never returns to Lua
after fork. The madplay profile in the [contract](PLAYER_ADAPTER.en.md) stays
unchanged. This is a schoolbell bundle dependency, not a core audio API.

A separate CLOEXEC control channel carries preparation/exec error stage and
errno. The parent reads it without blocking and reconciles child status.
EOF may accompany early death; it alone does not prove exec. Launch evidence
is separate from termination outcome. waitpid(child, ..., WNOHANG) obtains an
ordinary exit code or signal; a signal is not converted to an ordinary
128+signal exit. Fast exit does not require a previously observed running state.
Revision 1.10 selects executable-identity observation: [results](PLAYER_RESULTS.en.md).

Use flock(LOCK_EX | LOCK_NB) on one resource lock file for the current boot.
Do not delete/replace that file during operation. The player inherits the FD
through exec. Do not issue LOCK_UN while an old player may exist: inherited
descriptors share the lock. This coordinates schoolbell instances, not arbitrary
third-party programs opening /dev/dsp.

After a crash, a new owner checks the lock. Acquiring it permits new work subject
to other checks, but cannot reconstruct the lost result. Unknown old requests
are not replayed. Media garbage collection is prohibited until references have
been recovered and the old player excluded.

The exact madplay build must pass lock-FD retention and stdin playback checks.
Failure requires agreement on an alternative before integration. Neither
property has been verified yet. Open the retained revision relative to a trusted
directory, checking path components without symlinks and fstat for a regular
file; hand the open file to the child as stdin. An open FD does not make content
immutable: the published-revision manager must enforce immutability.

## API

```lua
handle, err = player.begin(request, media_handle, permit)
snapshot = player.poll(handle)
ok, err = player.release(handle)
```

This is the accepted internal interface shape, not an implemented Lua binding
or a public core API. Exact fields and errors are accepted in revision 1.10: [results](PLAYER_RESULTS.en.md).

Begin prepares the resource/file and checks permit immediately before authorizing
child creation. It never extends TTL. It returns launching without waiting for
exec or sound. OS file operations are not promised hard real-time bounds.
A failure with proven absence of a child may return an error without a handle.
If a process may exist, it must retain an observable handle rather than vanish
behind such an error.

Poll performs one nonblocking pass and returns a snapshot:

| Semantic field | Values/rule |
| --- | --- |
| State | launching, running, terminal, uncertain |
| Launch evidence | Separate: confirmed, not launched, or unknown |
| Outcome when available | not_started, exit with code, signal with number, unknown |
| Identity | Instance generation + attempt, not PID alone |
| Diagnostics | Stage, errno, reason for uncertainty |

Unknown forbids release while execution may continue. Confirmed exit or signal
allows terminal even if exec history is unknown. Repeated poll retains the result
until explicit release. Release is allowed only after confirmed termination or
rejection without a process; it does not stop the player. Foreign/stale generations
cannot control a new attempt. Active cancel/stop is absent in the first version.
Owner loss does not introduce durable queues or exactly-once guarantees.

## Initial parameters and remaining decisions

| Parameter | Accepted |
| --- | --- |
| Launch confirmation | Configurable 2000 ms, monotonic from authorization |
| Timeout | uncertain, no retry/release |
| Automatic launch retries | 0 |
| stdout/stderr | /dev/null, 0 stored bytes |
| poll | One nonblocking pass per call |

Structured errors remain available without text output. The exec control channel
is distinct from stdout/stderr. Revision 1.10 accepts budgets of 64/64 for parent/child preparation, 8 for poll
and 8 for a separate cleanup pass; the transport limit of 4 syscall/endpoint does not
apply. 2000 ms is an initial test setting, not a measured bound.

Frame constants and generation/ranges are accepted in [revision 1.11](PLAYER_WIRE.en.md).
Open items: system clocks/random source, atomic admission with media retention, and reference recovery. Host acceptance uses a substitute process without an
audio device. Target build checks and real sound require a separate agreed stage.

Schoolbell specification 1.12: isolated Lua SBPE codec and player API model with injected operations. 32 host test groups cover frames, generations, deadlines/outcomes, quotas and cleanup. No native binding, processes, sound, core or router changes; IPK unchanged. [Player model](PLAYER_MODEL.en.md).
