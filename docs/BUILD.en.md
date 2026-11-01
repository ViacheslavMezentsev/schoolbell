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
Schoolbell CI selects checks by changed paths; require successful ci-gate for the exact pushed SHA
before land. A built IPK does not authorize installation.

## Selective CI checks

Following openwrt-modbus-core, CI always validates documentation and its own
selection rules. Separate jobs cover runtime (C/Lua), web (UI/Pages), and IPK.
Ordinary Markdown guides run web without C/Lua or IPK builds; UI JS/CSS/HTM
runs web and package; runtime Lua runs runtime and package. Contracts, licenses,
build scripts, CI and unknown paths select everything. The mandatory documentation
check validates source-map changes.

Selection covers the entire push range, deletions and both sides of renames.
Manual runs, new branches and unavailable history use the full suite.
`ci-gate` requires every selected job to succeed; only unselected jobs may be
skipped. An IPK artifact is produced only when package is selected.
`make all` still runs the complete local suite, including `make check-ci`.
