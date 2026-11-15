# Balance pass - 2026-11-15

Method: `BalanceTool` auto-player (see `server/Tests/BalanceTool.luau`), seed 42. Options: `Solo`, `Pets`, `Gear`, `Subclass`. Target frontier = `30*(h/2)^0.435`. The auto-player plays near-optimally, so it runs ahead of the target; compare scenarios against each other, not against the target.

Frontier stage reached at 0.25h / 1h / 2h / 6h / 14h:

| Scenario | 0.25h | 1h | 2h | 6h | 14h |
|---|---|---|---|---|---|
| Target | 12 | 22 | 30 | 48 | 70 |
| 2P baseline | 10 | 22 | 30 | 60 | 90 |
| 2P + pets | 10 | 22 | 30 | 60 | 80 |
| 2P + pets + gear | 20 | 30 | 40 | 70 | 100 |
| 2P + pets + gear + subclass | 20 | 40 | 50 | 100 | 180 |
| Solo baseline | 6 | 7 | 10 | 10 | 30 |
| Solo + pets + gear + subclass | 6 | 10 | 10 | 10 | 40 |

## Changes
- **Gear was ~5x too strong** (a stage-10 sword was ~+60% attack; pets+gear party hit stage 68 at 15 min and stage 2198 at 14h). Stat numbers cut ~4x, sell values cut ~2.5x. Now gear is worth roughly +10-30% progress.
- **Pets** are about neutral (gold spent on levels offsets the bonus) - left as is, headroom for stronger pets.
- **Subclasses** were ~3x progress at 14h; mods cut ~40% (e.g. Berserker Attack +45% -> +25%). Stage 30 is now a visible spike (+40-80%) without wrecking the curve.
- **BalanceTool bug fixed**: the gear step looped forever (always swapping), which is why earlier runs timed out.

## Still open
- Solo (no partner) is far behind the target. The starter companion fixes this in play but the sim's Solo mode has no companion; add a companion mode.
- Baseline 2P runs ahead of target from 6h; consider steepening `ScalePower` once real players are measured.
- Gear gating at boss stages (every 10) makes frontier jumpy in the sim.
