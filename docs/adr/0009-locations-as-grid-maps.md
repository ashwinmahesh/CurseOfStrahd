# ADR 0009: Locations are grid maps; exploration and combat share them

Status: accepted (Phase 3)

## Context

The party roams in real time and every fight snaps to a 5 ft grid laid over the level (plan §5.2, §5.3). Phase 2
built maps from rows of characters (ADR 0007). Phase 3 needs many locations written by agents.

## Decision

- **A location is data** (`data/locations/<id>.json`, `docs/contracts/locations.md`): the same map rows as an
  encounter, plus areas, spawns, exits, doors (locked, keyed, secret), props (examine, book, search, lever),
  containers, lights, traps, NPCs with their conversations, encounters with triggers, narration keys and rest rules.
  `make validate` checks that everything stands on open floor, every exit and spawn exists, and every item, monster,
  NPC, conversation and flag is real.
- **Exploration moves on the grid**: click to move or WASD, with the cheapest path; followers step into the square
  the one ahead of them just left (marching order), or stay put while one character moves alone. Movement is smooth
  between squares but positions are always squares, so a fight starts exactly where everyone stands.
- **Fights happen in place**: the location's grid as it stands (closed doors are walls, NPCs block their squares)
  becomes the Encounter's grid; the party fights where it stood, with stealth surprise when sneaking; the
  CombatView from the arena runs it; victory returns to exploration with the fallen stabilized.
- **The world keeps state in StoryState** (doors opened, containers looted and partial contents, traps found,
  disarmed or sprung, fights won, hidden things found), so leaving and returning, or loading, puts it back.
- Vision rules (Darkvision, darkness and obscurement in checks and attacks) belong to the spell and ability audit;
  the world reports light levels and draws light.

## Consequences

- One geometry for both modes means no separate navmesh or collision to keep in sync, and level art is a dressing of
  the map (placeholder boxes until the Phase 4 art pass).
- Free-form movement off the grid isn't possible; it isn't needed for a turn-based game whose fights use squares.
