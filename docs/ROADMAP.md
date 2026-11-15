# Duo Quest Roadmap

> Living document. Updated whenever we finish or reprioritise something.
> **Last updated:** 2026-11-15

**Jump to:** [Now](#now) · [Next up](#next-up) · [Later](#later) · [Done](#done) · [Open questions](#open-questions) · [Known gaps](#known-gaps)

Status key: ✅ done · 🔨 code written, not yet checked in Studio · ⬜ not started

---

## Now
What we are working on this week.

| Status | Item | Notes |
|---|---|---|
| 🔨 | Spawn in the world, in front of your arena, walking (not battle view) | Changed 2026-11-14 |
| 🔨 | World map: pick any unlocked stage to farm | Map button + `SetStage`; tests pass, UI unseen |
| 🔨 | Shared hub: other parties' live arenas, info cards | Walk / Battle view toggle confirmed working |
| ⬜ | Studio check of hub + map, fix what breaks | Needs Rojo connected, Stop → wait → Play |

## Next up
In rough order.

- ⬜ **Real assets** from free Studio sources: monsters, pets, scenery (replace placeholder shapes)

## Later
- ⬜ Pets as combatants
- ⬜ Rebirth ranks / Legacy progression polish
- ⬜ Friend invites and random partner matchmaking
- ⬜ Pacing and balance pass including passives and ultimates
- ⬜ Live-server testing: teleport between places, real DataStore saves
- ⬜ Mobile / tablet / PC playtest pass (UI scale, touch controls, gamepad)
- ⬜ Seasonal reset testing and season rewards

## Done
Newest first.

### 2026-11-15 (overnight, code only, not yet checked in Studio)
- 🔨 Gear and inventory: Weapon / Armor / Trinket drops from stages (rarity rolls, boss drops, ItemRarity passive helps), bag of 30 (full bag sells new drops), equip / unequip / sell, ghost partners keep their gear, Gear screen (29 tests with daily login)
- 🔨 Daily login: 7-day streak cycle with rewards that scale with your frontier, Daily screen
- 🔨 Leaderboards: furthest stage and highest level per season (ordered DataStore), Ranks screen, and a sign in the hub (10 tests; live-server saving untested)
- 🔨 Pets: 4 pets (Slimey, Foxling, Mossback, Spark Wisp) earned by clearing stages, kept every season, levelled with gold, small combat bonuses; shown beside heroes in the world and on arena cards; Pets screen; ghost partners fight with their pet (22 tests)
- 🔨 Click-to-inspect on heroes and other players' avatars (class, level, pet, skills, passives, party stage)
- 🔨 See-through ghost figure for an offline partner
- 🔨 Boss-stage banner in your own arena

### 2026-11-14
- ✅ Walk / Battle view camera toggle (confirmed working in Studio)
- 🔨 Shared hub world: arena slots, world snapshots, live fight broadcast to other players (`World`, `WorldService`, `Arenas`, `BattleCamera`)
- 🔨 World map screen and party stage selection with farming (`Party.SetStage`, 6 new tests)
- ✅ Rojo restarted and connected; project folder open in VS Code

### Earlier (before 2026-11-14; exact dates not recorded)
- ✅ Dedicated Roblox place `DuoQuest.rbxl` for the project (kept out of git)
- ✅ 3D battle scene with side view, real avatars (when loadable), monsters, damage numbers, skill effects
- ✅ Zones that change after bosses (4 themes, 10 stages each)
- ✅ Responsive UI for phone, tablet and PC
- ✅ Server API (`Api` remote, rate limited) and client UI: Skills, Passives, Ultimate, Party
- ✅ Two-player parties: codes, ghost partner while offline, ghost skill edits, revert
- ✅ Server-authoritative combat; fights replayed as animation on clients
- ✅ Classes (Warrior, Cleric), skills, passives, party ultimates, rarities
- ✅ Progression, economy, offline AFK, seasons
- ✅ Headless test suites (profile, combat, abilities, stages, parties, pacing, presentation)

## Open questions
- Where should leaderboard data live (global ordered DataStore vs per-server)?
- How many arenas per server before we cull animation more aggressively?
- Pet design: cosmetic only, or fighters? (Currently planned as fighters later.)

## Known gaps
- Studio runs with in-memory data, so nothing is saved there.
- Real-avatar loading on the client is unverified; a plain body shows otherwise.
- Pets, balance numbers and passive/ultimate values are placeholders.
- Teleport and real DataStore paths are untested.
- Docs: design decisions live in `docs/PRESENTATION.md`; setup in `README.md`.


## 2026-11-15 (overnight additions)
- [x] Subclasses: Berserker/Guardian (Warrior), Priest/Templar (Cleric). Unlock at frontier stage 30, permanent per season, 3 skills each (first free, rest via shards). Tiered `Parent` links allow deeper branches later.
- [x] Starter ghost companion: single-member parties get a ghost partner (Cleric, or Warrior for Cleric owners) that mirrors the owner's level, is editable via ghost loadout, and is replaced when a real partner joins.
- [x] Balance pass 2026-11-15 (gear and subclass numbers cut, sim bug fixed) - see docs/BALANCE.md
- Open questions: respec for subclasses, deeper branches, stronger pets, pets as combatants.

## 2026-11-15 (pacing and bosses)
- [x] Level pacing retuned to the owner's goals (lv10 ~12m, lv20 ~27m, lv30 ~1h) - docs/BALANCE.md
- [x] Subclass unlock moved to player level 30; enemies step up after floor 30
- [x] Boss mechanics: fixed-timer heavy attacks with telegraph warnings, minion summons, enrage; 3 bosses (Slime King, Goblin Warlord, Spore Mother)
- [ ] Hand-check floor 40 (Slime King, stronger) and later bosses; add more boss types and a boss info card showing their attack timings
- [ ] Simulator: smarter skill choice and a companion mode

## 2026-11-15 (first Studio test)
- [x] Played in Studio with Rojo: hub, HUD, Skills, Party (ghost Cleric loadout), Pets, Daily, Gear, boss floor 10 with the ghost Cleric all work; no errors in the output.
- [x] Fixed: panels drew blank (UI layering mode), Map screen drew over the previous panel, gear stats showed +0.
- [ ] Not yet seen in Studio: slimelet spawns on screen, Warlord/Spore Mother fights, subclass choice at level 30, leaderboards board, inspect click, world map on a second player.

## 2026-11-15 (UI overhaul, checked in Studio)
- [x] HUD laid out Roblox-style: portrait with XP + gold/shards top-left, zone/stage top-centre, character rail (Skills, Passives, Pets, Party) left, world rail (Map, Gear, Bag, Daily, Ranks) right, Fight log + Battle view bottom-right, party cards bottom-left, skill bar bottom-centre. Red dots on Skills (picks/subclass), Daily (claimable), Party (no party).
- [x] Ultimate is no longer a button: a charge gauge under its icon fills with the same rules as the sim and pulses when it fires; the ultimate is picked in the Party screen.
- [x] World interactables (home base in front of your own arena): World Map board, Rankings board, Daily Gift chest (ProximityPrompts). Every arena has a gold "Watch battle" pad: step on it and use the prompt to watch anyone's fight; a "Stop" bar returns the camera. Your own pad reads "Battle view".
- [x] Bag is its own screen; Gear shows worn pieces plus a Sets tab (collection per zone with bonuses). Hovering an item shows a tooltip and tints the row green (better, or completes a set bonus) or red (worse, or loses a set bonus).
- [x] Gear sets: one per 10-stage zone, drop only in that zone (boss floors most), stronger than normal gear there, 2/3-piece bonuses.
- [x] Skill icons (generated glyph tiles by effect kind, rarity border) with hover tooltips in Skills, the skill bar and the partner's loadout; passive/ultimate tooltips too.
- [x] Last-fight log (Fight log): timestamped casts, boss telegraphs ("lands at" times so a shield/heal can be timed), summons, deaths, ultimate; toggle for every hit.
- [x] Per-zone scenery: ground material, sky gradient, themed props (cacti, snow pines, lava rocks, dead trees, pillars, clouds, crystals...) and foreground decor for all 10 zones.
- [x] Bug found and fixed: the server was not sending Spawn/Telegraph/Status events, so minions and boss warnings never reached the client.
- [ ] Not yet checked: Sunken Ruins / Cloud Spire scenery, touch devices (tooltips are written for tap), two real players watching each other, set-bonus hover text on a real set piece.
- [ ] Owner's "more" list is still to come.
