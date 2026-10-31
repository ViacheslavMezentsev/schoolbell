# Host build and tests

[Русский](BUILD.md) · [IPK and dependencies](PACKAGING.en.md)

Requirements: Linux/WSL, Python 3.8+, Node.js 18+, make, GCC, libc headers,
Lua 5.1 and liblua5.1-0-dev. Ubuntu: `sudo apt-get install lua5.1 liblua5.1-0-dev gcc libc6-dev make python3 nodejs`.
Check `node --version`; use a supported Node 18+ installation if needed.
Never install build tools on the device.

```sh
make all
```

Runs archive/docs checks, script IPK build and validation, C/Lua/player child,
calendar, media, .sbb/.sbp, HTTP/UI, clock fault injection and package lifecycle
tests. Uses temporary directories, fake commands and test children; no audio,
device access, host clock setting or NTP changes. No sibling core required.
LUA_CFLAGS/LUA_LIBS support an externally installed Lua SDK; put lua5.1 on PATH
and configure LD_LIBRARY_PATH for a local shared library. Never commit the SDK.
`make build verify` requires neither Lua nor a compiler.

This does not cross-build the MIPS clock IPK, download real offline dependencies,
deploy Pages or perform hardware acceptance. Pages build/tests are included in make all. See PACKAGING for cross-build
and ABI conditions. Offline tests use synthetic packages, not installable artifacts.

Sources live under src/lua, src/native and src/portable-plan; UI under ui/root;
system payload and metadata under packaging/openwrt; strict JSON under vendor/modbus.
site contains the demo, guide and training; the owner publishes Pages separately.
Schoolbell CI runs make all; require successful ci-gate for the exact pushed SHA
before land. A built IPK does not authorize installation.
