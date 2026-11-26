# Playtest with real people (setup + checklist)

Written 2026-11-23 for the first live tests, updated 2026-11-26. Progress saving is built in (DataService): a player's profile is saved
every 2 minutes, when they leave, and when a server shuts down. Each profile is locked to one server at a time, so it
cannot be edited from two places at once. Since 2026-11-24 the place is saved to Roblox ("Idle Party Quest", private)
with Studio API access on, so Studio playtests save too (and change your real profile). Saving has still not been checked
in the LIVE game. The real save code is tested headless against a fake DataStore
(`DataServiceTests`: leave and rejoin on another server, opening the game twice, a crashed server, a party teleport,
Roblox errors, old saves upgraded), so the live check below is a confirmation, not a first try.

## One-time setup (owner, in Roblox Studio)
1. **Publish the place**: File > Publish to Roblox. Ctrl+S (Save to Roblox) is not enough: testers play the
   PUBLISHED version, so publish again after every change you want them to get. Note the game link.
2. **DataStores for Studio**: DONE 2026-11-24 (Game Settings > Security > "Enable Studio Access to API Services" = On).
   Studio and the live game share the same saved data.
3. **Server size**: Creator Hub > Places > (the place) > Access > Maximum Visitor Count = **16**. Every party (1-4
   players) gets one of the 8 lots; if more than 8 parties are on one server, the 9th-16th get overflow lots further
   down the homes street (World.MAX_PLAYERS / LOT_LIMIT).
4. **Who can join**: Game Settings > Permissions: keep the game Private and add testers as friends/collaborators,
   or make it Public (it is unlisted until it has players). Friends can join you from your profile.
5. **Purchases are LIVE**: the VIP and Extra Character Slots Game Passes and the 4 Sunstone packs have real ids
   (`Config/Premium`), so testers can spend real Robux. No purchase has been tested yet. Either buy the cheapest pack
   yourself first (Sunstones arrive, the first-buy bonus doubles them, a rejoin keeps them), or set the ids to 0 for the
   test (purchases are then switched off).

## Before inviting people (owner, 10 minutes, alone)
- Join the live game (not Studio). Make a character, play ~5 minutes, claim the daily gift, do an errand.
- Leave, wait 10 seconds, rejoin: level, gold, gear, the errand and the daily claim should all still be there.
- Join from a second device or account if you have one: check you can see each other in the town.

## With a second account or a friend (before the wider test)
These have only been seen with companions, never with two real players:
- Party by code: both on one lot, fighting together, each sees the other on the HUD and the battle card.
- Guild: found one, the other joins at the Guild Board; guild chat; a 🎁 gift from Bag > Stash.
- A sparring duel between the two of you (Combat Arena).
- Open the game on a second server while still in the first: the first one should kick you, nothing lost.

## Checklist for testers (send them this)
Play for 20-30 minutes, then write down anything odd. The things to try:
- [ ] Make a character, pick a class, skip or finish the tutorial.
- [ ] Walk round town: Guild (north), Old Town (north-west), Wishing Grove (north-east), Pet Area (west),
      Market (east), Combat Arena (south-west), Player Homes (south-east), Dungeon in the east wall,
      Giant Bosses outside the north-east gate.
- [ ] Do an errand from the Notice Board (5 a day), fish at the pond, play with your pet, find a glowing relic.
- [ ] Party up: one player opens Party > make a code, the other joins with it. You should fight together.
- [ ] Duel each other in the sparring ring (Combat Arena).
- [ ] Join or make a guild at the Guild Board; try guild chat.
- [ ] Spend talent points after levelling; try the Settings screen (sound, HUD size).
- [ ] Claim the daily gift (the same 7-day streak for everyone: 10K gold on day 1 up to 40K and a skill pick on day 7).
- [ ] Look at the 🏅 Collection screen (bestiary + class mastery).
- [ ] If you can, play a while on a phone or tablet too.
- [ ] **Leave and rejoin**: is everything still there? (This is the most important one.)
- Report: what broke, what was confusing, what was fun, how long until you got bored. Easiest: the 📝 **Feedback**
  button on the HUD (pick Bug / Confusing / Idea / Fun, write a line, Send). It records where you were and your level.

## The playtest log (owner)
Everything testers send and everything that goes wrong is kept for you, from every server, in the DataStore
`IPQ_Playtest` (one list per day, UTC): open 📝 **Feedback > Read log** in Studio (needs API access on) or in the
live game (only the place's creator, or rank 254+ in the owning group, sees that tab).
- **Feedback**: topic, who (level, class, stage), where they stood (district + position, or "battle view"), the note.
- **Errors**: server script errors, handlers that threw (with a stack trace, "handler Wish" etc.) and players' client
  script errors. The same error is one line with a count (x50), so the worst ones stand out.
- **Sessions**: one line per visit: minutes played, level and stage at join -> leave. Short visits = where people quit.
Rows are written every 60 s and when a server closes; feedback is written at once. "Today" / "Last 3 days" toggles.

## What to watch in the server output (owner)
- `[DataService] Profile <id> cannot be saved as is: ...` means a save is failing: send me the line.
- `[DataService] ... failed (attempt n/3)` now and then is fine (Roblox retries); many in a row is not.
- `Lost session lock` means someone joined a second server while still in the first: they are kicked to protect data.

## Known limits for this test
- 8 lots always shown per server; parties 9-16 get overflow lots down the homes street (never seen in Studio).
- Studio cheats (the flask button) only exist in Studio.
- Balance is tuned for 2-4 heroes in a party (companions fill empty seats). Balance is checked in the headless sim up to
  level 100 (~150 hours); a playtest will only reach the first few zones.
- Never seen in Studio: the fallen-ally banner, the expedition-ready sign, dungeon wave banners, the all-relics title.
  The 📝 Feedback button and the error log will catch these.
