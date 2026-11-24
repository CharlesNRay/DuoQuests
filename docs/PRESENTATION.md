# Presentation: how the game looks and feels

Idle Party Quest should look like a living idle RPG (Ulala: Idle Adventure, Go Go
Muffin): the party travels through scenery, fights monsters, plays skill
animations, and moves on to new regions after bosses. The panels built so far
(HUD, Skills, Passives, Ultimate, Party) sit on top of this view.

## Decisions (confirmed)
- **Platforms:** phone, tablet AND PC. Everything is responsive: scaled UI,
  touch targets of at least 44px, mouse/keyboard and gamepad friendly, and the
  battle camera adapts to the screen shape.
- **Camera:** fixed side view. Heroes on the left, enemies on the right.
- **Characters:** the players' real Roblox avatars on rigs (partner too, from
  their saved appearance, also when they are a ghost), with their pets beside
  them. Class gear and looks can be layered on later.
- **World map:** the party can replay ANY cleared stage to farm, or push the
  frontier. A loss still steps the party back one stage.
- **Assets:** only free assets from Roblox Studio. Placeholder shapes where
  nothing fits.

## A shared world, like Roblox (confirmed)
The game is not a locked camera. Players walk around a shared hub and can see
what everyone else is doing and how they compare, which is a core Roblox appeal.
- **Hub:** a normal walkable world. Players spawn here with their avatar and move
  with the usual controls (touch, mouse/keyboard, gamepad).
- **Your arena:** your party fights in its own arena in the world, near you. You can
  walk off at any time; a "Battle view" button snaps the camera back to the fixed
  side view (the current scene), and another leaves it.
- **Other parties:** every party on the same server fights live in its own arena you
  can walk up to and watch. Near an arena a card shows its zone and stage, both
  members' class, level and pets. Clicking a player inspects them.
- **Same server only:** you only see parties on your server. Leaderboards cover
  everyone; the hub shows the server's players, and a ghost (offline) partner
  appears as a ghost figure in the arena.
- **Zones:** an arena's scenery, monsters and lighting follow its party's zone, so
  walking past arenas shows different regions side by side.

## How it works
- Combat stays server-authoritative. The simulation decides every hit; the
  client only replays the fight's event log as animation, damage numbers and
  effects. Visuals can never change an outcome.
- A zone is a diorama in the Workspace: scenery, lighting, music and a monster
  roster. Every 10th stage is a boss; beating it opens the next region.
- Between fights the party walks forward through the zone so it feels like
  travel, then the next wave appears.
- The world map shows regions and stage nodes, the party's position, and what
  is locked.

## Build order
0. (done) One arena/side-view scene with avatars, monsters, animations.
1. One zone with real avatars, monsters, attack/hit/death animations and damage
   numbers. First feel test.
2. Skill and ultimate effects, pets in the fight, boss presentation.
3. Zone transitions with changing scenery, plus the world map and stage pick.
4. Art polish with more free assets.

## Revised build order with the shared world
A. Make the battle scene an arena placed in the world (not a far-away diorama).
B. Hub: spawn area, normal movement, camera toggle between walking and Battle view.
C. Server broadcasts every party's fights to all clients on the server; clients
   render each party's arena and replay its fight. Only nearby arenas are animated.
D. Info cards near arenas, and player inspect (class, level, pets, zone, stage).
E. Leaderboards in the hub; ghost partner figure; world map and stage select.

## Needed from the code
- Confirm the simulation's event log has enough detail (who acted, skill used,
  target, amount, time) to replay as animation.
- Party stage selection (replay a cleared stage) in Party/PartyService, with
  tests.
- Zone/region config: stages per zone, names, boss stage, monster roster.
