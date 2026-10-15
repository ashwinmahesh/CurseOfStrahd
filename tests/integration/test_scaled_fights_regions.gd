extends FightSeriesCase
## The fights of Argynvostholt, Tsolenka, the Abbey, Krezk, the Amber Temple, Berez, Van Richten's tower and the werewolf den that had no series, scaled for 2024 heroes and the sharp test party.
## Over seeds 1-8 the four pregens on the sharp autopilot (smiting, opening with Spirit Guardians, throwing Fireball, as he
## plays) win 5, give or take one, on Balanced (owner, 2026-10-13 18:05), each fight played from where walking in or
## talking sets it off, with its foes starting spread out (tests/unit/test_fight_spread.gd). Every fight finishes.

const SEEDS: Array = [1, 2, 3, 4, 5, 6, 7, 8]


func before_each() -> void:
	speakers_step_aside = true


## Wins over seeds 1-8 between `low` and `high`.
func _held(location: String, hour: int, level: int, encounter: String, at: Array[Vector2i], low: int, high: int,
		flags: Array[String] = [], guests: Array[String] = [], doors: Array[String] = []) -> void:
	var wins := await _series(location, hour, level, encounter, SEEDS, flags, guests, doors, at)
	assert_true(wins >= low, "%s at level %d is won at least %d times in 8 (%d)" % [encounter, level, low, wins])
	assert_true(wins <= high, "%s at level %d is lost at least %d times in 8 (%d)" % [encounter, level, 8 - high, wins])


## garden_sentry, abbey_of_st_markovia_garden variant 0 at level 7.
func test_garden_sentry_v0_at_level_7() -> void:
	await _held("abbey_of_st_markovia_garden", 12, 7, "garden_sentry", [Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7), Vector2i(6, 8)], 4, 6, [])


## bride_defends, abbey_of_st_markovia_shrine variant 2 at level 5.
func test_bride_defends_v2_at_level_5() -> void:
	await _held("abbey_of_st_markovia_shrine", 12, 5, "bride_defends", [Vector2i(11, 13), Vector2i(12, 14), Vector2i(13, 14), Vector2i(11, 14)], 4, 6, [])


## bride_defends, abbey_of_st_markovia_shrine variant 1 at level 6.
func test_bride_defends_v1_at_level_6() -> void:
	await _held("abbey_of_st_markovia_shrine", 12, 6, "bride_defends", [Vector2i(11, 13), Vector2i(12, 14), Vector2i(13, 14), Vector2i(11, 14)], 4, 6, [])


## wards_cells, abbey_of_st_markovia_wards variant 1 at level 6.
func test_wards_cells_v1_at_level_6() -> void:
	await _held("abbey_of_st_markovia_wards", 12, 6, "wards_cells", [Vector2i(10, 20), Vector2i(11, 20), Vector2i(9, 20), Vector2i(10, 21)], 4, 6, [])


## wards_cells, abbey_of_st_markovia_wards variant 0 at level 7.
func test_wards_cells_v0_at_level_7() -> void:
	await _held("abbey_of_st_markovia_wards", 12, 7, "wards_cells", [Vector2i(10, 20), Vector2i(11, 20), Vector2i(9, 20), Vector2i(10, 21)], 4, 6, [])


## frozen_watch, amber_temple_entrance variant 0 at level 10.
func test_frozen_watch_v0_at_level_10() -> void:
	await _held("amber_temple_entrance", 12, 10, "frozen_watch", [Vector2i(22, 5), Vector2i(21, 5), Vector2i(20, 5), Vector2i(21, 6)], 4, 6, [])


## frozen_watch, amber_temple_entrance variant 1 at level 9.
func test_frozen_watch_v1_at_level_9() -> void:
	await _held("amber_temple_entrance", 12, 9, "frozen_watch", [Vector2i(22, 5), Vector2i(21, 5), Vector2i(20, 5), Vector2i(21, 6)], 4, 6, [])


## hollow_eyed, amber_temple_faceless_god variant 0 at level 10.
func test_hollow_eyed_v0_at_level_10() -> void:
	await _held("amber_temple_faceless_god", 12, 10, "hollow_eyed", [Vector2i(31, 14), Vector2i(30, 15), Vector2i(29, 15), Vector2i(28, 16)], 4, 6, [])


## hollow_eyed, amber_temple_faceless_god variant 2 at level 7.
func test_hollow_eyed_v2_at_level_7() -> void:
	await _held("amber_temple_faceless_god", 12, 7, "hollow_eyed", [Vector2i(31, 14), Vector2i(30, 15), Vector2i(29, 15), Vector2i(28, 16)], 4, 6, [])


## hollow_eyed, amber_temple_faceless_god variant 1 at level 8.
func test_hollow_eyed_v1_at_level_8() -> void:
	await _held("amber_temple_faceless_god", 12, 8, "hollow_eyed", [Vector2i(31, 14), Vector2i(30, 15), Vector2i(29, 15), Vector2i(28, 16)], 4, 6, [])


## patrina_wails, amber_temple_faceless_god variant 0 at level 10.
func test_patrina_wails_v0_at_level_10() -> void:
	await _held("amber_temple_faceless_god", 12, 10, "patrina_wails", [Vector2i(5, 10), Vector2i(5, 11), Vector2i(6, 11), Vector2i(4, 11)], 4, 6, [])


## courtyard_phantoms, argynvostholt variant 2 at level 6 (godfrey_met).
func test_courtyard_phantoms_v2_at_level_6() -> void:
	await _held("argynvostholt", 23, 6, "courtyard_phantoms", [Vector2i(19, 16), Vector2i(20, 17), Vector2i(20, 18), Vector2i(20, 19)], 4, 6, ["godfrey_met"])


## courtyard_phantoms, argynvostholt variant 1 at level 7 (godfrey_met).
func test_courtyard_phantoms_v1_at_level_7() -> void:
	await _held("argynvostholt", 23, 7, "courtyard_phantoms", [Vector2i(19, 16), Vector2i(20, 17), Vector2i(20, 18), Vector2i(20, 19)], 4, 6, ["godfrey_met"])


## courtyard_phantoms, argynvostholt variant 0 at level 8 (godfrey_met).
func test_courtyard_phantoms_v0_at_level_8() -> void:
	await _held("argynvostholt", 23, 8, "courtyard_phantoms", [Vector2i(19, 16), Vector2i(20, 17), Vector2i(20, 18), Vector2i(20, 19)], 4, 6, ["godfrey_met"])


## lamp_dark, argynvostholt_beacon variant 2 at level 6.
func test_lamp_dark_v2_at_level_6() -> void:
	await _held("argynvostholt_beacon", 12, 6, "lamp_dark", [Vector2i(1, 12), Vector2i(2, 12), Vector2i(1, 13), Vector2i(3, 12)], 4, 6, [])


## lamp_dark, argynvostholt_beacon variant 1 at level 7.
func test_lamp_dark_v1_at_level_7() -> void:
	await _held("argynvostholt_beacon", 12, 7, "lamp_dark", [Vector2i(1, 12), Vector2i(2, 12), Vector2i(1, 13), Vector2i(3, 12)], 4, 6, [])


## lamp_dark, argynvostholt_beacon variant 0 at level 8.
func test_lamp_dark_v0_at_level_8() -> void:
	await _held("argynvostholt_beacon", 12, 8, "lamp_dark", [Vector2i(1, 12), Vector2i(2, 12), Vector2i(1, 13), Vector2i(3, 12)], 4, 6, [])


## bone_watch, argynvostholt_mausoleum variant 2 at level 6.
func test_bone_watch_v2_at_level_6() -> void:
	await _held("argynvostholt_mausoleum", 12, 6, "bone_watch", [Vector2i(7, 12), Vector2i(8, 12), Vector2i(6, 12), Vector2i(7, 13)], 4, 6, [])


## bone_watch, argynvostholt_mausoleum variant 1 at level 7.
func test_bone_watch_v1_at_level_7() -> void:
	await _held("argynvostholt_mausoleum", 12, 7, "bone_watch", [Vector2i(7, 12), Vector2i(8, 12), Vector2i(6, 12), Vector2i(7, 13)], 4, 6, [])


## bone_watch, argynvostholt_mausoleum variant 0 at level 8.
func test_bone_watch_v0_at_level_8() -> void:
	await _held("argynvostholt_mausoleum", 12, 8, "bone_watch", [Vector2i(7, 12), Vector2i(8, 12), Vector2i(6, 12), Vector2i(7, 13)], 4, 6, [])


## berez_drowned_lights, berez variant 1 at level 7.
func test_berez_drowned_lights_v1_at_level_7() -> void:
	await _held("berez", 23, 7, "berez_drowned_lights", [Vector2i(22, 13), Vector2i(23, 13), Vector2i(22, 14), Vector2i(22, 12)], 4, 6, [])


## berez_drowned_lights, berez variant 0 at level 8.
func test_berez_drowned_lights_v0_at_level_8() -> void:
	await _held("berez", 23, 8, "berez_drowned_lights", [Vector2i(22, 13), Vector2i(23, 13), Vector2i(22, 14), Vector2i(22, 12)], 4, 6, [])


## berez_scarecrows, berez variant 2 at level 7.
func test_berez_scarecrows_v2_at_level_7() -> void:
	await _held("berez", 12, 7, "berez_scarecrows", [Vector2i(33, 23), Vector2i(34, 24), Vector2i(35, 25), Vector2i(36, 26)], 4, 6, [])


## berez_scarecrows, berez variant 1 at level 8.
func test_berez_scarecrows_v1_at_level_8() -> void:
	await _held("berez", 12, 8, "berez_scarecrows", [Vector2i(33, 23), Vector2i(34, 24), Vector2i(35, 25), Vector2i(36, 26)], 4, 6, [])


## berez_scarecrows, berez variant 0 at level 9.
func test_berez_scarecrows_v0_at_level_9() -> void:
	await _held("berez", 12, 9, "berez_scarecrows", [Vector2i(33, 23), Vector2i(34, 24), Vector2i(35, 25), Vector2i(36, 26)], 4, 6, [])


## gate_wolves, krezk variant 1 at level 6.
func test_gate_wolves_v1_at_level_6() -> void:
	await _held("krezk", 23, 6, "gate_wolves", [Vector2i(41, 20), Vector2i(42, 20), Vector2i(40, 20), Vector2i(41, 21)], 4, 6, [])


## gate_wolves, krezk variant 0 at level 7.
func test_gate_wolves_v0_at_level_7() -> void:
	await _held("krezk", 23, 7, "gate_wolves", [Vector2i(41, 20), Vector2i(42, 20), Vector2i(40, 20), Vector2i(41, 21)], 4, 6, [])


## sorin_pursuers, krezk_pool_of_the_white_sun variant 2 at level 6 (sorin_vigil, sorin_seen, sorin_known, krezk_gate_open).
func test_sorin_pursuers_v2_at_level_6() -> void:
	await _held("krezk_pool_of_the_white_sun", 1, 6, "sorin_pursuers", [Vector2i(15, 12), Vector2i(16, 12), Vector2i(14, 12), Vector2i(15, 13)], 4, 6, ["sorin_vigil", "sorin_seen", "sorin_known", "krezk_gate_open"])


## sorin_pursuers, krezk_pool_of_the_white_sun variant 1 at level 7 (sorin_vigil, sorin_seen, sorin_known, krezk_gate_open).
func test_sorin_pursuers_v1_at_level_7() -> void:
	await _held("krezk_pool_of_the_white_sun", 1, 7, "sorin_pursuers", [Vector2i(15, 12), Vector2i(16, 12), Vector2i(14, 12), Vector2i(15, 13)], 4, 6, ["sorin_vigil", "sorin_seen", "sorin_known", "krezk_gate_open"])


## sorin_pursuers, krezk_pool_of_the_white_sun variant 0 at level 8 (sorin_vigil, sorin_seen, sorin_known, krezk_gate_open).
func test_sorin_pursuers_v0_at_level_8() -> void:
	await _held("krezk_pool_of_the_white_sun", 1, 8, "sorin_pursuers", [Vector2i(15, 12), Vector2i(16, 12), Vector2i(14, 12), Vector2i(15, 13)], 4, 6, ["sorin_vigil", "sorin_seen", "sorin_known", "krezk_gate_open"])


## tsolenka_watch, tsolenka_pass_guard_tower variant 1 at level 7.
func test_tsolenka_watch_v1_at_level_7() -> void:
	await _held("tsolenka_pass_guard_tower", 12, 7, "tsolenka_watch", [Vector2i(10, 10), Vector2i(10, 11), Vector2i(11, 11), Vector2i(9, 11)], 4, 6, [])


## tsolenka_watch, tsolenka_pass_guard_tower variant 0 at level 8.
func test_tsolenka_watch_v0_at_level_8() -> void:
	await _held("tsolenka_pass_guard_tower", 12, 8, "tsolenka_watch", [Vector2i(10, 10), Vector2i(10, 11), Vector2i(11, 11), Vector2i(9, 11)], 4, 6, [])


## tower_night_visitors, van_richtens_tower variant 2 at level 6 (van_richten_notes_read).
func test_tower_night_visitors_v2_at_level_6() -> void:
	await _held("van_richtens_tower", 23, 6, "tower_night_visitors", [Vector2i(15, 20), Vector2i(16, 20), Vector2i(15, 21), Vector2i(15, 19)], 4, 6, ["van_richten_notes_read"])


## tower_night_visitors, van_richtens_tower variant 1 at level 7 (van_richten_notes_read).
func test_tower_night_visitors_v1_at_level_7() -> void:
	await _held("van_richtens_tower", 23, 7, "tower_night_visitors", [Vector2i(15, 20), Vector2i(16, 20), Vector2i(15, 21), Vector2i(15, 19)], 4, 6, ["van_richten_notes_read"])


## tower_night_visitors, van_richtens_tower variant 0 at level 8 (van_richten_notes_read).
func test_tower_night_visitors_v0_at_level_8() -> void:
	await _held("van_richtens_tower", 23, 8, "tower_night_visitors", [Vector2i(15, 20), Vector2i(16, 20), Vector2i(15, 21), Vector2i(15, 19)], 4, 6, ["van_richten_notes_read"])


## den_guards, werewolf_den_caves variant 2 at level 6.
func test_den_guards_v2_at_level_6() -> void:
	await _held("werewolf_den_caves", 12, 6, "den_guards", [Vector2i(19, 27), Vector2i(20, 27), Vector2i(18, 27), Vector2i(19, 28)], 4, 6, [])


## den_guards, werewolf_den_caves variant 1 at level 7.
func test_den_guards_v1_at_level_7() -> void:
	await _held("werewolf_den_caves", 12, 7, "den_guards", [Vector2i(19, 27), Vector2i(20, 27), Vector2i(18, 27), Vector2i(19, 28)], 4, 6, [])


## den_guards, werewolf_den_caves variant 0 at level 8.
func test_den_guards_v0_at_level_8() -> void:
	await _held("werewolf_den_caves", 12, 8, "den_guards", [Vector2i(19, 27), Vector2i(20, 27), Vector2i(18, 27), Vector2i(19, 28)], 4, 6, [])
