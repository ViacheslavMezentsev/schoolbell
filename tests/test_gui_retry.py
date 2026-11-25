"""Repeatable GUI installations; injected transport, no device access."""
import base64
import json
import os
from pathlib import Path
import subprocess
import unittest
from types import SimpleNamespace
from unittest.mock import patch
from test_gui_zip import GuiZipTests
import zip_worker as gui

class RetryTests(GuiZipTests):
    def attempt(self, old=None, fail=False, action='install'):
        self.args.action=action
        calls=[]
        def remote(command, **kw):
            calls.append((command,kw))
            if 'opkg list-installed' in command:
                return SimpleNamespace(stdout=(('modbus-schoolbell - '+old+'\n') if old else '').encode())
            if 'opkg --force-reinstall' in command:
                if fail: raise subprocess.CalledProcessError(255,['ssh'])
                return SimpleNamespace(stdout=b'INSTALL_VERIFIED\n')
            return SimpleNamespace(stdout=b'19.07.9\n')
        self.calls=calls
        return gui.run_retry(self.args,self.root,lambda *_:None,lambda _:remote,
                             lambda *_:dict(host='192.0.2.1'),lambda _:None)
    def test_repeat_same_version_and_unknown_attempt(self):
        (self.folder/'write-started').write_text('old unknown')
        (self.folder/'backup.tar').write_bytes(b'keep backup')
        self.assertEqual(self.attempt('5.1.127'),'done')
        self.assertEqual(self.attempt('5.1.127'),'done')
        self.assertEqual(len(list((self.folder/'attempts').glob('*/verified.json'))),2)
        self.assertEqual((self.folder/'backup.tar').read_bytes(),b'keep backup')
        self.assertEqual((self.folder/'write-started').read_text(),'old unknown')
    def test_failure_then_retry_without_new_session(self):
        with self.assertRaises(subprocess.CalledProcessError): self.attempt(fail=True)
        self.assertEqual(self.attempt(),'done')
        self.assertEqual(len(list((self.folder/'attempts').glob('*/write-started'))),2)
        self.assertEqual(len(list((self.folder/'attempts').glob('*/verified.json'))),1)
    def test_upgrade_downgrade_and_nonsemantic_version(self):
        for old in ('5.1.124','6.0.0','5.1.127-1'):
            self.assertEqual(self.attempt(old),'done')
            cmd=next(c for c,k in self.calls if 'opkg --force-reinstall' in c)
            self.assertIn('--force-downgrade',cmd)
            self.assertIn('preserved.sha256',cmd)
            subprocess.run(['sh','-n'],input=cmd.encode(),check=True)
    def test_only_missing_dependencies_and_project_reinstalled(self):
        rows=[dict(name=n,version='1') for n in ('libc','luci','modbus-schoolbell','modbus-schoolbell-clock')]
        self.assertEqual([r['name'] for r in gui.install_rows(rows,{'libc':'other','modbus-schoolbell':'1'})],
                         ['luci','modbus-schoolbell','modbus-schoolbell-clock'])
    def test_optional_check_does_not_write(self):
        self.assertEqual(self.attempt(action='prepare'),'ready')
        self.assertFalse((self.folder/'attempts').exists())
        self.assertFalse(any('opkg --force' in c for c,k in self.calls))
    def test_damaged_zip_no_connection(self):
        self.tx.archive.write_bytes(b'bad')
        with patch.object(gui,'ensure_host') as trust:
            with self.assertRaises(Exception): self.attempt()
            trust.assert_not_called()
    def test_host_rotation_requires_exact_confirmation(self):
        line='192.168.1.1 ssh-rsa '+base64.b64encode(b'key-one').decode()
        scan=SimpleNamespace(stdout=(line+'\n').encode())
        known=Path(os.environ['LOCALAPPDATA'])/'SchoolbellSetup/known_hosts'
        known.write_text('192.0.2.4 ssh-rsa other\n192.168.1.1 ssh-rsa old\n')
        with patch('subprocess.run',return_value=scan):
            with self.assertRaises(ValueError):gui.ensure_host(self.args,self.folder,lambda _:None)
            key=json.loads((self.folder/'pending-host.json').read_text())['fingerprint']
            self.args.trusted_host_key='wrong'
            with self.assertRaises(ValueError):gui.ensure_host(self.args,self.folder,lambda _:None)
            self.args.trusted_host_key=key
            gui.ensure_host(self.args,self.folder,lambda _:None)
        self.assertIn('192.0.2.4 ssh-rsa other',known.read_text())
        self.assertIn(line,known.read_text());self.assertNotIn('ssh-rsa old',known.read_text())
        self.assertFalse((self.folder/'pending-host.json').exists())

if __name__=='__main__': unittest.main()
