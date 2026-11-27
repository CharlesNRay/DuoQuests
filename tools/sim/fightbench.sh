#!/bin/bash
# CPU cost of one server fight simulation per stage band (see runners/fightbench.luau).
H="$(cd "$(dirname "$0")" && pwd)"
LUAU="${LUAU:-luau}"
if [ -z "$PYTHON" ]; then for cand in python3 python "py -3"; do if $cand -c "" >/dev/null 2>&1; then PYTHON="$cand"; break; fi; done; fi
$PYTHON "$H/sync.py" >/dev/null && cp "$H/runners/fightbench.luau" "$H/.build/hl6/fightbench.luau" && cd "$H/.build/hl6" && $LUAU fightbench.luau
