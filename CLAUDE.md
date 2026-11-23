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
5. Owner-side: create the VIP Game Pass + Sunstone Developer Products and give the ids (`GamePassId`/`ProductId` are 0); upload `branding/logo.png` and set `Config/Branding.LogoImage`.
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
  Store search API `toolbox-service/v2/assets:search?searchCategoryType=Audio`), `client/Sound.luau` (SoundGroups DQ_Music /
  DQ_Effects / DQ_Interface, 3D combat sounds at the fighter, music cross-fade by context: boss arena `info.Kind`
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

## Gotchas
- Studio testing: the HUD 🧪 button opens the "Test cheats" panel (Studio only, `UI/DevScreen` -> `handlers.Dev(action, n)`, `DEV_ACTIONS` in ApiService):
  +1/5/10 levels, +5/10/25 stages (cleared like real wins, party moves there), +50M/500M gold, Sunstones, test items, Epic gear for your stage, all pets at max level,
  reset dailies (keys, dungeon bonuses, gifts, expedition ready), spawn world boss, toggle premium pass. Add new cheats there, not as new HUD buttons. SEEN in Studio 2026-11-22. Vendor prompts need you within 14 studs;
  teleport from the command bar (Client view): `game.Players.LocalPlayer.Character:PivotTo(CFrame.new(x, 4, z))` - Trainer (13.5, -5), Pet Store (-13.5, -5).
  The command bar has its own module cache, so `require(DataService).GetProfile` there returns nil.
- Don't launch Studio via the Start menu while it is open: it starts a second instance (close it).
- Hook message "N unpushed commits" can be a stale tracking ref: compare `git ls-remote origin <branch>` with `git rev-parse HEAD`.
- Test files use `warn or print`; `warn` is nil in the headless harness.
- Pet level shown/used = min(stored level, owner level); a new season (owner back at level 1) shows pets low until the hero catches up; stored level is kept.
