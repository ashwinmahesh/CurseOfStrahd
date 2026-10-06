# ADR 0011: The rest of Barovia: region packages, treasure spots, allies and dark gifts

Status: accepted (Phase 5)

## Context

Phase 5 (plan §10) adds regions 5 to 10 (plan §6) as independent content packages built in parallel, raises the
level cap to 11, and its exit is that every Tarokka outcome place exists and its treasure or ally can be obtained.
Writers working at the same time must not edit the same files, and the reading's places (data/tarokka/outcomes.json)
have to become something the engine can hand over.

## Decision

- **A region package owns its files.** `docs/regions/<region>.md`, `data/locations/<region>*.json`,
  `narrative/<region>/`, `data/flags/<region>.json`, `data/quests/<quest>.json` for its quests, the NPCs it introduces,
  its random tables, and **its own travel file `data/travel/<region>.json`**. The travel map is every file in
  `data/travel/` merged (places and roads), so writers never edit one shared map file. A road may join a new place to
  any existing place.
- **Treasure spots.** A location names the Tarokka places it holds in `treasure_spots`:
  `{"<place id>": {"container": "<container id>"} | {"encounter": "<encounter id>"} | {"dialogue": "<file:node>"}}`.
  When the reading puts the Tome, the Holy Symbol or the Sunsword at that place, it is in that container, it is loot
  from that fight, or the conversation hands it over with the statement `tarokka give <place id>`. The condition
  `treasure_at:<place id>` is true while a treasure that hasn't been found is there. Finding one sets
  `treasure_found_<slot>` (tome, symbol, sword). Places inside Castle Ravenloft come with the castle (Phase 6).
- **Allies.** Each high card's ally is an NPC with `guest: true` and a `guest_build`; the ally's region writes a
  conversation that ends in `join <npc>` when `tarokka.ally.npc == <npc>` (it may also be possible otherwise).
- **Dark gifts** are data (`data/dark_gifts/<id>.json`): a benefit (modifiers, granted spells or actions, as feats
  have) and a cost that cannot be undone (modifiers or a flaw the character carries). The dialogue statement
  `dark_gift <id>` offers it to a party member the player picks; accepting is permanent and saved in the build.
- **Level cap 11.** Milestones in the new regions take the party from 5 to 11. Spells of levels 5 to 9 are data now
  (monster and NPC casters need the high ones); player characters reach 6th-level spells at 11.

## Consequences

- `make validate` checks each place in outcomes.json outside the castle against a `treasure_spots` entry in its
  region, each ally card against a guest NPC, and every travel file's places and roads.
- The Phase 5 exit test reads the reading's places and spots, so a new region is covered by adding data.
