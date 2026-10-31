# .sbp wire format and import operation

## Dynamic media compatibility — 5.1.27

Stable IDs are `user_<hex>` for uploads or `userN` for imports, at most 64 ASCII characters. Legacy `user1`–`user8` remain valid; bundled `test`, `0`–`4` remain protected. Display row numbers are not IDs.

Framing remains `SBBACKUP1` for .sbb and `SBPLAN1` for .sbp. The manifest selects `schoolbell-backup/2` for extended IDs or more than eight user tracks; `schoolbell-plan/2` for more than eight user dependencies. Readers accept versions 1 and 2; older readers reject an unknown version explicitly. Small compatible exports retain version 1. Version 2 removes media/file count quotas while preserving reference, integrity, manifest-byte and archive-byte checks. Pages exports bundled tracks only; imported user audio can be inspected without uploading it to GitHub.

This is a partial file-policy implementation: A–P assignment encoding, schedule/range counts and internal calculation budgets still need a separate migration.

The following sections describe the earlier stage; the compatibility note above takes precedence.

> Target policy updated in specification 1.75, section 5.3: object/slot quotas are removed from requirements in favour of shared file admission budgets. Numbers and slot rules below describe the existing format/implementation only. They remain enforced in 5.1.26 until compatible encoding, migration and tests are implemented; this is not a silent change to SBPLAN1. Existing data must never be truncated.


[Русский](PORTABLE_PLAN_WIRE.md) · [Accepted policy](PORTABLE_PLAN.en.md)

Accepted by the owner on2026-10-28, specification1.67 question8.2.15.
Isolated byte codecs have TC-175 coverage; see [scope](PORTABLE_PLAN_CODEC.en.md).
System import/API candidate5.1.20: [validation scope](PORTABLE_PLAN_IMPORT.en.md). Installed5.1.19 is unchanged.

## Container and schema

Use separate streaming framing, never the replacing .sbb restore:
ASCII `SBPLAN1` + LF (8 bytes), eight zero-padded decimal manifest-length digits
+ LF (9), 64 lowercase hex manifest SHA256 + LF (65), exact UTF-8 manifest bytes,
then files in array order at exact declared lengths without separators.
Header is82 bytes. Reject CRLF, whitespace/zero length, BOM, truncation, trailing
bytes, duplicate/unknown keys, invalid UTF-8, null required values, noninteger or
negative sizes and JSON nesting beyond16. Hash original bytes, not reserialization.
Object key order is irrelevant; array order matters. Hashes are not authentication.

Required manifest fields:

| Field | Definition |
| --- | --- |
| format | `schoolbell-plan/1`, the only schema version |
| exporter | `{name,version}`; name schoolbell-device or schoolbell-pages; informational major.minor.patch up to32 ASCII bytes, no leading zeroes in numeric components |
| timezone | `{name,posix}` from the module's pinned zone list; name up to64 ASCII bytes, posix up to256, no CR/LF/NUL |
| files | 1…9 `{name,size_bytes,sha256}` entries |
| media | 1…14 catalogue entries |

First file is calendar.json (1…12288 bytes), then unique media/<sha256>.mp3 sorted
by hash. No arbitrary paths or system archive unpacker. Source filenames do not
control paths; title provides display text. SHA is64 lowercase hex, size integer.
Media entry: `{id,title,source,size_bytes,sha256}` plus bundled_id for bundled,
or file for user. IDs match `[A-Za-z0-9_-]{1,64}`, titles1…96 UTF-8 bytes,
nonblank and without controls. Bundled IDs test,0…4 match installed size/hash,
without payload. User file/path/size/hash must match files; MP3 <=524288 bytes,
<=60 seconds, nonempty. Different catalogue entries may share payload bytes.
IDs and bundled IDs are unique in their scopes. Reject unreachable/missing files
and media. No external downloads.

Calendar has exactly `{plans,schedules,pre_minutes,pre_media}`:

- 1…8 plans `{id,name,start,end,schedule_ids,days}`; inclusive YYYY-MM-DD ranges,
  years0001…9999, no overlap. Up to16 unique schedule references. One days character
  per date: dot is quiet, A…P indexes schedule_ids.
- 0…16 schedules `{id,name,color,rows}`, color required1…16; no separate row-count cap;
  Rows `{id,time,media,enabled,pre}` use HH:MM, media catalogue ID and booleans.
- pre_minutes integer1…10, pre_media always included even without pre rows.
  Disabled rows retain dependencies; all selected schedule_ids are exported even
  if not currently referenced by a days character.
- IDs follow the above pattern; plan/schedule scopes distinct, rows unique within
  each schedule. Names1…96 UTF-8 bytes, nonblank/no controls. Export legacy year
  as range and missing color as current UI color. No mode/fixed/manual settings.

No additional day-span limit; JSON/result limits apply.

## Compatibility and mapping

Compare both timezone fields exactly; no alias guessing or clock/TZ/NTP mutation.
Pages explicitly selects a plan zone; browser zone is only a suggestion. Device
verifies configured zone against effective rules; unknown/mismatched rules reject.
UTC uses the same pinned list. Calendar DST ambiguity checks remain necessary.

Assign free user1…user8 in media-array order. Never reuse occupied slots, even
with identical hashes. Equal payload bytes are transferred once; different user
entries still occupy distinct free slots and retain titles. Bundled references map
by bundled_id. Pre-bell compatibility compares size/hash and interval, not slot.
IDs become imp-<operation_id>-p<N>, -s<N>, -r<N> (1-based, rows per schedule).
Check collisions and reject; remap all references. Names compare exact UTF-8,
without automatic normalization/renaming; preview accepts explicit incoming names.
Inclusive date overlaps reject.

## Bounds

Manifest16384 bytes; calendar and merged normalized draft12288 each; unique user
MP3 sum2097152; entire container2125906 =82+16384+12288+2097152. Files1…9,
media1…14. Audio chunk16384, at most two byte-buffer chunks; this is **not an RSS
guarantee**. Measure Lua/JSON/LuCI/validator overhead before installation.
Name overrides JSON4096; preview/receipt32768 each. One unfinished device operation,
including upload/preview/recovery. Enforce actual bytes irrespective of Content-Length.

Private tmp upload, not a whole Lua string: remaining container plus128 KiB metadata,
leaving max(1 MiB,10% tmp partition). Tmpfs space does not establish available RAM.
Abort after60 seconds with no input or300 seconds total upload.
Persistent staging before intent budgets new media, both temporary/final copies when
copying, old/new metadata, allocation blocks,128 KiB overhead and remaining
max(512 KiB,10% partition). Existing/pinned objects already consume space. Honor
larger existing manager requirements; recheck under locks and handle later ENOSPC.

## Proposed authenticated LuCI API

Every request needs admin session; all POST need CSRF, GET never mutates.
Browser generates32 lowercase-hex cryptographically random operation_id before POST
and retains it for uncertain outcomes. Actions below are relative to the module.

| Action | Request / result |
| --- | --- |
| POST plan_import_upload | Multipart file + operation_id; validated or rejected |
| POST plan_import_preview | `{operation_id,names}`; plans/schedules ID-to-name maps; preview or blockers |
| POST plan_import_commit | `{operation_id,preview_token}`; exact prepared result only |
| GET plan_import_status | operation_id; state/receipt, no replay |
| POST plan_import_cancel | `{operation_id}`; only before durable intent |
| POST plan_import_resume | `{operation_id}`; explicit continuation, not another import |

Response `{ok,operation_id,state,code}` plus state-specific fields. ok=true only
means the request succeeded; import success requires committed. States receiving,
validated,preview,committing,committed,rejected,cancelled,expired,recovery_required,
not_found. Busy never invents an operation: if unregistered, not_found/busy/ok=false.

Preview includes token64hex, archive_sha256, draft_revision, media_revision,
plan/schedule/media mappings (old_id/new_id/name or slot), timezone, pre_change
(before/after interval and melody ID/hash), space(required/free/reserve per storage),
up to64 blockers{code,path} and blockers_truncated. No token when blocked.
Draft revision empty is only for absent baseline draft.
Opaque token binds archive, revisions, names, mapping and exact result bytes; it
does not replace CSRF. New preview invalidates old. Preview expires15 monotonic
minutes after issuance, not extended by polling; reboot invalidates it. Pre-intent
operation expires after30 idle minutes, GET does not renew; durable intent never expires.

Commit rechecks revisions, zone, auto-off, free slots and space. UI rejects dirty
edits; new edits invalidate confirmation and late responses cannot overwrite them.
Conflict requires new preview. Receipt result includes draft_revision,media_revision,
automatic_enabled:false and mappings. Same commit returns receipt, no duplicate.
Reject upload reusing an ID. Lost response requires status; not_found is neither
success nor permission for blind replay: reconcile data before new preview.
Retain last16 completed receipts <=32 KiB each in completion order independent of
wall clock. Budget their space; never evict pending operations.

Codes: ok,busy,format,size,checksum,dependency,unsupported_media,timezone,overlap,
name_conflict,pre_conflict,slots,space,automatic_enabled,conflict,expired,invalid_state,
storage_unavailable,recovery_required,not_found. No personal paths in path.
HTTP auth401/403, malformed400, oversized413, conflict/busy409, semantic422,
storage503, admitted/read200. UI checks JSON/state too, including old HTTP200 failures.
Authorize before body consumption; test that the LuCI route supports this.

## Durable publication

Lock order player gate → editor → media. Upload/preview does not hold these locks.
Validate MP3 without audio. Preserve existing slots and applied plan.

1. Recheck admission under locks, prepare target draft/catalog and persistent
   media staging, verify hashes and sync files/directories.
2. Atomically write/sync import.pending with operation_id, exact result,
   base/target revisions and staged lengths/hashes: **durable intent**. Earlier
   failures remove only owned staging; cancellation is forbidden after intent.
3. Pending blocks ordinary draft/media access, activation, backup/restore and sound;
   diagnostics/status and safe disable remain available. Package installation must
   preserve pending staging. Check marker after reboot too.
4. Publish media/catalog/draft through durable operations, verify revisions,
   references, hashes and auto-off.
5. Write/sync committed receipt, remove pending and sync directory, then report
   committed. If pending and receipt coexist, recovery verifies result before cleanup.

Interrupted intent requires explicit resume under the same locks. Continue only
when data matches base or intended target revisions. Unexpected changes/missing
staging block recovery; no automatic rollback or lock deletion. A lock's age alone
does not establish abandonment; check process ownership. Never enable bells while pending.
After uncertain writes read durable records before reporting success.

Pages applies the same admission and writes the entire draft as one localStorage
value; storage exceptions preserve old data. Reject user media before writing;
no uploads to GitHub. Multi-tab exclusion plus revision recheck is required;
single setItem is not CAS. Unsupported locking must cause refusal, not unsafe import.

## Delivery sequence and vectors

1. Pure JS/Lua codecs and shared byte fixtures, without HTTP/device writes.
2. Dependency/mapping/preview model and conflict tests.
3. Bundled-only Pages, then system staging/API with faults at every write/sync/rename
   and lost HTTP response.
4. Device UI, auth/limit regressions, separately authorized installation after
   backup and full user-media transfer with auto-off.
5. After .sbp deployment, prepare a separate acceptance record for the exact
   artifact set on a new same-model device: OpenWrt, installation/configuration,
   functionality/recovery and a week or longer automatic run. Fix artifact hashes
   and criteria before testing. Monitoring does not prove audibility; networked
   endurance does not prove Internet-free operation. Authorize physical effects
   before each relevant test.

Primitive vector (not a valid plan): UTF-8 `{}` is2 bytes, length00000002, SHA256
`44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a`. Framing can accept these bytes, semantic validation must reject
the manifest. Full valid fixtures are the first implementation stage, not a claim
that this documentation example establishes implementation coverage.

Since 5.1.24 there is no separate row-count cap. The 12288-byte draft and event calculation budgets remain; capacity depends on data. Older versions may reject larger plans: use compatible device and Pages versions.
