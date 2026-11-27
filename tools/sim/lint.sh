#!/bin/bash
# Finds names used but never defined (a missing local function crashes only when that line runs, so the headless
# suites can miss it in services they do not load). Roblox globals are ignored. Needs luau-analyze
# (LUAU_ANALYZE=/path, else luau-analyze on PATH, else ~/bin/luau-analyze.exe). Prints "lint: N unknown names".
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$H/../.." && pwd)"
A="${LUAU_ANALYZE:-}"
if [ -z "$A" ]; then
  if command -v luau-analyze >/dev/null 2>&1; then A=luau-analyze; elif [ -x "$HOME/bin/luau-analyze.exe" ]; then A="$HOME/bin/luau-analyze.exe"; fi
fi
if [ -z "$A" ]; then echo "lint: skipped (no luau-analyze)"; exit 0; fi
R='game|task|warn|script|Instance|Enum|CFrame|Vector3|Vector2|Vector3int16|Vector2int16|Color3|UDim2|UDim|TweenInfo|workspace|typeof|tick|Ray|NumberSequence|ColorSequence|NumberRange|BrickColor|Rect|NumberSequenceKeypoint|ColorSequenceKeypoint|PhysicalProperties|Font|DateTime|RaycastParams|OverlapParams|delay|spawn|wait|settings|plugin|shared|Random|Faces|Axes|Region3|PathWaypoint|elapsedTime|time|version|require|SharedTable|utf8|buffer|vector|UserSettings|stats|gcinfo|debug'
cd "$ROOT"
n=0
for f in $(git ls-files 'src/*.luau' 'src/**/*.luau'); do
  out=$("$A" "$f" 2>&1 | grep "Unknown global" | grep -vE "Unknown global '($R)'")
  if [ -n "$out" ]; then echo "$out"; n=$((n + $(echo "$out" | wc -l))); fi
done
echo "lint: $n unknown names"
