#!/usr/bin/env python3
"""Selection boundaries, multi-commit pushes, deletions/renames and fail-closed gate."""
import copy
import subprocess
import tempfile
import unittest
from pathlib import Path
from ci_paths import COMPONENTS, changed_paths, select
from ci_gate import errors

class CI(unittest.TestCase):
    def test_selection(self):
        cases = [
            (None, COMPONENTS), ([], ()),
            (['README.md', 'docs/BUILD.md'], ('web',)),
            (['docs/source-map.json'], ()),
            (['ui/root/www/schoolbell-test/app.js'], ('web', 'package')),
            (['ui/root/usr/lib/lua/luci/view/schoolbell_test.htm'], ('web', 'package')),
            (['src/lua/schoolbell/controls.lua'], ('runtime', 'package')),
            (['site/demo.js'], ('web',)),
            (['README.md', 'src/lua/schoolbell/controls.lua'], COMPONENTS),
        ]
        for paths, expected in cases:
            with self.subTest(paths=paths):
                self.assertEqual(select(paths), {x: x in expected for x in COMPONENTS})
        for path in ['Makefile', '.github/workflows/ci.yml', 'scripts/ci_paths.py',
                     'docs/TECHNICAL_SPECIFICATION.md', 'docs/requirements/AUDIO_STATUS.md',
                     'docs/formats/example.md', 'docs/LICENSING.md', 'NOTICE', 'site/LUCI-LICENSE',
                     'assets/melodies/0.mp3', 'packaging/unknown', 'unknown.file']:
            self.assertTrue(all(select([path]).values()), path)

    def test_git_range(self):
        with tempfile.TemporaryDirectory() as tmp:
            def git(*args):
                return subprocess.check_output(['git', *args], cwd=tmp, stderr=subprocess.DEVNULL).decode().strip()
            def commit():
                git('add', '.')
                git('-c', 'user.name=CI', '-c', 'user.email=ci@example.invalid',
                    '-c', 'commit.gpgsign=false', 'commit', '-qm', 'fixture')
                return git('rev-parse', 'HEAD')
            git('init', '-q')
            p = Path(tmp)
            (p/'old name.md').write_text('before')
            before = commit()
            (p/'old name.md').rename(p/'new name.md')
            commit()
            (p/'last.js').write_text('last')
            head = commit()
            self.assertEqual(set(changed_paths(before, head, tmp)),
                             {'old name.md', 'new name.md', 'last.js'})
            self.assertEqual(changed_paths(head, head, tmp), [])
            for missing in [None, '0'*40, 'f'*40, 'invalid']:
                self.assertIsNone(changed_paths(missing, head, tmp))
            self.assertIsNone(changed_paths(before, 'invalid', tmp))

    def test_gate(self):
        good = {'changes': {'result': 'success', 'outputs': {x: 'true' for x in COMPONENTS}},
                'docs': {'result': 'success'}}
        good.update({x: {'result': 'success'} for x in COMPONENTS})
        self.assertEqual(errors(good), [])
        for name in ['changes', 'docs', *COMPONENTS]:
            for result in ['failure', 'cancelled', 'skipped', None]:
                bad = copy.deepcopy(good)
                bad[name]['result'] = result
                self.assertTrue(errors(bad), (name, result))
        for name in COMPONENTS:
            skipped = copy.deepcopy(good)
            skipped['changes']['outputs'][name] = 'false'
            skipped[name]['result'] = 'skipped'
            self.assertEqual(errors(skipped), [])
            for result in ['failure', 'cancelled', None]:
                skipped[name]['result'] = result
                self.assertTrue(errors(skipped))
            bad = copy.deepcopy(good)
            del bad['changes']['outputs'][name]
            self.assertTrue(errors(bad))

if __name__ == '__main__':
    unittest.main()
