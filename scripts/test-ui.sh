#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
for script in scripts/test-schoolbell-*.js; do node "$script"; done
node scripts/test-site-portable.js

# Pure model shared with the setup QML prototype; no Qt or device required.
node tools/setup/gui/test-flow.cjs
node tools/setup/gui/test-state.cjs

python3 tools/setup/gui/test-package-worker.py
python3 tools/setup/gui/test-fresh-install.py
python3 tools/setup/gui/test-device-backup.py

python3 tests/test_release_bundle.py

python3 tests/test_release_plan.py

python3 tests/test_zip_install.py
