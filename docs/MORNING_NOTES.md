# Morning notes (2026-11-27 overnight)

Branch `claude/overnight-world-systems`, everything pushed. 54/54 suites pass, lint 0. Studio left saved, unmuted,
not playing. (The notes from 2026-11-15 are in git history.)

## Needs you
1. **Your party's stage was knocked back by the season test.** Before the fix, the "Start next season" cheat saved
   your real party record (`IPQ_Parties`) as season 2 at stage 1; coming back to season 1 reset it again. Your hero
   is untouched (level 115, furthest 137) but the party frontier dropped from 137 (it has climbed back to ~51 since).
   It is fixed for the future (below). I was not allowed to write the live store; to restore it, stop Play and run
   this in the Studio command bar (Edit mode), then click Continue on the "Dangerous Command" dialog:
   ```lua
   game:GetService('DataStoreService'):GetDataStore('IPQ_Parties'):UpdateAsync('Party_97c97a66-bf0e-4f24-996f-6158315617f7', function(v) if v == nil or v.SeasonId ~= 1 then return nil end v.Frontier = math.max(v.Frontier, 137) return v end)
   ```
   Or just let it climb back.

## Seen in Studio tonight
- Season flow with the test cheat: "Season 2 has begun" card + last season's row, hero and companions at level 1,
  party at stage 1, Season screen reward claimed. The card's season line is now a button that opens the Season screen.
- Your real save after a test season: still season 1, Rogue 115 (DataService keeps the stored profile).
- Daily gift (flat 10K/12K/15K/18K...), Collection screen, expedition-ready sign over the camp, fallen-ally tags and
  banner, dungeon "Wave 2 / 3" banner.

## Fixed
- SeasonResultsService crashed every minute in Studio (a missing local function: the Top-% histogram never got
  written). New `tools/sim/lint.sh` finds names used but never defined in every file; it runs at the end of runall.sh.
- Test season no longer touches the real party store (PartyService keeps writes in memory while it runs; checked:
  the record stayed season 1). `Party.EnsureSeason` only resets forward.
- Season screen said "Reach stage 3 to be ranked (you are on stage 4)" while waiting for the next bracket update.
- Boss/dungeon arena banners sat on top of the stage card (moved lower); the stage battle card hides during those fights.

## Performance (first real numbers, docs/RELEASE.md section 4)
Test cheats > "Stress test" fills the free lots with fake parties. On your PC, 16 lots, standing among them: ~55 fps,
p95 25-33 ms, some 70-110 ms hitches (rendering, not our Lua: fight starts <= 5 ms, events <= 3 ms). Changes: at most
6 neighbour fights animate at once (3 on phones / low graphics), lots and cards redraw only when they change, the
server party loop yields after 20 ms (one fight sim = 5-38 ms, `tools/sim/fightbench.sh`). Phones still unmeasured.

## Noticed, not changed
- In a fresh season, veterans' pets (levels capped to the hero's level, but ranks and pet gear kept) out-damage the
  level 12 heroes: 3 of the top 4 damage rows in a Crypt run were pets. Probably fine (permanent progress carries the
  early season), but say if you want pets toned down early in a season.
- A missing asset warning on every Play (`rbxassetid://203785492`, "Asset type does not match") is not from our
  code; maybe a plugin or something in the place.
