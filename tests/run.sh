#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work
GODOT_BIN="${GODOT_BIN:-godot}"
"$GODOT_BIN" --headless --editor --path . --quit > work/import.log 2>&1
if rg -n 'SCRIPT ERROR|^ERROR:' work/import.log; then
  exit 1
fi
timeout 180s "$GODOT_BIN" --headless --path . --script tests/run_tests.gd > work/headless.log 2>&1
cat work/headless.log
if rg -n 'SCRIPT ERROR|^ERROR:|^FAIL:' work/headless.log; then
  exit 1
fi
rg -q 'RESULT checks=[0-9]+ failures=0 completed_routes=' work/headless.log
timeout 180s "$GODOT_BIN" --headless --path . --script tests/media_tests.gd > work/media.log 2>&1
cat work/media.log
if rg -n 'SCRIPT ERROR|^ERROR:|^FAIL:' work/media.log; then
  exit 1
fi
rg -q 'MEDIA RESULT checks=[0-9]+ failures=0 completed_ui_modes=8 restored_events=11' work/media.log
