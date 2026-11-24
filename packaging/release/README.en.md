# Schoolbell package bundle — candidate

[Русский](README.md)

**Local archive-format candidate, not a public installation release.** manifest.json
identifies the application and files. Includes the app, native clock and all 33 pinned
dependencies; excludes firmware and the wizard.

## Compatibility

OpenWrt 19.07.9, ramips/mt76x8, mipsel_24kc, MR3020 v3. scripts/check.sh checks exact
kernel/libc ABI. Project hardware checks used EU v3.30; they do not validate every
revision or fresh installation of this ZIP. Do not replace kernel/libc or force dependencies.

## Host checks

Extract into a separate host directory and check SHA256SUMS. Hashes detect corruption;
signed provenance is not implemented yet. Verify the download source first. Do not copy
the entire bundle to a small router's /tmp without RAM admission; extract on the host.

## Professional workflow

Before manual installation, save configuration/overlay and a recovery plan off-device,
and stop automatic bells. Compare `opkg list-installed` with packages.tsv and check
incremental RAM/flash needs. Existing compatible dependencies need not be reinstalled.
Do not install a wildcard of every IPK or refresh feeds for this offline bundle; transfer
only required packages. With the complete extracted bundle on suitable router storage,
`sh scripts/check.sh` checks identity and integrity without changing settings. It neither
admits space nor creates backups. After a separately performed installation,
`sh scripts/verify.sh` checks versions, services and automation off. Neither script changes
sound, network, time or packages.

**Automatic install.sh and manual-install acceptance remain unfinished.** This candidate
does not authorize unsupported upgrade/rollback paths. Wizard 0.1.0 still uses the legacy
embedded bundle; ZIP discovery is the next stage.

packages/ contains unchanged IPKs; licenses/ includes notices and distribution gaps;
RELEASE_NOTES.md describes the version; input-manifest.json records input provenance;
manifest.json defines format 1 and assembly provenance. Distribution clearance and hardware
validation remain false. Corresponding sources, component/audio rights, fresh-install
acceptance and signed artifacts must be addressed before public release. No device backups
are included.

## Preliminary plan on the host

The ZIP includes `scripts/snapshot.sh` (read-only device state) and `scripts/plan.py`
(Python 3.8+ on the host, no networking). For an authorized device, run only snapshot.sh
over SSH and save its standard output off-device as UTF-8 snapshot.tsv. Any SSH/script
error means an incomplete snapshot; do not use it. Do not transfer the entire ZIP.
Run from the extracted bundle on the host:

```sh
python3 scripts/plan.py --snapshot ../snapshot.tsv
```

Keep snapshot.tsv outside the bundle directory: exact SHA256SUMS coverage rejects extra
files. On Windows use `python` or `py -3` instead of `python3`. JSON output contains
`install`/`retain`, estimated RAM/overlay requirements and input hashes. Only fresh and
already-current inventories are supported. Upgrades need a validated rollback package;
repair of incomplete installations is also refused. Estimates include 512 KiB overlay
and 4096 KiB RAM reserves, exclude backup storage and cannot guarantee filesystem writes.

`preliminary-only` / `write_authorized=false` is not write admission or service health
verification. Snapshots may be stale or altered. Live rechecks, verified off-device
backup, recovery preparation and confirmation remain required before installation.
No write script is included yet. Hashes detect corruption, not trusted provenance.
