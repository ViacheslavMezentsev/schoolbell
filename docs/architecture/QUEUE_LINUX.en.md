# Queue and Linux player composition

[Русский](QUEUE_LINUX.md) · [Queue](PLAYBACK_QUEUE.en.md) · [Lua binding](LUA_PLAYER.en.md)

The isolated `schoolbell.queue_player` bridge connects the Lua FIFO to the
Linux adapter. The owner explicitly calls step. There is no background thread,
core API, UI, audio device or IPK integration.

## Build and host checks

```sh
sh packages/schoolbell/tests/test-lua-player.sh
make test-schoolbell
make ci-schoolbell
```

Uses the binding's Lua 5.1 development/C99 dependencies. The runner executes
8 binding groups, then 10 composition groups (TC-71) in a separate VM.
Only the fixture child runs: ordinary-file stdin and /dev/null output.
The C host checks FD balance and absence of unreaped children.

## Wiring

```lua
local bridge = assert(require("schoolbell.queue_player").new(
    native_player, -- dedicated empty schoolbell.player_linux instance
    function(media_id, revision)
        return trusted_fds[media_id][revision] -- exact, already retained revision
    end,
    {"speaker"}))
local worker = assert(require("schoolbell.playback_queue").new(
    clock, bridge, {resources={"speaker"}}))
-- submit/status/cancel/forget unchanged; caller repeatedly invokes worker.step().
-- After all queued/active work has been cancelled or drained:
assert(bridge.close())
```

Bridge/native/queue resource sets must match. The native instance belongs
exclusively to one bridge: do not concurrently call its methods or attach
another queue. Construction rejects a nonempty instance. Backend functions
are frozen. Plain-table backends are allowed for fault injection, not untrusted
extension code.

The resolver receives media_id and media_revision, returning a borrowed
regular-file FD or failure. The host fixture preopens and retains the file
until completion. The resolver neither chooses the latest revision nor releases
the file. Cancelled/expired pending jobs never call it; missing files never launch.
This is not production admission: submit still stores labels only. Atomic
admission-time retention, replacement/deletion and media recovery remain absent.

## States and release

- A native begin handle leaves the queue starting, without a started event.
- Confirmed running/exec yields playing and one started event.
- Poll observes termination, followed by release. Until cleanup succeeds, the
  queue stays finishing and retains the resource.
- Exit with confirmed exec and no observation error yields finished/failed by
  exit code. Signal yields failed/player_signal with a separate signal field,
  no exit_code. Not_started maps to player_not_started. Insufficient exec
  evidence or terminal observation errors map to player_exec_unknown.
- A possibly live process remains uncertain. Timeout, clock failure and TTL
  expiration neither kill the child nor release its resource.

The queue keeps legacy started/rejected and running/exited fake-backend results;
launching, draining, failed and deferred are added. Deferred guarantees no new
process and returns the job to the FIFO head with unchanged deadlines.
Failed reasons are player_signal (signal 1..127), player_not_started,
player_exec_unknown and player_begin_unknown; inapplicable fields are rejected.
Signal/reason appear in status/events. Forget still requires a terminal receipt.

Per step/resource: one native begin, or one poll and one terminal release;
after previous cleanup, one begin for the next job is allowed.
That transition can therefore use up to 8+8+64 backend calls, not 8 per whole step.
Each native call keeps its own budget; Lua/resolver/GC time is outside those counts.
There are no hidden waiting loops, sleeps or automatic replay.

## Lost results

Bookkeeping is reserved before begin. A begin exception does not prove rejection:
pending recovers the single unclaimed handle. Until reconciliation, other new
starts are deferred while existing work continues. Under exclusive ownership,
an empty pending list produces failed/player_begin_unknown without restarting
that job. Multiple unclaimed handles leave the resource uncertain.

A release exception preserves the terminal snapshot. A later release confirms
success or stale_handle if the first release already completed. Stale is accepted
only after that exception. Incomplete cleanup continues poll/release.
A completed result remains until ticket replacement, preventing response loss
from replaying the child. Storage is bounded to one record per resource.

Close does not cancel jobs or poll children; active bridge records block it.
The owner must also cancel/drain queued jobs before close.
VM/process crash recovery and arbitrary OOM inside queue.step are not implemented;
native retention alone cannot restore queue state. No durable events, ack/replay
or active stop are provided.

## Verification limits

TC-71 covers FIFO/two resources, exec-before-started, cancellation/TTL/UTC,
final permit after preparation, UTC loss, completion despite clock faults,
exit/signal/exec failure, delayed release, lost results, uncertain observation,
missing media and exit zero without exec confirmation.
The existing 24 queue groups remain. This is neither hardware acceptance nor sound.

Next: trusted storage with atomic revision retention at submit, then separately
approved target ABI and actual madplay checks.


The next isolated stage adds [exact revision retention at submit](MEDIA_ADMISSION.en.md). The optional retained_userdata argument of native begin is pinned with its handle. The old API remains compatible.
