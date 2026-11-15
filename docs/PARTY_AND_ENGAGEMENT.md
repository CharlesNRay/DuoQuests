# Party progression and the login loop

Design notes, not built yet. Decisions from the designer are marked **Decided**.

## Party progression rules

- **Decided:** progress is shared. If one player is online, they and their
  partner's ghost fight the party's stage. When the party clears a new stage,
  the offline partner also progresses, and earns the rewards for that new stage
  (claimable when they log in).
- **Decided:** if BOTH players are offline, the party does not advance. It stays
  on whatever stage it can clear.
- **Decided:** both offline still produces AFK gains, as farming income on the
  stage the pair can already clear, at REDUCED rate. It never moves the frontier.
- Ghost strength is the partner's last saved snapshot (class, level, loadout,
  slot levels), refreshed when they log out and when they change their build.
- The stage the party is on lives on the party record. Each player keeps their
  own frontier (`Season.HighestStage`) and gets credited when the party passes
  stages they hadn't reached.

## Finding a party (decided direction)

Players need a "Find a party" screen with three ways to get a partner:

1. **Invite Roblox friends.** Friends can be invited straight from the friends
   list (Roblox's social APIs only expose a player's friends who are in the
   same server or playing, so the invite flow needs a design pass).
2. **Invite others** from the party finder (players who are looking for a
   partner) or by a shared join code.
3. **Join at random** for players who don't care who they party with: a
   matchmaking queue that pairs two players who opted in.

Design notes for when this is built:
- Matching should prefer similar stage and level, widening over time, since the
  party starts at the weaker member's stage.
- Players need a way to leave a party and to block or report a partner, and
  the party record has to be cleaned up when it empties.
- Invites and the random queue need a shared, cross-server list (MemoryStore),
  and the pairing has to be race-safe so two servers cannot give the same
  player two partners.
- Roblox safety expectations apply: no free-text chat between matched
  strangers beyond what Roblox's own chat provides.

## Joining a party (decided)

A party starts at the WEAKER member's frontier. A stronger player does not lift
it: they carry the weaker partner up, stage by stage, until the pair can't
climb any further. The stronger player is paid the reduced replay rate on stages
they already cleared, and their own frontier only moves again once the party
passes it. The weaker player is paid full frontier rewards for each stage.

## Stage timer (decided)

Every stage has a time limit (60 s regular, 90 s boss, in `Config/Stages`).
Running out of time is a loss, so a fight can never be stalled out, and a
timed-out fight steps the party back like any other loss. The same limit applies
to the AFK estimate.

## Offline rules (decided, values are starting points)

- **AFK window:** 12 hours at the full offline rate (people sleep or work that
  long). Adjust with data.
- **Reduced rate:** offline farming pays a fraction of live play (start at 50%).
- **No hard cap on XP.** Past the 12 hour window, offline gains keep accruing at
  lower and lower rates (tiers), so a partner who is away does not fall far
  behind the one who keeps playing. Starting tiers (proposal, applies to AFK
  farming): 0-12 h 50%, 12-24 h 30%, 24-72 h 15%, after 72 h 5%.
- **Ghost is not boosted** by offline time. It is just the last snapshot.
- **Partner can adjust the ghost's loadout:** the partner may swap skills and
  their order for the offline player's ghost (only skills the owner already
  owns) so a missing skill never blocks a boss because players could not log in
  at the same time. They cannot spend resources, unlock or level anything.
- **Inventories are capped,** and the cap can be raised by spending in-game
  money. Overflow is salvaged into currency instead of being lost.

## Offline claims

When a player logs in they see a claim screen made of:

1. **Partner progress:** frontier-clear rewards for stages the party cleared
   while they were away (once per stage, tracked by a per-player ledger).
2. **AFK gains:** farming income since logout, capped (hours and efficiency
   are open design values), only while the party could clear that stage.
3. Daily login, event login and event rewards waiting to be claimed.

## Built so far (pure logic, headless-tested)

`Shared/Party`, `Shared/Offline`, `Config/Offline`, and ghost support in
`StageRunner`. A party record holds the shared stage, frontier, each member's
ghost snapshot and queued AFK gains.

- Ghost loadouts are separate from the player's own, editable by either member
  (owned skills only, full loadout, logged, one-tap revert by the owner).
- AFK is estimated from the stage the pair can actually clear: it simulates the
  saved snapshots, finds the highest stage they win (stepping down from the
  party's stage), counts fights from the real fight length, and pays each member
  at that stage's rates times the offline tier.
- Both members are credited for the same both-offline gap, claimable at their
  own login.
- Partner progress is paid by catching the member's frontier up to the party's,
  one stage at a time, so it can never be paid twice.

## PartyService (built)

`Services/PartyCore` (tested without Roblox) and `Services/PartyService`
(Roblox glue, wired into `Main`).

- Every player always has a party: a solo (open) one is made on first login.
- **Join codes:** a member of an open party makes a 6-character code (15 minute
  life, no confusing characters). Entering it joins that party; the joiner's own
  solo party is deleted. A pair must leave before joining another.
- **Leave:** the leaver is paid first, the remaining member keeps the party,
  the last member leaving deletes it, and the leaver gets a fresh solo party.
- **Hosting:** one server runs a party at a time (a host lock with a 60 s
  timeout). Another server sends its player to the host with TeleportService
  (written, NOT yet tested outside Studio).
- **No overwrites between servers:** membership changes are atomic and bump a
  revision; a host that finds the revision changed adopts the stored record
  instead of saving over it.
- **Pacing:** a fight resolves instantly, then the party waits out its
  duration plus the pause, so real time matches the tuned economy.
- Saved at most every 30 s per party and when a player leaves.

Still to build: friend invites (SocialService invite prompt carrying the party
code), random matchmaking, remotes for the client UI, an in-game party screen.

## Things to do on login (wish list, to prioritise)

Free-to-build, profile-only (no backend):
- Daily login rewards (streak, no heavy penalty for missing a day)
- Claim AFK gains and partner progress
- Daily and weekly quests (clear N stages, win N boss fights, spend gold...)
- Spend resources: level slots, unlock skills
- Equipment: gear dropped while AFK waits in an inventory to compare and swap
- Milestone rewards (first clears, season milestones that feed next season)

Needs shared server state:
- Server goals: the whole server (or all players) contributes toward a target,
  everyone claims a reward when it is reached
- Event bosses: players deal damage over time, personal contribution ranks
  and tiered rewards
- Event login rewards and limited-time events
- Leaderboards (season, event)

## Constraints to keep in mind

- Server goals and event bosses need global counters and ranked data
  (MemoryStore for live counters, ordered DataStores for rankings), with
  batched writes so we stay inside Roblox's DataStore request limits.
- Rewards stay deterministic or free-random. Anything random bought with Robux
  needs Roblox's odds disclosure.
- Missing a day should cost overflow, never progress, so a consistent
  few-minutes-a-day player is rewarded and a missed day is not punished.
- Balance has to be refit against a check-in based player (several short
  sessions plus capped offline accrual) and against partner contribution.
