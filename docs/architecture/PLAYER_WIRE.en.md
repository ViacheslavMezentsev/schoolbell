# Player frame constants, generations and parameter ranges

[Русский](PLAYER_WIRE.md) · [Specification 1.11](../requirements/TECHNICAL_SPECIFICATION.md)

Requirements 3.6.29–3.6.34 are accepted; revision 1.12 adds a codec and isolated
model, while the system adapter remains absent. TC-61–65 are planned. [Result fields](PLAYER_RESULTS.en.md) stay intact.

## Child frame

Exactly 16 bytes; all multibyte integers are unsigned, big-endian.
Do not transmit a raw C struct.

| Offset | Field | Value |
| --- | --- | --- |
| 0–3 | magic | ASCII SBPE: hex 53 42 50 45 |
| 4 | version | 1 |
| 5 | kind | 1, child system-operation failure |
| 6–7 | stage | Only 5, 8 or 10 |
| 8–11 | errno | 1..4095 |
| 12–15 | reserved | 0 |

Global stage numbering: validate=1, lock=2, media=3, pipe=4, stdio=5,
permit=6, fork=7, exec=8, observe=9, cleanup=10.
Only stdio/exec/cleanup are valid in a child frame; other stages use the parent
API. Unknown or out-of-range values produce protocol_error, without guessing
the version.

Reference exec/errno=2 frame:

```text
53 42 50 45 01 01 00 08 00 00 00 02 00 00 00 00
```

At most one frame, followed by termination of the error path. Partial frames
accumulate across poll calls; extra/truncated frames are rejected. Child exit
alone does not substitute for the frame. Internal logic errors must not invent
errno; without a trustworthy frame launch confirmation stays uncertain.

## Generation and attempts

Generation is 16 bytes from a system random source, encoded as 32 lowercase
hex characters. Created once per instance, it remains unchanged. Unavailable
randomness rejects creation; no time/PID fallback. Tests inject the source.

Generation is neither a secret nor authorization. Native handles are also bound
to their owning instance; matching generation text and attempt number cannot
forge a handle. Statistical randomness is not a mathematical uniqueness claim.

Attempt_id is an integer 1..4294967295, increasing without reuse. Gaps after
preparation failure are allowed. Exhaustion returns limit for new attempts while
existing ones remain serviceable; never wrap through zero.

## Configuration

| Parameter | Range/value |
| --- | --- |
| launch_timeout_ms | Integer 100..60000, default 2000 |
| Resources | 1..4 |
| Active attempts | One per resource, including launching/uncertain |
| Retained adapter records | 1..128, default 128; includes terminal until release |
| Resource ID | 1..64 ASCII [A-Za-z0-9_-] |
| exit_code | Integer 0..255 |
| signal | Positive number valid on the platform |
| Monotonic timestamps | Integer milliseconds 0..2^53-1 |

Timeout, resource set and record limit are fixed at instance creation.
Reject fractions, NaN, infinities, numeric strings and deadline overflow,
without rounding/clamping. Do not assume a universal signal ceiling of 64;
the native layer checks the target platform.

Fixed: 64/64 preparation operations, 8 per poll, 8 per separate cleanup pass,
one read of up to 16 bytes per poll, zero launch retries, zero stored stdout/stderr.
Requests cannot supply arbitrary executable, argv or audio device: these belong
to the trusted profile. Adapter record quotas do not change waiting-queue limits;
MP3/media-storage limits belong to the media manager.

## Next stage

Isolated codec and API model with injected system operations: reference/invalid
frames, every split point, randomness failure, foreign handles, counter exhaustion
and range boundaries. Real processes still require system clocks/random source,
atomic admission with media retention and reference recovery.
The original contract was documentation only; revision 1.12 model coverage is
listed below. No sound or router changes.

Schoolbell specification 1.12: isolated Lua SBPE codec and player API model with injected operations. 32 host test groups cover frames, generations, deadlines/outcomes, quotas and cleanup. No native binding, processes, sound, core or router changes; IPK unchanged. [Player model](PLAYER_MODEL.en.md).
