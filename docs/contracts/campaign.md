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

`pos` is where the place sits on the map image (0-1 across and down). A road may bend around water or mountains with `via`: a list of points `[[x, y], ...]` in the same fractions, drawn as a smooth curve (docs/ui/travel_map.md). A place without `when` is on the map from the
start (somewhere everyone in the valley knows); a place with `when` appears once it holds or the party has been there. Entering a location's travel exit (an exit with `"to": "travel"`) opens the map.

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

Every entry pays (Ashwin, 2026-10-09; story/road_spoils.gd, game_root): a fight's spoils hold coins for each foe by its
Challenge Rating (after the 2024 DMG's individual treasure), one find in step with the party's level (a healing
potion, a gem or a spell scroll) and a chance of a magic item that grows with the foes' XP against the party's
Moderate budget; a dialogue entry leaves a smaller purse and one find in the loot window when its conversation ends,
or after the fight it led to. Rolled from the playthrough's seed and the encounter, so a reload gives the same. A
journey under way waits until the loot window closes.

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

## Region travel files (Phase 5, ADR 0011)

Every file in `data/travel/` is merged into the one map: a region adds `data/travel/<region>.json` with the same shape
(`id`, `name`, `places`, `roads`) holding only its own places and the roads that reach them. Road ends may be places
from any file. Place ids are unique across files.

## Treasure spots (Phase 5, ADR 0011)

In a location file:

```json
"treasure_spots": {
  "old_bonegrinder": {"container": "hag_oven"},
  "argynvostholt_vladimir": {"encounter": "vladimir_horngaard"},
  "krezk_pool_of_the_white_sun": {"dialogue": "krezk/pool:the_pool"}
}
```

- Keys are `place` values from data/tarokka/outcomes.json (a location id, or `location:spot`). Every place outside
  Castle Ravenloft must have exactly one spot, in a location of its region.
- `container`: a container id in the same location. Opening it also yields every treasure the reading put there.
- `encounter`: an encounter id in the same location. Winning that fight adds the treasure to the loot.
- `dialogue`: a conversation node (file:node) that reaches `tarokka give <place id>`.
- Condition `treasure_at:<place id>`: a treasure not yet found is there (so a line can hint at it).
- Found treasures set `treasure_found_tome`, `treasure_found_symbol`, `treasure_found_sword`. Items:
  `tome_of_strahd`, `holy_symbol_of_ravenkind`, `sunsword`.

## Allies (Phase 5)

Each ally card's NPC (outcomes.json `ally.<card>.npc`) has `"guest": true`, a `guest_build`, and a conversation in its
region that reaches `join <npc>` when `tarokka.ally.npc == <npc>`. The darklord card has no ally; the marionette
(Pidlwick II) waits in the castle (Phase 6).

## Dark gifts (Phase 5)

`data/dark_gifts/<id>.json`:

```json
{"id": "gift_of_zantras", "name": "Zantras's gift", "vestige": "Zantras", "summary": "Our words.",
 "benefit": {"modifiers": [{"stat": "ability", "ability": "cha", "value": 4, "max": 22}], "text": "..."},
 "cost": {"modifiers": [], "flaw": "You can't bear to be out of the spotlight.", "text": "..."}}
```

Dialogue: `dark_gift <id>` asks which party member accepts (or none); the gift is saved in that character's build and
can't be undone. Condition: `gift:<id>` (anyone in the party carries it).

## Endings (Phase 6, ADR 0014)

`data/endings/<id>.json` (schema: ending.schema.json):

```json
{"id": "ireena_given_up", "title": "The Bride of Ravenloft", "summary": "One line for the title card and the save.",
 "priority": 15, "when": "flag.strahd_parley == ireena and not flag.strahd_destroyed",
 "narration": "endings/ireena_given_up:start", "tone": "blood", "music": "ending",
 "epilogue_from": "strahd_triumphant",
 "epilogue": [{"topic": "ireena", "title": "Ireena Kolyana", "portrait": "ireena", "when": "", "text": "Our words."}]}
```

- **When the game ends**: the dialogue statement `end_game`; a conversation that leaves `strahd_parley` at `yield` or
  `ireena` (the parley, with or without `end_game`); a wipe in an encounter with `final_battle`; any won fight that
  leaves `strahd_destroyed` set. A scene that destroys Strahd without a fight ends with `end_game`.
- **Which ending**: the highest `priority` whose `when` holds then. It is recorded once in the flag `campaign_ending`
  (story/endings.gd `Endings.request`) and never changes.
- **The ending screen** (ui/screens/ending_screen.gd): the title card (`title`, `summary`), the `narration` node played
  line by line (Narrator, NPC and `interject` lines only; it never offers a choice), then the slides, then The End:
  the game's save slot is written marked `"finished": {ending, title}` (SaveSystem.save_finished) and Return to the
  title goes to the main menu. Finished saves list after unfinished ones (Continue skips them) with "The End: <title>"
  as their place; loading one plays its ending again.
- **Slides**: this ending's `epilogue`, then those of `epilogue_from` (and its own `epilogue_from`). Each `topic` is
  shown once: the first slide of it whose `when` holds, so an ending's own slide replaces the inherited one and a
  topic's variants go most specific first. A topic with no slide that holds is left out. `{name}` is the bearer of
  the Second Thirst (`gift_of_the_hollow`), else the leader; `"portrait": "{name}"` is that character's portrait. The
  party members lost on the way close the slides.
- `tone` lights the screen (`dawn`, `night`, `blood`); `music` is the art/audio.json mood it plays (default `ending`).

| Ending | Priority | When | Epilogue |
|---|---|---|---|
| `new_darklord` The Second Thirst | 40 | `flag.strahd_destroyed and gift:gift_of_the_hollow` | own, then `strahd_triumphant` |
| `ireena_at_peace` At Sergei's Side | 30 | `flag.strahd_destroyed and flag.ireena_pool_choice == promised` | own, then `strahd_destroyed` |
| `strahd_destroyed` Dawn over Barovia | 20 | `flag.strahd_destroyed` | the dawn set |
| `ireena_given_up` The Bride of Ravenloft | 15 | `flag.strahd_parley == ireena and not flag.strahd_destroyed` | own, then `strahd_triumphant` |
| `strahd_triumphant` The Mists Remain | 10 | `not flag.strahd_destroyed` (a wipe in the final battle, or `yield`) | the dark set |

Slide topics read: `vallaki_backed`, `abbot_fate`, `ilya_fate`/`ilya_heard`, `order_fate`, `winery_wine_flows`,
`martikovs_reconciled`, `keepers_allied`/`ilinca_vouched`, `amber_temple_sealed`, `dark_gifts_taken`,
`kasimir_bargain`, `kasimir_at_peace`, `patrina_fate`, `van_richten_reunited`, `rictavio_unmasked`,
`van_richten_met_at_tower`, `ezmerelda_met`, `mordenkainen_restored`/`mordenkainen_met`, `wolf_pack_leader`,
`lysaga_dead`/`lysaga_fate`, `bonegrinder_fate`, `death_house_children_at_rest`/`death_house_sacrificed`/
`death_house_refused`, `ireena_pool_choice`, `ireena_in_krezk`, `guest:ireena`, `visited:vallaki`, `visited:krezk`,
`strahd_parley`.

## Castle Ravenloft and the final battle (Phase 6, ADR 0014)

- The castle is region `castle_ravenloft` in five parts (docs/regions/castle_ravenloft.md): each part's entry map has
  `from_<part>` spawns and exits to the others. Its 15 Tarokka places are ordinary treasure spots.
- **Final battles:** each enemy room in outcomes.json (except `castle_ravenloft`, the roaming `mists` card) has exactly
  one location encounter with `"final_battle": "<room id>"` and `"lair": true`, with Strahd in it. The engine adds to its
  `when` that the reading's room (or the roam pick) is that room, `strahds_lair` is at `foretold` or later and Strahd
  isn't destroyed; it plays `strahd/final:parley` first and fights only if `strahd_parley` is `fight` or unset. The
  condition `final_room:<room id>` is true for the room he waits in.
- **Withdrawing foes:** a location or visit encounter may carry `"withdraw": {"who", "at_hp_below", "after_rounds",
  "flag"}`; the foe leaves (no loot, no death) and the flag is set.
- **Strahd's coffin:** 0 Hit Points outside his tomb is Misty Escape: `strahd_in_coffin` is set and he leaves. The
  catacombs' coffin scene sets `strahd_destroyed`, moves `strahds_lair` to `destroyed` and ends the game.

## Strahd's visits (Phase 6, ADR 0014; data/strahd/visits.json, schema: strahd_visits.schema.json)

Each visit: `id`, `summary`, `trigger` (`on`: travel, arrive, rest, ...), `when` (a condition), `once` or
`cooldown_hours` and `max`, `dialogue` (`file:node`), and `then`: steps with a `when` and an `encounter` (inline,
usually with `withdraw`), a `go` (`location:spawn`) or a `dialogue`. `story/strahd_presence.gd` runs them; the design is
docs/regions/strahd_presence.md. `make validate` checks every dialogue node, monster, withdrawing foe, `go` target and
the flags the visits read and set.
