extends TestCase
## Owner report (2026-10-07): after Offalia Wormwiggle eats one of her mother's dream pastries she should lie asleep on
## the bakery floor from then on, prone, with the sleep showing, and she stood on at the oven. An NPC entry with
## `asleep: true` (LocationNpcs.put_to_sleep) lays its figure down Unconscious and Prone; the Alt plates say so, talking
## to her reaches the asleep conversation, and a save and load keeps it.

const OFFALIA := "offalia_wormwiggle"
const OVEN := Vector2i(15, 10)
const FLOOR := Vector2i(14, 12)

var root: Node


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "old_bonegrinder"
	Dice.reseed(4)
	await _start_game()


func after_each() -> void:
	if root != null and is_instance_valid(root):
		root.queue_free()
	SaveSystem.delete_slot("test_sleeping")


func _start_game() -> void:
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	await _finish_dialogue()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


## Clicks through the conversation on screen (the arrival's and the pastry's have no choices).
func _finish_dialogue() -> void:
	for i in 30:
		var d := root.get("dialogue") as DialogueUI
		if d == null:
			break
		d.call("_advance")
		await _frames(1)
	await _frames(2)


func _token() -> CombatToken:
	return _view().npc_tokens.get(OFFALIA, null) as CombatToken


func _lying(tok: CombatToken) -> bool:
	return (tok.get("_lying") as Sprite3D).visible or (tok.sprite != null and tok.sprite.pose == "down")


func _plates() -> Array[String]:
	var labels := (root.get("hud") as ExploreHud).thing_labels
	labels.pinned = true
	var texts: Array[String] = []
	for p in labels.plates():
		texts.append(str(p["text"]))
	labels.pinned = false
	return texts


func _assert_asleep_on_the_floor() -> void:
	var tok := _token()
	assert_true(tok != null, "Offalia is still in the bakery")
	assert_eq(_view().grid.cell_at(tok.position), FLOOR, "she lies where she sat down, not at the oven")
	var cr := tok.combatant.creature
	for cond: StringName in [&"unconscious", &"incapacitated", &"prone"]:
		assert_true(cr.has_condition(cond), "asleep means %s (got %s)" % [cond, cr.active_conditions()])
	assert_true(_lying(tok), "her figure is drawn lying down")
	var chips := (tok.get("_status") as Label3D).text
	assert_true(chips.contains("Prone") and chips.contains("Unconscious"), "her conditions show over her (got %s)" % chips)
	assert_true(LocationNpcs.is_asleep(_view(), OFFALIA))
	assert_eq(LocationNpcs.state_words(_view(), OFFALIA), "asleep, prone")
	var thing := _view().thing_at(FLOOR)
	assert_eq(str(thing.get("id", "")), OFFALIA)
	assert_eq(str(thing["label"]), "Offalia Wormwiggle (asleep, prone)", "the hover hint says so")
	assert_eq(str((thing["spec"] as Dictionary)["dialogue"]), "old_bonegrinder/offalia:asleep", "talking to her finds her asleep")
	var menu := _view().actions_at(FLOOR)
	assert_eq(str(menu["title"]), "Offalia Wormwiggle")
	assert_eq(str(((menu["actions"] as Array)[0] as Dictionary)["label"]), "Approach", "nobody offers to chat with a sleeper")
	var said: Array[String] = []
	var hear := func(text: String) -> void: said.append(text)
	_view().narration.connect(hear)
	_view().act(FLOOR, "look")
	_view().narration.disconnect(hear)
	assert_true(said.size() == 1 and said[0].ends_with("Asleep: Unconscious and Prone."), "Look says so (got %s)" % [said])
	assert_true(_view().thing_at(OVEN).is_empty(), "nobody stands at the oven")


func test_the_dream_pastry_lays_offalia_down_asleep() -> void:
	var tok := _token()
	assert_true(tok != null and _view().grid.cell_at(tok.position) == OVEN, "she starts at the oven")
	assert_false(tok.combatant.creature.has_condition(&"prone"))
	assert_false(_lying(tok), "awake, she stands")
	assert_eq(LocationNpcs.state_words(_view(), OFFALIA), "")
	GameState.story.give_item("dream_pastry", 1, GameState.story.party[0])
	root.call("start_dialogue", "old_bonegrinder/offalia:feed", OFFALIA)
	await _frames(2)
	await _finish_dialogue()
	assert_true(bool(GameState.story.get_flag("offalia_asleep")), "the pastry put her to sleep")
	_assert_asleep_on_the_floor()
	assert_true(_plates().has("Offalia Wormwiggle · asleep, prone"), "Alt names her asleep (got %s)" % [_plates()])


func test_a_blow_or_a_shake_would_wake_her_still_prone() -> void:
	var m := Monster.from_data(Compendium.shared().monster_data("night_hag"))
	LocationNpcs.put_to_sleep(m)
	var nap: Effect = null
	for fx in m.effects:
		if bool(fx.data.get("wakeable", false)):
			nap = fx
	assert_true(nap != null and nap.ends_on_damage, "a blow or the Wake action ends it")
	m.remove_effect(nap)
	assert_false(m.has_condition(&"unconscious"))
	assert_true(m.has_condition(&"prone"), "a sleeper wakes on the floor")


func test_she_sleeps_on_after_a_save_and_load() -> void:
	GameState.story.set_flag("offalia_met")
	GameState.story.set_flag("offalia_asleep")
	_view().refresh_npcs()
	await _frames(2)
	_assert_asleep_on_the_floor()
	assert_eq(SaveSystem.save("test_sleeping"), OK)
	root.queue_free()
	await _frames(2)
	GameState.reset()
	assert_eq(SaveSystem.load_slot("test_sleeping"), OK)
	await _start_game()
	_assert_asleep_on_the_floor()
