extends TestCase
## Owner report (2026-10-13): "Some enemies should be laying down, ex Vasilka, it says she's lying under a sheet very
## still" and she stood beside her table. An NPC entry's or an encounter foe's `lying` (LyingFigures) lays the figure
## down with no condition until the story moves on or its fight opens, then it gets up: Vasilka on the surgery table
## under her sheet (or with it drawn over her face), rising off her bier to defend her wedding in her own look, the
## witch where she fell, Sarkhaza low across her hoard.

var root: Node


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _boot(location: String, flags: Dictionary = {}) -> LocationView:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "wren_featherfoot"]:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	for f: String in flags:
		GameState.story.set_flag(f, flags[f])
	GameState.story.location = location
	GameState.story.minute_of_day = 12 * 60
	Dice.reseed(7)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	var d := root.get("dialogue") as DialogueUI
	if d != null:
		d.queue_free()
		root.set("dialogue", null)
	return root.get("view") as LocationView


func _lying_view(tok: CombatToken) -> Sprite3D:
	return tok.get("_lying") as Sprite3D


func _sheet(tok: CombatToken) -> MeshInstance3D:
	return tok.get("_sheet") as MeshInstance3D


func test_vasilka_lies_on_the_surgery_table_under_her_sheet() -> void:
	var v := await _boot("abbey_of_st_markovia_wards")
	var tok := v.npc_tokens.get("vasilka", null) as CombatToken
	assert_true(tok != null, "Vasilka is in the surgery")
	assert_true(tok.resting, "she lies down")
	assert_false(tok.sprite.visible, "nobody stands there")
	assert_true(_lying_view(tok).visible, "her head shows above the sheet")
	assert_true(_lying_view(tok).region_enabled, "only her head and neck: the sheet is turned down to her collarbone")
	assert_true(_sheet(tok) != null and _sheet(tok).is_inside_tree(), "under a linen sheet")
	assert_true(_lying_view(tok).global_position.y > tok.global_position.y + 0.3, "up on the table, not on the floor")
	assert_eq(v.grid.cell_at(tok.position), Vector2i(23, 10), "on the table's square")
	var thing := v.thing_at(Vector2i(23, 10))
	assert_eq(str(thing.get("id", "")), "vasilka", "clicking the table finds her")
	assert_eq(str(thing["label"]), "Vasilka", "the hover names her; nobody offers to chat")
	var menu := v.actions_at(Vector2i(23, 10))
	assert_eq(str(((menu["actions"] as Array)[0] as Dictionary)["label"]), "Approach")
	assert_true(tok.combatant.creature.active_conditions().is_empty(), "lying there is no condition")


func test_the_sheet_drawn_over_her_face_stays_there() -> void:
	var v := await _boot("abbey_of_st_markovia_wards", {"vasilka_fate": "never_woke", "abbot_fate": "slain",
		"vasilka_face_covered": true})
	var tok := v.npc_tokens.get("vasilka", null) as CombatToken
	assert_true(tok != null and tok.resting)
	assert_false(_lying_view(tok).visible, "her face is covered")
	assert_true(_sheet(tok) != null, "by the sheet")


func test_vasilka_comes_down_off_her_bier_to_defend_her_wedding() -> void:
	var v := await _boot("abbey_of_st_markovia_shrine", {"abbot_dress_asked": true, "wedding_dress_delivered": true})
	var bier := v.prop_nodes.get("bride_bier", null) as Node3D
	assert_true(bier != null, "the Belviews carried in a bier")
	assert_true(v.start_encounter("bride_defends"), "her wedding is stopped")
	await _frames(2)
	var e := v.combat_view.e
	var her: Combatant = null
	for c in e.combatants:
		if c.name() == "Vasilka":
			her = c
	assert_true(her != null, "she fights")
	if her == null:
		return
	assert_eq(CombatToken.art_id(her), "vasilka", "in her own look, not any flesh golem's")
	var tok := v.combat_view.tokens[her.id] as CombatToken
	assert_true(tok.resting, "the fight opens with her lying on the bier")
	var lies := _lying_view(tok).global_position
	var top := bier.global_transform * LyingFigures.top_of(bier).get_center()
	assert_true(Vector2(lies.x, lies.z).distance_to(Vector2(top.x, top.z)) < 0.3, "on the bier beside her square (%s, the bier %s)" % [lies, top])
	assert_true(top.distance_to(v.board.cell_center(Vector2i(16, 2))) < 0.6, "which stands north of her")
	await get_tree().create_timer(2.0).timeout
	assert_false(tok.resting, "she gets up as the fight opens")
	assert_true(tok.sprite.visible and not _lying_view(tok).visible, "and stands on her own square")
	# A round-start save keeps her look.
	var back := EncounterSnapshot.restore(EncounterSnapshot.capture(e), Dice.roller, GameState.story.party)
	for c in back.combatants:
		if c.name() == "Vasilka":
			assert_eq(CombatToken.art_id(c), "vasilka", "after a load too")
	v.combat_view.finished.emit("victory")
	await _frames(4)


func test_baba_lysaga_lies_where_she_fell() -> void:
	var v := await _boot("berez_baba_lysagas_hut", {"lysaga_slain_in_hut": true})
	var tok := v.npc_tokens.get("baba_lysaga", null) as CombatToken
	assert_true(tok != null and tok.resting, "she lies by her hearth")
	assert_true(_lying_view(tok).visible and not tok.sprite.visible)
	assert_true(_sheet(tok) == null, "no sheet over her")


func test_sarkhaza_lies_low_across_her_hoard_until_the_chain_hauls_her_up() -> void:
	var v := await _boot("ghakis_lair")
	var tok := v.npc_tokens.get("sarkhaza", null) as CombatToken
	assert_true(tok != null and tok.resting, "she lies across the gold")
	assert_true(tok.sprite.visible and tok.sprite.position.y < -0.3, "a dragon lies on her belly, low, legs under her")
	GameState.story.set_flag("wyrm_chain_drawn", true)
	v.refresh_npcs()
	await _frames(1)
	tok = v.npc_tokens.get("sarkhaza", null) as CombatToken
	assert_true(tok != null and not tok.resting, "hauled up on the chain she stands")


## Every `lying.on` names a prop of its own place (the figure lies on it).
func test_every_lying_figure_lies_on_a_prop_that_is_there() -> void:
	for loc: Dictionary in Compendium.shared().all("locations"):
		var id := str(loc["id"])
		var props := {}
		for p: Variant in loc.get("props", []):
			props[str((p as Dictionary)["id"])] = true
		var entries: Array = (loc.get("npcs", []) as Array).duplicate()
		for en: Variant in loc.get("encounters", []):
			entries.append_array((en as Dictionary)["monsters"] as Array)
		for n: Variant in entries:
			var how: Variant = (n as Dictionary).get("lying", null)
			if how is Dictionary and (how as Dictionary).has("on"):
				assert_true(props.has(str((how as Dictionary)["on"])), "%s: %s lies on %s" % [id, n, (how as Dictionary)["on"]])
