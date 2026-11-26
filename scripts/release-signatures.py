#!/usr/bin/env python3
"""Sign/verify release checksums using the existing SSH key; never uploads files."""
import argparse
import hashlib
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PUBLIC_KEY = ROOT / 'packaging/release/signing-key.pub'
NAMESPACE = 'schoolbell-release'
IDENTITY = 'schoolbell-release'


def checked_sums(directory):
    directory = Path(directory)
    sums = directory / 'SHA256SUMS'
    if sums.is_symlink() or not sums.is_file():
        raise ValueError('Missing or linked SHA256SUMS')
    data = sums.read_bytes()
    if not data or len(data) > 65536:
        raise ValueError('Invalid checksum list size')
    seen = set()
    for line in data.decode('ascii').splitlines():
        match = re.fullmatch(r'([0-9a-f]{64})  ([A-Za-z0-9][A-Za-z0-9._-]*)', line)
        if not match:
            raise ValueError('Invalid checksum entry')
        digest, name = match.groups()
        if name in seen or name in ('SHA256SUMS', 'SHA256SUMS.sig'):
            raise ValueError('Duplicate or self-referencing checksum entry')
        seen.add(name)
        path = directory / name
        if path.is_symlink() or not path.is_file():
            raise ValueError('Missing or linked asset: ' + name)
        actual = hashlib.sha256()
        with path.open('rb') as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b''):
                actual.update(block)
        if actual.hexdigest() != digest:
            raise ValueError('Checksum mismatch: ' + name)
    return data


def public_key(path):
    fields = Path(path).read_text(encoding='ascii').split()
    if len(fields) < 2 or fields[0] != 'ssh-ed25519' or not re.fullmatch(r'[A-Za-z0-9+/=]+', fields[1]):
        raise ValueError('Expected an Ed25519 public key')
    return ' '.join(fields[:2])


def verify(directory, trusted_key=PUBLIC_KEY, keygen='ssh-keygen'):
    directory = Path(directory)
    data = checked_sums(directory)
    signature = directory / 'SHA256SUMS.sig'
    if signature.is_symlink() or not signature.is_file():
        raise ValueError('Missing or linked signature')
    with tempfile.TemporaryDirectory(prefix='schoolbell-signature-') as temp:
        allowed = Path(temp) / 'allowed-signers'
        allowed.write_text(IDENTITY + ' namespaces="' + NAMESPACE + '" ' + public_key(trusted_key) + '\n', encoding='ascii')
        subprocess.run([keygen, '-Y', 'verify', '-f', str(allowed), '-I', IDENTITY,
                        '-n', NAMESPACE, '-s', str(signature)], input=data, check=True)
    print('RELEASE VERIFIED: signature and every listed asset match.')


def sign(directory, signing_key, keygen='ssh-keygen'):
    directory = Path(directory)
    # Pass only the public key to ssh-keygen; the existing agent supplies signing.
    if not str(signing_key).endswith('.pub') or public_key(signing_key) != public_key(PUBLIC_KEY):
        raise ValueError('Signing key must match the pinned public key (.pub)')
    data = checked_sums(directory)
    signature = directory / 'SHA256SUMS.sig'
    if signature.exists() or signature.is_symlink():
        raise ValueError('Signature already exists; do not replace published signatures')
    result = subprocess.run([keygen, '-Y', 'sign', '-f', str(signing_key), '-n', NAMESPACE],
                            input=data, stdout=subprocess.PIPE, check=True)
    if not result.stdout.startswith(b'-----BEGIN SSH SIGNATURE-----'):
        raise ValueError('No SSH signature returned')
    with signature.open('xb') as stream:
        stream.write(result.stdout)
    verify(directory, keygen=keygen)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('sign', 'verify'))
    parser.add_argument('--directory', required=True, type=Path)
    parser.add_argument('--signing-key', type=Path)
    parser.add_argument('--ssh-keygen', default='ssh-keygen')
    args = parser.parse_args()
    if args.action == 'sign':
        if not args.signing_key:
            parser.error('--signing-key is required for sign')
        sign(args.directory, args.signing_key, args.ssh_keygen)
    else:
        verify(args.directory, keygen=args.ssh_keygen)
