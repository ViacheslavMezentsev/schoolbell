# Import a calendar plan on a device

[Русский](PORTABLE_PLAN_IMPORT.md) · [Wire contract](PORTABLE_PLAN_WIRE.en.md)

Candidate **5.1.20**, host validation only. Installed5.1.19 is unchanged.
This adds to the saved inactive draft; it does not restore/replace a backup.

Save or explicitly discard local edits, disable automatic bells, then open
Calendar → Import calendar plan .sbp. Upload for validation, edit conflicting
incoming names, preview dependencies/timezone/pre-bell/storage and confirm adding
to the draft. Existing objects and the applied plan remain unchanged. Automatic
bells remain disabled. Re-read the same operation after a lost response; never
blindly repeat POST. A pending durable import can only be resumed, not cancelled.
Do not remove its locks, pending marker or staged files manually.

The shared strict codec/preview and media manager validate all dependencies,
including disabled rows, bundled hashes/sizes, user MP3, free slots, names/date
conflicts and final draft limits. MP3 decoding uses null output, never audio.
Temporary uploads/proofs live in a private directory; one operation, a15-minute
preview and30-minute inactivity timeout use monotonic time and boot identity.
GET does not extend expiry. Player→editor→media locks protect the final recheck.
Durably staged files and import.pending precede catalog/draft publication. A
verified committed receipt precedes barrier removal;16 receipts are retained.
Normal data access and package upgrades are blocked while import is pending.
Settings, existing melodies and the applied plan are preserved.

Storage admission reserves two audio copies, metadata, the full16-receipt budget
and reserve. Reported large host free/reserve values saturate at2147483647bytes
with capped=true; admission still uses full values.

HTTP actions share the authenticated LuCI admin route:
plan-import?action=upload|preview|commit|status|cancel|resume&operation_id=… .
GET only reads status. POST checks the LuCI CSRF Bearer token before parsing.
Upload is multipart file; other actions use bounded JSON. Content-Length is
required; chunked requests without it are rejected. Container bound2125906bytes
is independent of the8192-byte multipart overhead allowance. No automatic POST retry.

TC-180 covers actual host files, user MP3, add-only data, receipt replay, conflicts,
expiry, corrupt archives, stage interruptions and before/after57 filesystem
mutations. The gateway uses substituted device ports; HTTP/UI tests check early
authorization, bounds, dirty/revision guards and uncertain outcomes. Pages retains
bundled-only export and read-only import preview; device UI is excluded from Pages.

Before installation, measure target RSS/tmp/flash and MP3 admission time and test
actual LuCI multipart and server deadlines. Callback time checks do not prove that
a blocked socket read is interrupted: verify uhttpd network/script limits against
60/300seconds. These target checks remain open. No device install, sound, automatic
activation, clock/NTP adjustment or physical power-loss test occurred.
Next: separately authorized target validation after backup; then device export
including user melodies and end-to-end transfer acceptance.
