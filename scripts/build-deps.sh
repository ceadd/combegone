#!/usr/bin/env bash
# Builds self-contained (static) arm64 copies of ffmpeg, ffprobe and comskip
# into vendor/bin. Developer-only: people using combegone.app never run this.
set -euo pipefail

FFMPEG_VERSION="6.1.2"
ARGTABLE_VERSION="2-13"
COMSKIP_COMMIT="${COMSKIP_COMMIT:-a140b6ac8bc8f596729e9052819affc779c3b377}"  # 0.83.001, 2025-04-18
MIN_MACOS="14.0"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/build/deps"
SRC="$WORK/src"
PREFIX="$WORK/prefix"
OUT="$ROOT/vendor/bin"
JOBS="$(sysctl -n hw.ncpu)"

export MACOSX_DEPLOYMENT_TARGET="$MIN_MACOS"
export CC=clang
export CFLAGS="-arch arm64 -mmacosx-version-min=$MIN_MACOS -O2"
export LDFLAGS="-arch arm64 -mmacosx-version-min=$MIN_MACOS"
# Only ever look at our own prefix, never Homebrew's libraries.
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"
unset PKG_CONFIG_PATH
# argtable2 and comskip are older C; modern clang treats these as errors.
OLD_C="-include ctype.h -Wno-implicit-function-declaration -Wno-int-conversion -Wno-incompatible-pointer-types -Wno-implicit-int"

mkdir -p "$SRC" "$PREFIX" "$OUT"

fetch() { # url dest
  if [[ ! -f "$2" ]]; then
    curl -fL --retry 3 -o "$2.part" "$1"
    mv -f "$2.part" "$2"
  fi
}

# ---------- argtable2 ----------
if [[ ! -f "$PREFIX/lib/libargtable2.a" ]]; then
  echo "==> argtable2"
  fetch "https://downloads.sourceforge.net/project/argtable/argtable/argtable-2.13/argtable${ARGTABLE_VERSION}.tar.gz" "$SRC/argtable.tar.gz"
  rm -rf "$SRC/argtable${ARGTABLE_VERSION}"
  tar -xzf "$SRC/argtable.tar.gz" -C "$SRC"
  (cd "$SRC/argtable${ARGTABLE_VERSION}" &&
    CFLAGS="$CFLAGS $OLD_C" ./configure --prefix="$PREFIX" --disable-shared --enable-static --disable-dependency-tracking &&
    make -j"$JOBS" -C src && make -C src install &&
    mkdir -p "$PREFIX/lib/pkgconfig" && cp argtable2.pc "$PREFIX/lib/pkgconfig/")
fi

# ---------- ffmpeg ----------
if [[ ! -f "$PREFIX/bin/ffmpeg" ]]; then
  echo "==> ffmpeg $FFMPEG_VERSION"
  fetch "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz" "$SRC/ffmpeg.tar.xz"
  rm -rf "$SRC/ffmpeg-${FFMPEG_VERSION}"
  tar -xJf "$SRC/ffmpeg.tar.xz" -C "$SRC"
  (cd "$SRC/ffmpeg-${FFMPEG_VERSION}" &&
    ./configure --prefix="$PREFIX" \
      --arch=arm64 --cc=clang \
      --extra-cflags="-mmacosx-version-min=$MIN_MACOS" \
      --extra-ldflags="-mmacosx-version-min=$MIN_MACOS" --extra-libs=-liconv \
      --enable-gpl --enable-static --disable-shared \
      --disable-autodetect --enable-zlib --enable-bzlib --enable-iconv \
      --enable-videotoolbox --enable-audiotoolbox \
      --disable-network --disable-ffplay --disable-doc --disable-debug &&
    make -j"$JOBS" && make install)
fi

# ---------- comskip ----------
if [[ ! -f "$PREFIX/bin/comskip" ]]; then
  echo "==> comskip ($COMSKIP_COMMIT)"
  if [[ ! -d "$SRC/Comskip/.git" ]]; then
    git clone https://github.com/erikkaashoek/Comskip.git "$SRC/Comskip"
  fi
  (cd "$SRC/Comskip" && git fetch -q origin && git checkout -q "$COMSKIP_COMMIT" &&
    git clean -fdxq &&
    ./autogen.sh &&
    CFLAGS="$CFLAGS $OLD_C" LIBS="-liconv" PKG_CONFIG="pkg-config --static" ./configure --prefix="$PREFIX" --disable-dependency-tracking &&
    make -j"$JOBS" &&
    cp comskip "$PREFIX/bin/comskip")
fi

cp "$PREFIX/bin/ffmpeg" "$PREFIX/bin/ffprobe" "$PREFIX/bin/comskip" "$OUT/"
strip -x "$OUT"/ffmpeg "$OUT"/ffprobe "$OUT"/comskip

echo "==> checking that bundled tools only use system libraries"
bad=0
for b in "$OUT"/*; do
  if otool -L "$b" | tail -n +2 | awk '{print $1}' | grep -vE '^(/usr/lib/|/System/Library/)'; then
    echo "!! $b links non-system libraries" >&2; bad=1
  fi
done
[[ $bad == 0 ]] || exit 1
echo "==> done: $(ls "$OUT" | tr '\n' ' ')"
