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

## Stage 40 boss wall: Dire Wolf trimmed (2026-11-22)
Losses per boss over 84 runs (before): 10: 1, 20: 21, 30: 2, **40: 65** (8 runs never beat it by L40), 50: 9, 60: 0.
The stage curve itself is smooth there (x1.05 per stage); the wall was the Dire Wolf: the fastest base attack of any
boss (1.0/s) plus Howl putting Enraged (x1.5 attack, x1.25 speed) on it ~37% of the time even at full health.
Changes: Dire Wolf Attack 12 -> 10.5, AttackSpeed 1.0 -> 0.85; Howl cooldown 16 -> 22 s, 5 s instead of 6 (Snow Wolf
uses Howl too). Feral Pounce is shared with Wolf/Boar/Magma Hound, so it was left alone.
Roster (6 classes x 2 paths x 3 seeds, companion, full), before -> after:
| | before | after |
|---|---|---|
| time stuck at the stage 40 boss | avg 1.34 h, 18/35 runs over 1 h | avg 0.47 h, 5/36 over 1 h |
| boss 40 beaten first try | 8 | 18 |
| stage at L40 | 53 (sd 11.5, 39-88) | 54 (sd 7.3, 40-68) |
| hours to L40 | 9.5 | 9.3 |
Still slow at it: Rangers (4 of the 7 runs with 50+ losses). Boss 20 (Goblin Warlord, also Stagger) averages ~25 losses: the
intended "doing nothing walls at stage 20" check. Class means now: Mage 62, Summoner 57, Warrior 57, Cleric 50, Rogue 50, Ranger 48.

## Ranger/Cleric buff, two hidden combo finishers, finisher priority (2026-11-22)
Bugs found while buffing:
- **Duplicate ability keys.** The Templar's "Judgment" and the bosses' "CrushingBlow" reused the keys of the Cleric and
  Warrior combo finishers in Config/Abilities, so the later entries silently replaced them: neither class has ever had its
  finisher (Judged/Sundered layers were never used up). Renamed to `Verdict` (Templar) and `BossCrush` (enemy, still shown
  as "Crushing Blow"). `SkillIdTests` now checks every combo mark has a finisher and no class pool holds an enemy skill.
  Side effect: a Warrior's Common skills are now just its 4 starters (Meadow skill wishes give copies).
- **Finishers almost never fired.** One cast per ~1.6 s (cast time + AfterCastDelay) in slot order, and a fast builder in an
  earlier slot (Smite, cd 1.5-3) was ready every cycle. `Simulation.FINISHER_MIN_LAYERS` (2): a ready finisher now goes first
  once an enemy carries that many layers of its mark.
Balance changes: Sharpshooter and Beastmaster DamageDealt -0.60 -> -0.50; Templar -0.45 -> -0.30; Priest -0.18 -> -0.12.
Bot changes (balance90): keeps Heal + Blessing (Cleric) and Taunt (Warrior) before the combo; logs `LOADOUT` lines.
Why Clerics lagged: in every other squad the companion Cleric wears Blessing (+25% party attack); a player Cleric who equips
by level drops it. Forced kits, 6 seeds: Heal/Blessing/RadiantBurst/Smite -> stage 62 at L40 (8.6 h); Heal/RadiantBurst/
Smite/Judgment -> 46 (10.6 h). A Judgment that also blessed the party did not help (its level trails the starter Blessing).
Roster at L40 (3 seeds; Cleric 6 seeds), before -> after: Cleric 50.5 -> 53.2, Ranger 47.5 -> 56.0, Rogue 49.8 -> 56.7,
Mage 62.2 -> 66.3, Summoner 57.2 -> 60.5, Warrior 56.7 -> 51.5 (now wears Taunt + Crushing Blow); hours to L40 ~9.1.
Open: Judgment is still a weaker 4th skill than Smite or Radiant Burst for a Blessing Cleric; real players may also drop
Blessing (a UI hint, or making Blessing harder to drop, would help); Warrior is now the lowest damage-side squad.

## Warrior: keep Iron Skin; Berserker halving actually applied (2026-11-23)
Forced Warrior kits (6 seeds x 2 paths, companion, full, stage at L40): Taunt/ShieldBash/Whirlwind/CrushingBlow 50.8;
no Taunt (ShieldBash/Whirlwind/CrushingBlow/IronSkin) 50.2; starter kit Taunt/IronSkin/ShieldBash/Whirlwind 56.7;
Taunt/IronSkin/ShieldBash/CrushingBlow 55.8. Iron Skin (a starter, so high level) is what the squad needs; the restored
Crushing Blow is fine as the 4th skill but not instead of Iron Skin. A self shield on Crushing Blow (20% max health) only
gave +1.4 and was dropped. The bot now keeps Taunt + Iron Skin (like Heal + Blessing for Clerics).
The 2026-11-22 "Berserker penalties halved" commit only changed this file: Config/Subclasses still had -0.313 damage and
-0.24 health. Now -0.15 / -0.12. Real bot, 6 seeds: Warrior 58.2 and 53.8 in two runs (Guardian 65/58, Berserker 51/49);
was 51.5. Path means swing ~±4 at 6 seeds. Berserker stays ~10 stages behind Guardian in every kit: still open.

## Berserker: lifesteal instead of a damage penalty; Guardian loses its damage bonus (2026-11-23)
Both Warrior paths wear the same skills in the sim (Taunt, Iron Skin + two starters; path skills start low), so only the
path mods differ, and the Guardian's (+15% attack, +14.2% damage dealt) out-damaged the Berserker's (+25% attack, -15%
damage dealt) on top of all its tankiness. The Warrior is the squad's tank on either path, so Berserker damage barely
moved the squad: no damage penalty +4, Blood Frenzy kits 55-57 (6 seeds, noise ±4). What helped is sustain.
Changes: Berserker DamageDealt -0.15 -> 0, new Lifesteal +0.25 (15% gave 55 at 12 seeds); Guardian DamageDealt +0.142 -> 0.
12 seeds, stage at L40: Berserker ~50 -> 59.8 (40-92), Guardian 64.8 -> 62.2 (47-94), ~8.8 h. Gap ~10 -> ~2.

## Talents (2026-11-23)
Level-up talent points (`Config/Talents`, 1 per level, 39 at L40, 8 talents x 10 ranks, the bot auto-spends by role).
`abl.sh ... 40 full <Class> companion`, 2 seeds x 2 paths each (12 runs per side):

| | no talents | talents |
|---|---|---|
| all | stage 60.8 at L40, 8.4 h | stage 67.6, 8.3 h |
| Warrior | 55.8 | 73.2 |
| Mage | 62.5 | 68.0 |
| Cleric | 64.2 | 61.5 -> 68.0 after the healer build led with Might (Mending first did not push stages) |

About +7 stages at L40, inside the 40-90 target; L40 time unchanged (~8 h). Warrior gains most (Vitality/Bulwark keep the
tank up, which carries the party). `abl.sh` mode `notalent` turns talents off for comparison.

## Judgment at equal rank (2026-11-24)
`tools/sim/runners/judgeprobe.luau`: the same 4-hero gearless L35 party, Cleric kit Heal/Blessing/Smite/Judgment vs
Heal/Blessing/RadiantBurst/Smite, every skill at rank 1, 30 seeds. Cleric damage per fight, Judgment vs Radiant:
stage 14 6210 vs 4907, stage 17 6277 vs 6162, stage 20 (boss, lost) 8781 vs 6715; wins equal. So Judgment is not weak in
itself: it trails in real play because it is Epic and ranks up slower than the Common/Rare starters (and Smite feeds it).
No stat change. If players still skip it, the lever is its rank (copies from wishes), not its numbers.

## Late game runaway (2026-11-25)
Runs to L75-100 (never tried before: the bot used to stop at L40) found that past stage ~80 the party ran away: stage
80 -> 266 in two game hours (L43 -> L62). The enemy curve `1 + 0.045 x (stage-1)^1.6` flattens in relative terms (stage
150 is only ~1% harder than 149) while every new stage drops gear that is a bit better (flat stats grow linearly with
the stage, and percent stats multiply together: crit chance, crit damage, attack speed, damage dealt). Any power spike
then turned into dozens of free stages.
- `Config/Gear.PercentSoft { From = 60, Exp = 0.3 }`: percent stats on gear count the item as stage
  `60 x (S/60)^0.3` past stage 60 (a Legendary +10 ring at stage 200: 0.66 crit chance before, 0.28 now).
- `Config/Stages.LateGrowth { From = 80, Rate = 0.008 }`: each stage past 80 is 0.8% harder on top (compounding).
  Tried From 60 with Rate 0.006 / 0.009 / 0.015 / 0.025 / 0.035 (all walled stage ~95 for 20+ levels; 1.5%+ walls
  everything at ~90) and From 80 / 0.008 (kept). Without it (only PercentSoft) runs still jumped 102 -> 172 by L58.
- Stage 100 used to be a long wall: rarity stops improving at stage 100 (Gear.Drop anchors end there), so past it only
  levels and upgrades push.

## Fight length (2026-11-25)
`Simulation` metrics (balance tools, `setup.Metrics`) showed fights at the frontier lasted 3-5 s at L50+ and the tested
hero died in nearly every one; healing done was ~0 from L50 on (a Cleric's Heal never fired), so roles only mattered
through burst. `Config/Stages.FightLength { Health = 2.4, Attack = 0.7 }`: stage monsters (and dungeon waves, and
monster adds) get 2.4x health and 0.7x attack. Frontier fights now last ~6-12 s.
- 1.8 / 0.55 kept the same "who wins" maths but made heroes far stronger (L40 frontier 65-91): longer fights let heals,
  shields and cooldown skills work. 2.4 / 0.7 puts L40 back at ~50-65 (Warrior Berserker high, see below).
- Fewer fights an hour: `Config/Economy.FightPay = 1.4` (gold, XP and shards per win) keeps the per-hour pace.
- Tested: 2.6 / 0.85 (L40 ~41-55, too hard) and 3.0 / 0.95 (L40 ~38-48, 15-23 h to L45).
- Late fights got short again (L50+ frontier fights 4-7 s): `LateGrowth.AttackShare = 0.5` gives attack half of the
  late growth and health the rest (health x attack still grows (1+Rate)^2 a stage).

## Zone 10 (2026-11-25)
Half the paths sat at stage 91-100 for 20-30 levels (Pyromancer 91-94 from L60 to L90). Zone 10's monsters hit ~40%
harder than zone 9's at the same scale (Sky Harpy 9 attack x 1.2 speed with a bleeding Swoop every 7 s, Storm Sprite
1.1 speed with an all-heroes Thunderclap). Sky Harpy Attack 9 -> 8, AttackSpeed 1.2 -> 1.05; Storm Sprite AttackSpeed
1.1 -> 1.0.
- Zone 11 copies of those monsters (Thunder Hawk, Volt Wisp) softened the same way: Mage and Summoner paths sat at
  stage ~100 from L60 to L100.
- `Stages.DefenseScale`: hero Defense is measured against the monster scale with ALL of the late growth (`Scale` only
  carries AttackShare of it). Measured against `Scale`, a Guardian ran from stage 110 to 167 in ten levels.

## Class report (2026-11-25)
Bot METRIC lines (every 10 levels, 12 fights at the best cleared stage with Simulation metrics) and
`tools/sim/classreport.py` build the class report (stage, hours, damage, pet share, buff/debuff damage, healing,
shields, mitigation per path). Roster to L100, 3 seeds per path, companion party, talents on:
| path | L100 stage before tweaks | after |
|---|---|---|
| Berserker | 171 | 151 (Lifesteal 0.25 -> 0.15) |
| Guardian | 159 | 131 (Defense +0.3 -> +0.2) |
| Priest | 140 | |
| Necromancer | 130 | |
| Beastmaster, Duelist | 127 | |
| Templar | 126 | |
| FrostWeaver | 121 | |
| SpiritCaller | 118 | |
| Pyromancer | 117 | |
| Sharpshooter | 111 | 118 (DamageDealt -0.5 -> -0.4) |
| Assassin | 109 | 119 (DamageDealt -0.6 -> -0.45) |
L40 (2 seeds): every path 44-65 (mean ~53) in 9-13 h. L100 in ~37-45 game hours of active play.
Supports carry their party late: at L90 a Priest's Blessing added ~412K/s of party damage on top of its own 92K, and
Taunt's Exposed made Warriors worth 74-171K/s more party damage. Pets do 20-60% of a hero's damage.

## Talents doubled (2026-11-25)
3 seeds per path at L60, talents on vs off: Berserker 100/95, Priest 101/99, Pyromancer 80/84, Beastmaster 89/72,
Duelist 96/94, Necromancer 95/94 (about +4 stages for 59 points). Per-rank values about doubled (Might 0.015 -> 0.03,
Vitality/Bulwark 0.02 -> 0.035, Precision 0.005 -> 0.008, Ferocity 0.03 -> 0.05, Swiftness 0.01 -> 0.018, Focus
0.008 -> 0.012, Mending 0.025 -> 0.04, Onslaught 0.015 -> 0.025, Fortitude -0.012 -> -0.02, Party Spirit 0.005 ->
0.008). Now at L60: Berserker 126, Priest 101, Pyromancer 97, Beastmaster 100, Duelist 95, Necromancer 98 (+13 on
average; the stage ~100 wall caps several). L40 roster unchanged (40-61, 2 seeds).

## Final roster (2026-11-25, talents doubled)
3 seeds per path to L100 (companion party): Pyromancer 141, Beastmaster 138, Priest 137, Templar 134, FrostWeaver 126,
Necromancer 123, Assassin 120, Sharpshooter 117, SpiritCaller 117, Duelist 116; Warriors still lead: Berserker 170,
Guardian 156 (after Bulwark 0.035 -> 0.025, Berserker Attack +0.25 -> +0.2, Warrior growth MaxHealth 35 -> 30 and
Defense 3 -> 2.5; before those 172 / 165). L40: every path ~46-62. L100 in 31-45 game hours.
Why Warriors lead with a companion party: the player's own hero gets all the gear, pets and talents; when it is the
tank the party holds, when the tank is the (ungeared) companion it falls first. A real party of four geared players
does not have that gap, so Warriors were not cut further. Watch it in playtests.

## Boss walls (2026-11-25, slow pacing)
Time from reaching stage N-1 to beating boss N (14 runs to L90-100): boss 70 avg 5.7 h (max 39 h, ~570 losses), boss 90
avg 27.6 h (max 93 h, ~1,860 losses, 2 runs never beat it); others under 2 h. Both are 12-attack bosses (Inferno Lord,
Goblin Warlord) with Stagger and Enrage; with longer fights the enraged second half wiped parties.
Enraged Attack x1.5 -> x1.3 and AttackSpeed x1.25 -> x1.15 (every boss); Goblin Warlord and Inferno Lord Attack 12 -> 11;
Crushing Blow (Goblin Warlord) 3x -> 2.5x.

## Slow progression and the upgrade loop (2026-11-25, owner request)
Owner's loop: log in, upgrade (gear, levels, talents, skills, wishes), push a few stages, wait for more upgrades. Not
big pushes. The bot prints `LOOP` lines per level band: stages cleared, the most new stages in any game hour, and
the longest wait between two new stages.
- Leveling: `Economy.LevelPace` multiplies a level's XP cost by band (1.7 around L10, 0.75 around L30, 2.9 at L50,
  4.4 at L70, 5.8 at L90, 7 at L110).
- Stages: `LateGrowth.Bands` 1.8% a stage from stage 25, 0.5% from stage 70 (1% left L60-90 runs ~6 stages in
  120 h); the old x1.1 step at stage 61 removed (on top of the growth it was a 20-50 h wall).
- Roster (one run per path, before the boss fix): L20 3-4 h, L40 13-16 h (stage 40-51), L60 42-57 h (55-84),
  L80 97-138 h, L100 188-278 h (stage 70-97, Berserker 141). Hours are active play with fights back to back; away
  earnings make real players faster.
- `NumberScale` 10 -> 100 (owner: bigger numbers); balance-neutral (defense and bosses scale with it).

## Roles (2026-11-26, owner rule)
Each path is judged by its role first; its other parts must never beat its primary role.
- Tanks (Guardian; Berserker = a tank that sustains by hitting; Duelist = the tanky Rogue) take the hits and survive.
- Healers (Priest; Spirit Caller = the Summoner's healer path) heal the most. A healer class's damage path (Templar) is a
  damage dealer first: heals grow with attack, so the Templar has HealingDealt -0.5 (it out-healed the Priest before).
- Damage paths deal the most damage, both single target and area (no "AoE dps" vs "single dps" split).
Check: `py -3 tools/sim/roles.py <prefix>` (share of party damage / healing / damage taken per level band). A share is
only meaningful with another healer in the party: the companions often have none, so for healer vs damage path use a
controlled fight (same party, same stage). Controlled check 2026-11-26: Priest heals 2-2.5x the Templar, the Templar deals ~2x the Priest.
Changes: Priest healing +45%, less damage; Templar healing -50%, damage penalty -0.12; Spirit Caller healing +100%;
Duelist and Swordsaint tankier instead of more damage; Warlord's damage bonus -> health; small Berserker/Guardian trims.

## Skills: one job each, and a second purpose (2026-11-26, owner rule)
Skills are measured in their own category (`tools/sim/runners/skillrank.luau`: each skill alone in the loadout, per second
of fight): Single (damage on a boss), AoE (damage on a pack), Heal, Shield (soaked), Buff/Debuff (what its statuses added or
kept off), Summon (its minions' damage). Within a class and category the best skill may do just that; every other one has a
second purpose (stun, execute, combo layer, self-heal, debuff, cleanse...). `skillaudit.luau` lists purposes and flags PURE.
- New mechanic: Damage `Execute = { Below, Mult }` (Executioner Strike, Execute).
- Stacking damage-over-time commons (Fireball, Ignite, Power Shot, Backstab, Fan of Knives, Meteor) lead their categories
  by far in long fights; the Epic/Legendary damage skills of Mage, Ranger and Rogue were 25-45% of them and were raised
  x1.35-1.6 (now 45-90%, each with a purpose the top one lacks).
- Not measured well by the probe: attack-speed buffs (Hasted) and conditional skills (cast only when hurt).

## Longer fights (2026-11-26, owner: 3-4x longer so skills cycle)
`Config/Stages.FightLength` Health 8.4 (was 2.4), Attack 0.45 (was 0.7); time limits 200 s / 300 s boss (were 60/90);
`Economy.FightPay` 4.3 (was 1.4: ~3x fewer fights an hour). Regular fights 7-13 s -> 25-60 s. Attack 0.3 was tried first:
long fights favour heals and shields, L60 stages jumped to 81-115. At 0.45 (8 paths, 1 seed): L30 4.2-4.7 h, L60 32-48 h,
stage at L60 52-87 (before: 38-65 h, 55-85). Boss 20 first beaten after 1-2.3 h (unchanged).

## Long-fight class passes (2026-11-26, overnight)
12 paths x 2 seeds to L100 per pass (`abl.sh <tag> 100 full <Path> companion`). Stage at L100, first -> latest pass:
tanks led by far (Berserker 177, Guardian 146) and fragile damage dealers trailed (Assassin 81, Pyromancer 84, Beastmaster 77).
Changes: Berserker attack +8% (owner), lifesteal 0.07, health -0.16; Guardian defense +12% (owner), health +0.07, damage
taken -0.05; damage paths' health penalties softened (long fights punish fragility: Pyromancer -0.10, Sharpshooter/Assassin
-0.15, Beastmaster -0.15); Assassin damage penalty 0; Pyromancer -0.16; Beastmaster pets: PetDamage 2.0, PetBoost 1.25 / +8
skill levels (owner: pets much stronger). Latest: most paths 86-116; Berserker swings 112-200 between passes (seed luck).
Caveat: in companion mode the tested hero's own upgrades decide how far the whole party survives, which favours tanks;
roles (roles.py) hold: damage paths 44-69% of party damage, tanks take 59-86% of hits, healers heal most.
Partner check (2026-11-26): with a second auto-played hero (`abl.sh tag 100 full <Path> <Class> <Path>`) the cross-role gap
goes away: Sharpshooter+Guardian 144-180 = Guardian+Sharpshooter 151-156, Priest+Guardian 151-171. Companion-mode gaps
between roles come from the weak companions (a damage dealer has no real tank beside it). Compare classes with partners
from now on: Warrior paths with a Ranger Sharpshooter, everything else with a Warrior Guardian.

## Pet pass (2026-11-26)
`tools/sim/runners/petrank.luau` (each pet at level 60 / rank 1 on one hero, party score near where it starts losing, vs no pet;
edit CLASS for a Warrior run). Mage: Common +9-23%, Rare +16-29%, Epic +16-60%, Legendary +30-109%. Fixed the outliers:
Crownling (season prize) +109% -> +86% (Power 1.3 kept: season prizes must out-stat every wishable pet; Royal Decree damage 3.4x, party shield halved: damage + party shield
together was the outlier), Spiritling Power 1.6 (was 2.0), Oathgriffin 1.6 / Aurora 1.25 / Wardenowl 1.2 (were below their
rarity). Defensive pets rank higher on a Warrior (Bannerhound, Thornback +25-29%), as they should.

## Partner checks, converged (2026-11-26)
3 seeds per path, levelled partner (Warrior paths: Ranger Sharpshooter; others: Warrior Guardian), stage at L100 over the
last passes: every path lands in ~120-185, most 140-175, and the same path moves +-20-35 stages between identical passes
(Assassin 154 -> 118 with no change), so differences inside that band are noise. Stop tuning classes from these numbers;
re-check only after a real change. Roles hold (roles.py): damage paths 42-67% of party damage, tanks take 54-70% of hits,
Priest/Templar 76-90% of healing. Boss waits average 0-5 h; boss 90/100 still trap the odd run for ~60 h (1 in 36).
Duelist fix that mattered: its own skills (Riposte 2.8x, Blade Dance 3.8x, Parry taunts), not more stats (105-108 -> 120-147).

## Boss traps (2026-11-26)
Problem: 1 run in 36 sat at boss 90 (Goblin Warlord) or 100 (Spore Mother) for 50-60 h, mostly healer pairs at 100 and
Guardian pairs at 90; 130/140/180 trapped some runs for 15-30 h. The bot now prints `BOSSWHY` lines (boss stages 60+:
lost fights split into timeout / wipe, boss health left, seconds, heroes alive). Every lost boss fight was a WIPE 30-60 s
in with the boss at 20-40% (its enraged half), shorter than a normal frontier fight: bosses hit too hard for their health.

Change: `Config/Stages.BossFightLength = { Health = 1.3, Attack = 0.8 }` on stage bosses only (dungeon, world and season
bosses unchanged; a boss's summons inherit its attack factor). About the same damage race, more time for heals and shields.

| 12 paths x 3 seeds, L100 | before (X2) | after (Z1) |
|---|---|---|
| mean frontier | 151 | 151 |
| boss 90 wait avg / max | 3.4 h / 59.7 h | 0.2 h / 2.5 h |
| boss 100 wait avg / max | 3.5 h / 59.2 h | 0.2 h / 2.2 h |
| worst wait at any boss | 59.7 h | 4.5 h (boss 110) |
| boss first-clear fight (60+) | 66 s | 87 s |

Frontiers after: Berserker 188, Templar 167, Beastmaster 165, FrostWeaver 165, Necromancer 160, Guardian 157, Priest 148,
SpiritCaller 144, Sharpshooter 141, Duelist 132, Pyromancer 130, Assassin 118 (within the +-20-35 noise of earlier runs).
The progress time moved from boss walls into the normal stages; bosses still stop a party briefly (avg 0-0.5 h).
