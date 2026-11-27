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
Built 2026-11-27 (tests green, NOT seen in Studio): the season schedule and the rollover. The end-of-season rewards
(leaderboards, brackets, frozen results, prize pets and auras) are built and tested headless, NEVER run live.
- [x] [claude] Season rollover (`Shared/SeasonRollover`): on the first join after a switch every character keeps its
      class and starts fresh; kept: everything under Permanent plus unused items, bag size and wish pity
      (`Config/Seasons.Carry`). Last season's characters go into SeasonHistory; a "Season N begins" card shows once.
- [x] [claude] Season switch without republishing: the current season is the newest one in `Config/Seasons` whose
      StartsAt has passed (`Shared/SeasonClock`). Add the next season ahead of time; players online at the switch are
      asked to rejoin. Season boss, leaderboards, results, parties and the market follow the new id.
- [x] [claude] Headless tests: SeasonRolloverTests (31) + a DataService section (load after a switch).
- [x] [claude] Studio check with the Test cheats > "Start next season" button (SEEN 2026-11-27: "Season 2 has begun"
      card with last season's row, hero + companions level 1, party at stage 1, Season screen reward claimed). Found
      and fixed: SeasonResultsService crashed every minute (a missing local function); `tools/sim/lint.sh` now finds
      undefined names in every file and runs at the end of runall.sh. Also found: the test season saved the real party
      record (IPQ_Parties) as season 2 and back at stage 1; now PartyService keeps every party write in memory while a
      test season runs (SEEN: the record stayed season 1 after a test season) and Party.EnsureSeason only resets forward.
- [ ] [both] A real switch on the live game before the first real season ends (e.g. a short season added to the
      schedule during the playtest). NOTE: it uses real season ids, so launch then needs the fresh start below.
- [ ] [owner] Season length and launch dates (suggested: first season 4 weeks, then 6-week seasons).
- [ ] [owner] Does each season get something new? (The config has a `Mechanic` hook: elements, relics, curses...,
      none built.) Season 1 can launch without one, but season 2 should probably have something.
- [ ] [claude] Fresh start at launch, if wanted: playtest seasons leave data in the season-keyed stores
      (`IPQ_Leaderboard_S<n>`, `IPQ_SeasonResults`, `IPQ_SeasonBoss`, `IPQ_SeasonHist_S<n>`) and in players' saves;
      either rename the stores or start launch at a season id the playtest never used.

## 4. Scale and safety (before going public)
- [~] [claude] **Performance with a full server** (first pass 2026-11-27, Studio on the owner's PC; phones NOT measured).
      Client: Test cheats > "Stress test" fills the free lots with fake parties replaying your latest fight and prints
      `STRESS` lines (frame avg/p95/worst, memory, parts, slowest fight start/event/snapshot). 16 lots, standing among
      them: 8 animating = avg 18 ms (~55 fps), p95 25-33 ms, worst 70-110 ms vs 1 lot avg 16.7 (60 fps cap), p95 21,
      worst 28. Fight starts take <= 5 ms, events <= 3 ms, so the hitches are rendering, not our Lua. Changes: at most
      6 neighbour fights animate at once (3 on touch / low graphics; yours always), lots, cards and open-lot markers
      are only redrawn when they change (every 3 s snapshot rebuilt all of them; now 0.2-5 ms). Server: one fight
      simulation costs 5-38 ms (`tools/sim/fightbench.sh`); the party loop now yields after ~20 ms of work so 16
      parties falling due together cannot stall the server. Still open: a real phone with a busy server, network
      (ArenaFight pushes) on a live 16-player server.
- [x] [claude] DataStore budget (2026-11-27, from the code; not measured live). Roblox per server per minute:
      reads (GetAsync + every UpdateAsync) and writes 60 + 10/player (220 at 16 players), sorted reads 5 + 2/player.
      Full server worst case (everyone improving every minute): writes ~105 (16 solo parties saving every 30 s = 32,
      leaderboards up to 48, profiles 8, guilds ~11, histogram/boss/playtest ~7), reads ~105 + guild screens. Fixed:
      the 8 boards were read every minute (over budget below 2 players: 8 vs 7) -> 3 per minute in turn, only with
      budget left; Season screen reads only with budget; the season results no longer write the same scores as the
      leaderboards (-32 writes). Also fixed: the Top-% histogram counted a player again on every server they joined
      (and per character) -> counted once, in their save (`Shared/SeasonHistogram`); leaderboards kept the old season's
      stores and scores after a switch -> follow the season. Watch live: "DataStore request was added to queue".
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
1. **Season rollover**: built 2026-11-27, seen in Studio with the test cheat; needs one live switch.
2. **Full-server performance**: PC measured in Studio (fine); phones and live network not measured.
3. **Pacing with real players**: only sim-tested; may need a round of retuning after playtests.
4. **Live multiplayer** (cross-server party, guild load, session locks): only headless tests.
5. **Late game**: stages loop after 200, balance checked to L100 (~150 h); no real player gets near it before launch,
   so it is fine for release but needs watching.
