#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/satz-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${TMPDIR:-/tmp}/satz-swift-cache"
if [ -d /Applications/Xcode.app/Contents/Developer ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
swift build -c release --disable-sandbox --cache-path "${TMPDIR:-/tmp}/satz-package-cache"
bundle=dist/Satz.app
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp .build/release/Satz "$bundle/Contents/MacOS/Satz"
cp packaging/Info.plist "$bundle/Contents/Info.plist"
swift scripts/icon.swift "$bundle/Contents/Resources/AppIcon.icns"
# A stable local requirement avoids changing the identity on every local rebuild.
# Release distributors should use their own Developer ID identity instead.
codesign --force --sign - --identifier org.satz.local \
  --requirements '=designated => identifier "org.satz.local"' "$bundle"
codesign --verify --deep --strict "$bundle"
echo "Built $bundle"
