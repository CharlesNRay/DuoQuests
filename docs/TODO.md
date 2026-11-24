# Idle Party Quest: what is left

Last updated 2026-11-24. Claude keeps this list current. Short entries; details are in CLAUDE.md and the other docs.

## Waiting on the owner (only you can do these)

- **Game Passes and products.** In Creator Hub, make the *VIP* and *Extra Character Slots* Game Passes and the four
  *Sunstone* Developer Products, then send the ids. Until then the buttons say "coming soon".
- **Rename on Roblox.** Set the experience title to *Idle Party Quest* in Creator Hub. Put the search words in the
  description, for example "idle RPG, incremental, co-op with friends".
- **Logo.** `branding/logo.png` still shows the old Duo Quest art. Upload a new one and set `Config/Branding.LogoImage`.
- **Studio API access.** Game Settings > Security > "Enable Studio Access to API Services". Without it, Studio saves
  nothing and the 📝 feedback log only lasts until Play stops.
- **Season dates.** Season 1 runs Nov 1 to Feb 1, which is a placeholder. Suggested: 6-week seasons, the first one 4 weeks,
  starting on launch day.
- **Talent points after level 81.** All talents are full at level 81 and levels go to 120, so levels 82-120 give no points.
  Suggested: a *Mastery* row of 4 talents with 10 ranks each that opens at level 81 (Skill Power, Overdrive, Party Spirit,
  Fortune). Not decided yet.
- **Open questions.**
  - The 4 questions in docs/TOWN.md.
  - Market "Pet Food x5" (2,304g) vs. Pet Store "Pet Snack" (6,900g each) for the same item.
  - A Crypt run at stage 6 pays about 9.7K gold.
- **Fresh start at launch?** If testers' progress should not carry into the real launch, rename the save store
  `PlayerData_v1` to `PlayerData_v2` just before launch.

## Building next (Claude)

- Enemies and bosses of their own for the stage 101-200 biomes. Right now they reuse the stage 1-100 monsters.
  (in progress)
- The sky and light change with the biome in battle view. Dark biomes such as Void and Astral show a blue daytime sky now.
  (in progress)
- The Mastery talent row, once you say yes.
- More player homes. Lots 5-8 continue down the homes street, which needs a gate in the town wall. Max Players is 4 until then.
- Balance pass:
  - The class roster spread (docs/BALANCE.md).
  - Judgment is a weak 4th Cleric skill.
  - Stages 101-200 have not been tuned; the bot rarely gets past stage 90.

## Not seen working in Studio yet

These pass the tests but nobody has looked at them in the game.

- **Combat:**
  - A fallen ally's red outline and "is down" banner.
  - Wave banners in dungeons.
  - The combo pips and the "COMBO xN!" pop-up.
  - The new status icons.
  - Lightning flashing in Stormspire, seen in a real fight.
- **Cosmetics:** season auras once won, the other auras and kill effects, cosmetics "Try" (60 s).
- **HUD and menus:**
  - The HUD size setting.
  - Headshots of other real players in your party.
  - The owner sign of a lot shared by two real players.
  - The map badge tooltip.
  - Tutorial arrow steps after step 1.
  - The skipped-tutorial toast.
- **Social:** guild chat, gifting.
- **Pets:** the VIP second pet slot, the pet-food shard bar.
- **Town:**
  - The "Relic Hunter" title moment.
  - A fishing catch made by hand.
  - Elder Thessaly's errand.
- **Sound:** loudness between music and effects, and the music switching for the world, season and guild bosses.

## Before launch

- Publish, then test with 2-4 real accounts (docs/PLAYTEST.md): party join, ghosts, saving, rejoining on another server.
- A live save check after publishing (DataStore, session lock, autosave).
- Read the playtest log (📝 > Read log) after each test day.
