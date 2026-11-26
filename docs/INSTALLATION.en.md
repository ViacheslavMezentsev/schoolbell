# Installation and recovery

[Русский](INSTALLATION.md) · [Start with a release](GETTING_STARTED.en.md) · [Equipment](HARDWARE.en.md)

## Choose your method

| Task | GUI wizard | Expert CLI |
| --- | --- | --- |
| Install OpenWrt | Embedded image; guided adapter preparation, READY, transfer and network recovery | [Setup.cmd](../tools/setup/README.md) |
| Restore stock firmware | Embedded OEM Build250625; same guided sequence | [Setup.cmd -RestoreFactory](../tools/setup/RECOVERY.md) |
| Install Shkolnik | Select an external ZIP; fresh installation, same-version reinstall and retry | `install.py` and instructions inside the bundle |

Start with the [release guide](GETTING_STARTED.en.md) for download, extraction, passwords, Reset timing and expected results. The [wizard reference](../tools/setup/gui/README.md) covers details. CLI users should follow the exact archive's instructions; a source checkout is not a ready-to-run kit.

## Scope and evidence

The supported flashing profile is **TL-MR3020 EU v3.30** on Windows 11 x64. Other revisions require their own acceptance. The downloaded **wizard 0.3.1 / Shkolnik 5.1.127** pair passed same-version installation and OpenWrt → OEM → OpenWrt → fresh Shkolnik installation, with automatic DHCP recovery. See the [report](acceptance/wizard-0.3.1-github.md).

Exact-build OEM → OEM, clean Windows without development tools, manual ZIP CLI, data-preserving downgrade and overlay restore remain separate checks. GUI success does not close them. Rebuilt archives require their own verification. Future releases list their exact tested pair and hashes.

Full backups are optional and are not automatically restored. OEM passwords may survive firmware recovery; a settings reset is a separate action. Firmware transfer completion does not prove boot: open the device interface and check its version.

## Maintenance

Update this overview, the release guide, wizard reference and release notes when a procedure changes. Product history belongs in CHANGELOG, current work in [TODO](../TODO.md), evidence in acceptance reports. Do not present historical checks as new acceptance.
