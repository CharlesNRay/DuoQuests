# Skills design notes

Living notes on the skill system. "Decided" items are implemented; "Open"
items are waiting on a design decision.

## Decided and implemented

- A character has **one automatic basic attack** (class-specific) and **four
  equipped active skills**. Skills cast automatically on cooldown when their
  conditions are met. Slot order is casting priority, one cast per tick.
- Players can **swap** equipped skills. The server validates every equip
  request (`Skills.ValidateLoadout`): max four, no duplicates, class skills
  only, owned only.
- **Skills are class-locked.** Each class has its own pool.
- **Levels belong to the slot, not the skill** (like Go Go Muffin). Swapping a
  skill keeps the slot's level. Every slot shares one cap (20 for now,
  `Skills.MAX_SLOT_LEVEL`). Stored as `Season.SlotLevels[classId]`.
- Skills have a **rarity** (Common, Rare, Epic). Rarity no longer sets a level
  cap. It sets how strong the skill's base numbers are, and the fallback power
  growth for simple effects (8% / 10% / 12% per level).
- **Every skill grows its own stats per level** (not just damage). Each effect
  lists a `PerLevel` table (`Config/Abilities`, resolved in
  `Combat/AbilityStats`): damage skills grow damage, shields grow size and
  duration, buffs grow duration and **Strength** (how far the buff moves the
  stat), heals grow healing, and cooldowns can shrink (`CooldownPerLevel`,
  with a `MinCooldown` floor). The UI reads the same numbers through
  `AbilityStats.Rows`, so what the player sees is exactly what combat does.
- **Resurrection (Cleric, Epic) can be cast once per combat**
  (`UsesPerCombat = 1`). It needs a fallen ally and a living Cleric, so it
  cannot rescue a wiped party. It revives at 35% max health at level 1, up to
  82.5% at level 20. Works the same when the Cleric is a ghost.
- **Skill ownership, loadouts and slot levels reset each season**
  (`OwnedAbilities`, `Loadouts`, `SlotLevels` live in the Season section).
- Prototype classes: **Warrior** (tank) and **Cleric** (healer). Mage is kept
  in config but not unlocked.
- Warrior has 8 skills (4 Common, 2 Rare, 2 Epic); Cleric has 9 (Resurrection
  is a third Epic). Each class starts owning its 4 Common default-loadout
  skills.
- **Passives:** class-specific buffs that are always active. A player equips up
  to **3** (slots unlock at frontier 1 / 20 / 50, so you start with 1). They
  are chosen by goal: damage, defense, healing, gold, XP or item rarity.
  Passive levels belong to the **slot** (cap 20, gold cost), like skills, and
  each passive grows its own stat. Passives are **unlocked by reaching a
  stage**, not bought, so there is no ownership state to save. Everything
  resets each season (`PassiveLoadouts`, `PassiveSlotLevels`). New players
  start with their class's first passive equipped. Combat passives are small
  on purpose (pacing was tuned with them on); gold and XP passives scale the
  clear and AFK rewards, and item rarity is stored for when items drop.
- **Party ultimate:** one move that BOTH members use, decided by the
  combination of their classes (`Config/Ultimates`). The party shares a gauge
  that fills with time and with every skill either member casts, and the
  ultimate fires automatically when full. Each class pair has several
  ultimates, unlocked by the **party frontier**. The party equips one and
  either member can change it (`Party.SetUltimate`), like the ghost loadout.
  Its level is the average slot level of the two members. A lone member (no
  partner yet) has no ultimate.
- **Seeing your partner's build:** the partner loadout popup shows their
  skills, passives, pet and gear. Only the **skills and their order** can be
  edited (the ghost loadout). Passives, pet and gear are view only.

## Decided, not built yet

- **Veterans stay marginally stronger through titles and cosmetics.** A title
  can grant a small, capped character buff, applied in `StatCalc` so the
  combat code never needs to know where it came from. Titles and cosmetics are
  permanent; skills and levels are not.
- **Pets are combatants** (like Ulala and Go Go Muffin). They **attack and
  have their own skills**, and buff their owner. They have **no HP and cannot
  be targeted or killed**. Pet rewards are granted at the start of the next
  season, based on milestones reached in the previous one. **Both players have
  a pet** (shown in the battle HUD). A future class could buff pets.
- **Slot position is casting priority and carries the slot level** (accepted
  for now).
- **Title buffs can be stronger and affect more than one stat.** Still capped
  so veterans are ahead, not untouchable.
- Skill Shard costs: Epic about 3-4x Common (accepted).
- **Pacing target:** after about a week of play a player owns every skill for
  their class, but slots are nowhere near max level and builds are not
  min-maxed.
- **Acquisition must not force farming old bosses.** No skill is tied to a
  specific boss drop. See the proposal below.

## Skill list (placeholder numbers)

| Class | Skill | Rarity | What it does |
|---|---|---|---|
| Warrior | Shield Bash | Common | Damage + Fortified (defense) |
| Warrior | Taunt | Common | Enemies must target the Warrior for 6s |
| Warrior | Iron Skin | Common | Large defense boost for 8s |
| Warrior | Whirlwind | Common | Damage to all enemies (needs 2+) |
| Warrior | Shield Wall | Rare | Shield (30% max HP) + Fortified |
| Warrior | Crushing Blow | Rare | Heavy single-target damage |
| Warrior | Last Stand | Epic | Cannot die for 4s (below 50% HP) |
| Warrior | Rallying Cry | Epic | Party defense boost |
| Cleric | Heal | Common | Heals the most wounded ally (below 70%) |
| Cleric | Smite | Common | Holy damage to one enemy |
| Cleric | Blessing | Common | Party attack boost |
| Cleric | Radiant Burst | Common | Damages enemies, heals allies |
| Cleric | Divine Shield | Rare | Shields the most wounded ally |
| Cleric | Group Heal | Rare | Heals the whole party (below 60%) |
| Cleric | Guardian Angel | Epic | Protects a dying ally from death |
| Cleric | Judgment | Epic | Huge holy damage to one enemy |
| Cleric | Resurrection | Epic | Revives a fallen ally. Once per combat |

Each skill's stats at every level come from its `PerLevel` entries in
`Config/Abilities` (for example Shield Bash: damage 140% + 10% per level,
cooldown 6.0s - 0.1s per level; Shield Wall: shield size and duration;
Iron Skin: duration and Strength).

## Passive list (placeholder numbers)

| Class | Passive | Unlocks at stage | What it does |
|---|---|---|---|
| Warrior | Iron Hide | 1 | + defense |
| Warrior | Treasure Sense | 10 | + gold gained |
| Warrior | Brute Force | 20 | + damage dealt |
| Warrior | Vitality | 30 | + max health |
| Warrior | Quick Study | 40 | + XP gained |
| Warrior | Fortune Seeker | 60 | + item rarity |
| Cleric | Holy Light | 1 | + healing done |
| Cleric | Tithe | 10 | + gold gained |
| Cleric | Devotion | 20 | + attack |
| Cleric | Warding | 30 | - damage taken |
| Cleric | Scholar | 40 | + XP gained |
| Cleric | Providence | 60 | + item rarity |

## Ultimate list (Warrior + Cleric, placeholder numbers)

| Ultimate | Unlocks at party frontier | What it does |
|---|---|---|
| Sanctified Charge | 1 | Holy damage to all enemies + heals the party |
| Bulwark of Dawn | 40 | Shields the party + slows every enemy |
| Radiant Judgment | 80 | Huge holy damage to all enemies + party attack buff |

## Research notes

- Go Go Muffin (one leveling guide): leveling is tied to the skill SLOT, not
  the skill, and swapping a skill keeps the slot's level. Bonuses arrive at
  every fifth level. The page did not cover how skills are obtained.
- Ulala: the pages found did not describe skill acquisition in detail (one
  mentions a "yellow" skill from a daily-quest wishing well). We are not
  copying a specific system; the acquisition design below is our own.
- Roblox paid random items policy
  (https://create.roblox.com/docs/en-us/production/monetization/paid-random-items):
  anything random bought with Robux, or with currency bought with Robux,
  needs every outcome and its exact odds shown before purchase, pity systems
  count as probability modifiers, and restricted regions must be offered a
  free or fixed alternative (`PolicyService`). Random rewards earned by
  playing, without payment, need no disclosure.

## Proposal: how skills are acquired (frontier-based)

Goal: progress pushes players forward, never back to old content.

1. **Skill Shards** are a generic currency earned from the stage you are
   currently pushing, with a bigger payout on a boss clear. Rewards scale up
   with stage, so the frontier is always the best place to be.
2. **Unlock by choice:** spend shards to unlock any skill from your class pool.
   Cost depends on rarity (Common cheap, Epic expensive). Players pick what
   they want, so there is no random pull and no duplicates.
3. **Milestone first clears** (new stage ranges) grant a free pick, so pushing
   forward is always rewarded even if shards run dry.
4. **Gold levels the slots.** Levels cost gold only.
5. **Monetization:** fixed-price items and convenience, not random skill pulls.
   If Robux ever buys random items, Roblox's paid-random-items rules apply:
   show all outcomes and exact odds before purchase, and offer a free or fixed
   alternative in restricted regions.

Tuning goal: costs are set so a normal week-one player unlocks all 8 skills.

Questions still open:

- Passive and ultimate numbers are placeholders. The auto-player in
  `BalanceTool` does not buy passives or ultimates yet, so a refit of the
  pacing model should include them.
- Passive slot unlock stages (1 / 20 / 50) and passive unlock stages are
  guesses.
- More class pairs need ultimates when more classes arrive.
- Should the game have a rebirth system on top of the seasons? (discussing)
