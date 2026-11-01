#!/usr/bin/env python3
"""Build the engineering LuCI payload; no installation or dependency downloads."""
import io
import pathlib
import sys
import tarfile

repo = pathlib.Path(__file__).resolve().parents[1]
files = {}
for root in (repo / 'packaging/openwrt/root', repo / 'ui/root'):
    for path in root.rglob('*'):
        if path.is_file():
            name = path.relative_to(root).as_posix()
            assert name not in files, 'duplicate payload path: ' + name
            files[name] = path
for name in ('test', '0', '1', '2', '3', '4'):
    files['usr/share/schoolbell-sound-test/' + name + '.mp3'] = repo / ('assets/melodies/' + name + '.mp3')
for name in ("system_actions", "system_reset", "audio_output", "plan_export_bundle", "plan_import", "plan_admission", "automatic_status", "system_metrics", "queue_metrics", "clock_set", "media_ids", "clock_commands", "clock_mailbox", "clock_policy", "clock_gate", "clock_trust", "clock_reference", "clock_reference_store", "clock_system", "backup", "backup_codec", "mp3", "media_manager", "media_library", "calendar", "media_codec", "media_fs", "schedule_store", "journal", "timezone", "controls", "automatic", "automatic_store"):
    files["usr/share/schoolbell-editor/lua/schoolbell/" + name + ".lua"] = (
        repo / "src/lua/schoolbell" / (name + ".lua"))
for name in ('codec','preview','export'):
    files['usr/share/schoolbell-editor/lua/schoolbell/plan_'+name+'.lua'] = repo / ('src/portable-plan/'+name+'.lua')
files["usr/share/schoolbell-editor/lua/modbus/json_strict.lua"] = (
    repo / "vendor/modbus/json_strict.lua")
version = next(line.split(': ', 1)[1] for line in
               (repo / 'packaging/openwrt/package/CONTROL/control').read_text().splitlines()
               if line.startswith('Version: '))
import re
assert re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version), 'expected major.minor.patch'
with tarfile.open(sys.argv[1], "w") as archive:
    data = (version + '\n').encode()
    entry = tarfile.TarInfo('usr/share/schoolbell-editor/VERSION')
    entry.mode = 0o644
    entry.size = len(data)
    archive.addfile(entry, io.BytesIO(data))
    dependency=b'{"time_control":{"package":"modbus-schoolbell-clock","version":"1.0.0","architecture":"mipsel_24kc","lua":"5.1","required_when_enforced":true}}\n'
    info=tarfile.TarInfo('usr/share/schoolbell-editor/dependencies.json');info.mode=0o644;info.size=len(dependency)
    archive.addfile(info,io.BytesIO(dependency))
    for name, source in sorted(files.items()):
        data = source.read_bytes()
        entry = tarfile.TarInfo(name)
        entry.mode = 0o755 if name.startswith(('etc/init.d/', 'usr/sbin/')) else 0o644
        entry.size = len(data)
        archive.addfile(entry, io.BytesIO(data))
print("Payload:", len(files) + 1, "files")
