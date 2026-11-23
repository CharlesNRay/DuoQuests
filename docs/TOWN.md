# Town plan (draft 2026-11-23, for the owner to approve)

Goal: while the party auto-fights on its lot, the player has reasons to walk around town and talk to NPCs.
Town play must never be needed to progress: it gives a little extra (target: at most ~10% of a day's Wishstones and gold),
plus cosmetics, titles and pet treats. Combat stays the main way to get stronger.

## Size and layout
Today: a plaza (radius 70) with the shops around its ring, the Wishing Tree just outside it (south-west), and the lots
to the north. Plan: keep the plaza as the shopping square and add **three small districts** around it, joined by a ring road
about 110-150 studs from the fountain.

- Every district is within **~10-15 seconds' walk** of the fountain (normal walk speed is 16 studs/s). That makes the town
  feel bigger without being spread too thin.
- Signposts at every fork, and district names on the Map screen.

```
                 LOTS (north)
          ┌───────────────────────┐
          │     lot rows (8)      │
          └──────────┬────────────┘
     WEST            │ road            EAST
  Wishing Grove   ┌──┴──┐        Training Grounds
  pond, pet park ─┤PLAZA├─ ring ─ dummy, sparring ring,
  Wishing Tree    │shops│         guild hall
                  └──┬──┘
                     │
               SOUTH: Town Gate
         spawn, notice board, tavern
```

## Districts and what to do there
### South: Town Gate (where you arrive)
- **Notice board, with 3 daily town bounties:** for example "catch 3 fish", "bring Old Maren her lost cat", "find 2 relics".
  Reward: a few Wishstones and an XP Tonic. Uses the existing quest/daily tracking.
- **Tavern, with 4-6 named townsfolk who give short errand chains** (fetch, deliver, talk to someone in another district).
  These send players across town. Rewards: gold, titles ("Friend of the Forge"), and now and then a cosmetic.

### West: Wishing Grove (moves the Wishing Tree into a proper garden)
- **Fishing pond: a quick timing minigame.**
  - Common fish sell at the Merchant or become pet food (Pet Snack).
  - Rare fish go in a collection log, and a full set gives a trophy and a title.
  - Rare catches are capped per day, so fishing can't become the best gold source.
- **Pet park: your active pet runs free.**
  - Petting it or throwing a ball gives a small amount of pet XP. There's a cooldown, and it's capped per day.
  - Pets of other players' parties show up here too, which makes the town social.

### East: Training Grounds
- **Training dummy: hit it to run a 15-second fight with your exact build** (the same server sim as real fights).
  - It shows damage per second, by skill. It's a tool for trying loadouts and runes, not a reward source.
- **Sparring ring: a friendly duel between two players' heroes, decided by the sim.** For fun only; it gives no rewards.
- **Guild hall:** guild chat board, the guild raid entrance, and a trophy wall.

### All over town: hidden relics
- 25-30 small glowing relics in corners, on roofs and behind buildings. A few new ones show up each day, and each one is
  found once per player.
- Collecting sets unlocks an aura or a title. There's a "Relics 12/30" log on the Map screen.

## Rules for every activity
- **Server checks everything.** Being near a spot uses `World.NearShop`-style distance checks with new
  `World.TownSpots`; caps and cooldowns are stored on the profile; rewards come from the server only.
- **Client-built parts, like the plaza today** (no server cost). Activities run while the party keeps fighting, and the
  combat log and HUD stay up.
- **Every new reward goes into the sim bot** (`abl.sh`), so we can check that town income stays under the ~10% target.
- **No new emoji newer than Unicode 12** (newer ones don't render).

## Build order (each phase: tests green, pushed, then you check it in Studio)
1. **Layout:** ring road, the three districts as scenery, signposts, district names on the map, Wishing Tree moved into
   the Grove. No new gameplay yet: you check that it feels the right size.
2. **Notice board and tavern errands:** the cheapest real gameplay, and it gets players walking.
3. **Fishing pond and pet park.**
4. **Training dummy** (and the sparring ring if you want it).
5. **Hidden relics and their collection log.**

## Questions for you
1. Rewards: is "small Wishstones/gold, plus cosmetics and titles" right, or should town play give **only** cosmetics
   and fun (no power at all)?
2. Fishing and the pet park: keep both, or just one?
3. Sparring ring between players: wanted, or skip it?
4. Size: is ~10-15 seconds' walk from the fountain to each district right, or should it be bigger or smaller?
