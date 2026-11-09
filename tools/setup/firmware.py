"""Pinned recovery profiles. No generic OEM stripping or network access."""
import hashlib

OPENWRT_SHA = 'e621da95d07d25102b1016a28400122f5c92bce9830d5cc061323e306b6204fa'
OEM_SOURCE_SHA = '1141467bd4b7b8292e2a50811a388eb999f4cbf207365e1be47718ebc6143d2f'
OEM_RECOVERY_SHA = '2b0d85b1c7f5e6c65930e117ada0afe60a29a35882ecac65610191876b6b0665'
RECOVERY_BYTES = 0x7c0000
PROFILES = {
    'openwrt': ('tp_recovery.bin', OPENWRT_SHA, 'OpenWrt 19.07.9'),
    'factory': ('oem-recovery.bin', OEM_RECOVERY_SHA, 'TP-Link EU v3.30 Build250625'),
}

def sha256(data):
    return hashlib.sha256(data).hexdigest()

def prepare_oem(data):
    """Only the accepted Build250625: zero prefix + unchanged inner image."""
    if len(data) != RECOVERY_BYTES + 0x200 or sha256(data) != OEM_SOURCE_SHA:
        raise ValueError('Unsupported OEM input: expected original EU Build250625 SHA256')
    result = bytes(0x20000) + data[0x20200:]
    if len(result) != RECOVERY_BYTES or sha256(result) != OEM_RECOVERY_SHA:
        raise ValueError('OEM recovery layout/hash mismatch')
    return result

def load_payload(root, profile):
    name, expected, label = PROFILES[profile]
    payload = (root / 'firmware' / name).read_bytes()
    if len(payload) != RECOVERY_BYTES or sha256(payload) != expected:
        raise ValueError('Recovery image size/hash mismatch: ' + label)
    return payload, label
