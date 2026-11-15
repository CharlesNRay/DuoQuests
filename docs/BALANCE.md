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


---

# Pacing and bosses - 2026-11-15 (second pass, supersedes the table above)

Design goals from the owner:
- Level 10 at ~12 min, level 20 about 15 min later (~27 min), level 30 about 30 min after that (~1 h).
- Subclasses unlock at **player level 30** (was stage 30). They are a growth milestone (new skills and mechanics), not a way to blow through content, so enemies **step up right after floor 30** (`Config/Stages.Tiers`: x1.1 from floor 31 and again from 61).
- Regular stages: tough but beatable. **Every 10th floor is a boss** that is a real hurdle and rewards smart skill choices.

## What changed
- `Economy.XPScale` = 14 (XP only). `Stages`: ScalePerStage 0.045, ScalePower 1.35, BossScaleMult 1.1, Tiers as above.
- **Boss mechanics** (new): scheduled attacks on fixed timers with a 1.5s `Telegraph` warning, `Summon` effect (capped by `MaxAllies`), `Enrage` below 50% health. Skills fire in slot order as cooldowns come up, so a Warrior can time a shield before the hit and a Cleric a heal after it.
  - Floor 10 Slime King: splits off 2 slimelets at 5s, 19s, 33s... (area skills help).
  - Floor 20 Goblin Warlord: Crushing Blow (3x attack on one target) at 8s, 19s, 30s... (shield before, heal after).
  - Floor 30 Spore Mother: Spore Call minions at 5s, Spore Burst (whole party) at 10s, 22s... plus enrage.
  - Bosses cycle (40 = Slime King again, stronger).
- Simulator (`BalanceTool`) now reports level milestones and boss attempts. `PacingTests` checks them.

## Simulated results (efficient 2-player auto-player, pets+gear+subclass)
| Milestone | Goal | Simulated |
|---|---|---|
| Level 10 | ~12 min | 7-8 min |
| Level 20 | ~27 min | 20-21 min |
| Level 30 | ~57 min | 47-51 min |
| Boss 10 failed attempts | a few | 2 |
| Boss 20 failed attempts | some | 6-8 |
| Boss 30 failed attempts | some | 7-13 |
| Boss 40 failed attempts | a hurdle | ~40 (too high; see below) |

The auto-player is more efficient than a real player at spending, so it runs ahead of the goals on purpose.

## Caveats
- The auto-player equips the most recently unlocked skills and cannot plan around boss timings or pick area skills on purpose, so it over-penalises mechanic bosses. Real players should do better. **Floor 40 (Slime King again) is a ~40-attempt wall for the bot; check it by hand.**
- Solo play with no partner is still much slower; the starter companion helps in the real game but the simulator has no companion mode yet.
- XP is tied to stage progress, so levels past 30 depend on beating the stage 30-40 bosses.
