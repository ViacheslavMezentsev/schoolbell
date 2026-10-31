# Schoolbell package

5.1.27: dynamic user MP3 collection replaces eight fixed positions; existing IDs/references and six protected bundled tracks remain. MP3 up to 64 KB (64000 bytes) is a recommendation, not a rejection threshold. Current file admission remains 512 KiB/60 s, metadata 16 KiB and archive 2 MiB. The separate 2 MiB media-library quota is removed; actual free space, staging and system reserve are checked. Journal: two 16 KiB segments, 32 KiB total, seven-day retention. A Flash bar below CPU shows free MiB/percent alongside uptime; used space above 75% is yellow and above 90% red. Pages synchronized.

5.1.25 (host): unified Date and time settings combine timezone, readings, confirmed browser-time setting and trust controls. The Lua system adapter disables automatic bells, sets UTC with stock date and verifies readback; NTP, timezone and services are unchanged. Pages simulates the command. Device deployment and acceptance remain pending.

2026-10-31: 5.1.22 installed and owner UI acceptance completed; Pages published. Isolated browser .sbp user-MP3 roundtrip accepted within its documented scope. [New-device acceptance plan](../acceptance/ACCEPTANCE_RUN.en.md) prepared; artifacts still need freezing, no flashing/run authorized.

Historical stages below (not current status):

5.1.22 (host): device local time HH:MM is right-aligned above the CPU bar; uptime is below (page age in Pages). Reuses existing clock polling and hides stale time. Default idle logout is 30 minutes; existing choices are preserved. Major section gaps are aligned and the bell-delete cross enlarged. Pages synchronized; this version is not installed on the device.

[Selected-plan device export](../formats/PORTABLE_PLAN_EXPORT_DEVICE.en.md): candidate5.1.21, host-tested, not installed.

Candidate5.1.20: [add-only .sbp import](../formats/PORTABLE_PLAN_IMPORT.en.md), host transaction/HTTP/UI tests and synchronized Pages; no installation. Device remains5.1.19.

Host build5.1.19 adds uptime above CPU and the revised heading. Installed5.1.18 was not updated.

Pages: selected-plan .sbp export and read-only import preview. [Details](../formats/PORTABLE_PLAN_PAGES.en.md); IPK5.1.19 changes only heading/uptime; .sbp remains Pages-only.

Lua/JS selected-plan .sbp assembly: complete dependencies, streamed user audio, 35 shared host cases; [API and scope](../formats/PORTABLE_PLAN_EXPORT.en.md). Specification 1.69, TC-177; no IPK/UI/device integration.

Pure .sbp Lua/JS preview: calendar dependencies, conflicts and additive mapping;45 shared host scenarios, [API/scope](../formats/PORTABLE_PLAN_PREVIEW.en.md). Specification1.68, TC-176; no IPK/UI/installation.

Isolated Lua/JS .sbp codecs and shared62-vector corpus: [coverage/API](../formats/PORTABLE_PLAN_CODEC.en.md). Specification1.67, TC-175; no IPK/UI/installation. Next: export assembly and then Pages integration.

Accepted framing, fields, bounds and API: [PORTABLE_PLAN_WIRE.en.md](../formats/PORTABLE_PLAN_WIRE.en.md). Question8.2.15 is closed by agreement; system import is not implemented.

Accepted [.sbp contract](../formats/PORTABLE_PLAN.en.md): selected calendar plans with complete dependencies, bundled-only Pages, preview and additive non-overwriting import. Specification 1.67; full-import TC-168–174 remain planned. Byte codecs have separate TC-175 coverage; package remains 5.1.18.

Status on 2026-10-28: 5.1.18 installed and accepted by the owner. Draft read recovery after busy (isolated directory), toolbar placement and enlarged journal arrows have been checked; data and system settings retained. Automatic bells off, clock/NTP unchanged. TODO reconciled; next stages are the dependency/preview model, followed by Pages/device export and import. This does not certify unattended recovery after power loss.

5.1.18: journal navigation arrows use 28 px glyphs in compact buttons. The Pages demo notice is collapsed, with a blue information border and Details, after other notices and before tabs; expand it for explanations and reset. No device installation.

5.1.17: the complete journal pager (page indicator and four buttons) sits on the right of the same toolbar as refresh, filter and copy on the left. Groups wrap on narrow screens. Shared Pages UI synchronized; no device installation.

5.1.16: draft reads retry explicit busy only (up to three GETs, 0.5/1 s delays); storage errors are not disguised as contention. Retry remains available after failure; unsaved edits and session loss are protected against late responses. Right-aligned journal navigation adds first/last pages, icons and tooltips. Shared Pages UI synchronized; no device installation.

2026-10-28: 5.1.15 installed after backup; the owner accepted journal pages, error filtering, full-history copy and the compact mute button. Settings, plans and melodies preserved; automatic bells disabled, clock/NTP unchanged. Recommended next steps: recover draft reads after temporary storage contention, then a portable calendar-plan bundle. This is a plan, not implementation or power-loss acceptance.

5.1.15: compact mute label; journal pages of 20 rows, error filter, full loaded-history clipboard copy (including HTTP fallback), device-local timestamps. The 16 KiB bound remains; entries older than 7 days are hidden on reads and atomically pruned on append without resetting sequence numbers. Future records survive clock rollback. Pages synchronized; demo retains at most 80 events.

5.1.14: Journal → Statistics → HTTP requests now includes an API-method table (for example, GET automatic and POST test). Each row shows starts, completions, HTTP/network errors, pending responses and mean/maximum latency to response headers. The same twelve 5-second start-time bins apply; requests pending beyond that window remain visible. URL parameters, tokens and bodies are not retained; different arguments to the same POST method are grouped. HTTP 200 with an operation refusal is not an HTTP error; melody duration and command execution are not separately measured. Collection is passive across module tabs, without additional requests or device writes. Pages shares the code over its local model; no device installation.

5.1.13: compact sound-status/diagnostics row removes the empty header gap. Status and draft notices are grouped above the tabs, both with a Details hint. Only lower CPU tick labels were removed; percentage and colors remain. Feedback credits author Vyacheslav Mezentsev and co-author Codex (OpenAI). Pages shares the layout; no device installation.

5.1.12: automatic status reads no longer revalidate an unchanged plan. After full validation, the worker publishes a private RAM snapshot bound to the exact active-file bytes and current boot. GET compares bytes; a mismatch, age over 40 s, damaged snapshot or installation/restore operation cannot confirm readiness. Validation on changes/application and playback admission remains. No additional HTTP requests or flash writes. Pages keeps the shared interface and does not simulate hardware latency. This stage does not update the installed package.

5.1.11 (host only, not installed): collapsed Statistics switches between executor mailbox and HTTP views. The real single-slot time/enable command mailbox reports waiting depth, running state, wait times and completions in twelve 5-second bins across clients, in /tmp only; telemetry faults cannot block commands. Stop, audio and HTTP reads bypass this mailbox. Pages models its own training commands with zero wait. A thin whole-device CPU line below the title uses existing polls (idle+iowait excluded; green through 75%, yellow above 75%, red above 90%, unknown grey). Resolve problem is above the status panel on the right. No extra HTTP polling.

5.1.10: explicit chart hints show reads, commands and failures for the selected interval on hover, tap or keyboard arrows. Selection survives refresh until the interval leaves the minute window. Pages synchronized.

5.1.9: the collapsed draft panel matches the upper status panel: theme background and a yellow left border. The heading reads “Музыкальный настраиваемый звонок”. The 5.1.8 traffic chart is retained; Pages shares the UI.

5.1.8 (host only): Journal shows passive, tab-local module API traffic in twelve 5-second bins, split into reads/commands, with HTTP/network failures, pending requests and mean/maximum time to HTTP headers. This does not measure internal worker exchanges, bytes or command execution latency. Memory only, no additional requests or device writes; Pages measures its local model. Not installed.

5.1.7 (host only): audio routes explicitly distinguish browser playback on a computer/phone from Shkolnik speakers. The draft panel starts collapsed with a warning background; status stays visible, save/apply actions are available when expanded. Expanding does not change the plan. Pages synchronized; not installed.

5.1.6 (host verification, not installed): Resolve problem explains status and offers safe reading/navigation to settings, sign-in, media or journal. It never enables bells, bypasses protection, changes clocks or replays commands. No fresh data does not claim a network failure. UI wording uses device; copy identifiers are in technical details. Pages shares the interface.

5.1.5 installed and accepted by the owner in a short quiet-day test: the header button resumes the previously applied plan (green Running) and stops it (yellow Off). Four samples over 12 seconds confirmed operation and clock trust without recurring observation_gap. Final state: automatic bells off, applied copy retained, exported backup byte-identical, clock/NTP and system configuration unchanged. This does not validate audible bells, maximum-size plans or sustained operation. Pages is synchronized locally; publication remains a separate owner action.

5.1.5: status below the controls is left-aligned, with a colored background sized to the message. Pages shares this style.

5.1.4 (host only): the colored automatic-bell status spans the entire header button group, including sign-in/out. Pages shares the same markup and styles. Command behavior is unchanged; no device installation.

5.1.3 (host only): compact Auto bells button with a confirmed colored status. Stop retains the applied snapshot; resume checks its revision/generation, time and media, without reading or applying the draft. Pages simulates the same flow without automatic audio. No router installation.

Specification 1.55: [signed manifest and discovery API](https://github.com/ViacheslavMezentsev/openwrt-modbus-core/blob/243a7ccad6aeb2499d3efd5d0c4cef9e822d393e/docs/core/SIGNED_RELEASES.en.md), multiple components/platforms and compatible application versions. Requirements only; no updater or router changes.

[Release checks and updates — requirements](https://github.com/ViacheslavMezentsev/openwrt-modbus-core/blob/243a7ccad6aeb2499d3efd5d0c4cef9e822d393e/docs/core/RELEASE_UPDATES.en.md). Not implemented yet.

The product is named Shkolnik (previously Shkolnik-4), without a version in its name. Technical schoolbell package names, URLs and data formats are unchanged.

5.1.0: live named calendar plans with non-overlapping inclusive ranges, painting, resize and civil-time preview. Legacy years are read without rewriting; the editor saves ranges. Pages shares the editor/format with bundled media only. New plan/backup data requires 5.1.0; portable dependency bundles remain planned. Host checks only, no installation.

[Named ranges: prototype](../architecture/RANGE_PLANS.en.md)

5.0.32: explicit schedule/year dependencies and local/saved reconciliation. Pages demo and host tests updated; router remains on 5.0.31, publication separate.

[UI journeys, symmetric actions and security plan](../architecture/UI_COMPLETENESS.en.md) — проект для согласования / draft.

[Schoolbell user guide](../user/USER_GUIDE.en.md) — schoolbell 5.0.31.

[Startup audit and host checks](../architecture/STARTUP_AUDIT.en.md): boot/TZ, clock reference and an independent 15+6 oracle; no hardware acceptance.

[Schoolbell 5.x acceptance programme](../acceptance/ACCEPTANCE.en.md): draft release gates, AC-01–12 journeys, parity and open budgets. Not hardware acceptance or a specification change.

Schoolbell 5.0.31: target opkg compatibility fixes (no stat dependency, explicit archive directories, owned LuCI cache invalidation). Installation, recovery downgrade and upgrade preserve data and leave automatic bells off; no clock/NTP changes.

Schoolbell 5.0.28: complete engineering IPK and pinned offline bundle; host lifecycle tests, no target installation. [Packaging](../architecture/PACKAGING.en.md).

Installed 5.0.27 with native clock1.0.0: real mailbox contention and browser confirmation verified. Control enabled, time confirmed, automatic bells disabled; clocks/NTP unchanged.

5.0.27: clock-result lock contention is pending, not failure; bounded GET waiting, no POST replay. Storage errors are distinct from busy.

5.0.26: native clock dependency and authenticated time confirmation/bypass UI, worker-owned activation, host tests. Not installed. See [time controls](../architecture/CLOCK_UI.en.md).


5.0.25: executor clock admission with explicit optional bypass and injected-clock tests. Not deployed. Native dependency and confirmation UI remain deployment prerequisites: [integration scope](../architecture/CLOCK_EXECUTOR.en.md).

Router check: a fresh archive with one user melody was restored through the page; re-export matched byte-for-byte and automatic bells remained disabled. This does not test power loss or every quota boundary.


5.0.24: backup status and download retry transient busy GETs up to four attempts with 200/500/1000 ms delays. Download retains one overall 180 s deadline. Restore POST is never automatically retried; exhaustion leaves the status check available.


5.0.23: title and filename spaces use %20 for LuCI 19.07 CGI; literal plus signs remain plus signs.


5.0.22: MP3 upload and restore carry the CSRF token in Authorization: Bearer, forwarded by uhttpd 19.07 CGI. A LuCI session and an exact CSRF token match remain required; tokens never enter URLs. CGI previously dropped X-CSRF-Token, causing HTTP403 before file writes.

5.0.21: unconfirmed uploads retain the original error and operation ID; the list is fetched again without resending the file. Failed reads preserve disabled stale rows until refresh. This is a diagnostic fix; the browser upload failure cause remains under investigation.

5.0.20: transient media-list busy receives up to four GET attempts with 200/500/1000 ms pauses. Exhaustion preserves the previous list as unconfirmed, disables actions and leaves refresh available. Busy is not called corruption. Upload POST is never retried.

Schoolbell 5.0.19: fix empty LuCI audio responses on Lua 5.1. Streaming sources/sinks use coroutine-safe protection throughout; regressions cover yielding upload/download and cleanup after disconnect.

Schoolbell 5.0.18: confirmed uploads automatically refresh the media list. Every populated row has browser playback; empty slots are labeled in the table and selectors and cannot be played. A refresh failure does not reupload the saved file. The demo includes all six bundled melodies. Host checks without sound; not deployed to the router.

Schoolbell 5.0.17: backup downloads have a 180-second overall deadline, including the response body. Timeout/disconnection returns control; check status before retrying. Late responses are not saved and restoration is never started automatically. Pages displays the UTC build date and commit. Host-tested; not deployed to the router.

Schoolbell 5.0.16: the calendar starts in view mode; clicking a date previews draft bells without erasing its assignment. Explicitly select a schedule or eraser to paint. A shared panel distinguishes the draft from the active snapshot. Save edits first, then separately apply the checked revision; changes from another window require reloading. Preview is not execution evidence. Validated on the host and in the browser demo; not deployed to the router.

Schoolbell 5.0.14: persisted router playback attenuation in Settings; takes effect on the next bell while Mute cancels the current one. The system mixer is unchanged.

Automatic bells: independent fixed/annual bell service, explicit saved-plan activation, Mute and no catch-up playback. Reboot/timezone changes require checking the clock and reactivation. System time and NTP are unchanged.



[Русский](README.md)

School calendar, bells and melodies. Calendar calculation, the LuCI editor and an engineering automatic executor are implemented. Public core registration and the production player remain separate stages.

[ТЗ 1.38](../requirements/TECHNICAL_SPECIFICATION.md) · [CHANGELOG](CHANGELOG.en.md)

The specification remains a draft. Requirement/test IDs belong to this component;
qualify references with `core`, `demo` or `schoolbell`. A specification revision
is not an API version. The root changelog retains pre-split history; future
component changes belong here and in its specification. Research remains local.

## Sample preview package

`make build-schoolbell` creates `out/modbus-schoolbell_0.0.1_all.ipk`;
its independent version is set with `SCHOOLBELL_VERSION`. It is part of `make all`.
This is a media-only preview containing `/usr/share/modbus-schoolbell/melodies/test.mp3`
and NOTICE, with no service, cron, player, configuration, or automatic sound.
The functional port will declare its future core API dependency; no compatibility
with that API is claimed now.

[Original media](../../assets/melodies/README.en.md): six MP3s;
only the shortest test.mp3 (about 3.28 s, 13104 bytes) is bundled. CI verifies
the manifest and exact IPK payload using Python 3.8+ on the build host.
The preview package has not been installed. The owner confirmed manual MP3
playback with madplay; this does not validate the functional package.

For the first experiment, connect speakers at minimum volume, then inspect
player availability, the audio device and USB power. After separate agreement,
play the short file once and remove temporary files. Building the IPK does not
install a player, alter mixer/drivers, or produce sound.

Specification 1.3 owns audio execution, FIFO/expiry/cancellation transferred from core, with offline dependencies and persistent storage. Manual playback is confirmed; the functional package is not implemented.

Specification 1.4 defines functional parity with the original: two schedule modes, preliminary bells, browser clock synchronization, local UI and five melodies plus test. Added planned TC-14–33, media management and backup. Preview 0.0.1 and runtime are unchanged.

The separate schoolbell CI job runs for package or dependency changes; locally use `make ci-schoolbell`. See [CI](https://github.com/ViacheslavMezentsev/openwrt-modbus-core/blob/243a7ccad6aeb2499d3efd5d0c4cef9e822d393e/docs/CI.en.md). Hardware acceptance remains separate.

Schoolbell specification 1.5 clarifies schema/migration ownership, calendar/media validation and fleet templates versus backups under core 1.16. TC-34/35 are planned; runtime and preview are unchanged.

Specification 1.6: isolated Lua calendar with fixed/annual modes, quiet dates, midnight preliminary bells and gap/fold rejection. 29 groups, 14,404 independent date vectors and original 15+6 across a full leap year. No core/audio/router integration; media-only IPK unchanged, full parity remains pending.

[Calendar API](../architecture/CALENDAR.en.md) · `make test-schoolbell`

Schoolbell specification 1.7: isolated Lua playback queue, per-resource FIFO, monotonic TTL/UTC, owner cancellation and an injectable player. 24 host test groups; unknown outcomes retain the resource. No core/process/audio/router integration; media-only IPK unchanged.

[Playback queue](../architecture/PLAYBACK_QUEUE.en.md) · `make test-schoolbell`

Schoolbell specification 1.8 accepts the system player contract: launching/exit, retained media revisions and blocking after failures. TC-43–49 are planned; implementation, sound, IPK and router are unchanged. [Player adapter](../architecture/PLAYER_ADAPTER.en.md).

Schoolbell specification 1.9 accepts native player mechanisms and begin/poll/release, inherited flock FD, stdin media, a 2000 ms timeout and /dev/null. TC-50–55 are planned; madplay properties require verification. Code and router unchanged. [System API](../architecture/PLAYER_SYSTEM_API.en.md).

Schoolbell specification 1.10 defines result/error fields, executable-identity exec evidence, a 16-byte frame and 64/64/8/8 budgets. TC-56–60 are planned; requirements only, code and router unchanged. [Results API](../architecture/PLAYER_RESULTS.en.md).

Schoolbell specification 1.11 fixes SBPE/v1 big-endian, generations, attempt counters and parameter ranges. TC-61–65 are planned; requirements only, no code/audio/router changes. [Wire contract](../architecture/PLAYER_WIRE.en.md).

Schoolbell specification 1.12: isolated Lua SBPE codec and player API model with injected operations. 32 host test groups cover frames, generations, deadlines/outcomes, quotas and cleanup. No native binding, processes, sound, core or router changes; IPK unchanged. [Player model](../architecture/PLAYER_MODEL.en.md).

Schoolbell specification 1.13: isolated Linux C player adapter and a test child without an audio device; 13 host process/fault groups, FD checks and inherited flock after owner death. No Lua binding, core, madplay/audio or router changes; IPK unchanged. [Linux player](../architecture/LINUX_PLAYER.en.md).

## Accepted interface mockup

[Local UI mockup](https://github.com/ViacheslavMezentsev/openwrt-modbus-core/blob/243a7ccad6aeb2499d3efd5d0c4cef9e822d393e/packages/schoolbell/ui-mockup/README.en.md): calendar, schedules, media library, states and three theme modes. Synthetic data only; functional UI and integration remain future work. Not included in the IPK.

Schoolbell spec 1.14: isolated Lua 5.1 Linux player binding, userdata and eight host groups with a fixture process, GC/OOM and recoverable handles. No queue/core, audio device, sound or router/IPK changes. [Lua binding](../architecture/LUA_PLAYER.en.md).

Schoolbell spec 1.15: isolated bridge connects the Lua queue and Linux player; launching/finishing, signal outcomes and cleanup before the next start. Ten fixture-child host groups; no core, audio device, sound or router/IPK changes. [Queue/Linux bridge](../architecture/QUEUE_LINUX.en.md).

Isolated [admission-time revision retention](../architecture/MEDIA_ADMISSION.en.md): TC-72, nine host groups. Specification 1.16.

[Persistent media library: accepted requirements](../architecture/MEDIA_PERSISTENCE.en.md). TC-73–82: planned, not implemented.

[Format, quotas and commit](../formats/MEDIA_FORMAT.en.md): accepted 1.18 contract, not implemented.

[Isolated media manager](../architecture/MEDIA_MANAGER.en.md): prepared objects, no production integration.

- [Schoolbell manual sound check page](https://github.com/ViacheslavMezentsev/openwrt-modbus-core/blob/243a7ccad6aeb2499d3efd5d0c4cef9e822d393e/packages/schoolbell/router-page/README.en.md).

- [Saved schedule editor](../architecture/SCHEDULE_EDITOR.en.md).

- [Annual calendar](../architecture/ANNUAL_CALENDAR.en.md).

The Feedback tab links to [Issues](https://github.com/ViacheslavMezentsev/openwrt-modbus-core/issues) and bug/feature forms, available after the templates reach main. Internet and a GitHub account are required; logs are submitted manually after removing secrets.

[Melody uploads](../architecture/MEDIA_UPLOAD.en.md).

[Backup and transfer](../formats/BACKUP.en.md): restore leaves automatic ringing disabled.

[Clock trust and rollback](../architecture/CLOCK_TRUST.en.md): accepted requirements, implementation pending.

Specification 1.32 defines the reference format and observation budgets; isolated implementation is pending.

[Isolated clock trust model](../architecture/CLOCK_TRUST_MODEL.en.md): codec, fake clock/storage and host tests; no executor integration.

[System clock/reference adapter](../architecture/CLOCK_SYSTEM.en.md): isolated host ports, no router deployment.

Storage bar: normal through 75%, yellow above 75%, red above 90%. Usage refers to the displayed filesystem, not just the media quota. Reserve and upload admission limits are unchanged.

Since 5.1.24 there is no separate row-count cap. The 12288-byte draft and event calculation budgets remain; capacity depends on data. Older versions may reject larger plans: use compatible device and Pages versions.

System clock setting in 5.1.25: Lua clock_set formats a numeric UTC date for stock date and verifies exit/readback. The compatible mechanism is documented by [LuCI 19.07 setLocaltime](https://github.com/openwrt/luci/blob/openwrt-19.07/modules/luci-base/root/usr/libexec/rpcd/luci); this RPC is not invoked and sysfixtime is not restarted. No absolute accuracy or power-loss retention guarantee is made.
