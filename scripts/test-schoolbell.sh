#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
command -v lua5.1 >/dev/null
cd "$ROOT"
lua5.1 tests/test_json_strict.lua
lua5.1 tests/test_calendar.lua
lua5.1 tests/test_sparse_plan.lua
python3 tests/test_calendar_dates.py "$(command -v lua5.1)"
lua5.1 tests/test_playback_queue.lua
lua5.1 tests/test_player_model.lua
sh tests/test-linux-player.sh
sh tests/test-lua-player.sh

sh tests/test-media-manager.sh

lua5.1 tests/test_sound_test.lua
lua5.1 tests/test_audio_output.lua
lua5.1 tests/test_session_http.lua
node scripts/test-schoolbell-session-ui.js

python3 tests/test_offline_bundle.py
python3 tests/test_target_cache.py

lua5.1 tests/test_row_play_http.lua

lua5.1 tests/test_system_actions.lua
lua5.1 tests/test_system_reset.lua
lua5.1 tests/test_system_http.lua
lua5.1 tests/test_system_ports.lua

lua5.1 tests/test_bell_metrics.lua
lua5.1 tests/test_metrics_http.lua
