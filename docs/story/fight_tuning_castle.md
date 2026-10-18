# Castle Ravenloft's rooms and watches, and the road home from Yester Hill

(Owner, 2026-10-13: the book's fights were written for weaker characters. Over seeds 1-8 the four pregens on the sharp
autopilot win five in eight on Balanced, give or take one, each fight played from where walking in or touching something
sets it off, its foes starting spread out. The bosses are the boss lane's, in `docs/story/boss_fights.md`.)

## The road home from Yester Hill

The foot of Yester Hill (`yester_hill`) now allows a risky rest (2026-10-15); the summit and the Gulthias tree
(`yester_hill_gulthias_tree`) still allow none. Before, a party that had just won the summit walked home with its healers'
slots spent on Cure Wounds and the rest of its slots gone, and the first road ambush (`vineyard_road:hedgerow_blights`,
or the `druids_return` revenge) met a spent party: the four playthrough heroes who win that fight eight times in eight
rested lost all eight tries in `test_phase5_exit` at seed 11. Now the party can come down from the crown and rest on the
hill's foot before it sets out, as a player would.

## The castle's rooms, watches and guards

Fights that had no series test, each now held by `tests/integration/test_scaled_fights_castle_rooms.gd` (seeds 1-8, the four
pregens on the sharp autopilot, 4 to 6 wins, none timing out). Where the room is too cramped to add foes without one
Fireball catching most of them (the accountant's rug room, the Kestrel cellar), the foes are fewer and stronger or carry more
Hit Points rather than more of the same. The Kestrel fights are played with Ilse Varga in the party, as the story has it.

| Fight | Where | Version | Level | Was | Now | Wins |
|---|---|---|---|---|---|---|
| `cat_gargoyle_watch` | catacombs | L10v0 | 10 | 6 gargoyle | 16 gargoyle (101 HP) | 5 |
| `cat_sleepers` | catacombs | L10v0 | 10 | 3 vampire spawn | 10 vampire spawn | 4 |
| `cat_sleepers` | catacombs | L10v1 | 10 | 2 vampire spawn | 10 vampire spawn | 4 |
| `cat_guardians` | catacombs_tombs | L10v0 | 10 | strahds animated armor, 2 helmed horror | 2 strahds animated armor, 4 helmed horror | 5 |
| `court_accountant_rug` | court | L10v0 | 10 | rug of smothering, 3 crawling claw | rug of smothering (57 HP), 3 crawling claw (4 HP), 3 strahds animated armor (235 HP) | 5 |
| `court_post_watch` | court | L10v0 | 10 | strahds animated armor, 3 helmed horror | strahds animated armor (190 HP), 4 helmed horror (102 HP) | 5 |
| `crg_courtyard_gargoyles` | gates | L10v0 | 10 | 6 gargoyle | 16 gargoyle (77 HP) | 4 |
| `crg_courtyard_gargoyles` | gates | L9v1 | 9 | 4 gargoyle | 14 gargoyle (84 HP) | 5 |
| `larders_guardroom` | larders | L10v0 | 10 | 2 wight, 2 helmed horror, 4 strahd zombie | 4 wight, 4 helmed horror, 6 ghast, strahd zombie | 5 |
| `larders_watch_alarm` | larders | L10v0 | 10 | 2 wight, 2 helmed horror, 4 strahd zombie | 4 wight (102 HP), 3 helmed horror (75 HP), strahd zombie (38 HP), 5 ghast (45 HP) | 5 |
| `larders_furnace` | larders_dungeon | L10v0 | 10 | 2 flameskull, fire elemental | 3 flameskull, fire elemental | 4 |
| `larders_jailers` | larders_dungeon | L10v0 | 10 | 3 helmed horror | 8 helmed horror (108 HP) | 5 |
| `larders_questioner` | larders_dungeon | L10v0 | 10 | wight, 2 black pudding, 6 crawling claw | 3 wraith (151 HP), 5 black pudding (153 HP), 9 crawling claw (4 HP) | 5 |
| `crg_kestrel_cellar` | main_floor | L10v0 | 10 | 3 vampire spawn | 7 vampire spawn (126 HP) | 6 |
| `crg_kestrel_cellar` | main_floor | L10v1 | 10 | 3 vampire spawn | 7 vampire spawn (144 HP) | 5 |
| `crg_kestrel_table` | main_floor | L10v0 | 10 | 5 vampire spawn (110 HP) | 5 vampire spawn (162 HP) | 5 |
| `crg_turret_guard` | main_floor | L10v0 | 10 | 2 strahds animated armor | 4 strahds animated armor (118 HP) | 6 |
| `crg_turret_guard` | main_floor | L9v1 | 9 | strahds animated armor | 4 strahds animated armor | 6 |
| `spires_stair_watch` | spires | L10v1 | 10 | 3 vampire spawn, 3 swarm of bats | 8 vampire spawn, 8 swarm of bats | 6 |
| `spires_stair_watch` | spires | L11v0 | 11 | 4 vampire spawn, 3 swarm of bats | 9 vampire spawn, 7 swarm of bats | 5 |
| `spires_stair_watch` | spires | L9v2 | 9 | 2 vampire spawn, swarm of bats | 6 vampire spawn, 5 swarm of bats | 5 |
| `heart_guardians` | spires_heart | L10v1 | 10 | 2 strahds animated armor, helmed horror | 3 strahds animated armor (140 HP), 2 helmed horror (75 HP) | 5 |
| `heart_guardians` | spires_heart | L11v0 | 11 | 2 strahds animated armor, 2 helmed horror | 3 strahds animated armor, 3 helmed horror | 6 |
| `heart_guardians` | spires_heart | L9v2 | 9 | strahds animated armor, helmed horror | 3 strahds animated armor, 2 helmed horror | 6 |
| `peak_guardians` | spires_roofs | L10v1 | 10 | 6 gargoyle | 16 gargoyle (70 HP) | 4 |
| `peak_guardians` | spires_roofs | L11v0 | 11 | 8 gargoyle | 16 gargoyle (55 HP) | 5 |
| `peak_guardians` | spires_roofs | L9v2 | 9 | 4 gargoyle | 16 gargoyle (58 HP) | 5 |
| `cauldron_coven` | spires_rooms | L10v1 | 10 | 6 barovian witch, black pudding | 11 barovian witch (74 HP), 8 black pudding (313 HP) | 6 |
| `cauldron_coven` | spires_rooms | L11v0 | 11 | 8 barovian witch, black pudding | 12 barovian witch (64 HP), 5 black pudding (272 HP) | 5 |
| `cauldron_coven` | spires_rooms | L9v2 | 9 | 4 barovian witch, black pudding | 10 barovian witch (36 HP), 6 black pudding (153 HP) | 5 |
| `escher_fight` | spires_rooms | L10v0 | 10 | vampire spawn, 2 swarm of bats | 7 vampire spawn, 7 swarm of bats | 5 |
| `roost_swarm` | spires_roost | L10v0 | 10 | 6 swarm of ravens | 6 swarm of ravens (11 HP), 10 wereraven (55 HP) | 5 |
| `roost_swarm_roused` | spires_roost | L10v0 | 10 | 6 swarm of ravens | 6 swarm of ravens (13 HP), 8 wereraven (65 HP) | 5 |
