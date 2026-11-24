# Setup wizard implementation plan

[Русский](SETUP_WIZARD_PLAN.md) · [Current functionality](../tools/setup/gui/README.md)

Date: 2026-11-24. Proposed implementation sequence, including the owner's request
for embedded offline OEM recovery. This is not a claim that all routes work today.
Each implementation stage updates the specification and its acceptance cases.

## Baseline and routes

GUI 0.2.1 has three entry routes. Only package installation performs real GUI
operations. Fresh external-ZIP installation passed with existing dependencies;
full dependency provisioning and backup restoration remain unaccepted. Firmware
operations exist in the console kit. ZIP upgrades are not implemented yet.
Firmware acceptance is limited to **TL-MR3020 EU v3.30**; a generic v3 system ID
cannot establish the region and physical revision.

| Route | User flow | Required outcome |
| --- | --- | --- |
| Install OpenWrt | Equipment, revision, adapter, image/backup, checks, Reset after READY, transfer, boot/access/root password | Verified OpenWrt; explicit separate transition to packages |
| Install Schoolbell | Equipment/password, archive selection, device, combined plan/backup, confirmation, install, verify | Verified packages/services, automation off, settings preserved |
| Recover router | Equipment, recovery type, profile/backup, data-loss confirmation, operation, verification | Verified OEM OS or separately restored compatible settings |

Require a dedicated USB–Ethernet adapter and cable. Show adapter name, description
and address. Keep the masked password in memory within the current route and
provide the common reveal control. Detailed guidance belongs in Help; show the
Reset photo/instruction at the relevant step, not before the server is ready.

## Embedded OEM recovery

Embed the verified **EU v3.30 Build250625** recovery image in the wizard, preferably
as a Qt EXE resource. Include model/region/revision, version, source, size and SHA256
in its profile. Verify private-session extraction before network changes or TFTP.
No Internet or adjacent firmware archive should be required for OEM recovery.
Schoolbell bundles remain external ZIPs. Offline delivery also needs all runtime
and helper components; static Qt alone does not make the EXE self-contained.

OEM recovery can retain the previous TP-Link password and settings. A complete
factory reset is a distinct, explicitly confirmed step after boot, followed by
checking initial setup. Build250625 is the supported OEM version, not necessarily
the version originally shipped with every unit. Other archived OEM versions need
separate profile validation and acceptance. Never replace device calibration,
identity or bootloader with another unit's generic dump.

## Delivery stages

| Stage | Work | Completion / proposed next branch |
| --- | --- | --- |
| 0 | Finish current external-ZIP fixes, result restoration, navigation and current documentation | Owner-authorized signed commits, host/Qt/build checks; owner pushes/merges current `codex/setup-external-routes` |
| 1 | Shared structured worker events, session/operation IDs, progress/errors, cancellation, concurrency and restart recovery | Failure/stale-event/retry tests; no success inferred from arbitrary log text; `codex/setup-operation-core` |
| 2 | Firmware profiles and embedded OEM; physical adapter selection without IPv4, narrow privileged helper, saved network state, routes/firewall/DHCP | DryRun and UAC/link/VPN/ports/late-DHCP/crash/corrupt-image checks; `codex/setup-firmware-core` |
| 3 | Firmware-only OpenWrt route separated from package installation; READY/transfer/boot verification and first LuCI/password access | Authorized OEM → OpenWrt acceptance with automatic network restoration; `codex/setup-openwrt-route` |
| 4 | Embedded OEM route, data-loss confirmation, boot/version/login checks and separate factory-reset guidance | Authorized offline OpenWrt → OEM and OEM → OEM acceptance, retained and forgotten password cases; `codex/setup-oem-recovery` |
| 5 | File picker and adjacent ZIPs, complete fresh installation, already-current verification, rollback-backed upgrades, multi-archive combined plan | Fresh dependencies, upgrades, conflicts, preserved data/volume; `codex/setup-bundle-upgrade` |
| 6 | Distinct `.sbb` and compatible-overlay restoration, identity/version checks, replacement preview and backup of current state | Actual restore acceptance with automation off; MTD is emergency evidence, not generic write-back; `codex/setup-backup-restore` |
| 7 | Compatible stable GitHub assets, explicit version choice, bounded downloads/cache/cancellation, signed metadata and hashes | Offline local/cache behavior and failure/tamper checks; `codex/setup-release-source` |
| 8 | Portable delivery, runtime/licenses/corresponding sources, signing, clean Windows, themes/DPI and novice instructions | Full OEM → OpenWrt → packages → upgrade → restore → OEM cycle without manual DHCP, console commands or tool downloads; `codex/setup-release-readiness` |

Create each new branch from current clean main after the previous merge. Finish and merge the current group before starting the next branch. The owner performs push, exact-HEAD CI checks, merge, tags and
publication. This plan does not authorize hardware operations.

## Shared architecture and failure behavior

Reuse Python transaction/profile/backup logic for CLI and GUI. QML presents steps.
Only network/firewall configuration uses an elevated helper with a narrow input
contract. Never put passwords in command arguments, code strings, logs or receipts.
Persist session and operation IDs; ignore stale events. Keep copyable diagnostics
separate from plain-language outcomes.

Cancellation before writing restores the network. During writing do not forcibly
stop the worker or claim cancellation is safe. After interruption verify the actual
outcome instead of automatically repeating writes. Initially accept dedicated DHCP
adapters; reject manual configuration until exact restoration is supported.
TFTP ACK proves transmission only; OS/version verification remains separate, with
explicit manual confirmation when automation cannot establish it.

On OEM, use vendor-interface configuration export instead of promising SSH backup.
An unbootable device may not permit backup; show this before confirmation and keep
existing evidence. Multiple ZIPs require one plan for profile/package/dependency
conflicts, versions, space and order. A firmware/ABI change belongs to the firmware
route, not a kernel replacement inside package installation. Hash integrity alone
is not trusted release authenticity; the owner controls release-signing keys.

## Validation and portability

Host tests cover hashes, bounds, archive safety, sessions, interruption, retries,
secret handling and event ordering. Network tests use fake transports/loopback and
non-mutating DryRun. GUI checks cover both/system themes, 100/150/200% scaling,
small windows, keyboard navigation and clear next actions. Hardware acceptance
uses only separately authorized devices and exact artifact versions/hashes with
verified backup/recovery. Host PASS is not hardware acceptance.

Complete Windows 11 first. Keep QML, profiles, archives, sessions and events
portable, with separate platform adapters for network discovery/configuration,
elevation and firewall. Linux follows, then macOS, each requiring its own build,
packaging and hardware acceptance; Qt or WSL availability does not prove support.

Stage 0 is complete; the stage 1 core passed local checks, with hardware acceptance
still pending. Stage 2 now has a [pure DryRun planner](../tools/setup/NETWORK_PREFLIGHT.md).
Windows snapshot collection and GUI preflight are connected. A privileged
helper with network restoration is connected and mock-tested. Actual UAC/address
assignment/DHCP remain unaccepted; next are image embedding, scoped firewall and TFTP. Embedded OEM is not connected yet. Then continue with OpenWrt/OEM
(3–4), bundles/restoration (5–6), and release sources/delivery (7–8).
