extends TestCase
## A dead hero on the map (owner report, 2026-10-14: "When a party member dies, I shouldn't be able to play as them when
## moving around the overworld"): they stay in the party (the roster, the sheet, revival) but never lead, can't be picked
## to lead, aren't drawn walking about or marked on the minimap, and the rest of the party carries on without them.

const LOC := {
	"id": "test_dead_hall", "name": "Test Dead Hall", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"################",
		"#.......#......#",
		"#..............#",
		"#.......#......#",
		"################"], "light": "dim"},
	"spawns": {"default": [2, 2]},
	"doors": [{"id": "mid_door", "cell": [8, 2]}],
	"rest": "risky",
	"npcs": [{"npc": "ismark", "cell": [13, 2], "dialogue": "test/dead_hall:start"}],
}

const DIALOGUE := """
~ start
Ismark: Hello.
set test_dead_hall_spoke
-> END
"""

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_dead_hall"] = LOC.duplicate(true)
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/dead_hall"))
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_dead_hall"
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


func after_each() -> void:
	Compendium.shared().tables["locations"].erase("test_dead_hall")
	if root != null:
		root.queue_free()
		root = null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


## Kills party member `i` the way a fight leaves them: 0 Hit Points and dead, still on the roster.
func _kill(i: int) -> Character:
	var ch := GameState.story.party[i]
	ch.hp = 0
	ch.dead = true
	return ch


func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	root.call("_unhandled_input", ev)


func _walk(v: LocationView, cell: Vector2i) -> void:
	assert_true(v.walk_to(cell), "a way to %s" % cell)
	for i in 600:
		if (v.get("_queue") as Array).is_empty():
			break
		await get_tree().process_frame
	await _frames(2)


func test_tab_passes_over_the_dead() -> void:
	var v := _view()
	var first := GameState.story.party[0]
	var dead := _kill(1)
	var third := GameState.story.party[2]
	_press(&"cycle_leader")
	await _frames(1)
	assert_eq(v.leader().creature, third, "Tab goes on to the next hero who is alive")
	assert_eq(GameState.story.party[0], third)
	assert_eq(GameState.story.leader_character(), third, "and they are the one who speaks")
	assert_true(dead in GameState.story.party, "the dead hero is still in the party")
	assert_eq(GameState.story.party.size(), 4)
	assert_true(first in GameState.story.party)


func test_a_dead_hero_cannot_be_picked_to_lead() -> void:
	var v := _view()
	var lead := v.leader().creature
	var dead := _kill(2)
	_press(&"select_member_3")
	v.set_leader(2)
	await _frames(1)
	assert_eq(v.leader().creature, lead, "number keys, the party panel and the menu all go through set_leader")
	assert_true(dead in GameState.story.party)
	# Right-clicking them offers their sheet but not the lead.
	var at := v.members[2].cell
	var lead_action: Dictionary = {}
	for a: Dictionary in v.actions_at(at)["actions"]:
		if str(a["id"]) == "lead:2":
			lead_action = a
	assert_false(lead_action.is_empty(), "the menu still lists them")
	assert_false(bool(lead_action.get("enabled", true)), "but they can't be made to lead")
	var ids: Array = (v.actions_at(at)["actions"] as Array).map(func(a: Dictionary) -> String: return str(a["id"]))
	assert_true("sheet:2" in ids, "their sheet is still there")


func test_the_lead_passes_on_when_the_leader_dies() -> void:
	var v := _view()
	var dead := _kill(0)
	await _frames(3)
	var lead := v.leader().creature
	assert_false(lead.dead, "a living hero leads")
	assert_eq(lead, GameState.story.party[0])
	assert_eq(GameState.story.leader_character(), lead)
	assert_true(dead in GameState.story.party and v.members.any(func(m: Combatant) -> bool: return m.creature == dead),
		"the dead hero is still in the party and on the map's roster")
	assert_eq(v.rig.follow, v.tokens[v.leader().id], "the camera follows the new leader")


func test_a_dead_leader_in_a_loaded_party_is_replaced() -> void:
	# A save (or a fight) that left a dead hero first in the marching order.
	root.queue_free()
	await _frames(1)
	_kill(0)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(4)
	var v := _view()
	assert_false(v.leader().creature.dead)
	assert_eq(GameState.story.party.size(), 4)


func test_a_dead_hero_is_not_drawn_or_marked() -> void:
	var v := _view()
	var dead := _kill(1)
	var tok := v.tokens[v.members[1].id] as CombatToken
	tok.refresh()
	await get_tree().create_timer(0.9).timeout
	assert_true(dead.dead)
	assert_true(tok.sprite == null or tok.sprite.modulate.a < 0.05, "no figure to see")
	assert_false(tok.get_node("Ring").visible if tok.has_node("Ring") else false)
	var mm := Minimap.new()
	add_child(mm)
	mm.show_location(v)
	var shown := mm.party_shown()
	assert_eq(shown.size(), 3, "the minimap marks the three who are up")
	assert_false(shown.any(func(m: Combatant) -> bool: return m.creature == dead))
	assert_eq(shown[0], v.leader(), "leader first")
	mm.queue_free()


func test_the_dead_stay_put_and_the_line_closes_up() -> void:
	var v := _view()
	var dead := _kill(1)
	var dead_cell := v.members[1].cell
	var behind := v.members[2]
	await _walk(v, Vector2i(9, 2))
	assert_eq(v.leader().cell, Vector2i(9, 2))
	assert_eq(v.members[1].cell, dead_cell, "the dead hero doesn't walk")
	assert_true(dead.dead)
	assert_true(behind.cell.distance_to(Vector2(v.leader().cell)) <= 2.0, "the next hero still follows the leader (at %s)" % behind.cell)
	assert_true(v.members[3].cell.distance_to(Vector2(v.leader().cell)) <= 3.0, "and so does the last (at %s)" % v.members[3].cell)


func test_doors_and_conversations_work_with_a_dead_hero() -> void:
	var v := _view()
	var dead := _kill(1)
	assert_true(v.grid.has_flag(Vector2i(8, 2), CombatGrid.WALL), "a closed door in the way")
	await _walk(v, Vector2i(12, 2))
	assert_eq(v.leader().cell, Vector2i(12, 2), "the party opened it and went through")
	assert_false(v.grid.has_flag(Vector2i(8, 2), CombatGrid.WALL))
	assert_true(dead.dead and dead in GameState.story.party)
	root.call("start_dialogue", "test/dead_hall:start", "ismark")
	await _frames(2)
	var d := root.get("dialogue") as DialogueUI
	assert_true(d != null)
	assert_false(GameState.story.leader_character().dead, "a living hero speaks for the party")
	for i in 5:
		if root.get("dialogue") == null:
			break
		d.call("_advance")
		await _frames(1)
	assert_true(bool(GameState.story.get_flag("test_dead_hall_spoke")))


func test_camp_works_with_a_dead_hero() -> void:
	GameState.story.options["difficulty"] = "story"
	GameState.story.minute_of_day = 20 * 60
	var dead := _kill(1)
	var v := _view()
	root.call("open_screen", "rest", 0)
	await _frames(1)
	var make: Button = null
	for b in (root.get("screen") as Node).find_children("*", "Button", true, false):
		if (b as Button).text == "Make camp (8 hours)" and not b.is_queued_for_deletion():
			make = b as Button
	assert_true(make != null and not make.disabled, "the Long Rest makes camp")
	if make != null:
		make.pressed.emit()
	await _frames(2)
	var camp := LocationCamp.of(v)
	assert_true(camp != null, "camp is made")
	if camp != null:
		assert_false(camp.people.has(v.members[1].id), "nobody sits the dead by the fire")
		for m in v.members:
			if m.creature != dead:
				assert_true(camp.people.has(m.id), "%s is by the fire" % m.name())
	assert_false(v.leader().creature.dead)
	assert_true(dead in GameState.story.party)


func test_the_whole_party_dead_changes_nothing() -> void:
	var v := _view()
	for i in 4:
		_kill(i)
	var order: Array = GameState.story.party.duplicate()
	await _frames(3)
	assert_eq(GameState.story.party, order, "the game over's business, not the lead's")
	assert_eq(GameState.story.party.size(), 4)
