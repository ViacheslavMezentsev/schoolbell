# Pages: .sbp export and import preview

[Русский](PORTABLE_PLAN_PAGES.md) · [Wire format](PORTABLE_PLAN_WIRE.en.md)

This stage adds browser export and a read-only import proposal. Installed 5.1.18
is unchanged. IPK5.1.19 separately adds only heading/uptime. The owner publishes Pages separately.

## Operator journey

1. Edit ranges/assignments in Calendar and bells in Schedules.
2. Expand the .sbp transfer panel and explicitly choose the plan timezone.
   The browser zone is only a hint; selection changes no clocks, NTP or demo settings.
3. Select plans and download .sbp. The current draft, including unsaved edits, is
   captured. Apply pending name/date fields first. Export does not save the draft.
4. Choose an .sbp file. Its header, lengths, strict JSON and SHA are verified.
   Select the destination timezone, save existing demo edits and request preview.
5. Review blockers or the proposed plans/schedules and pre-bell change. Rename
   imported names explicitly and retry. Overlapping dates are never replaced.
   Preview does not add anything or enable bells.

All referenced schedules, disabled rows, colors and pre-bell dependencies travel
with selected plans. Bundled audio uses ID/size/SHA without MP3 payloads. User audio
is rejected explicitly in Pages. Re-import into the same draft normally reports
overlaps and name conflicts; this is expected, not a corrupt archive.

## Implementation and limits

The builder copies the shared codec/export/preview unchanged and injects the panel
and a cloned read-only editor snapshot into Pages only. The device payload has no
new files or routes. Bundled media metadata is generated from actual build files.
The adapter has no network/storage/command API; files are not uploaded. Normal
demo persistence still uses localStorage, which preview does not modify.

The pinned zone table comes from LuCI openwrt-19.07; source/hash/license are in
site/portable-zones.NOTICE and LUCI-LICENSE. Original names (including spaces) are
retained, with UTC=UTC matching the package adapter. This targets compatibility,
not current worldwide timezone legislation. Future device import must compare
both name and POSIX rules with its own supported table, without changing clocks.

Web Crypto and Blob.arrayBuffer are required (HTTPS Pages or localhost). The total
2125906-byte limit is checked before reading; manifest/calendar limits are16384/
12288 bytes. User payloads are rejected after the authenticated-by-checksum manifest
and before any MP3 read. Web Crypto buffers at most16 KiB per metadata digest; it
is not a streaming SHA implementation for future audio imports. Browser RSS is not
measured; JSON objects and output Blob copies add overhead. Concurrent edits revoke
old proposals and cancel stale asynchronous export downloads.

TC-178: make check-site / test-site-portable.js plus shared editor/snapshot tests:
cross-year plans, actual bundled hashes, corruption/truncation/trailing bytes/size,
early user-media rejection, dirty/mode/timezone/name blockers, immutable inputs and
stale async results. Local browser checks exercised download, expected conflicts
on re-import, and successful preview of an independent synthetic plan.

Next: device admission/staging, atomic additive commit, revision/quota/recovery
checks; then separately authorized installation and Pages-to-device acceptance.
Preview provides no commit token. Installed5.1.18 does not yet import .sbp.
