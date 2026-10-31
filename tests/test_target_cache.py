#!/usr/bin/env python3
"""No-network tests for pinned target build inputs."""
import hashlib
import importlib.util
import io
from pathlib import Path
import sys
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
spec = importlib.util.spec_from_file_location('target', ROOT / 'scripts/build-target.py')
target = importlib.util.module_from_spec(spec)
spec.loader.exec_module(target)


def rejects(call):
    try:
        call()
    except ValueError:
        return
    raise AssertionError('expected refusal')


with tempfile.TemporaryDirectory() as directory:
    cache = Path(directory)
    data = b'verified archive fixture'
    item = {'file': 'sdk.tar.xz', 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(), 'url': 'https://invalid.example/sdk'}
    with patch.object(target.urllib.request, 'urlopen', side_effect=AssertionError('network forbidden')):
        rejects(lambda: target.verified_cache(cache, item))
        (cache / item['file']).write_bytes(data)
        assert target.verified_cache(cache, item).read_bytes() == data
        (cache / item['file']).write_bytes(b'x' * len(data))
        rejects(lambda: target.verified_cache(cache, item, True))
    (cache / item['file']).unlink()
    for bad in (data[:-1], data + b'excess', b'x' * len(data)):
        with patch.object(target.urllib.request, 'urlopen', return_value=io.BytesIO(bad)):
            rejects(lambda: target.verified_cache(cache, item, True))
        assert not list(cache.iterdir()), 'partial input leaked'
    with patch.object(target.urllib.request, 'urlopen', side_effect=OSError('interrupted')):
        try:
            target.verified_cache(cache, item, True)
        except OSError:
            pass
        else:
            raise AssertionError('expected failure')
    assert not list(cache.iterdir())
    with patch.object(target.urllib.request, 'urlopen', return_value=io.BytesIO(data)):
        assert target.verified_cache(cache, item, True).read_bytes() == data
print('PASS pinned target cache: offline, missing, corrupt, truncated, oversized, interrupted and successful download')
