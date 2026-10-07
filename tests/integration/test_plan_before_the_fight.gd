extends TestCase
## Plan before the fight (F7, docs/rules/stealth.md) on a fixture hall: turn-based exploring (each member moves up to
## their Speed a round, one at a time; ending the round gives the movement back), foes waiting in plain view that show
## once seen and notice the party, and a fight opened by the party with 2024 Surprise and members starting it hidden.

const LOC := {
	"id": "test_plan_hall", "name": "Plan Hall", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"##############",
		"#.....#......#",
		"#.....#......#",
		"#............#",
		"#.....#......#",
		"#.....#......#",
		"##############"], "light": "bright"},
	"areas": [{"id": "den", "name": "Den", "cells": [[10, 1], [12, 5]]}],
	"spawns": {"default": [3, 3]},
	"doors": [{"id": "den_door", "cell": [6, 3]}],
	"encounters": [{"id": "den_wolf", "trigger": "enter_area:den", "waiting": true,
		"monsters": [{"monster": "wolf", "cell": [11, 2]}], "flag": "test_den_wolf_dead"}]
}

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_plan_hall"] = LOC.duplicate(true)
	GameSettings.set_turn_based(false)
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_plan_hall"
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	# Everyone where the test wants them: the leader in the doorway's line, the rest in the west room.
	var v := _view()
	var cells: Array[Vector2i] = [Vector2i(3, 3), Vector2i(2, 2), Vector2i(2, 4), Vector2i(1, 3)]
	for i in v.members.size():
		v.members[i].cell = cells[i]
		(v.tokens[v.members[i].id] as Node3D).position = v.board.cell_center(cells[i])


func after_each() -> void:
	GameSettings.set_turn_based(false)
	Compendium.shared().tables["locations"].erase("test_plan_hall")
	if root != null:
		root.queue_free()
		root = null
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func _walk_until_idle() -> void:
	for i in 600:
		if _view()._queue.is_empty():
			return
		await get_tree().process_frame


## Every member's Stealth while sneaking, set rather than rolled.
func _sneak_with(total: int) -> void:
	var v := _view()
	v.set_sneaking(true)
	for m: Combatant in v.members + v.guest_members:
		v.sneak_totals[m.creature] = total


func test_turn_based_moves_one_member_within_their_speed_a_round() -> void:
	var v := _view()
	root.call("_command", "plan")
	assert_true(v.planning, "T or the hotbar's button switches it on")
	assert_true(GameSettings.turn_based(), "and the choice is kept")
	assert_eq(v.plan_round, 1)
	var lead := v.leader()
	var speed := lead.speed()
	assert_eq(LocationPlan.left_ft(v, lead), speed)
	var others: Array[Vector2i] = []
	for m: Combatant in v.members.slice(1):
		others.append(m.cell)
	# Too far for one round: refused, nobody moves.
	assert_false(v.walk_to(Vector2i(3 + speed / 5 + 1, 3)), "beyond this round's movement")
	# Within it: only the leader walks, and it comes off their movement.
	assert_true(v.walk_to(Vector2i(5, 3)))
	await _walk_until_idle()
	assert_eq(lead.cell, Vector2i(5, 3))
	assert_eq(LocationPlan.left_ft(v, lead), speed - 10)
	for i in others.size():
		assert_eq(v.members[i + 1].cell, others[i], "the others stay where they were placed")
	# Nobody stops on a companion's square.
	assert_false(v.walk_to(Vector2i(2, 2)), "a companion stands there")
	# The round ends: movement back, and every ten rounds a minute passes.
	var minutes := GameState.story.total_minutes()
	root.call("_command", "plan_round")
	assert_eq(v.plan_round, 2)
	assert_eq(LocationPlan.left_ft(v, lead), speed)
	for i in 9:
		v.next_round()
	assert_eq(GameState.story.total_minutes(), minutes + 1, "ten rounds of six seconds")
	# Picking who moves (1-4 or Tab) moves them alone.
	v.set_leader(1)
	var mover := v.leader()
	assert_true(v.walk_to(Vector2i(2, 1)))
	await _walk_until_idle()
	assert_eq(mover.cell, Vector2i(2, 1))
	assert_eq(lead.cell, Vector2i(5, 3), "the one who moved first stays put")
	root.call("_command", "plan")
	assert_false(v.planning, "back to real time")
	assert_false(v.solo, "and the party follows the leader again")
	assert_false(GameSettings.turn_based())


func test_passing_through_a_companion_costs_double() -> void:
	var v := _view()
	v.toggle_plan()
	var path: Array[Vector2i] = [Vector2i(3, 3), Vector2i(2, 3), Vector2i(1, 3), Vector2i(1, 2)]
	assert_eq(LocationPlan.path_ft(v, v.leader(), path), 20, "5 + 10 through Silvain's square + 5")


func test_a_waiting_foe_shows_once_seen_and_can_be_attacked() -> void:
	var v := _view()
	_sneak_with(30)
	assert_eq(v.waiting.size(), 1, "the den's wolf waits there")
	assert_false(LocationStealth.is_shown(v.waiting[0]), "behind the closed door it can't be seen")
	assert_true(v.thing_at(Vector2i(11, 2)).is_empty())
	assert_true(v.walk_to(Vector2i(7, 3)))
	await _walk_until_idle()
	assert_false(v.in_combat, "a sneaking party it doesn't notice walks on")
	assert_true(LocationStealth.is_shown(v.waiting[0]), "through the open door the wolf shows")
	var thing := v.thing_at(Vector2i(11, 2))
	assert_eq(str(thing.get("kind", "")), "foe")
	var ids: Array = (v.actions_at(Vector2i(11, 2))["actions"] as Array).map(func(a: Dictionary) -> String: return str(a["id"]))
	assert_true("strike" in ids, "Attack: start the fight")
	assert_true(v.grid.has_flag(Vector2i(11, 2), CombatGrid.LOW), "nobody walks through it")


func test_a_party_walking_openly_is_noticed_and_the_fight_starts() -> void:
	var v := _view()
	assert_true(v.walk_to(Vector2i(8, 3)))
	await _walk_until_idle()
	assert_true(v.in_combat, "the wolf sees the party come through the door")
	await _frames(3)
	for c in v.combat_view.e.combatants:
		assert_false(c.surprised, "%s isn't surprised: the foe started it" % c.name())
	assert_true(v.leader().cell.x < 10, "before the party reached the den itself")


func test_a_sneaker_it_beats_is_noticed() -> void:
	var v := _view()
	_sneak_with(1)
	assert_true(v.walk_to(Vector2i(8, 3)))
	await _walk_until_idle()
	assert_true(v.in_combat, "the wolf's passive Perception beats a Stealth of 1")
	await _frames(3)
	for c in v.combat_view.e.combatants:
		assert_false(c.surprised)


func test_a_sneaking_party_strikes_with_surprise_and_hidden_members() -> void:
	var v := _view()
	_sneak_with(30)
	v.toggle_plan()
	# Tamsin slips behind the wall north of the door; the leader goes to the doorway's far side.
	v.set_leader(1)
	assert_true(v.walk_to(Vector2i(5, 1)))
	await _walk_until_idle()
	var tucked := v.leader()
	v.set_leader(1)
	assert_true(v.walk_to(Vector2i(7, 3)))
	await _walk_until_idle()
	var exposed := v.leader()
	assert_false(v.in_combat)
	assert_true(LocationStealth.is_shown(v.waiting[0]))
	var wolf_token := v.waiting[0]["token"] as CombatToken
	root.call("_command", "strike")
	await _frames(3)
	assert_true(v.in_combat, "the party opens the fight")
	assert_false(v.planning, "turn-based stops for the fight")
	var e := v.combat_view.e
	for c in e.combatants:
		if c.side == &"enemy":
			assert_true(c.surprised, "the wolf noticed nobody: Disadvantage on Initiative")
			assert_true("Surprised" in c.initiative_test.disadvantage_sources)
			assert_eq(v.combat_view.tokens[c.id], wolf_token, "it keeps the figure it had while waiting")
		elif c.creature == tucked.creature:
			assert_true(c.hidden, "behind the wall with Stealth 30: starts hidden")
			assert_true(c.creature.has_condition(&"invisible"))
		elif c.creature == exposed.creature:
			assert_false(c.hidden, "in the open, so not hidden")
	assert_true(v.waiting.is_empty(), "its foes are in the fight now")
	# The fight ends: nobody stays hidden, and turn-based comes back as the player left it.
	GameSettings.set_turn_based(true)
	for c in e.combatants:
		if c.side == &"enemy":
			e.deal_damage(null, c, [{"amount": 100, "type": "slashing"}], false, "test")
	v.combat_view.finished.emit("victory")
	await _frames(3)
	assert_false(tucked.creature.has_condition(&"invisible"), "the Invisible condition from hiding ends with the fight")
	assert_true(v.planning, "turn-based again after the fight")


func test_a_party_that_isnt_sneaking_surprises_nobody() -> void:
	var v := _view()
	var e := LocationStealth.watch(v)
	assert_true(LocationStealth.surprised_at_start(v, e).is_empty(), "heard coming")
	_sneak_with(30)
	assert_eq(LocationStealth.surprised_at_start(v, e).size(), 1, "sneaking, the unaware wolf is surprised")


func test_dim_light_lowers_passive_perception() -> void:
	var v := _view()
	var e := LocationStealth.watch(v)
	var wolf := v.waiting[0]["foe"] as Combatant
	var lead := v.leader()
	var plain := wolf.creature.passive_score(&"perception").total()
	e.ambient_light = "dim"
	# The wolf's Darkvision sees dim light as bright: no penalty within 60 ft.
	assert_eq(LocationStealth.passive_perception(e, wolf, lead), plain)
	wolf.creature.base_senses.erase("darkvision")
	assert_eq(LocationStealth.passive_perception(e, wolf, lead), plain - 5, "without it, Lightly Obscured: 5 lower")
	e.ambient_light = "bright"
	assert_eq(LocationStealth.passive_perception(e, wolf, lead), plain)


func test_the_settings_row_and_a_new_place_keep_the_choice() -> void:
	GameSettings.set_turn_based(true)
	root.call("enter_location", "test_plan_hall", "default")
	await _frames(3)
	assert_true(_view().planning, "a place entered with turn-based on starts in rounds")
	assert_true((root.get("plan_bar") as PlanBar).get_child(0) is PanelContainer)
	await _frames(2)
	assert_true(((root.get("plan_bar") as PlanBar).get_child(0) as Control).visible, "its panel shows")
