#!/bin/sh
# Read-only post-install checks. Run only on the intended router.
set -eu
cd "$(dirname "$0")/.."
sh scripts/check.sh
while IFS="$(printf '\t')" read -r name expected file; do
 actual=$(opkg status "$name" | sed -n 's/^Version: //p')
 if [ "$actual" != "$expected" ]; then
  case "$name:$actual" in
   luci-base:git-22.045.73925-36e5c1c-1|luci-lib-ip:git-22.045.73925-36e5c1c-1|luci-lib-jsonc:git-22.045.73925-36e5c1c-1|luci-lib-nixio:git-22.045.73925-36e5c1c-1|luci-theme-bootstrap:git-22.045.73925-36e5c1c-1|libubus-lua:2021-07-01-38c7fdd8-1|libubus20210603:2021-07-01-38c7fdd8-1) ;;
   *) echo "Version mismatch: $name ($actual; expected $expected)" >&2; exit 1 ;;
  esac
 fi
done < packages.tsv
lua -e 'package.path="/usr/share/schoolbell-editor/lua/?.lua;"..package.path;local s=require("schoolbell.automatic_store");assert(not s.decode(s.raw()).enabled)'
/etc/init.d/schoolbell-auto running
/etc/init.d/uhttpd running
printf '\nVERIFY OK: package versions, services and automatic bells off. Sound output was not tested.\n'
