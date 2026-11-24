"""GUI ZIP routing with fake transport only; no devices."""
import json
import os
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import test_zip_install as transactions
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/setup/gui'))
import zip_worker as gui

class GuiZipTests(unittest.TestCase):
    def setUp(self):
        self.tx=transactions.TransactionTests();self.tx.setUp();self.addCleanup(self.tx.doCleanups)
        self.root=self.tx.root/'runtime';self.root.mkdir()
        (self.root/'wizard-version.txt').write_text('0.2.0')
        (self.root/'firmware').mkdir();(self.root/'firmware/tp_recovery.bin').write_bytes(self.tx.image.read_bytes())
        known=self.tx.root/'appdata/SchoolbellSetup/known_hosts';known.parent.mkdir(parents=True);known.write_text('test trust')
        env=patch.dict(os.environ,{'LOCALAPPDATA':str(known.parent.parent)});env.start();self.addCleanup(env.stop)
        self.folder=self.tx.root/'gui-session';self.folder.mkdir()
        self.args=SimpleNamespace(action='inspect-zip',zip=str(self.tx.archive),source='192.0.2.2',index=7,session=str(self.folder))
        self.routes=[]
    def run_action(self,action):
        self.args.action=action
        gui.run_core(self.args,self.root,lambda source,index:self.routes.append((source,index)),lambda conn:self.tx.remote,lambda _:None)
    def prepare(self):self.run_action('inspect-zip');self.run_action('prepare')
    def test_inspection_is_offline_and_checks_version(self):
        self.run_action('inspect-zip');self.assertEqual(self.routes,[]);self.assertEqual(self.tx.calls,[])
        selected=json.loads((self.folder/'zip-selection.json').read_bytes());self.assertEqual(selected['version'],'5.1.127')
        with self.assertRaises(ValueError):gui.inspect(self.tx.archive,'0.1.0')
    def test_prepare_install_verify_and_archive(self):
        self.prepare();self.assertTrue((self.folder/'zip-session/session.json').is_file())
        self.assertTrue(self.routes);self.assertEqual(self.tx.writes,0)
        self.run_action('install');self.assertEqual(self.tx.writes,1)
        self.run_action('verify');gui.archive_allowed(self.folder)
        self.assertTrue((self.folder/'zip-session/verified.json').is_file())
        with self.assertRaises(ValueError):self.run_action('install')
    def test_changed_zip_refused_before_route(self):
        self.run_action('inspect-zip');self.tx.archive.write_bytes(b'changed')
        with self.assertRaises(ValueError):self.run_action('prepare')
        self.assertEqual(self.routes,[]);self.assertEqual(self.tx.calls,[])
    def test_pinned_zip_survives_source_removal(self):
        self.prepare();self.tx.archive.unlink();self.run_action('install')
        self.assertEqual(self.tx.writes,1)
    def test_selection_and_prepare_locked(self):
        self.prepare()
        for action in ('inspect-zip','prepare'):
            with self.assertRaises(ValueError):self.run_action(action)
    def test_failed_verify_invalidates_archive_permission(self):
        self.prepare();self.run_action('install');self.args.index=9
        with self.assertRaises(ValueError):self.run_action('verify')
        self.assertFalse((self.folder/'zip-session/verified.json').exists())
        with self.assertRaises(FileNotFoundError):gui.archive_allowed(self.folder)
    def test_legacy_session_not_reused(self):
        (self.folder/'prepared.json').write_text('{}')
        with self.assertRaises(ValueError):self.run_action('inspect-zip')
        self.assertEqual(self.tx.calls,[])

if __name__=='__main__':unittest.main()
