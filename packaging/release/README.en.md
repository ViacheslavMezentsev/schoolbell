# Schoolbell package bundle — candidate

[Русский](README.md)

**Local candidate, not a public installation release.** Includes Schoolbell, native
clock and 33 pinned dependencies. Firmware and the GUI are separate.

## Compatibility and scope

OpenWrt 19.07.9, ramips/mt76x8, mipsel_24kc, TL-MR3020 v3; exact kernel/libc are checked.
Project EU v3.30 experiments do not establish hardware acceptance of this ZIP.
The manual installer supports **fresh OpenWrt**. Upgrades, repair, firmware flashing
and automatic rollback are not supported. An already-installed version is not reinstalled.

Run on a host with Python 3.8+ and OpenSSH; no router Python is required. On Windows
use `python` or `py -3`, on WSL/Linux `python3`. GUI 0.1.0 still uses its embedded
legacy bundle; GUI ZIP selection is a separate next stage.

## Preparation

Extract on the host and check archive SHA256SUMS and the source. Hashes detect corruption,
not authorship; signed downloads are pending. Do not copy the whole ZIP to router RAM,
replace kernel/libc, update feeds or install wildcard IPKs.

Use a dedicated Ethernet connection, reliable power, known root password or SSH key,
a previously verified device key in known_hosts and a verified image of the same
OpenWrt for recovery. Unknown keys are never accepted automatically. Routes are not
changed. Specify the intended router IPv4 and the dedicated adapter's local IPv4.
Automatic bells must be off. Reset is not needed for package installation.

The ZIP excludes `tp_recovery.bin`. Prepare it using tools/setup documentation; the
accepted SHA256 is
`e621da95d07d25102b1016a28400122f5c92bce9830d5cc061323e306b6204fa`.
Keep the session outside the extracted bundle in a private directory. The overlay
backup contains passwords/settings: never publish it or commit it to Git.

## Prepare, install, verify

Run on the host from the extracted bundle. Replace ROUTER_IP, PC_IP and KNOWN_HOSTS;
set paths to the original ZIP and recovery image. The session directory must be new;
existing backups are never overwritten.

```sh
python3 scripts/install.py prepare --zip ../schoolbell-v5.1.127-openwrt-19.07.9-ramips-mt76x8-mipsel_24kc.zip --recovery ../tp_recovery.bin --session ../install-session --host ROUTER_IP --source PC_IP --known-hosts KNOWN_HOSTS
python3 scripts/install.py install --session ../install-session
python3 scripts/install.py verify --session ../install-session
```

`prepare` validates ZIP, profile, inventory and space. It saves full overlay, inventory,
device/boot identity, protected-setting hashes and recovery image off-device. Transfer
hash and archive readability must pass before PREPARED. Backup RAM admission is separate
from package space.

`install` asks for `INSTALL ROUTER_IP`; preparation lasts 30 minutes. Session evidence,
IPKs, backups, connection, original boot, inventory, settings and space are rechecked.
Only missing packages are transferred, SHA256-checked and explicitly passed to opkg.
Success requires correct versions, services running, automation off and preserved
network/system settings. A fresh system has no previous Schoolbell plans/settings.

After an interrupted or uncertain write, `write-started` remains. **Do not retry install,
delete the marker or bypass it with a new installation.** Run `verify` on the original
session. Failed verification invalidates old success evidence. A reboot, key change or
partial installation needs separate diagnosis; there is no automatic repair or rollback.

The session retains `bundle.zip`, verified `overlay.tar`, `backup.tar`,
`openwrt-recovery.bin` and linked receipts. Recovery means flashing that same OpenWrt
through Reset and restoring overlay through a separate procedure, never the install
command. Hardware acceptance of this recovery cycle is still required.

The sibling `.guard` and `/tmp/schoolbell-release.lock` serialize this installer.
A leftover lock after a crash needs investigation; do not remove an active lock or run
other installation/configuration tools concurrently.

## Read-only checks

`snapshot.sh` reads device state; save its UTF-8 output outside the bundle. Reject any
failed/incomplete capture. On the host:

```sh
python3 scripts/plan.py --snapshot ../snapshot.tsv
```

The plan is `preliminary-only` / `write_authorized=false`; stale snapshots cannot replace
live checks, backup or confirmation. `check.sh`/`verify.sh` are legacy checks of the entire
extracted directory on suitable device storage, not installers.

## Status

Transactions are tested locally with synthetic data and injected SSH, including execution
of shell guards in an isolated filesystem. ZIP hardware acceptance, GUI integration,
Windows SSH transactions, corresponding dependency sources and audio rights remain open.
`distribution_cleared=false` and `hardware_validated=false` remain. packages/ contains
unchanged IPKs, licenses/ holds notices/open issues, RELEASE_NOTES.md describes the release,
and manifest.json/input-manifest.json record provenance.
