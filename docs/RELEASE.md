# Idle Party Quest: release checklist

Made 2026-11-26. Everything between now and the official release, in order. Day-to-day leftovers stay in docs/TODO.md;
this list is the big picture. Tick items here as they land.

Legend: **[owner]** only you can do it, **[claude]** I build or check it, **[both]** needs you in the game with me.
**BIG** = not sure how it behaves yet, and probably a fair bit of work.

## 1. Before the first playtest (friends, 2-4 people)
- [ ] [claude] Muted Studio pass of everything never seen: slow pacing and 3.5x longer fights, boss change, flat daily
      gift, Collection screen, damage numbers by who hit whom, NumberScale 100, this week's skill/pet changes.
- [ ] [owner] Publish (File > Publish to Roblox), fill in the Content rating questionnaire, set Manage audience.
- [ ] [owner] One test purchase on the live game (cheapest Sunstone pack), or set the product ids to 0 for the test.
- [ ] [both] Live save check alone: play 5 min, leave, rejoin; then a second server kicks the first, nothing lost.
- [ ] [both] Two-account check: party by code, guild + chat + gift, duel, headshots on HUD and battle card.
- [ ] [owner] Decide: does playtest progress carry into launch? (If not, rename the save store just before launch.)

## 2. Playtest rounds
- [ ] [owner] Send testers the checklist in docs/PLAYTEST.md.
- [ ] [claude] After each test day: read the playtest log (feedback, errors, session lengths), fix, push.
- [ ] [both] **BIG: Does the pacing feel good?** Slow upgrade loop, long fights, walls at bosses: all tuned in the
      headless sim only. Real session lengths (the Sessions log) decide whether early game needs to be faster.
- [ ] [both] **BIG: First 10 minutes.** Tutorial, menu, town size: can a new player find their way without help?

## 3. Seasons (needed before the first season ends)
Today: one season, "Prototype Season", dates are placeholders (Nov 1 to Feb 1). The end-of-season rewards
(leaderboards, brackets, frozen results, prize pets and auras) are built and tested headless, NEVER run live.
- [ ] [claude] **BIG: Season rollover is not built.** Nothing moves a player into the new season when
      `CurrentSeasonId` changes: their old season data would just carry on. Needed: on join, if the player's
      `Season.SeasonId` is old, pay their season prizes, keep Permanent (pets, passes, collections, cosmetics),
      start fresh season data for every character slot; parties, guild raids, market, boss records follow the new id.
- [ ] [claude] Season switch without republishing (the config says "later this moves to a DataStore key").
- [ ] [claude] A headless test that runs a whole season end: results freeze, prizes paid once, new season starts.
- [ ] [both] Run a fake short season on the live game (e.g. a 1-hour season) before the real one ends.
- [ ] [owner] Season length and launch dates (suggested: first season 4 weeks, then 6-week seasons).
- [ ] [owner] Does each season get something new? (The config has a `Mechanic` hook: elements, relics, curses...,
      none built.) Season 1 can launch without one, but season 2 should probably have something.

## 4. Scale and safety (before going public)
- [ ] [claude] **BIG: Performance with a full server.** 16 players = up to 16 lots, each with 4 heroes, summons, pets,
      particles and damage numbers. Never measured. Needs a stress test (fake fights on all lots in Studio, watch
      frame time, memory and network), then cutting effects at distance if needed.
- [ ] [claude] DataStore budget: guild writes, leaderboards, playtest log and season reports all at once on a full
      server. Check against Roblox request limits.
- [ ] [both] Party join across servers and guilds with many members, live (only tested headless).
- [ ] [both] Overflow lots 9-16 (needs 9+ parties on one server; can be faked with test accounts or skipped by
      lowering Max Players).
- [ ] [owner] Real phone/tablet test, then turn on Phone + Tablet in Devices.

## 5. Store and polish
- [ ] [owner] Logo image upload (`Config/Branding.LogoImage`).
- [ ] [both] Purchases tested live: each pack, both passes, rejoin keeps them. Sunstone prices use Managed pricing,
      so the Robux shown in our Store may drift: check they match.
- [ ] [both] Sound: loudness music vs effects, boss music switching, the wish sounds (nobody has listened yet).
- [ ] [owner] Open questions: Pet Food price (Market 2,304g x5 vs Pet Store 6,900g each), Crypt pay at stage 6,
      the 3 town questions in docs/TOWN.md (fishing + pet park, sparring ring, town size).
- [ ] [claude] Remaining never-seen UI (docs/TODO.md list): wave banners, auras once won, relic title, hand-made
      fishing catch, Elder's errand, expedition sign, pet shard bar.

## 6. Launch day
- [ ] [owner] Set the real season dates, final save-store decision, publish.
- [ ] [owner] Make the game Public, thumbnails and description final.
- [ ] [claude] Watch the error log and session lengths for the first days; hotfix list ready.

## Not sure yet, a fair bit of work (summary)
1. **Season rollover**: missing, must exist before the first season ends.
2. **Full-server performance**: never measured.
3. **Pacing with real players**: only sim-tested; may need a round of retuning after playtests.
4. **Live multiplayer** (cross-server party, guild load, session locks): only headless tests.
5. **Late game**: stages loop after 200, balance checked to L100 (~150 h); no real player gets near it before launch,
   so it is fine for release but needs watching.
