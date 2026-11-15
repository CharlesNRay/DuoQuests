# Duo Quest

A cooperative idle RPG for Roblox built around persistent two-player parties,
automated combat, seasonal resets and capped permanent account progression.

Built with Luau and synced into Roblox Studio using Rojo.

## Layout

```
default.project.json         Rojo project file
src/
  shared/                    -> ReplicatedStorage.Shared
    Config/                  data-only modules
      Classes, Enemies       combatant definitions (Warrior, Cleric; Mage later)
      Abilities, Statuses    skills and the timed effects they apply
      Rarities               Common/Rare/Epic: power gained per slot level
      Seasons                current season
      Stages, Economy        stage layout; every reward and cost number
      Offline                AFK rate tiers (50% first 12 h, then less)
      Zones                  regions (10 stages each, boss last): name, colours, scenery
    Combat/                  pure combat simulation (no Roblox APIs)
      Simulation             fixed-tick, deterministic fight between two teams
      Hooks                  event hooks that seasonal mechanics plug into
      Entity, StatCalc, Rng  combatants, stat building (skills + passives), seeded randomness
      AbilityStats           each skill's per-level numbers (used by combat and the UI)
    Util/                    helpers (TableUtil)
    Skills.luau              equipping rules and slot level cap (4 slots)
    Passives.luau            passive slots, unlocks, equip rules, stat totals (3 slots)
    Ultimates.luau           which party ultimates a class pair can use
    Stages.luau              what each stage contains (every 10th is a boss)
    Zones.luau               which zone a stage belongs to
    Remotes.luau             names of the client/server remotes
    Progression.luau         XP, levels, clear rewards, frontier, milestones
    Economy.luau             spending: unlock skills, level slots, equip
    StageRunner.luau         runs one stage fight and applies rewards
    Party.luau               two-player party: ghosts, shared stage, claims, AFK
    Offline.luau             estimates AFK gains from a saved party
    ProfileTemplate.luau     shape of a player profile
docs/
  SKILLS.md                  skill design decisions and open questions
  server/                    -> ServerScriptService.Server
    Main.server.luau         starts services, connects players
    Services/DataService     session-locked loading and saving
    Services/PartyCore       party saving, hosting, join codes, leave (no Roblox APIs)
    Services/PartyService    runs parties: stage loop, rewards, DataStores
    Services/ApiService      the doorway for the UI: checked requests, fight pushes
    Tests/                   run from the Studio command bar
  client/                    -> StarterPlayerScripts.Client
    Main.client.luau         builds the UI and 3D scene, listens for fights
    UI/                      Kit (helpers), Hud, Screens (skills/passives/ultimate/party)
    Battle/                  3D side-view battle: Scene, Models, Actor, Replay
```

## How combat is extended

- New ability: add an entry to `Config/Abilities` (cooldown, conditions, effects, and
  a `PerLevel` table so it grows its own stats).
- New passive: add an entry to `Config/Passives` and list it in the class's `PassivePool`.
- New ultimate: add an entry to `Config/Ultimates` and list it under its class pair.
- New status: add an entry to `Config/Statuses` (stat modifiers and/or flags).
- New effect type or condition: register it with `Simulation.Effects` or
  `Simulation.Conditions`; no edits to the simulation itself.
- Seasonal mechanics: register handlers on the hooks listed at the top of
  `Combat/Simulation.luau` (`OnCalculateDamage`, `OnAbilityCast`, ...).

## Working on it

1. Install Rojo (VS Code extension + Studio plugin).
2. Open this folder in VS Code (File > Open Recent), click **Rojo** in the status bar and
   start the server for `default.project.json`. If you change `default.project.json`,
   stop and start it again.
3. In Studio, open `DuoQuest.rbxl` (a Baseplate saved in this folder; git ignores it) and
   click **Connect** in the Rojo plugin.
4. Changes to files sync into Studio automatically. Stop Play, wait a few seconds, then
   Play again to see edits.

File naming: `Name.luau` = ModuleScript, `Name.server.luau` = Script,
`Name.client.luau` = LocalScript.

## Tests

In Studio's Command Bar (View > Command Bar):

```lua
require(game.ServerScriptService.Server.Tests.ProfileTests)()
require(game.ServerScriptService.Server.Tests.CombatTests)()
require(game.ServerScriptService.Server.Tests.AbilityTests)()
require(game.ServerScriptService.Server.Tests.StageTests)()
require(game.ServerScriptService.Server.Tests.PartyTests)()
require(game.ServerScriptService.Server.Tests.PartyCoreTests)()
require(game.ServerScriptService.Server.Tests.SkillStatsTests)()
require(game.ServerScriptService.Server.Tests.PassiveUltimateTests)()
require(game.ServerScriptService.Server.Tests.PresentationTests)()
require(game.ServerScriptService.Server.Tests.PacingTests)()
```

See [docs/ROADMAP.md](docs/ROADMAP.md) for what's done and what's next.
