#!/bin/bash
# Balance simulation: an auto-player for one class or path, fights played out headless.
# usage: abl.sh <tag> <goalLevel> <mode> <ClassOrPath> [partner] [partnerPath]      results in .build/res_<tag>.txt
#   modes:   full | nogear | noskill | nopet | nogold | notalent | lazy (lazy = upgrades nothing; only levels grow)
#   partner: solo (default) | companion (the starter ghost a lone player gets) | <Class> (a second auto-played hero, always "full")
#   env:     SEEDS=n runs n seeds per path (default 1; single runs are noisy, use 3+ to compare builds)
#            NOSYNC=1 skips copying src (sync once yourself first when starting many jobs at the same time)
# Run several at once; each takes ~3-5 minutes per seed for goal 40 (a partner roughly doubles it).
H="$(cd "$(dirname "$0")" && pwd)"; LUAU="${LUAU:-luau}"
tag=$1; goal=$2; mode=$3; c=$4; partner=${5:-solo}; partnerPath=$6; seeds=${SEEDS:-1}
# Python for sync.py: $PYTHON, else the first that really runs (on Windows python3/python can be Store stubs)
if [ -z "$PYTHON" ]; then
  for cand in python3 python "py -3"; do
    if $cand -c "" >/dev/null 2>&1; then PYTHON="$cand"; break; fi
  done
fi
PYTHON="${PYTHON:-python3}"
[ "$NOSYNC" = "1" ] || $PYTHON "$H/sync.py" >/dev/null
rm -rf "$H/.build/hl_$tag"; cp -r "$H/.build/hl6" "$H/.build/hl_$tag"; cp "$H/runners/balance90.luau" "$H/.build/hl_$tag/"
pp="nil"; [ -n "$partnerPath" ] && pp="\"$partnerPath\""
cd "$H/.build/hl_$tag"; echo "return { $goal, $seeds, \"$c\", \"$mode\", \"$partner\", $pp }" > cfg.luau
$LUAU balance90.luau > "$H/.build/res_$tag.txt" 2>&1
echo FINISHED >> "$H/.build/res_$tag.txt"
