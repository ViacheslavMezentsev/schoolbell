# Persistent schoolbell media library

Accepted specification 1.17 contract, requirements 3.5.10–3.5.27;
[Русский](MEDIA_PERSISTENCE.md). Requirements only: no implementation, sound or
router changes.

Bundled melodies remain package resources; user files and catalog live in a
separate persistent data area preserved by package updates. `/tmp` is not the
persistent library. Missing storage never triggers creation of an empty library.
External-storage support is deferred.

## Replacement

Revisions are immutable. Catalog entries include media ID, revision, size,
SHA-256 and validated audio properties. Display names are not paths; snapshot
generations are internal metadata rather than additional user-setting versions.

Only one mutating operation runs at a time: peak-space/reserve check → bounded
streaming upload → MP3/compatibility validation → revision storage → consistent
bundle preparation → publication. Enforce actual size without buffering the whole
MP3 in RAM. Handle space failures even after admission; never delete referenced
files to make room for an upload.

Uploading a revision does not change saved plans. A separate replacement action
shows affected references in selected schedules and publishes them consistently.
Accepted requests retain their original revision. A bundle ties catalog, settings
and plans to exact files; immutable files may be shared across bundles.

## Persistence and recovery

Report saved only after durable file, metadata and publication completion,
including file/directory synchronization. Rename alone is not a durability proof.
The exact commit protocol and supported filesystems remain open. Ambiguous commit
failure means outcome requires verification, not a promise that the old state
survived. A lost success response requires reconciliation rather than blind retry.

| Situation | Required behavior |
| --- | --- |
| Incomplete upload/unpublished bundle | Never activate |
| Valid current bundle | Validate files/references and normal execution readiness |
| Corrupt current, valid previous bundle | Restore the whole previous bundle for inspection; automatic bells stay paused until confirmation |
| No valid bundle | Recovery mode, no empty plan or automatic bells |
| Reboot | No old-queue replay or catch-up bells |
| Service-only crash | Exclude an old player before new launches or removal of its files |

Keep one previous consistent bundle by default; this is not an external backup.
Deletion requires reconstructed references from all saved plans, active bundle,
rollback, unfinished backup and live leases. Uncertain ownership blocks cleanup.
Repeated recovery must be safe. Publication, recovery and cleanup never launch sound.

## Verification and remaining decisions

TC-73–82 are planned: upgrades/missing storage, malformed files/references,
ENOSPC/short writes/interruption, selected replacement, concurrency, interruption
at every commit step, sync errors/lost responses, corrupt bundles, repeated recovery,
old processes and cleanup with live references. Host tests do not establish flash
power-loss durability; target experiments need separate approval.

Question 8.2.12 tracks paths/formats, API/permissions, audio validation/properties,
quotas/reserves, operation identity, commit/reconciliation, joint plan publication,
filesystems and cleanup. The prototype's 16 lifetime publications are not the
production library limit. This branch does not implement core 6.6 settings storage.

Stage 1.18 accepts [format, quotas and commit order](../formats/MEDIA_FORMAT.en.md). The open list above describes stage 1.17; current remaining decisions are in specification 1.18 question 8.2.12.
