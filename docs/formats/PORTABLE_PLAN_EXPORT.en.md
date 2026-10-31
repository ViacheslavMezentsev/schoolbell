# Assembling an exported .sbp

[Русский](PORTABLE_PLAN_EXPORT.md) · [Wire format](PORTABLE_PLAN_WIRE.en.md) · [Import preview](PORTABLE_PLAN_PREVIEW.en.md)

Isolated export.lua/export.js under packages/schoolbell/portable-plan assemble
selected calendar plans. Specification 1.69, TC-177, 2026-10-29. Not included in
IPK, LuCI or Pages; the installed package remains 5.1.18.

## Snapshot and dependencies

The exact input fields are draft, selected, timezone, media and exporter.
Draft uses the existing validated model, at most 12 KiB. Selected contains 1–8
unique plan IDs; unknown IDs fail. Timezone is name/posix, exporter is name/version
as defined by the wire contract. Media contains up to 14 id/title/size_bytes/sha256
entries. The complete snapshot passes strict JSON limits: 16 KiB, 4096 nodes,
depth 8. It is copied before callbacks; original data stays unchanged.

Plans and schedules retain draft order regardless of selection order. Legacy
year entries become full-year ranges with year-YYYY IDs and «План YYYY» names.
Missing schedule color uses the original draft index modulo 16, starting at 1,
matching the UI. All selected schedule_ids are included even if unused by days.
All rows, including disabled rows, retain media dependencies; pre_media is always
included. Mode, fixed_schedule, manual_media and system settings are excluded.
Missing required media fails without substituting the test bell.

Media order is test, 0–4, user1–user8. Slot IDs become archive-local IDs and are
remapped during import. Bundled files have no payload. User payloads are deduplicated
by SHA while separate names remain separate media entries. Equal hashes with
different lengths fail. A shared payload is read from the first slot in that order;
payload paths media/<sha>.mp3 are sorted by SHA. The schoolbell-pages exporter
rejects selected user-media dependencies. Unrelated media is not exported.

## API and ownership

JS `prepare(snapshot, hashFactory)` asynchronously returns manifest/calendar
Uint8Arrays and sources (name/slot/size_bytes/sha256). Lua `prepare(snapshot)`
returns equivalent strings, hashing metadata with media_codec. Preparation alone
does not verify audio bytes.

`encode(snapshot, sourceFor, hashFactory, emit)` uses the existing stream codec
and returns the final byte count only on success (Promise in JS). sourceFor(slot,
metadata) returns chunks up to 16384 bytes, EOF null in JS / nil in Lua.
hashFactory supplies update/finish; emit accepts output chunks. A false return or
callback exception stops encoding; see the [codec API](PORTABLE_PLAN_CODEC.en.md).
The caller must pin media revisions and close/release every source on success or
failure. This layer owns no descriptors or storage locks.

User audio is streamed, not buffered as a whole; size and SHA are checked while
copying. Changed, short or extended streams fail. Output remains tentative until
success: discard partial bytes on any failure, never publish them as a valid .sbp.
Canonical JSON sorts keys and escapes controls, quotes and backslashes as Unicode
escapes; Lua and JS produce identical bytes. Wire bounds apply: 12 KiB calendar,
16 KiB manifest, 512 KiB per MP3, 2 MiB unique audio, 2125906 bytes overall.

## Evidence and remaining scope

35 shared test-export.py cases run both implementations against an independent
Python exact-byte oracle. Successful archives are decoded and passed to preview.
Coverage includes subsets/multiple plans, legacy/cross-year dates, quiet plans,
unused schedule_ids, disabled rows, pre-bell, colors, Unicode, payload deduplication,
maximum sizes, missing dependencies and open/read/emit failures. Input snapshots
remain unchanged; early rejection emits no bytes. Included in make test-schoolbell
and make all. Audio is synthetic: these tests do not validate MP3 or playback.

The system adapter still needs coherent snapshots, pinned revisions, bundled
delivery verification, pinned timezone validation, MP3/duration checks, cancellation,
temporary-file cleanup and real target RAM/resource measurements. The UI must
identify exports of unsaved drafts. Next: Pages export/import preview, then system
admission and commit. No automatic bells are enabled by this model.
