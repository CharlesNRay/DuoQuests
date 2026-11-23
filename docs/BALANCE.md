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
Mage check (2026-11-18): Mage is NOT low on damage. In four-hero stage fights it deals the most damage, and +stats (Attack 19,
speed 0.9) did not move its frontier (40-49) while making it the top boss dps, so that was reverted (only MaxHealth 110 -> 120 kept).
The gap is survival: the Warrior companion (the only tank in a Mage team) dies in every fight (gearless probe, level 30, stage 14),
while a Summoner team also has taunting skeletons. Next lever: tank survival (Warrior/Guardian companion, or tank aggro/defense).
Tank buff (2026-11-18): Warrior MaxHealth 200 -> 260 (+35/level, was 25), Defense 10 -> 14 (+3/level, was 2). Probe
(`tools/sim/runners/partyprobe.luau`): the Warrior now survives every won fight (0/30 deaths, was 30/30). Sims (companion, full):
Mage fr 42-47 at L40 in 9.4-10.2h (boss 20 now 0 losses, dungeons won at the recommended level), Warrior fr 55-61, Summoner 62-86;
L30 4.9-5.3h for all. All inside the targets; Summoner is the high outlier (next: trim MinionHealthScale if it stays ahead).
Summoner trim (2026-11-18): `Economy.MinionHealthScale` 0.5 -> 0.4. Summoner (2 seeds x 2 paths): fr 45-62 at L40 in 8.8-12.4h (was 62-86).

Bosses for four heroes (2026-11-18): `abl.sh` now prints `BOSSDMG` lines (world/season boss damage as a multiple of
`Bosses.DamageScale`; the world tiers are 1/3/6/10/16/20x). Before the change a geared four-hero party dealt 4-7x at L10,
9-13x at L20-30, 15-137x at L40, i.e. most tiers mid-game. `Bosses.DamageScale` base 260 -> 520 halves those (typical mid-game
fight = tier 3-4, the top tier a stretch); guild raid health is built from DamageScale so it doubled too; season boss MaxHealth
30M -> 60M (a guess: it depends on how many players join, tune with live data). L40 still overshoots because DamageScale grows
linearly with frontier while power grows faster.
Late boss scale (2026-11-19): fresh runs (3 classes x 2 paths x 2 seeds, companions, full) at base 520 gave world-boss
damage of L10 1.4-3.2x, L20 2.9-6x, L30 4.6-10.7x (on target) but L40 2.8-34x (median ~14.5, 4/12 reach the 20x top tier).
`Bosses.DamageScale` now also grows 2% per stage past stage 35 (x1.32 at 51, x2.1 at 92): L40 median ~8.5x (tier 3-4,
1/12 reach the top tier), L30 almost unchanged. Guild raid health follows DamageScale, so it grows the same way late.

Class roster check (2026-11-19, companion, full, 2 paths x 2 seeds, frontier at L40 / hours):
| Class | frontier at L40 | hours | note |
|---|---|---|---|
| Mage | 45-52 (median ~50) | 8.9-12.0 | tightest spread, mid-pack: no change needed |
| Warrior | 40-92 (~51) | 7.8-11.8 | Guardian seed 1 ran away to 92 |
| Summoner | 57-81 (~61) | 8.8-10.5 | highest |
| Ranger | 40-64 (~54) | 8.8-11.1 | |
| Rogue | 40-62 (~51) | 8.6-11.6 | |
| Cleric | 39-45 (~40) | 10.6-11.7 | lowest: Templar 39 sits at the bottom of the 40-90 target |

Cleric buff (2026-11-19). Cause found with a loadout dump: the bot's Cleric wears sensible skills (Judgment, Radiant Burst,
Heal, Blessing). The gap is structural. A lone player's skill upgrades go into their own hero. A Mage owner turns them into damage, but a
Cleric owner turns them into healing that a party that never dies does not need, while its companion damage dealers stay on
starter skills. Raw Attack barely helps (14/2.5 -> 16/2.9 gave +3 stages; 18/3.2 no more). Changes kept:
- Cleric Attack 14 -> 16, growth 2.5 -> 2.9.
- Purify reworked: still cleanses and heals, now also applies `Consecrated` to every enemy (takes x1.15 damage, deals x0.9,
  Strength +0.04/level, 7 s), no longer waits for a debuff, cooldown 18 -> 14 (min 8).
- Blessing (party Attack buff) x1.2 -> x1.25 and Strength per level 0.03 -> 0.05, so a high-level Blessing is the healer's damage.
Result (2 paths x 2 seeds): fr 39-48 at L40 (median ~45, was ~40) in 9.3-11.6h. The stage 40 boss is reached at 365-486 min (was 470-600).
Mage check after the Blessing change: fr 51-52 (companion Clerics' Blessing is low level, so other teams gain little).

## Skill rework: combos, team aura, support skills that add damage (2026-11-19)
Ideas borrowed from idle RPGs like Ulala (combo skill sets, a full-team aura, support classes that add damage by
weakening enemies); names and numbers are ours.
- Combos (`Consume` on a Damage effect, layer statuses with `Combo = true`, up to 5 layers, 10 s): builders add a layer of the
  class mark, the finisher deals +X% per layer and removes them. Mage Fireball/Lightning Bolt -> Arcane Charge -> Arcane Blast
  (+30%); Ranger Power Shot/Piercing Arrow -> Tracked -> Explosive Arrow (+25%); Rogue Backstab/Poison Blade -> Opened ->
  Eviscerate (+30%); Warrior Shield Bash/Whirlwind -> Sundered -> Crushing Blow (+25%); Cleric Smite/Radiant Burst -> Judged ->
  Judgment (+30%); Summoner Haunt -> Soul Rot -> Soul Leech (+20%; Haunt gave 2 layers at first, Summoner ran ahead).
- Team aura (`Config/TeamAura`): 1 tank + 1 healer + 2 damage heroes in a fight = x1.06 health, attack and defense for all.
- Support skills: Taunt also Exposes every enemy (x1.1 damage taken, +3%/level); Last Stand adds Frenzied; Rallied also
  gives x1.1 Attack; Guardian Angel casts on cooldown (20 s) and Emboldens the party; plus the Cleric changes above.
- Everything together made L40 come in 4.9-9.9h at frontier 45-117, so `Config/Stages.PartyScale` 2.2 -> 2.6.
Result (companion, full, 2 paths x 2 seeds):
| Class | frontier at L40 | hours to L40 | L30 |
|---|---|---|---|
| Mage | 41-45 | 9.0-10.5 | 4.9-5.5h |
| Warrior | 42-56 | 9.0-10.4 | 4.9-5.5h |
| Summoner | 44-62 | 8.6-11.6 | 4.9-6.1h |
| Ranger | 41-48 | 9.1-10.8 | 4.9-5.3h |
| Rogue | 48-61 | 7.9-9.6 | 4.6-5.3h |
| Cleric | 42-45 | 10.0-11.1 | 5.0-5.7h |
Caveat: the bot equips skills by level, so it does not plan combos (it may wear a finisher without its builders). Real
players who build a combo should do better. Not checked after the change: lazy/nogear walls, dungeons, boss tiers.
Follow-up checks after the rework (2026-11-19):
- Dungeons: the Spire (stage 38, recommended L40) failed for most L40 parties (frontier 41-46), the Abyss was mixed, so
  Abyss Stage 27 -> 25 and Spire 38 -> 35. Now won 5/5 at the recommended level unless the party is behind (Spire fails at fr <= 41).
- Boss tiers: damage went up with combos and the aura (L40 median ~12x), so `Bosses.DamageScale` base 520 -> 600 and the
  late growth past stage 35 0.02 -> 0.03 per stage. Now L10 ~2.3x, L20 ~5x, L30 ~7.5x, L40 ~10x (tier 4; top tier 20x a stretch).
- Lazy (upgrades nothing): stage 20-25 after 16-17h, ~1000 losses at boss 20 (walls there). No gear: stage 23-30 at L40 in 11-13h.
Combo bot (2026-11-19): `balance90.luau` now wears an owned finisher with its owned builders (builders first, then the
finisher, then the best remaining skill); cfg entry 7 = false brings back the level-only bot. Results (2 paths x 2 seeds):
Mage fr 40-65 (8.1-10.8h), Warrior 39-56 (9.0-10.2h), Summoner 40-54 (8.9-11.3h), Ranger 43-52 (9.2-10.1h), Rogue 40-54
(8.9-10.8h), Cleric 37-53 (10.2-11.2h); L30 4.4-6.0h. Same pace as the level-only bot, classes closer together
(medians ~45-52), so no retune.

## Pets in the sim (2026-11-19)
`balance90.luau` now also spends wish tickets (tutorial, bosses, eggs; it ignored them before), wears the best pet gear in
every open slot and sells spare pieces, feeds all pet food to the active pet, and spends up to a fifth of its gold at the
Pet Store (eggs 3/day, gear crates once a slot is open). Pet levels from fights and boss pet gear drops were already in.
Each run prints a `PET` line (pet level, worn gear). Results (companion, full, 2 paths x 2 seeds):
L40 in 8.0-10.8h (median ~9.1h, was ~10h without the pet habits), frontier 40-66, L30 4.6-5.8h; by L40 the pet wears 3-4
pieces, mostly Epic with some Legendary. No pets (nopet, Mage and Warrior): L40 in 12.6-14.4h at frontier 34-45, so pets
are clearly worth it. No retune (inside 9-12h at the fast edge; PartyScale 2.6 -> 2.7 if it should be slower).
Finding: pet food piles up (10-95 left at L40) because a pet cannot level past its owner; food is only useful while the pet
lags behind (e.g. a new pet). Fixed 2026-11-22: food fed to a capped pet fills a bar that pays 1 pet shard of its rarity per 16,000 XP (`Config/Pets.FoodOverflow`, `Pets.OverflowFood`).

## Replay Wishstone income (checked 2026-11-22, no change)
`STONES30` lines (Mage, companion, full): 321-332 Wishstones earned by L30 (~5h, ~1950 fights, frontier 36-40).
First clears pay ~76 (2 each) and the stage 10/20/30 bosses ~12 more; the rest, ~240 (~75%), comes from replays
(1 per `Economy.WishstonesReplayEvery` = 4 replay wins). That is one wish (3-8 stones) every ~4 minutes of play.
Kept as is: replaying is the idle loop, and every balance target above was tuned with this income included. To make wishes
scarcer, raise WishstonesReplayEvery (5 = -20% of the total) and re-run abl.sh (skills and pets would slow down).


## Roster check and Berserker buff (2026-11-22)
Fresh roster (companion, full, 2 paths x 2 seeds, frontier at L40): Mage 48-61, Cleric 45-51, Ranger 45-53, Rogue 45-61,
Summoner 58-66 (highest, inside the 40-90 target, left alone), Warrior Guardian 61-69 but **Berserker 37-40** (only path
below target). Cause: the Warrior is still the party's tank, and the Berserker mods took -24% health and -31% damage dealt
on top of its attack bonus, so the front line fell and the extra attack did not make up for it.
Change: Berserker DamageDealt -0.313 -> -0.15, MaxHealth -0.240 -> -0.12.
Result (3 seeds): fr 42-61 (median 57) at L40 in 8.3-10.3h, L30 in 4.6-5.5h: mid-pack.

## Runes (2026-11-22)
Per-piece values are small (Config/Runes) because 8 worn pieces stack. The bot buys rune pouches with up to 10% of its gold
and carves its best rune onto worn pieces with none or a lower tier (`runeCare`; prints a `RUNES` line).
Roster with runes (companion, full, 2 paths x 2 seeds, frontier at L40): Mage 51-68, Cleric 42-61, Ranger 40-55, Rogue 40-57,
Summoner 55-62, Warrior Berserker 40-49 / Guardian 56-79 - inside the noise of the run without runes, all in the 40-90 target.
At L40 the bot wears only 1-3 runes: they are lost whenever a piece is replaced (gear changes often while levelling) and drops
are a boss per 10 stages + 3% of frontier wins + dungeons + pouches. Runes are a mild boost now; the dials if they should matter
more: drop rate, pouch price, or letting a rune move to the piece that replaces it.
Rune moves with the slot (2026-11-22): equipping a replacement (Equip or Equip best) moves the old piece's rune onto the new
one unless the new piece already has an equal or better rune. Now the bot wears 3-8 runes at L40 (was 1-3). Roster
(companion, full, 2 paths x 2 seeds, frontier at L40 / hours): Mage 51-67, Cleric 42-61, Ranger 50-81, Rogue 42-61,
Summoner 45-68, Warrior Berserker 65-66 (6.4-7.6h) / Guardian 48-63. All inside the 40-90 target. Watch Berserker: both
seeds were fast (L40 in 6.4-7.6h vs 8.3-10.3h before runes); run SEEDS=3+ before trimming it.

## Gear bad-luck protection and what really spreads the roster (2026-11-22)
- `Config/Gear.Pity` (catch-up only): after 10 won fights (replays count) with no gear upgrade, if the weakest worn
  piece is below 85% of a "par" item (best cleared stage, that stage's most common rarity, roll 1), the next win drops
  that par item for that slot ("lucky find" in the fight toast; never auto-sold). Gear at par never triggers it.
- A first version always gave an upgrade (and stepped rarity up to beat strong gear): every class got far stronger
  (mean stage at L40 55 -> 81, L40 in ~6h instead of ~9h, one run reached stage 180). Dropped.
- The catch-up version leaves the roster where it was (3 seeds: mean stage 53, range 39-88, L40 in 9.5h).
- Lesson: gear score and stage line up (corr 0.85) because items drop at the stage you reach, not because gear luck
  drives the stage. The spread comes from boss walls: a run that has not beaten the stage 40 boss when it reaches L40
  sits at 40 (all six 40-ish runs), one that broke it climbs to 55-88. Class still matters: Mage 66, Summoner 58,
  Warrior 52, Ranger 51, Cleric 47, Rogue 45 (3 seeds each, 2 paths).
