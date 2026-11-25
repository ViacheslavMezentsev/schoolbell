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
   password, check the device, then separately confirm installation.
5. Open the router interface and check its version. Fresh installation leaves automatic bells off.

OEM recovery installs Build250625, not any arbitrary previous OEM version.
The old TP-Link password may survive; factory reset is a separate operation.
Full wizard backups require OpenWrt and are optional for flashing. On OEM, use
TP-Link Backup & Restore for configuration backups.

## Known limitations

Preview, without Authenticode. Reflashing OpenWrt may change the saved SSH host key;
the GUI does not rotate it yet. Do not disable verification: an expert must compare
the new key and replace only the matching old record. A pre-write preparation
failure may require a new session. The full cycle passed with that manual repair,
not as an unconditional clean-PC acceptance. A clean Windows host and this exact ZIP
still require separate testing. Distribution materials remain incomplete; see
licenses/OPEN-ITEMS.md. SHA256SUMS checks integrity, not publisher identity without
a trusted signature.

[Guide](https://github.com/ViacheslavMezentsev/schoolbell/blob/main/docs/INSTALLATION.en.md)
