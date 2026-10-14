extends FightSeriesCase
## The roads' random fights (data/random_encounters/) scaled for 2024 heroes and the sharp test party (owner, 2026-10-13
## 18:05: 5 in 8 on Balanced for every fight at every level). Each is played as game_root plays a road fight: the four
## pregens at the default spawn of the table's own map, at the level its region is travelled at, the entry's foes placed
## as the table gives them (a fight on another ground has them laid out by RoadGrounds, held spread out by
## test_fight_spread.gd), by day or by night as its `when` says. Over seeds 1-8 the sharp autopilot wins 5, give or take
## one, and every fight finishes.

const SEEDS: Array = [1, 2, 3, 4, 5, 6, 7, 8]


func _road_once(table_id: String, entry_id: String, level: int, hour: int, seed_value: int) -> Dictionary:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, level)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	var table := Compendium.shared().get_entry("random_encounters", table_id)
	var ground := str(table["map"])
	GameState.story.location = ground
	GameState.story.minute_of_day = hour * 60
	Dice.reseed(seed_value)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	var v := root.get("view") as LocationView
	var entry := {}
	for e: Variant in table["entries"]:
		if str((e as Dictionary).get("id", "")) == entry_id:
			entry = e as Dictionary
	var foes := RoadGrounds.placed(entry["monsters"] as Array, ground, ground)
	assert_true(v.start_custom_encounter({"id": "random_%s" % entry_id, "monsters": foes,
		"surprise": str(entry.get("surprise", ""))}), "%s starts" % entry_id)
	await _frames(2)
	var e := v.combat_view.e
	var res := PartyAutopilot.new(e).run(30)
	while e.pending != null:
		e.answer_reaction(false)
	root.queue_free()
	root = null
	await _frames(2)
	return res


## Wins over seeds 1-8 between 4 and 6 (target 5), and every fight finishes.
func _road(table_id: String, entry_id: String, level: int, hour: int) -> void:
	var wins := 0
	for s: int in SEEDS:
		var res := await _road_once(table_id, entry_id, level, hour, s)
		assert_ne(str(res["outcome"]), "timeout", "%s seed %d finished" % [entry_id, s])
		if str(res["outcome"]) == "victory":
			wins += 1
	print("        %s at level %d: %d/8 won" % [entry_id, level, wins])
	assert_true(wins >= 4 and wins <= 6, "%s on %s at level %d is won 4 to 6 times in 8 (%d)" % [entry_id, table_id, level, wins])


func test_amber_temple_road_cliff_gargoyles_at_level_10() -> void:
	await _road("amber_temple_road", "cliff_gargoyles", 10, 12)


func test_amber_temple_road_frozen_climbers_at_level_10() -> void:
	await _road("amber_temple_road", "frozen_climbers", 10, 23)


func test_argynvostholt_road_dire_wolves_day_at_level_8() -> void:
	await _road("argynvostholt_road", "dire_wolves_day", 8, 12)


func test_argynvostholt_road_the_conquerors_dead_at_level_8() -> void:
	await _road("argynvostholt_road", "the_conquerors_dead", 8, 23)


func test_argynvostholt_road_werewolf_hunters_at_level_8() -> void:
	await _road("argynvostholt_road", "werewolf_hunters", 8, 12)


func test_baratok_slopes_dire_wolves_at_level_9() -> void:
	await _road("baratok_slopes", "dire_wolves", 9, 12)


func test_baratok_slopes_ogres_at_level_9() -> void:
	await _road("baratok_slopes", "ogres", 9, 12)


func test_baratok_slopes_spiders_at_level_9() -> void:
	await _road("baratok_slopes", "spiders", 9, 12)


func test_baratok_slopes_werewolves_ridge_at_level_9() -> void:
	await _road("baratok_slopes", "werewolves_ridge", 9, 23)


func test_berez_marsh_insect_cloud_at_level_9() -> void:
	await _road("berez_marsh", "insect_cloud", 9, 12)


func test_berez_marsh_marsh_lights_at_level_9() -> void:
	await _road("berez_marsh", "marsh_lights", 9, 23)


func test_berez_marsh_scarecrow_walk_at_level_9() -> void:
	await _road("berez_marsh", "scarecrow_walk", 9, 12)


func test_bonegrinder_lane_lane_bats_at_level_6() -> void:
	await _road("bonegrinder_lane", "lane_bats", 6, 23)


func test_bonegrinder_lane_lane_dead_at_level_6() -> void:
	await _road("bonegrinder_lane", "lane_dead", 6, 23)


func test_bonegrinder_lane_lane_wolves_at_level_6() -> void:
	await _road("bonegrinder_lane", "lane_wolves", 6, 12)


func test_bonegrinder_lane_lane_wolves_night_at_level_6() -> void:
	await _road("bonegrinder_lane", "lane_wolves_night", 6, 23)


func test_krezk_road_krezk_road_blights_at_level_7() -> void:
	await _road("krezk_road", "krezk_road_blights", 7, 12)


func test_krezk_road_krezk_road_dead_at_level_7() -> void:
	await _road("krezk_road", "krezk_road_dead", 7, 23)


func test_krezk_road_krezk_road_werewolves_at_level_7() -> void:
	await _road("krezk_road", "krezk_road_werewolves", 7, 23)


func test_krezk_road_krezk_road_wolves_at_level_7() -> void:
	await _road("krezk_road", "krezk_road_wolves", 7, 12)


func test_svalich_road_bats_and_dead_at_level_4() -> void:
	await _road("svalich_road", "bats_and_dead", 4, 23)


func test_svalich_road_dead_on_the_road_at_level_4() -> void:
	await _road("svalich_road", "dead_on_the_road", 4, 23)


func test_svalich_road_strahds_wolves_at_level_4() -> void:
	await _road("svalich_road", "strahds_wolves", 4, 23)


func test_svalich_road_werewolf_night_at_level_4() -> void:
	await _road("svalich_road", "werewolf_night", 4, 23)


func test_svalich_road_wolf_pack_night_at_level_4() -> void:
	await _road("svalich_road", "wolf_pack_night", 4, 23)


func test_svalich_road_wolves_shadowing_at_level_4() -> void:
	await _road("svalich_road", "wolves_shadowing", 4, 12)


func test_svalich_woods_bats_and_wolves_at_level_4() -> void:
	await _road("svalich_woods", "bats_and_wolves", 4, 23)


func test_svalich_woods_dead_in_the_trees_at_level_4() -> void:
	await _road("svalich_woods", "dead_in_the_trees", 4, 23)


func test_svalich_woods_strahds_wolves_at_level_4() -> void:
	await _road("svalich_woods", "strahds_wolves", 4, 23)


func test_svalich_woods_werewolves_at_level_4() -> void:
	await _road("svalich_woods", "werewolves", 4, 23)


func test_svalich_woods_wolf_pack_night_at_level_4() -> void:
	await _road("svalich_woods", "wolf_pack_night", 4, 23)


func test_svalich_woods_wolves_in_the_pines_at_level_4() -> void:
	await _road("svalich_woods", "wolves_in_the_pines", 4, 12)


func test_vineyard_road_druid_patrol_at_level_6() -> void:
	await _road("vineyard_road", "druid_patrol", 6, 12)


func test_vineyard_road_druids_return_at_level_6() -> void:
	await _road("vineyard_road", "druids_return", 6, 12)


func test_vineyard_road_hedgerow_blights_at_level_6() -> void:
	await _road("vineyard_road", "hedgerow_blights", 6, 12)


func test_vineyard_road_strahds_wolves_at_level_6() -> void:
	await _road("vineyard_road", "strahds_wolves", 6, 23)


func test_vineyard_road_wolves_on_the_moor_at_level_6() -> void:
	await _road("vineyard_road", "wolves_on_the_moor", 6, 23)


func test_zarovich_hills_dire_wolves_at_level_8() -> void:
	await _road("zarovich_hills", "dire_wolves", 8, 12)


func test_zarovich_hills_hill_ghouls_at_level_8() -> void:
	await _road("zarovich_hills", "hill_ghouls", 8, 23)


func test_zarovich_hills_pack_hunt_at_level_8() -> void:
	await _road("zarovich_hills", "pack_hunt", 8, 23)


func test_zarovich_shore_marsh_lights_at_level_8() -> void:
	await _road("zarovich_shore", "marsh_lights", 8, 23)


func test_zarovich_shore_shore_wolves_at_level_8() -> void:
	await _road("zarovich_shore", "shore_wolves", 8, 12)


func test_zarovich_shore_the_drowned_at_level_8() -> void:
	await _road("zarovich_shore", "the_drowned", 8, 23)
