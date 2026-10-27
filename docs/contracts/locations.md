# Locations, NPCs, quests and flags (ADR 0009)

Levels are data. A location is a grid map like an encounter's (ADR 0007), so exploration and combat share one
geometry: a fight starts where the party stands, on the same squares. `world/exploration/` dresses the map in 3D;
`story/` runs quests and flags; `make validate` checks every reference.

## data/locations/<id>.json (schema: data/schemas/location.schema.json)

```json
{
  "id": "death_house_ground",
  "name": "Death House, Ground Floor",
  "region": "death_house",
  "summary": "...",
  "map": {"rows": ["#####", "#...#"], "theme": "manor", "light": "dim"},
  "areas": [{"id": "foyer", "name": "Foyer", "cells": [[1, 1], [6, 4]], "light": "dim"}],
  "spawns": {"default": [3, 9], "from_upstairs": [12, 2]},
  "exits": [{"id": "stairs_up", "cell": [12, 1], "to": "death_house_upper", "spawn": "from_downstairs", "label": "Stairs up"}],
  "doors": [{"id": "front_door", "cell": [3, 10], "locked": false, "lock_dc": 0, "key": "", "secret_dc": 0}],
  "props": [{"id": "portrait_durst", "cell": [5, 2], "kind": "examine", "label": "Family portrait", "model": "painting"}],
  "containers": [{"id": "wardrobe", "cell": [8, 3], "label": "Wardrobe", "items": [{"id": "dagger", "qty": 1}], "gold": 0, "lock_dc": 0}],
  "lights": [{"cell": [4, 4], "kind": "candle", "bright_ft": 5, "dim_ft": 10}],
  "traps": [{"id": "pit", "cells": [[9, 6]], "detect_dc": 12, "disarm_dc": 12, "save": {"ability": "dex", "dc": 12}, "damage": "2d6", "damage_type": "bludgeoning", "flag": "death_house_pit_found"}],
  "npcs": [{"npc": "rose", "cell": [6, 6], "dialogue": "death_house/rose_thorn:start", "when": "not flag.rose_thorn_gone"}],
  "encounters": [{"id": "nursery_specter", "trigger": "enter_area:nursery", "when": "not flag.nursery_cleared",
                  "monsters": [{"monster": "specter", "cell": [10, 3], "name": "Nursemaid"}], "surprise": "", "flag": "nursery_cleared"}],
  "narration": {"enter": "enter:death_house_ground"},
  "rest": "risky",
  "rest_text": "The house won't let you sleep."
}
```

- **Map rows** use the combat legend: `.` floor, `#` wall, `=` low obstacle (furniture, Half Cover), `~` Difficult
  Terrain, `1`-`4` raised floor 5 ft a step (a walk, a ledge, a stair), `_` a low dais 2 ft (a podium, a stage, an
  altar's step, a porch, a jetty: owner 2026-10-12, no climb and no high ground), `w` deep water (not walkable, doesn't block sight), space = void.
  Each 5 ft rise between two walkable built floors is drawn with a short flight of small steps in the lower square
  against the face (owner: Castle Ravenloft 2026-10-15, every place 2026-10-17; Stairs.flight, ArenaBoard._flights,
  and CastleBuilder for the castle gates' wall walk): drawing only, the rules still have a 5 ft step up. A 10 ft face
  is a climb and has none; nor does a prop stood on (`stand_ft`) or natural ground, which slopes. Doors are cells listed in `doors` (drawn as a closed door; a closed
  door blocks movement and sight until opened).
- **Doors:** `locked` or a `lock_dc` makes a lock, opened by its `key`, by picking (thieves' tools, `lock_dc`), forcing
  (Athletics, `lock_dc` + 2) or Knock; `secret_dc` hides the door until it's found. `when` is a condition the door
  needs before it opens at all (a portcullis a story flag raises; until then it won't budge), and `unlocked_when` one
  that takes its lock off (the church undercroft's bar once Father Donavich lifts it; until then it can be picked or
  forced). `flag` is set when the door opens. `locked_text` is what the Narrator says, and the menu's reason, when the
  door won't open because its `when` doesn't hold (default "It won't budge"). `leaf: "none"` draws no leaf and no
  frame: a ward whose look is a prop on its square (the guardians' curtain of light); it still blocks and opens as a door.
- **Spawns:** `default` is where a plain arrival lands, and where an exit that names no `spawn` and a dialogue's
  `move <location>` go; an exit's `spawn` and `move <location>:<spawn>` (docs/contracts/dialogue.md) name another, on
  this map or a different one (`make validate` checks both). A load puts the party back on its saved squares; any that
  a later edit to the map has closed (a wall, a prop, water, outside a smaller map) are replaced by the nearest open
  square, or by squares beside the default spawn when none is within 8 squares (`LocationParty.open_squares`), and a
  round-start save whose fight no longer fits the map begins that fight again from its own squares. A door's square
  counts as open (a hero in a shut doorway holds it open), except a secret door nobody has found.
- **Natural ground:** `map.elevation` (optional), rows beside `rows`, lays hills and hollows under the squares: one
  character a square, `0`-`9` then `a`-`z` for 0 to 175 ft in 5 ft steps, `.` or a space for a square left as built.
  Neighbouring natural squares 5 ft apart are a gentle slope, 10 ft a steep one, 15 ft or more a cliff (climbed or
  jumped down; docs/rules/deviations.md). The board draws them as one sloped ground with rock under cliffs; empty
  squares given a height are the hillside the land draws round the walked ones. Yester Hill and Krezk's road and abbey
  track are the first maps that use it.
- **Road battle grounds:** `foe_spots` (`[[x, y], ...]`) makes a map somewhere a random road fight from another table
  can play out (a table's or a road's `grounds`, docs/contracts/campaign.md): open squares three or more from the
  `default` spawn, off the ways out, in cover or up high (the treeline, behind a cairn, on a ledge), where the fight's
  foes start, each on the free one nearest where its table put it round the party (story/road_grounds.gd). Give one
  a dozen or so, on both sides of the road; `make validate` wants at least eight, each walkable from the spawn. A
  ground needs a way out to `travel`; it is outdoors, with its mood and vista place like any outdoor map.
- **Light:** `bright`, `dim` or `dark` for the map and each area; `lights` add bright and dim radii, and an optional
  `color` (a palette colour: Baba Lysaga's green hearth is "bile"; a fire's own flame takes it too). A prop's `flame`
  colours the fire burning in its piece (a hearth), as SetDressing.FLAME_TINTS has it. A light with `visual: true` is only
  painted: it lights the picture but gives a fight no light zone (the Amber Temple's great hall: its fights were tuned
  on the old lamps). (Vision rules —
  what Darkvision and darkness do to checks and attacks — belong to the spell and ability audit; the world only
  reports each square's light level.)
- **Encounter triggers:** `enter_area:<area>`, `open:<door_or_container>`, `examine:<prop>`, `flag:<flag>` (when a
  flag is set, e.g. by dialogue), `dialogue` (only started by a `combat` line). On victory the game sets `flag` and
  moves `quest: {id, stage}` along. A boss's monster entry (narrative/combat/bosses.json, or a foe with legendary actions) may carry `hp` to tune that stat block for this fight; every other foe fights at its stat block's Hit Points (owner, 2026-10-24: the Monster Manual's, no custom HP).
  `waiting: true` (an `enter_area` fight only) puts its foes in plain view before the fight: they show once the party
  can see them, can notice the party, and can be attacked first (docs/rules/stealth.md, F7). A waiting monster's
  `facing` (north, south, east, west or between) points its sight cone; unset, it faces the middle of its group. A foe
  with `unseen: true` isn't in plain view (a trap's, an ambush's): no figure, and it notices no one, until the fight puts
  it on its square. `make validate` asks every variant of a waiting fight to wait, to have a foe in view, and each foe in
  view to say its `facing` (the nine fights that waited before facings, tools/data/validate_data.py LEGACY_WAITING,
  keep facing the middle of their group).
  A monster's `lying` lays it down before its fight (as an NPC entry's, below) and it gets up as the fight opens: the
  dead sitting up on their pallets, Vasilka coming down off her bier. Its `art` dresses it in another sprite than its
  stat block's (Vasilka fights on a flesh golem's block in her own look); a round-start save keeps it. Its `steps_down:
  {npc}` says the foe is that person of the place (the Amber Sentinel on its dais): however the fight starts, their figure
  leaves the board and the foe's takes their place and strides to its start square (StepDown, addons/dnd_core/world/combat/step_down.gd;
  motion off cuts to it), its stat block's size untouched.
  Its `boss: false` keeps a foe on a boss's stat block out of the game's bosses (Difficulty.boss_entry): no boss bar, no
  boss damage or to-hit step (the brides on the vampire's block).
  Its `states` (ids from the stat block's own `states`) join its traits for this fight: Sarkhaza chained or
  grave-salted, each a trait on her sheet (LocationFights.with_states). A state may cut its Multiattack (`multiattack`)
  and its legendary uses (`legendary_uses`), or seat it in a coven (`coven`: the night hag's shared spells, the three hags'
  last stand).
  `surprise`: `party`, `enemies` or
  empty; `when` is a condition (docs/contracts/dialogue.md). A region may keep a truce (StoryConditions.TRUCES): while
  it holds, its `enter_area` fights wait as if their `when` were false, and are back as they were once it ends (Castle
  Ravenloft while Strahd's dinner invitation is open and the party hasn't left the castle since, docs/regions/
  castle_ravenloft_gates.md §8): leaving the region ends a truce for good (its `over` flag, StoryConditions.note_departure). Foes start spread out (owner, 2026-10-14): of three or
  more, no 20 ft burst catches them all, nor more than three quarters of eight or more, and none starts on a wall, low
  cover or another foe (tests/unit/test_fight_spread.gd, which lists the rooms too small for it). Road fights are held
  to the same on every ground they can play out on.
- **Rest:** `safe`, `risky` (a Long Rest is interrupted on a 1 in 6, and makes camp on the map: docs/story/camp.md)
  or `no` (no Long Rest: its card says `rest_text`); default risky. A Short Rest is taken in any of them, `no`
  included, unless a fight on the map was begun and not won or foes are in plain view of the party
  (story/rest_rules.gd).
- **Crime (F8, docs/rules/stealth.md):** a container's `owner` (an npc id) makes taking from it stealing when somebody
  sees; an area's `private` (an npc id) makes it a private room, with `open` (a condition) for when it may be entered;
  the location's `watch` names the guard who answers a crime here ("" for nobody; unset, the region's watch).
- **Antimagic areas (Dungeon Expansion Plan V1):** an area's `antimagic` (true, or the notice a caster is shown) makes it a place where no
  spell is cast: from the character sheet, scrolls and the `cast` statement when the party's leader stands in it
  (`Wards.antimagic_notice`, `FieldCasting.cast`, `cast_utility`, `revive`, `cast_from_scroll`), and in a fight there, where its open
  squares are an Antimagic Field zone for the whole fight (`LocationFights._ward_the_fight`: spells and magic items go quiet on
  them, as in combat/high_magic.gd). Van Richten's Tower's ring, five feet out from its walls, is the first.
- **NPCs:** `{npc, cell, dialogue, when, hours, facing, approach, asleep, lying, on, path, pause, steps_aside}`. The first entry per NPC whose
  `when` holds stands there; the game re-checks after every conversation and fight. `approach: n` makes the NPC speak
  first, once, when the leader comes within n squares and can see them. `asleep: true` lays the NPC down asleep
  (Unconscious, so Incapacitated and Prone, as the 2024 rules have a sleeper); the hover hint, Look and the Alt plates
  say so. `lying` lays the figure down with no condition (owner 2026-10-13, Vasilka "lies under a sheet, very still"):
  `true`, or `{on, head, sheet, pose, lift, picture}` (addons/dnd_core/world/exploration/lying_figures.gd). A person lies on their back on
  their own square, on top of the furniture standing there (a table, a bier, a pallet), or on the prop `on` names
  beside them; head along the furniture, or toward `head`; `sheet` lays linen over them to the `chest` or over the
  `face`. A beast or a dragon lies low on its belly (`pose`: back or belly). `picture` names a drawing of the figure
  lying down (art/sprites/lying/<id>.png) that stands in for it, turned to the camera, until it gets up (Sarkhaza
  across her gold); until the drawing exists the figure lies as it would without one. The hover names them and the menu offers
  Approach. `path: [[x, y], [x, y, seconds], ...]` walks the NPC from its cell through each waypoint and back, standing
  `pause` seconds (default 3, or a waypoint's own) at each (NpcRoutes): it holds while anyone talks or fights, while
  the leader stands beside it and while its next square is taken, and under turn-based exploring walks only as a
  round ends; a sleeper, or a figure lying there, never walks. A waypoint may also be `{"at": [x, y], "wait": s, "face": dir, "work": "swing" or "gesture"}`: a stop
  where the person turns to their work and swings at it (an axe, a spade: the figure's attack) or gestures over it
  (its spell gesture) every few seconds; an entry's own `work` does the same at its cell, standing or home from its
  path (lane 28). Waypoints must be open floor reachable without opening a door. `hours: [from,
  to]` keeps the NPC here only between those hours (`[19, 6]` passes midnight), so townsfolk go to work, the tavern
  and home: a person may have an entry in each place. The people re-check who stands where whenever the hour turns
  while the party is in the location (LocationClock). `on: <prop id>` stands the figure on a prop of the place (its piece's
  `seat`, the middle of its top: the Amber Sentinel on its dais, LocationNpcs._seat); the person still counts as on their
  own `cell`. `steps_aside: true` keeps the figure out of every fight on the
  map: it leaves the board as a fight begins, so its square doesn't block, and comes back with the rebuild after
  (LocationNpcs.clear_for_fight; Castle Ravenloft's household, owner 2026-10-15).
- **Prop kinds:** `examine` (Narrator line `examine:<id>`), `book` (`codex` entry), `search` (a hidden thing found
  with `search_dc`), `lever` (sets `flag`), `decor` (no interaction). Optional `when`, `dialogue`, `item`, `flag`, `say`
  (a Narrator trigger tried before `examine:<id>`: a camp's fire indoors says `examine:camp_fire:indoors`), and
  `facing` (north, south, east, west or between: which way the piece's front looks, instead of away from the wall
  beside it or south) and `span` ([across, down] squares, its own cell the north-west one: a wagon stands over the middle
  of its two-by-two block of low cover). A prop's or container's `scale` (0.25 to 8; owner 2026-10-17) draws its piece
  that many times its modelled size: the dragon's desk and chair are three times a desk and a chair, his skull in the
  trophy room 2.2, his bones in the mausoleum 2.6. A 3D piece keeps its square at its middle and spills over its
  neighbours, whose squares stay unfurnished (SetDressing.scaled_squares); the rules' grid never changes, so give it
  room by where you put it (nothing else of the prop's own should stand in the squares it covers). A prop's `tint` (a palette
  colour's name or `"#rrggbb"`) multiplies the colours of its 3D piece: the dead colossus at the Amber Temple's doors in dark
  amber (ModelPiece.tint, applied before it can fade in the party's way). A `model` of
  `silver_heap` is a heap of coins built from the coins (CoinHeap), `scale` times the gold heap's size.
  `gold_hoard` is the same heap in gold coin (Sarkhaza's cavern).
  A prop's `stand_ft` (5 to 60, in 5 ft steps) makes it something stood on: its squares (its cell, or all its `span`)
  are that many feet above the ground underneath (LocationView.grid_for, CombatGrid.raise). 5 ft is a step up (a
  podium); 10 ft or more is a ledge: climbed (1 extra foot per foot), jumped down from (5 ft and the fall), high ground
  for ranged attacks, and it hides what is behind it like a wall that high. Put it on `.` squares, not `=`. Its model
  is the raised thing (a platform, a gallows, a great tree with a perch) and is drawn from the ground up, so its top
  should sit about `stand_ft` high; the board draws only the ground under it. It is always there (no `when`).
  Climbable trees built for it (stood on at exactly 10 ft): `hunters_tree_stand`, a pine with a plank platform over
  its one square; `broad_oak_bough`, an oak whose level bough runs over two squares (give it `span: [2, 1]`, or
  `[1, 2]` with a `facing` that turns it) with its trunk on the square west of them (before turning).
  A search prop's `skill` is the check that finds it: `perception` (default) or `investigation` (a compartment you
  work out; Search rolls it as well when one is within 15 ft). A search prop with an `item` is a hidden find
  (docs/story/found_magic_items.md): each character gets one look, and one who misses it can't find it later; the
  Narrator's `check:<skill>:<id>:failure` line, if any, plays on a miss. Detect Magic senses one holding a magic
  item within 30 ft without saying where.
- **Wall styles:** `wall_styles` (optional) `[{cells: [[x0, y0], [x1, y1]], paint, trim, wheels}]` paints the walls
  inside that block in a palette colour (`paint`, on the painted-wood planks) with two trim bands in `trim` round its
  outside faces, and `wheels: true` puts two wheels on each long side: a walled block that is a vehicle, not a building
  (Rictavio's carnival wagon in the Blue Water Inn's yard). The rules grid is unchanged (docs/art/interiors.md).

## data/npcs/<id>.json (schema: npc.schema.json)

`id`, `name`, `title`, `summary`, `portrait` (art id), `sprite` (art id), `attitude` (starting: hostile,
indifferent, friendly), `voice` (docs/voice/<id>.md), `monster` (stat block id if they can fight), `guest` (true if
they can join as a guest ally), `tags`, `pockets` (F8: items a picked pocket holds beyond the coins their tags give,
or false for a pocket nobody can pick).

## data/quests/<id>.json (schema: quest.schema.json)

`id`, `name`, `summary`, `giver`, `kind`, `stages: [{id, journal, objectives: [text], hint, ends: false|"success"|"failure"}]`.
`kind: "main"` puts a quest under the journal's Main tab (the story's spine); every other quest is under Other.
The Other tab files its quests under a heading for each `region` (Ashwin, 2026-10-18; story/quest_regions.gd): the
region ids of data/locations, in the order the campaign reaches them, then `companions` (the party members' own quests)
last; open quests come first under each heading, the finished ones after. A quest's `region` must be in
`QuestRegions.ORDER` (tests/unit/test_quest_regions.gd checks), so a new region adds its name and place there.
The journal shows each reached stage's text in order. `hint` says what to do next at that stage, behind the journal's
Hint button: the place and the person or action, never the twist (`{tarokka.<slot>.hint}` fills in the party's
reading). Every stage that doesn't end its quest has one; `make validate` fails without it.

## data/flags/<region>.json (the flag registry, one file per region so writers don't collide)

```json
{"flags": [{"id": "rose_thorn_met", "type": "bool", "summary": "The party spoke with the ghost children."}]}
```

Types: `bool`, `int`, `string`. Every flag a dialogue file, location or quest reads or sets is registered in one of
these files. `make validate` fails if a flag is
read but never set, set but never read, or used but missing. A flag the game sets from code (the easter-egg packages'
`eggs_engine.json`, set when a story fight ends) carries `"set_by": "engine"`: dialogue and locations may read it without
setting it, and `make validate` refuses data that sets it.

`make validate` also walks the whole story from a new game (tools/data/story_reach.py): exits and the travel map,
every conversation from its NPC, prop, road event, Strahd visit, schedule, camp talk, banter, captive, watch and ending,
taking anything that could be true as true. It fails on a quest stage, conversation node, prop with an item or a
conversation, or container that no playthrough reaches; on a flag a condition reads that nothing reachable sets; and on
quest stages only reached on a map that a random road encounter happens to open (give such a place an exit or a
travel place with a `when`).
