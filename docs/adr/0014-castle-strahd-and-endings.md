# ADR 0014: Castle Ravenloft, Strahd and the endings

Status: accepted (Phase 6)

## Context

Phase 6 (plan §10) closes the campaign: Castle Ravenloft as a multi-floor dungeon with secret passages and the
Tarokka's final battle room, Strahd as a boss with legendary and lair actions, mist and bat forms and a retreat to his
coffin, his harassment of the party across the whole campaign, and endings and epilogues driven by flags. The exit is
that the campaign can be completed from start to finish with at least three distinct endings reachable. Like Phase 5,
the castle is written by several writers at once, so each part owns its files; the engine pieces are contracts here
first so content and code can be built in parallel.

## Decision

### The castle is one region in five parts

- Region id `castle_ravenloft`. `docs/regions/castle_ravenloft.md` is the overview (parts, map ids, stairs between
  parts, which Tarokka places and enemy rooms each part holds, who owns what). Each part has its own design doc
  `docs/regions/castle_ravenloft_<part>.md`, its locations `data/locations/castle_ravenloft_<part>*.json`, its
  conversations `narrative/castle_ravenloft/<part>_*.dialogue`, and its flags `data/flags/castle_ravenloft_<part>.json`.
  The parts: `gates` (the approach, courtyard, main floor, chapel, dinner), `court` (the Court of the Count and the
  Rooms of Weeping: audience hall, study, treasury, the brides, Rahadin), `spires` (the towers and roofs: the Heart of
  Sorrow, the north tower peak, the ravens' roost, Pidlwick II), `larders` (the Larders of Ill Omen and the dungeon:
  the wine cellar, the hall of bones, the cells), `catacombs` (the crypts and the tombs of Sergei, Barov and Ravenovia,
  and Strahd).
- **Floors are maps; stairs are exits.** A floor or wing is a location map; stairs, chutes and secret passages are
  exits (one-way where the place is). Secret doors are hidden areas or locked doors with a Perception or Investigation
  DC (the existing HiddenAreas and door locks). Teleport traps and the elevator are exits with a condition or a trap.
- **Travel:** `data/travel/castle_ravenloft.json` has the castle gate place, joined to the existing road by the Svalich
  Woods / village side. Entering the castle never needs the dinner invitation, but the invitation is the polite way in.
- **Treasure spots** are ADR 0011's, unchanged: every `castle_ravenloft_*` place in data/tarokka/outcomes.json is a
  `treasure_spots` key in exactly one castle location.

### The final battle

- `tarokka.enemy.room` names where Strahd waits. Each enemy room has one encounter, in the location that holds the
  room, marked `"final_battle": "<room id>"` and `"lair": true` (location encounters already have a trigger area
  and a `when`). The engine adds to its `when`: the reading's enemy room is that room, `strahds_lair` is at
  `foretold` or later, and Strahd isn't destroyed. The card `mists` (room `castle_ravenloft`) means he roams: the
  engine picks one of the enemy rooms from the playthrough seed when the reading is drawn and stores it in the
  reading (`tarokka.enemy.roam`), so saves stay stable. The condition `final_room:<room id>` is true for the room
  he waits in (the drawn room, or the roam pick).
- **The parley.** Before a final battle starts, the engine plays `strahd/final:parley` (the presence package writes
  it): Strahd names his price. It sets `strahd_parley` to `fight`, `yield` or `ireena`; only `fight` (or a parley that
  sets nothing) starts the battle. `yield` and `ireena` end the game (below).
- Strahd is destroyed only in his coffin: dropping him to 0 Hit Points anywhere else turns him to mist (Misty Escape)
  and he flees to `castle_ravenloft_strahds_tomb`, flag `strahd_in_coffin`. Finishing him there (the stake, sunlight,
  or the coffin fight) sets `strahd_destroyed` and moves `strahds_lair` to `destroyed`. If the party wipes in the final
  battle, it is not a load screen: it leads to an ending (below).

### Strahd in combat

- Monster `strahd_von_zarovich` (Curse of Strahd numbers: the 2025 Monster Manual has no Strahd; owner rule
  2026-10-06). The engine adds what his block needs, as data any monster can use:
  - `legendary_actions`: `{"per_round": 3, "options": [{"id", "name", "cost", "action" or "move"}]}`; used at the end
    of another creature's turn, refreshed at the start of his own. Shown in the initiative tracker.
  - `lair_actions`: on initiative count 20 (losing ties) when the encounter has `lair: true`; one per round, the same
    one never twice in a row.
  - Regeneration (`regenerates`: hit points at the start of his turn unless he took Radiant damage or is in running
    water), Shapechanger (`forms`: bat, wolf, mist; a form swaps size, speed, attacks and immunities and keeps his hit
    points), Misty Escape (above), Charm, Children of the Night (a summon that adds swarms or wolves to the fight),
    Spider Climb, and the vampire weaknesses already in the engine.
  - An AI profile `strahd`: he strikes the weakest or the one carrying a treasure, charms, summons, uses legendary
    moves to stay out of reach, and leaves (mist or bat) when the encounter says so.
- **Withdrawing.** An encounter may say when a foe leaves: `"withdraw": {"who": "<monster id>", "at_hp_below": n,
  "after_rounds": n, "flag": "<flag set when he leaves>"}`. Strahd's harassment fights use it: he tests the party and
  goes. Leaving is not dying: no loot, no Misty Escape.

### Strahd's presence across the campaign

- `story/strahd_presence.gd` and `data/strahd/visits.json`: visits are data, each with a trigger (arrival in a place, a
  rest, a night of travel, days since the party entered Barovia), a condition (flags, `night`, Ireena with the
  party), `once` or a cooldown, and what happens (a conversation, an encounter that withdraws, a letter delivered, a
  Narrator line). He watches, writes, visits at night, tests the party in fights, and comes for Ireena. The dinner
  invitation (a letter and his black carriage) is one visit; it opens the castle's front door politely.
- His conversations are `narrative/strahd/*.dialogue` (the presence package), and the castle parts' dialogue may
  call into them.

### Endings and epilogues

- `data/endings/<id>.json`: `{"id", "title", "priority", "when": "<condition>", "narration": "<file:node>",
  "epilogue": [{"when": "<condition>", "text": "..."}...]}`. The dialogue statement `end_game` (or the engine after the
  final battle or a wipe in it) picks the highest-priority ending whose `when` holds, plays its narration, then shows
  the epilogue slides whose `when` holds (Vallaki's fate, Krezk, the Martikovs, the Order of the Silver Dragon, the
  dark gifts, Ireena, Ismark, each ally) on an ending screen, marks the save as finished and returns to the main menu.
- At least three endings, reachable by play: Strahd destroyed (dawn returns; Ireena's fate decides how), Strahd
  triumphant (the party falls in the final battle, or yields at the parley), and Ireena given up / the bride
  (the party hands her over at the parley, or she goes to him). Others (a party member who took the Vampyr's gift becoming the land's new darklord,
  Ireena at peace with Sergei) are welcome where the flags support them.

## Consequences

- `make validate` checks the castle's treasure spots against outcomes.json like ADR 0011, every enemy room against exactly one
  `final_battle` encounter, Pidlwick II as a guest with a join scene, every ending's narration and condition, and every
  visit's dialogue and encounter.
- The Phase 6 exit test plays the campaign from a new game to each of three endings with the test bots, and checks
  every castle Tarokka place, every enemy room's fight and the castle ally.
- Content and code are built in parallel against these fields; field names may be refined by the engine owner, who
  updates this ADR and docs/contracts/campaign.md in the same change.
