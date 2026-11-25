# Setup wizard — preview

[Русский](README.md)

Windows 11 x64; TP-Link TL-MR3020 **EU Ver. 3.30** with original bootloader only.
You need router power, a dedicated USB–Ethernet adapter, RJ45 cable, PowerShell 7
and Windows OpenSSH Client. Package installation requires the OpenWrt root password;
set it in LuCI first. Python is bundled; Qt/MSYS2/Python installation is unnecessary.

1. Extract the entire ZIP into a separate directory; do not run inside the archive viewer.
2. Run `schoolbell-setup-wizard.exe`, select the operation and dedicated adapter.
3. OpenWrt and OEM images are embedded. Approve UAC. Use Reset/power only after
   READY, following the wizard instructions. Keep power on after transfer and wait
   for boot and network restoration.
4. Download the separate `schoolbell-v…-openwrt-19.07.9-ramips-mt76x8-mipsel_24kc.zip`.
   Put it beside the EXE or select it in the form; do not extract it. Enter the
   password and confirm installation. Inspection and full backup are optional;
   reinstall and retry do not require a new session.
5. Open the router interface and check its version. Fresh installation leaves automatic bells off.

OEM recovery installs Build250625, not any arbitrary previous OEM version.
The old TP-Link password may survive; factory reset is a separate operation.
Full wizard backups require OpenWrt and are optional for flashing. On OEM, use
TP-Link Backup & Restore for configuration backups.

## Known limitations

Preview, without Authenticode. After flashing OpenWrt, the wizard displays a new
SSH fingerprint for explicit acceptance in the form. Correct an invalid password
in the same field and retry. Full backup is optional for package installation too.
Old attempts and backups are preserved; the Schoolbell URL appears in the form
and log after an attempt. A clean Windows host and this exact ZIP
still require separate testing. Distribution materials remain incomplete; see
licenses/OPEN-ITEMS.md. SHA256SUMS checks integrity, not publisher identity without
a trusted signature.

[Guide](https://github.com/ViacheslavMezentsev/schoolbell/blob/main/docs/INSTALLATION.en.md)
