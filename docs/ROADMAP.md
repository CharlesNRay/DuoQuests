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
- ⬜ Gear and inventory
- ⬜ Rebirth ranks / Legacy progression polish
- ⬜ Daily login rewards
- ⬜ Friend invites and random partner matchmaking
- ⬜ Pacing and balance pass including passives and ultimates
- ⬜ Live-server testing: teleport between places, real DataStore saves
- ⬜ Mobile / tablet / PC playtest pass (UI scale, touch controls, gamepad)
- ⬜ Seasonal reset testing and season rewards

## Done
Newest first.

### 2026-11-15 (overnight, code only, not yet checked in Studio)
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
