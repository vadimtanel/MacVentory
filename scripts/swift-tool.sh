#!/bin/bash
# Keep build caches inside the project; no package dependencies are downloaded.
set -euo pipefail
cd "$(dirname "$0")/.."
verb="${1:?Usage: swift-tool.sh build|test|run [arguments]}"
shift
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
options=(--cache-path "$PWD/.build/cache" --config-path "$PWD/.build/config" --security-path "$PWD/.build/security")
if [ "${MACVENTORY_DISABLE_SWIFTPM_SANDBOX:-0}" = 1 ]; then options+=(--disable-sandbox); fi
developer_directory="$(/usr/bin/xcode-select -p)"
if [[ "$developer_directory" = *CommandLineTools ]]; then
  # This CLT's macOS 27 SDK requires a SwiftUI macro plugin supplied only by full Xcode.
  if [ -d "$developer_directory/SDKs/MacOSX26.5.sdk" ]; then
    options+=(--build-system native --sdk "$developer_directory/SDKs/MacOSX26.5.sdk")
  fi
  if [ "$verb" = test ]; then
    options+=(--disable-xctest --triple "$(uname -m)-apple-macos14.0"
      -Xswiftc -F -Xswiftc "$developer_directory/Library/Developer/Frameworks"
      -Xswiftc -plugin-path -Xswiftc "$developer_directory/usr/lib/swift/host/plugins/testing"
      -Xlinker -rpath -Xlinker "$developer_directory/Library/Developer/Frameworks")
  fi
fi
exec swift "$verb" "${options[@]}" "$@"
