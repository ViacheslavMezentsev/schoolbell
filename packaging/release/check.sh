#!/bin/sh
# Read-only bundle/device checks. No install, feed refresh or setting changes.
set -eu
cd "$(dirname "$0")/.."
sha256sum -c SHA256SUMS
. /etc/openwrt_release
test "$(id -u)" = 0
test "$(cat /tmp/sysinfo/board_name)" = tplink,tl-mr3020-v3
test "$DISTRIB_RELEASE:$DISTRIB_TARGET:$DISTRIB_ARCH" = 19.07.9:ramips/mt76x8:mipsel_24kc
test "$(opkg status kernel | sed -n 's/^Version: //p')" = 4.14.267-1-d92769dc5268e102503ae83fe968a56c
test "$(opkg status libc | sed -n 's/^Version: //p')" = 1.1.24-2
test ! -e /etc/schoolbell-editor/package.pending
printf '\nInstalled packages / Current inventory:\n'
opkg list-installed
df -k /overlay /tmp
printf '\nCHECK OK: identity and integrity only; no installation or space admission.\n'
