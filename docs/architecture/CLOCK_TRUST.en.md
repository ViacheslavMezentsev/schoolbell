# Schoolbell clock trust

Current 5.0.25 stage: [executor integration and optional control](CLOCK_EXECUTOR.en.md). Earlier stage boundaries below are historical; isolated target adapter validation passed, deployment and confirmation UI remain pending.

[Русский](CLOCK_TRUST.md)

Accepted requirements in specification 1.32, section 4.7. Revision 1.33 adds an isolated host model. Installed schoolbell 5.0.14, firmware, services, clocks and NTP remain unchanged. TC-125 partially covers TC-113–124; system/UI integration remains planned.

| State | Meaning | Automatic ringing |
| --- | --- | --- |
| Unconfirmed | New boot, no usable evidence or observation context | Blocked |
| Rollback detected | UTC earlier than the saved confirmed timestamp by more than 5 s | Blocked |
| Confirmed | Evidence accepted with an identified source | Separate explicit enable allowed |
| Review required | Clock step, observation failure or exceeded agreed uncertainty | Blocked |

A saved timestamp is a lower reference, not downtime measurement or restored trust. UTC later than that timestamp does not establish accuracy. During continuous observation compare UTC elapsed time with monotonic elapsed time. A step strictly greater than 5 s in either direction requires review; equality does not trigger. Thresholds are configurable from 1 to 60 seconds in 1-second increments; observation budgets are listed below. A DST change in displayed local time is not a UTC step.

First implementation stage: durable reference/source/checksum, states, server-side admission gate and explicit manual verification. Confirming the displayed clock is separate from enabling the plan. Browser time is only an aid. Failed persistence or stale context cannot succeed. Replacing a mistakenly future reference requires explicit acknowledgement; the consumed-event watermark is never lowered. Automatic network confirmation and RTC checks follow separately after source-quality criteria are agreed.

Loss of trust blocks new automatic bells/pre-bells and invalidates the previous enable. Already admitted audio may finish; Mute still applies. Manual ringing remains available under normal player restrictions. Reconfirmation does not re-enable anything or replay missed events. The executor checks trust at final admission, not merely at the UI button.

The duty panel shows state, reason, source and confirmation date; bounded logging records transitions/actions, not every poll. Plan years remain independent of the clock; missing years are quiet. Plan years never set the clock. Backup/fleet transfer does not carry device-specific reference, trust or enable permission.

Open: system clock sources/error bounds, confirmation context representation, future migrations, actual flash wear/resources, NTP/RTC quality, allowable uncertainty and autonomous trust duration. Five seconds is a detection threshold, not promised bell accuracy. A one-day passive measurement cannot guarantee year-long accuracy. No core API is added by this package contract.

File `/etc/schoolbell-editor/clock-reference.json`: at most 1024 bytes, data/checksum envelope. Data has exactly format="schoolbell-clock/1", source="manual", confirmed_utc_ms and checkpoint_utc_ms. SHA-256 of canonical data, strict bounds and a synthetic vector are specified in 4.7.13 / appendix T. Unsupported formats are not rewritten. The existing media codec has a 32-bit number limit: UTC-ms needs an isolated codec, without changing media formats.

Commit: temp → fsync → atomic replacement → directory fsync. Only successful persistence confirms time. Orphan temp is never a reference; corrupt primary data does not trigger fallback. Save immediately on manual confirmation, then no more than once per 3600 monotonic seconds while observation remains trusted, even with ringing disabled. Hourly checkpoints never update the confirmation timestamp/source. Lost trust stops advancement; failed mandatory writes require review. About 24 periodic commits per day do not quantify physical flash wear.

| Budget | Value |
| --- | --- |
| Observation period | 1000 ms |
| Maximum usable gap | 3000 ms inclusive |
| MONO → UTC → MONO | 100 ms inclusive; account for timestamp association uncertainty |
| Before audio admission | Additional fresh check after preparation |
| Confirmation request | Expires at 15000 ms; bound to current context |

Ambiguous threshold crossing requires review, not optimistic admission. Observation continues while awaiting the player; lost trust does not interrupt existing audio. Ordinary observation does not write flash, access networks or launch processes. Threshold changes never clear a block. Next: system adapter and observation integration, without claiming hardware accuracy.

Revision 1.33 adds the [host model API and limitations](CLOCK_TRUST_MODEL.en.md). Planned checks above have partial isolated coverage; system integration, UI and router changes remain outside this stage.

Revision 1.34: the [system adapter](CLOCK_SYSTEM.en.md) is implemented and host-tested. Earlier references to future system work now concern target validation and integration. Executor/UI integration remains pending.
