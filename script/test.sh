#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
mkdir -p .build/ModuleCache .build/SwiftPMCache
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT_DIR/.build/ModuleCache"
export XDG_CACHE_HOME="$ROOT_DIR/.build/SwiftPMCache"
swift test --disable-sandbox --cache-path "$ROOT_DIR/.build/SwiftPMCache"
