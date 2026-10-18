extends FightSeriesCase
## Castle Ravenloft's rooms, watches and guards (the fights that had no series test), scaled up for 2024 heroes
## (owner, 2026-10-13: the book's fights were written for weaker characters). The bosses are held in
## test_scaled_boss_fights.gd, the Hall of Faces and the portrait gallery in test_scaled_fights_castle.gd.
## Over seeds 1-8 the four pregens on the sharp autopilot (smiting, opening with Spirit Guardians, throwing Fireball, as he
## plays) win 5, give or take one, on Balanced (owner, 2026-10-13 18:05), each fight played from where walking in or
## talking sets it off, with its foes starting spread out (tests/unit/test_fight_spread.gd). Every fight finishes. A fight
## that waits in plain view (docs/rules/stealth.md) starts where its foes first notice a party walking in from the spawn
## the story uses, not sneaking: the squares and the doors opened on the way are those, walked and read off.

const SEEDS: Array = [1, 2, 3, 4, 5, 6, 7, 8]


func before_each() -> void:
	speakers_step_aside = true
	prepare = Callable()


## Wins over seeds 1-8 between `low` and `high`.
func _held(location: String, hour: int, level: int, encounter: String, at: Array[Vector2i], low: int, high: int,
		flags: Array[String] = [], guests: Array[String] = [], doors: Array[String] = []) -> void:
	var wins := await _series(location, hour, level, encounter, SEEDS, flags, guests, doors, at)
	assert_true(wins >= low, "%s at level %d is won at least %d times in 8 (%d)" % [encounter, level, low, wins])
	assert_true(wins <= high, "%s at level %d is lost at least %d times in 8 (%d)" % [encounter, level, 8 - high, wins])


## cat_gargoyle_watch, castle_ravenloft_catacombs variant 0 at level 10.
func test_cat_gargoyle_watch_v0_at_level_10() -> void:
	await _held("castle_ravenloft_catacombs", 12, 10, "cat_gargoyle_watch", [Vector2i(36, 9), Vector2i(35, 9), Vector2i(34, 8), Vector2i(34, 7)], 4, 6, [], [], ["cat_champion_gate"])


## cat_sleepers, castle_ravenloft_catacombs variant 0 at level 10.
func test_cat_sleepers_v0_at_level_10() -> void:
	await _held("castle_ravenloft_catacombs", 23, 10, "cat_sleepers", [Vector2i(37, 16), Vector2i(38, 16), Vector2i(37, 17), Vector2i(37, 15)], 4, 6, [])


## cat_sleepers, castle_ravenloft_catacombs variant 1 at level 10.
func test_cat_sleepers_v1_at_level_10() -> void:
	await _held("castle_ravenloft_catacombs", 12, 10, "cat_sleepers", [Vector2i(37, 16), Vector2i(38, 16), Vector2i(37, 17), Vector2i(37, 15)], 4, 6, [])


## cat_guardians, castle_ravenloft_catacombs_tombs variant 0 at level 10.
func test_cat_guardians_v0_at_level_10() -> void:
	await _held("castle_ravenloft_catacombs_tombs", 12, 10, "cat_guardians", [Vector2i(16, 8), Vector2i(16, 7), Vector2i(16, 6), Vector2i(16, 5)], 4, 6, [])


## court_accountant_rug, castle_ravenloft_court variant 0 at level 10.
func test_court_accountant_rug_v0_at_level_10() -> void:
	await _held("castle_ravenloft_court", 12, 10, "court_accountant_rug", [Vector2i(4, 17), Vector2i(5, 17), Vector2i(3, 17), Vector2i(4, 18)], 4, 6, [])


## court_post_watch, castle_ravenloft_court variant 0 at level 10.
func test_court_post_watch_v0_at_level_10() -> void:
	await _held("castle_ravenloft_court", 12, 10, "court_post_watch", [Vector2i(18, 19), Vector2i(19, 19), Vector2i(20, 20), Vector2i(21, 21)], 4, 6, [], [], ["court_guardroom_door"])


## crg_courtyard_gargoyles, castle_ravenloft_gates variant 0 at level 10 (strahd_invitatio).
func test_crg_courtyard_gargoyles_v0_at_level_10() -> void:
	await _held("castle_ravenloft_gates", 23, 10, "crg_courtyard_gargoyles", [Vector2i(19, 12), Vector2i(18, 11), Vector2i(18, 13), Vector2i(20, 11)], 4, 6, ["strahd_invitatio"])


## crg_courtyard_gargoyles, castle_ravenloft_gates variant 1 at level 9 (strahd_invitatio).
func test_crg_courtyard_gargoyles_v1_at_level_9() -> void:
	await _held("castle_ravenloft_gates", 23, 9, "crg_courtyard_gargoyles", [Vector2i(19, 12), Vector2i(18, 11), Vector2i(18, 13), Vector2i(20, 11)], 4, 6, ["strahd_invitatio"])


## larders_guardroom, castle_ravenloft_larders variant 0 at level 10.
func test_larders_guardroom_v0_at_level_10() -> void:
	await _held("castle_ravenloft_larders", 12, 10, "larders_guardroom", [Vector2i(20, 12), Vector2i(21, 12), Vector2i(19, 12), Vector2i(20, 13)], 4, 6, [])


## larders_watch_alarm, castle_ravenloft_larders variant 0 at level 10.
func test_larders_watch_alarm_v0_at_level_10() -> void:
	await _held("castle_ravenloft_larders", 12, 10, "larders_watch_alarm", [Vector2i(25, 5), Vector2i(26, 5), Vector2i(24, 5), Vector2i(25, 6)], 4, 6, [])


## larders_furnace, castle_ravenloft_larders_dungeon variant 0 at level 10.
func test_larders_furnace_v0_at_level_10() -> void:
	await _held("castle_ravenloft_larders_dungeon", 12, 10, "larders_furnace", [Vector2i(28, 3), Vector2i(29, 3), Vector2i(28, 4), Vector2i(28, 2)], 4, 6, [])


## larders_jailers, castle_ravenloft_larders_dungeon variant 0 at level 10.
func test_larders_jailers_v0_at_level_10() -> void:
	await _held("castle_ravenloft_larders_dungeon", 12, 10, "larders_jailers", [Vector2i(21, 3), Vector2i(20, 3), Vector2i(19, 3), Vector2i(18, 3)], 4, 6, [], [], ["larders_jailers_post_door"])


## larders_questioner, castle_ravenloft_larders_dungeon variant 0 at level 10.
func test_larders_questioner_v0_at_level_10() -> void:
	await _held("castle_ravenloft_larders_dungeon", 12, 10, "larders_questioner", [Vector2i(2, 20), Vector2i(3, 20), Vector2i(1, 20), Vector2i(2, 21)], 4, 6, [])


## crg_kestrel_cellar, castle_ravenloft_main_floor variant 0 at level 10.
func test_crg_kestrel_cellar_v0_at_level_10() -> void:
	prepare = func(st: StoryState) -> void:
		st.party[st.party.size() - 1] = Pregens.build("ilse_varga", 10)
		st.party[st.party.size() - 1].finish_long_rest()
		st.set_quest_stage("kestrel_company", "the_deserter")
	await _held("castle_ravenloft_main_floor", 12, 10, "crg_kestrel_cellar", [Vector2i(11, 2), Vector2i(12, 2), Vector2i(10, 2), Vector2i(11, 1)], 4, 6, [])


## crg_kestrel_cellar, castle_ravenloft_main_floor variant 1 at level 10 (kestrel_vell_rests).
func test_crg_kestrel_cellar_v1_at_level_10() -> void:
	prepare = func(st: StoryState) -> void:
		st.party[st.party.size() - 1] = Pregens.build("ilse_varga", 10)
		st.party[st.party.size() - 1].finish_long_rest()
		st.set_quest_stage("kestrel_company", "the_deserter")
	await _held("castle_ravenloft_main_floor", 12, 10, "crg_kestrel_cellar", [Vector2i(11, 2), Vector2i(12, 2), Vector2i(10, 2), Vector2i(11, 1)], 4, 6, ["kestrel_vell_rests"])


## crg_kestrel_table, castle_ravenloft_main_floor variant 0 at level 10 (kestrel_merrow_called).
func test_crg_kestrel_table_v0_at_level_10() -> void:
	await _held("castle_ravenloft_main_floor", 12, 10, "crg_kestrel_table", [Vector2i(5, 8), Vector2i(6, 8), Vector2i(7, 8), Vector2i(8, 8)], 4, 6, ["kestrel_merrow_called"])


## crg_turret_guard, castle_ravenloft_main_floor variant 0 at level 10.
func test_crg_turret_guard_v0_at_level_10() -> void:
	await _held("castle_ravenloft_main_floor", 12, 10, "crg_turret_guard", [Vector2i(30, 20), Vector2i(29, 20), Vector2i(28, 21), Vector2i(27, 22)], 4, 6, [], [], ["crg_turret_east_door"])


## crg_turret_guard, castle_ravenloft_main_floor variant 1 at level 9.
func test_crg_turret_guard_v1_at_level_9() -> void:
	await _held("castle_ravenloft_main_floor", 12, 9, "crg_turret_guard", [Vector2i(30, 20), Vector2i(29, 20), Vector2i(28, 21), Vector2i(27, 22)], 4, 6, [], [], ["crg_turret_east_door"])


## spires_stair_watch, castle_ravenloft_spires variant 1 at level 10.
func test_spires_stair_watch_v1_at_level_10() -> void:
	await _held("castle_ravenloft_spires", 12, 10, "spires_stair_watch", [Vector2i(28, 4), Vector2i(29, 4), Vector2i(28, 3), Vector2i(29, 5)], 4, 6, [])


## spires_stair_watch, castle_ravenloft_spires variant 0 at level 11.
func test_spires_stair_watch_v0_at_level_11() -> void:
	await _held("castle_ravenloft_spires", 12, 11, "spires_stair_watch", [Vector2i(28, 4), Vector2i(29, 4), Vector2i(28, 3), Vector2i(29, 5)], 4, 6, [])


## spires_stair_watch, castle_ravenloft_spires variant 2 at level 9.
func test_spires_stair_watch_v2_at_level_9() -> void:
	await _held("castle_ravenloft_spires", 12, 9, "spires_stair_watch", [Vector2i(28, 4), Vector2i(29, 4), Vector2i(28, 3), Vector2i(29, 5)], 4, 6, [])


## heart_guardians, castle_ravenloft_spires_heart variant 1 at level 10.
func test_heart_guardians_v1_at_level_10() -> void:
	await _held("castle_ravenloft_spires_heart", 12, 10, "heart_guardians", [Vector2i(8, 7), Vector2i(8, 8), Vector2i(8, 9), Vector2i(8, 10)], 4, 6, [])


## heart_guardians, castle_ravenloft_spires_heart variant 0 at level 11.
func test_heart_guardians_v0_at_level_11() -> void:
	await _held("castle_ravenloft_spires_heart", 12, 11, "heart_guardians", [Vector2i(8, 7), Vector2i(8, 8), Vector2i(8, 9), Vector2i(8, 10)], 4, 6, [])


## heart_guardians, castle_ravenloft_spires_heart variant 2 at level 9.
func test_heart_guardians_v2_at_level_9() -> void:
	await _held("castle_ravenloft_spires_heart", 12, 9, "heart_guardians", [Vector2i(8, 7), Vector2i(8, 8), Vector2i(8, 9), Vector2i(8, 10)], 4, 6, [])


## peak_guardians, castle_ravenloft_spires_roofs variant 1 at level 10.
func test_peak_guardians_v1_at_level_10() -> void:
	await _held("castle_ravenloft_spires_roofs", 12, 10, "peak_guardians", [Vector2i(25, 5), Vector2i(26, 5), Vector2i(24, 5), Vector2i(25, 6)], 4, 6, [])


## peak_guardians, castle_ravenloft_spires_roofs variant 0 at level 11.
func test_peak_guardians_v0_at_level_11() -> void:
	await _held("castle_ravenloft_spires_roofs", 12, 11, "peak_guardians", [Vector2i(25, 5), Vector2i(26, 5), Vector2i(24, 5), Vector2i(25, 6)], 4, 6, [])


## peak_guardians, castle_ravenloft_spires_roofs variant 2 at level 9.
func test_peak_guardians_v2_at_level_9() -> void:
	await _held("castle_ravenloft_spires_roofs", 12, 9, "peak_guardians", [Vector2i(25, 5), Vector2i(26, 5), Vector2i(24, 5), Vector2i(25, 6)], 4, 6, [])


## cauldron_coven, castle_ravenloft_spires_rooms variant 1 at level 10.
func test_cauldron_coven_v1_at_level_10() -> void:
	await _held("castle_ravenloft_spires_rooms", 12, 10, "cauldron_coven", [Vector2i(6, 9), Vector2i(6, 8), Vector2i(7, 8), Vector2i(8, 8)], 4, 6, [])


## cauldron_coven, castle_ravenloft_spires_rooms variant 0 at level 11.
func test_cauldron_coven_v0_at_level_11() -> void:
	await _held("castle_ravenloft_spires_rooms", 12, 11, "cauldron_coven", [Vector2i(6, 9), Vector2i(6, 8), Vector2i(7, 8), Vector2i(8, 8)], 4, 6, [])


## cauldron_coven, castle_ravenloft_spires_rooms variant 2 at level 9.
func test_cauldron_coven_v2_at_level_9() -> void:
	await _held("castle_ravenloft_spires_rooms", 12, 9, "cauldron_coven", [Vector2i(6, 10), Vector2i(6, 9), Vector2i(6, 8), Vector2i(7, 8)], 4, 6, [])


## escher_fight, castle_ravenloft_spires_rooms variant 0 at level 10.
func test_escher_fight_v0_at_level_10() -> void:
	await _held("castle_ravenloft_spires_rooms", 12, 10, "escher_fight", [Vector2i(17, 15), Vector2i(18, 15), Vector2i(16, 15), Vector2i(17, 16)], 4, 6, [])


## roost_swarm, castle_ravenloft_spires_roost variant 0 at level 10.
func test_roost_swarm_v0_at_level_10() -> void:
	await _held("castle_ravenloft_spires_roost", 12, 10, "roost_swarm", [Vector2i(14, 6), Vector2i(13, 5), Vector2i(12, 5), Vector2i(11, 5)], 4, 6, [])


## roost_swarm_roused, castle_ravenloft_spires_roost variant 0 at level 10.
func test_roost_swarm_roused_v0_at_level_10() -> void:
	await _held("castle_ravenloft_spires_roost", 12, 10, "roost_swarm_roused", [Vector2i(7, 3), Vector2i(6, 3), Vector2i(5, 3), Vector2i(4, 3)], 4, 6, [])
