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
