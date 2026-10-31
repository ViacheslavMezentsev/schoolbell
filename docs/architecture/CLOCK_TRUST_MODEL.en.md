# Isolated clock trust model

Current 5.0.25 stage: [executor integration and optional control](CLOCK_EXECUTOR.en.md). Earlier stage boundaries below are historical; isolated target adapter validation passed, deployment and confirmation UI remain pending.

[Русский](CLOCK_TRUST_MODEL.md)

The host-only clock_reference, clock_reference_store and clock_trust modules implement specification section 4.7. They are excluded from the schoolbell 5.0.14 payload. No executor, router or NTP changes. System clock sampling, safe directory opening and confirmation UI remain separate work.

## Codec and storage

clock_reference.encode(data) returns JSON/checksum; decode(raw) returns data/checksum or throws. Strict clock/1 schema, exact integers through 2^53−1, 1024 bytes and canonical SHA-256 do not change the media format. The adapter additionally validates its supported calendar range.

clock_reference_store.new(open) requires a private exclusively locked handle implementing read/stat/unlink/write/sync/rename/close. read returns nil only for absence; errors throw, mutations may also return false. close releases the lock; open must clean up a failed acquisition. load() returns {ok,data,revision}, with nil/"empty" for absence. save(data,expected_revision) checks CAS, then temp → file fsync → rename → directory fsync → readback. Results are {ok,revision} or {ok=false,code}: invalid_reference, conflict, storage_error. Orphan temp is never an authority; corruption has no fallback. Post-rename failure is uncertain, never success. The model latches storage failure until separate inspection/reloading; no automatic retry.

## Model API

clock_trust.new(io,options) requires clock() → {before_ms,utc_ms,after_ms,context}, valid_utc(ms) → true and store.load/save. All times use milliseconds. The adapter must change context on boot/observer/timezone-context changes and provide actual resolution/error bounds. rollback_seconds and step_seconds are integers 1–60, default 5.

| Call | Result / responsibility |
| --- | --- |
| observe() | Fresh sample, hourly checkpoint when due, status snapshot |
| status() | Cached diagnostics only, never a launch permit |
| request_confirmation() | token, utc_ms, context, requires_rollback_ack; nil/code on failure |
| confirm(token,ack) | Single-use confirmation and persistence, {ok,code}; no auto enable |
| enable() / disable() | Separate permission; enable requires fresh trust |
| admit() | Fresh final observation and boolean admission after preparation |
| configure(settings) | Validate both thresholds, revoke permission/token; never clear a block |
| drain_events() | Transitions plus count of displaced entries |

The token is an instance-local opaque Lua table, not a wire token or authentication/CSRF mechanism. TTL starts conservatively at the displayed pair's beginning. A fresh sample after persistence rejects stale permission; the next checkpoint period starts after this completed commit/check.

The caller drives one-second observations, including player waits. A gap >3000 ms, pair >100 ms, context loss, error or possible threshold violation closes admission. The jump interval is [ΔUTC−(after2−before1), ΔUTC−(before2−after1)]; ambiguity fails closed. Loading a saved reference never restores trust. accuracy_known stays false: absence of steps is not UTC accuracy measurement.

Diagnostics retain at most 16 transitions plus a loss counter, not a durable journal. The model neither starts/stops audio nor owns replay watermarks. Integration must guard both bells and pre-bells, retain no-replay logic and independent Mute.

## Validation and limits

test_clock_trust.lua runs in the normal host runner: schema/vector/limits, CAS, persistence-stage failures and reopening, boot/rollback/step, uncertain samples, TTL, observation continuity and hourly writes. Injected storage verifies logic, not physical power-loss durability. Production UI/API, system clock source/accuracy, RAM/CPU/flash and executor integration remain unverified. NTP is unchanged.

Revision 1.34: the [system adapter](CLOCK_SYSTEM.en.md) is implemented and host-tested. Earlier references to future system work now concern target validation and integration. Executor/UI integration remains pending.
