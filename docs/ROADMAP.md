# Duo Quest Roadmap

> Living document. Updated whenever we finish or reprioritise something.
> **Last updated:** 2026-11-22

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

### 2026-11-17 to 2026-11-22 (four-hero parties, combat rework, balance)
- 🔨 Parties of up to 4: every fight has 4 heroes, companions fill empty seats (classes the party lacks), party ultimate from any pair of classes, boss/raid/dungeon fights take the whole team. ✅ Seen: 3 companions on HUD and Party tabs, ghost skill edits, Hero and Skills tabs per teammate.
- ✅ Bigger arena pads for 4 heroes (64x50, scenery pushed back, rows pack tighter). Seen in Studio.
- 🔨 Summons expire after 20 s and dead ones are removed (the "never despawn" pile-up). ✅ Boss arena "Leave fight"; raid/world/season buttons say Battle.
- ✅ Dungeons are one continuous fight: 2-3 waves then a boss, fixed stage and recommended level, daily bonus for the first clear of each per day. Seen: list, Crypt run, daily bonus. 🔨 Wave banners not seen.
- 🔨 Combat rework (ideas from idle RPGs like Ulala): class combos (builder skills add layers of a class mark, a finisher hits harder per layer and uses them up), a team aura for tank + healer + 2 damage, support skills that weaken enemies (Taunt: Exposed, Purify: Consecrated) or buff the party (Guardian Angel, Rallying Cry, Blessing). Combo layer counts on the status pips and a "COMBO xN!" pop.
- 🔨 Balance: tanks and Cleric buffed, Summoner trimmed, enemy party scale 2.6, boss damage scale and dungeon stages retuned; all six classes reach stage ~40-66 by L40 in 8-11 h (docs/BALANCE.md). The balance bot now plays combos, pets (gear, food, Pet Store) and wish tickets.
- 🔨 Pet food fed to a pet at your level becomes pet shard progress; Market Pet Food has a fixed price; skipped-tutorial payout shows a notice.
- ⬜ Still to do: Studio check of the combat rework, guild chat, gifting, cosmetics try-on, restyle of the older screens.

### 2026-11-16 (numbers, Battle hub, activities, market)
- ✅ Number scale: health / attack / defense x10 (`Economy.NumberScale`), XP x20 (`Economy.XPNumber`), gold on a new curve (thousands early, millions later), costs ~x60. Percentages unchanged, so balance is invariant. Large numbers print short (`Util/NumberFormat`: 12.4K, 3.2M).
- ✅ Subclass per-level growth (`Subclasses.Growth`): offensive paths gain Attack faster, protective paths Defense / Health. All 12 paths re-run through the balance harness; Templar retuned (it stalled at stage 40).
- ✅ Ember Wastes uses Magma Hounds instead of crabs.
- ✅ Battle hub (⚔): world boss, season boss, guild raid, dungeons, expeditions. Bosses fight in their own ember arena with a results card (damage meter, rewards). Seen in Studio: world boss arena + results.
- 🔨 Dungeons (keys, floors, final-floor replay) and expeditions (start / collect): tests pass, UI not yet seen.
- 🔨 Gold Market in the Store: daily capped wishes, season-limited items. Tests pass, UI not yet seen.
- ✅ Pets attack independently (`Pet_Strike`) with a visible lunge and damage in the meter. 🔨 Active pets follow you in town (not yet seen).
- ✅ Combat HUD: smaller log, damage meter first, skill bar clear of the dock. Window chrome restyle, travel buttons in their own corner, 17-step tutorial.
- 🔨 Pets screen rebuilt as card grid + detail pane + slim shard strip (compiles, not seen).
- ⬜ Still to do: same style for Hero / Skills / Party / Bag / Map / Quests / Boss / Store / Wish, text overflow audit with big numbers, levels 90 to 120 + Paragon + second subclass tier, pets to level 50, guild raids, VIP pass / second pet slot / gifting / Robux IDs / PolicyService, upload `branding/logo.png` and set `Config/Branding.LogoImage`.

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

## 2026-11-15 (world life: plaza, shops, hero, map; checked in Studio)
- Central plaza (World.PLAZA): fountain, lamps, trees, benches, wandering townsfolk; Merchant + Blacksmith NPC stalls, Map/Rankings boards, Daily chest. Players spawn here; Plaza/Home buttons teleport.
- Player lots: roads between lot columns, "open lot" markers for up to World.MAX_LOTS.
- Selling moved to the Merchant (single + "Sell all Common" / "Sell worse gear"); gear upgrades at the Blacksmith (10 levels, +6%/level, gold). Server enforces World.SHOP_RANGE. Bag is view/equip only.
- Hero screen (You | Partner): turntable avatar, stats (shared/Hero.luau), skills, passives, gear.
- World map redrawn as a parchment road with zone nodes and player portrait pins (live from the World snapshot).
- HUD: full-screen anchors, menu dock bottom-centre, top-left kept clear of Roblox chat.
- Tests: GearDailyTests +15 (upgrade, bulk sell, plaza geometry, hero sheet).

## 2026-11-15 HUD pass
- HUD scaled down (0.8 desktop / 0.9 touch); combat HUD only shows while watching a battle; "Hide HUD" in the watching bar hides everything non-combat.
- Daily button removed (use the plaza gift); gold/shards top-right; live Map card (stage, zone, pips) top-right opens the world map.
- Skills screen revamp: icon-only equipped row + unlocked pool, detail side panel on the right, party on the left.
- Failed stage now steps the party back one stage and holds (Farm) until the player presses Advance (`Advance` API, `Party.Advance`).

## 2026-11-15 gear + menus pass
- Passives merged into the Skills page (3 passive slots under the equipped skills, passive pool below, details + level/equip on the right); Passives and Ranks buttons removed from the dock (rankings stay at the plaza board).
- Menus slid up so the dock stays visible; party card sits right under Roblox's menu/chat buttons; map card in the top-right corner with gold/shards directly left.
- Item Power (stat / slot base * 10, comparable across slots) on every item; bag sorted strongest first; Bag has a list / icons-only toggle.
- Everybody starts with a Common weapon (Gear.EnsureStarter at profile load).
- Set pieces are now a variant of a normal drop (no separate set roll) and are worn like any gear; the Sets collection tab is gone (Gear tab shows bonuses of worn sets).
- Hero page draws worn gear on the avatar (weapon by the hand, armour on the chest, trinket at the neck). No helmet slot exists yet (3 slots: Weapon, Armor, Trinket).

## Gear slots, stash, combat feel, Skills screen (Nov 15)
- 8 worn slots (helmet, amulet, armor, pants, weapon, 2 rings, boots); Stash tab for consumables; timed buffs (XP / damage / etc.) via Merchant Supplies; Studio-only Dev grant button.
- Combat: party abilities now have cast times (damage/heal land after a wind-up) and a 1s lockout after each cast; basic attacks continue. Bosses keep their telegraphs.
- Live combat log pops open during fights with a minimize button; the Fight log button still shows the full last fight.
- Hero screen frames the body only so the character is centred; UI reference size enlarged so everything reads smaller.
- Skills screen rebuilt: You / Partner tabs, drag to reorder cast order, drag pool skills onto slots, scrolling pool, partner ghost skills editable.
- TODO next: worn sets visible on character, pet wishing + pet food, Wishing Tree (pet + skill wishes; then remove shard/gold unlocks on Skills/Pets pages), world boss.

## Wishing Tree (Nov 15)
- Wishing Tree in the plaza (glowing tree + spring). Pet wishes (tickets or gold) and Skill wishes (tickets or shards); three tiers unlocked at stages 1/15/40 with better odds; 10-pulls; pity (Rare+ every 10, Epic+ every 40, pet Legendary every 90); duplicate pets become pet XP.
- 15 pets, 13 wish-only, each with its own look (new shapes: Bunny, Bird, Turtle, Drake) and stat; new Legendary rarity.
- Shard-unlock button removed from the Skills page; skills come from wishes or boss free picks. Pets page now shows pet icons and how to get each pet.


## Boss events (world boss + season boss)
- World boss: appears on a timer on every server and stands in the arena area; each player strikes it (45s fight with their own build, cooldown, strike cap); at the end of the timer everyone gets every damage tier they reached (cumulative).
- Season boss "Verdant Colossus": one health bar for all servers (DataStore counter, UpdateAsync batches), permanent HP loss, withers in the season's finale so it dies near the end; health thresholds give community rewards (claim in the Boss window); on death every contributor gets a Colossus Egg -> Colossling (Legendary pet).
- Code: Shared/Bosses + Config/Bosses (rules/data, BossEventTests), Server/Services/BossService, ApiService BossState/BossStrike/BossClaim/BossHatch, Screens.Boss + HUD button.
- TODO: Colossling pet model (Golem shape), partner joins a strike, tune numbers, season StartsAt/EndsAt per season.

## Polish batch (Nov 15, later)
- Boss strikes are real auto-battle fights (player + partner/ghost) in the player's arena; bosses are stationary.
- Plaza spread out (radius 70); Gear dock page removed; passives drag-and-drop; Gold Charm removed; spectate card with Advance.
- Loot has 5 rarity tiers (Common, Uncommon, Rare, Epic, Legendary) blended by stage (early C/U, mid U/R/E, late E/L).
- Wishing Tree bigger/more magical and placed on the paving; HUD exact-value hovers, clickable partner card; skill/passive swaps are optimistic (no lag).
- Merchant: rarity checkboxes + one Sell button; new Bag tab to upgrade bag size (+5 slots, up to 14 upgrades).
- TODO: worn set visuals, verify tree/merchant visuals in Studio (Studio kept crashing), mobile tooltips.

## Pets, Wishstones, quests (Nov 15, evening)
- Pets: no more gold upgrades. Duplicates from wishes rank a pet up (up to rank 6, +25% stats per rank, stronger pet skill); pets still level from pet food and fighting. Some pets give two stats; single-stat pets give more of that stat. Every pet has its own skill (cast by its owner as an extra ability, level = rank).
- Wishstones: one currency for both Wishing Tree options (and tickets). Earned from every stage clear (frontier 2, boss +4, every 4th replay 1), daily login, quests and the season pass.
- Stash: boosts warn before wasting time over the 2-hour cap (server refuses unless forced).
- Daily quests (3 per day + bonus) and a 30-level season pass (free track; Premium levels reserved). Quests window (HUD 📜). Pass XP from stage clears and quests.
- Skills have unique icons; panels keep their scroll position on refresh; tree moved onto the grass; townsfolk are non-solid and walk away from you; arena backdrop wall removed; arena name cards show only up close; fight HUD shows the stage being fought (not the next one).
- TODO: wire the Robux purchase for the premium pass, mobile tooltips, verify all of this in Studio. (Boss strike quest, weekly quests, premium track and pet skill icons: done, see below.)

## Skill rarity, ranks and manual upgrades (Nov 15, afternoon)
- Skills now have a TIER (Common/Rare/Epic/Legendary, the rarity you hold) and a RANK (1-10). Combat level = rank + tier levels above the skill's own base rarity (max 20). Config/SkillProgress, shared/SkillProgress; state in Season.SkillState (resets with the season).
- A skill wish rolls a rarity, then any class skill whose own rarity is not higher (unowned skills 3x as likely). First copy = skill unlocked at that tier. A higher-tier copy of an owned skill WAITS as an upgrade (button: Skills page > Upgrade); a lower copy waiting is turned into XP. Spare copies become skill XP (10/25/60/150 by rarity) and the player presses Rank up themselves (664 XP total to max). Nothing upgrades by itself.
- Pets: duplicates are banked as COPIES (Permanent.PetCopies); the player spends 1/1/2/2/3 copies per rank on the Pets page. Max rank pets turn spares into pet XP.
- Gold slot levelling is gone (Economy.LevelSlot stays in code, unused); levels follow the skill (ghost snapshots carry Party SkillLevels, so moving a skill keeps its level).
- Season pass never pays gold or shards: odd levels consumables, even levels Wishstones, every 5th level a Skill Wish (5/15/25) or Pet Wish (10/20/30) ticket; Skill Wish and Pet Wish tickets are separate everywhere (daily bonus gives one of each).
- Skills page: Earlier/Later buttons removed (drag to reorder); locked things (passive slots, locked passives, locked pets, locked wish tiers) show a padlock veil with the stage needed. Red dots on Skills/Pets docks when a rank up or upgrade is ready.
- Wishing Tree name tag moved above the canopy.
- Pacing (simulated, Bright skill wishes, ~12 skills per class): 100 wishes -> top four skills ~level 12-13; 200 -> ~2 maxed; 300 -> ~5 maxed.

## Party leave fixes (Nov 15)
- A fresh solo party (after Leave) starts at the player's own frontier, never stage 1.
- The fight clock is carried over when you leave (PartyService.Leave): a new party's first fight is no longer due at once, so spamming Leave cannot clear a stage per click.
- Skill wishes are open from the start (no stage-locked tiers) and can give any class skill; Legendary joined the skill odds. A chosen subclass's skills join the wish pool and arrive as Legendary (choosing a path also grants its first skill as Legendary).

## Weekly quests and boss strike quest (Nov 15, night)
- Weekly quests: four bigger quests drawn each Monday (UTC), one per event kind, in a new "Weekly quests" tab with a time-left counter. Each pays Wishstones + Pass XP + a Grand Pet Food; all four claimed unlocks a weekly bonus (Skill Wish + Pet Wish ticket, Wishstones, Pass XP). Never gold. API: ClaimWeeklyQuest(index), ClaimWeeklyBonus(). State in Permanent.WeeklyQuests.
- New "Strike" quest event (world and season boss strikes both count): daily "Strike a boss once", weekly "Strike a boss 4 times".
- Quests dock badge also lights for weekly claims. 44 quest tests.
- Joining a real partner: pair starts at the lower frontier; each player's own furthest stage stays on their profile (never lowered) and is where they restart after leaving.

## Premium pass track and pet skill icons (Nov 15, night)
- Season pass has two tracks side by side: Free and Premium (locked until `Season.Pass.Premium`; `Quests.SetPremium(profile, true)` is what a Robux purchase will call). Premium pays Wishstones, consumables, Pet Wish on 5/15/25, Skill Wish on 10/20/30, a skill pick at 20 and 30 Wishstones at 30; never gold. Claim all takes both tracks. Studio-only HUD button (star) toggles premium for testing.
- Pet skills have their own icons (Icons.PetSkill) on the Pets page with a hover tip; the pet's rank is the level badge.
- Verified in Studio (Nov 15): Weekly and Daily tabs, premium pass column, Pets page skill icons, Wishing Tree prompt (works within ~14 studs of the trunk), Wish screen (Pet/Skill ticket labels, unlocked skill tiers, locked pet tiers), skill wish results, Skills page Rank up and Upgrade. Fixed: unsupported emoji in pet skill icons, wish result grid overlapping the footer (5 per row).

## Currency split and Premium shop (Nov 15, evening)
- Two currencies: Wishstones (blue 💎, earned only: stage clears, quests, pass, daily; the wishing currency) and Sunstones (orange 🔶, bought with Robux, permanent across seasons; spent in the Premium shop). Shards stay (violet 💠, skill unlocks).
- Sunstones never buy wishes, tickets, Wishstones or anything random, so Roblox's paid-random-item rules (odds, regional restriction) do not apply to the shop. Direct Wishstone sales are removed from the plan.
- Premium shop (HUD 🔶 button): Starter Pack (once per account), Level-up Pack (3 hero levels, 3/season), Subclass Pack (4 skill picks + boosts, 1/season), Pass Boost (+5 pass levels, 4/season), Bag Expansion, Boost Bundle (unlimited), Premium Season Pass (400). Config/Premium; Shared/Premium; 23 tests.
- "Get Sunstones" tab: four Robux packs, first purchase of each doubles. Server: PremiumService.ProcessReceipt (idempotent by PurchaseId, saves before granting). Packs show "soon" until real Developer Product ids go into Config/Premium Packs[].ProductId.
- Studio helpers: first Dev button grants test items, a star toggles the premium pass, "Studio only: add 1,000 Sunstones" in the Get Sunstones tab.
- TODO: PolicyService check for the premium pass's wish tickets in restricted regions; cosmetics shop; gifting; real product ids; verify in Studio.
- Verified in Studio: four currency pills (gold, shards, blue Wishstones, orange Sunstones), Premium shop list, Get Sunstones packs, test Sunstones, buying the Starter Pack (spends 120, sold out afterwards, skill picks arrive).

## Premium shop changes (Nov 15, night)
- Level-up Pack and the +5 Pass Boost removed. New: Pass Max-out (700, takes the pass straight to level 30), Premium Pass + Max-out Deal (990 vs 1,100 separately; gone once either half is owned), Enhanced Starter Pack (450, once per account: 8 skill picks, 3 bag upgrades, big consumable stock; BEST VALUE tag).
- Subclass Pack (180): hidden until the player reaches the subclass level, then a pop-up offers it once (Buy / Not now); after it is closed it is listed in the shop. Server tracks Season.PremiumOffers; API DismissPremiumOffer; client PremiumScreen.Popup. 37 premium tests.

## End-of-season rewards (Sunstones for playing)
- Done (rules + server + screen): everyone ranked at stage 3 or higher earns Sunstones and Wishstones by percentile (Top 10%..100%, ten brackets so nobody is left out). Exact ranks (1, 2, 3, 10, 20, 50) earn more on top, and the best of each class (Warrior, Cleric, Mage; top 1, 3, 10) earn extra again. The three layers add together; rank rewards also give titles and an aura id (stored in `Permanent.Titles` / `Permanent.Cosmetics` until the cosmetics shop exists). Numbers in `Config/SeasonRewards` (first guesses; top 1 earns 600+100+150 Sunstones, last bracket 10).
- `Shared/SeasonRewards` (pure rules, 28 tests) + `SeasonResultsService` (per-class boards, a score histogram for the percentiles, results frozen at the season's `EndsAt`) + `GetSeasonRewards` / `ClaimSeasonRewards` API + the 🏆 Season Rewards screen (live standing, projected Sunstones, all brackets, a claim button). Claims are once per season (`Permanent.SeasonRewards.Claimed`).
- Ties count together (percentile = everyone at or above your score), so a bracket never holds more than its share.
- NOT yet tested on a live server: DataStore reads/writes, the frozen results, claiming after a real season end. Studio uses an in-memory board. Needs: a season-end test (shorten `EndsAt`), a guard against alt accounts farming the lowest brackets (the stage 3 minimum is a first step), and a "Hall of Fame" list of past champions.
- Also planned from the same talk: Sunstones on the season pass free track and the weekly quest bonus (small), cosmetics shop (name colours, auras, kill effects), second pet slot, VIP pass, gifting.
- Class leaderboards: each class in `Config/Classes` automatically gets a board (`Class_<class>`, a tab on the Ranks screen, a store the season rewards read). A new class needs nothing else; a class with `Locked = true` (Mage today) gets its board when the flag is removed. A player's score counts for the class they currently play (stage progress is not tracked per class). The hub sign shows only the overall boards.
- Rank rewards raised: #1 1000, #2 700, #3 600, ranks 4-10 400, 11-20 275, 21-50 150 (class awards unchanged: 300 / 150 / 60).
- Stacking (`StackRanks = true` in Config/SeasonRewards): a player gets EVERY rank row and class row they qualify for, not only the tightest. #1 earns 1000+700+600+400+275+150 = 3,125 from ranks, plus 510 as best of a class, plus 200 percentile = 3,835 Sunstones. #2 2,125, #3 1,425, ranks 4-10 825, 11-20 425, 21-50 150. Set the flag to false to go back to one row per player.
- Season rewards retuned (totals lowered, class awards raised, non-Sunstone prizes added). Stacked ranks: #1 300+200+150+100+60+40 = 850, #2 550, #3 350, ranks 4-10 200, 11-20 100, 21-50 40. Class awards stack: best of a class 500+300+150 = 950, top 3 450, top 10 150. Percentile 10-120. A #1 who is also the best of a class earns about 1,920 Sunstones.
- Prizes besides Sunstones: titles, cosmetic ids (auras Champion/Silver/Bronze/Elite, Sparks kill effect, Laurel name colour, and per-class aura / kill effect / name colour), and four season-prize pets (Config/Pets `Reward = true`, never in the Wishing Tree): Crownling (rank 1, Legendary), Laurelwing (ranks 1-3, Epic), and a pet for the best of each class (Bannerhound for Warrior, Haloette for Cleric; a new class needs an entry in `ClassPets`). A duplicate prize pet becomes a pet copy. The cosmetic ids are saved on the player but nothing draws them yet (cosmetics shop / equip screen is next); pet looks reuse existing shapes (Drake, Wisp, Cat) with new colours.
- Season prize pets are strong on purpose: `Power` on the pet def multiplies every stat line (Crownling and Laurelwing Legendary at 1.7, Bannerhound and Haloette Epic at 2.0), so each out-stats the best wishable pet (a test checks it); their skills are stronger too (Royal Decree 3.0x damage plus a party shield, Victory March gives the whole party Frenzied, Banner Guard fortifies and shields, Halo Mend heals one ally a lot and everyone a little). Laurelwing is Legendary. Numbers need playtesting.

## Sunstones for playing and the cosmetics system
- Sunstones for free players: 10/15/25 at pass levels 10/20/30 (50 on the free track), 15/20/40 on the premium track (75), +10 on the weekly quest bonus. Written straight to `Permanent.Premium.Sunstones` from Shared/Quests (Premium requires Quests, so no import).
- Cosmetics: `Config/Cosmetics` (6 shop auras, 5 shop kill effects, 7 shop name colours, 5 shop titles; season prizes: Champion/Silver/Bronze/Elite auras, Sparks, Laurel, and Aura/Kill/Name per class), `Shared/Cosmetics` (Owned, Equip, Buy with Sunstones, List, Look; 20 tests), API `BuyCosmetic` / `EquipCosmetic`, state field `Cosmetics`, the 🎨 Cosmetics screen (tabs per slot, buy/equip/take off; season prizes show locked), and `CosmeticsVisuals` (name tag with title and name colour and an aura on every character, from player attributes `CosAura/CosName/CosTitle`; the local player's kill effect bursts where an enemy dies in the fight scene).
- NOT yet seen in Studio: the screen layout (mini-button row may be crowded now), the aura/name tag look, the kill burst. The hero in the fight scene is a drawn actor, not the character, so it does not wear the aura yet (the plaza and home characters do). Prices are first guesses.
- Verified in Studio (Play): the wishing animation (x1 and x10 grid), the Season Rewards screen (needed an area frame around its scroll list to render cleanly) and the Cosmetics screen (buy, equip; the Flame aura shows as embers on the plaza character and the custom name tag draws).

## Redeem codes (built)
- `server/Data/CodeList` (server only, clients never see it): `[CODE] = { Rewards = {Sunstones, Wishstones, SkillPicks, Items, Titles, Cosmetics}, StartsAt?, ExpiresAt?, Disabled? }`. Sample codes WELCOME, DUOQUEST, THANKS, SEASON1: replace before launch.
- `Shared/Codes`: normalises the text, once per account (`Permanent.Codes.Redeemed`), start/expiry window, pays out. 11 tests.
- API `RedeemCode`: 5 wrong tries a minute, then a 30 second lock. UI: 🎁 button, Redeem Code box.
- Not built: codes with a global use limit (needs a DataStore counter).

## Character creator (built)
- Shared/Character + Config/Character: name rules (3-14 letters/digits/space/-/_, small blocklist plus Roblox's TextService filter on the server), class pick (Warrior/Cleric; Mage is Locked), look = indexes into skin / hair / outfit colour lists. `Permanent.Character`.
- API: CreateCharacter (once), UpdateCharacter (free), RenameCharacter (100 Sunstones). A new player (or any existing player who has no character yet) lands in the creator; the 🧍 button reopens it as the Character screen.
- The name shows in the HUD and the party. The look is drawn on the hero in the FIGHT scene (blocky body, or the Roblox avatar if the toggle is on). The plaza avatar is still the player's Roblox avatar.
- Not built: switching class after creation (needs a rule for loadouts, party snapshots and class leaderboards), name uniqueness, a plaza avatar that matches the creator look.

## Equip best gear (built)
- Bag screen: "Equip best" wears the highest Item Power of every gear type (rings keep the best two); ties keep what is worn; nothing is lost. Set bonuses are not counted, only Item Power. `Gear.EquipBest`, API `EquipBestGear`, 7 tests.

## Cosmetics in the fight scene (built, not yet seen in Studio)
- A hero's equipped aura now also shows on the drawn fight hero (follows body swaps). Name colour and title are still only on plaza/home characters; the fight scene has health bars, not name tags.

## Skill effects (built; NOT yet seen in Studio)
- `Config/SkillEffects` gives every ability, pet skill, status and ultimate a look (kind + colours); `client/Battle/SkillEffects` draws them from glowing parts, no assets. A test fails when a new skill has no look.
- Single-target hits: Slash, Cross, Smash, Orb, Pillar, Beam, Lightning, Shards, Flame, Claws, Burst. Area skills draw once over the side they hit: Nova, Quake, Whirl, Rain, Wave, Starfall. Heals: Rings, Spiral, Bloom, Cross. Shields: Dome, Barrier, Bubble. Buffs: Chevrons, Glyph, Pulse. Resurrection: Rise.
- Basic attacks differ per class (Warrior slash, Cleric holy burst, Mage arcane orb, monsters a plain burst). Pet skills pop their own symbol over the pet. Each ultimate has its own show (Charge, Dawn, Judgment).
- Wired into Replay for Damage, Heal, Status, Cast, Ultimate and Revive events; every call is wrapped in pcall so a bad effect can never break a fight.
- TODO: watch it in Studio and tune sizes/timings; ultimate damage hits still use the old bolt.

## Cosmetics expansion (built)
- 14 new shop items (auras Ocean/Blossom/Storm/Ember/Gilded, kill effects Stars/Bubbles/Embers/Snowfall/Glitter, name colours Ocean/Sunset/Ice/Ember) and 4 titles; 5 themed bundles (Inferno, Frostbound, Blossom, Stormcaller, Royal Gold) in a Sets tab. A bundle costs less than its three pieces and gets cheaper in proportion to what you already own. `Cosmetics.BuyBundle`, API `BuyCosmeticBundle`, 6 new tests.
- Not built: try-on preview. Prices are still first guesses.

## New classes: Mage, Ranger, Rogue, Summoner

All four are playable from the character creator (picking one at creation unlocks it and grants its starter skills). Each has 8 skills, 6 passives,
two paths of 3 skills, a season prize pet (Arcanix, Skyhawk, Shadowcat, Spiritling), class cosmetics and a leaderboard.

- Mage: Pyromancer (burning, big hits) and Frost Weaver (freeze, chill, party shields).
- Ranger: Sharpshooter (crit damage) and Beastmaster (pet bonuses +75%, pet skill +4 levels).
- Rogue: Assassin (crits, executes) and Duelist (dodging, ripostes that heal).
- Summoner: Necromancer (curses, plague, drain) and Spirit Caller (shields and heals). Spirits are drawn as skill effects; real minion combatants are still to do.
- New combat mechanics: damage over time (`Dot` on a status: Burning, Poisoned), `Stunned` flag (Frozen; bosses are immune), `PetBoost` on a subclass.
- Every pair of different classes has one ultimate (14 new). Add a second per pair later.
- All numbers are first guesses. To tune: class base stats, Ranger/Rogue crit and speed, DoT strength, ultimate multipliers.
- Not seen in Studio yet: new skill looks, Mage/Ranger/Rogue/Summoner hero colours, the six-button class row in the creator.

## Class picker and weapons (replaces the character creator)

- A new player only picks a class. Their Roblox name and avatar are used; there is no name or look to set (the old creator handlers remain on the server but the screen no longer uses them).
- Auto-combat does not start until everyone online in the party has chosen a class (PartyService.tickEntry); it starts right after the pick.
- Each class has a weapon (`Weapon` and `Blurb` in Config/Classes). `Shared/ClassWeapons` builds it as a Tool from parts. Tapping a class in the picker wields a local-only preview on the player's own character and shows a 3D view; choosing gives the real tool (server `WeaponService`, backpack + StarterGear) and equips it.
- Not seen in Studio yet: weapon orientation in the hand (blades should point forward; the bow and tome may need grip tweaks), the picker layout.

## HUD cleanup, Store, Season board, quests, Wishing Tree polish
- HUD: one **Store** button (premium shop, redeem code, cosmetics tabs); no Character button; fight log lives in the battle (watching) bar; no Battle view button.
- Season rewards is a plaza board next to the leaderboards and a button on the map; title only, with a hoverable "?" explaining cumulative rewards.
- Quests/Season pass: red dots on Daily/Weekly/Season tabs; claimable rewards sort to the top.
- Wishing Tree: themed banner per side (leafy green pets, violet skills), tinted cards, a "Pool" button per tier listing every pet/skill that tier can give by rarity, and a longer first-Legendary suspense sequence (gold heartbeat, held card, "NEW LEGENDARY" reveal).
- Open: shards still have no use (recommended: subclass skills + shard cost on high gear upgrades).

## Summoner rework: minions that cost health and can die
- New `Config/Minions` (Imp, Skeleton, Wraith, Ghoul, Bone Titan, Guardian Spirit). Effects `SpendHealth` (pay a share of max HP, never lethal), `Raise` (minion joins the party; strength from the summoner's stats x MinionPower), `Devour` (consume the weakest minion to heal). Conditions `SelfHealthAbove`, `MinionsBelow`, `HasMinions`.
- Minions are real party-side entities: enemies attack them (55% of hits while any live, taunting skeletons/titans take everything), they die, and they fall with their summoner. They never count as party survivors or the ultimate caster.
- Recovery: Soul Leech, Devour, Death Coil, ghoul leech, Necromancer lifesteal, Vampirism passive (new `Lifesteal` stat), Guardian Spirit's Spirit Mend.
- Shards: hidden from the HUD, daily/quest rewards and the skill unlock buttons for now (backend untouched).

## Pet shards, collection bonus and pet damage
- Duplicates beyond a pet's max rank become rarity shards. 30 shards buy a chosen pet (wish pets only); 10 condense into 1 of the next rarity ("Condense all" on the Pets screen). Deviation from the request: condense is 10:1, not 30:1 (tunable in Config/Pets `Shards`).
- Collection bonus: every owned pet gives rarity points x rank (Common 1, Rare 2, Epic 4, Legendary 8); each point adds 0.1% Attack and Health.
- All pets now also cast a basic "Pet Strike" every 3.5s; existing pet damage skills were buffed x1.6.

## Daily calendar
- The daily gift is a 7-day calendar (claimed / today / upcoming).

## Boss challenge rework
- The strike/charges mechanic is gone. A boss is a very hard normal auto-combat fight (Config/Bosses `Abilities`, `AttackMult`). Challenge whenever (20s cooldown); only your best damage ever counts toward the boss. Tier thresholds still need real-gear tuning (test parties without gear reach roughly 1-3x).

## Combat log, DPS meter, buffs, gear
- Pet hits are logged as the pet, not the owner. `FightStats` builds a damage meter (players in their own colours, pets and minions as separate rows); shown in the Log screen and live in the combat log ("DPS" toggle).
- Buffs show in the combat view (above the skill bar) so they stay visible with the HUD hidden.
- Roblox's default Backpack hotbar is disabled (the class weapon is cosmetic only).
- Gear names are class themed (Config/Gear `ClassNames`); in-battle weapon model is per class; the Hero screen shows the equipped pet.
- Studio-only dev button "+5 levels" (DevLevel).

## Skills: copies, rank 20
- Spare skill copies are banked per rarity on the skill (`SkillState[id].Copies`); "Consume" on the Skills page turns same-or-lower rarity copies into XP (`ConsumeSkillCopies`). Max rank is 20 with a slow XP curve (x1.24 per rank, ~3,660 XP total). Tier bonus is now +2/+4/+6 ranks (Rare/Epic/Legendary); the combat level cap is still 20.

## Partner (ghost companion)
- The starter companion now mirrors its owner: same gear (slots, rarity, power), a pet of the owner's rarity at the owner's pet level/rank, the owner's collection bonus and average skill level.

## Arena, monsters and monster skills
- Scene: zone ambience (fireflies, leaves, dust, sand, snow, embers, mist, bubbles, sparkles), two parallax hill layers, slow clouds, swaying trees and an apron of ground behind the fight.
- `client/Battle/Creatures.luau`: 12 new body shapes with animated parts (wings, legs, tails, jaws, arms, claws, floating, squish). `Actor` animates tagged parts and has attack styles (Lunge, Slam, Pounce, Bite, Shoot, Cast, Spin); monsters pick one by body shape (`Look.Attack` overrides).
- 24 new monsters in zone pools (`Config/Stages ZonePools`, zone 1 keeps the starter trio) and 4 new bosses (Dire Wolf, Broodmother, Lich King, Inferno Lord). 15 new monster skills (poison, webs, frost breath, ember bolt, boulder toss, drain, screech, shell guard, swoop, thunderclap, ground pound, bone rattle, howl, pounce, sand sting) with looks and cast animations.

## Levels and the level-90 subclass
- Level cap 50 -> 120. At level 90 each of the 12 paths unlocks its final form (Warlord, Paragon, Archon, Crusader, Cataclysmist, Glacialist, Deadeye Marshal, Wildlord, Nightblade, Swordsaint, Lich, Ancestral Sage): stats stack on the first path and it brings one Legendary skill. XP curve and stat growth past 50 are NOT yet balanced.
- Boss fights already hold the party's stage fights while the replay plays (no passive progress meanwhile).

## Guilds (cross-server)
- Guilds live in a shared DataStore (`DuoQuestGuilds`: G_<id>, N_<name>, U_<userId>, Directory) so every server sees the same guild; Studio falls back to memory. All writes use `UpdateAsync` with pure transforms (`Shared/Guilds`).
- Collective daily (3) and weekly (3) missions: everyone's actions (queued in `Permanent.GuildPending` by `Quests.Record`, flushed every ~2 min) fill one bar; goals scale with active members; the guild earns Guild Points when a bar fills (+bonus for finishing all); each contributor claims personal gold, wishstones and Guild Marks.
- The leader alone spends Guild Points on upgrades (Attack, Max Health, Defense, Attack Speed, Crit Chance/Damage, EXP, Gold, member slots). Combat upgrades ride on `Pets.Collection(...).Mods`, EXP/gold on `Permanent.GuildBuffs` in `Progression.ApplyClear`.
- Succession: leader unseen 5 days -> next officer (longest serving), then top contributor, who must have been seen in the last 3 days; otherwise nothing changes and it is checked again whenever the guild is opened or flushed.
- Weekly raid boss (4 bosses cycle): one shared health bar sized from active members' frontiers, 3 strikes per member per day, rewards by damage share plus a bonus when it falls; last week's raid stays claimable.
- Guild pets: 7 guild-only pets (`Guild = true`), earned with the Guild Wish using personal Guild Marks (pity at 12 / 60).
- Not yet: guild chat, expeditions/dungeons, live DataStore test in a published place.

## Pet damage
- Every pet hit (its strike and its skill, tag `Pet_*`) is multiplied by `Config/Pets.DamageScale` (4.5) in `Simulation:DealDamage`, and by the owner's `PetDamage` stat. Beastmaster adds +200% PetDamage (Wildlord +100% more), so the pet out-damages the Ranger (measured ~60-70% of the pair's damage vs ~40-45% for a normal build). `XPScale` retuned to 11 so level pacing still holds.

## Skills / Passives menu pass
- Skills and passives can be unequipped (a skill loadout needs at least one skill; empty slots show a "+" plate you can drop onto). The Skills / Passives tabs put that list at the top of the pool; owned skills sort by the tier you hold.
- Global look pass (Go Go Muffin style): chunky shaded buttons with a dark rim, a banner across the top of every window, stroked panels. A full per-menu layout redo (card grids, detail popups) is still to do for the other screens.

## Damage over time and skill utility
- Stacking DoTs: Burning (max 5, Mage/fire), Poisoned (max 8, Rogue, the deepest stacker) and the new Bleeding (max 5, Warrior/Ranger). Each stack ticks for a slice of the caster's Attack plus a slice of the target's max health; the %-health part is capped by the caster's Attack and bosses take only 40% of it (`Simulation.percentDamage`).
- Damage effects can carry `PercentTargetHealth` (+`PercentCap`); low-damage skills across all classes got a small %HP hit and/or a stacking DoT (Fireball/Meteor burn, Backstab/Fan of Knives/Flurry/Poison Blade poison, Whirlwind/Crushing Blow/Power Shot bleed, Smite/Volley/Haunt etc. small %HP). Skill tooltips show the %HP and stack lines.
- Measured on the world boss (where %HP is reduced): Rogue +26%, Ranger +20%, Mage +12%, others +3-5%; against ordinary monsters the %HP portion matters more.
- Stack counts are drawn on the status pips over each fighter (`Actor:_updatePip`); combo layers show from 1 and a finisher pops "COMBO xN!" (2026-11-19).

## IP (Item Power) score
- `shared/Power.luau`: one number for hero strength. Level x5, equipped gear (Gear.ItemPower), skills (tier + level), passives, active pet (rarity, level, rank), pet collection, subclass, titles, guild bonuses. Never affects combat.
- Shown on the HUD (hover for the breakdown), Hero screen, pet cards, skill tooltips and gear text. Tests: PowerTests.

## Combat rows, monster utility, pets and pacing (balance pass)
- Rows: melee fighters and all summons stand in the Front row, ranged fighters in the Back row, bosses and enemy casters behind their minions. Melee attackers reach only the front-most living row; back-row attackers have a 35% chance per basic attack to reach past it, and skills marked `Reach = "Any"` snipe the back row. Area attacks hit only the main target's row unless the skill is `AllRows` (ultimates, boss attacks and a few piercing skills). The battle view lines fighters up by row, side by side.
- Monsters: bleeds, poison, curses, slows on small monsters (Wolf, Boar, Harpy, Skeleton, Goblin, Mushroom, Mummy, Golem, Yeti). Hard crowd control (Stunned) only from bosses (Stagger).
- Cleanse: `Cleanse` effect (Purify, Sanctuary, Rallying Cry). Few classes have it.
- Pets: ownership, level, XP and the equipped pet are account-wide (Permanent), levels 1-50 at 200 XP x level, buffed stats/rank bonus/damage.
- Paragon: past level 120, XP fills Paragon levels (max 100, +0.4% Attack/Health/Defense each).
- Pacing and class balance tuned with the balance harness (scratchpad), target: level 90 in 7-10 days.

### Haste, gear rolls, pet stats and pacing (2026-11-16)
- Haste stat (Add): slightly shortens ability cooldowns, capped at 50%. Pants roll it; some pets and subclasses grant it.
- Gear stat rolls vary 0.85-1.15 per piece (Roll on the gear row).
- Pet stat units rebalanced from measured value: Attack/MaxHealth/Defense strongest, then AttackSpeed, CritMultiplier, CritChance and Haste (weakest per point, so their per-point values were raised).
- XPScale 0.8 plus per-subclass DamageDealt/MaxHealth autotune: level 90 targets about 65 online hours (7-10 days with idle). Harness: scratchpad balance90/autotune. Measured spread after 4 rounds is roughly 42-68h (3 seeds, noisy); re-run with more seeds before launch.

### Main menu and characters (2026-11-16)
- Players.CharacterAutoLoads is off: nobody spawns until they press Play on a character at the main menu (client/UI/MainMenu).
- A character is just a class with its own season progress. Up to 2 per player (Characters.MAX). Permanent.Slots/ActiveSlot; profile.Season is always the active character's season, the other is stashed in its slot. Old profiles migrate into slot 1.
- Server: MakeCharacter(classId), PlayCharacter(slot) (spawns, joins party; switching mid-session re-joins the party and is refused while a partner is online: LeavePartyFirst).
- Not yet done: delete character, per-character names, Studio visual check, switching while partnered.
