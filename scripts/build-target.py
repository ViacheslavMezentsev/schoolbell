#!/usr/bin/env python3
"""Build the pinned OpenWrt MIPS package and offline bundle; never contact a device."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import subprocess
import tempfile
import urllib.request
from schoolbell_ipk import read, sha
from license_materials import checksums

ROOT = Path(__file__).resolve().parents[1]


def verified_cache(cache, item, download=False):
    path = cache / item['file']
    if not path.exists():
        if not download:
            raise ValueError('Missing cached input: ' + str(path) + '; use --download explicitly')
        cache.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=cache, delete=False) as output:
            temporary = Path(output.name)
            try:
                with urllib.request.urlopen(item['url'], timeout=60) as response:
                    remaining = item['bytes'] + 1
                    while remaining:
                        chunk = response.read(min(remaining, 1024 * 1024))
                        if not chunk:
                            break
                        output.write(chunk)
                        remaining -= len(chunk)
                output.close()
                verify(temporary, item)
                temporary.replace(path)
            finally:
                temporary.unlink(missing_ok=True)
    verify(path, item)
    return path


def verify(path, item):
    if path.stat().st_size != item['bytes'] or hashlib.sha256(path.read_bytes()).hexdigest() != item['sha256']:
        raise ValueError('Size/SHA256 mismatch: ' + str(path))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache', type=Path, default=ROOT / 'out/target-cache')
    parser.add_argument('--dependencies', type=Path, default=ROOT / 'out/offline-cache')
    parser.add_argument('--out', type=Path, required=True, help='new output directory')
    parser.add_argument('--download', action='store_true')
    parser.add_argument('--qemu', help='optional qemu-mipsel executable for a Lua module-load smoke test')
    args = parser.parse_args()
    out = args.out.resolve()
    if out.exists():
        raise ValueError('Output must be a new directory')
    lock = json.loads((ROOT / 'packaging/offline/toolchain-19.07.9.json').read_text())
    archives = {k: verified_cache(args.cache, v, args.download) for k, v in lock['inputs'].items()}
    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.mips-build-', dir=out.parent) as work:
        work = Path(work)
        # Only hash-pinned archives are extracted, into a fresh private directory.
        for path in archives.values():
            subprocess.run(['tar', '-xf', str(path.resolve()), '--no-same-owner', '-C', str(work)], check=True)
        sdk = work / lock['sdk_directory']
        lua = work / 'lua-5.1.5'
        patches = work / 'openwrt-19.07.9/package/utils/lua/patches'
        for patch in sorted(patches.glob('*.patch')):
            subprocess.run(['patch', '--batch', '-p1', '-i', str(patch)], cwd=lua, check=True, stdout=subprocess.DEVNULL)
        toolchain = sdk / 'staging_dir/toolchain-mipsel_24kc_gcc-7.5.0_musl'
        cc = toolchain / 'bin/mipsel-openwrt-linux-musl-gcc'
        env = dict(os.environ, STAGING_DIR=str(sdk / 'staging_dir'))
        def run(*command):
            return subprocess.run(list(map(str, command)), cwd=ROOT, env=env, check=True)
        result = work / 'result'
        result.mkdir()
        run('python3', ROOT / 'scripts/build-schoolbell.py', '--out', result / 'script')
        run('python3', ROOT / 'scripts/build-schoolbell-clock.py', '--cc', cc, '--include', lua / 'src', '--out', result / 'native')
        package = next((result / 'script').glob('modbus-schoolbell_*_all.ipk'))
        command = ['python3', ROOT / 'scripts/build-schoolbell-bundle.py', '--schoolbell', package,
                   '--native', result / 'native/modbus-schoolbell-clock_1.0.0_mipsel_24kc.ipk',
                   '--cache', args.dependencies.resolve(), '--out', result / 'bundle']
        if args.download:
            command.append('--download')
        run(*command)
        native = read(result / 'native/modbus-schoolbell-clock_1.0.0_mipsel_24kc.ipk')[2]
        so = work / 'clock_linux.so'
        so.write_bytes(native['usr/lib/lua/schoolbell/clock_linux.so'][0])
        readelf = toolchain / 'bin/mipsel-openwrt-linux-musl-readelf'
        env['LC_ALL'] = 'C'
        audit = subprocess.check_output([str(readelf), '-h', '-A', '-d', '-Ws', str(so)], env=env, text=True)
        if not all(mark in audit for mark in ('ELF32', 'little endian', 'mips32r2', 'o32', 'Soft float', 'luaopen_schoolbell_clock_linux')):
            raise ValueError('Unexpected native ABI/export')
        if set(re.findall(r'\(NEEDED\).*\[(.*?)\]', audit)) != {'libgcc_s.so.1', 'libc.so'}:
            raise ValueError('Unexpected native shared dependencies')
        lua_ipk = next((result / 'bundle').glob('liblua5.1.5_*.ipk'))
        lua_so = work / 'liblua.so'
        lua_files = read(lua_ipk)[2]
        lua_so.write_bytes(next(body for name, (body, _) in lua_files.items() if name.startswith('usr/lib/liblua.so.') and body.startswith(b'\x7fELF')))
        smoke = 'not requested'
        if args.qemu:
            # Feed libraries have no section headers (sstrip). Test actual dynamic loading.
            libs = work / 'smoke-libs'
            libs.mkdir()
            (libs / 'liblua.so.5.1.5').write_bytes(lua_so.read_bytes())
            lua_binary = work / 'lua'
            lua_binary.write_bytes(read(next((result / 'bundle').glob('lua_*.ipk')))[2]['usr/bin/lua'][0])
            lua_binary.chmod(0o755)
            code = 'local f=assert(package.loadlib(arg[1],"luaopen_schoolbell_clock_linux")); local m=f(); assert(type(m.sample)=="function" and type(m.open)=="function"); print("MIPS_LUA_LOAD_OK")'
            script = work / 'smoke.lua'
            script.write_text(code)
            run(args.qemu, '-L', toolchain, '-E', 'LD_LIBRARY_PATH=' + str(libs) + ':' + str(toolchain / 'lib'), lua_binary, script, so)
            smoke = 'MIPS_LUA_LOAD_OK (QEMU, no clock/storage calls, not hardware)'
        (result / 'native/elf-audit.txt').write_text(audit)
        provenance = {'inputs': lock, 'compiler': subprocess.check_output([str(cc), '--version'], env=env, text=True).splitlines()[0],
                      'lua_headers': 'Lua 5.1.5 with all OpenWrt v19.07.9 target patches (not host headers)',
                      'qemu_smoke': smoke, 'hardware_validated': False}
        (result / 'build-provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
        (result / 'bundle/build-provenance.json').write_bytes((result / 'build-provenance.json').read_bytes())
        (result / 'bundle/SHA256SUMS').write_text(checksums(result / 'bundle'))
        result.rename(out)
    print('BUILD COMPLETE: ' + str(out) + ' (not installed or hardware validated)')


if __name__ == '__main__':
    main()
