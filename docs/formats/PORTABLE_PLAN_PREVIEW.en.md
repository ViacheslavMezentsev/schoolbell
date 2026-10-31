# .sbp import preview model

[Русский](PORTABLE_PLAN_PREVIEW.md) · [Wire contract](PORTABLE_PLAN_WIRE.en.md) · [Codec](PORTABLE_PLAN_CODEC.en.md)

Specification 1.68, TC-176, 2026-10-29. Pure preview.lua/preview.js under
packages/schoolbell/portable-plan, not installed in IPK/LuCI/Pages. Installed version
remains 5.1.18; no device tests in this stage.

## Computation

Uses existing calendar/draft validators for schema, ranges, assignments, references
and bounds. All imported schedules must be referenced by selected plans. Media
must be exactly the closure of all rows, including disabled rows, plus always
included pre_media. Missing and extra dependencies block preview.

Checks exact timezone name/posix, installed bundled size/SHA from the snapshot,
bundled-only Pages, auto-off/clean editor, date overlaps, names and pre-bell conflicts
including disabled pre=true rows. Assigns fresh IDs and only free user slots.
Never reuses occupied equal-hash slots. Missing files still referenced by current
rows/pre_media/manual_media reserve their slots to avoid changing old references.

Produces a merged candidate preserving existing objects, mode, fixed schedule
and manual melody. Applied plan is outside this model. Candidate receives existing
draft limits including12 KiB; JS/Lua use matching canonical byte-size encoding.

## Input/output

preview(manifestRaw,calendarRaw,context) is synchronous (JS Uint8Array, Lua strings).
Bytes must come from a **successfully verified complete container**. Structure is
rechecked, but the model does not read payloads or rehash calendar. Arbitrary raw
pairs are not authenticated archive inputs.

Context is a coherent future system-adapter snapshot: draft, timezone{name,posix},
media (<=14{id,size_bytes,sha256}), operation_id (32 lowercase hex), booleans
automatic_enabled/dirty, target device/pages, names{plans,schedules} ID-to-name maps.
Unknown fields reject. Names JSON <=4096 bytes. Lua snapshot must fit strict JSON
limits16 KiB/4096 nodes/depth8; oversized/invalid snapshots never permit import.
Names compare exact UTF-8, without automatic renaming.

Always admitted=false. Failure returns no candidate, blockers<=64 code/path and
blockers_truncated; malformed structure may stop at one error. Codes format,
dependency,dirty,automatic_enabled,timezone,overlap,unsupported_media,slots,
name_conflict,pre_conflict,conflict,size. Dirty is a local UI reason, not a new HTTP status.
Success returns candidate, mapping(plans/schedules/rows/media), candidate_bytes,
user_slots and before/after pre_change. Input context remains unchanged.
Legacy year entries are retained verbatim in candidate; normalized ranges are used
only for overlap checks. Incoming plans must use range format.

This is **not the final HTTP preview**: no revision token/expiry, space calculation,
upload or commit. Adapter must bind the verified archive and revisions, validate
effective zone, MP3/duration, RAM/space, mint token, recheck under locks and perform
durable publication/recovery. DST gap/fold validation belongs to the calendar
execution validation; equal zone strings do not establish it.

Next comes selected-plan export/dependency collection. This model validates an
already supplied closure; it does not assemble archives. Pages does not load it yet.
No files, processes, sound or clock commands are produced.

## Tests

test-preview.py generates45 shared scenarios and invokes Lua/JS. Successful outputs
are compared completely, including byte count; independent expectations check IDs,
slots, old objects/settings and input immutability. Covers quiet/cross-year/leap dates,
disabled rows, missing/orphan dependencies, occupied/referenced-missing slots, names,
pre-bell/timezone/dirty/automation conflicts, malformed input, bounded blockers and
merged JSON limits. Included in make test-schoolbell/make all alongside62 byte vectors.
TC-168–174 are still incomplete: host model evidence is not end-to-end import acceptance.
