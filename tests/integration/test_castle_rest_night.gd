extends TestCase
## A night's camp in Castle Ravenloft (held ask, 2026-10-24; tests/unit/test_castle_rest.gd has the rules): the party on the
## main floor may sleep once that floor is clear, and a night broken on a 2 brings the castle's own dead down on the camp,
## the vampire spawn at level 8.

var root: Node


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null
		await _frames(3)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The four at `level` in `place` at night, with `clear` the fights waiting on its floor won, and the camp they make there.
func _camp(place: String, level: int, clear: bool) -> LocationCamp:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, level)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.milestones = level - 1
	GameState.story.location = place
	GameState.story.minute_of_day = 22 * 60
	if clear:
		for f in RestRules.waiting_fights(GameState.story, place):
			(GameState.story.loc_state(str(f["location"]))["encounters"] as Dictionary)[str(f["id"])] = true
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	return LocationCamp.pitch(root.get("view") as LocationView, root, "risky")


func test_the_party_may_sleep_on_a_floor_that_is_clear_and_not_on_one_that_is_not() -> void:
	var camp := await _camp("castle_ravenloft_main_floor", 8, false)
	assert_true(camp != null, "a camp can be pitched on the main floor")
	if camp == null:
		return
	assert_eq(camp.sleep_refusal(), "Enemies still prowl this floor. Clear them out, rest somewhere else, or ward the rest (Leomund's Tiny Hut, Guards and Wards).")
	root.queue_free()
	root = null
	await _frames(3)
	camp = await _camp("castle_ravenloft_main_floor", 8, true)
	assert_true(camp != null)
	if camp != null:
		assert_eq(camp.sleep_refusal(), "", "the floor is clear: the party may sleep, with the count's floor still full of enemies above")
		assert_false(RestRules.waiting_fights(GameState.story, "castle_ravenloft_court").is_empty())


func test_a_night_broken_in_the_castle_brings_the_castles_dead() -> void:
	var camp := await _camp("castle_ravenloft_main_floor", 8, true)
	assert_true(camp != null)
	if camp == null:
		return
	var view := root.get("view") as LocationView
	# A seed whose first d6 (the night's interruption) shows a 2: only the castle breaks a night on it.
	var s := 1
	while DiceRoller.new(s).roll_one(6) != 2:
		s += 1
	Dice.reseed(s)
	camp.sleep()
	await _frames(2)
	assert_true(view.in_combat, "something comes out of the dark")
	assert_false(camp.slept, "nobody slept the night")
	var ids: Array = view.combat_view.e.combatants.filter(func(c: Combatant) -> bool: return c.side == &"enemy").map(
		func(c: Combatant) -> String: return (c.creature as Monster).data.get("id", ""))
	assert_eq(ids.count("vampire_spawn"), 3, "three vampire spawn: %s" % [ids])
	assert_eq(ids.count("swarm_of_bats"), 2, "and their bats")
