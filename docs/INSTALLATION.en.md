# Installation and recovery: choose a method

[Русский](INSTALLATION.md) · [Releases](RELEASING.en.md) · [Wizard plan](SETUP_WIZARD_PLAN.en.md)

As of 2026-11-25: Schoolbell 5.1.127, wizard 0.3.0. Both methods are maintained:
a step-by-step GUI and a console kit for experienced users. A route on the home
screen does not mean firmware transfer is implemented.

| Task | GUI | Console |
| --- | --- | --- |
| OEM → OpenWrt 19.07.9 | Transfer, boot and DHCP checked on 2026-11-25 | Setup.cmd; final installation state accepted, uninterrupted cycle pending |
| OpenWrt → stock Build250625 | Recovery, DHCP and OEM login checked on 2026-11-25 | Setup.cmd -RestoreFactory; hardware tested |
| OEM → same stock Build250625 | Implemented; OEM-to-OEM not separately tested with this GUI | Setup.cmd -RestoreFactory; hardware tested |
| Schoolbell package ZIP | Fresh 5.1.127 and dependencies accepted on 2026-11-25; post-flash SSH key manually replaced | Included host install.py prepare/install/verify; manual hardware acceptance pending |
| Upgrade from a package ZIP | Not implemented in the current ZIP route | Follow the IPK upgrade procedure; do not substitute fresh installation |

The accepted firmware profile is **TL-MR3020 (EU) Ver. 3.30** only. Check the label;
OpenWrt's v3 model string does not establish an exact revision. Build250625 is the
supported stock release, not necessarily the firmware originally shipped on a device.

## Preparation

Use router power, a dedicated USB–Ethernet adapter/RJ45 cable, Windows 11 x86_64,
PowerShell 7 and administrator privileges for network changes. Keep a verified
backup on the PC; backups may contain secrets and must not enter release assets.
Packages require the root password; OEM login requires its administrator password.
Reset transfer needs no password. A Wi-Fi key is not an administrator password.
Choose the dedicated adapter by name/description, not a remembered interface index.

## GUI

Extract the entire wizard ZIP and run schoolbell-setup-wizard.exe. Companion workers
and runtime files are required; static Qt does not make the whole product one file.
Place the separate package ZIP beside the EXE. See the [GUI guide](../tools/setup/gui/README.md).

Both images are embedded. Select the operation, model and dedicated adapter,
check the connection and confirm start/UAC. Only after **READY**, remove router
power, hold Reset and reconnect power. Release Reset after transfer begins; keep
power connected until boot. Wait for network recovery and check the device UI/version.

On 2026-11-25 this flow passed for OEM recovery and OpenWrt installation, followed
by fresh Schoolbell ZIP installation. Post-flash SSH host-key rotation required
manual comparison and record replacement; the GUI does not do this yet. Do not
disable key checks. Clean Windows and the exact release ZIP still need acceptance.
Pre-flash backup is optional and remains a separate operation.

## Console

Use a fully extracted compatible kit. See [installation](../tools/setup/README.md)
and [stock recovery](../tools/setup/RECOVERY.md), including failure recovery.
In PowerShell 7 run `./Setup.cmd -DryRun` or `./Setup.cmd -RestoreFactory -DryRun`.
After checks, run `./Setup.cmd` or `./Setup.cmd -RestoreFactory` as administrator.
The current OpenWrt console route also offers packages; firmware-only extraction is
pending. Stock recovery requires the pinned firmware/oem-recovery.bin in the kit.

Only after READY, remove power from the intended router, hold Reset and reconnect
power. Release Reset after transfer starts; leave power connected until boot finishes.
TRANSFER COMPLETE proves transport, not flash/boot success. Check LuCI/version for
OpenWrt or the OEM interface/Build250625 for stock. OEM settings/password may survive;
resetting an already booted device is a separate destructive settings reset.

## Maintenance

Route changes update this table, detailed guides, TODO, both changelogs and release
notes. Keep evidence in the [acceptance record](acceptance/ACCEPTANCE_RUN.en.md).
Historical acceptance does not validate a newly built archive; release files need
checks and acceptance tied to their exact hashes.
