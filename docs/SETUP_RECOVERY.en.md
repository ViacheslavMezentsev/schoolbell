# Factory recovery: TL-MR3020 EU v3.30

[Русский](SETUP_RECOVERY.md) · [Wizard](../tools/setup/README.md)

## Acceptance on 2026-11-09

A spare EU v3.30 returned from OpenWrt 19.07.9 to **1.8.0 0.9.1 v0001.0 Build 250625 Rel.56805n**. All 8,126,464 bytes and terminal block15873 were acknowledged. Normal LEDs, stock Wi-Fi, DHCP, ICMP and HTTP200 were observed. After a separately authorized factory reset, the owner created a password and supplied an authenticated Status screenshot confirming the firmware and TL-MR3020 v3 00000003. The working router was not used.

All seven MTD partitions were backed up with matching remote before/after and host SHA256; configuration and overlay were also saved. An 8 MiB flash image was assembled from non-overlapping boot/firmware/config/factory. Restoring those backups was not tested. Private dumps/logs/identifiers are not published.

## Failure mechanism and artifact

The original OEM up_boot file contains a 512-byte outer header, 128 KiB padded bootloader and a 0x7a0000-byte inner image starting at 0x20200. The installed loader exactly matched the OEM bootloader. Recovery loads at RAM 0x80060000 and copies 0x7a0000 bytes from 0x80080000 to flash 0x20000: it skips only 128 KiB. The original file therefore shifted firmware header/kernel by 512 bytes. The old transfer had completed; transport failure alone did not explain the result.

The verified candidate is **128 KiB zeros + the unchanged OEM inner image from 0x20200**. It includes no OEM bootloader. The write window is [0x20000,0x7c0000), excluding boot/config/factory. Kernel/rootfs/header fields are unchanged. The original salted checksum and kernel decompression were verified. This conversion is allowed only for the pinned source, not arbitrary firmware.

- Original BIN SHA256: `1141467bd4b7b8292e2a50811a388eb999f4cbf207365e1be47718ebc6143d2f`.
- Recovery SHA256: `2b0d85b1c7f5e6c65930e117ada0afe60a29a35882ecac65610191876b6b0665`, 8,126,464 bytes.

The [official TP-Link archive](https://static.tp-link.com/upload/firmware/2025/202507/20250714/TL-MR3020_3.0_1.7.0%20Build%20250625.zip) is named 1.7.0, but the enclosed BIN and running UI report 1.8.0. Inputs are pinned by hash, not archive name. See the [OpenWrt image recipe](https://github.com/openwrt/openwrt/blob/v19.07.9/target/linux/ramips/image/mt76x8.mk) and [header structure](https://github.com/openwrt/openwrt/blob/v19.07.9/tools/firmware-utils/src/mktplinkfw2.c). No firmware binaries are committed.

## Password and limits

Recovery does not reset configuration. The previous administrator password may remain; a separate powered-on factory reset lets the owner create a new one if forgotten. The Wi-Fi label key is separate. See the wizard README for steps.

Hardware evidence covers the prepared image and manual Python TFTP path OpenWrt → OEM, not end-to-end acceptance of the new Setup.cmd -RestoreFactory route. OEM → OEM and full OEM feature qualification remain untested. Return to OpenWrt and Schoolbell 5.1.123 installation through PowerShell 7 passed later on 2026-11-09; see the [record](acceptance/ACCEPTANCE_RUN.en.md). Post-write protected-region hashes were not checked; config was then intentionally reset. There is no historical failed-flash dump/UART trace to establish the exact old boot failure stage. Transient HTTP unavailability after writing remains unexplained.

[Supported models/revisions and offline kit](../tools/setup/RECOVERY.md) · [archived vendor summary](../tools/setup/vendor/support.en.md) · [original downloads and hashes](../tools/setup/vendor/manifest.json).
