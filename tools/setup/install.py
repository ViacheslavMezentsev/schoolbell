"""Install only on a directly connected, fresh TL-MR3020 v3. Windows OpenSSH."""
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parent
BUNDLE = ROOT / 'bundle'
CHECK = """set -eu
. /etc/openwrt_release
test "$(id -u)" = 0
test "$(cat /tmp/sysinfo/board_name)" = 'tplink,tl-mr3020-v3'
test "$DISTRIB_RELEASE:$DISTRIB_TARGET:$DISTRIB_ARCH" = '19.07.9:ramips/mt76x8:mipsel_24kc'
test "$(opkg status kernel | sed -n 's/^Version: //p')" = '4.14.267-1-d92769dc5268e102503ae83fe968a56c'
test "$(opkg status libc | sed -n 's/^Version: //p')" = '1.1.24-2'
"""
VERIFY = """test "$(opkg status modbus-schoolbell | sed -n 's/^Version: //p')" = '5.1.123'
test "$(opkg status modbus-schoolbell-clock | sed -n 's/^Version: //p')" = '1.0.0'
test ! -e /etc/schoolbell-editor/package.pending
lua -e 'package.path="/usr/share/schoolbell-editor/lua/?.lua;"..package.path;local s=require("schoolbell.automatic_store");assert(not s.decode(s.raw()).enabled)'
/etc/init.d/schoolbell-auto running
/etc/init.d/uhttpd running
"""

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def packages():
    manifest = json.loads((BUNDLE / 'manifest.json').read_bytes())
    rows = manifest['packages']
    assert manifest['architecture'] == 'mipsel_24kc'
    for row in rows:
        if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.+-]*\.ipk', row['file']):
            raise ValueError('Invalid package filename')
        if sha(BUNDLE / row['file']) != row['sha256']:
            raise ValueError('Damaged package: ' + row['file'])
    return rows

# Factory OpenWrt r11405-2a3558b0de package versions observed after TFTP.
STOCK = {
    "libubus-lua": "2021-07-01-38c7fdd8-1",
    "libubus20210603": "2021-07-01-38c7fdd8-1",
    "luci-base": "git-22.045.73925-36e5c1c-1",
    "luci-lib-ip": "git-22.045.73925-36e5c1c-1",
    "luci-lib-jsonc": "git-22.045.73925-36e5c1c-1",
    "luci-lib-nixio": "git-22.045.73925-36e5c1c-1",
    "luci-theme-bootstrap": "git-22.045.73925-36e5c1c-1"
}

def plan(rows, installed):
    missing = []
    for row in rows:
        version = installed.get(row['name'])
        if version is None:
            missing.append(row)
        elif version != row['version'] and version != STOCK.get(row['name']):
            raise ValueError(f"Existing {row['name']} {version}; expected {row['version']}. Aborting.")
    return missing

def install(ssh):
    def remote(cmd, **args):
        return subprocess.run(ssh + [cmd], check=True, **args)

    rows = packages()
    # Also identifies the board before any remote write.
    inventory = remote(CHECK + 'opkg list-installed', capture_output=True, text=True).stdout
    installed = dict(line.split(' - ', 1) for line in inventory.splitlines() if ' - ' in line)
    marker = '/tmp/schoolbell-setup-5.1.123'
    known = 'test -f ' + marker
    if 'modbus-schoolbell' in installed:
        remote(known + ' || { echo "Schoolbell already installed. Fresh installation only."; exit 1; }')
    else:
        remote(known + ' || { test ! -e /etc/schoolbell-editor && test ! -e /etc/modbus-schoolbell; }')
    missing = plan(rows, installed)
    if missing:
        for row in missing:
            print(row['name'], row['version'])
        reserve = 512 * 1024
        overlay = (sum(r['file_blocks_estimate'] for r in missing) + reserve + 1023)//1024
        ram = (sum(r['bytes'] for r in missing) + 1023)//1024 + 2048
        space = f"""test "$(df -k /overlay | awk 'END {{print $4}}')" -ge {overlay} || {{ echo 'Insufficient flash'; exit 1; }}
test "$(df -k /tmp | awk 'END {{print $4}}')" -ge {ram} || {{ echo 'Insufficient tmpfs'; exit 1; }}
"""
        remote('set -eu\n' + space)
        if input('Install listed packages / Установить пакеты? [INSTALL]: ').strip() != 'INSTALL':
            raise SystemExit('Cancelled')
        # All IPKs named explicitly to opkg. No feed refresh or forced dependency overrides.
        with tempfile.TemporaryFile() as payload:
            with tarfile.open(fileobj=payload, mode='w',format=tarfile.USTAR_FORMAT) as tar:
                for row in missing:
                    tar.add(BUNDLE / row['file'], arcname=row['file'], recursive=False)
                checks = ''.join(r['sha256']+'  '+r['file']+'\n' for r in missing).encode()
                info=tarfile.TarInfo('SHA256SUMS')
                info.size=len(checks)
                tar.addfile(info, io.BytesIO(checks))
            payload.seek(0)
            remote(CHECK + space + f"""umask 077
d=$(mktemp -d /tmp/schoolbell-install.XXXXXX)
trap 'rm -rf "$d"' EXIT
cd "$d"
tar xf -
sha256sum -c SHA256SUMS
touch {marker}
opkg install ./*.ipk
""", stdin=payload)
    remote(CHECK + VERIFY)
    print('Schoolbell 5.1.123 verified. Automatic bells off.')
    print('Set the router administrator password (input is hidden).')
    subprocess.run(ssh[:1]+['-t']+ssh[1:]+['passwd'],check=True)

if __name__ == '__main__':
    if sys.argv[1:] == ['--check']:
        print('Verified', len(packages()), 'packages')
    else:
        # Separate host-key database for this installation; bind to the direct cable IP.
        hostfile = Path(os.environ['LOCALAPPDATA'])/'SchoolbellSetup'/'known_hosts'
        hostfile.parent.mkdir(exist_ok=True)
        install(['ssh.exe','-F','NUL','-b','192.168.1.2','-o','ConnectTimeout=8',
                 '-o','HostKeyAlgorithms=+ssh-rsa','-o','StrictHostKeyChecking=ask',
                 '-o','UserKnownHostsFile="'+hostfile.as_posix()+'"','root@192.168.1.1'])
