# Campaign data: Tarokka, travel, random encounters, shops and guests (ADR 0010)

`make validate` checks every file below against its schema and every id it names.

## data/tarokka/cards.json (schema: tarokka_cards.schema.json)

```json
{"cards": [
  {"id": "artifact", "name": "Artifact", "deck": "high", "summary": "Our words: what the card stands for."},
  {"id": "swords_1", "name": "Avenger", "deck": "common", "suit": "swords", "value": 1, "summary": "..."},
  {"id": "swords_master", "name": "Warrior", "deck": "common", "suit": "swords", "value": 10, "summary": "..."}
]}
```

14 high cards; 40 common cards (four suits, 1 to 9 plus a master card = value 10). `art` (optional) names a card
image in `art/tarokka/`.

## data/tarokka/outcomes.json (schema: tarokka_outcomes.schema.json)

```json
{
  "tome":   {"swords_1": {"place": "argynvostholt_...", "region": "argynvostholt", "verse": "Madam Eva's words",
                          "hint": "The journal's one-line hint"}},
  "symbol": {"...every common card...": {}},
  "sword":  {"...every common card...": {}},
  "ally":   {"artifact": {"npc": "ezmerelda", "region": "...", "verse": "...", "hint": "...", "where": "..."}},
  "enemy":  {"artifact": {"room": "castle_ravenloft_...", "verse": "...", "hint": "..."}}
}
```

- Every common card appears in `tome`, `symbol` and `sword`; every high card in `ally` and `enemy`.
- `place` and `room` are location ids (or `location_id:area_id`); ones in later-phase regions are pending
  references (`validate_data.py --pending` lists them). `npc` is an npc id (pending allowed).
- `verse` and `hint` are our own words, never the book's.

## The reading in dialogue and conditions

```
tarokka draw              Draws the reading (once per playthrough; StoryState.seed decides it).
tarokka read tome         Madam Eva (the speaker) turns a card: a notice with the card's name, then her verse.
                          Slots: tome, symbol, sword, ally, enemy.
```

Conditions: `tarokka.drawn`, `tarokka.sword == swords_3` (the card), `tarokka.sword.region == vallaki`,
`tarokka.ally.npc == ezmerelda`. Quest journal text may use `{tarokka.tome.hint}` and the like.

## data/travel/barovia.json (schema: travel.schema.json)

```json
{
  "id": "barovia", "name": "Barovia",
  "places": [{"id": "village_of_barovia", "name": "Village of Barovia", "location": "village_of_barovia",
              "spawn": "from_west_road", "pos": [0.62, 0.58], "region": "village_of_barovia", "when": ""}],
  "roads": [{"id": "svalich_village_crossroads", "from": "village_of_barovia", "to": "svalich_crossroads",
             "hours": 2, "table": "svalich_road", "name": "Old Svalich Road", "when": ""}]
}
```

`pos` is where the place sits on the map image (0-1 across and down). A place with `when` appears once it holds
(heard of, visited). Entering a location's travel exit (an exit with `"to": "travel"`) opens the map.

## data/random_encounters/<table>.json (schema: random_table.schema.json)

```json
{
  "id": "svalich_road", "map": "road_ambush", "chance_day": 0.15, "chance_night": 0.4,
  "entries": [
    {"weight": 3, "when": "night", "monsters": [{"monster": "wolf", "cell": [10, 4]}], "text": "Narration as it starts."},
    {"weight": 2, "dialogue": "svalich_road/events:hanging_tree"}
  ]
}
```

`map` is a location used as the battlefield (the party arrives at its `default` spawn). A dialogue entry plays a
conversation instead of a fight (it may still end in `combat <id>` from that map's encounters).

## Shops (in data/npcs/<id>.json)

```json
"shop": {"sells": [{"id": "rope", "qty": -1}, {"id": "potion_of_healing", "qty": 1, "price": 500}],
         "buys": ["weapon", "armor", "gear", "treasure"], "markup": 10.0, "sell_rate": 0.5, "closed": "night"}
```

`qty` -1 = always in stock. `price` overrides `cost_gp × markup`. Selling pays `cost_gp × sell_rate`. The dialogue
statement `shop` opens the shop for the NPC being spoken to; `closed` is a condition.

## Guests (in data/npcs/<id>.json)

```json
"guest": true, "guest_build": {"monster": "noble", "level_note": "fixed by the story"}
```

or `"guest_build": {"pregen": "<pregen id>", "level": 3}` for a guest with a full character sheet. Dialogue:
`join ireena` adds the guest (they follow, fight on the party's side under the player's control, and appear in the
party frames), `leave ireena` removes them. Conditions: `guest:ireena`.
