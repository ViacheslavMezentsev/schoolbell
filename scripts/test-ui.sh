#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
for script in scripts/test-schoolbell-*.js; do node "$script"; done
node scripts/test-site-portable.js
