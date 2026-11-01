#!/usr/bin/env python3
"""Conservative component selection. Unknown/missing Git history means full CI."""
import json
import os
from pathlib import Path
import re
import subprocess

COMPONENTS = ('runtime', 'web', 'package')


def select(paths):
    selected = set()
    if paths is None:
        return dict.fromkeys(COMPONENTS, True)
    for path in paths:
        # Only explicitly understood paths may omit a test suite.
        if path == 'docs/source-map.json':
            pass  # Always validated by check-docs.
        elif path.startswith(('docs/requirements/', 'docs/formats/', 'docs/architecture/', 'docs/acceptance/')):
            selected.update(COMPONENTS)
        elif path.startswith('docs/') and path.endswith('.md') and not any(
                word in path.upper() for word in ('SPEC', 'LICENS', 'NOTICE', 'DEPENDENC')):
            selected.add('web')
        elif path in ('README.md', 'README.en.md', 'CHANGELOG.md', 'CHANGELOG.en.md', 'TODO.md'):
            selected.add('web')
        elif path in ('site/LUCI-LICENSE', 'site/portable-zones.NOTICE'):
            selected.update(COMPONENTS)
        elif path.startswith('site/'):
            selected.add('web')
        elif path.startswith('ui/') and path.endswith(('.js', '.css', '.htm')):
            selected.update(('web', 'package'))
        elif path.startswith('scripts/test-schoolbell-') and path.endswith('.js'):
            selected.add('web')
        elif path.startswith('src/lua/') or (path.startswith('tests/') and path.endswith(('.lua', '.c', '.sh'))):
            selected.update(('runtime', 'package'))
        else:
            # Contracts, licensing, build/CI scripts, mixed and unknown paths.
            selected.update(COMPONENTS)
    return {name: name in selected for name in COMPONENTS}


def changed_paths(before, head, cwd=None):
    if not re.fullmatch(r'[0-9a-fA-F]{40}', before or '') or set(before) == {'0'}:
        return None
    if not re.fullmatch(r'[0-9a-fA-F]{40}', head or ''):
        return None
    try:
        subprocess.run(['git', 'cat-file', '-e', before + '^{commit}'], cwd=cwd,
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        data = subprocess.check_output(['git', 'diff', '--name-only', '-z', '--no-renames',
                                        before, head, '--'], cwd=cwd)
        return [x.decode('utf-8', 'surrogateescape') for x in data.split(b'\0') if x]
    except subprocess.CalledProcessError:
        return None


def main():
    event = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text())
    paths = changed_paths(event.get('before'), os.environ.get('GITHUB_SHA'))
    if paths is not None:
        subprocess.run(['git', 'diff', '--check', event['before'], os.environ['GITHUB_SHA'], '--'], check=True)
    else:
        subprocess.run(['git', 'show', '--format=', '--check', 'HEAD'], check=True)
    plan = select(paths)
    print(json.dumps({'full_fallback': paths is None, 'paths': paths, 'jobs': plan}, ensure_ascii=True))
    with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
        for name, enabled in plan.items():
            output.write(name + '=' + str(enabled).lower() + '\n')


if __name__ == '__main__':
    main()
