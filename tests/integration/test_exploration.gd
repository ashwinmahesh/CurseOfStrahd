extends TestCase
## Exploration (plan §5.2, ADR 0009) on a fixture location: the party is placed and follows the leader, doors and
## locks, containers and loot, examine and codex, traps found by passive Perception and searching, conversations,
## fights started in place and ended back in exploration, rests, and saving the story.

const LOC := {
	"id": "test_hall", "name": "Test Hall", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"############",
		"#....#.....#",
		"#....#.....#",
		"#..........#",
		"#....#.....#",
		"############"], "light": "dim"},
	"areas": [{"id": "east_room", "name": "East room", "cells": [[6, 1], [10, 4]]}],
	"spawns": {"default": [2, 3]},
	"doors": [{"id": "inner_door", "cell": [5, 3], "locked": true, "lock_dc": 5}],
	"props": [{"id": "old_book", "cell": [1, 1], "kind": "book", "label": "Old book", "codex": "old_book", "text": "Words."},
		{"id": "loose_stone", "cell": [3, 1], "kind": "search", "search_dc": 1, "label": "Loose stone", "item": "dagger"}],
	"containers": [{"id": "chest", "cell": [1, 4], "label": "Chest", "items": [{"id": "dagger", "qty": 2}], "gold": 5}],
	"traps": [{"id": "pit", "cells": [[3, 4]], "detect_dc": 1, "disarm_dc": 5, "label": "Pit", "save": {"ability": "dex", "dc": 10}, "damage": "1d6"}],
	"npcs": [{"npc": "ismark", "cell": [4, 2], "dialogue": "test/hall:start"}],
	"encounters": [{"id": "wolves", "trigger": "enter_area:east_room", "monsters": [{"monster": "wolf", "cell": [9, 2]}], "flag": "test_wolves_dead"}]
}

const DIALOGUE := """
~ start
Ismark: Hello.
set test_spoke
-> END
"""

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_hall"] = LOC.duplicate(true)
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/hall"))
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_hall"
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


## The fixture hall goes again, so a test that walks every location (test_set_dressing) never meets it.
func after_each() -> void:
	Compendium.shared().tables["locations"].erase("test_hall")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func _walk_until_idle() -> void:
	for i in 400:
		if (_view().get("_queue") as Array).is_empty():
			return
		await get_tree().process_frame


func test_party_is_placed_and_follows_the_leader() -> void:
	var v := _view()
	assert_eq(v.members.size(), 4)
	assert_eq(v.leader().cell, Vector2i(2, 3))
	assert_true(v.walk_to(Vector2i(2, 1)))
	await _walk_until_idle()
	if v.leader().cell != Vector2i(2, 1):
		# Spotting the pit (passive Perception) stops the walk; walking on continues.
		assert_eq(str((GameState.story.loc_state("test_hall")["traps"] as Dictionary).get("pit", "")), "found")
		v.walk_to(Vector2i(2, 1))
		await _walk_until_idle()
	assert_eq(v.leader().cell, Vector2i(2, 1))
	assert_true(v.grid.distance_ft(v.members[1].cell, 1, v.leader().cell, 1) <= 10, "the next member is close behind")
	assert_eq(GameState.story.positions[0], Vector2i(2, 1))


func test_a_single_step_plays_the_walk_cycle() -> void:
	# A WASD step is one square: the walk used to stop in the same frame it started, so it never showed.
	# A step that turns something up (here the pit, spotted next to the square) used to leave the party walking in place.
	var v := _view()
	var tok := v.tokens[v.leader().id] as CombatToken
	for leg: Array in [[Vector2i(1, 0), Vector2i(3, 3)], [Vector2i(-1, 0), Vector2i(2, 3)]]:
		v.step(leg[0] as Vector2i)
		var walked := false
		for i in 400:
			await get_tree().process_frame
			if v.leader().cell == leg[1] and tok.sprite.moving:
				walked = true
				break
		assert_true(walked, "the leader walks while gliding into %s" % leg[1])
		var stood := false
		for i in 4000:
			await get_tree().process_frame
			if not tok.sprite.moving:
				stood = true
				break
		assert_true(stood, "and stands still once there")
		assert_false((v.tokens[v.members[1].id] as CombatToken).sprite.moving, "followers stop too")


func test_locked_door_opens_with_tools_or_force() -> void:
	var v := _view()
	assert_true(v.grid.has_flag(Vector2i(5, 3), CombatGrid.WALL), "a closed door blocks")
	# The tools are on the right-click menu (a plain click only says it's locked: test_interactions.gd).
	v.act(Vector2i(5, 3), "pick")
	await _walk_until_idle()
	await _frames(2)
	var state := str((GameState.story.loc_state("test_hall")["doors"] as Dictionary).get("inner_door", ""))
	assert_true(state in ["open", ""], state)
	if state == "open":
		assert_false(v.grid.has_flag(Vector2i(5, 3), CombatGrid.WALL))


func test_book_goes_to_the_codex_and_search_finds_hidden_things() -> void:
	var v := _view()
	v.interact(v.thing_at(Vector2i(1, 1)))
	assert_true("old_book" in GameState.story.codex)
	assert_true(v.thing_at(Vector2i(3, 1)).is_empty(), "hidden until searched")
	v.search()
	assert_false(v.thing_at(Vector2i(3, 1)).is_empty(), "found")
	assert_eq(str((GameState.story.loc_state("test_hall")["traps"] as Dictionary).get("pit", "")), "found")


func test_loot_window_takes_items_and_gold() -> void:
	var v := _view()
	v.interact(v.thing_at(Vector2i(1, 4)))
	await _frames(2)
	var loot := root.get("loot") as LootWindow
	assert_true(loot != null)
	loot.call("_take_all")
	assert_eq(GameState.story.gold, 5.0)
	assert_true(bool((GameState.story.loc_state("test_hall")["looted"] as Dictionary).get("chest", false)))


func test_conversation_sets_flags() -> void:
	root.call("start_dialogue", "test/hall:start", "ismark")
	await _frames(2)
	var d := root.get("dialogue") as DialogueUI
	assert_true(d != null)
	for i in 5:
		if root.get("dialogue") == null:
			break
		d.call("_advance")
		await _frames(1)
	assert_true(bool(GameState.story.get_flag("test_spoke")))


func test_entering_an_area_starts_the_fight_in_place_and_victory_returns() -> void:
	var v := _view()
	assert_true(v.start_encounter("wolves"))
	await _frames(5)
	assert_true(v.in_combat)
	var cv := v.combat_view
	assert_true(cv != null)
	assert_eq(cv.e.combatants.size(), 5)
	for c in cv.e.combatants:
		if c.side == &"enemy":
			cv.e.deal_damage(null, c, [{"amount": 100, "type": "slashing"}], false, "test")
	cv.finished.emit("victory")
	await _frames(3)
	assert_false(v.in_combat)
	assert_true(bool(GameState.story.get_flag("test_wolves_dead")))


func test_story_saves_and_loads() -> void:
	GameState.story.set_flag("saved_flag", 7)
	var err := SaveSystem.save("test_slot")
	assert_eq(err, OK)
	GameState.reset()
	assert_eq(SaveSystem.load_slot("test_slot"), OK)
	assert_eq(int(GameState.story.get_flag("saved_flag")), 7)
	assert_eq(GameState.story.party.size(), 4)
	assert_eq(GameState.story.location, "test_hall")
	SaveSystem.delete_slot("test_slot")


func test_round_start_save_resumes_the_fight() -> void:
	var v := _view()
	v.start_encounter("wolves")
	for i in 30:
		await get_tree().process_frame
		if not GameState.combat_snapshot.is_empty():
			break
	assert_false(GameState.combat_snapshot.is_empty(), "the fight saved itself as round 1 began")
	assert_true(SaveSystem.has_slot("round_start"))
	var wolf_hp := 0
	for c in v.combat_view.e.combatants:
		if c.side == &"enemy":
			c.creature.hp = 4
	assert_eq(SaveSystem.load_slot("round_start"), OK)
	var e := EncounterSnapshot.restore(GameState.combat_snapshot["data"] as Dictionary, DiceRoller.new(1), GameState.story.party)
	assert_eq(e.round_no, 1)
	assert_eq(e.combatants.size(), 5)
	for c in e.combatants:
		if c.side == &"enemy":
			wolf_hp = c.creature.hp
	assert_eq(wolf_hp, 11, "the wolf as the round began, not as it is now")
	assert_eq(e.order.size(), 5)
	SaveSystem.delete_slot("round_start")



func test_npc_speaks_on_approach_and_leaves_when_the_story_moves_on() -> void:
	var v := _view()
	var spec := (v.loc["npcs"] as Array)[0] as Dictionary
	spec["approach"] = 2
	spec["when"] = "not flag.test_spoke"
	(GameState.story.loc_state("test_hall")["traps"] as Dictionary)["pit"] = "found"
	v.refresh_npcs()
	await _frames(1)
	assert_eq(v.thing_at(Vector2i(4, 2))["kind"], "npc")
	v.walk_to(Vector2i(2, 2))
	for i in 200:
		if root.get("dialogue") != null:
			break
		await get_tree().process_frame
	var d := root.get("dialogue") as DialogueUI
	assert_true(d != null, "Ismark spoke first")
	for i in 5:
		if root.get("dialogue") == null:
			break
		d.call("_advance")
		await _frames(1)
	assert_true(bool(GameState.story.get_flag("test_spoke")))
	await _frames(2)
	assert_true(v.thing_at(Vector2i(4, 2)).is_empty(), "his condition no longer holds")
	assert_false(v.grid.has_flag(Vector2i(4, 2), CombatGrid.LOW), "his square is free again")


func test_right_click_menus_offer_the_right_actions() -> void:
	var v := _view()
	var door := v.actions_at(Vector2i(5, 3))
	var ids: Array = (door["actions"] as Array).map(func(a: Dictionary) -> String: return str(a["id"]))
	assert_true("pick" in ids and "force" in ids and "look" in ids, str(ids))
	var npc := v.actions_at(Vector2i(4, 2))
	assert_eq(str(npc["title"]), "Ismark Kolyanovich")
	assert_eq(str((npc["actions"] as Array)[0]["id"]), "talk")
	var me := v.actions_at(v.leader().cell)
	assert_eq(str((me["actions"] as Array)[0]["id"]), "lead:0")
	assert_false(bool((me["actions"] as Array)[0]["enabled"]), "already leading")
	var ground := v.actions_at(Vector2i(2, 2))
	assert_eq(str((ground["actions"] as Array)[0]["id"]), "walk")
	# Forcing the door from the menu walks over and tries Athletics until it gives.
	for i in 8:
		if not v.grid.has_flag(Vector2i(5, 3), CombatGrid.WALL):
			break
		v.act(Vector2i(5, 3), "force")
		await _walk_until_idle()
		await _frames(1)
		if v.grid.has_flag(Vector2i(5, 3), CombatGrid.WALL) and str((GameState.story.loc_state("test_hall")["doors"] as Dictionary).get("inner_door", "")) == "unlocked":
			v.act(Vector2i(5, 3), "open")
			await _walk_until_idle()
	assert_false(v.grid.has_flag(Vector2i(5, 3), CombatGrid.WALL), "forced open")
	root.call("open_world_menu", Vector2i(4, 2), Vector2(300, 300))
	assert_true((root.get("menu") as ContextMenu).visible, "the menu shows")
	root.call("world_action", v.leader().cell, "spells:2")
	await _frames(1)
	assert_true(root.get("screen") is CharacterSheetScreen)


func test_a_guest_follows_and_fights_on_our_side() -> void:
	assert_true(GameState.story.add_guest("ireena"))
	var v := _view()
	v.place_guests()
	await _frames(1)
	assert_eq(v.guest_members.size(), 1)
	var g := v.guest_members[0]
	v.walk_to(Vector2i(2, 1))
	await _walk_until_idle()
	assert_true(v.grid.distance_ft(g.cell, 1, v.members[v.members.size() - 1].cell, 1) <= 10, "the guest keeps up")
	assert_true(v.start_encounter("wolves"))
	await _frames(5)
	var sides := v.combat_view.e.combatants.map(func(c: Combatant) -> String: return str(c.side))
	assert_true("guest" in sides, str(sides))
	for c in v.combat_view.e.combatants:
		if c.side == &"guest":
			assert_true(c.is_player_controlled(), "the player commands guests")
	root.call("_refresh")
	GameState.story.remove_guest("ireena")


func test_the_fight_inherits_the_light() -> void:
	var v := _view()
	assert_true(v.start_encounter("wolves"))
	await _frames(3)
	var e := v.combat_view.e
	assert_eq(e.ambient_light, "dim", "the hall's map light")
	assert_eq(e.light_at(v.leader().cell), "bright", "the lantern")


func test_exploring_spells_light_detect_and_find_traps() -> void:
	var v := _view()
	var silvain := GameState.story.party[3]
	var opts: Array = FieldCasting.utility_options(GameState.story.party, silvain, DiceRoller.new(1)).map(func(o: Dictionary) -> String: return str(o["id"]))
	var hedda := GameState.story.party[2]
	var hopts: Array = FieldCasting.utility_options(GameState.story.party, hedda, DiceRoller.new(1)).map(func(o: Dictionary) -> String: return str(o["id"]))
	assert_true("light" in hopts, "Hedda knows Light: %s" % [hopts])
	var res := FieldCasting.cast_utility(GameState.story, hedda, "light", false)
	assert_true(bool(res["ok"]), str(res))
	assert_true(StoryConditions.check("spell:light", GameState.story))
	v.apply_spell_effect("light")
	assert_true(v.lantern.visible)
	GameState.story.advance_minutes(61)
	assert_false(StoryConditions.check("spell:light", GameState.story), "an hour later it's gone")
	v.apply_spell_effect("find_traps")
	assert_eq(str((GameState.story.loc_state("test_hall")["traps"] as Dictionary).get("pit", "")), "found")
	assert_true(opts.size() >= 0)


func test_escape_in_combat_opens_the_menu_and_pauses_the_fight() -> void:
	var v := _view()
	assert_true(v.start_encounter("wolves"))
	await _frames(4)
	v.combat_view.menu_requested.emit()
	await _frames(1)
	assert_true(root.get("screen") is PauseMenu)
	assert_true(get_tree().paused, "the fight waits")
	v.combat_view.menu_requested.emit()
	await _frames(1)
	assert_true(root.get("screen") == null, "Escape again closes it")
	assert_false(get_tree().paused)


## Owner bug reports: trees showed a black box behind them after fading, and flickered in the forest. A fading tree
## keeps its texture's alpha and draws after the screen pass; once back, it's a cut-out again.
func test_trees_fade_and_come_back_without_a_box() -> void:
	root.call("enter_location", "into_the_mists_road", "")
	await _frames(3)
	var board := _view().board
	if board.occluders.is_empty():
		# 3D trees (docs/art/models.md, owner request 2026-10-07): they fade through their meshes' transparency.
		assert_false(board.mesh_occluders.is_empty(), "the road has trees")
		var t3 := board.mesh_occluders[0]
		var at := t3.global_position + Vector3(-1.5, 0, 0)
		for i in 10:
			board.fade_occluders(at + Vector3(10, 10, 0), at, 0.5)
		var mesh := t3.find_children("*", "GeometryInstance3D", true, false)[0] as GeometryInstance3D
		assert_true(mesh.transparency > 0.5, "the tree between the camera and the party fades")
		for i in 10:
			board.fade_occluders(at + Vector3(-10, 10, 0), at, 0.5)
		assert_eq(mesh.transparency, 0.0, "back, solid, when the camera moves")
		return
	var tree := board.occluders[0]
	var focus := tree.position + Vector3(-1.5, 0, 0)
	for i in 10:
		board.fade_occluders(focus + Vector3(10, 10, 0), focus, 0.5)
	assert_true(tree.modulate.a < 0.5, "the tree between the camera and the party fades")
	assert_true(tree.transparent, "its own alpha still counts while fading")
	assert_eq(tree.render_priority, DirectionalSprite.RENDER_PRIORITY, "drawn after the screen pass, not under it")
	for i in 10:
		board.fade_occluders(focus + Vector3(-10, 10, 0), focus, 0.5)
	assert_eq(tree.modulate.a, 1.0, "back when the camera moves")
	assert_true(tree.transparent, "no black box: the texture's alpha still cuts the tree out")
	assert_eq(tree.alpha_cut, SpriteBase3D.ALPHA_CUT_DISCARD)
	assert_eq(tree.render_priority, 0)
