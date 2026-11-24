#!/bin/sh
# Read-only input for the HOST planner. No bundle/packages need to be on the router.
set -eu
export LC_ALL=C
test "$(id -u)" = 0
. /etc/openwrt_release
printf 'format\t1\nboard\t%s\nopenwrt\t%s\ntarget\t%s\narchitecture\t%s\n' "$(cat /tmp/sysinfo/board_name)" "$DISTRIB_RELEASE" "$DISTRIB_TARGET" "$DISTRIB_ARCH"
printf 'overlay_kib\t%s\ntmp_kib\t%s\n' "$(df -k /overlay | awk 'END {print $4}')" "$(df -k /tmp | awk 'END {print $4}')"
pending=0; test ! -e /etc/schoolbell-editor/package.pending || pending=1
data=0; if test -e /etc/schoolbell-editor || test -e /etc/modbus-schoolbell; then data=1; fi
printf 'pending\t%s\ndata\t%s\n' "$pending" "$data"
version=$(opkg status modbus-schoolbell | sed -n 's/^Version: //p')
if test -n "$version"; then
    lua - <<'LUA'
package.path='/usr/share/schoolbell-editor/lua/?.lua;'..package.path
local a=require('schoolbell.automatic_store')
assert(not a.decode(a.raw()).enabled, 'Automatic bells must be off')
LUA
fi
printf 'automatic\toff\n'
# A failed opkg must not be hidden by a successful awk in a pipeline.
inventory=$(opkg list-installed)
printf '%s\n' "$inventory" | awk -F ' - ' 'NF != 2 {exit 1} {printf "package\t%s\t%s\n",$1,$2}'
printf 'complete\t1\n'
