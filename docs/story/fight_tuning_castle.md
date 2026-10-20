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
| `cat_gargoyle_watch` | catacombs | L10v0 | 10 | 6 gargoyle | 16 gargoyle (110 HP) | 6 |
| `cat_sleepers` | catacombs | L10v0 | 10 | 3 vampire spawn | 10 vampire spawn | 4 |
| `cat_sleepers` | catacombs | L10v1 | 10 | 2 vampire spawn | 10 vampire spawn | 4 |
| `cat_guardians` | catacombs_tombs | L10v0 | 10 | strahds animated armor, 2 helmed horror | 2 strahds animated armor, 4 helmed horror | 5 |
| `court_accountant_rug` | court | L10v0 | 10 | rug of smothering, 3 crawling claw | rug of smothering (120 HP), 3 crawling claw (4 HP), 4 strahds animated armor (120 HP) | 6 |
| `court_post_watch` | court | L10v0 | 10 | strahds animated armor, 3 helmed horror | strahds animated armor (120 HP), 4 helmed horror (102 HP) | 5 |
| `crg_courtyard_gargoyles` | gates | L10v0 | 10 | 6 gargoyle | 16 gargoyle (64 HP) | 5 |
| `crg_courtyard_gargoyles` | gates | L9v1 | 9 | 4 gargoyle | 14 gargoyle (68 HP) | 5 |
| `larders_guardroom` | larders | L10v0 | 10 | 2 wight, 2 helmed horror, 4 strahd zombie | 4 wight, 4 helmed horror, 6 ghast, strahd zombie | 5 |
| `larders_watch_alarm` | larders | L10v0 | 10 | 2 wight, 2 helmed horror, 4 strahd zombie | 4 wight (102 HP), 3 helmed horror (75 HP), strahd zombie (38 HP), 5 ghast (45 HP) | 5 |
| `larders_furnace` | larders_dungeon | L10v0 | 10 | 2 flameskull, fire elemental | 3 flameskull, fire elemental | 4 |
| `larders_jailers` | larders_dungeon | L10v0 | 10 | 3 helmed horror | 8 helmed horror (135 HP) | 5 |
| `larders_questioner` | larders_dungeon | L10v0 | 10 | wight, 2 black pudding, 6 crawling claw | 3 wraith (151 HP), 5 black pudding (153 HP), 9 crawling claw (4 HP) | 5 |
| `crg_kestrel_cellar` | main_floor | L10v0 | 10 | 3 vampire spawn | 7 vampire spawn (126 HP) | 6 |
| `crg_kestrel_cellar` | main_floor | L10v1 | 10 | 3 vampire spawn | 7 vampire spawn (144 HP) | 5 |
| `crg_kestrel_table` | main_floor | L10v0 | 10 | 5 vampire spawn (110 HP) | 5 vampire spawn (162 HP) | 5 |
| `crg_turret_guard` | main_floor | L10v0 | 10 | 2 strahds animated armor | 4 strahds animated armor (118 HP) | 6 |
| `crg_turret_guard` | main_floor | L9v1 | 9 | strahds animated armor | 4 strahds animated armor | 6 |
| `spires_stair_watch` | spires | L10v1 | 10 | 3 vampire spawn, 3 swarm of bats | 8 vampire spawn, 8 swarm of bats | 6 |
| `spires_stair_watch` | spires | L11v0 | 11 | 4 vampire spawn, 3 swarm of bats | 9 vampire spawn, 7 swarm of bats | 5 |
| `spires_stair_watch` | spires | L9v2 | 9 | 2 vampire spawn, swarm of bats | 6 vampire spawn, 5 swarm of bats | 5 |
| `heart_guardians` | spires_heart | L10v1 | 10 | 2 strahds animated armor, helmed horror | 3 strahds animated armor (120 HP), 2 helmed horror (75 HP) | 5 |
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

## Waiting fights: which start each series holds (overworld stealth, piece 3)

A fight that waits in plain view starts where its foes first notice a party walking in, not only inside its area, so each
series starts there (the squares read off by walking from the spawn the story uses, with the doors opened on the way), and
the foes' Hit Points and squares are tuned from it. Where a place has a second real way in the series holds that start too
when one tuning can hold both: the courtyard's gate, yard middle and main-floor arrivals (the gate's column on the bridge
was 1 and 2 in 8 at the old 77 and 84 Hit Points, the yard's middle 4 and 5; now 5 and 5, 6 and 6, 5 and 6 with the six
foes standing by the portcullis moved to the yard's north half and 64 and 68 Hit Points), the jailers' west door and the
lift (the three horrors along the lift's corridor moved into the west hall, 135 Hit Points: 5 and 5), the champion's gate
from the north corridor and from the tombs (110 Hit Points: 6 and 5). Starts no tuning holds with the first-time way, as
measured (wins over seeds 1-8): the courtyard's side gate from the overlook 8 and 8 at levels 10 and 9 (6 and 6 at the old
data), the east turret's back door 8 and 7 (as at the old data), and Berez's field (docs/story/fight_tuning.md): from the
vault 5 and 4 at levels 7 and 8 hold but level 9 is 8 (6 at the old data, where the road was 7: the level 9 version's third
more Hit Points bring the road to 6), and from the hut 2, 2 and 3 (2, 2 and 6 at the old data).

## The Lesser Vaults' four fights (Dungeon Expansion Plan C1, 2026-10-18)

New fights, each tuned from nothing (they had no old version): seeds 1-8, the four pregens on the sharp autopilot at level 10,
5 wins, each held by `tests/integration/test_scaled_fights_castle_rooms.gd` (4 to 6), foes spread by
`tests/unit/test_fight_spread.gd` (each room is big enough that no Fireball catches more than the rule allows, so none is in
CRAMPED). The ladders tried are below the table (wins out of 8 over seeds 1-8).

| Fight | Where | Version | Level | Foes | Wins | Note |
|---|---|---|---|---|---|---|
| `cat_stahbal` | catacombs_vaults | L10v0 | 10 | 6 wights (144 HP), 12 skeletons | 5 | the captains rise from the coffins along the walls; 12.5 rounds, 2.5 heroes down a fight |
| `cat_sasha` | catacombs_vaults | L10v0 | 10 | 7 vampire spawn (86 HP; Sasha Ivliskova and six bridesmaids in webs) | 5 | woken by speaking to her; sets `cat_sasha_slain`; 5.8 rounds, 1.9 down |
| `cat_spiders` | catacombs_vaults | L10v0 | 10 | 7 giant spiders (80 HP), 4 wraiths | 5 | the wraiths are the nest's older prey, up out of the webs. Spiders alone only reached 5 in 8 as 12 spiders at 285 HP, a 20-round slog with two stalled fights; 7.6 rounds, 1.4 down |
| `cat_jarnwald_ghouls` | catacombs_vaults | L10v0 | 10 | 10 ghouls (79 HP), 3 ghasts (98 HP) | 5 | measured with the pit already sprung (as in play: a sprung trap is not armed in the fight); 4.9 rounds, 1.9 down |

The ladders (a scratch harness played each line-up over seeds 1-8; the final line-ups were then confirmed by the real series
tests). Skeletons are unnamed; wights, spawn, ghouls and wraiths too, except Sasha's seven.

- `cat_stahbal` (wights, skeletons): 4+12 8; 6+12 8; 6+12 at 110 HP 7; 6+12 at 125 HP 4; **6+12 at 140 HP 5**; 7+11 7; 7+10 6;
  8+10 4; 10+8 3.
- `cat_sasha` (vampire spawn): 3 8; 5 8; 5 at 130 HP 7; 7 5; 8 3; with names (Sasha and bridesmaids) **7 5**, 6 8.
- `cat_spiders`: giant spiders alone win too easily (6 at 60 HP, 8 and 10 at 80 HP: 8 of 8, nobody down) and only reach 5 in 8 by
  inflating them (10 at 200 HP 8; 12 at 260 HP 6; 12 at 285 HP 5 in 14 rounds or, with the foes spread so no Fireball
  catches ten of them, 3 with two timeouts in 20): a slog. With wraiths for the nest's older prey: 6 spiders at 100 HP + 3
  wraiths 7; 8 at 80 + 4 6; 6 at 100 + 5 3; **7 at 90 + 4 wraiths 5**.
- `cat_jarnwald_ghouls` (ghouls, ghasts): 8+2, 12+3, 14+4 at their own HP 8; 10 ghouls at 80 + 3 ghasts at 100 HP 7; 11 at 80 +
  3 at 100 6; 11 at 85 + 3 at 105 4; 12 at 85 + 3 at 105 4; 12 at 80 + 3 at 100 3; 14 at 100 + 4 at 120 2; **10 at 90 + 3 at
  110 HP 5**.

**Re-measured on 2026-10-20, on origin/main 26221e1ca.** The engine had moved since the first tuning (spread strikes, foes
sharing squares, AI and dangerous ground, free aim and more): the same line-ups won 6, 4, 3 and 4 in 8 (the spiders below
the band). Only Hit Points moved, the squares stayed: the real series tests now give **5, 5, 5 and 5**. A scratch harness
tried, over seeds 1-8: wights at 150 HP 3, 160 HP 3, 170 HP 1, 148 HP 4, 146 HP 4, **144 HP 5**, 142 HP 6; Sasha's seven spawn at
88 HP 4, **86 HP 5**, 85 HP 7, 84 HP 7, 80 HP 6, 75 HP 7; the spiders at 85 HP 6, **80 HP 5**, 70 HP 5; the ghouls and ghasts at
85 and 105 HP 4, 82 and 102 HP 4, 80 and 100 HP 4, 80 and 98 HP 4, 78 and 100 HP 6, 78 and 98 HP 6, 75 and 95 HP 6, 70 and 90 HP 7,
**79 and 98 HP 5**, 79 and 99 HP 5.

