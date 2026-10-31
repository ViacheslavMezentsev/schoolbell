# Media catalog, quotas and commit protocol

Accepted specification 1.18: 3.5.28–3.5.41 and 5.3; [Русский](MEDIA_FORMAT.md).
Requirements only; no code, UI, IPK, audio-device or router changes.

## Catalog and layout

Use the existing strict JSON decoder, rejecting duplicate keys, unknown fields
and arbitrary paths. Melody fields: id, name, revisions. Revision fields:
revision, source, size_bytes, audio. Audio fields: format, duration_ms,
sample_rate_hz, channels. Revision is the 64-hex SHA-256 of exact file bytes;
no duplicate hash field. Source is bundled or user; format is mp3. The validator
sets size/audio properties, not the browser. Schedules reference id + revision.
Identical content may share an immutable file. Display names are not paths.
One internal format version lives in bundle metadata, outside user settings;
its value and exact envelopes/field ranges remain open.

Persistent root: /etc/modbus-schoolbell/data, containing objects/ (user MP3s),
snapshots/ (immutable metadata bundles), staging/ (preparation), current.json
(current/previous pointers) and recovery.json (saved recovery pointer).
Bundled melodies stay in /usr/share/modbus-schoolbell/melodies. Mutable transaction
parts share one filesystem. Paths are package-generated. A snapshot ties catalog,
settings, schedules and plans together; its descriptor lists fixed filenames,
sizes and SHA-256. Never mix snapshots. Current references current/previous
snapshots and descriptor hashes, with an integer generation independent of RTC.

## Initial protective limits

| Parameter | Limit |
| --- | --- |
| Melodies / total revisions per catalog | 32 / 64 |
| User MP3 | 512 KiB; 60 seconds |
| User MP3s including retained old files and upload | 2 MiB |
| catalog.json | 64 KiB |
| All snapshot JSON including descriptor | 256 KiB |
| Streaming upload buffer | 16 KiB |
| Concurrent uploads/mutations | 1 |
| Free reserve after predicted peak | max(512 KiB, 10% of persistent partition capacity) |

KiB = 1024 bytes; MiB = 1048576 bytes. Shared physical objects count once;
additional copies and uploads consume space. Metadata, staging and rollback
also count toward peak-space admission. Limits do not promise available space.
Handle ENOSPC after admission too. Measure Lua/JSON/MP3 RAM and FD use before
integration; replace the native prototype's 16 lifetime publications without
losing live leases. The streaming buffer is not a whole-process RAM bound.

## Commit order

1. Exclusive mutation ownership; compare expected generation, otherwise conflict.
2. Bounded streaming upload and MP3/duration/compatibility validation.
3. Store immutable object; synchronize file and directory.
4. Prepare complete snapshot; validate references/hashes; synchronize files/directories.
5. Persist a verified copy of the old current pointer as recovery.
6. Write/synchronize a temporary pointer (new current, former current as previous),
   rename over current, then synchronize its parent directory.
7. Only then report saved. Cleanup is separate; cleanup failure cannot undo commit.

Peak storage may need three generations: prepared, current and previous rollback.
Do not remove objects referenced by recovery. After safe cleanup keep current
and one previous bundle, plus objects retained by other plans/live references.
The exact recovery-pointer transition before GC remains to be specified.

| Result | Meaning |
| --- | --- |
| saved | Durable commit confirmed |
| rejected | Change was not published |
| conflict | Expected generation changed |
| needs_recovery | Commit outcome cannot be established |

Store operation ID in the snapshot descriptor. Reconcile a lost response by ID
before retrying; an unknown/expired ID does not prove rejection. This is not an
unbounded idempotency journal or permission for blind replay.
Recovery validates current and its complete bundle, then verified recovery
information if damaged. Never select by newest directory name/time. Fallback
keeps automatic bells paused; unreliable evidence means recovery mode.
Incomplete uploads are never activated and old queue entries are not replayed.

## Remaining decisions and verification

Question 8.2.12 covers exact pointers/descriptors and their integrity checks,
ranges/IDs, first initialization, recovery replacement/crash transitions,
reconciliation/result retention/GC, catalog envelope, plan/settings schemas,
MP3 validator, API/permissions, filesystem support and free-space/percentage
rounding. Host rename success does not validate target power-loss durability.
TC-83–90 are planned: structure, layout, boundaries, peak/resources, conflicts,
every commit step, lost responses and recovery/cleanup. Hardware power tests
require separate approval. [Previous policy](../architecture/MEDIA_PERSISTENCE.en.md).
