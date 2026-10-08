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
  Terrain, `1`-`4` raised floor, `w` deep water (not walkable, doesn't block sight), space = void. Doors are cells listed in `doors` (drawn as a closed door; a closed
  door blocks movement and sight until opened).
- **Doors:** `locked` or a `lock_dc` makes a lock, opened by its `key`, by picking (thieves' tools, `lock_dc`), forcing
  (Athletics, `lock_dc` + 2) or Knock; `secret_dc` hides the door until it's found. `when` is a condition the door
  needs before it opens at all (a portcullis a story flag raises; until then it won't budge), and `unlocked_when` one
  that takes its lock off (the church undercroft's bar once Father Donavich lifts it; until then it can be picked or
  forced). `flag` is set when the door opens.
- **Natural ground:** `map.elevation` (optional), rows beside `rows`, lays hills and hollows under the squares: one
  character a square, `0`-`9` then `a`-`z` for 0 to 175 ft in 5 ft steps, `.` or a space for a square left as built.
  Neighbouring natural squares 5 ft apart are a gentle slope, 10 ft a steep one, 15 ft or more a cliff (climbed or
  jumped down; docs/rules/deviations.md). The board draws them as one sloped ground with rock under cliffs; empty
  squares given a height are the hillside the land draws round the walked ones. Yester Hill and Krezk's road and abbey
  track are the first maps that use it.
- **Light:** `bright`, `dim` or `dark` for the map and each area; `lights` add bright and dim radii, and an optional
  `color` (a palette colour: Baba Lysaga's green hearth is "bile"; a fire's own flame takes it too). A prop's `flame`
  colours the fire burning in its piece (a hearth), as SetDressing.FLAME_TINTS has it. (Vision rules —
  what Darkvision and darkness do to checks and attacks — belong to the spell and ability audit; the world only
  reports each square's light level.)
- **Encounter triggers:** `enter_area:<area>`, `open:<door_or_container>`, `examine:<prop>`, `flag:<flag>` (when a
  flag is set, e.g. by dialogue), `dialogue` (only started by a `combat` line). On victory the game sets `flag` and
  moves `quest: {id, stage}` along. A monster entry may carry `hp` to tune that stat block for this fight.
  `waiting: true` (an `enter_area` fight only) puts its foes in plain view before the fight: they show once the party
  can see them, can notice the party, and can be attacked first (docs/rules/stealth.md, F7). A waiting monster's
  `facing` (north, south, east, west or between) points its sight cone; unset, it faces the middle of its group.
  `surprise`: `party`, `enemies` or
  empty; `when` is a condition (docs/contracts/dialogue.md).
- **Rest:** `safe`, `risky` (a Long Rest is interrupted on a 1 in 6) or `no` (with `rest_text`); default risky.
- **Crime (F8, docs/rules/stealth.md):** a container's `owner` (an npc id) makes taking from it stealing when somebody
  sees; an area's `private` (an npc id) makes it a private room, with `open` (a condition) for when it may be entered;
  the location's `watch` names the guard who answers a crime here ("" for nobody; unset, the region's watch).
- **NPCs:** `{npc, cell, dialogue, when, hours, facing, approach, asleep, path, pause}`. The first entry per NPC whose
  `when` holds stands there; the game re-checks after every conversation and fight. `approach: n` makes the NPC speak
  first, once, when the leader comes within n squares and can see them. `asleep: true` lays the NPC down asleep
  (Unconscious, so Incapacitated and Prone, as the 2024 rules have a sleeper); the hover hint, Look and the Alt plates
  say so. `path: [[x, y], [x, y, seconds], ...]` walks the NPC from its cell through each waypoint and back, standing
  `pause` seconds (default 3, or a waypoint's own) at each (NpcRoutes): it holds while anyone talks or fights, while
  the leader stands beside it and while its next square is taken, and under turn-based exploring walks only as a
  round ends; a sleeper never walks. A waypoint may also be `{"at": [x, y], "wait": s, "face": dir, "work": "swing" or "gesture"}`: a stop
  where the person turns to their work and swings at it (an axe, a spade: the figure's attack) or gestures over it
  (its spell gesture) every few seconds; an entry's own `work` does the same at its cell, standing or home from its
  path (lane 28). Waypoints must be open floor reachable without opening a door. `hours: [from,
  to]` keeps the NPC here only between those hours (`[19, 6]` passes midnight), so townsfolk go to work, the tavern
  and home: a person may have an entry in each place. The people re-check who stands where whenever the hour turns
  while the party is in the location (LocationClock).
- **Prop kinds:** `examine` (Narrator line `examine:<id>`), `book` (`codex` entry), `search` (a hidden thing found
  with `search_dc`), `lever` (sets `flag`), `decor` (no interaction). Optional `when`, `dialogue`, `item`, `flag`, and
  `facing` (north, south, east, west or between: which way the piece's front looks, instead of away from the wall
  beside it or south) and `span` ([across, down] squares, its own cell the north-west one: a wagon stands over the middle
  of its two-by-two block of low cover).
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

`id`, `name`, `summary`, `giver`, `stages: [{id, journal, objectives: [text], ends: false|"success"|"failure"}]`.
The journal shows each reached stage's text in order.

## data/flags/<region>.json (the flag registry, one file per region so writers don't collide)

```json
{"flags": [{"id": "rose_thorn_met", "type": "bool", "summary": "The party spoke with the ghost children."}]}
```

Types: `bool`, `int`, `string`. Every flag a dialogue file, location or quest reads or sets is registered in one of
these files. `make validate` fails if a flag is
read but never set, set but never read, or used but missing.

`make validate` also walks the whole story from a new game (tools/data/story_reach.py): exits and the travel map,
every conversation from its NPC, prop, road event, Strahd visit, schedule, camp talk, banter, captive, watch and ending,
taking anything that could be true as true. It fails on a quest stage, conversation node, prop with an item or a
conversation, or container that no playthrough reaches; on a flag a condition reads that nothing reachable sets; and on
quest stages only reached on a map that a random road encounter happens to open (give such a place an exit or a
travel place with a `when`).
