# Shkolnik end-to-end acceptance on a new device

[Русский](ACCEPTANCE_RUN.md) · [AC-01–12 program](ACCEPTANCE.en.md) · [Packaging](../architecture/PACKAGING.en.md) · [User guide](../user/USER_GUIDE.en.md)

2026-10-31. Execution plan and record template, **not acceptance sign-off**.
Application candidate: 5.1.22. The new device firmware and complete artifact set
are not frozen yet. This does not modify the specification or AC criteria.
Only documentation is authorized now: no flashing, sound, automatic bells,
clock/NTP/network changes or power interruption.

## 1. Scope and decision gates

Proposed first profile: new TL-MR3020 EU v3.30, compatible offline bundle and
attended startup. Staff verify time and enable the applied plan after power-up;
subsequent operation needs no browser. Q5 still requires an explicit decision,
not a silent specification waiver. Unattended recovery requires a separate
trusted-time-source/resume contract, possibly a future external RTC.

Calendar coverage includes September–May and year boundaries. A week does not
prove time accuracy for an academic season, summer temperatures or years of
reliability. Online monitoring is not offline acceptance; network loss and power
recovery are separate tests. Pages and process exit codes do not prove audible sound.

Before PASS, agree Q1–Q5: acoustic start/stop limits, duration/load, RAM/storage
headroom and clock accuracy, overlapping-event policy, release profile and explicit
deferrals. Previously proposed +1 s/1 s remain proposals. Without an agreed limit
and measurement method, the corresponding property cannot pass.

## 2. Dedicated network bench

Preserve the laptop's primary addresses, DHCP, DNS and routes. Dedicate USB–Ethernet
to the new router. Locally record adapter name/index/MAC, original configuration
and recovery steps; confirm physical identity by disconnecting only the bench cable.
Do not choose the first interface, enable ICS, bridge networks or introduce DHCP.

Assign any required address only to the dedicated adapter after selecting the
procedure and checking overlapping subnets. Avoid unnecessary gateway/DNS settings.
Resolve route conflicts by agreeing the bench topology, not modifying the primary
interface. Do not disable VPN/firewall globally. Bind recovery TFTP and narrow
firewall rules to the bench, removing them afterwards. A USB adapter alone does
not prevent conflicting routes.

Prepare stable power, Ethernet cable, exact-revision image and official checksums,
stock configuration backup, compatible recovery image/tools and post-flash access
before authorization. Factory/sysupgrade/recovery images are not interchangeable.
Verify filenames, addresses, buttons and procedures against official sources at
the flashing stage; do not borrow another revision's instructions. Keep credentials,
MAC/serials, label photographs and backups private. The old working device is not
the flashing or network-configuration target.

## 3. Frozen artifact passport

Keep the populated record and evidence in a separate local pair
`docs/research/NN-schoolbell-acceptance/` and `tests/manual/NN-schoolbell-acceptance/`.
Commit only templates and anonymized summaries.

| Field | Required record before testing |
| --- | --- |
| Run/profile | Unique ID, operator, date/timezone, Q1–Q5 decisions, deferrals and permissions |
| Hardware | Model, EU/revision, private identity, clearly distinct from the old bench |
| Baseline | Stock firmware/access and hashed configuration backup; not a complete flash dump |
| OpenWrt | Release/build, target/subtarget, architecture, kernel/full ABI, libc/Lua/LuCI; image filename/type/source/bytes/SHA-256/authenticity result |
| Sources | Full clean commit and matching CI run/headSha; disclose dirty trees and patches |
| Packages | Core and Shkolnik Name/Version/Architecture; each native clock, player, driver and transitive dependency IPK |
| Bundle | Manifest, SHA256SUMS, offline archive, instructions and rollback; file names/bytes/hashes, dependency closure and kernel ABI compatibility |
| Pages | URL, source commit/build date, .sbp format and bundled-media set |
| Test data | .sbp/.sbb/MP3, independent expected events, timezone, volume/audio settings and limits; every file hashed |
| Peripherals | Audio card/hub/power/speakers/storage, browsers/OS and wiring |
| Measurement | Acoustic evidence method, time reference/uncertainty, polling interval, collector version/storage |

Each file entry has `role, filename, size_bytes, sha256, source, version,
architecture, verification`. Compute hashes; verify downloads and installation
copies. `Architecture: all` does not remove dependency ABI constraints. A checksum
manifest alone is not a signed release. Approve the set before installation.

Any firmware/IPK/driver/reference-data/significant configuration change creates a
new passport revision with explicit retest scope. Preserve old results. Changes
to execution/time/storage invalidate a comparative endurance run: restart the full
duration after fixes; never combine different versions or boot epochs.

## 4. Stages

Every stage records prerequisites, permission for its effects, steps, evidence and
final state. A skipped stage never passes.

| Stage / AC | Work and completion evidence |
| --- | --- |
| S0 / I | Passport, Q1–Q5, USB–Ethernet topology, chosen images and recovery; unresolved fields explicit. Preparation only. |
| S1 / AC-01 | Separately authorized stock backup, flash, first login/password and version/ABI check. Record actual steps and adapter restoration. Do not blindly clone the old device configuration. |
| S2 / AC-01/09 | Clean installation from a closed offline bundle without on-device dependency downloads; space, opkg, payload SHA, services and auto-off checks; rollback snapshot. |
| S3 / AC-02/06/10 | Login/logout/expiry, retained edits, separately authorized time/TZ/trust setup and clear warnings; auto-off. Confirming time does not set the clock. |
| S4 / AC-02/03/04/07/08/10 | Real LuCI: September–May, year/leap boundaries, painting/quiet dates, draft/applied separation. Pages .sbp import, user-MP3 export into an empty destination with preview/conflicts, .sbb backup/restore; compare links/content/SHA. Eight user slots within total quota, protected bundled media and rejection cases. |
| S5 / AC-03–05 | Authorized low-volume sound/automation: independent day oracle with 15 main + 6 pre-bells, manual/test/mute, retained-plan activation, no catch-up/duplicates, collisions/failures. Measure acoustic timing with uncertainty. Auto-off after short tests. |
| S6 / AC-06/09/10/11 | Separately authorized network/browser/offline/reboot/cold-start/audio failures, update/rollback with backup, physical write interruption. Require a coherent old/new copy or explicit block, never automatic activation. Mocks do not replace physical tests. |
| S7 / AC-11/12 | After blocker fixes: separately authorized automatic run of at least 7×24 hours with approved acoustic windows/oracle. Collect complete coverage; disable bells and verify data afterwards. |
| S8 / AC-01–12 | Close mandatory scenarios and Shkolnik-4 parity, audit guide/defects/limits, owner sign-off for exact artifacts/profile. Publishing remains separate. |

Missing browser clock setting, system events, external RTC or other gaps cannot
pass because a similar feature exists. Implement/test them or obtain explicit
profile limitations; then do not claim full parity. Reconcile gaps with current
code before S0.

## 5. Endurance run

Before starting record UTC/local start/end, timezone, polling (proposed 60 s),
expected snapshot count/seq, missed-contact handling and stale threshold (proposed
three periods). Agree PC storage and device resource limits/retention. The bounded
rotating device journal must be copied frequently enough to avoid evidence loss;
do not enlarge it unnecessarily or write frequent measurements to flash. Monitoring
load must not dominate the device.

Collect boot ID, uptime/version, applied revision/status, time trust, command queue
and outcomes, PID/starttime/FD/RSS/CPU, flash/tmp and journal. Prepare the event
oracle independently before starting, including suppressed events. Correlate each
expected event with submission, process start/exit and acoustic evidence wherever
sound is claimed. Exit 0 alone is insufficient. Observation gaps remain unverified.

Suggested schedule: first day a reference working day; remaining days ordinary
load, a quiet date and pre-approved mode changes. Mark online/offline windows.
Do not advance real clocks to accelerate calendar boundaries: use independent
host tests and explicitly described bench dates. Drift measurement is a separate
experiment; applying a correction changes the run conditions.

Start monitoring only after passport/time/access approval. Stay quiet when healthy;
report meaningful failure, required action or completion. Do not repeat completed
collection or restart services automatically. Preserve evidence on blockers and
follow the pre-agreed safe-stop procedure. Disable monitoring at completion and
remove only its own temporary tools.

## 6. Record template and release decision

For each scenario record:

- Run/passport revision, stage/AC/subcase, UTC/local time and operator;
- prerequisites/permission, versions/hashes, backup/rollback and exact actions;
- independent expectation, actual result, measurement method/uncertainty;
- local evidence, defects/retests;
- PASSED / FAILED / NOT TESTED and final state.

The decision matrix includes all AC-01–12; partial success never closes a whole
AC. Mandatory untested properties and blockers prevent acceptance PASS. Final
sign-off identifies artifacts, profile, permitted use, limitations, open questions,
date and owner decision. Leave bells off, data intact, no test players running,
and restore the dedicated adapter configuration.

## 7. Existing evidence

The owner accepted 5.1.22 UI on the old bench; Pages is published. User-MP3 .sbp
passed isolated Lua and browser download/upload/preview/commit/readback with SHA
matches. The browser test used installed JS/controller/CGI parser over a local SSH
bridge, not production LuCI login/routing. This informs S4 but does not pass the
new device. Large archives, slow clients, peak resources and power loss remain open.

2026-10-31: the owner accepted 5.1.23 on the existing bench: both themes, status border, schedule columns and row playback in the browser/device speakers. Backup and exact rollback were verified before installation; payload hashes and unchanged .sbb afterwards. Quiet playback at -18 dB passed and original volume was restored. Automatic bells remain disabled; clock/NTP unchanged. This does not replace S0–S8 on the new device. Next is S0: dedicated USB–Ethernet, exact firmware/recovery files, profile/Q1–Q5 and artifact passport. Pages publication of 5.1.23 has not been independently verified.

### 2026-11-08 — published Pages 5.1.120

Checked the [published interface](https://viacheslavmezentsev.github.io/schoolbell/) in a separate in-app browser: version **5.1.120**, commit `ce2e3fa28c20dae0b36b50a8598a96e1d134e058`, build time `2026-11-08T07:20:14Z`. This browser started with no applied plan and an empty journal. The owner requested the check; the working router was not accessed.

| Check | Observed result |
| --- | --- |
| Metrics summary (TC-236) | Right-aligned while collapsed, hidden when expanded. Unknown flash, saved volume and Internet match Resources. Available → unconfirmed → available updates correctly; NTP independently showed waiting. |
| Simulator calendar plan (part of TC-235) | Applied the sample plan and enabled automation. Next-event navigation executed a pre-bell at 2026-11-09 08:28 and a main bell at 08:30. Journal attempts/completions matched; daily count was 2. |
| Set time from browser (§4.7.9) | Two submissions completed successfully, displayed clocks matched to the second and automation switched off. Refreshing with ×1 clock speed also showed matching readings. |
| Rollback and audio (part of TC-235) | Returning the clock did not duplicate completed events. With the virtual card disconnected, the 09:15 event failed without disabling automation. After reconnection, 09:25 succeeded: daily count 3, excluding the failure. |
| Page reload (part of TC-235) | Automation off, clock paused, history/counts retained and a boot event added. No JavaScript warnings or errors appeared in the observed browser log. |

**Limits:** this checks the published UI and local model, not hardware. Fixed-schedule mode, every speed, a real phone and cancellation of the time dialog were not exercised on this publication. The short-lived dialog was not exposed to the observation tool; the successful setting was verified, while cancellation is covered by host tests, not this run. The tool could not fill the `datetime-local` input, so direct date editing is also not marked verified. These tooling limitations are not application defects without separate reproduction.

Final simulator state: automation off, time paused, audio ready, Internet available and NTP synchronized, history retained. No real audio, computer clock, network or bench changes. This result does not close full hardware acceptance or the remaining TC-235/TC-236 scenarios.

### 2026-11-08 — USB audio hot reconnection 5.1.120

With owner authorization, tested the working TL-MR3020 v3 bench, OpenWrt 19.07.9, Shkolnik **5.1.120**, AB13X USB Audio over OHCI on `/dev/dsp`. Initially automation was off, sound allowed and saved volume 50%. Verified the .sbb backup and data snapshot, preserving the original draft and applied school-year plan. No package, network, clock or volume changes during the run.

A temporary calendar plan contained three main bells using the test melody. Times below are device-local, Asia/Yekaterinburg (UTC+05:00).

| Time | Condition and result | Journal | Daily count |
| --- | --- | --- | --- |
| 13:40 | Card connected; successful completion at 13:40:03. Owner confirmed audible playback. | Attempt #437, `auto_ok` #438 | 0 → 1 |
| 13:43 | Owner disconnected the card; no sound devices were present before the deadline. Attempt recorded, `auto_audio_unavailable` at 13:43:01. Automation remained enabled. | Attempt #439, error #440 | Remained 1 |
| 13:46 | Reconnecting the same card restored `/dev/dsp` without restarting the service. Successful completion at 13:46:04; owner confirmed audible playback. | Attempt #441, `auto_ok` #442 | 1 → 2 |

**Result: PASSED for removal and reconnection of the same card over OHCI.** Three attempts, two successes; the failure did not increase the count (part of TC-210). The missed bell was not replayed after audio recovery. Missing audio did not disable automation.

Restored the original draft and applied school-year plan, leaving automation off. Sound settings matched the baseline; .sbb contents matched by hashes. Journal and daily counts retained the test results. Local evidence is in the Git-ignored `tests/manual/115-usb-hotplug-5-1-120` protocol.

**Limits:** substitution with another card model, the former problematic hub/EHCI combination and removal during active playback were not tested. This run does not close those scenarios or full hardware acceptance.

### 2026-11-08 — hot substitution with another audio card 5.1.120

With owner authorization, performed a separate check on the working TL-MR3020 v3, OpenWrt 19.07.9, Shkolnik **5.1.120**. Original card: AB13X USB Audio over OHCI; replacement: C-Media USB PnP Sound Device over OHCI. Both used `/dev/dsp`. Verified the .sbb backup and data snapshot; initially automation was off, sound allowed and volume 50%.

A temporary calendar plan contained two main bells using the test melody. Times are device-local, Asia/Yekaterinburg (UTC+05:00).

| Time | Condition and result | Journal | Daily count |
| --- | --- | --- | --- |
| 13:56 | AB13X: attempt at 13:56:01, successful completion at 13:56:04; owner confirmed audible playback. | #447 / `auto_ok` #448 | 2 → 3 |
| 14:00 | C-Media detected after physical substitution; attempt at 14:00:01, successful completion at 14:00:04; owner confirmed sound through the speakers. | #449 / `auto_ok` #450 | 3 → 4 |

**Result: PASSED for AB13X-to-C-Media substitution over OHCI.** Automation remained enabled without a service restart. Both attempts succeeded; no errors in the run events. The initial count of 2 came from the preceding run and was not counted again.

Restored the original draft and applied school-year plan, leaving automation off. Sound settings, including 50% volume, remained unchanged; .sbb contents matched by hashes. Journal and daily counts retained. No package, clock or network changes. Local protocol and evidence: `tests/manual/116-usb-card-substitution-5-1-120` (Git-ignored).

**Conditions and limits:** the OHCI USB path changed from `1.3` to `1.4` along with the card, so this was not an isolated same-port substitution test. The former problematic hub/EHCI and removal during active playback were not tested. The result does not cover every card model or close full hardware acceptance.

### 2026-11-08 — offline bells with browser closed, 5.1.120

The owner disconnected the working bench network from 19:41 to 19:59 (Asia/Yekaterinburg) and confirmed all Schoolbell pages were closed. The 19:42 pre-bell and 19:43 main bell were audible; journal attempts #453/455 and successes #454/456 matched, daily count increased from 4 to 6. Automation continued. Minute-spaced RAM observations showed Internet unconfirmed from 19:41:33 and available at 20:00:35 after reconnection.

Offline bell execution and operation without a browser PASSED. NTP remained displayed as synchronized throughout; its timestamp renewed at 19:50:28 while offline. Investigation identified periodic callbacks being incorrectly treated as fresh synchronization. This is not evidence of a network exchange; TC-234 remains incomplete. The prepared fix is tested on the host; the 5.1.121 hardware retest is recorded below.

Original school-year plan and draft restored, automation off, volume 50% and .sbb contents preserved. Protected configuration hashes, boot and NTP PID unchanged. Journal/counts retained; temporary observer removed after collecting evidence. Local evidence: `tests/manual/117-offline-bells-5-1-120` (Git-ignored).

### 2026-11-09 — 5.1.121 upgrade and offline NTP retest

Before the authorized upgrade, verified installed 5.1.120 against its rollback package, the .sbb backup and data snapshot. After installation all 86 files matched 5.1.121; .sbb contents and sound settings were preserved. Protected network/time configuration, boot and NTP PID remained unchanged. Automatic bells off, volume 50%; no NTP restart or synthetic confirmation events.

The owner disconnected the network from 10:08 to 10:26 (Asia/Yekaterinburg). Recorded 21 minute-spaced samples: automation always off, NTP always waiting (no fresh confirmation), the original event record unchanged and its age increasing. Internet was unconfirmed from 10:10:18; after reconnection the 10:27:26 cache confirmed reachability. Exact outage-detection latency was not separately measured.

**Passed:** no false NTP confirmation or renewed event timestamp in the observed offline interval, Internet recovery and preservation of the school-year plan, journal, counts and volume. Automation remained off; the temporary observer was removed after collecting evidence. Local evidence: `tests/manual/118-bench-5-1-121` and `tests/manual/119-ntp-offline-retest-5-1-121` (Git-ignored).

**Not tested:** fresh stratum confirmation followed by expiry and a new confirmation after reconnection. The initial record used the legacy format without an event type, and no fresh stratum was observed. Individual periodic callbacks were not instrumented. TC-234 remains partially open; stable stratum can produce no new confirmations even with working exchanges.

Local runtime/player, NTP boundary/regression, UI, Pages, IPK build/payload and documentation checks passed. The first full run stopped on the old expected UI text; after updating it, the full UI and remaining Pages/docs checks passed. Specification validation: no errors, three existing historical revision-marker warnings. Published Pages 5.1.121 was not separately verified.

## 2026-11-09 — OEM EU v3.30 recovery

Prepared recovery transfer, stock boot, Ethernet/Wi-Fi and login after a separate reset confirmed. Version 1.8.0 0.9.1 v0001.0 Build 250625 Rel.56805n. [Evidence and limits](../SETUP_RECOVERY.en.md). The new wizard was not hardware-tested.

### 2026-11-09 — device model and Resources layout, 5.1.122–5.1.123

The system reports TP-Link TL-MR3020 v3 through the existing controls request, without inferred subrevisions. The owner accepted the model and row order: model, Internet/NTP, switch/IP, CPU, Flash, audio. Shared Pages sources identify the simulator.

Verified backups and rollback packages before deployment; afterwards checked 86 package files, .sbb contents, sound settings, protected network/time settings and unchanged boot identity. Automatic bells remained off and volume stayed at 50%; no playback. Local UI/Pages and package checks passed; published Pages for this version was not separately checked. Full `make all` passed before committing. Local evidence: `tests/manual/121-bench-5-1-122` and `tests/manual/125-bench-5-1-123` (Git-ignored).
