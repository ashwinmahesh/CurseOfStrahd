extends TestCase
## Stealing and crime (F8) and the town watch (F2's watch; docs/rules/stealth.md) in a fixture shop in Vallaki: an
## owned till, a shopkeeper who sees or doesn't, picking a pocket, a private back room, and the watch's dialogue that
## fines the party and clears the record.

const LOC := {
	"id": "test_crime_shop", "name": "Crime Shop", "region": "vallaki", "summary": "A fixture.",
	"map": {"rows": [
		"################",
		"#.......#......#",
		"#.......#......#",
		"#..............#",
		"#.......#......#",
		"#.......#......#",
		"################"], "light": "bright"},
	"areas": [{"id": "back_room", "name": "Back room", "cells": [[9, 1], [14, 5]], "private": "urwin_martikov"}],
	"spawns": {"default": [2, 3]},
	"containers": [
		{"id": "till", "cell": [5, 1], "label": "Till", "owner": "urwin_martikov", "items": [{"id": "dagger", "qty": 1}], "gold": 10},
		{"id": "crate", "cell": [5, 5], "label": "Crate", "items": [{"id": "dagger", "qty": 1}], "gold": 0}],
	"npcs": [{"npc": "urwin_martikov", "cell": [6, 3]}],
	"encounters": [{"id": "watch_arrest", "trigger": "dialogue", "monsters": [{"monster": "vallaki_guard", "cell": [3, 1]}]}]
}

var root: Node
var requested: Array[String] = []


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_crime_shop"] = LOC.duplicate(true)
	GameSettings.set_turn_based(false)
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_crime_shop"
	GameState.story.gold = 100.0
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	requested.clear()
	_view().dialogue_requested.connect(func(ref: String, _npc: String) -> void: requested.append(ref))


func after_each() -> void:
	Compendium.shared().tables["locations"].erase("test_crime_shop")
	if root != null:
		root.queue_free()
		root = null
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func _urwin() -> Combatant:
	return (_view().npc_tokens["urwin_martikov"] as CombatToken).combatant


func _place_leader(cell: Vector2i) -> void:
	_view().leader().cell = cell


func test_the_till_says_whose_it_is() -> void:
	var v := _view()
	assert_true(str(v.thing_at(Vector2i(5, 1))["label"]).contains("Urwin's: taking is stealing"))
	assert_false(str(v.thing_at(Vector2i(5, 5))["label"]).contains("stealing"), "the crate is nobody's")


func test_stealing_in_sight_brings_the_watch() -> void:
	var v := _view()
	_place_leader(Vector2i(5, 2))
	var before := GameState.story.attitude("urwin_martikov")
	LocationCrime.after_loot(v, "till", 15.0)
	assert_eq(int(GameState.story.get_flag("crime_vallaki", 0)), 1, "the offence counts")
	assert_ne(GameState.story.attitude("urwin_martikov"), before, "Urwin thinks less of the party")
	assert_true("watch/vallaki:theft" in requested, "a watchman comes for the party")
	assert_true(v._staged.has("vallaki_guard"), "standing beside it")
	var arrest := LocationFights.spec_for(v, "watch_arrest")
	assert_true(bool(arrest.get("arrest", false)), "the fight a refusal starts is set up here, next to the party")


func test_taking_from_what_nobody_owns_or_nobody_sees_is_free() -> void:
	var v := _view()
	_place_leader(Vector2i(5, 4))
	LocationCrime.after_loot(v, "crate", 2.0)
	assert_eq(int(GameState.story.get_flag("crime_vallaki", 0)), 0, "nobody owns the crate")
	# Behind the wall, out of Urwin's sight.
	_place_leader(Vector2i(10, 1))
	_urwin().cell = Vector2i(2, 1)
	LocationCrime.after_loot(v, "till", 15.0)
	assert_eq(int(GameState.story.get_flag("crime_vallaki", 0)), 0, "nobody saw")
	assert_true(requested.is_empty())


func test_sneaking_past_a_shopkeeper_it_beats() -> void:
	var v := _view()
	_place_leader(Vector2i(5, 2))
	v.set_sneaking(true)
	for m: Combatant in v.members:
		v.sneak_totals[m.creature] = 40
	LocationCrime.after_loot(v, "till", 15.0)
	assert_eq(int(GameState.story.get_flag("crime_vallaki", 0)), 0, "a Stealth of 40 beats Urwin's passive Perception")


func test_picking_a_pocket() -> void:
	var v := _view()
	_place_leader(Vector2i(5, 3))
	var ids: Array = (v.actions_at(Vector2i(6, 3))["actions"] as Array).map(func(a: Dictionary) -> String: return str(a["id"]))
	assert_true("pickpocket" in ids, "on the right-click menu")
	# A pocket the thief can't miss: the lift succeeds, and Urwin, the only one here, never knew.
	_urwin().set_meta("passive_perception", 0)
	var gold := GameState.story.gold
	LocationCrime.pickpocket(v, "urwin_martikov")
	assert_true(GameState.story.gold >= gold, "coins from his purse")
	assert_eq(int(GameState.story.get_flag("crime_vallaki", 0)), 0, "nobody else saw")
	var again := LocationCrime.pickpocket_action(v, "urwin_martikov")
	assert_false(bool(again["enabled"]), "a pocket is picked once")


func test_a_caught_hand_is_a_crime() -> void:
	var v := _view()
	_place_leader(Vector2i(5, 3))
	_urwin().set_meta("passive_perception", 99)
	LocationCrime.pickpocket(v, "urwin_martikov")
	assert_eq(int(GameState.story.get_flag("crime_vallaki", 0)), 1, "Urwin caught the hand")
	assert_true("watch/vallaki:theft" in requested)


func test_nobody_picks_the_pocket_of_the_dead_or_a_foe() -> void:
	assert_ne(Crime.why_no_pocket(GameState.story, "strahd", false), "", "Strahd's own")
	GameState.story.attitudes["urwin_martikov"] = "hostile"
	assert_ne(Crime.why_no_pocket(GameState.story, "urwin_martikov", false), "", "a foe won't let you close")


func test_a_private_room_warns_then_it_is_trespass() -> void:
	var v := _view()
	_urwin().cell = Vector2i(8, 3)
	_place_leader(Vector2i(10, 3))
	assert_true(LocationCrime.check_trespass(v), "seen in the back room: told to leave")
	assert_eq(int(GameState.story.get_flag("crime_vallaki", 0)), 0, "only a warning")
	for i in LocationCrime.TRESPASS_GRACE:
		assert_false(LocationCrime.check_trespass(v), "steps to get out")
	assert_true(LocationCrime.check_trespass(v), "still there after that")
	assert_eq(int(GameState.story.get_flag("crime_vallaki", 0)), 1, "trespass")
	assert_true("watch/vallaki:trespass" in requested)


func test_the_watch_fines_and_clears_the_record() -> void:
	var st := GameState.story
	st.set_flag("crime_vallaki", 1)
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start("watch/vallaki:theft"))
	var b := r.next()
	while str(b["kind"]) != "options":
		b = r.next()
	var pay := -1
	var options := b["options"] as Array
	for i in options.size():
		if str((options[i] as Dictionary)["text"]).contains("twenty-five"):
			pay = i
	assert_true(pay >= 0, "the first offence costs twenty-five gold")
	b = r.choose(pay)
	while str(b["kind"]) != "end":
		b = r.next()
	assert_eq(st.gold, 75.0)
	assert_eq(int(st.get_flag("crime_vallaki", 0)), 0, "paid: the record is clear")
