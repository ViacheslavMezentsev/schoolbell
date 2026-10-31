#!/bin/sh
# Read-only identity/integrity check, not an installer or full space admission.
set -eu
cd "$(dirname "$0")"
sha256sum -c SHA256SUMS
. /etc/openwrt_release
[ "$DISTRIB_RELEASE" = 19.07.9 ] && [ "$DISTRIB_TARGET" = ramips/mt76x8 ] || {
    echo 'Wrong OpenWrt release/target' >&2; exit 1;
}
[ "$(opkg status kernel | sed -n 's/^Version: //p')" = 4.14.267-1-d92769dc5268e102503ae83fe968a56c ] || {
    echo 'Kernel ABI mismatch; do not force kmod installation' >&2; exit 1;
}
[ "$(opkg status libc | sed -n 's/^Version: //p')" = 1.1.24-2 ] || exit 1
opkg print-architecture | grep -q '^arch mipsel_24kc ' || exit 1
df -k /overlay /tmp
printf '%s\n' 'Identity and hashes OK. Review incremental disk/RAM needs, existing dependencies and rollback before installation. No packages installed.'
