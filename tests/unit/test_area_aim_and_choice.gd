extends TestCase
## Areas placed at a point, centred on the pointer (owner, 2026-10-13: "the pointer should be at the middle of the
## area"): TargetPicker.aim puts a Sphere on the nearest grid intersection and a Cube's middle there, its point of
## origin on the face nearest the caster, where its range is measured (SpellTargeting.point_distance_ft). And Slow's
## "up to six creatures of your choice in the Cube" (owner: "for slow, we should be able to select the target"): the
## cube is placed, then the creatures in it are picked, its foes picked to start with (TargetPicker's choose step,
## opts.chosen); with no picks (the AI, the test autopilot) its foes that hit hardest go first.


func _field(width: int = 20, depth: int = 10) -> Encounter:
	var rows: Array[String] = []
	for z in depth:
		rows.append(".".repeat(width))
	return TestCombat.encounter(rows, 4)


func _bounds(cells: Array[Vector2i]) -> Rect2i:
	var lo := cells[0]
	var hi := cells[0]
	for c in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)


# --- Centred on the pointer -------------------------------------------------------------------------

func test_a_cube_is_centred_on_the_pointer_and_spreads_away_from_its_caster() -> void:
	var e := _field(20, 16)
	var c := TestCombat.caster_with(e, ["slow", "silent_image"], Vector2i(0, 4))
	TestCombat.start_with(e, c)
	var s := Compendium.shared().spell_data("slow")
	var a := {"spell_id": "slow", "kind": "spell"}
	var aim := TargetPicker.aim(e, c, a, Vector2(10.2, 4.4))
	assert_eq(aim["point"], Vector2(6, 4), "its point of origin: the middle of the face toward the caster")
	assert_eq(aim["dir"], Vector2.RIGHT, "spreading away from the caster")
	var box := _bounds(e.spells.area_for(c, s, aim["point"] as Vector2, aim["dir"] as Vector2))
	assert_eq(box, Rect2i(6, 0, 8, 8), "a 40-ft cube, 8 squares a side, its middle at the pointer's intersection (10, 4)")
	# From the north, it spreads south.
	c.cell = Vector2i(10, 0)
	var south := TargetPicker.aim(e, c, a, Vector2(10.4, 9.6))
	assert_eq(south["dir"], Vector2.DOWN)
	assert_eq(_bounds(e.spells.area_for(c, s, south["point"] as Vector2, south["dir"] as Vector2)), Rect2i(6, 6, 8, 8))
	# An odd-sized cube (15 ft) sits on the middle of the square pointed at.
	c.cell = Vector2i(0, 4)
	var small := TargetPicker.aim(e, c, {"spell_id": "silent_image", "kind": "spell"}, Vector2(5.3, 4.7))
	assert_eq(_bounds(e.spells.area_for(c, Compendium.shared().spell_data("silent_image"), small["point"] as Vector2, small["dir"] as Vector2)),
		Rect2i(4, 3, 3, 3), "3 squares a side round square (5, 4)")


func test_a_sphere_sits_on_the_nearest_intersection_and_an_emanation_on_the_square_pointed_at() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["fireball"], Vector2i(0, 4))
	TestCombat.start_with(e, c)
	var fb := TargetPicker.aim(e, c, {"spell_id": "fireball", "kind": "spell"}, Vector2(5.3, 4.6))
	assert_eq(fb["point"], Vector2(5, 5))
	assert_eq(fb["dir"], Vector2.ZERO)
	var box := _bounds(e.spells.area_for(c, Compendium.shared().spell_data("fireball"), fb["point"] as Vector2, Vector2.ZERO))
	assert_eq(box, Rect2i(1, 1, 8, 8), "20-ft radius: 8 squares across, round (5, 5)")
	var gf := TargetPicker.aim(e, c, {"spell_id": "guardian_of_faith", "kind": "spell"}, Vector2(5.3, 4.6))
	assert_eq(gf["point"], Vector2(5.3, 4.6), "the square under the pointer holds it")


func test_range_is_measured_to_the_cubes_near_face_and_the_same_from_every_side() -> void:
	var rows: Array[String] = []
	for z in 5:
		rows.append(".".repeat(40))
	var e := TestCombat.encounter(rows, 2)
	var c := TestCombat.caster_with(e, ["slow", "fireball"], Vector2i(0, 2))
	TestCombat.start_with(e, c)
	var slow := Compendium.shared().spell_data("slow")
	var a := {"spell_id": "slow", "kind": "spell"}
	var near := TargetPicker.aim(e, c, a, Vector2(29.2, 2.4))
	assert_eq(str(e.spells._check_targets(c, slow, 3, [], near["point"] as Vector2, {})["why"]), "",
		"its middle 140 ft off, its near face 120 ft: in range")
	var far := TargetPicker.aim(e, c, a, Vector2(30.2, 2.4))
	assert_ne(str(e.spells._check_targets(c, slow, 3, [], far["point"] as Vector2, {})["why"]), "", "the near face 125 ft off")
	# A Sphere's intersection 150 ft from the caster's edge is in range from the west and from the east alike.
	var fireball := Compendium.shared().spell_data("fireball")
	assert_eq(str(e.spells._check_targets(c, fireball, 3, [], Vector2(31, 2), {})["why"]), "")
	assert_ne(str(e.spells._check_targets(c, fireball, 3, [], Vector2(32, 2), {})["why"]), "")
	c.cell = Vector2i(39, 2)
	assert_eq(str(e.spells._check_targets(c, fireball, 3, [], Vector2(9, 2), {})["why"]), "")
	assert_ne(str(e.spells._check_targets(c, fireball, 3, [], Vector2(8, 2), {})["why"]), "")
	# The AI's and the autopilot's aim at a creature's middle reads as it did.
	assert_eq(e.spells.targeting.point_distance_ft(c, Vector2(9.5, 2.5)), 150)


# --- Slow's creatures of your choice ----------------------------------------------------------------

## A caster at the west edge, an ally and seven foes in the cube round (10, 4): six zombies and a mimic.
func _slow_scene() -> Dictionary:
	var e := _field()
	var c := TestCombat.caster_with(e, ["slow"], Vector2i(0, 4))
	var ally := TestCombat.hero(e, "hedda_ironvow", Vector2i(8, 4))
	var foes: Array[Combatant] = []
	for cell: Vector2i in [Vector2i(7, 2), Vector2i(7, 6), Vector2i(9, 1), Vector2i(9, 7), Vector2i(11, 3), Vector2i(12, 5)]:
		foes.append(TestCombat.foe(e, "zombie", cell))
	var mimic := TestCombat.foe(e, "mimic", Vector2i(13, 4))
	foes.append(mimic)
	TestCombat.start_with(e, c)
	return {"e": e, "c": c, "ally": ally, "foes": foes, "mimic": mimic}


func test_slow_with_no_picks_takes_six_foes_the_hardest_hitting_first() -> void:
	var sc := _slow_scene()
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var s := Compendium.shared().spell_data("slow")
	var aim := TargetPicker.aim(e, c, {"spell_id": "slow", "kind": "spell"}, Vector2(10.2, 4.4))
	var cells := e.spells.area_for(c, s, aim["point"] as Vector2, aim["dir"] as Vector2)
	var taken := e.spells.targeting._area_victims(c, s, cells)
	assert_eq(taken.size(), 6)
	assert_true(sc["mimic"] in taken, "the mimic (CR 2) first, though farthest")
	assert_false(sc["ally"] in taken, "never the caster's ally")
	assert_eq(e.spells.targeting.area_candidates(c, s, cells).size(), 8, "all eight can be chosen")


func test_the_player_places_the_cube_then_picks_up_to_six_inside_it() -> void:
	var sc := _slow_scene()
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var ally := sc["ally"] as Combatant
	var foes := sc["foes"] as Array[Combatant]
	var a := ActionCatalog.new(e).find(c, "spell:slow")
	assert_false(a.is_empty())
	assert_eq(str(a["targeting"]), "point")
	var aim := TargetPicker.aim(e, c, a, Vector2(10.2, 4.4))
	var picker := TargetPicker.new(e)
	assert_true(picker.sculpt(c, a, aim["point"] as Vector2, aim["dir"] as Vector2, 3), "placing it starts the picks")
	assert_eq(picker.step, "choose")
	assert_true(picker.candidate(ally) and picker.candidate(foes[0]), "anyone in the cube can be picked")
	var view := picker.show(ally.cell, ally)
	assert_true(str(view["title"]).contains("6 of up to 6"), str(view["title"]))
	assert_eq(str(picker.pick(ally.cell, ally).get("do", "")), "refuse", "six already: one must be dropped first")
	var dropped := foes[0]
	assert_true(picker.pick(dropped.cell, dropped).is_empty(), "a click drops a picked foe")
	assert_true(picker.pick(ally.cell, ally).is_empty(), "and another adds the ally")
	var cmd := picker.pick(Vector2i(10, 6), null)
	assert_eq(str(cmd.get("do", "")), "perform", "a click on the floor casts it")
	var opts := (cmd["action"] as Dictionary)["opts"] as Dictionary
	var chosen := opts["chosen"] as Array
	assert_eq(chosen.size(), 6)
	assert_true(ally.id in chosen and not dropped.id in chosen)
	var r := e.spells.cast(c, "slow", 3, [], cmd["point"] as Vector2, cmd["dir"] as Vector2, opts)
	if r.is_paused():
		e.answer_reaction(false)
	assert_true(r.ok, r.reason)
	assert_false(dropped.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == "slow"), "the dropped foe is untouched")


func test_enter_casts_on_the_picks_backspace_aims_again_and_an_empty_cube_casts_at_once() -> void:
	var sc := _slow_scene()
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var a := ActionCatalog.new(e).find(c, "spell:slow")
	var aim := TargetPicker.aim(e, c, a, Vector2(10.2, 4.4))
	var picker := TargetPicker.new(e)
	assert_true(picker.sculpt(c, a, aim["point"] as Vector2, aim["dir"] as Vector2, 3))
	var cmd := picker.confirm()
	assert_eq(str(cmd["do"]), "perform", "Enter: the foes already picked")
	assert_eq((((cmd["action"] as Dictionary)["opts"] as Dictionary)["chosen"] as Array).size(), 6)
	assert_true(picker.undo(), "Backspace goes back to placing the cube")
	assert_false(picker.active())
	# No one in the cube: nothing to pick, it goes off as placed.
	var empty := TargetPicker.aim(e, c, a, Vector2(18.2, 9.4))
	assert_false(picker.sculpt(c, a, empty["point"] as Vector2, empty["dir"] as Vector2, 3))


func test_the_preview_shows_who_a_spell_of_your_choice_leaves_out() -> void:
	var sc := _slow_scene()
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var catalog := ActionCatalog.new(e)
	var a := catalog.find(c, "spell:slow")
	var aim := TargetPicker.aim(e, c, a, Vector2(10.2, 4.4))
	var pv := catalog.spell_preview(c, a, aim["point"] as Vector2, aim["dir"] as Vector2, 3)
	var ally_row := {}
	for row: Dictionary in pv["creatures"]:
		if str(row["id"]) == (sc["ally"] as Combatant).id:
			ally_row = row
	assert_true(bool(ally_row.get("unaffected", false)), "the ally isn't one of Slow's picks")
	assert_true(str(ally_row.get("line", "")).contains("not affected"))
	assert_false((pv["warnings"] as Array).any(func(w: String) -> bool: return w.begins_with("Friendly fire")), "no friendly fire warning")


func test_mass_cure_wounds_with_no_picks_heals_the_most_hurt_first() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["mass_cure_wounds"], Vector2i(0, 4))
	var allies: Array[Combatant] = []
	var x := 3
	for id: String in ["ilse_varga", "hedda_ironvow", "godrick_pendlebrook", "thistle", "kip_smudgewick", "liriel_dawnsong", "wren_featherfoot"]:
		allies.append(TestCombat.hero(e, id, Vector2i(x, 4)))
		x += 1
	TestCombat.start_with(e, c)
	var hurt := allies[allies.size() - 1]
	hurt.creature.hp = 1
	var s := Compendium.shared().spell_data("mass_cure_wounds")
	var cells := e.spells.area_for(c, s, Vector2(6, 4), Vector2.ZERO)
	var taken := e.spells.targeting._area_victims(c, s, cells)
	assert_eq(taken.size(), 6)
	assert_true(hurt in taken, "the farthest, but the most hurt")
