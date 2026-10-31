# Isolated schoolbell queue

[Русский](PLAYBACK_QUEUE.md) · [Specification](../requirements/TECHNICAL_SPECIFICATION.md)

`packages/schoolbell/lua/schoolbell/playback_queue.lua` is an internal Lua 5.1
model. It starts no processes, reads no files and calls no core API. It is not
included in the media-only IPK. `make test-schoolbell` covers TC-40–42 with
24 fake-clock/player groups; this does not confirm audible output.

## API

```lua
local queue = require("schoolbell.playback_queue")
local worker = assert(queue.new(clock, player, {
    resources = {"speaker"}, max_records = 128, max_pending = 32
}))
local receipt = assert(worker.submit("schoolbell", {
    resource = "speaker", media_id = "bell", media_revision = "v1",
    ttl_ms = 5000, expires_utc_ms = 1800000005000,
    source_id = "schedule-event-1"
}))
local result = assert(worker.step())
local current = assert(worker.status("schoolbell", receipt.id))
-- Only while queued:
-- worker.cancel("schoolbell", receipt.id)
-- Only after finished/failed/expired/cancelled:
-- worker.forget("schoolbell", receipt.id)
```

## Inputs and results

`clock()` returns `{mono_ms=N, utc_valid=boolean, utc_ms=N}`. UTC is required
only when valid. Monotonic time must not decrease. All times are integer
milliseconds within the exact Lua number range ±(2^53−1); monotonic time is
nonnegative. TTL is positive and deadline overflow is rejected. Calendar output
uses UTC seconds: the future client must convert units and select its allowed
lateness. The example does not prescribe this policy.

`submit(owner, request)` admits work without calling the player. Required fields:
resource/media_id/media_revision/ttl_ms; expires_utc_ms/source_id are optional.
Owner, resources and media IDs/revisions are 1–64 ASCII `[A-Za-z0-9_-]`
characters; source_id is at most 256 bytes. Unknown fields and metatables are
rejected. Media revision is a label, with no file existence/retention check.
Inputs/results are copied and backend functions captured at construction.
Owner is a trusted caller identity, not authentication.

`submit/status/cancel` return snapshots with id, owner, resource, media_id,
media_revision, source_id, state, accepted_mono_ms, deadline_mono_ms,
expires_utc_ms and optional reason/exit_code. Errors are `nil, {code=...}`.
Cancel adds changed=true on first cancellation, false on repetition.
Only an owner's queued request can be cancelled; active/uncertain is rejected.
Forget returns true and releases an owner's terminal receipt. Subsequent
status/cancel returns unknown; cancellation idempotency lasts until explicit
forget. IDs are never reused within one instance but are not unique across
instances. Durable state and redelivery are not implemented.

States: queued → starting → playing → finished/failed. An unknown start/poll
outcome enters uncertain and holds the resource. Confirmed running restores
playing; confirmed exit releases it. Queued can also become cancelled/expired/
failed (explicit launch rejection). Finished means exit_code=0, not audible sound.

## FIFO, deadlines and stepping

Each resource has its own FIFO and at most one active request. Monotonic TTL
starts at admission; calendar work additionally needs UTC strictly before
expires_utc_ms. Equality expires. Invalid UTC holds a calendar head without
overtaking while its TTL continues. Expired waiting entries, including tail
entries, are removed; independent resources proceed. Deadlines never interrupt
already active playback.

Step returns `{events={...}, clock_error=...}`, with an optional clock error.
At most one poll and one start per resource per step, plus a bounded queue scan.
Events are snapshots with kind: started, uncertain, finished, failed, expired.
Cancellation is reported directly by cancel, not an event. Repeated unknown polls
do not flood events: uncertain is emitted once per request; status stays current.
There is no background thread, durable outbox, ack or replay. The client consumes
step events. Clock failure blocks new starts but still allows confirmed exit
cleanup. A later step can recover when the clock becomes valid.

## Injectable player contract

- `player.start(resource, ticket, snapshot, permit)` returns
  `{ticket=ticket,state="started"}` or `state="rejected"`. It must call permit()
  immediately before its side effect. False prohibits launch. Rejected guarantees
  that no player exists for this ticket.
- Permit rechecks the clock and both deadlines, and expires when start returns.
  UTC loss/clock failure with confirmed rejection restores the same FIFO head
  with its original TTL; expiry terminates it. Plain rejection produces failed.
- `player.poll(resource,ticket)` returns `{ticket=ticket,state="running"}` or
  `{ticket=ticket,state="exited",exit_code=0..255}`. Only a matching confirmed
  exit releases the resource.
- Exceptions, malformed fields/tickets and started without permit produce
  uncertain: absence of a launched player cannot be established. There is no
  automatic retry, kill or timed release. A trusted backend must not falsely
  report running/exit/rejected or launch after a denied permit.

Callbacks must return in bounded time and avoid blocking the worker; the model
cannot interrupt a hung callback. Reentrant submit/cancel/forget/step returns busy;
status is allowed. OS integration needs process ownership, exit observation,
clock sources, IPC and recovery rules. Subscription removal is unrelated to the
queue; pause/re-registration/active stop are not implemented.

## Defensive limits and errors

Options: 1–4 unique resources as a dense list; max_records=1..128 (default 128),
max_pending=1..32 per resource (default 32). Records include waiting, active and
terminal entries; pending counts only waiting entries. No automatic eviction.
These are model limits, not RAM measurements. Clients must consume/release
receipts or admission returns full.

Codes: backend/options/resources for invalid construction; request for invalid
input; full/id_exhausted/deadline_overflow for admission; clock/clock_regressed
for invalid clocks; unknown/not_owner for receipt access; active/terminal/
not_terminal for invalid operations; busy for reentrancy. Event reasons:
ttl/utc, player_rejected/player_exit, start_result/start_unknown/poll_result/
poll_unknown; cancellation reason: owner_cancelled. A future integration layer
will map internal codes to the public API.

The system adapter contract is accepted in specification 1.8; this model API and code are unchanged. Asynchronous launching, signal outcomes and file retention remain to be implemented: [Player adapter](PLAYER_ADAPTER.en.md).

Schoolbell spec 1.15: isolated bridge connects the Lua queue and Linux player; launching/finishing, signal outcomes and cleanup before the next start. Ten fixture-child host groups; no core, audio device, sound or router/IPK changes. [Queue/Linux bridge](QUEUE_LINUX.en.md).


The next isolated stage adds [exact revision retention at submit](MEDIA_ADMISSION.en.md). The optional retained_userdata argument of native begin is pinned with its handle. The old API remains compatible.
