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
