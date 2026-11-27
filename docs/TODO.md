# Idle Party Quest: what is left

Last updated 2026-11-25. Claude keeps this list current. Short entries; details are in CLAUDE.md and the other docs.
The release checklist (big picture, phases to launch) is docs/RELEASE.md.

## Waiting on the owner (only you can do these)

- DONE 2026-11-24: the game is on Roblox ("Idle Party Quest", private, Studio API access on); VIP (2101996470) and Extra
  Character Slots (2102236400) Game Passes and the 4 Sunstone products (3735896385/525/614/758) exist and their ids are in
  `Config/Premium`. SEEN in Studio 2026-11-24 with free test purchases: the creator owns both passes (4 slots, VIP perks: gold 25%, no XP, pet slot, bag +20); each pack pays its Sunstones + first-time bonus once (160/840/1800/4000, a 2nd Handful = +80). The test Sunstones were cleared (Test cheats "Sunstones = 0", which also restores the first-time pack bonuses). Passes are re-checked on join (live only): a refunded pass is removed. Sunstone products have Roblox
  "Managed pricing" on, so their Robux price may drift from the numbers shown in our Store.
- DONE 2026-11-24 (owner): renamed, description, icon + thumbnail uploaded, Studio API access on, Max Players 16.
- **Publish** (File > Publish to Roblox; only "saved" so far), then fill in **Content rating** and set **Manage audience**
  (friends can then playtest). Devices: Computer only until phone/tablet is checked.
- **Logo for the main menu** (optional): upload `branding/logo.png` as an image and send the id (`Config/Branding.LogoImage`).
- **Season dates.** Season 1 runs Nov 1 to Feb 1, which is a placeholder. Suggested: 6-week seasons, the first one 4 weeks,
  starting on launch day.
- **Open questions.**
  - The 4 questions in docs/TOWN.md.
  - Market "Pet Food x5" (2,304g) vs. Pet Store "Pet Snack" (6,900g each) for the same item.
  - A Crypt run at stage 6 pays about 9.7K gold.
- **Fresh start at launch?** If testers' progress should not carry into the real launch, rename the save store
  `IPQ_PlayerData` (renamed from `PlayerData_v1` on 2026-11-24, so saving starts clean now) just before launch.

## Building next (Claude)

- Done 2026-11-24: monsters and bosses for stages 101-200; the sky follows the biome in battle view; Mastery talents (level 81+).

- DONE 2026-11-24: 8 lots + overflow lots 9-16 (16-player servers), welcome back card, solo AFK earnings, expedition
  sign, battle card panel, Hide HUD cleanup, wish sounds, training dummy countdown.
- Phone and tablet: first pass done 2026-11-24 (Device Simulator). Not done: a real phone test; text is still small on
  the smallest phones (HUD size setting helps); Devices in Creator Hub can include Phone + Tablet after a real test.
- **Party join across servers**: untested live (needs 2 real accounts).
- Balance pass: DONE 2026-11-25 (BALANCE.md from "Late game runaway" on; class report artifact). Still open:
  - Warriors lead at L100 with a companion party (170/156 vs 116-141); check with real parties before cutting more.
  - A stage ~95-100 wall still holds several paths for 10-20 levels (Legendary drops stop improving at stage 100).
  - Late frontier fights are ~6-7 s (10-12 s through L40); longer would need more monster health past stage 80.
  - Not seen in Studio: how the longer fights feel at the frontier, the doubled talents in the Talents screen numbers.

## Season goals (2026-11-25)
- DONE (not seen in Studio): Bestiary and Class mastery, kept every season (dock 🏅 Collection). Party kills count;
  small capped stat bonuses (bestiary +10% max, mastery +5% max).
- Ideas not built: zone set collection, weekly challenge tower, account achievements, mastery head start next season.

## Not seen working in Studio yet

- **Tonight (2026-11-25):** Collection screen (Bestiary/Mastery tabs, monster hover, pop-ups), damage numbers by who
  hit whom, NumberScale 100 (10x numbers), the slow pacing in real play.

Seen 2026-11-24: HUD size (now scales only the HUD), map badge tooltip, tutorial arrows (steps 3-5), fallen ally tags,
lightning, founding a guild and guild chat, cosmetics Try, COMBO pop-ups and status icons, the VIP second pet slot.

These pass the tests but nobody has looked at them in the game.

- **Combat:**
  - Wave banners in dungeons.
- **Cosmetics:** season auras once won, the other auras and kill effects.
- **HUD and menus:**
  - Headshots of other real players in your party.
  - The owner sign of a lot shared by two real players.
  - The skipped-tutorial toast.
- **Social:** gifting (needs two real players).
- **Pets:** feeding a max-level pet actually filling the shard bar (the "max: -> shards" button shows).
- **Town:**
  - The "Relic Hunter" title moment.
  - A fishing catch made by hand.
  - Elder Thessaly's errand.
- **Sound:** loudness between music and effects, the music switching for the world, season and guild bosses, and the
  new wish sounds (Legendary build-up).
- **Expeditions:** the "!" sign over the Expedition Camp and the dot on the Battle button.
- **Overflow lots 9-16** (needs 9+ parties on one server).
- **Training dummy** "Again in Ns" countdown.

## Before launch

- Publish, then test with 2-4 real accounts (docs/PLAYTEST.md): party join, ghosts, saving, rejoining on another server.
- A live save check after publishing (DataStore, session lock, autosave).
- Read the playtest log (📝 > Read log) after each test day.
