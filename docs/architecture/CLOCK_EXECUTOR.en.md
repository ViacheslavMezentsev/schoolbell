# Clock control in the executor

5.0.26: native clock dependency and authenticated time confirmation/bypass UI, worker-owned activation, host tests. Not installed. See [time controls](CLOCK_UI.en.md).

The 5.0.25 scope below is historical; native/UI work is now complete on host.

[Русский](CLOCK_EXECUTOR.md)

5.0.25 is a host integration, not a router deployment. The actual `schoolbell-auto` script uses `clock_gate` over `clock_trust`; tests inject clock, storage and player ports. They do not test real audio or deployed hardware execution.

Control defaults to enabled. Missing native support, corrupt policy or unavailable reference blocks automatic admission; there is no silent fallback. `clock_gate.system()` uses `clock_system` and the agreed `/etc/schoolbell-editor` directory, without creating the reference directory or modifying clocks/NTP.

Observation runs each nominal one-second pass and once per second while waiting for the player. Fresh admission is checked before claim, after preparation and at spawn. Cached status is never a permit. Untrusted UTC does not advance the durable watermark; missed events are consumed in memory and explicit plan reactivation starts from the current time. Loss of trust does not stop an already admitted child; it blocks subsequent starts. Mute remains independent.

## Disabling control

Local `/etc/schoolbell-editor/clock-policy.json`, at most 256 bytes, accepts only `{"enforced":true}` or `{"enforced":false}`. Missing means true; invalid, duplicate or extra fields and non-boolean values never disable control. The worker reads it at startup; portable SBB archives neither include nor restore it. In-process `gate.configure(boolean)` revokes admission and previous confirmations; enabling control requires fresh confirmation. Policy changes never write automatic.enabled=true. If a plan is already enabled, bypass removes only the trust requirement, retaining boot/TZ, Mute, TTL and watermark checks. The future UI must keep mode selection separate from plan activation.

Bypass reports `unchecked`, enforced=false and accuracy_known=false, never confirmed. It opens neither clock ports nor reference storage. Explicit enable is still required after a mode change. Re-enabling creates a new trust model without inherited trust/tokens.

## API and status

`new(factory, options)` takes a clock/store factory; options.enforced is a boolean defaulting to true, and threshold options retain the clock_trust contract. observe/status, request_confirmation/confirm and enable/disable/admit retain their model semantics. configure(boolean) changes only enforcement. Confirmation does not enable playback. Opaque Lua confirmation tokens are instance-local, not HTTP/CSRF tokens.

Worker status includes clock_trust: enforced, state, reason, automatic_permitted, accuracy_known=false and optional source. confirmed_utc/checkpoint_utc are integer seconds because the existing status JSON codec cannot encode UTC milliseconds. Persisted clock/1 references still use milliseconds.

## Validation and next stage

TC-132 covers eight gate groups and sixteen actual-worker scenarios: separate confirmation/enable, bypass/policy errors, restart/context, reference writes, steps after claim/during acquire, child waits, Mute, expiry and durable no-replay. The fake player never opens an audio device. Earlier isolated MR3020 adapter tests are not target validation of this integration.

Deployment requires the target-ABI clock_linux native dependency and an authenticated confirmation/mode UI bridge. Lua modules are included in the payload, but the native module is not yet bundled; enforced operation therefore blocks automatic bells with that payload alone. Installed router version 5.0.24 is unchanged. Next: native dependency packaging and IPC/API/UI, then separately approved deployment. No clock corrections or automatic NTP trust criteria are introduced.
