#!/bin/sh
# iPadOS 27 は、iOS 27 SDK でビルドした iPhone アプリを細長い窓で開く。
# SDK を 26.2 と記録すると、古い環境と同じ横幅の広い互換窓になる。
# 中身のコードは最新の SDK のまま。記録だけを戻す。
set -e

BIN="${TARGET_BUILD_DIR}/${EXECUTABLE_PATH}"
if [ ! -f "$BIN" ]; then
  echo "warning: stamp_legacy_ipad_window: no binary at $BIN"
  exit 0
fi

SHOW=$(vtool -show-build "$BIN")
PLATFORM_LINE=$(printf '%s\n' "$SHOW" | awk '/platform /{print $2; exit}')
case "$PLATFORM_LINE" in
  IOSSIMULATOR) PLATFORM=iossim ;;
  IOS) PLATFORM=ios ;;
  *)
    echo "stamp_legacy_ipad_window: skip platform ${PLATFORM_LINE}"
    exit 0
    ;;
esac

MINOS=$(printf '%s\n' "$SHOW" | awk '/minos /{print $2; exit}')
TOOL=$(printf '%s\n' "$SHOW" | awk '/tool /{print tolower($2); exit}')
TOOLVER=$(printf '%s\n' "$SHOW" | awk '/version /{print $2; exit}')
SDK=26.2
OUT="${BIN}.legacy-ipad"

if [ -n "$TOOL" ] && [ -n "$TOOLVER" ]; then
  vtool -set-build-version "$PLATFORM" "$MINOS" "$SDK" -tool "$TOOL" "$TOOLVER" \
    -replace -output "$OUT" "$BIN"
else
  vtool -set-build-version "$PLATFORM" "$MINOS" "$SDK" \
    -replace -output "$OUT" "$BIN"
fi
mv "$OUT" "$BIN"
chmod +x "$BIN"
