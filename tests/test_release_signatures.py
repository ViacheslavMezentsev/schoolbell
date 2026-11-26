import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('signatures', Path(__file__).resolve().parents[1] / 'scripts/release-signatures.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class Signatures(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'asset.zip').write_bytes(b'fixture')
        self.line = hashlib.sha256(b'fixture').hexdigest() + '  asset.zip\n'
        (self.root / 'SHA256SUMS').write_text(self.line)

    def test_valid_bytes(self):
        self.assertEqual(module.checked_sums(self.root), self.line.encode())

    def test_reject_damaged_or_missing_asset(self):
        (self.root / 'asset.zip').write_bytes(b'damaged')
        with self.assertRaises(ValueError): module.checked_sums(self.root)
        (self.root / 'asset.zip').unlink()
        with self.assertRaises(ValueError): module.checked_sums(self.root)

    def test_reject_bad_lists(self):
        for text in ('', self.line * 2, self.line.replace('asset.zip', '../asset.zip'),
                     self.line.replace('asset.zip', 'C:\\asset.zip'), self.line.replace('asset.zip', 'SHA256SUMS')):
            (self.root / 'SHA256SUMS').write_text(text)
            with self.assertRaises(ValueError): module.checked_sums(self.root)

    def test_missing_signature_does_not_call_verifier(self):
        with patch.object(module.subprocess, 'run') as run:
            with self.assertRaises(ValueError): module.verify(self.root)
            run.assert_not_called()

    def test_verifier_binds_namespace_key_and_exact_bytes(self):
        (self.root / 'SHA256SUMS.sig').write_bytes(b'fixture signature')
        def check(args, **kwargs):
            self.assertEqual(kwargs['input'], self.line.encode())
            self.assertEqual(args[args.index('-n') + 1], 'schoolbell-release')
            self.assertIn(module.public_key(module.PUBLIC_KEY), Path(args[args.index('-f') + 1]).read_text())
            self.assertTrue(kwargs['check'])
        with patch.object(module.subprocess, 'run', side_effect=check): module.verify(self.root)

    def test_no_signature_replacement(self):
        (self.root / 'SHA256SUMS.sig').write_bytes(b'existing')
        with self.assertRaises(ValueError): module.sign(self.root, module.PUBLIC_KEY)
        self.assertEqual((self.root / 'SHA256SUMS.sig').read_bytes(), b'existing')


if __name__ == '__main__': unittest.main()
