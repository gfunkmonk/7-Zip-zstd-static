#!/bin/bash
set -eo pipefail

PLATFORM=${PLATFORM:-Linux}
JOBS=$(nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo 2)

case $PLATFORM in
  macOS)
    case $ARCH in
      x86-64)
        MAKE_OPTS="-f ../../cmpl_mac_x64.mak";;
      arm64)
        MAKE_OPTS="-f ../../cmpl_mac_arm64.mak";;
      *)
        echo "Unsupported macOS architecture: $ARCH" >&2; exit 1;;
    esac
    STATIC_OPT=""
    EXTRA_LIBS="MY_LIBS=-liconv"
    ;;
  *)
    case $ARCH in
      x86-64)
        MAKE_OPTS="MY_ASM=uasm -f ../../cmpl_gcc_x64.mak";;
      x86|arm64)
        MAKE_OPTS="MY_ASM=uasm -f ../../cmpl_gcc_$ARCH.mak";;
      arm|armhf)
        MAKE_OPTS="-f ../../cmpl_gcc_arm.mak";;
      *)
        MAKE_OPTS="-f ../../cmpl_gcc.mak";;
    esac
    STATIC_OPT="COMPL_STATIC=1"
    EXTRA_LIBS=""
    ;;
esac

git ls-files -z | xargs -0 unix2dos -q --allow-chown && ( QUILT_PATCHES=../patches quilt push -a || exit 1 )

( cd CPP/7zip/Bundles/Alone2 && mkdir -p b/g && \
  make -j$JOBS \
    ${TOOL:+CROSS_COMPILE="${TOOL}-"} \
    CFLAGS_BASE_LIST="-c -D_7ZIP_AFFINITY_DISABLE=1 -DZ7_AFFINITY_DISABLE=1 -D_GNU_SOURCE=1" \
    CFLAGS_WARN_WALL="-Wall -Wextra" $STATIC_OPT $EXTRA_LIBS $MAKE_OPTS || exit 1 )

find . -type f -name '7zzs' -exec cp -va {} 7zz \;
[ -f 7zz ] || find . -mindepth 2 -type f -name '7zz' | head -n 1 | xargs -I{} cp -va {} 7zz
[ -f 7zz ] || { echo "Error: 7zzs or 7zz binary not found after build" >&2; exit 1; }
if command -v upx >/dev/null 2>&1; then upx --lzma 7zz || true; fi
if command -v file >/dev/null 2>&1; then echo -e "\033[38;2;223;115;255m File Info:  $(file 7zz | cut -d: -f2-)\033[0m"; fi
tar -cJvf "$GITHUB_WORKSPACE/7zz-$PLATFORM-$ARCH.tar.xz" 7zz
