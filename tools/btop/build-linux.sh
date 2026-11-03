#!/usr/bin/env bash
# Ubuntu 22.04 amd64: bash, git, curl, make, tar, xz-utils, coreutils.
set -euo pipefail
dest=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cd "$work"
triple=mipsel-unknown-linux-muslsf
upx=upx-5.3.0-amd64_linux
git clone -q --depth 1 --branch v1.4.8 https://github.com/aristocratos/btop.git checkout
test "$(git -C checkout rev-parse HEAD)" = cf1da5900b1e9eaa1c20fd7148dd812b43340b8a
mkdir src
git -C checkout archive HEAD | tar -x -C src
curl -fLsS --retry 2 -o gcc.tar.xz "https://github.com/cross-tools/musl-cross/releases/download/20260430/$triple.tar.xz"
curl -fLsS --retry 2 -o upx.tar.xz "https://github.com/upx/upx/releases/download/v5.3.0/$upx.tar.xz"
sha256sum -c <<'SUMS'
3b5619c84e001a2ec6c6740343072f1d185702c528b5c3de0f5b9a9f351f0359  gcc.tar.xz
79cea8a50b6fa102d10c7b79a419cd77dead3cc2d78661de2dc5e5815dc505c1  upx.tar.xz
SUMS
tar -xJf gcc.tar.xz
tar -xJf upx.tar.xz
export PATH="$work/$triple/bin:$PATH"
make -C src -j3 THREADS=3 STATIC=true STRIP=true GPU_SUPPORT=false PLATFORM=linux ARCH=mipsel \
    CXX="$triple-g++" OPTFLAGS='-Os -flto=3 -ffunction-sections -fdata-sections' \
    ADDFLAGS='-mips32r2 -mtune=24kc -msoft-float -Wl,--gc-sections' LDFLAGS=-latomic
"$upx/upx" --best --lzma -o packed src/bin/btop
"$upx/upx" -t packed

# Package the executable and upstream notices.
archive=btop-1.4.8-openwrt-19.07.9-mipsel_24kc.tar.xz
docs=btop/share/doc/btop
mkdir -p "$docs" btop/bin
install -m 755 packed btop/bin/btop
install -m 644 src/LICENSE "$docs/LICENSE-btop"
install -m 644 src/include/fmt/LICENSE.rst "$docs/LICENSE-fmt.rst"
install -m 644 "$upx/LICENSE" "$docs/LICENSE-upx"
install -m 644 "$upx/COPYING" "$docs/COPYING-upx"
curl -fLsS --max-time 30 --retry 2 https://raw.githubusercontent.com/ifduyue/musl/v1.2.6/COPYRIGHT -o "$docs/COPYRIGHT-musl"
for name in COPYING3 COPYING.RUNTIME; do
    curl -fLsS --retry 2 "https://raw.githubusercontent.com/gcc-mirror/gcc/releases/gcc-15.2.0/$name" -o "$docs/$name"
done
tar --sort=name --owner=0 --group=0 --numeric-owner --mtime=@0 --mode='u+rwX,go+rX,go-w' -cJf "$archive" btop
sha256sum "$archive" > "$archive.sha256"
install -m 644 "$archive" "$archive.sha256" "$dest/"
