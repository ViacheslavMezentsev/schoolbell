# Changelog

[Русский](CHANGELOG.md)

## 5.1.121 — 2026-11-09

- Recorded audible offline pre/main bells with all browser pages closed; journal and counts matched.
- Fixed false NTP confirmation renewal from periodic events. Legacy events without a type are not evidence; shared UI/Pages says no fresh confirmation. Stable stratum may produce no new events despite working NTP. Deployed; the 2026-11-09 offline retest produced no false confirmation. Fresh stratum expiry and reconfirmation remain untested.

## 5.1.120 — 2026-11-08

- Verified hot substitution of AB13X with C-Media over OHCI: both bells audible, journal/counts matched, no service restart. School-year plan restored, automation off and volume unchanged. Hub port changed; EHCI was not tested.

- Recorded same-card AB13X/OHCI hot-reconnection acceptance: two audible successes, one missing-card failure, continued scheduling and correct counts. School-year plan restored, automation off and volume unchanged; another card was tested in the subsequent run; EHCI remains untested.

- 2026-11-08: recorded published Pages 5.1.120 (`ce2e3fa28c20`) verification: simulator, browser-time setting, Metrics summary, journal/counts and page reload. Remaining scenarios stay in TODO; no bench access.

- Pages adds a Device simulator below Metrics: virtual time, audio, Internet and NTP states, silent pre-bell/main-bell execution with journal and daily counts. Opening the page leaves automation off and virtual time paused.
- Removed repeated demo labels and the disconnected-hardware banner. The header demo badge is highlighted; legacy draft migration and local-data reset are inside the simulator. Guide and Training links remain available.
- Setting time from the browser now opens an immediate confirmation dialog. Pages changes only virtual time. Expired confirmation, session loss and duplicate-submission protections remain in place.
- Fixed status flicker while virtual time runs; background updates preserve unfinished time input.
- Collapsed Metrics shows free flash, saved volume and Internet status on the right using existing data. Expanding the panel hides the summary; unavailable readings are not fabricated.
- Refreshed changed CSS/JS version tokens. Full `make all` passed; the 5.1.120 bench upgrade and UI were accepted with automation off and unchanged volume. Published Pages requires a separate check.

## Earlier changes

- Verified native NTP confirmation in 5.1.119: the service event appears in the cache and Resources without restarting NTP; automatic bells remain off and volume is unchanged.

- 5.1.119: Resources now show independent Internet and NTP states, with a cached background probe and an editable/disableable target in Interface settings. Pages shares the UI without probing the network.

- Verified offline boot: boot journal captured clock rollback; after reconnection the clock was corrected while automation stayed off and data/volume were preserved.

- Extended cold-boot acceptance: previously enabled automation is off after boot, plan and volume retained; manual enablement between power cycles confirmed.

- Recorded the 5.1.118 cold-boot check: one boot event, automatic bells staying off and unchanged volume; untested scenarios remain in TODO.

- Reorganized TODO into confirmed results and remaining checks; split mixed acceptance items without claiming unperformed tests passed.

- 5.1.118: Playback help uses consistent symbols: 🔊 in the browser, 🔔 through Schoolbell.

- 5.1.117: Shortened settings help for saving, enabling automatic bells and muting device output.

- 5.1.116: Clock difference now matches the displayed whole seconds; clarified refresh and set-time actions.

- 5.1.115: The media library heading now shares the collapsible section style: font size and weight, disclosure marker and expanded spacing.

- 5.1.114: Added Built-in and User media group headings, repeated on list pages.

- 5.1.113: Renamed the collapsible Melodies area to Media library.

- 5.1.112: Fixed the Interface settings summary by removing its duplicate ID from the cheat sheet. Restored native disclosure arrows and made the Melodies area collapsible.

- 5.1.111: Collapsed settings summaries in the device UI and Pages, reusing existing data without additional requests.

- 5.1.110: Unified clock formatting with highlighted differences, Interface settings, and an actionable draft banner with a three-second completion message.

- 5.1.109: Fixed preview cache checksum formatting on 32-bit routers.

- 5.1.108: Journal capacity appears last in General, with Apply aligned to the bottom of the selector.

- 5.1.107: Settings → General offers journal sizes of 16, 32 (default), 64 and 128 KiB. Apply with ✓. Reducing the size requires confirmation and immediately retains only the newest records that fit. The local journal and its capacity stay with the device across settings restore. Automatic bell counts are preserved.

- 5.1.106: The ×× button after Copy clears all journal entries after confirmation, including entries hidden by filters. The daily automatic bell counts are retained.

- 5.1.105: Removed Journal charts and their HTTP and command queue instrumentation.

- 5.1.104: The Journal tab shows its 32 KiB retention limit.

- 5.1.103: First and last page buttons in vertical lists use a triangle with a horizontal bar.

- 5.1.102: Optional device-wide confirmation for manual speaker playback, previews in bell settings, four paging buttons and a more compact journal.

- Added a diagnostic btop build for MR3020 and a Windows 11 first-install wizard for Schoolbell 5.1.100.

- 5.1.101: Daily bell counts use ten-bell bands. Reopening metrics reuses the minute cache; resource readings persist between polls.

- 5.1.100: Starting automatic bells reuses the verified applied plan when its stored bytes still match. Icon tools and paging buttons inside tabs measure 48 × 48 CSS px.

- 5.1.99: Paging buttons in Schedules, Melodies and Journal share the standard 44 × 48 CSS px toolbar button size.

- 5.1.98: Melodies now places Add and Refresh in the paging toolbar above the table.

- 5.1.97: Add bell and delete all bells now share the paging toolbar above the schedule table.

- 5.1.96: The cheat sheet opens with four collapsed sections. Melodies and Journal use ▲ and ▼ buttons with a row range.

- 5.1.95: Grouped the quick guide into four topics and added the project repository to Feedback.

- 5.1.94: Use the stop square ■ for automatic bells in the header and Settings.

- 5.1.93: Restrict bell row pagination to the Schedules tab.

- 5.1.92: Show ten bells per schedule page and follow the inserted or moved bell across page boundaries.

- 5.1.91: Group journal entries by local day and filter by source. Show melody titles in the schedule preview.

- 5.1.90: Reuse a checked preview for the same draft and date. Both sound test routes use the bundled asset directly; browser playback supports conditional requests.

- 5.1.89: Manual bells reuse a previously validated draft and log the request after starting the player.

- 5.1.88: Browser playback and timezone reads remain available during device playback or draft writes.

- 5.1.87: General appears first in Settings. Draft, melody list and backup status reads no longer acquire writer or playback locks.

- 5.1.86: The first quick-guide entry explains how to show or hide header labels.

- 5.1.85: Optional header button labels in General settings and a centered automatic status below the header.

- 5.1.84: Read a consistent journal snapshot without contending with the editor during page reload.

- 5.1.83: Automatic bell attempts and outcomes include the scheduled local time, bell type and working schedule. Copy retains UTC offsets.

- 5.1.82: Independent warning (!) and error (!!) filters in the journal.

- 5.1.81: Prepare the durable checkpoint before the bell, report after launch, and use sign-in and sign-out icons.

- 5.1.80: Require manual start after device boot, log boots and audio failures, and remove the clock confirmation setting.

- 5.1.79: Compact sound test routes and separate clock verification settings.

- 5.1.78: Removed the manual comparison and raw draft data from the editor.

- 5.1.77: Apply the draft separately from starting automatic bells. Protect the running source on save.

- Applied calendar plans are protected from deletion, including stopped snapshots. Date previews identify the plan and playback admission checks the selected mode’s media dependencies.

- 5.1.76: explicit calendar plan selection in Settings and applied plan name in the header.


- Draft specification 1.99 defines explicit calendar plan selection in Settings and acceptance from scheduled playback through the activity chart.

- 5.1.75: periodic metrics GET reads the persisted snapshot without decoding the full journal; aggregation reuses already parsed events. The executor retries failed persistence without an open browser.

- 5.1.74: retained journal events are aggregated on service startup even with automatic bells disabled; failed initialization retries at most once per minute.

- 5.1.73: Resources heading and persistent daily counters for all successful automatic playbacks, including pre-bells; independent of the browser and journal rotation. Live 33-week heatmap distinguishes unknown history from zero; Pages does not fabricate device activity.

- 5.1.72: device indicators and the synthetic activity grid share a collapsible Metrics area below the header, with equal top and bottom padding.

- 5.1.71: extended the synthetic activity preview by 13 weeks (March 16 — November 1), widened its grid and aligned the right header controls with the top tagline.

- 5.1.70: a temporary 20-week activity preview below the main controls clearly labels synthetic data and shows example automatic bell counts on day selection. Journal, execution and saved settings are unchanged; real statistics are not connected.

- 5.1.69 / spec 1.97: UI/Pages consistency review; the save toolbar no longer overlays the editor on phones. Stale guide/README labels are updated; every volume step is tested through save/readback.

- 5.1.68: consistent 💾 draft/settings save labels and a concise discard button with a detailed tooltip. Settings explain that the whole draft is saved; toolbars and status spacing are aligned. Comparison and activation are unchanged.

- 5.1.67: preview uses ✓ beside the date; manual sound checks use compact 🔊/🔔 buttons with adjacent output labels. Status spacing is reduced; playback and saving behavior are unchanged.

- 5.1.66 / spec 1.94: whole-plan deletion sits beside +/⧉ with a 30 px gap; plan/zone apply uses ✓ and zone/clock refresh uses ↻. Empty calendar/time form status spacing is removed; no SVG or behavior changes.

- 5.1.65: range assignment and plan deletion use ✓ and a red × with a 30 CSS px gap; tooltips and deletion confirmation are retained.

- 5.1.64: calendar plan creation and copying use compact + and ⧉ buttons with tooltips and accessible names, matching schedule tools.

- 5.1.63 / spec 1.91: both calendar pagers are right-aligned and share compact journal buttons, including first/last page actions. Navigation does not change the plan.

- 5.1.62 / spec 1.90: discrete volume slider with a separate ✓ apply button preserves existing and custom saved levels. Compact schedule tools, journal refresh/copy and boundary-page icons; corrected melody editing instructions.

- 5.1.61 / spec 1.89: melody editing uses a large * instead of the pencil; the automatic-bells button no longer displays a mode icon. Tooltips, play/pause symbols and behavior are unchanged.

- 5.1.60: header CPU is rounded to an integer; CPU, Flash and volume share the “50 %” format. Measurement precision and color thresholds are unchanged.

- 5.1.59: the audio row shows the volume label and percentage on the left, controller and card name on the right, retaining compact spacing.

- 5.1.58: compact header spacing is consistent: 6 px from label to bar, 8 px to the next row. Long audio names truncate with a full tooltip and stable row height.

- 5.1.57: a blue saved-volume bar separates audio and switch rows; it uses the existing poll without changing gain and clears stale values.

- 5.1.56 / specification 1.87: the header shows the physical switch position and current device IP below audio. It reuses controls polling with bounded file reads and local interface addresses, without commands or network changes. Unavailable values are cleared and demo is explicit.

- 5.1.55: MP3 upload uses 💾, with a tooltip and accessible name matching add or replace mode. Confirmation is retained.

- 5.1.54: melody renaming no longer turns spaces into plus signs. Query values encode spaces as %20 and literal plus signs as %2B; the regression test models LuCI decoding with Cyrillic and special characters.

- 5.1.53 / specification 1.86: 🖉 opens melody editing; ✓ saves the title without an MP3 upload. Atomic metadata-only rename preserves audio/references, checks generation/automatic state/locks and reconciles uncertain responses without POST retry. Revision hashes are hidden and the player has spacing below the form.

- 5.1.52 / specification 1.85: + below the melody table opens add; ↻ in a user row opens replace. The shared form is collapsible, focuses the title and confirms discarding pending input when switching targets. Existing replacement/deletion restrictions are retained.

- 5.1.51 / specification 1.84: move controls use ▲/▼; bottom add/delete-all controls use +/××. Tooltips, accessible names and delete-all confirmation are retained.

- 5.1.50 / specification 1.83: shared UI conventions for equivalent controls, switches, icons and spacing. Icon-only add, move and copy symbols use bold 32 CSS px; button dimensions are unchanged.

- 5.1.49: row actions are ordered add/up/down, playback, then delete, with 30 CSS px between groups.

- 5.1.48 / specification 1.82: per-row plus inserts a bell and focuses its time; up/down arrows reorder whole rows. Clear rows is renamed Delete all bells with an explicit confirmation. Changes remain in the draft until saved. Both switches share one column with a 30 CSS px gap.

- 5.1.47: consistent 28 px delete icons; Enabled, Pre-bell and Actions column headings are centered.

- 5.1.46: the CPU header shows the weekday and device-local date/time (`Вс 01.11.2026 · 16:24`), independently of the browser timezone.

- 5.1.45 validation: `make all` — PASS; forms parsed as YAML, RU/EN guides available (HTTP 200). Development bench checks covered 81 package files, 12 HTTP assets, unchanged data and 232 preserved journal entries. Volume remains 50%, automatic bells remain off; no audio was played.

- 5.1.45: device and Pages Feedback now link to schoolbell Issues. Bug/feature forms cover the device, demo and installation; RU/EN guides are linked from forms, the issue chooser and Feedback. Remove old core links and the temporary unavailable-forms notice.

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
