#!/bin/sh
set -eu
ulimit -c 0
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
CC=${CC:-cc}
command -v "$CC" >/dev/null
command -v timeout >/dev/null
build=$(mktemp -d /tmp/schoolbell-player.XXXXXX)
trap 'rm -rf "$build"' EXIT HUP INT TERM
"$CC" -std=c99 -O2 -Wall -Wextra -Werror -pedantic     "$ROOT/tests/player_child.c" -o "$build/child"
"$CC" -std=c99 -O2 -Wall -Wextra -Werror -pedantic     -I"$ROOT/src/native"     "$ROOT/src/native/player.c"     "$ROOT/tests/test_linux_player.c" -o "$build/host"
timeout 25s "$build/host" "$build/child" "$build"

"$CC" -std=c99 -O2 -Wall -Wextra -Werror -pedantic     -I"$ROOT/src/native"     "$ROOT/src/native/player.c"     "$ROOT/tests/test_linux_player_faults.c"     -Wl,--wrap=getrandom -Wl,--wrap=pipe2 -Wl,--wrap=fork     -Wl,--wrap=clock_gettime -Wl,--wrap=read -Wl,--wrap=waitpid     -Wl,--wrap=close -o "$build/faults"
timeout 20s "$build/faults" "$build/child" "$build"
