# Castle Ravenloft (region 11): overview

Plan §10 Phase 6; ADR 0014 (castle, Strahd, endings); ADR 0011 (treasure spots, allies). This page is the map of the
castle's five parts and the seams between them. Each part's design is its own doc, written by its owner. Areas are
named after the adventure's keyed areas (K1 to K88) in the part docs so they can be checked against the book; all text
in data and dialogue is our own words.

## Parts and owners

| Part | Doc | Covers (book areas, roughly) | Entry map |
|---|---|---|---|
| `gates` | castle_ravenloft_gates.md | the drawbridge and courtyards, the great entry and main floor, the dining hall (dinner with Strahd), the hall of faces, the chapel, the overlook balcony (K1 to K17) | `castle_ravenloft_gates` (courtyard, arrival) and `castle_ravenloft_main_floor` |
| `court` | castle_ravenloft_court.md | the Court of the Count and the Rooms of Weeping: the audience hall, the study, the treasury, Strahd's rooms, the brides, Rahadin, Lief Lipsiege, Gertruda, the guest rooms (K25 to K53) | `castle_ravenloft_court` |
| `spires` | castle_ravenloft_spires.md | the high tower stairway and the spires: the Heart of Sorrow, the north tower peak, the ravens' roost, the bridge and the roofs, Pidlwick II, Escher (K18 to K24, K54 to K60) | `castle_ravenloft_spires` |
| `larders` | castle_ravenloft_larders.md | the Larders of Ill Omen and the dungeon: the kitchen and Cyrus Belview, the wine cellar, the hall of bones, the guard rooms, the cells and the torture chamber (K61 to K83) | `castle_ravenloft_larders` |
| `catacombs` | castle_ravenloft_catacombs.md | the catacombs' crypts (the Mad Dog, the wizard, the gargoyle-watched warrior and the rest), Sergei's tomb, Strahd's tomb and his coffin, the tomb of King Barov and Queen Ravenovia (K84 to K88) | `castle_ravenloft_catacombs` |

A part owns `data/locations/castle_ravenloft_<part>*.json`, `narrative/castle_ravenloft/<part>_*.dialogue`,
`data/flags/castle_ravenloft_<part>.json`, its quests, the castle NPCs it introduces (table below) and their voice
bibles, and its Narrator lines (`narrative/narrator/castle_ravenloft_<part>.dialogue`) and banter
(`narrative/banter/castle_ravenloft_<part>.dialogue`). The `gates` part also owns `data/travel/castle_ravenloft.json`.

## Seams between parts

Each part's entry map has a spawn for every part that leads into it, named `from_<part>`, and the stairs, passages and
chutes that lead out are exits to the other part's entry map and that spawn. Every seam is written by both sides.

| Seam | Where (in the book's terms) | Exit in | Arrives at |
|---|---|---|---|
| gates ↔ court | the grand stairs up from the main floor | `castle_ravenloft_main_floor` / `castle_ravenloft_court` | `castle_ravenloft_court:from_gates` / `castle_ravenloft_main_floor:from_court` |
| gates ↔ spires | the high tower stairway off the main floor | `castle_ravenloft_main_floor` / `castle_ravenloft_spires` | `castle_ravenloft_spires:from_gates` / `castle_ravenloft_main_floor:from_spires` |
| court ↔ spires | the tower stairs from the upper floors | `castle_ravenloft_court` / `castle_ravenloft_spires` | `castle_ravenloft_spires:from_court` / `castle_ravenloft_court:from_spires` |
| gates ↔ larders | the servants' stairs down | `castle_ravenloft_main_floor` / `castle_ravenloft_larders` | `castle_ravenloft_larders:from_gates` / `castle_ravenloft_main_floor:from_larders` |
| gates ↔ catacombs | the stairs down from the chapel side to the crypts | `castle_ravenloft_main_floor` / `castle_ravenloft_catacombs` | `castle_ravenloft_catacombs:from_gates` / `castle_ravenloft_main_floor:from_catacombs` |
| larders ↔ catacombs | the dungeon's way down to the crypts | `castle_ravenloft_larders` / `castle_ravenloft_catacombs` | `castle_ravenloft_catacombs:from_larders` / `castle_ravenloft_larders:from_catacombs` |

Part-internal maps are named `castle_ravenloft_<part>_<what>` and joined however the part's doc says (stairs,
secret doors, one-way chutes, the elevator trap, teleport traps).

## Tarokka places (ADR 0011 treasure spots) and enemy rooms (ADR 0014 final battles)

Every place id below is a `treasure_spots` key in exactly one location of its part; every enemy room is the
`final_battle` of exactly one encounter there.

| Id | Part | Treasure place | Enemy room (card) |
|---|---|---|---|
| `castle_ravenloft_chapel` | gates | yes | artifact |
| `castle_ravenloft_overlook` | gates | | executioner |
| `castle_ravenloft_hidden_hearth` | gates | yes (hidden behind a hearth, deep in the keep) | |
| `castle_ravenloft_audience_hall` | court | yes (at the throne) | beast |
| `castle_ravenloft_study` | court | yes (a woman's portrait over the fireplace) | seer |
| `castle_ravenloft_treasury` | court | yes (under heaps of gold) | tempter |
| `castle_ravenloft_heart_of_sorrow` | spires | | marionette |
| `castle_ravenloft_north_tower_peak` | spires | yes (among the stone guardians) | |
| `castle_ravenloft_ravens_roost` | spires | yes (among the ravens' nests) | |
| `castle_ravenloft_wine_cellar` | larders | yes (a cellar that is also a tomb) | |
| `castle_ravenloft_hall_of_bones` | larders | yes | donjon |
| `castle_ravenloft_catacombs` | catacombs | | horseman |
| `castle_ravenloft_crypt_of_the_mad_dog` | catacombs | yes | |
| `castle_ravenloft_crypt_of_the_wizard` | catacombs | yes (his wand is the key) | |
| `castle_ravenloft_gargoyle_tomb` | catacombs | yes (a warrior's tomb watched by gargoyles) | |
| `castle_ravenloft_sergeis_tomb` | catacombs | yes | broken_one, innocent |
| `castle_ravenloft_tomb_of_barov_and_ravenovia` | catacombs | yes | ghost, raven |
| `castle_ravenloft_strahds_tomb` | catacombs | yes | darklord |

The card `mists` sends Strahd roaming (ADR 0014): one of the enemy rooms, picked from the seed.

## Castle people (who introduces them)

| NPC | Part | Notes |
|---|---|---|
| strahd (exists) | presence package (P6-03) writes his voice and visits; every part may give him lines | the host, the hunter |
| rahadin | court | Strahd's chamberlain, a dusk elf with screams in his wake |
| ludmilla_vilisevic, anastrasya_karelova, volenta_popofsky | court | the three brides (vampire spawn) |
| lief_lipsiege | court | the accountant chained in his office |
| gertruda | court | Mad Mary's daughter (quest find_gertruda, Vallaki): the castle is where she is found; new NPC |
| escher | spires | a cast-off consort (vampire spawn) |
| pidlwick_ii | spires | the clockwork jester, the marionette card's ally (guest, join scene) |
| cyrus_belview | larders | the mongrelfolk cook |
| sergei_von_zarovich (exists) | catacombs | the spirit at his brother's tomb; Ireena's story |

## Levels and balance

The party arrives at 9 to 11 (the cap is 11, ADR 0011); the castle gives no milestone of its own. Fights are tuned
for a party of four at level 10 with one guest, using the 2025 Monster Manual where it has the creature (owner rule).
