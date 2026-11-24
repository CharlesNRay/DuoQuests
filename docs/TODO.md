# Idle Party Quest: what is left

Last updated 2026-11-24. Claude keeps this list current. Short entries; details are in CLAUDE.md and the other docs.

## Waiting on the owner (only you can do these)

- DONE 2026-11-24: the game is on Roblox ("Idle Party Quest", private, Studio API access on); VIP (2101996470) and Extra
  Character Slots (2102236400) Game Passes and the 4 Sunstone products (3735896385/525/614/758) exist and their ids are in
  `Config/Premium`. Not tested: an actual purchase (Studio test purchases are free). Sunstone products have Roblox
  "Managed pricing" on, so their Robux price may drift from the numbers shown in our Store.
- **Rename on Roblox.** Set the experience title to *Idle Party Quest* in Creator Hub. Put the search words in the
  description, for example "idle RPG, incremental, co-op with friends".
- **Logo.** New art is in `branding/` (2026-11-24): `icon_512.png` for the game icon, `thumbnail.png` (and the louder
  `thumbnail_hype.png` / `icon_hype.png`) for the page. Upload `logo.png` as an image too and send the id for the main menu.
- **Studio API access.** Game Settings > Security > "Enable Studio Access to API Services". Without it, Studio saves
  nothing and the 📝 feedback log only lasts until Play stops.
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

- More player homes. Lots 5-8 continue down the homes street, which needs a gate in the town wall. Max Players is 4 until then.
- Balance pass:
  - The class roster spread (docs/BALANCE.md).
  - (Checked 2026-11-24: Judgment is fine at equal rank; it lags only because Epic skills rank up slower.)
  - Stages 101-200 have not been tuned; the bot rarely gets past stage 90.

## Not seen working in Studio yet

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
- **Sound:** loudness between music and effects, and the music switching for the world, season and guild bosses.

## Before launch

- Publish, then test with 2-4 real accounts (docs/PLAYTEST.md): party join, ghosts, saving, rejoining on another server.
- A live save check after publishing (DataStore, session lock, autosave).
- Read the playtest log (📝 > Read log) after each test day.
