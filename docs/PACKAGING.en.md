# Standalone IPK build

[Русский](PACKAGING.md)

`make build verify` builds and validates the Lua/UI IPK offline without a device.
modbus-schoolbell-clock 1.0.0 remains a separate native dependency. Host native
tests do not build the MIPS package. Use the target OpenWrt musl toolchain:

```sh
python3 scripts/build-schoolbell-clock.py --cc /path/to/mipsel-openwrt-linux-musl-gcc --include /path/to/lua51/include --out out/native
python3 scripts/build-schoolbell-bundle.py --schoolbell out/modbus-schoolbell_5.1.28_all.ipk --native out/native/modbus-schoolbell-clock_1.0.0_mipsel_24kc.ipk --cache out/offline-cache --out out/release
```

Prepopulate cache with pinned IPKs from packaging/offline/openwrt-19.07.9-mipsel_24kc.json.
Only explicit --download fetches missing packages, verifying length and SHA-256.
--core is optional for joint bundles. Target is OpenWrt 19.07.9 ramips/mt76x8,
mipsel_24kc, musl, Lua 5.1; firmware kernel ABI/libc are pinned in the lock.
The ELF check is not full ABI verification: use the correct toolchain and test
hardware separately. The bundle has manifest, SHA256SUMS and read-only check.sh,
not a signed release manifest. Build releases from an accepted clean SHA.
Nothing is installed or enabled; clocks/NTP are untouched. The historical archive
is excluded. Migration candidate 5.1.28 is based on 5.1.27, with payload differences reviewed.
It is not yet proposed for release or installation.

## Standalone target bundle

Linux x86_64 requires Python 3.8+, tar/xz, patch and an executable SDK environment.
The SDK provides GCC 7.5.0/musl for mipsel_24kc. Headers come from Lua 5.1.5
with every OpenWrt v19.07.9 target patch, not host Lua. Archive URLs, sizes and
SHA-256 are pinned in `packaging/offline/toolchain-19.07.9.json`. The SDK hash
was checked against official sha256sums; Lua against the OpenWrt Makefile.
The OpenWrt source archive hash pins downloaded bytes; it is not a publisher signature.

```sh
python3 scripts/build-target.py --download --out out/mips-first
# Repeat from caches without network access:
python3 scripts/build-target.py --out out/mips-offline
# Optional host QEMU load test with the actual MIPS Lua package:
python3 scripts/build-target.py --out out/mips-smoke --qemu qemu-mipsel
```

Only explicit `--download` permits fetching missing archives/IPKs. Corrupt cache
entries are rejected, never silently replaced. Output must be a new directory.
`--cache` selects SDK/source cache; `--dependencies` selects the 33 third-party
IPK cache. Copy both beforehand for offline builds. No sibling core is required;
the builder never contacts devices or installs packages.

Output: `script/` (5.1.28), `native/` (1.0.0, manifest and ELF audit), `bundle/`
(35 IPKs, manifest, SHA256SUMS, dependency lock, read-only check.sh and guides),
and `build-provenance.json` (SDK, headers and QEMU result). ELF verification
requires ELF32 LE MIPS32r2/o32 soft-float, libc.so and libgcc_s.so.1.
QEMU proves loading, not hardware clock/flash behavior.

Local evidence: two builds in different temporary directories produced native
IPK SHA-256 `24c07345de6409a89a3c74469e767c8fec440c73c70ed0ef008706d7bf48331b`;
the library is 17,924 bytes. All pinned dependencies, dependency closure and
SHA256SUMS passed. Total IPKs: 1,427,456 bytes; unpacked files: 2,988,309 bytes;
4 KiB per-file rounding estimate: 3,670,016 bytes. This is not incremental device
space (firmware already supplies some dependencies), a JFFS2 compression guarantee
or a RAM admission check. Native gzip timestamps are fixed for repeatable packing.

The bundle targets only the pinned release/kernel ABI. libc/kernel remain firmware
prerequisites, not forced replacement packages. Release from a clean signed HEAD;
the manifest reports dirty state. SDK/downloads/IPKs stay in ignored out, not Git.
Publication, distribution license review and bench install/upgrade/rollback remain
separate steps.
