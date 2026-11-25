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

### Firmware wizard steps

1. Select the dedicated USB–Ethernet adapter, confirm TL-MR3020 EU v3.30 and choose “Проверить подключение” (check connection).
2. Once checked, choose “Начать восстановление” (restore factory) or “Установить OpenWrt”. Confirm the operation and UAC. Network/server preparation is automatic.
3. Follow the illustrated Reset instructions only when the server-ready step appears.
4. The fixed result panel shows transfer, boot wait and network restoration without additional clicks.
5. Open the router interface, sign in and check the stated version. No confirmation button is required; opening the link does not count as automatic boot verification.

Help and diagnostics are collapsed. Standalone network preparation is diagnostic, not required for flashing. Pending temporary settings expose network restoration as the primary action.

Transfer results are scoped by UUID. A new instance does not present another completed transfer as its current result. A shared protected checkpoint retains crash recovery and adapter coordination; do not delete it to bypass an unfinished operation. The helper still conservatively serializes network operations across the computer because TFTP uses fixed addresses and ports.

Request wait (03:00) and flash/boot wait (01:30) show a countdown. Zero does not mean success: the helper controls the outcome. DHCP has no promised exact duration.

“Открыть лог действий” opens the current file in the default Windows text editor. Adapter selection, checks and operation stages append to that same file; repeated clicks do not create copies. A new session gets a new file, preserving previous logs in application data. Reload the file if your editor does not monitor external changes.

## Повторная установка GUI / GUI reinstall

Select the ZIP, connection and root password, then Install Schoolbell. Inspection and full backup are optional. Reinstall and retry do not require a new session; each attempt is retained separately. Confirm a changed SSH fingerprint in the form. Actual package compatibility is enforced by opkg; its failure does not disable retry.

After an installation attempt, http://192.168.1.1/cgi-bin/luci/admin/schoolbell appears as a clickable link and in the log. A failed attempt does not confirm availability.

### Acceptance on 2026-11-26

The owner confirmed successful reinstallation of bundle 5.1.127 over the same
version and opening Schoolbell using both the button and the text link.
This does not constitute write-interruption or invalid-password acceptance;
those remain separate checks. The working device was not changed in this stage.

The OpenWrt root password is used for both LuCI and SSH. Set it through LuCI on
fresh OpenWrt before installing the bundle. This is explained in package Help /
What you need and in firmware Help. The input is labelled root password, with a reminder directly below the field to set root through LuCI first.

An incorrect password causes SSH authentication to fail. The wizard reports the
connection error (usually code 255 / Permission denied), does not claim success,
and allows editing the password and retrying without a new session. With an
incorrect password from the outset, remote installation commands do not execute.
This behavior was reviewed in code, not separately accepted on hardware here.
