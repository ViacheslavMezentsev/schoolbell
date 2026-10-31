# Melody uploads (engineering profile)

## Dynamic media compatibility — 5.1.27

Stable IDs are `user_<hex>` for uploads or `userN` for imports, at most 64 ASCII characters. Legacy `user1`–`user8` remain valid; bundled `test`, `0`–`4` remain protected. Display row numbers are not IDs.

Framing remains `SBBACKUP1` for .sbb and `SBPLAN1` for .sbp. The manifest selects `schoolbell-backup/2` for extended IDs or more than eight user tracks; `schoolbell-plan/2` for more than eight user dependencies. Readers accept versions 1 and 2; older readers reject an unknown version explicitly. Small compatible exports retain version 1. Version 2 removes media/file count quotas while preserving reference, integrity, manifest-byte and archive-byte checks. Pages exports bundled tracks only; imported user audio can be inspected without uploading it to GitHub.

This is a partial file-policy implementation: A–P assignment encoding, schedule/range counts and internal calculation budgets still need a separate migration.

The following sections describe the earlier stage; the compatibility note above takes precedence.

The Melodies tab has six protected bundled slots (test and 0–4) and eight user slots (user1–user8). The API rejects bundled replacement and exposes no delete operation. Only user slots accept uploads and replacement. Disable automatic bells first. Existing draft references keep their slot; the next playback uses its new revision. This is not production revision-pinned schedule migration.

Authenticated raw POST uses a CSRF header, an expected generation and a 128-bit random operation ID. Uploads are streamed with a 16 KiB chunk limit. MP3 limits: 512 KiB and 60 seconds. A frame scan and madplay decoding to null precede publication; neither plays sound. Decoder completion does not prove audible quality. The shared player gate excludes replacement, cleanup and activation races. An uncertain decoder outcome retains the gate for administrative recovery; it is never removed based on age alone.

The existing manager stores immutable SHA-256 objects under /etc/modbus-schoolbell/data, atomic current/recovery pointers and one previous snapshot. Original bundled files are untouched. Upload plus retained objects and extra copy must fit 2 MiB and leave max(512 KiB,10% of filesystem capacity), plus metadata allowance. Real free space may impose a smaller limit. Conflicts, truncation, bad audio and failed admission leave the published library unchanged. A lost response can be checked by operation ID; unknown is not rejection. Corruption fails closed, without silently substituting bundled media.

The engineering snapshot contains media overrides only. Full settings/calendar snapshots, backup/import, production FD leases and explicit fallback confirmation remain pending. A crashed request may leave the shared gate; inspect processes and storage before administrative recovery. No automatic power-loss guarantee. The browser preview streams under the same gate; public demo allows only the bundled test sample and no uploads.

Tests: test_mp3.lua, test_media_library.lua, test_media_http.lua, existing 25 manager crash points. Host and router checks do not replace power-loss tests. No core, NTP or network changes.

The storage bar is a statvfs snapshot of the persistent filesystem, not RAM. It also shows the protected free-space reserve and retained user-media bytes against the 2 MiB quota. Refresh the list to update it; free space alone does not guarantee admission.

An empty user slot cannot play; activation rejects enabled rows referencing missing media. Five slots do not waive the total quota/reserve or promise room for five maximum-size files.
