# TL-MR3020 (EU) V3.30 OEM archives and installation method

[Русский](oem-firmware.md) · [Installer](../README.md#english) · [OEM recovery](../RECOVERY.md)

## Why the installer uses Reset

The installer uses the bootloader's TFTP recovery mode: hold Reset while applying power, with a server on the PC. OpenWrt 19.07.9 installation and stock Build250625 recovery have been tested on EU Ver. 3.30. This route does not depend on the stock web interface or its password.

TP-Link **Firmware Upgrade → Browse → Upgrade** expects a different file format. Static analysis of **1.8.0 Build250625** found size, MD5, content RSA signature, product ID, hardware platform version and additional compatibility checks. OpenWrt does not have a TP-Link signature. Renaming the file, removing its TFTP prefix or recalculating MD5 does not create that signature.

No valid OpenWrt web-upgrade candidate was produced for this OEM release. Use the tested Reset workflow. This finding applies to the examined Build250625, not every OEM release. The exact error of a historical attempt cannot be identified without its log; incompatibility with the discovered checks was established locally.

**Do not interchange files:** the original OEM BIN inside its ZIP follows the vendor update procedure; OpenWrt `tftp-recovery.bin` is for the bootloader; `sysupgrade.bin` updates an existing OpenWrt installation. Our prepared OEM recovery payload is not a web-upgrade file either.

## Preserved releases

Source: [official EU V3.30 support page](https://www.tp-link.com/en/support/download/tl-mr3020/v3.30/) and [saved HTML](tp-link-mr3020-v3.30-en.html). Expand **More** below Firmware if necessary. ZIP files are unchanged and include vendor instructions and GPL terms. [manifest.json](manifest.json) records URLs, sizes and SHA256.

| Release | Original local ZIP | Status |
| --- | --- | --- |
| 1.8.0 Build250625, published 2025-07-14 | [250625](tl-mr3020-eu-v3.30-250625.zip) | RestoreFactory passed OpenWrt → OEM and OEM → OEM. Original ZIP name says 1.7.0; its BIN and UI identify 1.8.0. |
| 1.9.0 Build260303, published 2026-05-13 | [1.9.0](tl-mr3020-eu-v3.30-1.9.0-260303.zip) | Official EU V3.30 release; archive and signature checked locally. Installation/recovery not hardware-tested. |
| 1.10.0 Build260303, published 2026-05-14 | [1.10.0](tl-mr3020-eu-v3.30-1.10.0-260303.zip) | Official EU V3.30 release, different container. Vendor warns that downgrading to a previous release is unavailable. Installation/recovery not hardware-tested. |

**RestoreFactory still supports only Build250625.** New ZIPs are not recovery profiles; the existing transformation must not be applied automatically to 1.10.0. Preserving original archives retains inputs for future recovery work, not a guarantee of arbitrary version rollback. Record the full OEM version and save settings before changing firmware. Do not upgrade to 1.10.0 merely as a step towards OpenWrt.

V3.0/V3.20 archives are not included as EU V3.30 recovery support. Examined V3.20 files have additional hardware version 2, versus 3 in Build250625; these are not interchangeable recovery profiles.

## Local analysis, 2026-11-09

The original Build250625 yielded `web/main/softup.htm` and `lib/libcmm.so`. The form calls `/cgi/softup`, then `/cgi/softburn`. Its server function `rsl_sys_verifyFirmware` is at 0x198a4 in this library; GOT resolution identifies `cen_rsaVerifySignByBase64En`. Signature failure returns 4503 on the examined mandatory path; insufficient additional hardware version returns 4506.

OEM contains a 512-byte outer header, a 128-KiB bootloader block and an inner image. OpenWrt recovery contains a 128-KiB prefix followed by an image without an OEM bootloader. Main OEM header fields are little-endian; OpenWrt tplink-v2 fields are big-endian, except selected addresses. Matching HWID 0x30200003 after proper decoding does not establish web-container compatibility: OEM product version is 1, OpenWrt HWREV is 3.

The Build250625 signature model was reproduced locally: outer signature at 0xd0, public RSA key extracted from the library, MD5 over the payload after the first 512 bytes with its inner signature field zeroed, and RSA PKCS#1 v1.5 verification of SHA1 over those 16 MD5 bytes. The complete signature block matched Build250625, 1.9.0 and two comparison V3.20 releases. Modifying one payload byte invalidated the signature. This is a host-side validator model, not execution of the OEM handler or hardware acceptance. The different 1.10.0 container/validator has not been fully analyzed.

No router flash or web-form upload was performed. Preserved archives retain upstream rights and are not relicensed under MIT.
