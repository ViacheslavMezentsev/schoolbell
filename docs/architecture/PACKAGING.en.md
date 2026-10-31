# Schoolbell IPK and offline bundle

GitHub release checks and UI-driven installation are future shared requirements: [release updates](https://github.com/ViacheslavMezentsev/openwrt-modbus-core/blob/243a7ccad6aeb2499d3efd5d0c4cef9e822d393e/docs/core/RELEASE_UPDATES.en.md), schoolbell specification 4.8. Current 5.1.2 does not check or install online releases. The build manifest and SHA256SUMS are not a signed release manifest.

[Русский](PACKAGING.md)

5.0.31 packages the existing engineering executor, LuCI UI, calendar, media library,
backup, time trust and six MP3s. It is a complete IPK of the current application,
not completed production integration with the core event API or isolated player queue.
Native clock 1.0.0 remains a separate IPK. Target opkg installation, recovery downgrade and upgrade have been checked with preserved settings/media and automatic bells off; browser acceptance is separate.

## Build and joint release

```sh
make build-schoolbell
# Build native clock with scripts/build-schoolbell-clock.py (see CLOCK_UI.en.md).
make build-core VERSION=0.4.0-1+g$(git rev-parse --short HEAD)
python3 scripts/build-schoolbell-bundle.py \
  --schoolbell out/modbus-schoolbell_5.0.31_all.ipk \
  --native out/schoolbell-clock/modbus-schoolbell-clock_1.0.0_mipsel_24kc.ipk \
  --core out/modbus-rtu-core_0.4.0-1+g$(git rev-parse --short HEAD)_all.ipk \
  --out out/schoolbell-release --download
tar -czf out/schoolbell-release-openwrt-19.07.9-mipsel_24kc.tar.gz -C out schoolbell-release
sha256sum out/schoolbell-release-openwrt-19.07.9-mipsel_24kc.tar.gz
```

Omit `--download` for an entirely cached build; use a new output directory.
Missing cache files, checksum/architecture/native-version mismatches and incomplete
closure fail before output publication. Output includes IPKs, manifest.json,
dependency lock, SHA256SUMS, read-only check.sh and these instructions. Rebuild from
an accepted clean HEAD after CI for release: the manifest records commit and dirty
state. The builder never publishes or installs anything.

Core and schoolbell may share one GitHub Release while retaining independent versions.
Target: **OpenWrt 19.07.9, ramips/mt76x8, mipsel_24kc, musl, Lua 5.1**.
Firmware prerequisites: kernel `4.14.267-1-d92769dc5268e102503ae83fe968a56c`,
libc `1.1.24-2`; neither is replaced. Script architecture `all` does not make native
IPKs portable to other firmware. Other OpenWrt versions need their own build/test.
Core is a companion artifact, not a dependency on its unreleased event API.

The lock pins 33 official dependencies (Lua/LuCI, madplay, USB audio), 950356 bytes.
Only luci-base and its theme are needed, not the full firewall/network metapackage.
All non-firmware dependencies are included. Existing installed versions may differ
from the feed; satisfying Depends is allowed but not proof of hardware compatibility.
Do not blindly upgrade existing system packages. HTTPS and pinned SHA protect
integrity against the reviewed lock; SHA alone is not release authentication.
Honor upstream source/notice licensing obligations before distributing binaries.
Audio was imported at the owner's request; no new audio license is assigned.

## Installation and rollback — separately approved target stage

1. Verify provenance/checksums on the PC. Save a verified `.sbb`, separate copies of
   `/etc/schoolbell-editor`, `/etc/modbus-schoolbell/data`, opkg metadata and a
   compatible previous complete IPK outside the router. `.sbb` excludes device
   clock reference/policy.
2. Review release/architecture/kernel ABI and installed dependency versions.
   `sh check.sh` checks identity/hashes and prints free space; it installs nothing.
   Account for `/tmp` IPKs, unpacking, metadata, old data/backups and at least
   max(512 KiB, 10% overlay) reserve. Manifest payload/block fields are estimates;
   feed Installed-Size is compressed, not a peak budget. Packages already in
   squashfs reduce incremental space. Generic admission/peak calculation is pending.
3. Disable automatic bells, finish sound/upload/backup operations and close the UI.
   For the first engineering-tar migration inspect file ownership with `opkg search`
   and retain its payload/data backup. Never force-overwrite conflicts.
4. After separate approval, install only missing compatible dependencies from local
   IPKs, then native clock, then schoolbell with `opkg install /path/to/package.ipk`.
   All files are present offline; no `opkg update` is needed. Stop on ABI/version
   conflicts rather than force-depends. Installing the included core is a separate action.
5. Hooks disable/stop the service and retain the shared sound/media gate plus durable
   `package.pending`. Postinst persists/readbacks auto-off, releases only its own gate
   and starts the disabled executor. Corrupt state, foreign locks and write failures
   leave installation blocked. Never remove a foreign lock. No clock/NTP/network edits.
6. Verify version, LuCI login, draft/media/backup reads, auto-off and core/demo health.
   Sound and activation require explicit actions. Remove temporary installer IPKs
   only after validation; retain the external rollback copy.

Rollback uses a compatible previous complete application IPK:
`opkg --force-downgrade install /path/to/previous.ipk`. This permits a version
reduction only; it does not override ABI/dependency checks. Hooks preserve auto-off.
Older code must understand the retained data schema; otherwise restore a verified
backup explicitly, never discard fields silently. Pre-5.0.28 preview IPKs are not
complete application rollback artifacts. The first migration requires the previous
engineering payload/data and separate target validation.

User directories are not package-owned or deleted on uninstall; package.pending
remains until a complete reinstall finishes. IPKG_INSTROOT hooks never execute
services/target code; when enabled in a built image the initializer creates private
roots, with fresh state defaulting to auto-off. Pending installations cannot start.
This is not power-fail-atomic opkg rollback; damaged code needs external recovery.

## Validation

TC-134 uses actual payload/hooks/Lua in an isolated host root with translated paths,
substitute procd and native host FS: fresh install, upgrade, rollback, data retention,
corruption/foreign-lock refusal and retry after tmpfs loss. TC-135 checks dependency
closure, hashes, architecture, exact native version and offline-cache failures.
CI does not execute MIPS code or replace target opkg/flash validation. Reboot,
power loss and year-long autonomous accuracy are not validated here.

Finishing installation clears only temporary mailbox request/result/next files under
its lock. A pending package marker rejects new commands before and after lock
acquisition, preventing stale enable requests from executing in the new worker.

Target compatibility findings: OpenWrt BusyBox can omit `stat`, so hooks use the
declared Lua/nixio dependencies. opkg may return zero even after failing to extract
files into omitted directories; both builders emit directory entries, and artifact
checks reject missing parents. Verify every installed payload hash, not exit code
alone. LuCI 19.07 bytecode ignores source mtimes, so postinst clears only schoolbell
module/controller caches and dispatcher indexes. Kernel/native clock runtime unchanged.

The first rollback used a locally generated `5.0.27+recovery` IPK made from the
installed engineering payload plus safe lifecycle support, not an old public release.
It preserved the original code bytes and user data. Reboot/power-loss/offline-first-boot
remain untested; no guarantee for incompatible older data schemas is implied.
