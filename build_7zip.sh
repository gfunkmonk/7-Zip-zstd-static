#!/bin/bash
# build_7zip.sh - Build 7-Zip static binary using musl cross-compilation.
# Run from the 7zip source directory: bash ../build_7zip.sh
set -euo pipefail
. "$(dirname "$0")/common.sh"

PLATFORM=${PLATFORM:-Linux}
# Default TOOL to empty so ${TOOL:+CROSS_COMPILE="${TOOL}-"} is safe under set -u.
# When TOOL is non-empty the make variable CROSS_COMPILE is set; when empty it is omitted.
TOOL=${TOOL:-}
JOBS=$(nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo 2)

echo -e "${VIOLET}= configuring build for ${PLATFORM}/${ARCH}${NC}"

case $PLATFORM in
  macOS)
    case $ARCH in
      x86-64) MAKE_OPTS="-f ../../cmpl_mac_x64.mak" ;;
      arm64)  MAKE_OPTS="-f ../../cmpl_mac_arm64.mak" ;;
      *)
        echo -e "${TOMATO}= ERROR: unsupported macOS architecture: ${ARCH}${NC}" >&2
        exit 1
        ;;
    esac
    STATIC_OPT=""
    EXTRA_LIBS="MY_LIBS=-liconv"
    ;;
  *)
    case $ARCH in
      x86-64)    MAKE_OPTS="MY_ASM=uasm -f ../../cmpl_gcc_x64.mak" ;;
      x86|arm64) MAKE_OPTS="MY_ASM=uasm -f ../../cmpl_gcc_${ARCH}.mak" ;;
      arm|armhf) MAKE_OPTS="-f ../../cmpl_gcc_arm.mak" ;;
      *)         MAKE_OPTS="-f ../../cmpl_gcc.mak" ;;
    esac
    STATIC_OPT="COMPL_STATIC=1"
    EXTRA_LIBS=""
    ;;
esac

echo -e "${AQUA}= applying patches${NC}"
git ls-files -z | xargs -0 unix2dos -q --allow-chown
QUILT_PATCHES=../patches quilt push -a || exit 1

echo -e "${AQUA}= building 7-Zip (${JOBS} jobs)${NC}"
(
  cd CPP/7zip/Bundles/Alone2
  mkdir -p b/g
  make -j"${JOBS}" \
    ${TOOL:+CROSS_COMPILE="${TOOL}-"} \
    CFLAGS_BASE_LIST="-c -D_7ZIP_AFFINITY_DISABLE=1 -DZ7_AFFINITY_DISABLE=1 -D_GNU_SOURCE=1" \
    CFLAGS_WARN_WALL="-Wall -Wextra" ${STATIC_OPT} ${EXTRA_LIBS} ${MAKE_OPTS}
)

echo -e "${MINT}= locating built binary${NC}"
find . -type f -name '7zzs' -exec cp -va {} 7zz \;
[ -f 7zz ] || find . -mindepth 2 -type f -name '7zz' | head -n 1 | xargs -I{} cp -va {} 7zz
[ -f 7zz ] || { echo -e "${TOMATO}= ERROR: 7zzs or 7zz binary not found after build${NC}" >&2; exit 1; }

if command -v upx >/dev/null 2>&1; then
  echo -e "${OCHRE}= compressing with upx${NC}"
  upx --lzma 7zz || true
fi
if command -v file >/dev/null 2>&1; then
  echo -e "${HELIOTROPE} File Info:  $(file 7zz | cut -d: -f2-)${NC}"
fi

echo -e "${AQUA}= packaging${NC}"
mkdir -p dist
ARCHIVE_NAME="7zz-${PLATFORM}-${ARCH}"
# The binary inside the archive must be named '7zz' so the macOS lipo step can
# extract it by that fixed name. Each arch build runs in its own isolated job so
# there is no cross-arch collision on dist/7zz.
cp 7zz dist/7zz
(cd dist && tar -cJf "${ARCHIVE_NAME}.tar.xz" 7zz)
echo -e "${JUNEBUD}= All done! Binary: dist/${ARCHIVE_NAME}.tar.xz ($(du -sh dist/7zz | cut -f1))${NC}"
