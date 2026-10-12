extends TestCase
## Owner report (2026-10-12): Godrick cast Find Steed while exploring and no steed showed up. The steed appears beside
## its paladin as the spell is cast, walks at the back of the line like a familiar, joins his fights once (summoned
## there, not as a second guest), and a new casting swaps it.

const LOC := {
	"id": "test_paddock", "name": "Test Paddock", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"############",
		"#..........#",
		"#..........#",
		"#..........#",
		"#..........#",
		"#..........#",
		"############"], "light": "dim"},
	"spawns": {"default": [2, 2]},
	"encounters": [{"id": "rat", "trigger": "manual", "monsters": [{"monster": "rat", "cell": [10, 5]}]}],
}

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_paddock"] = LOC.duplicate(true)
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "ilse_varga"]:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_paddock"
	Dice.reseed(7)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null
	(Compendium.shared().tables["locations"] as Dictionary).erase("test_paddock")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func _followers(v: LocationView, rider_id: String) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for g in v.guest_members:
		if str(g.get_meta("steed_of", "")) == rider_id:
			out.append(g)
	return out


## As the character sheet casts it: FieldCasting, then the world hears of it.
func _cast(godrick: Character, kind: String) -> void:
	var res := FieldCasting.cast_utility(GameState.story, godrick, "find_steed", false, 0, "", kind)
	assert_true(bool(res["ok"]), str(res))
	_view().apply_spell_effect("find_steed")
	await _frames(2)


func test_a_steed_cast_while_exploring_walks_with_its_paladin_and_joins_his_fight() -> void:
	var v := _view()
	var godrick := GameState.story.party[0]
	assert_true(_followers(v, godrick.id).is_empty(), "no steed before the spell")
	await _cast(godrick, "celestial")
	var steed := _followers(v, godrick.id)
	assert_eq(steed.size(), 1, "the steed appears")
	if steed.is_empty():
		return
	assert_true(v.tokens.has(steed[0].id) and (v.tokens[steed[0].id] as Node3D).visible, "drawn on the board")
	assert_true(bool((steed[0].creature as Monster).data.get("steed", false)), "an Otherworldly Steed")
	assert_eq(GameState.story.guests.size(), 0, "not one of the story's guests")
	# A fight: the steed is summoned beside him once, and walks on after it.
	assert_true(v.start_encounter("rat"))
	await _frames(3)
	var e := v.combat_view.e
	var steeds := e.combatants.filter(func(c: Combatant) -> bool:
		return c.creature is Monster and bool((c.creature as Monster).data.get("steed", false)))
	assert_eq(steeds.size(), 1, "one steed in the fight")
	v.combat_view.finished.emit("victory")
	await _frames(4)
	assert_eq(_followers(v, godrick.id).size(), 1, "and with him after it")
	# A new casting swaps it for the new kind.
	godrick.finish_long_rest()
	await _cast(godrick, "fey")
	var again := _followers(v, godrick.id)
	assert_eq(again.size(), 1, "still one steed")
	if not again.is_empty():
		assert_eq(str((again[0].get_meta("steed", {}) as Dictionary).get("type", "")), "fey", "the new one")


func test_a_steed_already_called_is_there_on_arrival() -> void:
	var godrick := GameState.story.party[0]
	godrick.steed = {"type": "fiend", "level": 2}
	root.call("rebuild")
	await _frames(3)
	assert_eq(_followers(_view(), godrick.id).size(), 1, "the steed from before walks with him")
