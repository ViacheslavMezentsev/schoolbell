# Changelog

5.1.27: dynamic user MP3 collection replaces eight fixed positions; existing IDs/references and six protected bundled tracks remain. MP3 up to 64 KB (64000 bytes) is a recommendation, not a rejection threshold. Current file admission remains 512 KiB/60 s, metadata 16 KiB and archive 2 MiB. The separate 2 MiB media-library quota is removed; actual free space, staging and system reserve are checked. Journal: two 16 KiB segments, 32 KiB total, seven-day retention. A Flash bar below CPU shows free MiB/percent alongside uptime; used space above 75% is yellow and above 90% red. Pages synchronized.

Development bench updated after a verified backup: before/after .sbb is byte-identical, auto-off and system/NTP guards retained. Acceptance device untouched. Visual acceptance is pending.

5.1.26: include clock_set.lua in the IPK. Archive verification now checks literal schoolbell runtime dependencies. The 5.1.25 packaging omission was discovered after deployment; source-tree tests did not detect it.

Development bench verification: installed 5.1.26 adapter loads and passes a fake-setter test; data retained, auto-off, clocks/NTP unchanged. Acceptance device restored to 5.1.23; actual clock setting remains unaccepted.

5.1.25 (host): unified Date and time settings combine timezone, readings, confirmed browser-time setting and trust controls. The Lua system adapter disables automatic bells, sets UTC with stock date and verifies readback; NTP, timezone and services are unchanged. Pages simulates the command. Device deployment and acceptance remain pending.

5.1.24: removed schedule row-count caps across storage, backup, portable plans and Pages. Byte budgets remain; larger plans require a compatible import target. Host checks only; not installed.

Pages: separate RU/EN draft guide, Guide links in demo notice/module card, conceptual bench/audio SVGs. No package or device changes.

2026-10-31: 5.1.22 installed and owner UI acceptance completed; Pages published. Isolated browser .sbp user-MP3 roundtrip accepted within its documented scope. [New-device acceptance plan](../acceptance/ACCEPTANCE_RUN.en.md) prepared; artifacts still need freezing, no flashing/run authorized.

Historical stages below (not current status):

5.1.22 (host): device local time HH:MM is right-aligned above the CPU bar; uptime is below (page age in Pages). Reuses existing clock polling and hides stale time. Default idle logout is 30 minutes; existing choices are preserved. Major section gaps are aligned and the bell-delete cross enlarged. Pages synchronized; this version is not installed on the device.

5.1.21 (host): selected-plan .sbp export with user audio/dependencies; complete file before HTTP, locks released before download. Pages synchronized; not installed.

5.1.20: add-only .sbp import with preview, conflicts, free slots, durable intent/resume/receipts and host/HTTP/UI tests. Pages keeps read-only preview. No installation.

5.1.11 (host only, not installed): collapsed Statistics switches between executor mailbox and HTTP views. The real single-slot time/enable command mailbox reports waiting depth, running state, wait times and completions in twelve 5-second bins across clients, in /tmp only; telemetry faults cannot block commands. Stop, audio and HTTP reads bypass this mailbox. Pages models its own training commands with zero wait. A thin whole-device CPU line below the title uses existing polls (idle+iowait excluded; green through 75%, yellow above 75%, red above 90%, unknown grey). Resolve problem is above the status panel on the right. No extra HTTP polling.

5.1.10: explicit chart hints show reads, commands and failures for the selected interval on hover, tap or keyboard arrows. Selection survives refresh until the interval leaves the minute window. Pages synchronized.

5.1.9: the collapsed draft panel matches the upper status panel: theme background and a yellow left border. The heading reads “Музыкальный настраиваемый звонок”. The 5.1.8 traffic chart is retained; Pages shares the UI.

5.1.8 (host only): Journal shows passive, tab-local module API traffic in twelve 5-second bins, split into reads/commands, with HTTP/network failures, pending requests and mean/maximum time to HTTP headers. This does not measure internal worker exchanges, bytes or command execution latency. Memory only, no additional requests or device writes; Pages measures its local model. Not installed.

5.1.7 (host only): audio routes explicitly distinguish browser playback on a computer/phone from Shkolnik speakers. The draft panel starts collapsed with a warning background; status stays visible, save/apply actions are available when expanded. Expanding does not change the plan. Pages synchronized; not installed.

5.1.6 (host verification, not installed): Resolve problem explains status and offers safe reading/navigation to settings, sign-in, media or journal. It never enables bells, bypasses protection, changes clocks or replays commands. No fresh data does not claim a network failure. UI wording uses device; copy identifiers are in technical details. Pages shares the interface.

5.1.5 installed and accepted by the owner in a short quiet-day test: the header button resumes the previously applied plan (green Running) and stops it (yellow Off). Four samples over 12 seconds confirmed operation and clock trust without recurring observation_gap. Final state: automatic bells off, applied copy retained, exported backup byte-identical, clock/NTP and system configuration unchanged. This does not validate audible bells, maximum-size plans or sustained operation. Pages is synchronized locally; publication remains a separate owner action.

5.1.5: bounded exact-byte SHA-256 cache (four entries up to 16 KiB) and clock observation during computation without nested checkpoint writes; gap threshold unchanged. Confirmed results clear waiting text; clock confirmation errors are explained. Short device button acceptance is complete; limitations are listed above.

5.1.5: left-align the status below the full button group and size its background to the text. Pages synchronized; installation and short acceptance completed.

5.1.4: automatic-bell status moved below the entire header button group; responsive layout and Pages demo synchronized. Command logic unchanged; not installed.

Specification 1.55: [signed manifest and discovery API](https://github.com/ViacheslavMezentsev/openwrt-modbus-core/blob/243a7ccad6aeb2499d3efd5d0c4cef9e822d393e/docs/core/SIGNED_RELEASES.en.md), multiple components/platforms and compatible application versions. Requirements only; no updater or router changes.

Specification 1.54: Shkolnik update notifications, stable identity/versioning and a simple administrator journey through the shared service. Bells remain disabled after installation; update UI is not implemented.

The save label uses “device” instead of “router”; Pages explicitly saves in the demo.

5.1.2: pagination is immediately above the months and repeated below them. Both controls share page and boundary states; bottom navigation scrolls to the calendar start. Pages is synchronized.

The product is named Shkolnik (previously Shkolnik-4), without a version in its name. Technical schoolbell package names, URLs and data formats are unchanged.

5.1.1: range months appear consecutively across year boundaries; long plans page through 12 months without changing assignments. Shared router and Pages interface.

5.1.0: live named calendar plans with non-overlapping inclusive ranges, painting, resize and civil-time preview. Legacy years are read without rewriting; the editor saves ranges. Pages shares the editor/format with bundled media only. New plan/backup data requires 5.1.0; portable dependency bundles remain planned. Host checks only, no installation.

5.0.37: logout verifies that the current session is absent after destroy; an empty reply alone proves neither success nor failure. ubus errors remain uncertain. Session loss disables sound/automatic controls and shows a login prompt; late replies cannot restore access. Pages synchronized. Host-tested, not installed.

5.0.36: login/logout status moved out of header controls into a normal-sized status line; Login styled as a button. Added a Login and Logout cheat-sheet route; Pages shares the interface.

5.0.35 (host): compact same-tab login with temporary draft handoff and no visible timer. A separate [named-range prototype](../architecture/RANGE_PLANS.en.md) is included in Pages; live storage remains year-based. No router installation in this step.

Schoolbell 5.0.34: session recovery without replay or replacing editor changes, CSRF-protected logout, configurable browser idle countdown, striped cheat-sheet routes and separate behavior notes. Host only; Pages synchronized.

5.0.33: first Cheat sheet tab covers setup, calendar, sound, media, reconciliation and backup. No automatic actions; Pages shares the same guide.

Installed 5.0.27 with native clock1.0.0: real mailbox contention and browser confirmation verified. Control enabled, time confirmed, automatic bells disabled; clocks/NTP unchanged.

5.0.27: clock-result lock contention is pending, not failure; bounded GET waiting, no POST replay. Storage errors are distinct from busy.

5.0.26: native clock dependency and authenticated time confirmation/bypass UI, worker-owned activation, host tests. Not installed. See [time controls](../architecture/CLOCK_UI.en.md).


5.0.5: lock-free atomic mute snapshots; distinct network/auth/storage errors.

5.0.4: persistent mute, owned-child cancellation, manual/pre-bell media test/0–4, daily or annual preview mode. No automatic bell activation.

5.0.3: fix UCI commit (-p instead of -P for commit only); regression reads the file after closing staging, not just the staged view.
[Русский](CHANGELOG.md)

## [Unreleased]

Specification 1.75: replace schedule/plan/media quotas with shared file admission and resource checks; retain journal rotation, integrity and add-only import. Migration and TC-184–187 remain pending; no code, package or device changes.


- Shkolnik 5.1.23: outlined automatic status, theme-aware colors and aligned Pages Guide. Schedule rows offer red deletion and selected melody previews in browser/device speakers (hardware disabled in Pages). Host checks only; not deployed.

- 5.1.19: device uptime above the CPU bar on the right, using existing polling; revised Russian heading. Pages labels its simulated page age explicitly. Host only, no installation.

- Pages: selected-plan .sbp export with bundled dependencies, explicit timezone and read-only import preview; conflicts/renaming, SHA validation and host/UI TC-178. No installation or IPK5.1.18 changes.

Lua/JS selected-plan .sbp assembly: complete dependencies, streamed user audio, 35 shared host cases; [API and scope](../formats/PORTABLE_PLAN_EXPORT.en.md). Specification 1.69, TC-177; no IPK/UI/device integration.

- Pure .sbp Lua/JS preview: calendar dependencies, conflicts and additive mapping;45 shared host scenarios, [API/scope](../formats/PORTABLE_PLAN_PREVIEW.en.md). Specification1.68, TC-176; no IPK/UI/installation.

- Isolated Lua/JS .sbp codecs and shared62-vector corpus: [coverage/API](../formats/PORTABLE_PLAN_CODEC.en.md). Specification1.67, TC-175; no IPK/UI/installation. Next: export assembly and then Pages integration.

- Accepted framing, fields, bounds and API: [PORTABLE_PLAN_WIRE.en.md](../formats/PORTABLE_PLAN_WIRE.en.md). Question8.2.15 is closed by agreement; system import is not implemented.

Accepted [.sbp contract](../formats/PORTABLE_PLAN.en.md): selected calendar plans with complete dependencies, bundled-only Pages, preview and additive non-overwriting import. Specification1.66; TC-168–174 planned. No implementation/installation; package remains5.1.18. Next: exact wire/API, bounds and recovery before the codec.

Status on 2026-10-28: 5.1.18 installed and accepted by the owner. Draft read recovery after busy (isolated directory), toolbar placement and enlarged journal arrows have been checked; data and system settings retained. Automatic bells off, clock/NTP unchanged. TODO reconciled; proposed next stage is the complete portable calendar-plan dependency contract, followed by Pages/device export and import. This does not certify unattended recovery after power loss.

5.1.18: journal navigation arrows use 28 px glyphs in compact buttons. The Pages demo notice is collapsed, with a blue information border and Details, after other notices and before tabs; expand it for explanations and reset. No device installation.

5.1.17: the complete journal pager (page indicator and four buttons) sits on the right of the same toolbar as refresh, filter and copy on the left. Groups wrap on narrow screens. Shared Pages UI synchronized; no device installation.

5.1.16: draft reads retry explicit busy only (up to three GETs, 0.5/1 s delays); storage errors are not disguised as contention. Retry remains available after failure; unsaved edits and session loss are protected against late responses. Right-aligned journal navigation adds first/last pages, icons and tooltips. Shared Pages UI synchronized; no device installation.

### Added

- 5.1.15: compact mute label; journal pages of 20 rows, error filter, full loaded-history clipboard copy (including HTTP fallback), device-local timestamps. The 16 KiB bound remains; entries older than 7 days are hidden on reads and atomically pruned on append without resetting sequence numbers. Future records survive clock rollback. Pages synchronized; demo retains at most 80 events.
- 5.1.14: Journal → Statistics → HTTP requests now includes an API-method table (for example, GET automatic and POST test). Each row shows starts, completions, HTTP/network errors, pending responses and mean/maximum latency to response headers. The same twelve 5-second start-time bins apply; requests pending beyond that window remain visible. URL parameters, tokens and bodies are not retained; different arguments to the same POST method are grouped. HTTP 200 with an operation refusal is not an HTTP error; melody duration and command execution are not separately measured. Collection is passive across module tabs, without additional requests or device writes. Pages shares the code over its local model; no device installation.

### Changed

- 2026-10-28: 5.1.15 installed after backup; the owner accepted journal pages, error filtering, full-history copy and the compact mute button. Settings, plans and melodies preserved; automatic bells disabled, clock/NTP unchanged. Recommended next steps: recover draft reads after temporary storage contention, then a portable calendar-plan bundle. This is a plan, not implementation or power-loss acceptance.

- 5.1.13: compact sound-status/diagnostics row removes the empty header gap. Status and draft notices are grouped above the tabs, both with a Details hint. Only lower CPU tick labels were removed; percentage and colors remain. Feedback credits author Vyacheslav Mezentsev and co-author Codex (OpenAI). Pages shares the layout; no device installation.

- 5.1.12: automatic status reads no longer revalidate an unchanged plan. After full validation, the worker publishes a private RAM snapshot bound to the exact active-file bytes and current boot. GET compares bytes; a mismatch, age over 40 s, damaged snapshot or installation/restore operation cannot confirm readiness. Validation on changes/application and playback admission remains. No additional HTTP requests or flash writes. Pages keeps the shared interface and does not simulate hardware latency. This stage does not update the installed package.

- 5.1.3 (host only): compact Auto bells button with a confirmed colored status. Stop retains the applied snapshot; resume checks its revision/generation, time and media, without reading or applying the draft. Pages simulates the same flow without automatic audio. No router installation.

- Schoolbell 5.0.32: deleting a fixed selection requires explicit replacement; clearing the last year explains fixed/quiet. Reconciliation retains local edits, reads both copies and never repeats writes/activation; subsequent save retains CAS. Pages shares UI and regressions. Host only, no installation or publication.

- Added a static schoolbell journey/completeness plan: deletion dependencies, undo/reconciliation, active preview, time/media and LuCI roles. Recorded HTTP/admin-login limitations; no implementation or router changes.

- Added the schoolbell 5.0.31 Markdown user guide: startup, schedules/year plan, sound, media, time, backups and troubleshooting, including current UI limitations. No runtime or router changes.

- Schoolbell host startup audit: 11 additional real-worker scenarios with injected boot/TZ/clocks/reference and an independent 15+6 oracle. Documented reboot versus same-boot restart with bypass; no runtime/IPK or router changes.

- Added the draft schoolbell 5.x acceptance programme: 12 end-to-end scenarios, legacy parity, attended versus future unattended startup, release gates and open numerical budgets. No runtime, IPK or router changes.

- Schoolbell 5.0.31: lifecycle uses declared Lua/nixio instead of missing BusyBox stat; IPKs explicitly include parent directories; owned LuCI bytecode is invalidated. Host regressions and target installation/recovery downgrade/upgrade passed with identical exported data and automatic bells disabled. Native clock archive receives directory records; its runtime and installed module are unchanged.

- Schoolbell 5.0.28: full script IPK, safe auto-off lifecycle, pinned offline dependencies and joint core release manifest; host install/upgrade/rollback tests. No router installation.

- 5.0.25: executor clock admission with explicit optional bypass and injected-clock tests. Not deployed. Native dependency and confirmation UI remain deployment prerequisites: [integration scope](../architecture/CLOCK_EXECUTOR.en.md).


- 5.0.24: backup status and download retry transient busy GETs up to four attempts with 200/500/1000 ms delays. Download retains one overall 180 s deadline. Restore POST is never automatically retried; exhaustion leaves the status check available.


- 5.0.23: title and filename spaces use %20 for LuCI 19.07 CGI; literal plus signs remain plus signs.


- 5.0.22: MP3 upload and restore carry the CSRF token in Authorization: Bearer, forwarded by uhttpd 19.07 CGI. A LuCI session and an exact CSRF token match remain required; tokens never enter URLs. CGI previously dropped X-CSRF-Token, causing HTTP403 before file writes.


- 5.0.21: unconfirmed uploads retain the original error and operation ID; the list is fetched again without resending the file. Failed reads preserve disabled stale rows until refresh. This is a diagnostic fix; the browser upload failure cause remains under investigation.

- 5.0.20: transient media-list busy receives up to four GET attempts with 200/500/1000 ms pauses. Exhaustion preserves the previous list as unconfirmed, disables actions and leaves refresh available. Busy is not called corruption. Upload POST is never retried.

- Schoolbell 5.0.19: fix empty LuCI audio responses on Lua 5.1. Streaming sources/sinks use coroutine-safe protection throughout; regressions cover yielding upload/download and cleanup after disconnect.

- Schoolbell 5.0.18: confirmed uploads automatically refresh the media list. Every populated row has browser playback; empty slots are labeled in the table and selectors and cannot be played. A refresh failure does not reupload the saved file. The demo includes all six bundled melodies. Host checks without sound; not deployed to the router.

- Schoolbell 5.0.17: backup downloads have a 180-second overall deadline, including the response body. Timeout/disconnection returns control; check status before retrying. Late responses are not saved and restoration is never started automatically. Pages displays the UTC build date and commit. Host-tested; not deployed to the router.

- Schoolbell 5.0.16: the calendar starts in view mode; clicking a date previews draft bells without erasing its assignment. Explicitly select a schedule or eraser to paint. A shared panel distinguishes the draft from the active snapshot. Save edits first, then separately apply the checked revision; changes from another window require reloading. Preview is not execution evidence. Validated on the host and in the browser demo; not deployed to the router.

- Schoolbell 5.0.15: storage usage >75% turns yellow, >90% red, with a text warning; shared router/demo styles. Not deployed to the router.

- Specification 1.34: BOOTTIME/REALTIME system ports and bounded FD reference storage, real host operations/fault tests; overlapping rounded observation brackets. No payload/executor/router changes.

- Specification 1.33: isolated UTC-ms reference codec, atomic CAS store and clock trust model; host boundary/fault tests. Version 5.0.14 and payload unchanged.

- Specification 1.32 accepts schoolbell-clock/1, hourly checkpointing and observation/confirmation budgets; TC-120–124 planned. Requirements only; no implementation or package version change.

- Accepted clock-trust and rollback contract (specification 1.31): automatic admission gate, separate time confirmation and enable; TC-113–119 planned. Documentation only, no version/runtime/router changes.

- Schoolbell 5.0.14: fix yielding LuCI backup download/upload; timezone is the first settings section.

- Schoolbell 5.0.13: backup/restore with automatic ringing disabled; eight user melodies with display titles; manual sound checks in the Melodies tab.

- Schoolbell 5.0.12: six protected bundled melodies plus five user slots; missing user media blocks plan activation.

- Schoolbell 5.0.11: persistent-storage usage bar, free space, protected reserve and retained media usage.

- Schoolbell 5.0.10: bounded melody uploads/replacement via the existing media manager, shared player gate, CAS and browser preview; no automatic activation.

- Schoolbell 5.0.9: aligned settings fields and subtle alternating table rows in both themes.

- Fixed in schoolbell 5.0.8: a normal polling delay no longer recursively writes the time watermark; reuse the verified serialized snapshot without repeating SHA before playback.

- Schoolbell 5.0.7: persisted router playback attenuation in Settings; takes effect on the next bell while Mute cancels the current one. The system mixer is unchanged.

- Schoolbell 5.0.6: independent fixed/annual bell service, explicit saved-plan activation, Mute and no catch-up playback. Reboot/timezone changes require checking the clock and reactivation. System time and NTP are unchanged.

- Schoolbell 5.0.2: distinct xterm256 colors with black/white text, an in-module time-zone selector with confirmation and conflict checks; a GitHub Pages landing page and browser-local demo sharing the router UI.

- Feedback tab: instructions and bug/feature form links, version context and a public-data warning.

- Schoolbell 5.0.1: persistent per-schedule colors from 16 muted shades, automatic assignment and manual selection, consistent across the list, calendar and preview. Journal text is left-aligned; time-zone settings are offered independently of clock synchronization.

- Schoolbell 5.0.0: collapsible status, tabs preserving edits, router/browser clocks and a LuCI synchronization link; private rotating journal with up to 16 KiB of records (24 KiB during commit). Automatic bells remain disabled; the UI never changes system time automatically.

- Schoolbell annual calendar: date/range assignments, shared draft persistence and civil-time main/preliminary bell preview. Legacy drafts remain unchanged on read; automatic execution stays disabled. Specification 1.22.

- Schoolbell schedule editor: names, rows, copying, persistent inactive drafts, reload/save, conflict and storage-failure checks. Automatic bells and annual calendar remain disconnected; specification 1.21.

- Working schoolbell manual LuCI sound page: browser and router USB audio routes for test.mp3, authentication/POST token and bounded diagnostic process. Both routes and audible sound confirmed by the user on MR3020; automatic scheduling is not integrated.

- Isolated MR3020 checks passed in tmpfs and a separate persistent directory; fixtures removed, no reboot/power loss.

- Schoolbell spec 1.19: isolated prepared-media manager, pointer checksums, fsync/rename, reconciliation and GC; 25 host process-crash checkpoints. No core/queue/sound; MP3 validation and full calendar schemas remain unconnected.

- Schoolbell spec 1.18 accepts strict JSON/SHA-256 revisions, layout, protective MR3020 quotas and current/recovery commit order. TC-83–90 planned; exact metadata fields/crash transitions remain open. Documentation only; no implementation, sound or router changes.

- Schoolbell specification 1.17 accepts persistent media, immutable replacement, consistent bundles and power-loss recovery. Fallback leaves automatic bells paused; TC-73–82 are planned. Requirements only; no implementation, sound or router/IPK changes.

- Exact media revision retention at admission: bounded native catalog, private leases and nine TC-72 host groups. Schoolbell specification 1.16. Mockup settings show separate browser-device and router-speaker test routes; buttons only simulate selection, without sound/API/router changes. IPK unchanged.

- Schoolbell spec 1.15: isolated bridge connects the Lua queue and Linux player; launching/finishing, signal outcomes and cleanup before the next start. Ten fixture-child host groups; no core, audio device, sound or router/IPK changes.

- Schoolbell spec 1.14: isolated Lua 5.1 Linux player binding, userdata and eight host groups with a fixture process, GC/OOM and recoverable handles. No queue/core, audio device, sound or router/IPK changes.

- Saved the accepted standalone schoolbell UI mockup: annual calendar, schedules, media library, player states and system/dark/light themes. Synthetic data only; no API, audio, router changes or IPK inclusion.

- Schoolbell specification 1.13: isolated Linux C player adapter and a test child without an audio device; 13 host process/fault groups, FD checks and inherited flock after owner death. No Lua binding, core, madplay/audio or router changes; IPK unchanged.

- Schoolbell specification 1.12: isolated Lua SBPE codec and player API model with injected operations. 32 host test groups cover frames, generations, deadlines/outcomes, quotas and cleanup. No native binding, processes, sound, core or router changes; IPK unchanged.

- Schoolbell specification 1.11 fixes SBPE/v1 big-endian, generations, attempt counters and parameter ranges. TC-61–65 are planned; requirements only, no code/audio/router changes.

- Schoolbell specification 1.10 defines result/error fields, executable-identity exec evidence, a 16-byte frame and 64/64/8/8 budgets. TC-56–60 are planned; requirements only, code and router unchanged.

- Schoolbell specification 1.9 accepts native player mechanisms and begin/poll/release, inherited flock FD, stdin media, a 2000 ms timeout and /dev/null. TC-50–55 are planned; madplay properties require verification. Code and router unchanged.

- Schoolbell specification 1.8 accepts the system player contract: launching/exit, retained media revisions and blocking after failures. TC-43–49 are planned; implementation, sound, IPK and router are unchanged.

- Schoolbell specification 1.7: isolated Lua playback queue, per-resource FIFO, monotonic TTL/UTC, owner cancellation and an injectable player. 24 host test groups; unknown outcomes retain the resource. No core/process/audio/router integration; media-only IPK unchanged.

- Schoolbell specification 1.6: isolated Lua calendar with fixed/annual modes, quiet dates, midnight preliminary bells and gap/fold rejection. 29 groups, 14,404 independent date vectors and original 15+6 across a full leap year. No core/audio/router integration; media-only IPK unchanged, full parity remains pending.

- Schoolbell specification 1.5 clarifies schema/migration ownership, calendar/media validation and fleet templates versus backups under core 1.16. TC-34/35 are planned; runtime and preview are unchanged.

- Specification 1.4 defines functional parity with the original: two schedule modes, preliminary bells, browser clock synchronization, local UI and five melodies plus test. Added planned TC-14–33, media management and backup. Preview 0.0.1 and runtime are unchanged.

- Specification 1.3 owns audio execution, FIFO/expiry/cancellation transferred from core, with offline dependencies and persistent storage. Manual playback is confirmed; the functional package is not implemented.

- Imported six original MP3s with a manifest; preview IPK 0.0.1 includes only test.mp3 and NOTICE. Specification 1.2 references core 1.7; player/scheduler are not implemented.

- Specification 1.1 references the accepted core 1.6 policy; application requirements and runtime are unchanged.

- Established specification 1.0 with its own requirement/test namespace. Runtime unchanged.
