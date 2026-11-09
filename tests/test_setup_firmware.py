"""Offline setup profile and package tests; never contact a device."""
import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/setup'))
import firmware
import build
import tftp_server
import build_recovery
import hashlib

class Recovery(unittest.TestCase):
    def test_unknown_source_rejected(self):
        for data in (b'', b'wrong firmware', bytes(firmware.RECOVERY_BYTES + 512)):
            with self.assertRaises(ValueError): firmware.prepare_oem(data)

    def test_layout_preserves_inner_payload(self):
        inner = bytes(range(256)) * (0x7a0000 // 256)
        source = b'H' * 512 + b'B' * 0x20000 + inner
        expected = bytes(0x20000) + inner
        with patch.object(firmware, 'OEM_SOURCE_SHA', firmware.sha256(source)), patch.object(firmware, 'OEM_RECOVERY_SHA', firmware.sha256(expected)):
            self.assertEqual(firmware.prepare_oem(source), expected)
            with self.assertRaises(ValueError): firmware.prepare_oem(source[:-1])
            with self.assertRaises(ValueError): firmware.prepare_oem(source[:512] + b'X' + source[513:])
        with patch.object(firmware, 'OEM_SOURCE_SHA', firmware.sha256(source)):
            with self.assertRaises(ValueError): firmware.prepare_oem(source)

    def test_profile_isolation_and_corruption(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); (root/'firmware').mkdir()
            data=bytes(firmware.RECOVERY_BYTES)
            profiles={'openwrt':('tp_recovery.bin',firmware.sha256(data),'OpenWrt'), 'factory':('oem-recovery.bin',firmware.sha256(data),'OEM')}
            (root/'firmware/tp_recovery.bin').write_bytes(data)
            with patch.dict(firmware.PROFILES, profiles, clear=True):
                self.assertEqual(firmware.load_payload(root,'openwrt')[1],'OpenWrt')
                with self.assertRaises(FileNotFoundError): firmware.load_payload(root,'factory')
                (root/'firmware/oem-recovery.bin').write_bytes(data[:-1])
                with self.assertRaises(ValueError): firmware.load_payload(root,'factory')
                (root/'firmware/oem-recovery.bin').write_bytes(b'X'+data[1:])
                with self.assertRaises(ValueError): firmware.load_payload(root,'factory')

    def test_builder_optional_factory_and_checksums(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp);bundle=p/'bundle';bundle.mkdir()
            rows=[]
            for i in range(35):
                name=['modbus-schoolbell','modbus-schoolbell-clock'][i] if i<2 else 'dependency-'+str(i)
                version=['5.1.100','1.0.0'][i] if i<2 else '1'
                file=name+'.ipk';(bundle/file).write_bytes(name.encode())
                rows.append({'name':name,'version':version,'file':file,'sha256':build.digest(bundle/file)})
            (bundle/'manifest.json').write_text(json.dumps({'packages':rows}))
            image=p/'openwrt.bin';image.write_bytes(b'fixture image')
            runtime=p/'runtime.zip'
            with zipfile.ZipFile(runtime,'w') as z:z.writestr('python.exe',b'fixture runtime')
            oem=p/'oem.bin';oem.write_bytes(b'fixture source')
            with patch.object(build,'IMAGE_SHA',build.digest(image)),patch.object(build,'PYTHON_SHA',build.digest(runtime)),patch.object(build,'prepare_oem',return_value=b'fixture recovery') as prepare:
                for enabled in (False,True):
                    dest=p/str(enabled);build.build(bundle,image,runtime,dest,oem if enabled else None)
                    with zipfile.ZipFile(next(dest.glob('*.zip'))) as z:
                        prefix=build.NAME+'/'
                        self.assertEqual(prefix+'firmware/oem-recovery.bin' in z.namelist(),enabled)
                        self.assertIn(prefix+'firmware.py',z.namelist())
                        for line in z.read(prefix+'SHA256SUMS').decode().splitlines():
                            digest,name=line.split('  ',1)
                            self.assertEqual(firmware.sha256(z.read(prefix+name)),digest)
                prepare.assert_called_once_with(b'fixture source')

    def test_archived_inputs_and_offline_recovery_kit(self):
        vendor = ROOT / 'tools/setup/vendor'
        manifest = json.loads((vendor / 'manifest.json').read_text())
        for row in manifest['artifacts']:
            data = (vendor / row['file']).read_bytes()
            self.assertEqual(len(data), row['bytes'])
            self.assertEqual(hashlib.sha256(data).hexdigest(), row['sha256'])
        for name in ('tp-link-mr3020-v3.30-en.html', 'tp-link-mr3020-v3.30-ru-kz.html'):
            page = (vendor / name).read_text()
            self.assertIn('TL-MR3020(EU)_V3.30_250625', page)
            self.assertIn('TL-MR3020_3.0_1.7.0', page)
        with tempfile.TemporaryDirectory() as tmp:
            dest = Path(tmp)
            build_recovery.build(dest)
            with zipfile.ZipFile(dest / (build_recovery.NAME + '.zip')) as z:
                prefix = build_recovery.NAME + '/'
                self.assertEqual(hashlib.sha256(z.read(prefix + 'firmware/oem-recovery.bin')).hexdigest(), firmware.OEM_RECOVERY_SHA)
                self.assertNotIn(prefix + 'install.py', z.namelist())
                self.assertIn('-RestoreFactory', z.read(prefix + 'Recovery.cmd').decode())
                self.assertIn('..', z.read(prefix + 'python/python311._pth').decode().splitlines())
                self.assertIn(prefix + 'python/LICENSE.txt', z.namelist())
                for line in z.read(prefix + 'SHA256SUMS').decode().splitlines():
                    digest, name = line.split('  ', 1)
                    self.assertEqual(hashlib.sha256(z.read(prefix + name)).hexdigest(), digest)

    def test_recovery_archive_corruption_rejected_before_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'python-3.11.9-embed-amd64.zip').write_bytes(b'corrupt')
            with self.assertRaises(ValueError):
                build_recovery.build(root / 'output', vendor=root)
            self.assertFalse((root / 'output').exists())

    def test_check_mode_never_binds_socket(self):
        for profile in ('openwrt','factory'):
            with patch.object(sys,'argv',['tftp_server.py','--profile',profile,'--check']),patch.object(tftp_server,'load_payload',return_value=(b'fixture',profile)),patch.object(tftp_server.socket,'socket',side_effect=AssertionError('network forbidden')):
                tftp_server.main()
        with patch.object(sys,'argv',['tftp_server.py','--profile','factory']),patch.object(tftp_server,'load_payload',side_effect=ValueError('bad image')),patch.object(tftp_server.socket,'socket',side_effect=AssertionError('network forbidden')):
            with self.assertRaises(ValueError): tftp_server.main()

if __name__=='__main__': unittest.main()
