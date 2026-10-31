# License and notice delivery

[Русский](LICENSE_DELIVERY.md)

Date: 2026-10-31. Baseline: `03473c4ce26fb04bf4f74ba99badab11c9e01fe1`.
Shared builder module scripts/license_materials.py delivers exact root LICENSE/NOTICE
copies and a standalone bilingual LICENSE-SCOPE.txt. MIT covers own code only;
audio/third-party materials are excluded. NOTICE source paths refer to the repository,
not installed device paths.

| Artifact | Destination | Additional materials |
| --- | --- | --- |
| modbus-schoolbell | `/usr/share/modbus-schoolbell/` | AUDIO-NOTICE.txt and media-manifest.json for six MP3s |
| modbus-schoolbell-clock | `/usr/share/modbus-schoolbell-clock/` | LICENSE, NOTICE, LICENSE-SCOPE.txt; no audio or ownership conflict with main IPK |
| Pages | `licenses/`, linked from the UI | MIT/NOTICE/scope, audio notice/manifest, Apache-2.0 and LuCI notice; return link |
| Offline bundle | `licenses/` | All above notices plus DEPENDENCIES.json/txt describing actual input IPKs |

Legacy Pages assets/NOTICE.txt remains the audio notice, now with media-manifest.json
alongside. Existing LuCI assets URLs are retained. Recursive SHA256SUMS covers licenses
and the target builder's added build-provenance.json. Bundle assembly refuses to
publish its directory if main/native IPKs lack current notice materials. Rebuild
old candidates without those files instead of presenting them as new builds.

Versions remain 5.1.28/1.0.0 under the project's documentation-only change rule.
IPK hashes changed; the old 5ab216e bundle was not overwritten. Runtime, lifecycle
scripts, native ELF and stock MP3 bytes match the prior candidate. Main IPK changes
NOTICE and Installed-Size and adds three documents; native adds three documents.
New outputs are candidates, not an installed release.

## Actual dependency gaps

All 33 locked IPKs were checked, including SHA-256/control. 32 License fields match.
luci-lib-jsonc has no License field (lock: unspecified); its LuCI 712bc8e source header
states Apache-2.0, which does not rewrite binary metadata. Evidence is kept separate;
MIT is not silently assigned to dependencies.

None of the 33 payloads has a separate filename containing license/copying/notice/
copyright. This filename scan is not an exhaustive inline-notice review. For every
input dependency, DEPENDENCIES.json records exact version/hash, original License/
Source fields, binary URL and missing materials:

- Sources, patches, configuration and build recipes corresponding to those binaries.
- Applicable full license texts and component-specific copyright/attribution notices.
- Precise GPL/LGPL editions, GCC exception and applicable source-delivery obligations.

Cached SDK/OpenWrt/Lua archives are not a complete corresponding-source kit for all
33 packages. Dependency IPKs remain byte-identical; adding own-code MIT does not
close their gaps. Optional core is also reported as an unreviewed external component.
Firmware libc/kernel and audio rights need separate review. Manifest and report
state distribution_cleared: false.

## LuCI

Time-zone data source pinned to `712bc8e52d73720dc42577c08eb80ce7b1548b1e`.
The retrieved tzdata.lua SHA-256 matches the previously recorded
`6737c7e313f858ac041bdd62582fe36aeb4c4ed2f676f4ba06108e68301a67fb`.
All 452 pairs match portable-zones.json after UTC=UTC is added. Original license
notice, full Apache-2.0 and transformation description are retained. This closes L3
for these data, not an audit of all LuCI components.

## Validation and limits

Focused checks inspect actual notice bytes in main IPK/Pages; bundle refusals for
missing/stale documents; optional core; atomic failure and nested LICENSE tampering
via SHA256SUMS. Target build checks real MIPS ELF/native package contents; synthetic
CI fixtures do not replace it. L5 delivery of the own-code set is complete. L2 (full
dependency materials) and L4 (audio rights) remain open; future dependency additions
under L5 require checking the final release set. No device, sound or settings access.

This iteration: full `make all`, focused refusals and links — PASS.
Real MIPS bundle built offline from caches; ELF checked and the module loaded by
real MIPS Lua under QEMU (`MIPS_LUA_LOAD_OK`). Nested checksums, 33 original IPKs
and runtime/MP3 preservation verified. These are host/QEMU checks, not installation
or hardware acceptance.
