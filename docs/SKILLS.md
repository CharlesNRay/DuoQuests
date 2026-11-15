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
  cap. It sets how much power each slot level adds (8% / 10% / 12%) and how
  strong the skill's base numbers are.
- **Skill ownership, loadouts and slot levels reset each season**
  (`OwnedAbilities`, `Loadouts`, `SlotLevels` live in the Season section).
- Prototype classes: **Warrior** (tank) and **Cleric** (healer). Mage is kept
  in config but not unlocked.
- Each class has 8 skills: 4 Common, 2 Rare, 2 Epic, with damage and role
  skills. Each class starts owning its 4 Common default-loadout skills.

## Decided, not built yet

- **Veterans stay marginally stronger through titles and cosmetics.** A title
  can grant a small, capped character buff, applied in `StatCalc` so the
  combat code never needs to know where it came from. Titles and cosmetics are
  permanent; skills and levels are not.
- **Pets are combatants** (like Ulala and Go Go Muffin) that buff their owner.
  Pet rewards are granted at the start of the next season, based on milestones
  reached in the previous one.
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

- Can pets be targeted by enemies, or are they untargetable support?
- Starting shard costs per rarity.
- Slot position is also casting priority, so levelling a slot makes that
  priority slot stronger. Is that coupling acceptable?
- Title buff cap (suggest at most a few percent total).
