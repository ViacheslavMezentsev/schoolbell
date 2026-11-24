#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
for script in scripts/test-schoolbell-*.js; do node "$script"; done
node scripts/test-site-portable.js

python3 tools/setup/gui/test-package-worker.py
python3 tools/setup/gui/test-fresh-install.py
python3 tools/setup/gui/test-device-backup.py

python3 tests/test_release_bundle.py

python3 tests/test_release_plan.py

python3 tests/test_zip_install.py

python3 tests/test_gui_zip.py

python3 tools/setup/gui/test-operation-protocol.py
python3 tools/setup/gui/test-session-recovery.py
