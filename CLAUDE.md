# Idle Party Quest (formerly Duo Quest) — notes for Claude Code

Renamed 2026-11-23: only player-visible text says Idle Party Quest (menu title, town gate, tutorial). 2026-11-24 (before any real player had a save): internal names renamed too. Instances/remotes `IdleParty*` (e.g. `IdlePartyRemotes`), sound groups and lighting `IPQ_*`, every DataStore `IPQ_*` (`IPQ_PlayerData`, `IPQ_Parties`, `IPQ_PartyCodes`, `IPQ_Guilds`, `IPQ_SeasonBoss`, `IPQ_Playtest`, `IPQ_SeasonResults`, `IPQ_SeasonHist_S<n>`, `IPQ_Leaderboard_S<n>_*`), log prefix `[IdlePartyQuest]`. Do NOT rename DataStores again once the game is live (that loses every save). Repo/folder and place file are still called DuoQuest(s). SEEN in Studio 2026-11-24: boots, new character, fights run. SEEN in Studio 2026-11-23: menu title "IDLE PARTY ⚔ QUEST" fits, gate reads IDLE PARTY TOWN; tutorial welcome card seen too.
- **Main menu 2026-11-23** (SEEN in Studio): menu battle is 4 heroes (Warrior in your avatar, Mira, Ilsa, Wren), fights retuned to stage 9-13
  (the old ones wiped in 1 s); the menu is centered on big screens (UIScale grows around the middle, Body is now anchored 0.5);
  title centered by text width. **Extra Character Slots** Game Pass (`Config/Premium.Passes.CharacterSlots`, 149 R$, `Characters.Max(profile)`
  2 -> 4): a locked card on the menu sells it ("coming soon" until the id is set), also listed in the Store; Test cheats "Toggle +2 char slots".
  Back to the menu from in-game: Settings (⚙️) > "🏠 Main menu" (SEEN in Studio; CONTINUE returns, fights keep going). Boss name tags
  (world/season boss) have MaxDistance 400: they are AlwaysOnTop and showed through everything, even over the menu.
- **HUD size + headshots 2026-11-23** (HUD size SEEN 2026-11-24): Settings "HUD size" 70-130% scales only the HUD layers
  (`hud:SetScale`, Chrome/Combat stretched by 1/scale) and the combat log (`LogLayer`, shorter at bigger sizes); panels keep
  the fit scale (panels taller than RefH 400 get cut off: Settings is 620 x 392). Saved as `Permanent.Settings.HudScale`; HUD portrait shows your Roblox headshot with the level in a
  corner chip; party rows show real players' headshots ringed in class colour (companions keep the class dot).
- **Homes street + Market ring 2026-11-24** (SEEN in Studio, with 3 fake teams run from the command bar): lots stand on both
  sides of a street from the plaza (`World.HOMES_STREET` angle 145, pairs at 162 / 234, lateral 39), fronts facing the street,
  so none hides behind another (the 2 x 2 block did). Slots 5-8 later continue down the street through a new wall gate.
  Each taken lot has an owner sign at its street edge, side-on so you read it walking by ("X's home" / "with ..."; Arenas
  `makeOwnerSign`); open lots' signs stand the same way. Fight back strip `World.APRON_DEPTH` 12 (was 24). Arenas are CFrames:
  `World.ArenaOrigin` returns a 4th value yaw, `Arenas:OriginOf` a CFrame, `Scene.Frame` (place fight things with
  `scene.Frame * ...`, not `Origin + Vector3`), BattleCamera takes a CFrame. Shops stand in a ring round the Market square
  (`PlazaSpots.X.Market` = angle, `World.MARKET_RING` 34, `World.ShopLook`), maypole + bunting in the middle.
- **Biomes + backdrops 2026-11-24** (SEEN in Studio via a 20-scene gallery built from the command bar): 20 zones now (stages
  1-200, then loop). 101-200 are elemental/magical: Stormspire (lightning flashes), Tidal Deep, Phoenix Pyre, Glowshroom
  Hollow, Aurora Wastes, Astral Expanse, Void Rift, Radiant Sanctum, Slime Meadows (owner idea; boss = Rainbow Slime via
  `Config/Zones` `Boss`, a crowned rainbow-cycling slime), Arcane Archive. Backdrops are silhouettes from
  `client/Battle/Backdrops.luau` (zone `Backdrop` style: wedge-ridge mountains with caps, hills with trees, mesas, volcano,
  ruins, floating islands, crystals...; `fx` "Bolt"/"Wave" animate in `Scene._update`); puffy clouds (`NoClouds`, `CloudColor`).
  Zones 11-20 have their own monsters (`Config/Stages.ZonePools` 11-20, 30 new enemies) and bosses (`Config/Zones Boss`):
  Thunder Titan, Leviathan, The Phoenix, Elder Mycelid, Frost Wyrm, Astral Watcher, Void Herald, Solar Archon, Rainbow Slime,
  Arcane Lich (existing body shapes + new Look extras Material / Transparency / Glow, applied in `Models.Enemy finish`;
  existing enemy abilities only). Battle view tints the sky per zone (`client/Battle/ZoneLighting`: zone ClockTime + Haze,
  night zones get a brighter fill + exposure; Clear on leaving battle view). SEEN in Studio with command-bar demo fights.
- **Mastery talents 2026-11-24** (SEEN in Studio: locked row at L80, open at L100): 4 talents x 10 ranks open at level 81
  (`Config/Talents` Unlock/Mastery): Onslaught (DamageDealt), Fortitude (DamageTaken -1.2%/rank), Party Spirit (Mode "Party":
  ranks of everyone in the fight add up, +0.5% Attack and Health per rank for the whole party, `StageRunner.NewParty`,
  ghost snapshots carry `PartySpirit`), Fortune (Mode "Reward": +2% gold and XP per rank in `Progression.ApplyClear`).
  Talents panel is 660 x 392 (RefH is 400: taller panels get cut off).
- **On Roblox 2026-11-24**: the owner used Save to Roblox; the experience is "Idle Party Quest" (private), Studio API access ON
  (saves now persist between Studio runs). Ctrl+S in Studio now saves to Roblox, not only the local .rbxl.
- **Wish sounds 2026-11-24** (all 12 ids load in Studio; nobody has listened yet): `Config/Audio` Wish* + `UI/WishAnim`
  (fall, charge pitched by best rarity, burst, flip per card, ding Rare, chimes Epic; Legendary = music duck + heartbeat +
  drum roll, boom + orchestra hit, NEW adds harp + fanfare). `Sound.Play` returns the Sound, `Sound.Stop`, `Sound.Duck`.
- **8 lots + overflow 2026-11-24** (SEEN in Studio: the PLAYER HOMES gate and lots 5-8 outside it): `World.MAX_LOTS` 8,
  `MAX_PLAYERS`/`LOT_LIMIT` 16 (Roblox Max Players 16; owner's pick). Pairs 1-2 inside the wall, from pair 3 the street goes
  through a wall gate (`TOWN_WALL.Gates` angle 145, `HOMES_STREET.Outside/OuterFirst`); `World.OuterGround` = grass strip
  under lots 5-16 (WorldService). Lots 9-16 exist only while used; `Hub.SetLots` runs an OverflowStreet piece out to them
  (not seen). Party max stays 4.
- **Welcome back + expeditions 2026-11-24** (welcome card SEEN in Studio by the owner and Claude; the camp sign and Battle dot NOT seen): solo players now earn AFK too (`Party.OpenSession`
  needed 2 members, so a solo player with companions got nothing while away); `UI/WelcomeBack` card after the menu shows
  `state.LastClaim` (AFK + stages the party cleared, `claim.At` = show once) plus what waits (expedition back, daily chest).
  Expedition back: `Town.SetExpeditionReady` sign over the Expedition Camp (studs-sized, MaxDistance 700) and a dot on
  the HUD Battle button (`extra.UpdateExpeditionReady`, rechecked every 5 s).
- **Phone + tablet pass 2026-11-24** (SEEN in Studio's Device Simulator, iPhone 7 / iPhone XR / Redmi Pad): `Kit.Touch`
  (touch and no keyboard; in Studio a touch screen alone, since the simulator has a keyboard). Main menu was never scaled
  (Render's Kit.clear destroyed the body's UIScale) -> fixed, slot cards also shrink to fit narrow screens. Touch: HUD
  size defaults to 1.2 (unless saved), Plaza/Home join the dock's left end (the stick owns the bottom-left), the combat log
  sits 70 higher and shorter (jump button), battle view uses the compact layout (stage card top-right, map card hidden,
  watching bar under the party list). Device Simulator: Test menu > Device Simulator (only in Edit mode).
- **Hide HUD 2026-11-24** (SEEN in Studio; the narrower corner stage card NOT re-seen): also hides the small buttons under
  the map card except 📝 Feedback; the stage card + fight timer move to the top-right corner (192 wide) and the watching bar
  (Log / Show HUD / Stop) to the bottom-left (`Hud:SetHudHidden`). Battle card is also a fixed panel top-left in battle
  view and at your own lot (`Arenas:SetScreenParent/Focus`, on the log layer); world cards MaxDistance 160.
- **Battle card 2026-11-24** (SEEN in Studio): the card over each lot (`Arenas` makeCard/fillCard) = header (zone, big STAGE,
  red BOSS), HERO | LV | CLASS | PET columns, headshot ringed in class colour (class dot for companions), "ghost" tag;
  raised to y 24 so damage numbers pop below it. Mockup: `branding/mockups/arena_card.png`.
- **Overnight balance + icons 2026-11-25** (tests green; Effects view, pin, skill/passive/talent icons SEEN in Studio):
  late-game runaway fixed (`Config/Stages.LateGrowth` 0.8%/stage past 80, `Config/Gear.PercentSoft`), fights last longer
  (`Config/Stages.FightLength` health 2.4 / attack 0.7, `Economy.FightPay` 1.4), every icon unique (`Config/IconLooks`,
  GENERATED by `tools/icons/icons.py`, which checks duplicates and that each glyph is Unicode emoji <= 12; run it after
  adding a skill/status/pet/passive/talent/rune/item), combat log Effects view + 📌 hold (`StatusText`), Simulation
  `Metrics` + bot METRIC lines + `tools/sim/report.py` / `classreport.py` (class report). Symbols that render as boxes in
  Roblox: ✦ ✧ ➶ ✕ (checked in Studio; ▲ ▼ ★ ☆ ✓ ✚ ● ☐ ☑ render).
- **Slow pacing + collections 2026-11-25** (tests green, NOT seen in Studio): owner wants a slow upgrade loop (upgrade,
  push a few stages, wait). `Economy.LevelPace`, `Config/Stages.LateGrowth.Bands` (1.8% from 25, 0.5% from 70), stage 61
  step removed, boss Enrage softened. Bot `LOOP` lines measure it. `NumberScale` 100 (was 10). Damage numbers by who hit
  whom (`Replay`, your hero gold). Bestiary (`Shared/Bestiary`, `Permanent.Bestiary.Kills`) and Class mastery
  (`Shared/ClassMastery`, `Permanent.Mastery`), screen `UI/CollectionScreen` (dock 🏅).
- **Roles, skill purposes, long fights 2026-11-26** (tests green, NOT seen in Studio): owner rules in docs/BALANCE.md
  "Roles" / "Skills: one job each" (primary role strongest; every skill that is not the best of its class + category has a
  second purpose; damage paths good at single AND area). Tools: `tools/sim/roles.py`, `runners/skillrank.luau`,
  `runners/skillaudit.luau`. Fights ~3.5x longer (`FightLength` 8.4 / 0.45, timers 200/300 s, `FightPay` 4.3).
- **Boss traps + flat daily 2026-11-26** (tests green, NOT seen in Studio): stage bosses get `Config/Stages.BossFightLength`
  (health x1.3, attack x0.8): longest boss wait 60 h -> 4.5 h, same mean frontier (BALANCE.md "Boss traps"; bot `BOSSWHY`
  lines). Daily login gift is flat gold per streak day (10K..40K, `Config/Daily` Gold), no frontier scaling (owner).
- **Season rollover 2026-11-27** (SEEN in Studio with the test cheat: card, level 1, stage 1, reward claim; no live switch yet): `Shared/SeasonClock` (current season = newest
  `Config/Seasons` entry whose StartsAt passed; never cache the id; `CurrentSeasonId` is gone), `Shared/SeasonRollover`
  (DataService runs it on load: every character restarts, Permanent + `Config/Seasons.Carry` kept, SeasonHistory rows,
  `Permanent.SeasonNews` card via WelcomeBack + Celebrate, handler `SeenSeasonNews`). Season prize Wishstones claimed
  before the switch wait in `Permanent.SeasonRewards.CarryWishstones`; claimed ledger uses string keys. Online players
  are kicked at a switch (Main.server). Test cheats "Start next season" = `SeasonClock.StartNext`: memory only, real
  DataStores untouched (`SeasonClock.IsTest`) and DataService keeps the stored profile while it is on.
- **DataStore budget 2026-11-27** (tests green, NOT seen live): LeaderboardService reads 3 boards a minute in turn
  (GetSortedAsync budget checked, `READS_PER_REFRESH`/`RESERVE`), follows the season (stores rebuilt, old scores
  forgotten, no writes after a season ends); SeasonResultsService only reads the boards (LeaderboardService writes them)
  and counts each player once in the Top-% histogram via `Shared/SeasonHistogram` (`Permanent.SeasonHist`).
- **Studio test mute**: Workspace attribute `StudioMute = true` (Edit mode, command bar) silences all game sound in Studio
  (owner asked: no sound while Claude tests). Set it before test runs, clear it (nil) before Ctrl+S.

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
Git Bash; they find a working Python themselves (`python3`/`python` there are Store stubs; `py -3` works). ~50 s for all 54 suites, then `tools/sim/lint.sh` (luau-analyze: names used but never defined; must say 0). New suites go in `src/server/Tests` and
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
     (fading left eyes/decals behind = the "never despawn" pile-up); health uses `Economy.MinionHealthScale` 0.4 (0.5 until the four-hero trim) (attack keeps `MinionScale` 0.27) so
     tanks live to hold aggro (abl companion: L40 stage 62-68 in 9.4-10h). Boss arena has a "Leave fight" button (skips to results; party fights stay
     held until the server hold ends). Guild raid button says "Battle" (it was already a real auto-combat fight); world/season say "Battle!".
   - DONE 2026-11-18 (tests green, NOT seen in Studio): parties of up to 4 (`Party.MAX_MEMBERS`); every fight has `Party.SEATS` = 4 heroes,
     empty seats filled by companions (`party.Companions`, ids -1..-3; old single `Companion` is migrated away). Join codes last until the
     party is full. Party ultimate = any pair of party classes (`Ultimates.ResolveParty`). Boss/raid/dungeon fights take the whole team
     (`PartyService.GetTeamSnapshots`); state has `Party.Teammates` (Partner = first). Party screen has teammate tabs, Hero screen tabs per
     teammate, HUD shows all teammates. Balance: `Config/Stages.PartyScale` 2.2 (docs/BALANCE.md "Four-hero balance").
     Tanks buffed 2026-11-18 (Warrior health/defense, see BALANCE.md); probe roles with `tools/sim/runners/partyprobe.luau`.
     SEEN in Studio 2026-11-18: solo Summoner gets 3 companions (Mira/Brom/Ilsa) on HUD and Party screen tabs, editing the 3rd companion's
     ghost skills, 4 heroes + imp summon in the arena, dungeon list (levels, waves, daily bonus ready/taken, 4 rows), Crypt run ("Waves 3/3",
     daily bonus line), Leave fight (skips to results), 5M cheat gold, Skills screen tab per teammate (reorder saved on the server). NOT seen: wave banners (run too fast). SEEN 2026-11-22: guild raid Battle (was broken: ServerError, `playBossFight` was used
     before its local was declared; fixed), world boss and season boss Battle! fights + results cards, expedition send/collect.
     STILL TO DO: balancing pass (2026-11-19 roster check in BALANCE.md: Mage mid-pack now, Summoner highest; Cleric buffed 2026-11-19 to fr ~45: Attack, Purify -> Consecrated enemy debuff, stronger Blessing; not seen in Studio); plaza arena pads
     (DONE 2026-11-18, SEEN in Studio 2026-11-19: pad 64x50, trees at z -11..-19, 4 heroes + skeleton + imp + pets in front of the trees; `World.ARENA_DEPTH` 50, rows pack within 19 studs); boss numbers retuned once (DamageScale x2, season 60M; see BALANCE.md), L40 boss overshoot fixed 2026-11-19 (DamageScale +2%/stage past 35, BALANCE.md "Late boss scale").
   - Studio test cheat (🧪 HUD button, `handlers.DevGrant`) should give much more gold.
   - DONE 2026-11-18 (tests green, NOT seen in Studio): dungeons are one continuous fight (`Simulation` option `Waves`, `Wave` events):
     2-3 waves then a boss, nothing resets between waves. Fixed difficulty (`Stage`) and recommended `Level` per dungeon, 4 dungeons
     (Crypt/Foundry/Abyss/Spire). Daily bonus: first full clear of each dungeon per day (`Activities.DailyBonus`). `abl.sh` prints
     `DUNGEON` lines (5 tries at the recommended level): a pair wins once its frontier is ~8 stages past the dungeon's Stage.
1. **Studio verification** of everything unseen. Seen and working (2026-11-16 evening): class-choose flow, tutorial card, Skill Trainer
   (train a slot), Pet Store (egg, crate, snack; header shows what a crate gave), feeding pet food (Bag > Stash), Pets detail card,
   Pets > Pet gear (wear/remove), map claim badges + Claim all, combat log 3 views, Flame aura on the hero, Store tabs, VIP row,
   Battle hub, dungeon run (victory card), expedition send. Still unseen: season auras once won, the other
   auras/kill effects, tutorial arrow steps past 1, pet follower, guild raid / world + season boss screens.
   Open UI nit: the map badge hover tooltip has not been seen.
   Watch for: tables keyed by numbers with gaps do not survive remotes (pet gear Equipped and StageClaims were hit); ✔ and newer emoji (🪙 🪢 🪦, Unicode 13+) do not render.
   Balance questions for the owner: Market "Pet Food x5" = 2,304g vs Pet Store Pet Snack 6,900g each (same item); one Forgotten Crypt run
   at stage 6 paid ~9.7K gold (3 keys/day). (and season auras), tutorial arrow/card, combat log views, map claim badges, tooltips, class-choose flow, pet follower, Battle hub dungeons/expeditions, Market tab, VIP row. Rojo must be reconnected via VS Code first.
2. DONE 2026-11-19: the sim bot uses pet gear, pet food, the Pet Store and wish tickets (BALANCE.md "Pets in the sim"); L40 ~9.1h. Pet food fed to a capped pet now fills a pet shard bar (1 shard per 16,000 XP, Bag > Stash button says "max: -> shards"; not seen in Studio); replay Wishstone income checked 2026-11-22: ~75% of Wishstones come from replays (~325 by L30), kept (BALANCE.md).
3. DONE 2026-11-22 (SEEN in Studio): Bag > Gear is a card grid + detail pane (Equip, ▲/▼ vs worn); Party is member cards + a detail pane
   (their skills: pick a slot, Earlier/Later, swap in any skill they own; Party ultimate: icon row + Equip). Checked the rest in Studio:
   Hero, Skills, Map, Quests, Store, Battle, Wish were already in the new style. VIP second pet slot done 2026-11-16 (`Pets.Second`, support pet: its stats count, only the main pet fights; Pets screen "Set 2nd"; not seen in Studio).
4. DONE 2026-11-22 (tests green, NOT seen in Studio): guild chat (Guild > Chat tab, `GuildService.Chat`, filtered, 30 kept, 1 msg/3 s), gifting (`Shared/Gifts`, Bag > Stash "🎁 Gift" to online party/guild mates on this server, 5 sent/10 received a day, no wish tickets), cosmetics try-on (Cosmetics shop "Try", 60 s, local only via `CosmeticsVisuals.TryOn`). (Skipped-tutorial payout notice DONE 2026-11-19: the Fight push carries `Reward.Tutorial`, the HUD toast shows it after that fight; toast is now 520x40 and wraps. Not seen in Studio.)
5. Owner-side: Game Passes (VIP, Extra Character Slots) and the 4 Sunstone products HAVE real ids (Config/Premium). Still open: upload `branding/logo.png` and set `Config/Branding.LogoImage` (empty).
6. DONE 2026-11-22: `docs/ROADMAP.md` has a 2026-11-17..22 entry; keep adding a dated entry when a batch of work lands.

- **Skill rework 2026-11-19** (tests green, NOT seen in Studio): class combos (builders add layers, a finisher consumes them),
  team aura for tank+healer+2 damage (`Config/TeamAura`), Taunt/Purify debuff enemies (Exposed/Consecrated), Guardian Angel,
  Rallying Cry, Last Stand, Blessing reworked; `PartyScale` 2.6. See docs/BALANCE.md "Skill rework". New status icons
  (✦ ➶ ✂ ⚒ ⚖ 🕯 ☀ ⚔ ★) not seen in Studio.
  Combo pips show the layer count from 1 and a finisher pops "COMBO xN!" over the enemy (not seen in Studio).

- **Runes 2026-11-22** (tests green, NOT seen in Studio): `Config/Runes` + `Shared/Runes`. One rune per gear piece (`item.Rune = { Stat, Tier }`),
  a new one replaces the old; replacing a HIGHER tier returns `ConfirmOverride` until resent with confirm (Bag shows a Replace/Cancel card).
  Equipping a replacement moves the old piece's rune onto it (`Gear.MoveRune`), unless the new piece has an equal or better rune.
  11 stats (Attack, Health, Defense, Damage dealt, Damage taken, Crit chance, Crit damage, Crit resist (new sim stat: lowers the
  chance to BE crit), Haste/cooldowns, Attack speed, Healing), 4 tiers. Uncarved runes live in `Season.Runes["Stat:Tier"]`.
  Sources: every frontier boss, 3% of frontier wins, a full dungeon clear, rune pouch (25K gold). Handlers `CarveRune`, `BuyRunePouch`.
  Carving and pouches moved 2026-11-23 to the **Rune Carver** plaza NPC (`Shops.RuneCarver`, spot `RuneCarver`); Bag > Gear only shows the rune. Rune glyph on gear cards, rune line in item tooltips.
  Crits now pop: big orange "CRIT!" number, red body flash, burst + slashes (`Replay.critText/critBurst`); not seen in Studio.

- **Gear bad-luck protection 2026-11-22** (tests green, NOT seen in Studio): `Config/Gear.Pity`, `Gear.PityDrop`/`Gear.IsUpgrade`,
  `Season.GearDry` counter in `Progression.ApplyClear`; catch-up only (par item when the weakest piece is below 85% of par after 10 dry wins).
  It did not narrow the roster spread: that comes from the stage 40 boss wall (BALANCE.md "Gear bad-luck protection").
- **Stage 40 boss wall 2026-11-22** (tests green): Dire Wolf Attack 10.5, AttackSpeed 0.85, Howl 22 s cd / 5 s. Time stuck there 1.34 h -> 0.47 h,
  stage spread at L40 39-88 -> 40-68 (BALANCE.md "Stage 40 boss wall").

- **Combo finishers fixed 2026-11-22** (tests green, NOT seen in Studio): the Templar "Judgment" (now `Verdict`) and the boss
  "CrushingBlow" (now `BossCrush`) had overwritten the Cleric/Warrior finishers (duplicate keys in Config/Abilities; `SkillIdTests`
  guards it). Ready finishers jump the slot order at 2+ layers (`Simulation.FINISHER_MIN_LAYERS`). Ranger/Templar/Priest damage
  penalties eased. The bot keeps Heal+Blessing / Taunt+IronSkin. Berserker -0.15 dmg / -0.12 health (2026-11-23; the 11-22 halving
  had only reached the docs). Open: Judgment is a weak 4th Cleric skill (BALANCE.md).
  Berserker 2026-11-23: no damage penalty, Lifesteal +0.25; Guardian loses DamageDealt +0.142 (L40: Berserker ~60, Guardian ~62; label "Lifesteal" in path text not seen in Studio).

- **Owner feedback 2026-11-23** (tests green, NONE seen in Studio): combat log stays minimized across fights (`LiveLog:Play`);
  town pet faced backwards (PetFollower turned it 180); companions' pets were the default orange "chick" in the arena until a
  fight (`GetHostedSummaries` left out companion PetId); Test cheats "Wishes" row (+500/5K Wishstones, 25/250 Skill + Pet Wish
  tickets); a fallen ally gets a red outline, "💀 Name is down" tag, "Name fell!" pop and a banner (`Actor:MarkDown`); Pets
  shard strip no longer wraps (guess at "text hiding behind shards": ask the owner where if it persists); Rune Carver NPC
  (hooded robe, staff, glowing rune stones, standing stone); every stall shows its trade (Merchant crates/coins/sword+shield,
  Pet Store eggs/cage/paw sign, Trainer dummy/scrolls/book + robe, Blacksmith hammer/rack); vendors spread around the plaza
  ring (`World.PlazaSpots`); lots 12 -> 8 (`MAX_LOTS`), spacing 84x76 -> 100x92. One lot per PARTY (WorldService.claimSlot):
  4 partied players share one lot, so Max Players 8 (Roblox game settings) never needs more than 8 lots.

- **Town phase 1 2026-11-23** (tests green, NOT seen in Studio): docs/TOWN.md. `World.Districts` (Grove west, Gate south, Training
  east, 150 studs from the fountain), ring road (W-S-E; north is the lots), spokes, signposts, arches; `client/Battle/Town.luau`
  builds them (pond, pet park, tavern, notice board, gate + walls, dummies, sparring ring, guild hall, houses along the ring,
  "coming soon" tags). Wishing Tree moved into the Grove (`PlazaSpots.Tree` -90 / 150). Floor 720x720. Phases 2-5 not started;
  the owner has not answered the 4 questions in docs/TOWN.md yet.
  Owner said it "looks awful"; fixed and SEEN in Studio 2026-11-23: the world boss and season Colossus were fixed server
  models standing in the new town (Colossus in the Town Gate) -> `World.BossField` / `BossSpots` south of the gate (BossService
  reads them); tavern/notice board/houses/guild hall now face their square (`facing()` in Town.luau); arches no longer hide
  their text; signposts moved off the plaza trees and use ">>" (the triangle glyphs did not render); buildings ~1.5x bigger.
  `tools/sim/townview/render.py` draws the plaza + town top-down headless (shim.luau stands in for Roblox) for layout checks.
  Studio camera trick: command bar `workspace.CurrentCamera.CameraType=Enum.CameraType.Scriptable` then set its CFrame.
  SEEN in Studio 2026-11-23 (batch from earlier that day): combat log stays minimized across stages; Wishes cheat row works;
  Rune Carver screen (carve, pouch, replace-a-better-rune confirm); pet follower faces the way you walk; companions' pets show
  on the lot (Chirpy). Fixed then: Pets shard strip no longer hides text under its buttons (collection % moved to its tooltip),
  pouch result shows at once, battle numbers have MaxDistance 90 (other lots' crits floated over the HUD). NOT seen: the
  fallen-ally outline/tag/banner (needs a hero to die).

- **Town errands 2026-11-23** (tests green, SEEN in Studio: all four errands, cat carry, offering, straw, Notice Board,
  tracker): docs/TOWN.md "Town errands". Signposts removed, lots 8 -> 4 (`World.MAX_LOTS`; a 5th party still gets slot 5 in
  the next row back, it is just not drawn as "open"). Owner asked next (2026-11-23): dungeon location outside town, spots in
  town for guild / expeditions / store, sound + music (per content type, level-up, stage clear) with sound settings, a clear
  level-up notice and level-up points to spend.
- **Town places 2026-11-23** (SEEN in Studio): Dungeon Gate (portal in a rocky hill west of the Grove, `TownSpots.DungeonGate`,
  opens Battle > Dungeons), Expedition Camp (tents + map table outside the wall SE, opens Battle > Expeditions), Guild Board
  beside the Guild Hall (opens Guild), Store stall on the plaza (`PlazaSpots.Store`). HUD buttons still open them too.
- **Sound 2026-11-23** (SEEN in Studio: all 32 ids load, town/stage/dungeon music switch, sliders change SoundGroup volume,
  level-up card, combat sounds created): `Config/Audio` (APMOfficial music, ProSoundEffects/Roblox SFX; ids from the Creator
  Store search API `toolbox-service/v2/assets:search?searchCategoryType=Audio`), `client/Sound.luau` (SoundGroups IPQ_Music /
  IPQ_Effects / IPQ_Interface, 3D combat sounds at the fighter, music cross-fade by context: boss arena `info.Kind`
  WorldBoss/SeasonBoss/GuildRaid/Dungeon, battle view = Stage, else Town). Settings screen (HUD gear button, handler
  `SaveSettings`, `Permanent.Settings`). `UI/Celebrate` = big level-up / errand card + sparkles. NOT heard (no audio check
  possible from here): loudness balance between tracks and effects; world/season/guild boss music not seen switching.
- **Talents 2026-11-23** (SEEN in Studio: level-up card names the points, red dot on the Talents dock button, +1/+5,
  Auto-spend by role, Reset): `Config/Talents` + `Shared/Talents`, 1 point per level (39 at L40), 8 talents x 10 ranks
  (Might, Vitality, Bulwark, Precision, Ferocity, Swiftness, Focus, Mending), free reset, `Season.Talents`. Mods ride in
  ExtraMods (StageRunner live path, `Party.MakeSnapshot` CollectionMods, hero sheet); IP +4 per point. Handlers
  `SpendTalent`, `ResetTalents`, `AutoTalents`. The sim bot auto-spends (`abl.sh` mode `notalent` turns it off).
- **Fishing + Training Dummy 2026-11-23** (SEEN in Studio: cast/bite/too-late, catches pay via the remote, bobber, dummy
  results with 4 heroes and a personal best): `Shared/Fishing` + `Config/Fishing` (12 paid catches a day, mostly pet
  food; casts kept in server memory, os.clock timing with a grace window), handlers `FishCast`/`FishReel` at
  `TownSpots.Pond`; `Shared/TrainingDummy` (20 s fight vs enemy `TrainingDummy`, no rewards, `Season.DummyBest`),
  handler `TrainDummy` at `TownSpots.Dummy`. UI: `UI/FishingGame`, `UI/DummyScreen`.
- **Pet park + relics 2026-11-23** (SEEN in Studio: relic pickup card and it vanishes, pet play +4000 pet XP, Notice
  Board "More to do in town" line): `Shared/TownLeisure`. Pet park once a day (`Season.PetPlayDay`, handler `PetPlay`);
  10 relics `TownSpots.Relic1..10` (2 Wishstones each per season, all 10 = +10 and title "Relic Hunter",
  `Season.Relics`, handler `TakeRelic`). Not seen: the all-relics title moment; sparring ring not built (owner undecided).

- **Owner feedback 2026-11-23 evening** (SEEN in Studio after: wall ring + gates, Boss Field/camp/dungeon outside, keg
  upright, new flower beds, Pip + board, fishing dial + "got away", star bursts; NOT seen: a dial catch by hand, Elder): carried
  items hang from an unrotated invisible handle (the platter and keg were sideways), keg stands upright; errands are a
  pool of 11 (`Config/Errands`), `Errands.Offered(day)` picks 5 a day (one per townsperson, same for everyone);
  new townsfolk Elder Thessaly (Grove, by the tree) and Pip the Courier (Gate), Greta gives errands too; new pick-up
  spots Flowers, Shallows, Well, Crates, Arrows, Bones, CampDrop. Town wall ring `World.TOWN_WALL` (radius 262, main
  gate south, small gates west and south-east); the Gate district's own gate is gone; Boss Field (z 365),
  Dungeon Gate (-310, 40) and Expedition Camp (150, 300) moved outside the wall. Notice board moved by the road into
  the Gate square; flower beds are real flowers now (the pink balls); ringside houses 146/158 removed (they blocked the
  camp road), lamps stand beside houses not before their doors. Fishing is a skill check: a needle sweeps a dial, REEL in
  the gold zone (`Config/Fishing` Speed/ZoneWidth/Laps; the server holds the client's elapsed time to its clock).
  Claim/buy/upgrade feedback: `CLAIM_FX` in Main (sounds + `Celebrate.Burst` stars at the cursor).
- **Sparring ring 2026-11-23** (SEEN in Studio: opponent list, a duel lost to Mira 1-1 on health): `Shared/Sparring`, 1v1
  duel in two bouts with sides swapped (the sim is not symmetric), handlers `SparList`/`SparFight` at `TownSpots.Ring`,
  opponents = players on the server + your party's companions; first win a day = 3 Wishstones; `UI/SparScreen`.

- **Town relayout to the owner's blueprint 2026-11-23** (SEEN in Studio: overview, guild castle, market arc): walled town
  radius 290 round the plaza; districts Guild (N, castle), Housing "Old Town" (NW, was the Gate square), Grove (NE,
  Wishing Tree), PetArea (W, pet park + pond), Market (E, the six shop stalls in an arc, `PlazaSpots` r150),
  Training "Combat Arena" (SW, sparring ring in the middle). Battle lots = 2 x 2 block SE (`World.LOT_BLOCK`,
  `LOT_COLUMNS`). Dungeon built into the east wall (wall gate `Hill`), Giant Bosses field outside the NE gate
  (`BossField` 237,-263), main gate S, Expedition Camp outside it. `townview/render.py` draws it all (now with a
  close-up per district). Sparring duels replay in the boss arena (opponent as a hero, `Replay` entry.Hero).

- **Save + multiplayer readiness 2026-11-23** (tests green; nothing seen live yet): `Util/DataSafety` checks a value is
  DataStore-safe (no mixed/gappy tables, no NaN, size); DataService warns once per problem before each save;
  `SaveSafetyTests` (played profile, busy guild, party with ghost + companions) and the bot prints `SAVECHECK` lines.
  FOUND AND FIXED: `Season.StageRewardsClaimed` was keyed by stage numbers (10, 20...): every live save after the first
  boss clear would have failed. Now string keys; schema v4 migration converts old data. Playtest setup and tester
  checklist: docs/PLAYTEST.md (publish, Studio API access, Max Players 4 = the 4 lots, rejoin check).
  `DataServiceTests` run the REAL DataService headless (sync.py writes `.build/hl6/DataServiceSim.luau`, DataService as a
  factory taking game/task/warn/os) on a fake DataStore with fake servers: join/leave/rejoin elsewhere, double login,
  crash + stale lock, teleport wait, retries, bad tables, v3 upgrade, rollback refusal, shutdown. Writes pass `{ userId }`.

- **Playtest log 2026-11-23** (tests green, NOT seen in Studio): HUD 📝 Feedback (`UI/FeedbackScreen`, handler `SendFeedback`,
  topics Bug/Confusing/Idea/Fun, 1 per 20 s, 15/day); server errors (`ScriptContext.Error` + ApiService handler failures via
  `xpcall` traceback), client errors (`ReportError`, 6/min, each message once per visit) and one Session line per visit;
  `Shared/PlaytestLog` rules, `Services/PlaytestService` buffers and writes DataStore `IPQ_Playtest` keys `Feedback|Errors|Sessions:<day>`
  every 60 s + on close. Reader: Feedback > "Read log" tab (`PlaytestRead`, `state.Player.CanReadLog`: Studio or the place's creator).
  8 lots were considered: they do not fit inside the town wall (slot 6 would sit outside), so Max Players stays 4.

## Gotchas
- Panels are not redrawn by state updates while the player types in one of their text boxes (Main: `GetFocusedTextBox`);
  forms should still save what is typed on `Text` change (GuildScreen found-a-guild form does).
- Tooltips (`Kit.Hover`) skip things covered by something solid (an open panel) at the mouse (`GetGuiObjectsAtPosition`).
- Studio testing via computer use: a TextBox in the game view needs two clicks (the first focuses the viewport); Shift+F5
  goes to whatever has focus, so use the toolbar Stop button; Rojo sometimes misses a file change (re-save the file) and
  `Source:find(...)` in the command bar (Edit context) tells whether Studio has the new code.
- Studio testing: the HUD 🧪 button opens the "Test cheats" panel (Studio only, `UI/DevScreen` -> `handlers.Dev(action, n)`, `DEV_ACTIONS` in ApiService):
  +1/5/10 levels, +5/10/25 stages (cleared like real wins, party moves there), +50M/500M gold, Sunstones, test items, Epic gear for your stage, all pets at max level,
  reset dailies (keys, dungeon bonuses, gifts, expedition ready), spawn world boss, toggle premium pass. Add new cheats there, not as new HUD buttons. SEEN in Studio 2026-11-22. Vendor prompts need you within 14 studs;
  teleport from the command bar (Client view): `game.Players.LocalPlayer.Character:PivotTo(CFrame.new(x, 4, z))` - Trainer (13.5, -5), Pet Store (-13.5, -5).
  The command bar has its own module cache, so `require(DataService).GetProfile` there returns nil.
- Don't launch Studio via the Start menu while it is open: it starts a second instance (close it).
- Hook message "N unpushed commits" can be a stale tracking ref: compare `git ls-remote origin <branch>` with `git rev-parse HEAD`.
- Test files use `warn or print`; `warn` is nil in the headless harness.
- Pet level shown/used = min(stored level, owner level); a new season (owner back at level 1) shows pets low until the hero catches up; stored level is kept.
