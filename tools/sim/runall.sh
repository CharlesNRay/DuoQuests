#!/bin/bash
# Runs every test suite headless. Needs the `luau` binary on PATH (or LUAU=/path/to/luau).
# Output shows only FAIL lines, errors and each suite's "done:" summary.
H="$(cd "$(dirname "$0")" && pwd)"
LUAU="${LUAU:-luau}"
python3 "$H/sync.py" && cp "$H/runners/run_base.luau" "$H/.build/hl6/run.luau" && cp "$H/runners/extra.luau" "$H/.build/hl6/extra.luau"
cd "$H/.build/hl6"
($LUAU run.luau; $LUAU extra.luau) 2>&1 | grep -E "FAIL|done:|rror|attempt"
