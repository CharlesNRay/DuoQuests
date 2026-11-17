#!/bin/bash
# Balance simulation: a solo auto-player for one class or path, fights played out headless.
# usage: abl.sh <tag> <goalLevel> <mode> <ClassOrPath>      results in .build/res_<tag>.txt
#   modes: full | nogear | noskill | nopet | nogold | lazy (lazy = upgrades nothing; only levels grow)
# Run several at once (2 cores handle ~4 jobs); each takes ~3-5 minutes for goal 40.
H="$(cd "$(dirname "$0")" && pwd)"; LUAU="${LUAU:-luau}"
tag=$1; goal=$2; mode=$3; c=$4
python3 "$H/sync.py" >/dev/null
rm -rf "$H/.build/hl_$tag"; cp -r "$H/.build/hl6" "$H/.build/hl_$tag"; cp "$H/runners/balance90.luau" "$H/.build/hl_$tag/"
cd "$H/.build/hl_$tag"; echo "return { $goal, 1, \"$c\", \"$mode\" }" > cfg.luau
$LUAU balance90.luau > "$H/.build/res_$tag.txt" 2>&1
echo FINISHED >> "$H/.build/res_$tag.txt"
