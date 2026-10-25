# Fight tuning: 5 wins in 8 on the sharp test party

**Hit Points since 2026-10-24** (owner: "for ALL monster HP, just use the Monster Manual values; no custom HP"): the foes in these fights fight at their stat blocks' Hit Points. The raised or lowered Hit Points the tables below describe are gone from the data, and the win counts are the ones measured before; the combat-length pass measures the fights again.

**Line-ups since 2026-10-25** (owner: "for pretty much all battles in the book, we can remove extra enemies we added and just leave them how they are in the book"): the book's fights and the roads' random fights that are not boss fights are back to the line-ups they were first entered with from the module, the same number and kinds of foe (git history's first version of each fight; Elisabeth Durst stays a ghast, as the book has her). The bigger line-ups the tables below describe are gone from the data, and their intro lines that named the extra foes went back to the first wording. The book's boss fights followed (owner: "Yes for boss fights"): each boss and story foe stays as it is, and the minions go back to the first version's count. The side quests' fights and the fights entered after 2026-10-13 keep theirs for now.

The owner's rule (2026-10-13 18:05): the test party (four pregens on the autopilot that smites, opens with Spirit
Guardians and throws Fireball, as he plays) wins **5 of 8 on Balanced at every level**, seeds 1-8, for every fight that
is not a boss (bosses are the boss lane's, at their own target). The tests hold 4 to 6; where no line-up landed on 5
the table gives the harder side (4) or, when only the easier side was found without the fight running out the clock,
6. A fight that never finishes (the autopilot with nothing it can hit) counts as lost and fails its test, so each
line-up was picked from ones that finished on all eight seeds. Foes start spread out (docs: Fireball rule,
tests/unit/test_fight_spread.gd).

Where each is held:
- tests/integration/test_scaled_fights_death_house.gd, _barovia.gd, _vallaki.gd and test_side_quest_bosses.gd: the fight
  at the level and entry the story gives it.
- tests/integration/test_scaled_fights_levels.gd: the other versions of those fights, for a party that comes earlier
  or later (`when level >= n` and the lure or flag variants).
- tests/integration/test_scaled_road_fights.gd: the roads' random fights (data/random_encounters/), played on the
  table's own map; on another ground RoadGrounds lays the same foes out again.
- tests/integration/test_night_visitors.gd: the camp's night visitors.

## Other-level versions

| Fight | Where | Version | Level | Foes | Wins |
|---|---|---|---|---|---|
| `squires_vigil` | argynvostholt | L6v3 | 6 | 2 revenant, 7 phantom warrior | 5 |
| `squires_vigil` | argynvostholt | L7v2 | 7 | 2 revenant, 8 phantom warrior | 5 |
| `squires_vigil` | argynvostholt | L9v0 | 9 | 4 revenant, 11 phantom warrior | 5 |
| `pasture_wolves` | barovia_high_pasture | L2v0 | 2 | dire wolf, 5 wolf | 5 |
| `hound_tenant` | burgomaster_mansion | L1v2 | 1 | ghast, 3 ghoul | 5 |
| `mansion_siege` | burgomaster_mansion | L2v1 | 2 | dire wolf, 10 zombie, 3 strahd zombie | 4 |
| `ilarion_wolves` | into_the_mists_road | L3v0 | 3 | dire wolf, 7 wolf | 5 |
| `drowned_landing` | lake_zarovich | L7v2 | 7 | wight, 5 ghast, 8 ghoul | 5 |
| `raven_trap` | lake_zarovich_trail | L5v2 | 5 | 3 vampire spawn, 4 swarm of bats | 5 |
| `raven_trap` | lake_zarovich_trail | L5v5 | 5 | 3 vampire spawn, 2 swarm of bats | 5 |
| `raven_trap` | lake_zarovich_trail | L6v4 | 6 | 4 vampire spawn, swarm of bats | 5 |
| `raven_trap` | lake_zarovich_trail | L7v0 | 7 | 4 vampire spawn, 5 swarm of bats | 5 |
| `raven_trap` | lake_zarovich_trail | L7v3 | 7 | 4 vampire spawn, 2 swarm of bats | 5 |
| `carriage_escort` | svalich_crossroads | L3v4 | 3 | nightmare, 2 specter, 2 zombie, giant rat | 5 |
| `carriage_escort` | svalich_crossroads | L3v5 | 3 | 2 nightmare, specter, zombie | 5 |
| `carriage_escort` | svalich_crossroads | L4v3 | 4 | 2 nightmare, 2 specter, 2 zombie | 5 |
| `carriage_escort` | svalich_crossroads | L5v0 | 5 | nightmare, 2 wight, 3 specter, 2 zombie | 5 |
| `carriage_escort` | svalich_crossroads | L5v1 | 5 | 2 nightmare, wight, 3 specter, 4 zombie | 5 |
| `den_blights` | tser_woods_den | L4v0 | 4 | 4 vine blight, 5 needle blight, 3 twig blight, giant rat | 5 |
| `festival_coup` | vallaki | L3v4 | 3 | 2 tough, 5 cultist, bandit captain | 5 |
| `festival_coup` | vallaki | L3v5 | 3 | bandit captain, 9 bandit | 5 |
| `festival_coup` | vallaki | L4v1 | 4 | 2 tough, 7 cultist, bandit captain | 5 |
| `festival_coup` | vallaki | L4v3 | 4 | warrior veteran, bandit captain, 5 bandit, scout | 5 |
| `ribbons_gate` | vallaki | L4v2 | 4 | 2 warrior veteran, bandit captain, scout, giant rat | 4 |
| `ribbons_gate` | vallaki | L6v0 | 6 | 6 warrior veteran, bandit captain, scout, 2 bandit | 5 |
| `ribbons_street` | vallaki | L4v2 | 4 | 3 warrior veteran | 4 |
| `ribbons_street` | vallaki | L6v0 | 6 | 6 warrior veteran | 5 |
| `roses_graves` | vallaki | L4v2 | 4 | 2 vampire spawn, 2 ghoul | 5 |
| `roses_graves` | vallaki | L4v5 | 4 | 2 vampire spawn, giant rat, rat | 4 |
| `roses_graves` | vallaki | L5v4 | 5 | 2 vampire spawn, 8 swarm of bats | 6 |
| `roses_graves` | vallaki | L6v0 | 6 | 5 vampire spawn | 5 |
| `roses_graves` | vallaki | L6v3 | 6 | 4 vampire spawn | 5 |
| `roses_street` | vallaki | L3v3 | 3 | vampire spawn, 3 swarm of bats | 5 |
| `roses_street` | vallaki | L4v2 | 4 | 2 vampire spawn, bat, giant rat | 5 |
| `roses_street` | vallaki | L6v0 | 6 | 3 vampire spawn, swarm of rats | 5 |
| `storeroom_spawn` | vallaki_coffin_maker | L3v2 | 3 | vampire spawn, 4 ghoul | 5 |
| `storeroom_spawn` | vallaki_coffin_maker | L4v1 | 4 | vampire spawn, 3 swarm of rats | 5 |
| `church_siege` | vallaki_st_andrals | L3v2 | 3 | 2 vampire spawn, swarm of bats | 5 |
| `church_siege` | vallaki_st_andrals | L4v1 | 4 | vampire spawn, 5 swarm of bats, 2 giant rat | 6 |
| `stella_shadow` | vallaki_wachter_house | L3v3 | 3 | wraith, 2 shadow, specter | 5 |
| `stella_shadow` | vallaki_wachter_house | L4v2 | 4 | wraith, 3 shadow, 3 specter | 4 |
| `stella_shadow` | vallaki_wachter_house | L6v0 | 6 | 2 wraith, 12 shadow, 2 specter | 5 |
| `wachter_cellar_cult` | vallaki_wachter_house | L3v2 | 3 | 2 tough, 5 cultist, warrior veteran | 4 |
| `wachter_cellar_cult` | vallaki_wachter_house | L4v1 | 4 | 4 tough, 4 cultist, warrior veteran | 5 |
| `doru_undercroft` | village_church | L2v1 | 2 | vampire spawn, 3 giant rat | 5 |
| `churchyard_dead` | village_of_barovia | L2v1 | 2 | 5 strahd zombie, 2 zombie | 5 |
| `night_streets_dead` | village_of_barovia | L2v1 | 2 | 11 zombie | 5 |
| `teodor_errand` | village_of_barovia | L2v2 | 2 | vampire spawn, 4 zombie, swarm of bats, 3 ghoul | 5 |
| `well_bride` | village_of_barovia | L2v2 | 2 | banshee, shadow, 2 bat | 5 |
| `woodpile_burns` | village_of_barovia | L2v2 | 2 | 3 needle blight, 5 twig blight | 5 |
| `woodpile_burns` | village_of_barovia | L3v1 | 3 | vine blight, 5 needle blight, 5 twig blight | 5 |
| `woodpile_wakes` | village_of_barovia | L2v2 | 2 | vine blight, 3 needle blight, 3 twig blight, rat | 5 |
| `woodpile_wakes` | village_of_barovia | L4v0 | 4 | shambling mound, 2 vine blight, rat | 4 |
| `hill_watch` | yester_hill | L7v1 | 7 | 6 wight, 5 ghoul | 5 |

## Random road fights

The level is the one its region is travelled at (Svalich Road and woods 4, Bonegrinder lane and the vineyard road 6,
Krezk road 7, Argynvostholt and the lake 8, Mount Baratok and Berez 9, the Amber Temple road 10). Foes sit on the
table's own map as listed; the first four-or-so squares around the arrival spawn stay clear.

A road the story-bot playthroughs walk has to stay winnable by their weaker party too (the playthrough heroes at the
region's level, no retry: a road fight lost is the walk lost). `baratok_slopes:spiders` was 2 giant spiders and 9 werewolves
(the sharp party 5 in 8, the playthrough party two in 8 even at level 9, and `test_phase5_exit` at seeds 19 and 31 lost to it); it
is now 2 giant spiders and 4 werewolves, the sharp party 6 in 8 (the top of the band, as a playthrough road may be) and the
playthrough party at level 8 seven in 8, and the Berez, Baratok and Tsolenka walk holds at seeds 7, 11, 19 and 31. The same easing, one table at a time until the
sharp party sat at 5 or 6 and the playthrough party at 6 or more, was done for the other tables those walks can meet:
Baratok `dire_wolves` and `ogres` and the vineyard road's `hedgerow_blights` and `druid_patrol` (a road's sharp-party band
stays 4 to 6; the playthrough party scores are measured on `test_zz`-style runs of ilse_varga, tamsin_tealeaf, hedda_ironvow
and silvain_aster at the playthrough's own level).

| Table | Entry | Level | Was | Now | Wins |
|---|---|---|---|---|---|
| amber_temple_road | `cliff_gargoyles` | 10 | 5 gargoyle | 13 gargoyle | 5 |
| amber_temple_road | `frozen_climbers` | 10 | 3 wight, 2 wraith | 4 wight, 2 wraith | 5 |
| argynvostholt_road | `dire_wolves_day` | 8 | 6 dire wolf | 6 dire wolf, 5 werewolf | 6 |
| argynvostholt_road | `the_conquerors_dead` | 8 | 6 strahd zombie, 2 ghast | 8 ghast, 4 wight, ghoul | 4 |
| argynvostholt_road | `werewolf_hunters` | 8 | 2 werewolf, 3 dire wolf | 5 werewolf, 6 dire wolf | 5 |
| baratok_slopes | `dire_wolves` | 9 | 4 dire wolf, 2 wolf | 6 dire wolf, 4 werewolf | 6 |
| baratok_slopes | `ogres` | 9 | 3 ogre | 2 ogre, 5 werewolf | 6 |
| baratok_slopes | `spiders` | 9 | 4 giant spider | 2 giant spider, 4 werewolf | 6 |
| baratok_slopes | `werewolves_ridge` | 9 | 3 werewolf, dire wolf | 5 werewolf, 3 dire wolf | 5 |
| berez_marsh | `insect_cloud` | 9 | 4 swarm of insects, 3 scarecrow | 6 scarecrow, 6 will o wisp, 4 banshee | 5 |
| berez_marsh | `marsh_lights` | 9 | 3 will o wisp, 2 swarm of insects | 7 will o wisp, 5 swarm of insects | 5 |
| berez_marsh | `scarecrow_walk` | 9 | 5 scarecrow, will o wisp | 8 will o wisp, 5 banshee | 4 |
| bonegrinder_lane | `lane_bats` | 6 | 4 swarm of bats, 3 strahd zombie | 9 strahd zombie, 7 ghast | 6 |
| bonegrinder_lane | `lane_dead` | 6 | 5 strahd zombie, 2 zombie | 9 ghast, 6 strahd zombie | 6 |
| bonegrinder_lane | `lane_wolves` | 6 | 3 dire wolf, 3 wolf | 9 dire wolf, 2 werewolf | 4 |
| bonegrinder_lane | `lane_wolves_night` | 6 | werewolf, 2 dire wolf, 2 wolf | 3 werewolf, 4 dire wolf, 4 wolf | 5 |
| krezk_road | `krezk_road_blights` | 7 | 2 druid, 2 needle blight, 4 twig blight | 4 druid, 3 vine blight, 6 needle blight | 5 |
| krezk_road | `krezk_road_dead` | 7 | 5 strahd zombie, 2 ghoul | 14 ghast | 6 |
| krezk_road | `krezk_road_werewolves` | 7 | 3 werewolf, 2 wolf | 4 werewolf, 2 wolf | 4 |
| krezk_road | `krezk_road_wolves` | 7 | 3 dire wolf, 3 wolf | 8 dire wolf, 3 werewolf | 5 |
| svalich_road | `bats_and_dead` | 4 | 3 swarm of bats, 4 strahd zombie, zombie | 3 swarm of bats, 8 strahd zombie | 5 |
| svalich_road | `dead_on_the_road` | 4 | 5 strahd zombie, 2 zombie | 11 strahd zombie | 6 |
| svalich_road | `strahds_wolves` | 4 | 4 dire wolf, 4 wolf | 4 dire wolf, 3 wolf, rat | 4 |
| svalich_road | `werewolf_night` | 4 | werewolf, dire wolf, 2 wolf | werewolf, dire wolf, 2 wolf | 4 |
| svalich_road | `wolf_pack_night` | 4 | 4 dire wolf, 4 wolf | 4 dire wolf, 3 wolf, rat | 4 |
| svalich_road | `wolves_shadowing` | 4 | 3 dire wolf, 2 wolf | 4 dire wolf, 3 wolf | 5 |
| svalich_woods | `bats_and_wolves` | 4 | 4 swarm of bats, 4 dire wolf | 4 swarm of bats, 3 dire wolf, wolf | 5 |
| svalich_woods | `dead_in_the_trees` | 4 | 5 strahd zombie, 2 zombie | 8 strahd zombie, 5 zombie | 5 |
| svalich_woods | `strahds_wolves` | 4 | 4 dire wolf, 4 wolf | 4 dire wolf, 4 wolf, rat | 5 |
| svalich_woods | `werewolves` | 4 | werewolf, dire wolf, 2 wolf | werewolf, 2 dire wolf, 2 wolf | 5 |
| svalich_woods | `wolf_pack_night` | 4 | 4 dire wolf, 4 wolf | 4 dire wolf, 4 wolf, rat | 5 |
| svalich_woods | `wolves_in_the_pines` | 4 | 3 dire wolf, 2 wolf | 5 dire wolf, 3 wolf | 6 |
| vineyard_road | `druid_patrol` | 6 | 2 druid, 3 needle blight, vine blight | 6 druid, 4 vine blight | 5 |
| vineyard_road | `druids_return` | 6 | 3 druid, 2 vine blight, 4 twig blight | 5 druid, 3 vine blight, 6 needle blight | 5 |
| vineyard_road | `hedgerow_blights` | 6 | 2 vine blight, 4 needle blight, 6 twig blight | 2 druid, 4 vine blight, 3 needle blight, werewolf | 6 |
| vineyard_road | `strahds_wolves` | 6 | 2 dire wolf, 4 wolf | 8 dire wolf, 3 werewolf | 6 |
| vineyard_road | `wolves_on_the_moor` | 6 | 2 dire wolf, 4 wolf | 8 dire wolf, 3 werewolf | 6 |
| zarovich_hills | `dire_wolves` | 8 | werewolf, 5 dire wolf | 5 werewolf, 9 dire wolf | 5 |
| zarovich_hills | `hill_ghouls` | 8 | 4 ghoul, 2 ghast | 9 ghast, 2 wight | 5 |
| zarovich_hills | `pack_hunt` | 8 | 3 werewolf, 3 wolf | 4 werewolf, 3 wolf | 5 |
| zarovich_shore | `marsh_lights` | 8 | 3 will o wisp | 8 will o wisp, 3 banshee | 5 |
| zarovich_shore | `shore_wolves` | 8 | 4 dire wolf | 6 dire wolf, 5 werewolf | 5 |
| zarovich_shore | `the_drowned` | 8 | 4 strahd zombie, 2 ghast | 9 ghast, 2 wight | 5 |

## Fights that had no series test (Argynvostholt, Tsolenka, the Abbey, Krezk, the Amber Temple, Berez, Van Richten's tower, the den guards)

| Fight | Where | Version | Level | Was | Now | Wins |
|---|---|---|---|---|---|---|
| `garden_sentry` | abbey_of_st_markovia_garden | L7v0 | 7 | 5 scarecrow | 4 scarecrow, 11 will o wisp (18 HP) | 5 |
| `bride_defends` | abbey_of_st_markovia_shrine | L5v2 | 5 | flesh golem, 3 mongrelfolk | 4 flesh golem, 6 mongrelfolk | 5 |
| `bride_defends` | abbey_of_st_markovia_shrine | L6v1 | 6 | flesh golem, berserker, 4 mongrelfolk | 3 flesh golem, 8 berserker, mongrelfolk | 5 |
| `wards_cells` | abbey_of_st_markovia_wards | L6v1 | 6 | berserker, 4 mongrelfolk | 15 berserker, mongrelfolk | 5 |
| `wards_cells` | abbey_of_st_markovia_wards | L7v0 | 7 | 2 berserker, 6 mongrelfolk | 11 berserker, 16 mongrelfolk | 5 |
| `frozen_watch` | amber_temple_entrance | L10v0 | 10 | 4 wight | 5 wight, 4 wraith | 4 |
| `frozen_watch` | amber_temple_entrance | L9v1 | 9 | 3 wight | 3 wight, 4 wraith | 5 |
| `hollow_eyed` | amber_temple_faceless_god | L10v0 | 10 | 5 nothic, 3 wraith | 6 nothic, 4 wraith | 4 |
| `hollow_eyed` | amber_temple_faceless_god | L7v2 | 7 | 4 nothic, wraith | 5 nothic, 2 wraith | 5 |
| `hollow_eyed` | amber_temple_faceless_god | L8v1 | 8 | 4 nothic, 3 wraith | 5 nothic, 3 wraith | 5 |
| `patrina_wails` | amber_temple_faceless_god | L10v0 | 10 | banshee, 4 specter | 8 banshee, 11 specter | 5 |
| `courtyard_phantoms` | argynvostholt | L6v2 | 6 | 2 phantom warrior | 14 phantom warrior | 6 |
| `courtyard_phantoms` | argynvostholt | L7v1 | 7 | 3 phantom warrior | 14 phantom warrior | 5 |
| `courtyard_phantoms` | argynvostholt | L8v0 | 8 | 4 phantom warrior | 12 phantom warrior, 2 revenant | 5 |
| `lamp_dark` | argynvostholt_beacon | L6v2 | 6 | wraith, 2 specter | 4 wraith, 6 specter | 5 |
| `lamp_dark` | argynvostholt_beacon | L7v1 | 7 | wraith, 3 specter | 3 wraith, 5 specter | 6 |
| `lamp_dark` | argynvostholt_beacon | L8v0 | 8 | 2 wraith, 2 specter | 5 wraith, 4 specter | 5 |
| `bone_watch` | argynvostholt_mausoleum | L6v2 | 6 | 2 phantom warrior | 11 phantom warrior | 6 |
| `bone_watch` | argynvostholt_mausoleum | L7v1 | 7 | 3 phantom warrior | 12 phantom warrior | 5 |
| `bone_watch` | argynvostholt_mausoleum | L8v0 | 8 | 4 phantom warrior | 15 phantom warrior | 5 |
| `berez_drowned_lights` | berez | L7v1 | 7 | 2 will o wisp, swarm of insects | 9 will o wisp, 7 swarm of insects | 5 |
| `berez_drowned_lights` | berez | L8v0 | 8 | 3 will o wisp, 2 swarm of insects | 6 will o wisp, 5 swarm of insects | 6 |
| `berez_scarecrows` | berez | L7v2 | 7 | 4 scarecrow, 2 swarm of insects | 10 scarecrow, 12 swarm of insects, 4 will o wisp | 6 |
| `berez_scarecrows` | berez | L8v1 | 8 | 5 scarecrow, will o wisp, 2 swarm of insects | 12 scarecrow, 7 will o wisp, 8 swarm of insects | 4 |
| `berez_scarecrows` | berez | L9v0 | 9 | 6 scarecrow, 2 will o wisp, 2 swarm of insects | 12 scarecrow (35 HP), 7 will o wisp (35 HP), 7 swarm of insects (25 HP) | 6 |
| `gate_wolves` | krezk | L6v1 | 6 | werewolf, 2 dire wolf, wolf | 4 werewolf, 5 dire wolf, 4 wolf | 4 |
| `gate_wolves` | krezk | L7v0 | 7 | werewolf, 3 dire wolf, 2 wolf | 4 werewolf, 6 dire wolf, 5 wolf | 4 |
| `sorin_pursuers` | krezk_pool_of_the_white_sun | L6v2 | 6 | flesh golem, 2 berserker, 4 mongrelfolk | 2 flesh golem, 4 berserker, 6 mongrelfolk | 6 |
| `sorin_pursuers` | krezk_pool_of_the_white_sun | L7v1 | 7 | 2 flesh golem, 3 berserker, 4 mongrelfolk | 3 flesh golem, 3 berserker, 4 mongrelfolk | 4 |
| `sorin_pursuers` | krezk_pool_of_the_white_sun | L8v0 | 8 | 3 flesh golem, 3 berserker, 4 mongrelfolk | 4 flesh golem, 3 berserker, 4 mongrelfolk | 6 |
| `tsolenka_watch` | tsolenka_pass_guard_tower | L7v1 | 7 | 4 phantom warrior | 11 phantom warrior | 4 |
| `tsolenka_watch` | tsolenka_pass_guard_tower | L8v0 | 8 | 5 phantom warrior | 15 phantom warrior | 5 |
| `tsolenka_vrocks` | tsolenka_pass | L7v3 | 7 | 2 vrock (152 HP each) | 2 vrock at 200 HP | 5 |
| `tsolenka_vrocks` | tsolenka_pass | L8v2 | 8 | 2 vrock (152 HP each) | 2 vrock at 280 HP | 5 |
| `tsolenka_vrocks` | tsolenka_pass | L9v1 | 9 | 2 vrock (152 HP each) | 2 vrock at 380 HP | 5 |
| `tsolenka_vrocks` | tsolenka_pass | L10v0 | 10 | 2 vrock (152 HP each) | 2 vrock at 420 HP | 5 |
| `tower_night_visitors` | van_richtens_tower | L6v2 | 6 | vampire spawn, 2 swarm of bats | 4 vampire spawn, 6 swarm of bats | 4 |
| `tower_night_visitors` | van_richtens_tower | L7v1 | 7 | 2 vampire spawn, 2 swarm of bats | 4 vampire spawn, 4 swarm of bats | 5 |
| `tower_night_visitors` | van_richtens_tower | L8v0 | 8 | 2 vampire spawn, wight, 2 swarm of bats | 3 vampire spawn, wight, 3 swarm of bats | 6 |
| `den_guards` | werewolf_den_caves | L6v2 | 6 | 3 werewolf, dire wolf | 5 werewolf, 3 dire wolf | 5 |
| `den_guards` | werewolf_den_caves | L7v1 | 7 | 4 werewolf, 2 dire wolf | 5 werewolf, 3 dire wolf | 5 |
| `den_guards` | werewolf_den_caves | L8v0 | 8 | 5 werewolf, 2 dire wolf | 7 werewolf, 3 dire wolf | 4 |

## The tower's ward (Dungeon Expansion Plan V1)

`ward_wolves` is new: the lightning ward on Van Richten's door goes off and werewolves come down off the ridge
(trap `vrt_door_ward_1`, flag `tower_ward_1`). The test party stands where the ward's step leaves it (the leader on the west
leaf's front square, the others in a line behind) and the foes start spread over the island's ring
(tests/integration/test_scaled_fights_regions.gd; tests/unit/test_fight_spread.gd). The door's front is inside the tower's
antimagic ring, so the leader fights in an Antimagic Field and casts nothing; the line-ups below were measured with the ring in
the fight. Before the ring went in, 3, 4 and 5 werewolves won 8 of 8 at levels 6, 7 and 8, and 5, 5 and 6 of them came down to the
band; with it, five werewolves at their stat block's 71 Hit Points won 2 of 8 at level 6, and 6 won 3 at level 8. Hit Points are tuned
in single points (the 8 seeds move a lot): 62 and 63 won 5 of 8, 60 won 6, 65 and 68 won 3.

| Fight | Where | Version | Level | Was | Now | Wins |
|---|---|---|---|---|---|---|
| `ward_wolves` | van_richtens_tower | L6v2 | 6 | new | 5 werewolf, 62 HP each | 5 |
| `ward_wolves` | van_richtens_tower | L7v1 | 7 | new | 5 werewolf, 78 HP each | 5 |
| `ward_wolves` | van_richtens_tower | L8v0 | 8 | new | 5 werewolf, 82 HP each | 5 |
