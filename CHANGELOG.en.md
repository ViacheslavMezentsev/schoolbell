# Changelog

[Русский](CHANGELOG.md)

## Unreleased

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
