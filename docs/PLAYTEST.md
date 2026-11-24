# Playtest with real people (setup + checklist)

Written 2026-11-23 for the first live tests. Progress saving is built in (DataService): a player's profile is saved
every 2 minutes, when they leave, and when a server shuts down. Each profile is locked to one server at a time, so it
cannot be edited from two places at once. In Studio without API access it falls back to memory (every playtest starts
fresh), which is why saving has not been seen working yet. The real save code is tested headless against a fake DataStore
(`DataServiceTests`: leave and rejoin on another server, opening the game twice, a crashed server, a party teleport,
Roblox errors, old saves upgraded), so the live check below is a confirmation, not a first try.

## One-time setup (owner, in Roblox Studio)
1. **Publish the place**: File > Publish to Roblox (or "Publish to Roblox As..." the first time). Note the game link.
2. **Turn on DataStores for Studio** (so Studio playtests save too): Home > Game Settings > Security >
   "Enable Studio Access to API Services" = On. Studio and the live game then share the same saved data:
   a Studio playtest changes your real profile.
3. **Server size**: Game Settings > Places > (the place) > Max Players = **4** for now. The town has 4 battle lots
   ("player homes"); each party takes one, and a solo player is a party of one. A 5th party would get a lot outside
   the yard (it still works, it just looks odd). Players who party up share a lot, so 4 per server is safe.
4. **Who can join**: Game Settings > Permissions: keep the game Private and add testers as friends/collaborators,
   or make it Public (it is unlisted until it has players). Friends can join you from your profile.
5. Purchases are switched off (Game Pass and product ids are 0), so nobody can spend Robux by mistake.

## Before inviting people (owner, 10 minutes, alone)
- Join the live game (not Studio). Make a character, play ~5 minutes, claim the daily gift, do an errand.
- Leave, wait 10 seconds, rejoin: level, gold, gear, the errand and the daily claim should all still be there.
- Join from a second device or account if you have one: check you can see each other in the town.

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
- [ ] Spend talent points after levelling; try the Settings (sound) screen.
- [ ] **Leave and rejoin**: is everything still there? (This is the most important one.)
- Report: what broke, what was confusing, what was fun, how long until you got bored. Easiest: the 📝 **Feedback**
  button on the HUD (pick Bug / Confusing / Idea / Fun, write a line, Send). It records where you were and your level.

## The playtest log (owner)
Everything testers send and everything that goes wrong is kept for you, from every server, in the DataStore
`DuoQuestPlaytest` (one list per day, UTC): open 📝 **Feedback > Read log** in Studio (needs API access on) or in the
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
- 4 lots per server (see Server size). More players per server needs a second lot block.
- Studio cheats (the flask button) only exist in Studio.
- Balance is tuned for 2-4 heroes in a party (companions fill empty seats).
