extends TestCase
## The side quests' fights in the real game (docs/story/side_quests.md): each starts on its own map from the location's
## data, every foe stands on open ground, and a guest who joined for it (Teodor) fights on the party's side.

var root: Node


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _boot(location: String, hour: int, level: int, flags: Array[String] = [], guests: Array[String] = []) -> LocationView:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "wren_featherfoot"]:
		var ch := Pregens.build(id, level)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	for f in flags:
		GameState.story.set_flag(f, true)
	for g in guests:
		GameState.story.add_guest(g)
	GameState.story.location = location
	GameState.story.minute_of_day = hour * 60
	Dice.reseed(7)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	return root.get("view") as LocationView


## Starts `encounter` and checks its board: foes on open squares, every named foe present.
func _fight(v: LocationView, encounter: String, named: Array[String]) -> Encounter:
	assert_true(v.start_encounter(encounter), "%s starts" % encounter)
	await _frames(3)
	var e := v.combat_view.e
	var names: Array[String] = []
	for c in e.combatants:
		assert_false(e.grid.is_solid(c.cell), "%s isn't in a wall (%s)" % [c.name(), c.cell])
		names.append(c.name())
	for n in named:
		assert_true(names.has(n), "%s is in the fight: %s" % [n, names])
	return e


func _end(v: LocationView) -> void:
	v.combat_view.finished.emit("victory")
	await _frames(4)


func test_the_coachman_comes_for_ileanas_door_and_teodor_stands_with_the_party() -> void:
	var v := await _boot("village_of_barovia", 22, 3, ["teodor_vigil", "teodor_met"], ["teodor"])
	var e := await _fight(v, "teodor_errand", ["The Coachman"])
	var teodor: Combatant = null
	var coachman: Combatant = null
	for c in e.combatants:
		if c.name() == "Teodor":
			teodor = c
		elif c.name() == "The Coachman":
			coachman = c
	assert_true(teodor != null, "Teodor is on the board")
	if teodor != null and coachman != null:
		assert_ne(teodor.side, coachman.side, "on the other side from the coachman")
	await _end(v)
	assert_true(bool(GameState.story.get_flag("teodor_errand_beaten", false)), "the win is remembered")
	assert_eq(GameState.story.quest_stage("polite_caller"), "held")


func test_the_woodpile_stands_up_in_grigores_yard() -> void:
	var v := await _boot("village_of_barovia", 19, 3, ["seedwood_known"])
	await _fight(v, "woodpile_wakes", ["The Woodpile"])
	await _end(v)
	assert_eq(GameState.story.quest_stage("cut_after_noon"), "stood_up")


func test_the_late_wood_burns_by_day() -> void:
	var v := await _boot("village_of_barovia", 11, 4, ["seedwood_known", "bildrath_wood_taken"])
	await _fight(v, "woodpile_burns", [])
	await _end(v)
	assert_true(bool(GameState.story.get_flag("late_wood_burned", false)))


func test_the_carriage_escort_at_the_crossroads_with_and_without_steaua() -> void:
	var v := await _boot("svalich_crossroads", 0, 4, ["mare_saved", "carriage_came"])
	var e := await _fight(v, "carriage_escort", ["The Lead Horse", "The Footman"])
	assert_false(e.combatants.any(func(c: Combatant) -> bool: return c.name() == "Steaua"), "saved, she isn't there")
	await _end(v)
	assert_true(bool(GameState.story.get_flag("carriage_beaten", false)))
	root.queue_free()
	root = null
	v = await _boot("svalich_crossroads", 0, 4, ["mare_lost", "carriage_came"])
	await _fight(v, "carriage_escort", ["The Lead Horse", "Steaua"])
	await _end(v)


func test_stellas_shadow_stands_up_in_her_bedroom() -> void:
	var v := await _boot("vallaki_wachter_house", 14, 5, ["stella_bound_known", "stella_met"])
	await _fight(v, "stella_shadow", ["The Master's Gaze"])
	await _end(v)
	assert_eq(GameState.story.quest_stage("cat_in_the_window"), "freed")


func test_ana_and_the_girls_in_the_street_and_in_their_graves() -> void:
	var v := await _boot("vallaki", 22, 5, ["roses_vigil", "ana_met"])
	await _fight(v, "roses_street", ["Ana", "Irina"])
	await _end(v)
	assert_true(bool(GameState.story.get_flag("roses_spawn_destroyed", false)))
	root.queue_free()
	root = null
	v = await _boot("vallaki", 11, 5, ["ana_grave_known"])
	await _fight(v, "roses_graves", ["Ana", "Irina", "Daria"])
	await _end(v)


func test_the_abbey_comes_for_sorin_at_the_pool() -> void:
	var v := await _boot("krezk_pool_of_the_white_sun", 1, 7, ["sorin_vigil", "sorin_seen", "sorin_known", "krezk_gate_open"])
	await _fight(v, "sorin_pursuers", ["A Bride Before Vasilka", "Belview Brute"])
	await _end(v)
	assert_eq(GameState.story.quest_stage("lighter_than_it_should_be"), "pursued")
