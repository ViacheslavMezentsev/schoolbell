# Equipment and tested connections

[Русский](HARDWARE.md) · [Get started](GETTING_STARTED.en.md) · [Project](../README.en.md)

## Router and installation

The tested flashing/recovery profile is **TP-Link TL-MR3020 (EU) Ver. 3.30**, powered through USB Type-C. A software model string of TL-MR3020 v3 does not prove the exact revision: check the case label. See [recovery support](../tools/setup/RECOVERY.md) and [vendor materials](../tools/setup/vendor/support.en.md).

The runtime is OpenWrt 19.07.9. Similar cases, other revisions and available OEM archives do not imply wizard support. Supported recovery installs OEM Build250625, not every firmware version shipped with this model.

GUI installation requires Windows 11 x64, PowerShell 7, Windows OpenSSH Client, administrator rights, a dedicated USB–Ethernet adapter and an Ethernet cable. Select that adapter, not the PC's primary network connection.

## Audio

| Tested configuration | Evidence |
| --- | --- |
| AB13X USB Audio directly through OHCI | 100 process starts without failure; later control bells were confirmed audible. |
| C-Media directly through OHCI | 100 process starts without failure. |
| Replacement hub + C-Media USB PnP Sound Device through OHCI | 100 starts without failure. |
| Earlier hub through EHCI | Intermittent USB audio startup failures; unresolved and not recommended for operation. |

For now use a direct OHCI connection or a hub where **Metrics → Resources → Audio** reports **OHCI**. The other controller's spelling is **EHCI**. These names identify the USB controller path, not a hub brand or certification.

AB13X and C-Media are detected device names, not guaranteed retail models. The public report does not establish the exact tested hub model, so this is not a recommendation for a specific product. OHCI alone does not establish reliability of every hub, audio adapter, cable or power supply.

Connect powered speakers or an amplifier and speakers. Check a manual bell, then scheduled pre-bell and main bell, audibility and journal entries. Successful process completion alone does not prove audible output.

The [USB audio report](PLAYBACK_RELIABILITY.en.md) records measurements and limits. This recommendation does not close the earlier EHCI defect or replace testing new components.
