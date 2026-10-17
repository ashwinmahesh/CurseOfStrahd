extends TestCase
## What the party finds glows orange (FoundGlow, FoundOutline; owner ask 2026-10-13): a hidden find, a secret door and
## a trap that a Search turns up pulse, then keep a steady outline until the party uses them or leaves; things found
## before the party came don't glow; a check's reveal lights its find too; a rebuild of the place's pieces keeps the
## glow on; a fight puts it away and it comes back after.

const LOC := {
	"id": "test_found_glow", "name": "Found Glow", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"###########",
		"#.........#",
		"#.........#",
		"#.........#",
		"#####.#####",
		"#.........#",
		"###########"], "light": "dim"},
	"spawns": {"default": [3, 2]},
	"doors": [{"id": "panel", "cell": [5, 4], "secret_dc": 1, "label": "a hidden panel"}],
	"props": [
		{"id": "loose_stone", "kind": "search", "cell": [2, 1], "search_dc": 1, "model": "rubble", "label": "a loose stone"},
		{"id": "old_satchel", "kind": "search", "cell": [4, 1], "search_dc": 1, "model": "satchel",
			"label": "an old satchel"}],
	"traps": [{"id": "wolf_trap", "label": "a hunter's wolf trap", "cells": [[6, 2]], "detect_dc": 1, "disarm_dc": 10,
		"save": {"ability": "dex", "dc": 10}, "damage": "1d4", "damage_type": "piercing", "text": "Snap."}],
}

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_found_glow"] = LOC.duplicate(true)
	GameState.reset()
	# Nobody who casts Guidance, so a Search is rolled at once.
	for id: String in ["ilse_varga", "tamsin_tealeaf", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_found_glow"
	GameState.story.visited["test_found_glow"] = true
	# Found on an earlier visit.
	(GameState.story.loc_state("test_found_glow")["found"] as Dictionary)["old_satchel"] = true
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await _frames(1)
	(Compendium.shared().tables["locations"] as Dictionary).erase("test_found_glow")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	await _frames(1)


func _view() -> LocationView:
	return root.get("view") as LocationView


func _glow() -> FoundGlow:
	return FoundGlow.of(_view())


## The found-outline materials on what's drawn under `node`.
func _outlines(node: Node3D) -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for n: Node in [node] + node.find_children("*", "GeometryInstance3D", true, false):
		var mat := (n as GeometryInstance3D).material_overlay as ShaderMaterial if n is GeometryInstance3D else null
		if mat != null and mat.shader in [FoundOutline.SPRITE_SHADER, FoundOutline.RIM_SHADER]:
			out.append(mat)
	return out


func _search() -> void:
	_view().search()
	await _wait(FoundGlow.CHECK_EVERY * 2.0)


func test_a_search_lights_what_it_finds_and_not_what_was_found_before() -> void:
	var glow := _glow()
	assert_true(glow != null, "every place watches for finds")
	assert_true(glow.lit.is_empty(), "nothing glows on arriving, not even the satchel found last time")
	await _search()
	assert_true(glow.is_lit("prop:loose_stone"), "the hidden find glows")
	assert_true(glow.is_lit("door:panel"), "and the secret door")
	assert_true(glow.is_lit("trap:wolf_trap"), "and the trap")
	assert_false(glow.is_lit("prop:old_satchel"), "the satchel found on an earlier visit doesn't")
	assert_false(_outlines(_view().prop_nodes["loose_stone"] as Node3D).is_empty(), "the find's piece wears the outline")
	assert_true(_outlines(_view().prop_nodes["old_satchel"] as Node3D).is_empty())
	assert_false(_outlines(_view().door_nodes["panel"] as Node3D).is_empty(), "so does the door")
	var piece_lit := false
	for n: Node3D in _view().trap_marks["wolf_trap"]:
		if n.name == &"TrapBorder":
			assert_true(_outlines(n).is_empty(), "the trap's red border is left as it is")
		elif not _outlines(n).is_empty():
			piece_lit = true
	assert_true(piece_lit, "the trap's own piece wears the outline")


func test_it_pulses_as_its_found_then_holds_steady() -> void:
	await _search()
	var mat := _outlines(_view().prop_nodes["loose_stone"] as Node3D)[0]
	var peak := 0.0
	for i in 8:
		peak = maxf(peak, float(mat.get_shader_parameter("glow")))
		await _wait(0.1)
	assert_true(peak > 1.2, "it swells as it's found (peak %.2f)" % peak)
	await _wait(FoundGlow.PULSE)
	assert_between(float(mat.get_shader_parameter("glow")), 0.999, 1.001, "then holds a steady outline")
	assert_true(_glow().is_lit("prop:loose_stone"), "and stays")


func test_using_a_find_or_opening_the_door_ends_its_glow() -> void:
	await _search()
	var stone := _view().prop_nodes["loose_stone"] as Node3D
	_view().interact(_view().thing_at(Vector2i(2, 1)))
	await _wait(FoundGlow.FADE + FoundGlow.CHECK_EVERY)
	assert_false(_glow().is_lit("prop:loose_stone"), "searched through: it goes")
	assert_false(_glow().lit.has("prop:loose_stone"))
	assert_true(_outlines(stone).is_empty(), "the piece is as it was")
	assert_true(_glow().is_lit("door:panel"), "the rest still glow")
	(GameState.story.loc_state("test_found_glow")["doors"] as Dictionary)["panel"] = LocationView.DOOR_OPEN
	await _wait(FoundGlow.FADE + FoundGlow.CHECK_EVERY * 2.0)
	assert_false(_glow().lit.has("door:panel"), "a door opened any way at all stops glowing")
	(GameState.story.loc_state("test_found_glow")["traps"] as Dictionary)["wolf_trap"] = "disarmed"
	await _wait(FoundGlow.FADE + FoundGlow.CHECK_EVERY * 2.0)
	assert_false(_glow().lit.has("trap:wolf_trap"), "so does a trap disarmed")


func test_a_checks_reveal_lights_its_find() -> void:
	LocationChecks._reveal_here(_view(), "loose_stone")
	await _wait(FoundGlow.CHECK_EVERY * 2.0)
	assert_true(_glow().is_lit("prop:loose_stone"), "found by a check rather than a Search: it glows all the same")


func test_the_glow_stays_on_a_rebuilt_piece() -> void:
	await _search()
	_view().refresh_npcs()   # a conversation or a fight ended: the place's pieces are made again
	await _wait(FoundGlow.CHECK_EVERY * 2.0)
	assert_false(_outlines(_view().prop_nodes["loose_stone"] as Node3D).is_empty(), "the new piece glows")


func test_a_fight_puts_the_glow_away_and_it_comes_back() -> void:
	await _search()
	var stone := _view().prop_nodes["loose_stone"] as Node3D
	_view().in_combat = true
	await _wait(FoundGlow.CHECK_EVERY * 2.0)
	assert_true(_outlines(stone).is_empty(), "no orange outlines among a fight's rings and areas")
	assert_true(_glow().lit.has("prop:loose_stone"), "but it isn't forgotten")
	_view().in_combat = false
	await _wait(FoundGlow.CHECK_EVERY * 2.0)
	assert_false(_outlines(stone).is_empty(), "after the fight it glows again")


func test_mobile_world_tap_outlines_objects_and_people_without_changing_desktop() -> void:
	var previous := MobileDevice.profile
	var view := _view()
	var prop := view.prop_nodes["old_satchel"] as Node3D
	TouchOutline.at(view, Vector2i(4, 1))
	assert_true(prop.get_node_or_null("TouchOutline") == null, "desktop does not get tap feedback")
	MobileDevice.profile = "iphone"
	assert_true(bool(root.call("touch_ready")))
	view.rig.snap_to_target()
	var at := view.rig.camera.unproject_position(view.board.cell_center(Vector2i(4, 1)) + Vector3(0, 0.25, 0))
	assert_eq(view.pick_cell(view.rig.camera, at), Vector2i(4, 1), "tap hits the visible satchel")
	root.call("touch_tap", at, true)
	assert_true(prop.get_node_or_null("TouchOutline") != null, "real world tap routes to the object outline")
	(root.get("menu") as ContextMenu).close()
	var token := view.tokens[view.leader().id] as CombatToken
	at = view.rig.camera.unproject_position(view.board.cell_center(view.leader().cell))
	root.call("touch_tap", at, true)
	assert_true(token.body.get_node_or_null("TouchOutline") != null, "party members also acknowledge touch")
	(root.get("menu") as ContextMenu).close()
	await _wait(0.55)
	assert_true(prop.get_node_or_null("TouchOutline") == null)
	assert_true(token.body.get_node_or_null("TouchOutline") == null)
	TouchOutline.at(view, Vector2i(7, 2))
	assert_true(view.find_children("TouchOutline", "", true, false).is_empty(), "bare ground does not glow")
	MobileDevice.profile = previous


func test_mobile_nearby_list_respects_secrets_and_opens_options_without_acting() -> void:
	var previous := MobileDevice.profile
	root.queue_free()
	await _frames(1)
	MobileDevice.profile = "iphone"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	var view := _view()
	view.rig.snap_to_target()
	var hud := root.get("hud") as ExploreHud
	var entries := hud.mobile.nearby_entries()
	var satchel := {}
	for entry in entries:
		assert_false(str(entry["id"]) in ["loose_stone", "panel", "wolf_trap"], "nearby list does not reveal undiscovered content")
		if str(entry["id"]) == "old_satchel":
			satchel = entry
	assert_false(satchel.is_empty(), "the discovered satchel is listed")
	var before := GameState.story.to_dict()
	var rng := Dice.roller.get_state()
	hud.mobile.nearby()
	await _frames(3)
	assert_eq(GameState.story.to_dict(), before, "browsing nearby objects does not interact")
	assert_eq(Dice.roller.get_state(), rng)
	if not satchel.is_empty():
		hud.mobile._pick_nearby(satchel)
		assert_true((root.get("menu") as ContextMenu).is_open(), "selection opens existing context actions")
		assert_eq(root.get("_menu_cell"), Vector2i(4, 1))
		assert_true((view.prop_nodes["old_satchel"] as Node).get_node_or_null("TouchOutline") != null)
		assert_eq(GameState.story.to_dict(), before, "opening options does not search, move or spend")
		(root.get("menu") as ContextMenu).close()
		hud.mobile.nearby()
		view.input_locked = true
		hud.mobile._pick_nearby(satchel)
		assert_false((root.get("menu") as ContextMenu).is_open(), "a stale list cannot bypass an input lock")
		assert_eq(hud.mobile.kind, "nearby")
		assert_true(hud.mobile.nearby_entries().is_empty())
		view.input_locked = false
		hud.mobile.close()
	MobileDevice.profile = previous
