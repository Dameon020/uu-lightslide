#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build
xcrun swiftc -swift-version 5 Sources/ScrollCore.swift Sources/ScrollEngine.swift Tests/main.swift \
  -o .build/ScrollTests -framework Cocoa -framework ApplicationServices
UU_SERVER_PID="$(pgrep -f '^/Applications/UURemote.app/Contents/Helpers/UURemoteServer$' | head -1 || true)"
if [ -n "$UU_SERVER_PID" ]; then
  .build/ScrollTests "$UU_SERVER_PID"
else
  .build/ScrollTests
fi
