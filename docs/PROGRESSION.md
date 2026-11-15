# Progression design notes

How a player moves through stages and what they earn. All numbers live in
`Config/Economy` and `Config/Stages` and are placeholders.

## Decided and implemented

- **Stages** are a pure function of the stage number (`Stages.Build`). Every
  10th stage is a lone boss. 
- **The frontier** (`Season.HighestStage`) is the furthest stage unlocked.
  Clearing it pays full rewards and moves it up one.
- **No farming old content:** replaying an already-cleared stage pays 50%, so
  the frontier is always the best place to be.
- **Rewards per clear:** Gold (levels skill slots), XP (player level), Skill
  Shards (unlock skills of your choice). Boss clears pay extra shards.
- **First clear of each boss stage** grants one free skill pick, guarded by the
  `StageRewardsClaimed` ledger so it can never be paid twice.
- **Spending** (`Economy`): shards unlock a skill (Common 180 / Rare 360 / Epic
  630), a pick unlocks any skill of the class, gold levels a slot (90 x current
  level). Every action validates fully and changes nothing on failure.
- **Every stage has a timer** (60 s, boss 90 s). Running out of time is a loss.
- **Losing a fight steps the party back one stage** (never below 1), so a party
  that is too weak keeps earning reduced rewards, grows stronger, and climbs
  again with no input. Retrying the same stage would soft-lock it.

## Balancing formula (calibrated)

**What the research says** (sources at the bottom):

- Idle games use costs that grow faster than income so each step takes longer
  than the last. The Kongregate "Math of Idle Games" talks and articles use
  exponential costs against sub-exponential production for this.
- Prestige-style resets use root curves: the payoff for each doubling needs a
  fixed multiple of the previous effort (cube root needs about 8x, square root
  about 4x).
- For RPG power and level curves, designers recommend **polynomial** curves
  (`y = A * x^B + C`, keep B small) for XP and enemy scaling, and reserve
  exponential for deliberate spikes such as bosses.

**Our choice:** everything is polynomial, because a player's power here is
polynomial too (stats and slot bonuses grow linearly with levels, and level
costs grow linearly). An exponential enemy curve against polynomial player
growth would just be a hard wall.

| Piece | Formula | Current values |
|---|---|---|
| Enemy scale | `1 + a * (stage - 1)^p` | a = 0.04, p = 1.3 |
| Gold per frontier clear | `RewardScale * (10 + 4 * stage)` | RewardScale = 0.1 |
| XP per frontier clear | `RewardScale * (10 + 3 * stage)` | |
| Shards per clear | `1 + stage / 10`, plus 5 on a boss | not scaled |
| XP to next level | `50 + 25 * (level - 1)` | max level 50 |
| Gold to level a slot | `90 * level` | slot cap 20 |
| Skill unlock (shards) | Common 180 / Rare 360 / Epic 630 | Epic is 3.5x Common |

**The target the numbers were fitted to.** The time to reach stage `s` is
`T(s) = 2h * (s / 30)^2.3`, so each new stage takes longer than the one before.
That gives these milestones for an auto-player:

| Online time | Target frontier | Simulated |
|---|---|---|
| 15 min | about 12 | 10 (first boss) |
| 2 hours | 30 | 30 |
| 14 hours (week one) | 70 | 70 |
| 84 hours (6 weeks) | 152 | 170 |

At 14 hours the auto-player owns all 8 Warrior skills and its slots average
level 8 of 20. A fully built party runs out of stages at about stage 170, which
leaves headroom above the 6-week target. The parameters came from grid
searches over `a`, `p`, reward scale, slot cost and unlock cost, scored against
these targets.

**Assumptions to confirm:** 2 hours online per day, a 6-week season, and a
2-second pause between fights. Change them in `Tests/PacingTests` and this
file together. The simulated player is simple (it spends everything greedily),
so treat this as a calibrated starting point, not a prediction. Real playtest
data will move it. After any change to `Config/Economy` or `Config/Stages`,
run `PacingTests` (add `{ Full = true }` for the 6-week check).

Other findings: regular stage fights are short (0-15 s) and only bosses reach
20-30 s. Rewards also have a floor of 1, which slightly inflates the earliest
stages.

**Sources**

- Anthony Pecorella, [The Math of Idle Games](https://blog.kongregate.com/quest-for-progress-the-math-of-idle-games)
  (Kongregate), including [part II](https://www.gamedeveloper.com/game-platforms/the-math-of-idle-games-part-ii)
  and [part III](https://gamedeveloper.com/design/the-math-of-idle-games-part-iii)
- [Graphs for Player Progression, part I](https://medium.com/@ipooprainbows/graphs-for-player-progression-part-i-c56d83740450)

## Still to build

- Party layer: shared stage stored on the party record, ghost partner snapshot.
- Remote events for the client (equip, unlock, level slot) calling `Economy`.
- Server stage loop timer and offline idle rewards.
- Pets as combatants, titles and veteran buffs, rebirth rank.
