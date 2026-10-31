# Portable calendar plan .sbp

> Target policy updated in specification 1.75, section 5.3: object/slot quotas are removed from requirements in favour of shared file admission budgets. Numbers and slot rules below describe the existing format/implementation only. They remain enforced in 5.1.26 until compatible encoding, migration and tests are implemented; this is not a silent change to SBPLAN1. Existing data must never be truncated.


Exact wire/API accepted in specification1.67: [contract](PORTABLE_PLAN_WIRE.en.md). Codecs, Pages export/preview and a [system import candidate5.1.20](PORTABLE_PLAN_IMPORT.en.md) are implemented; target checks remain open.

Accepted framing, fields, bounds and API: [PORTABLE_PLAN_WIRE.en.md](PORTABLE_PLAN_WIRE.en.md). Question8.2.15 is closed by agreement.

[Русский](PORTABLE_PLAN.md)

Accepted stage contract, 2026-10-28, schoolbell specification revision 1.66, section 4.10. Installed5.1.19 cannot import/export .sbp; candidate5.1.20 provides import but has not been installed. This is neither a full .sbb backup nor an installation package. Exact wire layout and transaction API are accepted in PORTABLE_PLAN_WIRE.en.md.

## Contents and compatibility

One .sbp file contains a bounded manifest JSON block, calendar.json and referenced user MP3 files at media/<sha256>.mp3. The sole schema identifier is schoolbell-plan/1; exporter application version is informative. The manifest describes the plan timezone, file names/sizes/SHA-256 and melody references, titles, bundled/user source and hashes; bundled entries also have a stable supplied identifier. The manifest block is not duplicated as a payload file.

The calendar uses the existing named inclusive date ranges, date assignments, schedules/colors/rows and pre-bell parameters. Local user1–user8 slots are not destination addresses. The dependency closure includes disabled rows and the pre-bell melody. User audio is included, identical bytes once. Bundled audio may be omitted only with exact ID/size/hash references; missing or different bundled audio is an error, never an automatic substitution/download.

Use a streaming container (short header, bounded known-length JSON manifest, known-length files), not ZIP or a new unpacker dependency. SHA-256 detects corruption, not authorship. Exact framing/fields/bounds are in PORTABLE_PLAN_WIRE.en.md; isolated implementation and vectors are described in PORTABLE_PLAN_CODEC.en.md.

Export the current draft and selected plans, including unsaved edits with an explicit notice. Export never saves or activates it. Exclude the active plan/enable permission, daily mode, manual melody, volume/mute, time trust, system time/NTP/timezone settings, network, credentials, journal and hardware settings. Existing global settings are retained except explicitly admitted pre-bell parameters.

Pages uses the same format with bundled melodies only initially. It rejects user-media archives in full with an explanation; no dropped dependencies. Device exports must include user audio despite this demo restriction.

## Import journey and non-overwrite policy

Calendar → Import plan → choose file → review contents → add to draft. Preview lists ranges, schedules, melodies, timezone, required slots/space and all blockers. Automatic bells must already be disabled. Unsaved edits must be saved or explicitly discarded; import does neither silently.

- Addition only. Overlaps within the archive or with existing inclusive ranges are rejected; repeated imports cannot duplicate a range.
- Assign new IDs to imported plans/schedules/rows and rewrite their references. Existing objects are not modified or implicitly merged.
- Conflicting plan/schedule names require an explicit new imported name. Matching melody titles do not prove identical content.
- User media uses free slots only. No occupied slot/file/title is replaced. Insufficient slots reject import. Occupied slots are not reused even for matching hashes. Shared payload bytes are transferred once, but distinct user catalogue entries receive distinct free slots.
- Different timezones reject import without shifting bell times or changing system timezone. Compare exact name/posix fields without automatic alias equivalence.
- If any existing row has pre=true, including disabled rows, interval and actual pre-bell melody must match. Compare content, not slot number. Otherwise reject. If no existing pre-bell references exist, imported parameters may be accepted with explicit preview disclosure.

Save and reread the combined inactive draft; bells stay disabled and the applied copy stays untouched. Applying the new draft is a separate user action. Recheck draft/media revisions and disabled automation before commit; concurrent changes invalidate preview. Confirmation binds the exact archive and dependency mapping.

## Integrity, resources and recovery

Apply current limits to the combined result: 12 KiB draft, 8 plans, 16 schedules, 8 user slots, MP3 up to 512 KiB/60 seconds, 2 MiB library quota and max(512 KiB,10% partition) free reserve. Account for existing/staged/retained data, metadata and peak RAM/tmp, and recheck space. Maximal objects are not guaranteed to fit. Container/buffer/space bounds are specified in PORTABLE_PLAN_WIRE.en.md; target peak RSS remains unmeasured.

Validate format, hashes, references and MP3 without sound before publication. Reject unsupported schemas, truncation, trailing bytes, duplicate names, unsafe paths and missing/corrupt dependencies. Never execute archive code or fetch dependencies. Device writes use normal LuCI authentication and POST/CSRF protection.

Publish draft and new media coherently. Pre-commit failure leaves existing logical data unchanged. Interrupted publication yields the complete old state, complete new state, or explicit recovery blocking partial data and keeping bells disabled. Success requires verified durable publication. Durable intent and recovery are specified in PORTABLE_PLAN_WIRE.en.md; the current resumable backup restore is not automatically an atomic import.

After a lost HTTP response query the same operation outcome; do not blindly replay POST. Repeated confirmation must not create duplicate plans or consume another slot.

Planned TC-168–174 cover academic/cross-year round trips and preview equivalence; disabled-row dependencies; bundled hashes/user MP3; lossless Pages rejection; conflicts/names/IDs/timezones/pre-bells; bounds/corruption; concurrent revisions, write interruptions and unknown outcomes. Start on host/Pages, then separately authorize installation with backup. Physical power-loss testing needs separate approval.
