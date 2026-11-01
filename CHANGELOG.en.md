# Changelog

[Русский](CHANGELOG.md)

## Unreleased

- 5.1.44 verification: make all and specification checks PASS. Authorized bench verification covered 81 package files, 12 HTTP assets, unchanged backup contents and 226 preserved journal entries. Volume remains 50%, automatic bells off; no playback. The owner confirmed the palette appearance on the bench.

- Specification 1.81: record the owner-approved 16 CSS names/HEX values and fixed built-in 4×4 palette order. Shared UI implementation and TC-195 remain pending; package version unchanged.

- 5.1.44: implement the specification 1.81 baseline CSS palette of 16 colors in the exact 4×4 order; tooltips include CSS names. Preserve numeric color assignments; quiet days remain neutral.

- 5.1.43: enlarge playback icons in both Actions columns to 24 CSS px; preserve button dimensions and the gap before deletion.

- 5.1.42: halve the gap before Delete in the Actions column of both tables (60 → 30 CSS px). Clarified the custom melody requirements: format, size and duration.

- 5.1.41 verification: make all PASS; installed on the development bench, preserving data, 220 journal entries, volume and auto-off. Real Chrome: repeat reloads reach draft readiness in 1.36–1.48 s vs 3.65–3.98 s; first reload after upgrade 2.66 s. Complete melody list takes 2.32–2.91 s on repeat reloads; no instant-load claim. Palette and actions inspected on the installed page. Uncommitted.

- 5.1.41: one Actions column in Schedules and Melodies, with a button-width empty slot before deletion. Initial schedule/media reads precede background polling; a 1.5-second wait limit prevents failed loading from starving status controls. A 4×4 color palette sits left of schedule selection and name; create/copy/delete use icons with accessible labels.

- 5.1.40: faster schedule reads with unchanged integrity checks: precompute SHA-256 rotation powers and expand dates only for assigned days. Start schedule loading before background reads; closed time settings no longer issue a duplicate startup clock request.

- 5.1.39: Check backup status when its section opens instead of on every page reload, avoiding storage-lock contention with the initial melody list.

- 5.1.38 validated: make all and strict specification checks passed; local Chrome confirmed the compact column and System section. Installed on the bench with verified backup/rollback: 81 files and 10 HTTP assets matched; .sbb data, 220 journal entries, 50% volume and auto-off preserved. Boot ID unchanged. Actual reboot/reset was not invoked; new actions were tested on host fixtures. No commit.

- 5.1.38: compact deletion column and removed bell count. Settings now includes System with confirmed reboot and resumable settings reset preserving melodies and journal. Specification revision 1.80, TC-192–194; installation never triggers these actions.

- 5.1.37: make all passed; installed on the bench with verified backup/rollback. Successful list reads: 531/531/703 ms versus 2770/3064 ms. .sbb contents, settings, 220 journal entries and 50% volume preserved, auto off. An orphan empty gate was separately recovered with the web service stopped, no owners and storage locks held; its origin is not established. No sound or commit.

- 5.1.37 fixes the 5.1.36 regression: melody listing no longer validates/hashes entire draft/applied plans or acquires the editor lock. Bounded reference snapshots provide UI hints; authoritative validation remains mandatory before deletion. Original bench listing took 2.8–3.1 s.

- 5.1.36 validation: make all and strict specification checks passed. Installed on the authorized bench over 5.1.35; backup, rollback, 78 files and 9 HTTP assets verified. Read-only catalog checks confirmed the title and usage flags. .sbb contents, settings and 220 journal entries preserved, volume 50%, auto off. Deletion was tested on host fixtures only; no bench playback, upload or deletion. No commit.

- 5.1.36: mandatory 64 KiB limit for new MP3 files, concise replacement instructions and deletion of unused user melodies with server-side reference checks and locks. Existing files/backups remain compatible. 2.mp3 is titled «Гостья из будущего». Specification revision 1.79, TC-190–191.

- Storage information separates actual usage from upload conditions. The system reserve is explained as a required amount of free space, not already occupied space. Installed on the bench as 5.1.35: backup and 5.1.34 rollback verified, 78 files and 9 HTTP assets matched, data and 218 journal entries preserved. Volume unchanged at 50%, automatic bells off, no audio played.

- Removed the audibility question after successful test playback. Persistent storage information in Melodies is collapsed by default, like journal statistics. Installed on the bench as 5.1.34: backup, exact 5.1.33 rollback, 78 files and 9 HTTP assets verified. Data and 218 journal entries preserved; volume unchanged at 50%, automatic bells off, no audio played.

- 5.1.33: the Melodies manual sound check is grouped in one collapsed section. CI selects runtime, web/Pages and package jobs by changed paths; the mandatory ci-gate rejects skipped selected checks. With owner authorization, 5.1.33 was installed on the bench: backup, rollback, 78 files and 8 HTTP assets verified; data and 211 journal entries preserved. Volume remains 50%, automatic bells off, no audio played. make all and targeted checks passed. Changes remain uncommitted.

- Installed 5.1.32 over 5.1.31 on the authorized bench. Backup and exact rollback IPK verified; all 78 files, .sbb contents, settings and 194 journal entries preserved. Gain remains 25% (-12 dB), automatic bells off, native 1.0.0. Eight CSS/JS assets verified over HTTP. The normal service restart leaves time trust unconfirmed/startup; clocks/NTP unchanged. No playback; icon appearance awaits owner confirmation. Full make all passed.

- 5.1.32 validation: full make all and strict specification checks passed; chains and buttons inspected in local Chrome without playback. No device installation.

- 5.1.32: corrected shared playback icons: 🔊 for browser playback and 🔔 for Schoolbell in schedules, media, manual buttons and chain endpoints instead of notes. Browser-window and device icons remain as chain nodes. The automatic-bell mode still reflects the applied plan, not a settings draft. Devices untouched.

- Installed 5.1.31 over 5.1.30 on the authorized bench: verified backup and exact rollback, all 78 IPK files, unchanged .sbb contents and settings. Gain remains -12 dB (25% in UI), automatic bells off, native 1.0.0. All 187 existing journal entries were preserved; API reports a 32768-byte limit without age retention. Eight CSS/JS assets verified over HTTP, applied calendar mode confirmed. No playback; visual review of the open interface remains with the owner. Full make all passed.

- 5.1.31 validation: full make all passed; strict checks of both specifications reported no errors or warnings. Regressions cover clock jumps, retained history and exact gain, and applied mode. Local Chrome checked four collapsed sections, preview alignment, switches/icons, light/dark themes and a 390 px container, with no JS errors or page overflow. This is not hardware acceptance.

- 5.1.31: superscript version, whole-percent volume, applied-mode icon, aligned buttons, collapsible settings, shared browser/device icons, concise playback explanation and row switches. Device and demo journals are bounded only by 32 KiB; age and clock jumps no longer remove entries. Requirements updated to 1.77 and AUDIO_STATUS 1.1 at the owner’s request. Not installed on devices.

- Installed 5.1.30 over 5.1.29 on the authorized bench. Verified backup and exact rollback IPK, 78 files, unchanged .sbb contents and system settings. Current -12 dB controls preserved byte for byte, automatic bells off, native 1.0.0. New CSS fetched over HTTP matches the source; the controller reports OHCI / AB13X USB Audio. No playback; visual confirmation of the refreshed page remains with the owner. Full make all passed.

- 5.1.30 validation: full make all passed; local Chrome confirmed stable header coordinates for long card names, no overlaps or horizontal overflow, including a 390 px container. This version was not installed on a device.

- 5.1.30: widened the CPU/Flash block to 320 px, bounded by the available width, to keep the audio card name and gain together. Updated the CSS URL to invalidate cache; narrow-screen wrapping remains available. Audio status uses a separate layer with a fixed two-line reservation: wrapping the name does not shift the interface and gain stays on the right; the full name remains in the tooltip.

- Installed 5.1.29 over 5.1.28 on the authorized bench: verified backup and exact rollback package, all 78 new IPK files, preserved .sbb contents and system settings. Gain remains -60 dB, automatic bells off, native 1.0.0. The GET controller returns OHCI/C-Media/USB PnP Sound Device; shared JS correctly renders the name and 0.1% (-60 dB). Full make all passed. No playback; browser inspection blocked by tool startup failure, requiring Ctrl+F5 and owner confirmation.

- 5.1.29 checks: make all, focused Lua/JS and strict requirements-supplement validation — PASS. Metadata module exercised read-only on target Lua; header inspected in local headless Chrome at 1280 and 390 px. No installation or device acceptance of the new UI.

- 5.1.29: below Flash, show controller/card model for /dev/dsp and saved gain in % (dB). Distinguish missing and unavailable metadata, hide device paths, never fall back to other cards. Flash is blue up to 75%, retaining 75/90% thresholds. Shared UI/Pages and AUDIO_STATUS requirements supplement. No installation or sound tests.

- New hub and third C-Media card passed 100 consecutive launches (416.01 s), with no failures or new kernel messages. Hub and card use 12 Mbit/s OHCI: this is not an EHCI retest. -60 dB and automatic-off retained, process/lock released. No code/package changes; full make all — PASS.

- Original AB13X direct/OHCI passed 100 consecutive launches (415.94 s), with no failures or new URB errors; one cannot get freq message is retained in the report. Gain -60 dB, automatic off, player and lock released. Both cards passed direct connection after failing through the original hub. No code/package changes; full make all — PASS.

- Replacement card through the hub failed again on attempt 7. Direct OHCI connection of the same card achieved 100 consecutive successes (417.93 s), no new kernel messages or retained process/lock. Gain stayed -60 dB, automatic playback off. No code/package changes; original hub configuration remains failing and schedule endurance is still pending. Full make all — PASS.

- Owner-authorized 100 consecutive playback attempts on the 5.1.28 bench: 96 completions, 4 madplay failures (exit=4) and four new USB URB -27 error groups. Gain reduced to -60 dB on request. Documented actual route and open reliability work; no fix or endurance acceptance claimed. Runtime/IPK unchanged.

- License delivery validation: full `make all`, missing/stale-notice refusals, nested SHA256SUMS and links — PASS. Real MIPS bundle and Lua module loading under QEMU verified; not hardware acceptance.

- Deliver licenses/NOTICE in main/native IPKs, Pages and offline bundle; SHA256SUMS covers nested documents. Added actual dependency evidence with open gaps. Pinned/verified LuCI timezone source. Documentation additions retain versions 5.1.28/1.0.0; IPK hashes changed, runtime/audio retained. No devices accessed.

- Licensed own code/documentation under MIT: LICENSE, RU/EN scope, README, NOTICE and vendor. Audio, archive and third-party components excluded; L1 closed, L2–L5 remain open. Owner identifies 4.mp3 as an excerpt from «Усатый нянь». Package payload/versions and devices unchanged. Validation: full `make all`, links and `git diff --check` — PASS; MIT text matches the standard, stock audio and IPK payload unchanged.

- Owner retained stock melodies; removed audio-experiment documents/links and closed timbre exploration. License audit, audio provenance and MIT preference retained. Recorded the owner’s browser time-setting observation with its limitations; no devices accessed. Full `make all`, link checks and `git diff --check` — PASS; stock MP3s and IPK payload unchanged.

- License audit records code provenance, 33 IPK metadata entries, Schoolbell-2 audio testimony and open items L1–L5. Added a repository NOTICE; stock MP3s, payload and package versions are unchanged. No devices accessed.

- Audit validation: full `make all` — PASS in WSL; `git diff --check` — PASS. Rebuilt IPK metadata, control and payload match the accepted 5.1.28 candidate. All stock MP3 hashes are unchanged. These are host checks, not hardware acceptance.

- All 75 installed files match the IPKs. The owner confirmed version 5.1.28 and existing data in the UI.

- Verified 5.1.27 → 5.1.28 upgrade from the standalone repository and target native 1.0.0 loading on the separately authorized development bench. Backup and rollback files were checked first; backup contents were preserved, automatic bells stayed off, and system/NTP settings remained unchanged. Downgrade and full hardware acceptance remain untested.

- Full make all passed: host regressions, package lifecycle and Pages; pinned cache checks, ELF and MIPS Lua/QEMU checks also passed. This is not installation or hardware acceptance.

- Added standalone MIPS builds with pinned SDK/Lua sources and 33 dependencies. Verified offline rebuild, stable native IPK, ELF ABI and QEMU loading. Devices unchanged; hardware acceptance remains separate.

- Validation: full make all and Pages-specific tests passed; a local browser verified the root UI, calendar, guide/training navigation and return. No sound or device commands were executed. Publication remains unverified.

- Migrated Pages build: root bell UI, separate RU/EN guide/training and device pages. Added explicit legacy draft copy to a new localStorage key without overwriting existing data; old data remains intact. Issue forms target schoolbell. Deployment is owner-triggered only; devices and IPK version unchanged.

- Made README compact following stm32-gdbtest and added complete RU/EN document maps. Verified all 81 transferred texts, local links and 11 pinned core references. Full make all passed; this is host validation, not new hardware acceptance.

- Accepted the user-provided FUNDING.yml without changing its link. Transferred 81 documents, preserving prose, requirements and TC identifiers; added a bilingual index distinguishing historical evidence from the current build. M1 accepted by the owner; Pages, devices and the IPK version remain unchanged.

- A second `make all` passed in an isolated snapshot containing only staged Git files, without the sibling core checkout or build cache; the host SDK was supplied separately.

- Verified host regressions, payload parity with explained differences, and git land against a temporary local remote. Target MIPS build, real offline bundle and devices are not validated in this stage.

- Imported standalone sources/dependencies with 5.1.28 build and host regressions. Offline bundles no longer require core. No Pages publication or device changes.

- Renamed the default branch to main; updated CI, rules and merge instructions.

- Fixed CI checkout depth: fetch two commits for the HEAD^ to HEAD whitespace check.

- Prepared the standalone WSL repository; archived legacy implementation under
  docs/archive/schoolbell-4 without modifying its contents or rewriting history.
- Added collaboration rules, migration inventory and foundation CI checks.
- Production 5.1.27 remains in core; no IPK, Pages publication or device changes.
