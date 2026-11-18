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

# Pair balance - 2026-11-16 (supersedes the solo-tuned numbers above)
The game is always played by two fighters: a partner, or the companion a lone player gets (it mirrors the owner's
gear, pet and average skill-slot level). The 2026-11-15/16 tuning had been measured with a hero fighting alone, so in a
pair every class reached level 40 in 1-2 hours at stage ~250 (the older pair tool showed the same: level 30 in ~50 min).

Cause: Defense was measured against a flat 1000 (`damage x 1000 / (1000 + Defense)`). Health and Defense both grow with
gear stage after stage, so toughness grew about stage^2 while enemy attack grew stage^1.35: once a party got ahead it
could never be stopped (runs either stalled ~60 or exploded past 150). Warrior + Cleric pairs (a lone Warrior gets the
Priest companion, a lone Cleric the Guardian one) have the most Defense and ran away first; that was the "Guardian" issue.

Changes:
- `Config/Economy.DefenseScaleExp = 0.5`: the 1000 becomes 1000 x (attacking enemy scale ^ 0.5) (Simulation:DealDamage).
- `Config/Stages.ScalePower` 1.35 -> 1.6: steeper enemy growth.
- New, off: `Config/Stages.HealthScalePower` (enemy health on its own curve). Tried and rejected (it made pairs faster).

Simulated with `tools/sim` (companion unless noted, goal level 40, 2 seeds):
| Check | Result | Target |
|---|---|---|
| All 12 paths | L40 in 8.5-12.3h at stage 40-81; L30 in 4.8-6.6h | L40 in 9-11h at stage 40-90; L30 in 4-10h |
| Real duo (Cleric Priest partner) | L40 in 9.2-13.4h at stage 37-50 | same |
| Levels at stage 10 / 30 | 3-8 / 23-31 | 5-8 / 23-28 |
| Upgrade nothing (lazy) | stalls at stage 19-20 | the stage 20 boss |
| No gear | stalls at 19-28 | ~16 |
| No skills | reaches 34-42 | ~30 |
| No pets | 20-30% slower | ~45% slower |
Sweeps that led here (8 sample builds): steeper curve alone left Warrior/Cleric pairs at stage 130-200; split health
curves made it worse; defense scaling on the old curve was far too easy (L40 in 1-3h); curve 1.6 + defense 0.5 fit.
Open: no-skills and no-pets slow a pair a little less than intended; stage 40 is where most builds sit at level 40.

## Early ease - 2026-11-16
Play-testing showed a fresh pair walled at stage 11 right after the tutorial (level 4, 20 wishes unspent). Two fixes:
the tutorial now ends with "make your wishes" and "watch your battle" steps, and `Config/Stages.EarlyEase =
{ From = 1, To = 40, Mult = 0.8 }` softens enemies (x0.8 at the start, easing back to full strength by stage 40; it started at 11
at first, but stages 2-10 had also got ~20% tougher and a level-2 pair lost stage 8 in the tutorial). No farm hold before
the first boss: a loss there just steps back and the party tries again (new players do not know the Advance button yet).
Simulated (companion, 2 seeds): level 30 unchanged at 5.1-6.1h (the subclass stays a 5-6h goal); level at stage 30 24-27;
L40 9.2-12.3h; a player who upgrades nothing reaches stage 15 by level 15-16 (was 20-22) and still stalls at stage 20-25.
PacingTests' old Warrior+Cleric bot spends no gold and levels no pets; its boss check now only asks that boss 20 is reached.

## Four-hero balance (2026-11-18)

Parties hold up to 4 players and every fight has 4 heroes: members (or their ghosts while offline) plus companions in the
empty seats (`Party.SyncCompanions`, classes the party lacks: Cleric, Warrior, Mage, Ranger, ...). Enemies scale with
`Config/Stages.PartyScale` = 2.2 on top of `Stages.Scale`. `abl.sh ... companion` now fills all three seats.
Results at 2.2 (full mode, companions): L30 4.8-6h, L40 8.6-11.5h at stage 41-62 (target 40-90 in 9-12h); lazy mode reaches
stage 20-23 only after 15h+ (walls at boss 20). Dungeon stages were lowered to match (Crypt 6, Foundry 17, Abyss 27, Spire 38).
Open: Mage lags (stage 40-51 at L40, ~100 losses at boss 20, loses dungeons at the recommended level) while Summoner leads (58-73).
