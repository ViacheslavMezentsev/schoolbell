# Schoolbell backup

## Dynamic media compatibility — 5.1.27

Stable IDs are `user_<hex>` for uploads or `userN` for imports, at most 64 ASCII characters. Legacy `user1`–`user8` remain valid; bundled `test`, `0`–`4` remain protected. Display row numbers are not IDs.

Framing remains `SBBACKUP1` for .sbb and `SBPLAN1` for .sbp. The manifest selects `schoolbell-backup/2` for extended IDs or more than eight user tracks; `schoolbell-plan/2` for more than eight user dependencies. Readers accept versions 1 and 2; older readers reject an unknown version explicitly. Small compatible exports retain version 1. Version 2 removes media/file count quotas while preserving reference, integrity, manifest-byte and archive-byte checks. Pages exports bundled tracks only; imported user audio can be inspected without uploading it to GitHub.

This is a partial file-policy implementation: A–P assignment encoding, schedule/range counts and internal calculation budgets still need a separate migration.

The following sections describe the earlier stage; the compatibility note above takes precedence.

Version 5.1.0 also backs up/restores named calendar ranges. Legacy year payloads remain readable without checksum changes. Downgrading below 5.1.0 requires a pre-migration backup: older modules do not understand ranges. A portable Pages plan bundle is a separate future feature, not this complete backup.

[Русский](BACKUP.md)

Engineering UI 5.0.14: Settings → Backup. Disable automatic ringing and save editor changes before downloading `.sbb`. The copy includes the saved draft (settings, schedules, annual assignments), Mute/volume and current user1–user8 titles/files. Protected bundled audio remains part of installation. Logs, automatic activation, network, passwords, clock and NTP are excluded.

To clone onto another device, install a compatible module and bundled audio and select the same timezone first. Upload the backup and confirm replacement of the entire saved plan and user library; this is not a merge. After success the page reloads and **automatic ringing remains disabled**. Verify the plan, local time and audio output before explicitly enabling it. This is a device backup, not a separate fleet template.

Flat schoolbell-backup/1 format: `SBBACKUP1\n`, eight decimal manifest-length digits plus LF, 64 lowercase hex SHA-256 of the manifest plus LF, JSON manifest, then concatenated file bodies in manifest order. First: draft.json, controls.json, catalog.json; then unique SHA256.mp3 objects. Manifest fields: format, timezone (exact /tmp/TZ contents), files[{name,size_bytes,sha256}]. SHA-256 detects damage, not authorship: only restore trusted copies.

Archive limit 2162816 bytes; manifest and each JSON <=16 KiB; eight objects <=512 KiB/60 seconds each. The shared 2 MiB media quota includes staging, retained objects and copying. Free reserve is max(512 KiB,10% partition), plus temporary metadata. Eight slots do not guarantee space for eight maximum-sized files. Input chunks are <=16 KiB; the internal buffer can temporarily hold two chunks. Format, hashes, references, timezone, space and MP3/null decode are checked before settings change. No audio output is used during validation.

Lock order: player gate, editor lock, media lock. After staging validation: durable restore.pending, automatic disabled, media publication, draft, controls, verification, receipt, marker removal. Pending blocks ordinary writers/playback/activation. Use Check status and Resume interrupted restore. There is no automatic rollback; do not manually delete the marker or staging.

A killed process may leave the shared player gate. A developer must verify no owned player remains and investigate the operation before removing that gate; age alone is insufficient. Corrupt staging needs investigation and a verified backup. Following a lost HTTP response, inspect status and saved data before retrying; restore-last.json records the last operation.

Host tests cover corruption, truncation, trailing bytes, traversal, timezone mismatch, existing library replacement and commit-boundary interruptions. Isolated target checks do not prove physical power-loss behavior. Production plan revision/FD leases remain a separate stage.

After an engineering payload update, send router-page/invalidate-cache.sh through SSH and run it on the router. It removes only temporary schoolbell/controller bytecode and the LuCI route index; otherwise a new page may call a stale API. Streaming HTTP uses yield-compatible protected calls on Lua 5.1, tested separately from file export.
