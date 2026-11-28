# Season ideas (draft 2026-11-27, owner to pick)

Owner rules (2026-11-27): every season is unique and new; the first season lasts 4 weeks; playtest progress does not
carry into launch.

What already changes every season: everyone restarts at level 1 (pets, Sunstones, cosmetics, titles kept), a new
leaderboard, the season boss, prize auras. What makes a season *new* is its **mechanic**: one rule or system that
only exists that season (`Config/Seasons` `Mechanic`, nothing built behind it yet). Each one below also gets its own
name, season boss look, prize aura and a title.

## Candidates

1. **Bonds** (co-op): heroes who fight in the same party build a bond level together (per pair). Bond levels give
   small shared perks (party Attack/Health, a pair ultimate charge bonus) and bond titles. Fits the game's core idea
   (playing together); ghosts/companions count at half. Low risk: a stat layer plus a screen.
2. **Relics**: bosses and dungeons drop season-only relics, a 4th kind of loot with build-changing effects
   ("crits chain to a second enemy", "heals overflow into shields", "summons explode on death"). 3 relic slots.
   Biggest variety in builds; needs the most balancing.
3. **Elemental tides**: each week one element (Storm, Frost, Fire, Void) rules: enemies of that element are stronger
   but drop double gold and runes, and one class gets a weekly spotlight bonus. Uses the elemental zones 11-20.
   Keeps a 4-week season changing week to week.
4. **Mutations**: monsters roll affixes (Shielded, Splitting, Vampiric, Enraged, Frozen-aura...) from the stage they
   are on; each affix you beat for the first time fills a season codex with rewards. Changes fights more than builds.
5. **Curses** (opt-in difficulty): pick curses before pushing (enemies +30% health, no healing between waves...);
   each one raises gold/XP and a separate "cursed" leaderboard. Rewards skill for top players, ignorable for others.
6. **Invasion**: a monster faction attacks the town a few times a day; the whole server fights waves at the gate for
   a shared reward track. Most social, most new code (a server-wide event).

## Suggested order
- **Season 1 (launch, 4 weeks): Bonds.** PICKED and BUILT 2026-11-27 (Config/Bonds, Shared/Bonds; on for the playtest
  season too). Name "Unbroken", season boss The Oathbreaker (broken shackles, snapped chains, violet
  cracks), prize Kindred aura (rose + gold ribbons circling each other) for the Top 20%. Not seen in Studio yet.
- **Season 2: Elemental tides.** Weekly change, reuses the elemental zones; light on new UI.
  DRAFT BUILT 2026-11-28 (owner has not picked it yet): `Config/Tides` + `Shared/Tides`, draft season in
  `Config/Seasons.Drafts[2]` (the real calendar never starts a draft; Studio's "Start next season" cheat does).
  Name "Tidebreak". Each week one element rises (Fire, Storm, Frost, Void; 5 zones each, so all 20 zones are covered):
  monsters there +20% health and attack, wins there +100% gold, +25% XP and an extra rune roll; one class a week
  in the spotlight (+10% attack and health in stage fights). Season boss The Maelstrom (storm-blue giant, glowing
  cracks, four tide orbs round its shoulders); prize Tidebound aura (four sparks, one per tide, circling the hero) for
  the Top 20%. Shown on the Season screen (tide card) and the HUD map card (a rising zone's name in the tide colour).
  Away fights (Offline estimate) ignore the tide. Not balance-simmed yet: a rising frontier zone is a harder push for
  a week, paid back by double gold there. To make it real: move the entry into `Seasons` with real dates.
- **Season 3: Relics.** The big build-variety season, once the base game balance is settled from real players.
- Later: Mutations, Curses, Invasion.
