# Duo Quest — notes for Claude Code

Roblox co-op idle RPG (Luau, Rojo). Two players fight together (a ghost partner stands in when one is offline), the combat
sim is server-authoritative and deterministic. Read `README.md` and `docs/` (PROGRESSION, BALANCE, SKILLS, ROADMAP) for design detail.

## Working agreements (from the owner)
- Work on branch `claude/overnight-world-systems`, never `main`. Push after each change and verify the remote head matches.
- After testing in Studio: stop Play, click in Studio, Ctrl+S to save. At most 2 Studio instances; leave Studio clean when finished.
- Run edits and commits one at a time (no parallel git).
- The owner sends feedback in small steps; keep replies short, say what changed and what was NOT verified in Studio.
- Never claim UI works unless seen in Studio: much of the UI from 2026-11-15/16 has NOT been seen in Studio yet (list below).

## Layout
- `src/shared` pure game logic + `Config/` data (runs headless). `src/server` Services (ApiService = all client calls as `handlers.X(player, profile, ...)`),
  `src/server/Tests` test suites. `src/client` UI (`UI/Kit.luau` helpers, `UI/Screens.luau`, `Shops.luau`, `Main.client.luau` wiring) and `Battle/` (Hub plaza, Actor, visuals).
- Client state comes from `ApiService.GetState` -> `state.Player.*`. Plaza vendors: `World.PlazaSpots` + `Hub.luau shopNpc` + `Main.client` (`SHOP_NPC`, `PANEL_SIZES`, `Screens.X`, `shopOpen`) + server `nearShop(player, name)`.
- Numbers are big: `Economy.NumberScale = 10`, `XPNumber = 20`; use `Util/NumberFormat.Short` for display.

## Testing and balance (no Studio needed)
`tools/sim/` — see its README. `tools/sim/runall.sh` runs every suite (all must be "0 failed"); `tools/sim/abl.sh` simulates hours of play per class
with parts turned off (`full|nogear|noskill|nopet|nogold|lazy`). Needs the standalone `luau` binary: on the owner's PC it is
`~/bin/luau.exe` (official 0.747 release; Aftman cannot install it because luau tags are "0.747", not semver). Run the scripts with
Git Bash; they find a working Python themselves (`python3`/`python` there are Store stubs; `py -3` works). ~45 s for all 44 suites. New suites go in `src/server/Tests` and
`tools/sim/runners/extra.luau`.

## Systems added/changed 2026-11-15/16 (all tests green, pushed, none verified in Studio)
- **Progression balance**: level power growth x`Economy.LevelGrowth` (0.35); flat gear stats x`Economy.GearPower` (9); Blacksmith +10%/level; Summoner minions x`MinionScale` (0.27).
  Targets (judged with a PARTNER: `abl.sh ... companion` or a class partner, never solo): doing nothing walls at the stage 20 boss; no gear ~stage 16-25; no skills ~30-40; no pets clearly slower; full upgrades stage 40-90 by L40 in 9-12h, L30 in 4-7h. Since 2026-11-16 the game is tuned for pairs (docs/BALANCE.md "Pair balance"): ScalePower 1.6, DefenseScaleExp 0.5.
  Pacing: levels 5-8 at stage 10, 23-28 at stage 30; L30 in ~4-10h (`Economy.EarlyWeak`, power-curve XP in `Progression.XPToNext`).
- **Skills**: effective level = rank + tier bonus (cap 20) + (slot level - 1), capped 40 (`SkillProgress.SlotLevelsFor`, snapshots carry `SlotBonus`). Slot levels bought with gold at the **Skill Trainer** (`Economy.LevelSlot`, handler `LevelSlot`). Copies raise rank; copies of a max-rank skill pay Skill Shards (`Config/SkillProgress.DupShards`).
- **Pets**: pets level from combat (hero XP share, cost x0.5), capped at owner's current level (`Pets.LevelCap`). 4 **pet gear** slots (Collar/Charm/Saddle/Toy) open at pet level 5/10/18/28 (`PetGear`, `Config/PetGear`); mods ride in `Pets.Collection(profile).Mods`. **Pet Store** vendor sells eggs (Pet Wish tickets, 3/day), gear crates, pet food; bosses drop gear (35%). Pets screen has a "Pet gear" view.
- Shop prices are fixed (no per-stage scaling). Starter Pack = 2 skill picks, Enhanced = 4. Skipping the tutorial still pays 10+10 wishes when the stage 10 boss falls (`Tutorial.PayIfSkipped`).
- Auras: layered themed particle recipes in `client/Battle/CosmeticsVisuals.luau`; season prize auras are hidden from the shop until won.
- Other: VIP Game Pass scaffolding (`Passes`, ids are 0), map stage rewards (`StageRewards`), 3-view combat log + damage-by-skill tracker, tutorial rewrite, class-choose enters game, Templar retune.

## Backlog / next steps
0. **Owner feedback 2026-11-17 (not started, do these first):**
   - DONE 2026-11-18 (tests green, NOT seen in Studio): summons now expire after `Minions.Lifetime` (20 s), dead ones are destroyed on the client
     (fading left eyes/decals behind = the "never despawn" pile-up); health uses `Economy.MinionHealthScale` 0.5 (attack keeps `MinionScale` 0.27) so
     tanks live to hold aggro (abl companion: L40 stage 62-68 in 9.4-10h). Boss arena has a "Leave fight" button (skips to results; party fights stay
     held until the server hold ends). Guild raid button says "Battle" (it was already a real auto-combat fight); world/season say "Battle!".
   - DONE 2026-11-18 (tests green, NOT seen in Studio): parties of up to 4 (`Party.MAX_MEMBERS`); every fight has `Party.SEATS` = 4 heroes,
     empty seats filled by companions (`party.Companions`, ids -1..-3; old single `Companion` is migrated away). Join codes last until the
     party is full. Party ultimate = any pair of party classes (`Ultimates.ResolveParty`). Boss/raid/dungeon fights take the whole team
     (`PartyService.GetTeamSnapshots`); state has `Party.Teammates` (Partner = first). Party screen has teammate tabs, Hero screen tabs per
     teammate, HUD shows all teammates. Balance: `Config/Stages.PartyScale` 2.2 (docs/BALANCE.md "Four-hero balance").
     STILL TO DO: balancing pass (Mage lags, Summoner leads); Skills screen "Partner" tab only edits the first teammate; plaza arena pads
     sized for 2; world/season boss + raid numbers (Config/Bosses) not retuned for 4.
   - Studio test cheat (🧪 HUD button, `handlers.DevGrant`) should give much more gold.
   - DONE 2026-11-18 (tests green, NOT seen in Studio): dungeons are one continuous fight (`Simulation` option `Waves`, `Wave` events):
     2-3 waves then a boss, nothing resets between waves. Fixed difficulty (`Stage`) and recommended `Level` per dungeon, 4 dungeons
     (Crypt/Foundry/Abyss/Spire). Daily bonus: first full clear of each dungeon per day (`Activities.DailyBonus`). `abl.sh` prints
     `DUNGEON` lines (5 tries at the recommended level): a pair wins once its frontier is ~8 stages past the dungeon's Stage.
1. **Studio verification** of everything unseen. Seen and working (2026-11-16 evening): class-choose flow, tutorial card, Skill Trainer
   (train a slot), Pet Store (egg, crate, snack; header shows what a crate gave), feeding pet food (Bag > Stash), Pets detail card,
   Pets > Pet gear (wear/remove), map claim badges + Claim all, combat log 3 views, Flame aura on the hero, Store tabs, VIP row,
   Battle hub, dungeon run (victory card), expedition send. Still unseen: expedition collect, season auras once won, the other
   auras/kill effects, tutorial arrow steps past 1, pet follower, guild raid / world + season boss screens.
   Open UI nit: the map badge hover tooltip has not been seen.
   Watch for: tables keyed by numbers with gaps do not survive remotes (pet gear Equipped and StageClaims were hit); ✔ and newer emoji (🪙 🪢 🪦, Unicode 13+) do not render.
   Balance questions for the owner: Market "Pet Food x5" = 2,304g vs Pet Store Pet Snack 6,900g each (same item); one Forgotten Crypt run
   at stage 6 paid ~9.7K gold (3 keys/day). (and season auras), tutorial arrow/card, combat log views, map claim badges, tooltips, class-choose flow, pet follower, Battle hub dungeons/expeditions, Market tab, VIP row. Rojo must be reconnected via VS Code first.
2. Test hero in `tools/sim` does not yet use pet gear, pet food or pet leveling; pets are probably worth more than the numbers show. Check replay Wishstone income (maybe too generous).
3. Restyle remaining screens (Hero, Skills, Party, Bag, Map, Quests, Boss, Store, Wish) in the card/detail style. VIP second pet slot done 2026-11-16 (`Pets.Second`, support pet: its stats count, only the main pet fights; Pets screen "Set 2nd"; not seen in Studio).
4. Not started: stack counts on monsters, guild chat, gifting, cosmetics try-on; show an on-screen notice for the skipped-tutorial payout.
5. Owner-side: create the VIP Game Pass + Sunstone Developer Products and give the ids (`GamePassId`/`ProductId` are 0); upload `branding/logo.png` and set `Config/Branding.LogoImage`.
6. `docs/ROADMAP.md` only covers up to the 2026-11-16 morning entry; add the items above.

## Gotchas
- Studio testing: the HUD 🧪 button grants test gold/items and ⬆ gives +5 levels (Studio only). Vendor prompts need you within 14 studs;
  teleport from the command bar (Client view): `game.Players.LocalPlayer.Character:PivotTo(CFrame.new(x, 4, z))` - Trainer (13.5, -5), Pet Store (-13.5, -5).
  The command bar has its own module cache, so `require(DataService).GetProfile` there returns nil.
- Don't launch Studio via the Start menu while it is open: it starts a second instance (close it).
- Hook message "N unpushed commits" can be a stale tracking ref: compare `git ls-remote origin <branch>` with `git rev-parse HEAD`.
- Test files use `warn or print`; `warn` is nil in the headless harness.
- Pet level shown/used = min(stored level, owner level); a new season (owner back at level 1) shows pets low until the hero catches up; stored level is kept.
