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
- **Light:** `bright`, `dim` or `dark` for the map and each area; `lights` add bright and dim radii. (Vision rules —
  what Darkvision and darkness do to checks and attacks — belong to the spell and ability audit; the world only
  reports each square's light level.)
- **Encounter triggers:** `enter_area:<area>`, `open:<door_or_container>`, `examine:<prop>`, `flag:<flag>` (when a
  flag is set, e.g. by dialogue), `dialogue` (only started by a `combat` line). On victory the game sets `flag` and
  moves `quest: {id, stage}` along. A monster entry may carry `hp` to tune that stat block for this fight.
  `waiting: true` (an `enter_area` fight only) puts its foes in plain view before the fight: they show once the party
  can see them, can notice the party, and can be attacked first (docs/rules/stealth.md, F7).
  `surprise`: `party`, `enemies` or
  empty; `when` is a condition (docs/contracts/dialogue.md).
- **Rest:** `safe`, `risky` (a Long Rest is interrupted on a 1 in 6) or `no` (with `rest_text`); default risky.
- **NPCs:** `{npc, cell, dialogue, when, facing, approach, asleep, path, pause}`. The first entry per NPC whose
  `when` holds stands there; the game re-checks after every conversation and fight. `approach: n` makes the NPC speak
  first, once, when the leader comes within n squares and can see them. `asleep: true` lays the NPC down asleep
  (Unconscious, so Incapacitated and Prone, as the 2024 rules have a sleeper); the hover hint, Look and the Alt plates
  say so. `path: [[x, y], [x, y, seconds], ...]` walks the NPC from its cell through each waypoint and back, standing
  `pause` seconds (default 3, or a waypoint's own) at each (NpcRoutes): it holds while anyone talks or fights, while
  the leader stands beside it and while its next square is taken, and under turn-based exploring walks only as a
  round ends; a sleeper never walks. Waypoints must be open floor reachable without opening a door.
- **Prop kinds:** `examine` (Narrator line `examine:<id>`), `book` (`codex` entry), `search` (a hidden thing found
  with `search_dc`), `lever` (sets `flag`), `decor` (no interaction). Optional `when`, `dialogue`, `item`, `flag`.

## data/npcs/<id>.json (schema: npc.schema.json)

`id`, `name`, `title`, `summary`, `portrait` (art id), `sprite` (art id), `attitude` (starting: hostile,
indifferent, friendly), `voice` (docs/voice/<id>.md), `monster` (stat block id if they can fight), `guest` (true if
they can join as a guest ally), `tags`.

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
