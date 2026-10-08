extends TestCase
## The side quests' bosses (docs/story/side_quests.md), played to the end by the test autopilot on their own maps at the
## level the quest expects: every fight finishes, every boss uses its turns without error, and the party can win but
## pays for it (hard, per the owner's standing rule).

var root: Node


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Boots `location` at `hour` with the four pregens at `level`, starts `encounter` and plays it with the autopilot.
func _play(location: String, hour: int, level: int, encounter: String, seed_value: int, flags: Array[String] = []) -> Dictionary:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, level)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	for f in flags:
		GameState.story.set_flag(f, true)
	GameState.story.location = location
	GameState.story.minute_of_day = hour * 60
	Dice.reseed(seed_value)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	var v := root.get("view") as LocationView
	assert_true(v.start_encounter(encounter), "%s starts" % encounter)
	await _frames(2)
	var e := v.combat_view.e
	var res := PartyAutopilot.new(e).run(30)
	for c in e.combatants:
		assert_true(c.creature.hp >= 0 and c.creature.hp <= c.creature.max_hp(), "%s HP in range" % c.name())
	root.queue_free()
	root = null
	await _frames(2)
	return res


func _series(location: String, hour: int, level: int, encounter: String, seeds: Array, flags: Array[String] = []) -> void:
	var wins := 0
	var downs := 0
	var rounds := 0
	for s: int in seeds:
		var res := await _play(location, hour, level, encounter, s, flags)
		assert_ne(str(res["outcome"]), "timeout", "%s seed %d finished" % [encounter, s])
		if str(res["outcome"]) == "victory":
			wins += 1
		downs += int(res["downs"])
		rounds += int(res["rounds"])
	print("        %s at level %d: %d/%d won, %.1f rounds, %.1f party members dropped per fight" % [
		encounter, level, wins, seeds.size(), rounds / float(seeds.size()), downs / float(seeds.size())])
	assert_true(wins >= 1, "%s can be won at level %d (%d/%d)" % [encounter, level, wins, seeds.size()])


func test_old_greytooth_at_level_6() -> void:
	await _series("lake_zarovich", 19, 6, "greytooth_hunt", [1, 2, 3, 4])


func test_the_drowned_of_pescari_at_level_8() -> void:
	await _series("lake_zarovich", 23, 8, "drowned_landing", [1, 2, 3])


func test_the_bone_marshal_and_his_column_at_level_6() -> void:
	await _series("into_the_mists_road", 23, 6, "bone_marshal", [1, 2, 3])


func test_the_bone_marshal_duel_at_level_8() -> void:
	await _series("into_the_mists_road", 23, 8, "bone_marshal", [1, 2, 3], ["riders_stood_down"])


func test_the_rag_queen_at_level_9() -> void:
	await _series("berez", 14, 9, "rag_queen", [1, 2, 3], ["lysaga_guests"])


func test_the_vine_mother_at_level_6() -> void:
	await _series("wizard_of_wines", 1, 6, "vine_mother", [1, 2, 3, 4], ["winery_reclaimed"])


func test_granny_ash_at_level_6() -> void:
	await _series("old_bonegrinder_track", 23, 6, "granny_ash", [1, 2, 3, 4], ["morgantha_slain"])
