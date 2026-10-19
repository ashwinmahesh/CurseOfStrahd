extends FightSeriesCase
## The other-level versions of the story's fights scaled for 2024 heroes and the sharp test party (owner, 2026-10-13
## 18:05: 5 in 8 on Balanced for every fight at every level). The same fights at the level they are tuned for are held in
## test_scaled_fights_barovia.gd, _vallaki.gd and _death_house.gd and test_side_quest_bosses.gd; this holds the versions
## a party meets when it comes earlier or later, as each plays from where walking in or talking sets it off. Over seeds
## 1-8 the four pregens on the sharp autopilot win 5, give or take one, and every fight finishes.

const SEEDS: Array = [1, 2, 3, 4, 5, 6, 7, 8]


func before_each() -> void:
	speakers_step_aside = true


## Wins over seeds 1-8 between `low` and `high`.
func _held(location: String, hour: int, level: int, encounter: String, at: Array[Vector2i], low: int, high: int,
		flags: Array[String] = [], guests: Array[String] = [], doors: Array[String] = []) -> void:
	var wins := await _series(location, hour, level, encounter, SEEDS, flags, guests, doors, at)
	assert_true(wins >= low, "%s at level %d is won at least %d times in 8 (%d)" % [encounter, level, low, wins])
	assert_true(wins <= high, "%s at level %d is lost at least %d times in 8 (%d)" % [encounter, level, 8 - high, wins])


## squires_vigil, argynvostholt variant 0 at level 9 (godfrey_met, courtyard_phantoms_defeated).
func test_squires_vigil_v0_at_level_9() -> void:
	await _held("argynvostholt", 2, 9, "squires_vigil", [Vector2i(20, 29), Vector2i(21, 29), Vector2i(19, 29), Vector2i(20, 30)], 4, 6, ["godfrey_met", "courtyard_phantoms_defeated"])


## squires_vigil, argynvostholt variant 2 at level 7 (godfrey_met, courtyard_phantoms_defeated).
func test_squires_vigil_v2_at_level_7() -> void:
	await _held("argynvostholt", 2, 7, "squires_vigil", [Vector2i(20, 29), Vector2i(21, 29), Vector2i(19, 29), Vector2i(20, 30)], 4, 6, ["godfrey_met", "courtyard_phantoms_defeated"])


## squires_vigil, argynvostholt variant 3 at level 6 (godfrey_met, courtyard_phantoms_defeated).
func test_squires_vigil_v3_at_level_6() -> void:
	await _held("argynvostholt", 2, 6, "squires_vigil", [Vector2i(20, 29), Vector2i(21, 29), Vector2i(19, 29), Vector2i(20, 30)], 4, 6, ["godfrey_met", "courtyard_phantoms_defeated"])


## pasture_wolves, barovia_high_pasture variant 0 at level 2 (pasture_erno_met).
func test_pasture_wolves_v0_at_level_2() -> void:
	await _held("barovia_high_pasture", 18, 2, "pasture_wolves", [Vector2i(10, 12), Vector2i(11, 12), Vector2i(9, 12), Vector2i(12, 12)], 4, 6, ["pasture_erno_met"])


## hound_tenant, burgomaster_mansion variant 2 at level 1.
func test_hound_tenant_v2_at_level_1() -> void:
	await _held("burgomaster_mansion", 22, 1, "hound_tenant", [Vector2i(12, 14), Vector2i(13, 14), Vector2i(11, 14), Vector2i(12, 15)], 4, 7, [], ["lupu"], ["study_door"])


## mansion_siege, burgomaster_mansion variant 1 at level 2.
func test_mansion_siege_v1_at_level_2() -> void:
	await _held("burgomaster_mansion", 12, 2, "mansion_siege", [Vector2i(4, 12), Vector2i(5, 11), Vector2i(6, 11), Vector2i(7, 11)], 4, 6, [])


## ilarion_wolves, into_the_mists_road variant 0 at level 3 (mists_wolves_resolved).
func test_ilarion_wolves_v0_at_level_3() -> void:
	await _held("into_the_mists_road", 9, 3, "ilarion_wolves", [Vector2i(30, 15), Vector2i(31, 15), Vector2i(29, 15), Vector2i(30, 16)], 4, 6, ["mists_wolves_resolved"])


## ilarion_wolves, into_the_mists_road variant 1 at level 2 (mists_wolves_resolved).
func test_ilarion_wolves_v1_at_level_2() -> void:
	await _held("into_the_mists_road", 9, 2, "ilarion_wolves", [Vector2i(30, 15), Vector2i(31, 15), Vector2i(29, 15), Vector2i(30, 16)], 4, 6, ["mists_wolves_resolved"])


## drowned_landing, lake_zarovich variant 0 at level 9.
func test_drowned_landing_v0_at_level_9() -> void:
	await _held("lake_zarovich", 23, 9, "drowned_landing", [Vector2i(17, 21), Vector2i(18, 21), Vector2i(16, 21), Vector2i(17, 22)], 2, 6, [])


## drowned_landing, lake_zarovich variant 2 at level 7.
func test_drowned_landing_v2_at_level_7() -> void:
	await _held("lake_zarovich", 23, 7, "drowned_landing", [Vector2i(17, 21), Vector2i(18, 21), Vector2i(16, 21), Vector2i(17, 22)], 4, 6, [])


## raven_trap, lake_zarovich_trail variant 0 at level 7 (fowlers_ready).
func test_raven_trap_v0_at_level_7() -> void:
	await _held("lake_zarovich_trail", 22, 7, "raven_trap", [Vector2i(3, 10), Vector2i(4, 10), Vector2i(2, 10), Vector2i(3, 11)], 3, 6, ["fowlers_ready"])


## raven_trap, lake_zarovich_trail variant 2 at level 5 (fowlers_ready).
func test_raven_trap_v2_at_level_5() -> void:
	await _held("lake_zarovich_trail", 22, 5, "raven_trap", [Vector2i(3, 10), Vector2i(4, 10), Vector2i(2, 10), Vector2i(3, 11)], 4, 7, ["fowlers_ready"])


## raven_trap, lake_zarovich_trail variant 3 at level 7.
func test_raven_trap_v3_at_level_7() -> void:
	await _held("lake_zarovich_trail", 22, 7, "raven_trap", [Vector2i(3, 10), Vector2i(4, 10), Vector2i(2, 10), Vector2i(3, 11)], 4, 6, [])


## raven_trap, lake_zarovich_trail variant 4 at level 6.
func test_raven_trap_v4_at_level_6() -> void:
	await _held("lake_zarovich_trail", 22, 6, "raven_trap", [Vector2i(3, 10), Vector2i(4, 10), Vector2i(2, 10), Vector2i(3, 11)], 3, 6, [])


## raven_trap, lake_zarovich_trail variant 5 at level 5.
func test_raven_trap_v5_at_level_5() -> void:
	await _held("lake_zarovich_trail", 22, 5, "raven_trap", [Vector2i(3, 10), Vector2i(4, 10), Vector2i(2, 10), Vector2i(3, 11)], 3, 6, [])


## carriage_escort, svalich_crossroads variant 0 at level 5 (mare_saved, carriage_came).
func test_carriage_escort_v0_at_level_5() -> void:
	await _held("svalich_crossroads", 0, 5, "carriage_escort", [Vector2i(31, 11), Vector2i(32, 11), Vector2i(30, 11), Vector2i(31, 12)], 3, 6, ["mare_saved", "carriage_came"])


## carriage_escort, svalich_crossroads variant 1 at level 5 (carriage_came).
func test_carriage_escort_v1_at_level_5() -> void:
	await _held("svalich_crossroads", 0, 5, "carriage_escort", [Vector2i(31, 11), Vector2i(32, 11), Vector2i(30, 11), Vector2i(31, 12)], 4, 6, ["carriage_came"])


## carriage_escort, svalich_crossroads variant 3 at level 4 (carriage_came).
func test_carriage_escort_v3_at_level_4() -> void:
	await _held("svalich_crossroads", 0, 4, "carriage_escort", [Vector2i(31, 11), Vector2i(32, 11), Vector2i(30, 11), Vector2i(31, 12)], 2, 6, ["carriage_came"])


## carriage_escort, svalich_crossroads variant 4 at level 3 (mare_saved, carriage_came).
func test_carriage_escort_v4_at_level_3() -> void:
	await _held("svalich_crossroads", 0, 3, "carriage_escort", [Vector2i(31, 11), Vector2i(32, 11), Vector2i(30, 11), Vector2i(31, 12)], 4, 6, ["mare_saved", "carriage_came"])


## carriage_escort, svalich_crossroads variant 5 at level 3 (carriage_came).
func test_carriage_escort_v5_at_level_3() -> void:
	await _held("svalich_crossroads", 0, 3, "carriage_escort", [Vector2i(31, 11), Vector2i(32, 11), Vector2i(30, 11), Vector2i(31, 12)], 3, 6, ["carriage_came"])


## den_blights, tser_woods_den variant 0 at level 4 (bear_path_known).
func test_den_blights_v0_at_level_4() -> void:
	await _held("tser_woods_den", 14, 4, "den_blights", [Vector2i(12, 12), Vector2i(13, 13), Vector2i(11, 12), Vector2i(12, 13)], 4, 6, ["bear_path_known"])


## festival_coup, vallaki variant 1 at level 4.
func test_festival_coup_v1_at_level_4() -> void:
	await _held("vallaki", 12, 4, "festival_coup", [Vector2i(20, 14), Vector2i(21, 15), Vector2i(22, 16), Vector2i(23, 17)], 4, 6, [])


## festival_coup, vallaki variant 3 at level 4 (wachter_cult_broken).
func test_festival_coup_v3_at_level_4() -> void:
	await _held("vallaki", 12, 4, "festival_coup", [Vector2i(31, 15), Vector2i(30, 16), Vector2i(29, 16), Vector2i(28, 17)], 3, 6, ["wachter_cult_broken"])


## festival_coup, vallaki variant 4 at level 3.
func test_festival_coup_v4_at_level_3() -> void:
	await _held("vallaki", 12, 3, "festival_coup", [Vector2i(20, 14), Vector2i(21, 15), Vector2i(22, 16), Vector2i(23, 17)], 2, 6, [])


## festival_coup, vallaki variant 5 at level 3 (wachter_cult_broken).
func test_festival_coup_v5_at_level_3() -> void:
	await _held("vallaki", 12, 3, "festival_coup", [Vector2i(31, 15), Vector2i(30, 16), Vector2i(29, 16), Vector2i(28, 17)], 4, 6, ["wachter_cult_broken"])


## ribbons_gate, vallaki variant 0 at level 6 (ribbons_list_known).
func test_ribbons_gate_v0_at_level_6() -> void:
	await _held("vallaki", 21, 6, "ribbons_gate", [Vector2i(22, 20), Vector2i(23, 21), Vector2i(24, 21), Vector2i(23, 20)], 4, 6, ["ribbons_list_known"])


## ribbons_gate, vallaki variant 2 at level 4 (ribbons_list_known).
func test_ribbons_gate_v2_at_level_4() -> void:
	await _held("vallaki", 21, 4, "ribbons_gate", [Vector2i(22, 20), Vector2i(23, 21), Vector2i(24, 21), Vector2i(23, 20)], 2, 6, ["ribbons_list_known"])


## ribbons_street, vallaki variant 0 at level 6 (ribbons_list_known).
func test_ribbons_street_v0_at_level_6() -> void:
	await _held("vallaki", 21, 6, "ribbons_street", [Vector2i(23, 21), Vector2i(24, 21), Vector2i(23, 20), Vector2i(23, 22)], 4, 7, ["ribbons_list_known"])


## ribbons_street, vallaki variant 2 at level 4 (ribbons_list_known).
func test_ribbons_street_v2_at_level_4() -> void:
	await _held("vallaki", 21, 4, "ribbons_street", [Vector2i(23, 21), Vector2i(24, 21), Vector2i(23, 20), Vector2i(23, 22)], 4, 6, ["ribbons_list_known"])


## roses_graves, vallaki variant 0 at level 6 (ana_grave_known).
func test_roses_graves_v0_at_level_6() -> void:
	await _held("vallaki", 11, 6, "roses_graves", [Vector2i(45, 8), Vector2i(45, 9), Vector2i(44, 9), Vector2i(43, 9)], 4, 7, ["ana_grave_known"])


## roses_graves, vallaki variant 2 at level 4 (ana_grave_known).
func test_roses_graves_v2_at_level_4() -> void:
	await _held("vallaki", 11, 4, "roses_graves", [Vector2i(45, 8), Vector2i(45, 9), Vector2i(44, 9), Vector2i(43, 9)], 4, 6, ["ana_grave_known"])


## roses_graves, vallaki variant 3 at level 6 (ana_grave_known).
func test_roses_graves_v3_at_level_6() -> void:
	await _held("vallaki", 23, 6, "roses_graves", [Vector2i(45, 8), Vector2i(45, 9), Vector2i(44, 9), Vector2i(43, 9)], 4, 7, ["ana_grave_known"])


## roses_graves, vallaki variant 4 at level 5 (ana_grave_known).
func test_roses_graves_v4_at_level_5() -> void:
	await _held("vallaki", 23, 5, "roses_graves", [Vector2i(45, 8), Vector2i(45, 9), Vector2i(44, 9), Vector2i(43, 9)], 4, 6, ["ana_grave_known"])


## roses_graves, vallaki variant 5 at level 4 (ana_grave_known).
func test_roses_graves_v5_at_level_4() -> void:
	await _held("vallaki", 23, 4, "roses_graves", [Vector2i(45, 8), Vector2i(45, 9), Vector2i(44, 9), Vector2i(43, 9)], 4, 6, ["ana_grave_known"])


## roses_street, vallaki variant 0 at level 6 (roses_vigil, ana_met).
func test_roses_street_v0_at_level_6() -> void:
	await _held("vallaki", 22, 6, "roses_street", [Vector2i(12, 28), Vector2i(13, 27), Vector2i(14, 26), Vector2i(15, 25)], 4, 8, ["roses_vigil", "ana_met"])


## roses_street, vallaki variant 2 at level 4 (roses_vigil, ana_met).
func test_roses_street_v2_at_level_4() -> void:
	await _held("vallaki", 22, 4, "roses_street", [Vector2i(12, 28), Vector2i(13, 27), Vector2i(14, 26), Vector2i(15, 25)], 4, 6, ["roses_vigil", "ana_met"])


## roses_street, vallaki variant 3 at level 3 (roses_vigil, ana_met).
func test_roses_street_v3_at_level_3() -> void:
	await _held("vallaki", 22, 3, "roses_street", [Vector2i(12, 28), Vector2i(13, 27), Vector2i(14, 26), Vector2i(15, 25)], 4, 6, ["roses_vigil", "ana_met"])


## storeroom_spawn, vallaki_coffin_maker variant 1 at level 4.
func test_storeroom_spawn_v1_at_level_4() -> void:
	await _held("vallaki_coffin_maker", 12, 4, "storeroom_spawn", [Vector2i(13, 10), Vector2i(12, 10), Vector2i(11, 10), Vector2i(10, 10)], 4, 7, [])


## storeroom_spawn, vallaki_coffin_maker variant 2 at level 3.
func test_storeroom_spawn_v2_at_level_3() -> void:
	await _held("vallaki_coffin_maker", 12, 3, "storeroom_spawn", [Vector2i(13, 10), Vector2i(12, 10), Vector2i(11, 10), Vector2i(10, 10)], 4, 6, [])


## church_siege, vallaki_st_andrals variant 1 at level 4.
func test_church_siege_v1_at_level_4() -> void:
	await _held("vallaki_st_andrals", 23, 4, "church_siege", [Vector2i(11, 4), Vector2i(11, 5), Vector2i(11, 6), Vector2i(11, 7)], 3, 6, [])


## church_siege, vallaki_st_andrals variant 2 at level 3.
func test_church_siege_v2_at_level_3() -> void:
	await _held("vallaki_st_andrals", 23, 3, "church_siege", [Vector2i(11, 4), Vector2i(11, 5), Vector2i(11, 6), Vector2i(11, 7)], 3, 6, [])


## stella_shadow, vallaki_wachter_house variant 0 at level 6 (stella_bound_known, stella_met).
func test_stella_shadow_v0_at_level_6() -> void:
	await _held("vallaki_wachter_house", 14, 6, "stella_shadow", [Vector2i(19, 11), Vector2i(20, 11), Vector2i(18, 11), Vector2i(19, 12)], 4, 6, ["stella_bound_known", "stella_met"])


## stella_shadow, vallaki_wachter_house variant 2 at level 4 (stella_bound_known, stella_met).
func test_stella_shadow_v2_at_level_4() -> void:
	await _held("vallaki_wachter_house", 14, 4, "stella_shadow", [Vector2i(19, 11), Vector2i(20, 11), Vector2i(18, 11), Vector2i(19, 12)], 4, 6, ["stella_bound_known", "stella_met"])


## stella_shadow, vallaki_wachter_house variant 3 at level 3 (stella_bound_known, stella_met).
func test_stella_shadow_v3_at_level_3() -> void:
	await _held("vallaki_wachter_house", 14, 3, "stella_shadow", [Vector2i(19, 11), Vector2i(20, 11), Vector2i(18, 11), Vector2i(19, 12)], 4, 7, ["stella_bound_known", "stella_met"])


## wachter_cellar_cult, vallaki_wachter_house variant 1 at level 4 (vallaki_pledg).
func test_wachter_cellar_cult_v1_at_level_4() -> void:
	await _held("vallaki_wachter_house", 23, 4, "wachter_cellar_cult", [Vector2i(7, 15), Vector2i(8, 15), Vector2i(7, 16), Vector2i(9, 15)], 4, 6, ["vallaki_pledg"])


## wachter_cellar_cult, vallaki_wachter_house variant 2 at level 3 (vallaki_pledg).
func test_wachter_cellar_cult_v2_at_level_3() -> void:
	await _held("vallaki_wachter_house", 23, 3, "wachter_cellar_cult", [Vector2i(7, 15), Vector2i(8, 15), Vector2i(7, 16), Vector2i(9, 15)], 4, 6, ["vallaki_pledg"])


## doru_undercroft, village_church variant 1 at level 2.
func test_doru_undercroft_v1_at_level_2() -> void:
	await _held("village_church", 12, 2, "doru_undercroft", [Vector2i(17, 23), Vector2i(18, 23), Vector2i(16, 23), Vector2i(17, 24)], 2, 6, [])


## churchyard_dead, village_of_barovia variant 1 at level 2.
func test_churchyard_dead_v1_at_level_2() -> void:
	await _held("village_of_barovia", 12, 2, "churchyard_dead", [Vector2i(31, 6), Vector2i(32, 6), Vector2i(30, 6), Vector2i(31, 7)], 4, 8, [])


## night_streets_dead, village_of_barovia variant 1 at level 2 (ismark_met).
func test_night_streets_dead_v1_at_level_2() -> void:
	await _held("village_of_barovia", 23, 2, "night_streets_dead", [Vector2i(20, 12), Vector2i(21, 12), Vector2i(19, 12), Vector2i(20, 13)], 4, 6, ["ismark_met"])


## teodor_errand, village_of_barovia variant 2 at level 2 (teodor_vigil, teodor_met).
func test_teodor_errand_v2_at_level_2() -> void:
	await _held("village_of_barovia", 22, 2, "teodor_errand", [Vector2i(31, 11), Vector2i(32, 11), Vector2i(30, 11), Vector2i(31, 12)], 4, 6, ["teodor_vigil", "teodor_met"], ["teodor"], [])


## well_bride, village_of_barovia variant 2 at level 2 (bride_bones_raised).
func test_well_bride_v2_at_level_2() -> void:
	await _held("village_of_barovia", 16, 2, "well_bride", [Vector2i(22, 14), Vector2i(23, 14), Vector2i(22, 15), Vector2i(24, 14)], 4, 6, ["bride_bones_raised"])


## woodpile_burns, village_of_barovia variant 1 at level 3 (seedwood_known, bildrath_wood_taken).
func test_woodpile_burns_v1_at_level_3() -> void:
	await _held("village_of_barovia", 11, 3, "woodpile_burns", [Vector2i(9, 12), Vector2i(10, 12), Vector2i(8, 12), Vector2i(9, 13)], 3, 6, ["seedwood_known", "bildrath_wood_taken"])


## woodpile_burns, village_of_barovia variant 2 at level 2 (seedwood_known, bildrath_wood_taken).
func test_woodpile_burns_v2_at_level_2() -> void:
	await _held("village_of_barovia", 11, 2, "woodpile_burns", [Vector2i(9, 12), Vector2i(10, 12), Vector2i(8, 12), Vector2i(9, 13)], 4, 7, ["seedwood_known", "bildrath_wood_taken"])


## woodpile_wakes, village_of_barovia variant 0 at level 4 (seedwood_known).
func test_woodpile_wakes_v0_at_level_4() -> void:
	await _held("village_of_barovia", 19, 4, "woodpile_wakes", [Vector2i(9, 12), Vector2i(10, 12), Vector2i(8, 12), Vector2i(9, 13)], 3, 6, ["seedwood_known"])


## woodpile_wakes, village_of_barovia variant 2 at level 2 (seedwood_known).
func test_woodpile_wakes_v2_at_level_2() -> void:
	await _held("village_of_barovia", 19, 2, "woodpile_wakes", [Vector2i(9, 12), Vector2i(10, 12), Vector2i(8, 12), Vector2i(9, 13)], 4, 6, ["seedwood_known"])


## hill_watch, yester_hill variant 1 at level 7 (yester_hill_resolved, barrow_watch_known).
func test_hill_watch_v1_at_level_7() -> void:
	await _held("yester_hill", 22, 7, "hill_watch", [Vector2i(28, 16), Vector2i(29, 16), Vector2i(27, 17), Vector2i(28, 17)], 4, 6, ["yester_hill_resolved", "barrow_watch_known"])
