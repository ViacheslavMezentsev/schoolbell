# Start with a release

[Русский](GETTING_STARTED.md) · [Equipment](HARDWARE.en.md) · [Shkolnik user guide](user/USER_GUIDE.en.md)

## 1. Download the files

Open [project Releases](https://github.com/ViacheslavMezentsev/schoolbell/releases), read the selected release's limitations and expand **Assets**. If no release is published yet, installers are not available there; source archives do not replace them.

| File | Action |
| --- | --- |
| `schoolbell-setup-wizard-v<version>-windows-x86_64.zip` | Extract the entire archive to its own folder. |
| `schoolbell-v<version>-openwrt-19.07.9-ramips-mt76x8-mipsel_24kc.zip` | Keep as ZIP beside the EXE or select it with the folder button. |
| `SHA256SUMS`, signature and public key/verification instructions | Verify the downloaded files using the instructions supplied with the release. |
| `.ipk`, build metadata and sources | Additional expert materials; the GUI uses the two ZIPs and verification materials. |

**Source code (zip/tar.gz)** contains project sources, not a ready-to-run installer. Wizard and Shkolnik versions are independent: use the pair listed in the release. Both supported firmware images are embedded in the wizard.

Checksums identify file contents; signatures authenticate the checksum list. A signed Git commit does not sign a downloaded ZIP. The release must supply the signature format, trusted key fingerprint and commands; do not assume verification if these are missing. To compare SHA-256, run PowerShell `Get-FileHash -Algorithm SHA256 'path-to-archive.zip'` and compare with the matching `SHA256SUMS` entry.

## 2. Prepare the PC and router

Prepare the [equipment](HARDWARE.en.md), **Windows 11 x64, PowerShell 7, Windows OpenSSH Client** and administrator access. Install these system prerequisites first. The extracted wizard does not require host Qt, Python or development tools; a completely clean Windows acceptance run remains pending.

Connect the router's Ethernet port to the dedicated USB–Ethernet adapter and power it on. Do not substitute the PC's primary network adapter. Save important data before flashing. Full backup is available for suitable OpenWrt installations but is optional; use the OEM interface to back up OEM settings if required.

Run `schoolbell-setup-wizard.exe` from the extracted folder, keeping all accompanying files. Choose a task.

## 3. Choose a task

### Install OpenWrt

1. Check the case label for **TL-MR3020 EU v3.30**, select the dedicated adapter and check the connection.
2. Start installation, confirm it and approve Windows administrator access.
3. Wait for **Server ready / READY**. Only then disconnect router power, hold WPS/RESET and reconnect power. Release the button once transfer starts.
4. Wait for transfer, flash/boot countdown and PC network recovery. Keep router power on. File transfer alone does not prove successful boot.
5. Open the router interface using the wizard, confirm OpenWrt/LuCI and set a root password. Continue to package installation.

### Install or reinstall Shkolnik

1. Select a ZIP from the list or folder button and check its displayed path/version.
2. Select the connection and enter the **root** password set in LuCI. Device checks and backups are separate optional actions.
3. Install Shkolnik and confirm. Same-version reinstall and retry after failure are available; read the error before retrying. If flashing changed the SSH key, verify the intended device and accept its new key in the form.
4. Wait for **INSTALL VERIFIED** and open Shkolnik using the link or button. Check version, automatic bells off and volume. Correct an invalid password in the form and retry.

The interface is `http://<router-address>/cgi-bin/luci/admin/schoolbell`. Use the address shown by the wizard, usually `192.168.1.1` after a fresh installation. Configure the plan and clock using the [user guide](user/USER_GUIDE.en.md). Installation does not enable automatic bells.

### Restore stock firmware

Choose stock recovery and follow the same preparation, READY, Reset and waiting sequence. Open the TP-Link interface and check **1.8.0 0.9.1 v0001.0 Build 250625 Rel.56805n**.

The old TP-Link administrator password may survive. It is neither the OpenWrt root password nor the Wi-Fi key on the label. A forgotten password requires a [separate settings reset on the running router](../tools/setup/RECOVERY.md); holding Reset at power-on for firmware transfer is different.

## Troubleshooting

Read the operation status and open the action log. Keep power on during flash writing: stopping the wizard cannot cancel a write already started by the router. Do not run multiple wizards on the same adapter. Use offered network recovery if temporary network settings remain. Report the result without passwords or backups.

[Other installation methods](INSTALLATION.en.md) · [Wizard reference](../tools/setup/gui/README.md) · [Tested 0.3.1 / 5.1.127 pair](acceptance/wizard-0.3.1-github.md)

[How to verify the signature and all files](../packaging/release/VERIFY.md).
