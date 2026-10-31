# Player results, errors and budgets

[Русский](PLAYER_RESULTS.md) · [Specification 1.10](../requirements/TECHNICAL_SPECIFICATION.md)

Contract 3.6.21–3.6.28 is accepted; revision 1.12 adds an isolated model.
The system implementation and native acceptance of TC-56–60 remain pending.
The [system API](PLAYER_SYSTEM_API.en.md) differs from the current isolated queue.

## Results

```lua
handle, err   = player.begin(request, media_handle, permit)
snapshot, err = player.poll(handle)
ok, err       = player.release(handle)
```

Handle is an opaque native object, not constructible from a PID.
Poll returns a copied snapshot; inapplicable fields are absent, not zero.

| Field | Type and values |
| --- | --- |
| generation | Instance generation string |
| attempt_id | Integer attempt number within the instance |
| state | launching / running / terminal / uncertain |
| exec_status | pending / confirmed / failed / unknown |
| outcome | When available: not_started / exit / signal / unknown |
| exit_code | Only for exit, integer 0–255 |
| signal | Only for signal, signal number |
| error | Optional structured error |
| launch_timeout | Boolean: confirmation deadline has expired |
| cleanup_pending | Boolean: cleanup remains |

Terminal excludes further execution of this attempt, not evidence of audibility.
Early death can produce terminal with exec_status=unknown and outcome=signal.
The timeout flag stays set even if later observation resolves the outcome.
Repeated poll retains the result until release. Unknown cannot allow release
while execution may continue. After process termination the record remains
occupied while cleanup_pending=true. Release is not stop.

## Errors and control channel

Errors contain code, stage and errno only for system-call failures.
Closed sets:

- code: invalid_argument, invalid_handle, stale_handle, busy, limit,
  media_invalid, permit_denied, clock_error, spawn_failed, exec_failed,
  observe_failed, protocol_error, launch_timeout, not_terminal, cleanup_failed.
- stage: validate, lock, media, pipe, stdio, permit, fork, exec, observe, cleanup.

Example: `{code="exec_failed", stage="exec", errno=2}`.
Expected read EAGAIN and waitpid without completion are not errors.
A possible child requires a retained handle, not just nil/err.

The child sends one 16-byte frame:
`magic[4], version[1], kind[1], stage[2], errno[4], reserved[4]`.
SBPE/v1 constants and big-endian are fixed in the [wire contract](PLAYER_WIRE.en.md).
Do not send a raw C struct. Partial frames accumulate across poll calls.
Invalid, extra or truncated frames produce protocol_error. Send failure does
not become successful launch confirmation.

## Exec and completion

Retain the validated executable before launch. While the child is owned and
not yet reaped, open /proc/<pid>/exe and compare device/inode through fstat
against the retained file. A match confirms exec; pathname text is insufficient.
Reported exec failure means failed. EOF does not prove exec. Unavailable /proc
leaves pending, then unknown after timeout. Early exit/signal can prove
termination while leaving exec history unknown. Stop PID-based access after
reaping; only the adapter reaps its children. This does not verify the dynamic
loader's operation or audible playback.

## Budgets

| Operation | Maximum system operations |
| --- | --- |
| Parent preparation in begin | 64 |
| Child preparation before exec | 64 |
| One poll | 8 |
| Separate cleanup/release pass | 8 |

At most one read of up to 16 bytes per poll. Count native-wrapper operations,
including failed attempts, clock reads, observation and temporary open/fstat/close.
Do not recheck confirmed exec. Loader/player work after exec is excluded.
No hidden retry loops or extra cleanup beyond the poll budget.

Reserve child bookkeeping and cleanup capacity before fork. Insufficient
preparation budget rejects before fork. Cleanup continues in separate passes
without losing records or FDs. Operation counts do not guarantee execution
time or memory consumption. These are defensive limits to verify.

Frame constants and generation/ranges are accepted in revision 1.11. System
clocks/random source, atomic media admission and
reference recovery remain open. Actual madplay properties and target /proc
access require separate checks. Code, IPK and router are unchanged; future
host scenarios use no audio device.

Schoolbell specification 1.12: isolated Lua SBPE codec and player API model with injected operations. 32 host test groups cover frames, generations, deadlines/outcomes, quotas and cleanup. No native binding, processes, sound, core or router changes; IPK unchanged. [Player model](PLAYER_MODEL.en.md).
