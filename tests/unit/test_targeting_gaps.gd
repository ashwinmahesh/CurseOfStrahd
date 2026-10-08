extends TestCase
## Targeting gaps (F10): walls drawn square by square (SpellTargeting, SpellPlacement) and the picks after the first
## (Commander's Strike's foe, Crown of Madness's victim, Maneuvering Attack's ally and square), with the combat view's
## picking steps (TargetPicker) driven without a scene.


## A humanoid foe with a 5-ft melee attack, weak saves and plenty of Hit Points.
func _brute(e: Encounter, cell: Vector2i, side: StringName = &"enemy", hp: int = 200) -> Combatant:
	var m := TestChars.dummy(hp, false, {"type": "humanoid", "ac": 1,
		"abilities": {"str": 10, "dex": 1, "con": 1, "int": 1, "wis": 1, "cha": 1},
		"actions": [{"id": "club", "name": "Club", "kind": "melee", "attack": {"bonus": 5, "reach": 5},
			"damage": [{"average": 4, "dice": "1d6+1", "type": "bludgeoning"}], "weapon": true}]})
	return e.add(m, side, cell)


## A Battle Master who knows Commander's Strike and Maneuvering Attack.
func _battle_master(e: Encounter, cell: Vector2i) -> Combatant:
	return e.add(TestChars.custom("fighter", "human", 3, {"fighter_subclass": ["battle_master"],
		"combat_superiority": ["commanders_strike", "maneuvering_attack", "trip_attack"]}), &"party", cell)


func _melee(e: Encounter, c: Combatant) -> String:
	for o in e.attack_options(c):
		if bool(o["melee"]) and str(o["kind"]) == "weapon":
			return str(o["id"])
	return ""


func _cells(pairs: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p: Variant in pairs:
		out.append(Vector2i(int((p as Array)[0]), int((p as Array)[1])))
	return out


## A long hall for range checks: 40 squares east to west.
func _hall() -> Encounter:
	var rows: Array[String] = []
	for z in 5:
		rows.append(".".repeat(40))
	return TestCombat.encounter(rows)


# --- Walls drawn square by square ------------------------------------------------------------------

func test_wall_spells_are_drawn_on_the_hotbar_and_a_tsunami_is_aimed() -> void:
	var comp := Compendium.shared()
	for id: String in ["wall_of_fire", "wind_wall", "wall_of_stone", "wall_of_ice", "wall_of_force", "wall_of_thorns", "blade_barrier", "prismatic_wall"]:
		assert_eq(ActionCatalog.spell_targeting(comp.spell_data(id)), "wall", id)
	assert_eq(ActionCatalog.spell_targeting(comp.spell_data("tsunami")), "point", "a Tsunami rolls from a point")
	assert_false(SpellTargeting.drawn_wall(comp.spell_data("wall_of_fire"), "ring"), "its ring is placed at a point")
	assert_false(SpellTargeting.drawn_wall(comp.spell_data("prismatic_wall"), "globe"))
	assert_false(SpellTargeting.drawn_wall(comp.spell_data("wall_of_force"), "dome"))


func test_a_drawn_wall_of_fire_covers_its_squares_and_burns_the_chosen_side() -> void:
	var e := TestCombat.open_field(2)
	var c := TestCombat.high_caster(e, ["wall_of_fire"], Vector2i(0, 0))
	var south := TestCombat.punching_bag(e, Vector2i(6, 5), 300)
	var north := TestCombat.punching_bag(e, Vector2i(6, 1), 300)
	TestCombat.start_with(e, c)
	var path: Array[Vector2i] = [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3), Vector2i(8, 3)]
	# Drawn eastward, the right-hand side is south (x east, y south).
	var r := e.spells.cast(c, "wall_of_fire", 4, [], Vector2(5.5, 3.5), Vector2.ZERO, {"path": path, "side": "right"})
	assert_true(r.ok, r.reason)
	var wall := e.spells.zones.object_of(c.id, "wall_of_fire")
	assert_eq(wall.cells, path, "the wall stands on the squares drawn")
	var side := wall.rule("side_cells", []) as Array
	assert_true([6, 5] in side, "10 ft south burns")
	assert_false([6, 1] in side, "the north side doesn't")
	assert_false([9, 3] in side, "a square in line past the end is on neither side")
	for i in 3:
		e.end_turn()
	assert_true(south.creature.hp < 300, "ending a turn on the burning side")
	assert_eq(north.creature.hp, 300, "the other side deals no damage")


func test_a_square_beside_the_wall_picks_its_burning_side() -> void:
	var e := TestCombat.open_field(2)
	var c := TestCombat.high_caster(e, ["wall_of_fire"], Vector2i(0, 0))
	TestCombat.start_with(e, c)
	var path: Array[Vector2i] = [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3)]
	assert_true(e.spells.cast(c, "wall_of_fire", 4, [], Vector2(4.5, 3.5), Vector2.ZERO, {"path": path, "side": Vector2i(4, 1)}).ok)
	var side := e.spells.zones.object_of(c.id, "wall_of_fire").rule("side_cells", []) as Array
	assert_true([4, 2] in side and [4, 1] in side, "the side of the square picked (north)")
	assert_false([4, 4] in side)


func test_a_bent_wall_burns_on_the_side_each_stretch_turns_toward() -> void:
	var e := TestCombat.open_field()
	TestCombat.high_caster(e, ["wall_of_fire"], Vector2i(0, 0))
	var place := e.spells.placement
	# East along row 2, then down column 6: walking it, the right-hand side is the inside of the bend (south-west).
	var path: Array[Vector2i] = [Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2), Vector2i(6, 3), Vector2i(6, 4), Vector2i(6, 5)]
	assert_eq(place.side_of(path, Vector2i(4, 4)), "right", "inside the bend")
	assert_eq(place.side_of(path, Vector2i(5, 4)), "right", "inside the bend, beside the downward stretch")
	assert_eq(place.side_of(path, Vector2i(7, 1)), "left", "the outer corner")
	assert_eq(place.side_of(path, Vector2i(8, 4)), "left", "east of the downward stretch")
	assert_eq(place.side_of(path, Vector2i(4, 1)), "left", "north of the eastward stretch")
	assert_eq(place.side_of(path, Vector2i(6, 6)), "", "in line past the end")
	var right := place.path_side(path, "right", 10)
	assert_true([4, 4] in right and [5, 3] in right)
	assert_false([8, 4] in right, "the far side of the downward stretch")
	assert_false([7, 1] in right)


func test_a_bent_wind_wall_stands_on_its_path_and_turns_arrows_across_it() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["wind_wall"], Vector2i(0, 7))
	var archer := TestCombat.punching_bag(e, Vector2i(4, 2))
	var mark := TestCombat.punching_bag(e, Vector2i(7, 2))
	TestCombat.start_with(e, c)
	# Down column 5, a diagonal step, then east along row 4.
	var path: Array[Vector2i] = [Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2), Vector2i(5, 3), Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4)]
	assert_true(e.spells.cast(c, "wind_wall", 3, [], Vector2(5.5, 3.5), Vector2.ZERO, {"path": path}).ok)
	assert_eq(e.spells.zones.object_of(c.id, "wind_wall").cells, path)
	assert_true(e.spells.zones.deflects_between(archer, mark), "a shot across the bent wall")
	assert_false(e.spells.zones.deflects_between(mark, TestCombat.punching_bag(e, Vector2i(10, 2))), "a shot that never crosses it")


func test_a_wall_path_must_touch_stay_short_and_keep_out_of_solid_squares() -> void:
	var e := TestCombat.encounter(["............", "....#.......", "............", "............"])
	var c := TestCombat.caster_with(e, ["wind_wall"], Vector2i(0, 3))
	TestCombat.start_with(e, c)
	var ch := c.creature as Character
	var slots := ch.slots_left(3)
	var cases := [
		[[[2, 2], [4, 2]], "Each square must touch the last one"],
		[[[2, 2], [3, 2], [2, 2]], "That square is already part of the wall"],
		[[[3, 2], [4, 1], [5, 0]], "The wall can't go through a solid square"],
		[[[3, 0], [3, 1], [4, 2]], "The wall can't pass the corner of a solid square"],
	]
	for row: Array in cases:
		var r := e.spells.cast(c, "wind_wall", 3, [], Vector2(3.5, 2.5), Vector2.ZERO, {"path": _cells(row[0] as Array)})
		assert_false(r.ok, "refused: %s" % str(row[0]))
		assert_eq(r.reason, str(row[1]), str(row[0]))
	# Wind Wall: 50 ft, ten squares.
	var too_long := _cells([[0, 2], [1, 2], [2, 2], [3, 2], [4, 2], [5, 2], [6, 2], [7, 2], [8, 2], [9, 2], [10, 2]])
	var r2 := e.spells.cast(c, "wind_wall", 3, [], Vector2(3.5, 2.5), Vector2.ZERO, {"path": too_long})
	assert_eq(r2.reason, "The wall is already as long as it gets (50 ft)")
	assert_eq(ch.slots_left(3), slots, "nothing spent on a refused wall")
	too_long.pop_back()
	assert_true(e.spells.cast(c, "wind_wall", 3, [], Vector2(3.5, 2.5), Vector2.ZERO, {"path": too_long}).ok, "ten squares is 50 ft")


func test_every_square_of_a_wall_of_fire_is_in_range_but_a_wind_wall_only_starts_there() -> void:
	var e := _hall()
	var c := TestCombat.high_caster(e, ["wall_of_fire", "wind_wall"], Vector2i(0, 2))
	TestCombat.start_with(e, c)
	var fire := Compendium.shared().spell_data("wall_of_fire")
	var wind := Compendium.shared().spell_data("wind_wall")
	var t := e.spells.targeting
	# 120 ft is 24 squares: the square 25 squares away is out of range.
	var far := _cells([[20, 2], [21, 2], [22, 2], [23, 2], [24, 2], [25, 2]])
	assert_eq(t.wall_path_why(c, fire, 4, far, {}), "That square is out of range (120 ft)", "a Wall of Fire is all within range")
	assert_eq(t.wall_path_why(c, wind, 3, far, {}), "", "a Wind Wall rises from a point in range")
	assert_eq(t.wall_path_why(c, wind, 3, _cells([[25, 2], [26, 2]]), {}), "That square is out of range (120 ft)", "its first square must be in range")
	assert_eq(t.wall_path_why(c, fire, 4, far, {"range_mult": true}), "", "Distant Spell doubles the range")


func test_straight_walls_go_one_way() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["blade_barrier"], Vector2i(0, 0))
	var t := e.spells.targeting
	var blades := Compendium.shared().spell_data("blade_barrier")
	assert_eq(t.wall_path_why(c, blades, 6, _cells([[2, 2], [3, 3], [4, 4], [5, 5]]), {}), "", "a diagonal line is straight")
	assert_eq(t.wall_path_why(c, blades, 6, _cells([[2, 2], [3, 2], [4, 3]]), {}), "Blade Barrier is a straight wall")
	assert_eq(t.wall_squares(blades, 6), 20, "100 ft")
	assert_eq(t.wall_squares(Compendium.shared().spell_data("wall_of_stone"), 5), 20, "ten 10-ft panels")
	assert_eq(t.wall_squares(Compendium.shared().spell_data("prismatic_wall"), 9), 18, "90 ft")


func test_a_wall_without_a_path_is_straight_along_the_cast_direction() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.high_caster(e, ["wall_of_fire"], Vector2i(0, 0))
	TestCombat.punching_bag(e, Vector2i(11, 0), 300)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "wall_of_fire", 4, [], Vector2(6.5, 3.5), Vector2.ZERO).ok)
	var flat := e.spells.zones.object_of(c.id, "wall_of_fire").cells
	assert_true(flat.size() >= 10 and flat.all(func(x: Vector2i) -> bool: return x.y == 3), "no direction: east to west")
	_cast_again(e, c)
	var again := e.spells.cast(c, "wall_of_fire", 4, [], Vector2(6.5, 3.5), Vector2.DOWN)
	assert_true(again.ok, again.reason)
	var upright := e.spells.zones.object_of(c.id, "wall_of_fire").cells
	assert_true(upright.size() == 8 and upright.all(func(x: Vector2i) -> bool: return x.x == 6), "aimed north to south: %s" % str(upright))
	# A monster's casting (the AI) takes its direction in opts.
	var nums := {"dc": Breakdown.new("DC").add("DC", 15), "attack": Breakdown.new("Attack").add("Attack", 7), "mod": 4}
	_cast_again(e, c)
	var by_numbers := e.spells.cast_with_numbers(c, "wall_of_fire", 4, [], Vector2(6.5, 3.5), nums, {"direction": Vector2.DOWN})
	assert_true(by_numbers.ok, by_numbers.reason)
	assert_true(e.spells.zones.object_of(c.id, "wall_of_fire").cells.all(func(x: Vector2i) -> bool: return x.x == 6))


func test_wall_of_thorns_and_blade_barrier_can_be_rings() -> void:
	var rows: Array[String] = []
	for z in 20:
		rows.append(".".repeat(20))
	var e := TestCombat.encounter(rows)
	var c := TestCombat.caster_with(e, ["wall_of_thorns", "blade_barrier"], Vector2i(0, 0))
	TestCombat.punching_bag(e, Vector2i(19, 0), 300)
	TestCombat.start_with(e, c)
	var nums := {"dc": Breakdown.new("DC").add("DC", 15), "attack": Breakdown.new("Attack").add("Attack", 7), "mod": 4}
	for row: Array in [["wall_of_thorns", 2.0], ["blade_barrier", 6.0]]:
		var id := str(row[0])
		c.action_available = true
		c.magic_action_used = false
		assert_true(e.spells.cast_with_numbers(c, id, 6, [], Vector2(10, 10), nums, {"choice": "ring"}).ok, id)
		var ring := e.spells.zones.object_of(c.id, id).cells
		var radius := float(row[1])
		assert_true(ring.size() > 8, id)
		assert_true(ring.all(func(x: Vector2i) -> bool: return absf((Vector2(x) + Vector2(0.5, 0.5)).distance_to(Vector2(10, 10)) - radius) <= 0.5),
			"%s: a ring %d ft across" % [id, int(radius * 2 * 5)])
		c.creature.concentration.end("test")
		e.spells.zones.prune()


## Ends the caster's wall and gives it its action and its level 4 slot back, to cast again this turn.
func _cast_again(e: Encounter, c: Combatant) -> void:
	c.creature.concentration.end("test")
	e.spells.zones.prune()
	c.action_available = true
	c.magic_action_used = false
	c.cast_slot_spell_this_turn = false
	(c.creature as Character).slots_used[3] = 0


# --- The view's wall drawing (TargetPicker) --------------------------------------------------------

func test_the_view_draws_a_wall_of_fire_square_by_square_then_its_side() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.high_caster(e, ["wall_of_fire"], Vector2i(0, 0))
	TestCombat.start_with(e, c)
	var cat := ActionCatalog.new(e)
	var a := cat.find(c, "spell:wall_of_fire")
	assert_eq(str(a["targeting"]), "wall")
	var picker := TargetPicker.new(e)
	assert_true(picker.begin(c, a, 4) == a and picker.step == "wall")
	assert_eq(str(picker.confirm()["do"]), "refuse", "Enter with nothing drawn")
	assert_true(picker.pick(Vector2i(3, 3), null).is_empty())
	assert_true(picker.pick(Vector2i(6, 3), null).is_empty(), "a click along a straight line adds the squares between")
	assert_eq(picker.path, _cells([[3, 3], [4, 3], [5, 3], [6, 3]]))
	assert_eq(str(picker.pick(Vector2i(4, 3), null)["do"]), "refuse", "no square twice")
	assert_eq(str(picker.pick(Vector2i(9, 5), null)["do"]), "refuse", "not touching")
	assert_true(picker.undo())
	assert_true(picker.pick(Vector2i(6, 4), null).is_empty(), "a diagonal step")
	var shown := picker.show(Vector2i(7, 5), null)
	assert_eq(shown["goal"], [Vector2i(7, 5)] as Array[Vector2i], "the next square")
	assert_true(str(shown["title"]).contains("20 of 60 ft"), str(shown["title"]))
	assert_true(picker.pick(Vector2i(6, 4), null).is_empty(), "a click on the last square ends the drawing")
	assert_eq(picker.step, "side")
	assert_false((picker.show(Vector2i(4, 5), null)["target"] as Array).is_empty(), "the burning side shows")
	assert_eq(str(picker.pick(Vector2i(7, 5), null)["do"]), "refuse", "in line past the end: neither side")
	var cmd := picker.pick(Vector2i(4, 5), null)
	assert_eq(str(cmd["do"]), "perform")
	var opts := (cmd["action"] as Dictionary)["opts"] as Dictionary
	assert_eq(SpellTargeting.path_of(opts), _cells([[3, 3], [4, 3], [5, 3], [6, 4]]))
	assert_eq(str(opts["side"]), "right")
	var r := cat.perform(c, cmd["action"] as Dictionary, cmd["targets"] as Array, cmd["point"] as Vector2, cmd["dir"] as Vector2, 4)
	assert_true(r.ok, r.reason)
	assert_eq(e.spells.zones.object_of(c.id, "wall_of_fire").cells, _cells([[3, 3], [4, 3], [5, 3], [6, 4]]))


func test_the_view_places_a_wall_of_fire_ring_at_a_point() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.high_caster(e, ["wall_of_fire"], Vector2i(0, 0))
	TestCombat.start_with(e, c)
	var a := ActionCatalog.new(e).find(c, "spell:wall_of_fire").duplicate(true)
	a["opts"] = {"choice": "ring"}
	var picker := TargetPicker.new(e)
	var aimed := picker.begin(c, a, 4)
	assert_eq(str(aimed["targeting"]), "point")
	assert_false(picker.active())
	assert_eq(str(a["targeting"]), "wall", "the hotbar's entry is left alone")
	var pv := ActionCatalog.new(e).spell_preview(c, aimed, Vector2(6, 4), Vector2.RIGHT, 4)
	assert_false(Vector2i(6, 4) in (pv["cells"] as Array), "the preview shows the ring, open in the middle")


func test_a_tsunami_aimed_at_a_point_faces_its_caster() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.high_caster(e, ["wall_of_fire"], Vector2i(0, 3))
	var tsunami := {"spell_id": "tsunami"}
	var across := TargetPicker.point_dir(e, c, tsunami, Vector2(8, 3.5))
	assert_true(absf(across.x) < 0.01 and absf(absf(across.y) - 1.0) < 0.01, "east of the caster it runs north-south: %s" % str(across))
	assert_eq(TargetPicker.point_dir(e, c, {"spell_id": "fireball"}, Vector2(8, 3.5)), Vector2.ZERO, "only walls")


# --- Commander's Strike -----------------------------------------------------------------------------

func test_commanders_strike_attacks_the_creature_picked() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var f := _battle_master(e, Vector2i(2, 3))
	var z := e.add(TestCombat.monster("zombie"), &"party", Vector2i(5, 3))
	var first_foe := TestCombat.punching_bag(e, Vector2i(6, 3), 200)
	var picked := TestCombat.punching_bag(e, Vector2i(5, 4), 200)
	TestCombat.start_with(e, f)
	var ch := f.creature as Character
	var dice := ch.resource_left("superiority_dice")
	TestCombat.next_d20(e, 19)
	var r := e.feature_actions.perform(f, "commanders_strike", z, Vector2.INF, "", [z, picked])
	assert_true(r.ok, r.reason)
	assert_true(picked.creature.hp < 200, "the creature picked is struck")
	assert_eq(first_foe.creature.hp, 200, "not the one the automatic pick would take")
	assert_false(z.reaction_available, "the ally's Reaction")
	assert_eq(ch.resource_left("superiority_dice"), dice - 1)


func test_commanders_strike_refuses_a_creature_beyond_the_allys_reach_and_falls_back_without_one() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var f := _battle_master(e, Vector2i(2, 3))
	var z := e.add(TestCombat.monster("zombie"), &"party", Vector2i(5, 3))
	var near := TestCombat.punching_bag(e, Vector2i(6, 3), 200)
	var far := TestCombat.punching_bag(e, Vector2i(10, 7), 200)
	TestCombat.start_with(e, f)
	var ch := f.creature as Character
	var dice := ch.resource_left("superiority_dice")
	var r := e.feature_actions.perform(f, "commanders_strike", z, Vector2.INF, "", [z, far])
	assert_false(r.ok)
	assert_true(r.reason.contains("can't reach"), r.reason)
	assert_true(z.reaction_available, "nothing spent")
	assert_eq(ch.resource_left("superiority_dice"), dice)
	assert_true(e.weapons.strike_option(z, far).is_empty())
	assert_false(e.weapons.strike_option(z, near).is_empty())
	# No creature picked: the best one in its reach, as before.
	TestCombat.next_d20(e, 19)
	assert_true(e.feature_actions.perform(f, "commanders_strike", z, Vector2.INF).ok)
	assert_true(near.creature.hp < 200)


func test_the_view_picks_commanders_strikes_ally_then_its_target() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var f := _battle_master(e, Vector2i(2, 3))
	var z := e.add(TestCombat.monster("zombie"), &"party", Vector2i(5, 3))
	TestCombat.punching_bag(e, Vector2i(6, 3), 200)
	var picked := TestCombat.punching_bag(e, Vector2i(5, 4), 200)
	var far := TestCombat.punching_bag(e, Vector2i(10, 7), 200)
	TestCombat.start_with(e, f)
	var cat := ActionCatalog.new(e)
	var a := cat.find(f, "feat:commanders_strike")
	var picker := TargetPicker.new(e)
	assert_false(picker.second(f, a, f, 0), "not the Battle Master itself")
	assert_true(picker.second(f, a, z, 0))
	assert_eq(picker.step, "strike")
	assert_true(picker.candidate(picked))
	assert_false(picker.candidate(far))
	assert_eq(str(picker.pick(far.cell, far)["do"]), "refuse")
	var cmd := picker.pick(picked.cell, picked)
	assert_eq(cmd["targets"], [z, picked])
	TestCombat.next_d20(e, 19)
	assert_true(cat.perform(f, cmd["action"] as Dictionary, cmd["targets"] as Array, Vector2.INF, Vector2.ZERO).ok)
	assert_true(picked.creature.hp < 200)


# --- Crown of Madness ------------------------------------------------------------------------------

## Crowns `t` for `c` (picking `victim`, or no one with ""), then plays `t`'s next turn with the AI.
func _crown_then_its_turn(e: Encounter, c: Combatant, t: Combatant, victim: String) -> void:
	var r := e.spells.cast(c, "crown_of_madness", 2, [t], Vector2.INF, Vector2.ZERO, {"crown_victim": victim})
	assert_true(r.ok, r.reason)
	assert_true(t.creature.has_flag("crowned"), "the crown takes")
	while e.current() != t:
		e.end_turn()
	TestCombat.next_d20(e, 19)
	e.run_ai_turn()


func test_the_crowned_creature_attacks_the_victim_its_caster_picked() -> void:
	var e := TestCombat.open_field(4)
	e.default_player_reaction = "never"
	var c := TestCombat.caster_with(e, ["crown_of_madness"], Vector2i(0, 0))
	var t := _brute(e, Vector2i(5, 3))
	var first_in_line := _brute(e, Vector2i(5, 4))
	var victim := _brute(e, Vector2i(6, 3))
	TestCombat.start_with(e, c)
	_crown_then_its_turn(e, c, t, victim.id)
	assert_true(victim.creature.hp < 200, "the creature its caster chose")
	assert_eq(first_in_line.creature.hp, 200, "not the first creature in its reach")
	assert_eq(str(e.ai.last_plan.get("why", "")), "Crown of Madness")


func test_the_crowned_creature_acts_normally_with_no_victim_or_one_out_of_reach() -> void:
	for victim_at: Vector2i in [Vector2i(-1, -1), Vector2i(10, 7)]:
		var e := TestCombat.open_field(4)
		e.default_player_reaction = "never"
		var c := TestCombat.caster_with(e, ["crown_of_madness"], Vector2i(0, 0))
		var t := _brute(e, Vector2i(5, 3))
		var friend := _brute(e, Vector2i(5, 4))
		var hero := _brute(e, Vector2i(4, 3), &"party")
		var victim: Combatant = _brute(e, victim_at) if victim_at.x >= 0 else null
		TestCombat.start_with(e, c)
		_crown_then_its_turn(e, c, t, victim.id if victim != null else "")
		assert_ne(str(e.ai.last_plan.get("why", "")), "Crown of Madness", "no forced attack (%s)" % str(victim_at))
		assert_eq(friend.creature.hp, 200, "its own side is left alone")
		assert_true(hero.creature.hp < 200, "it fights as it would (%s)" % str(victim_at))
		if victim != null:
			assert_eq(victim.creature.hp, 200)


func test_casting_refuses_the_crowned_creature_or_its_caster_as_the_victim() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["crown_of_madness"], Vector2i(0, 0))
	var t := _brute(e, Vector2i(5, 3))
	TestCombat.start_with(e, c)
	assert_eq(e.spells.cast(c, "crown_of_madness", 2, [t], Vector2.INF, Vector2.ZERO, {"crown_victim": t.id}).reason, "It must attack a creature other than itself")
	assert_eq(e.spells.cast(c, "crown_of_madness", 2, [t], Vector2.INF, Vector2.ZERO, {"crown_victim": c.id}).reason, "It is Charmed by you and can't attack you")


func test_keeping_control_names_the_next_victim_or_no_one() -> void:
	var e := TestCombat.open_field(4)
	e.default_player_reaction = "never"
	var c := TestCombat.caster_with(e, ["crown_of_madness"], Vector2i(0, 0))
	var t := _brute(e, Vector2i(5, 3))
	var first_victim := _brute(e, Vector2i(5, 4))
	var next_victim := _brute(e, Vector2i(6, 3))
	TestCombat.start_with(e, c)
	_crown_then_its_turn(e, c, t, first_victim.id)
	assert_true(first_victim.creature.hp < 200)
	while e.current() != c:
		e.end_turn()
	var keep := e.spells.sustained_for(c, "crown_of_madness")
	assert_false(keep.is_empty(), "the keep-control action")
	assert_true(e.spells.use_sustained(c, str(keep["id"]), [t]).reason.contains("other than itself"), "never itself")
	var r := e.spells.use_sustained(c, str(keep["id"]), [next_victim])
	assert_true(r.ok, r.reason)
	assert_false(c.action_available, "a Magic action")
	assert_eq(str(t.get_meta("crown_victim", "")), next_victim.id)
	while e.current() != t:
		e.end_turn()
	TestCombat.next_d20(e, 19)
	e.run_ai_turn()
	assert_true(next_victim.creature.hp < 200, "the new victim")
	assert_true(t.creature.has_flag("crowned"), "still crowned")
	# Keeping control naming no one: it acts normally.
	while e.current() != c:
		e.end_turn()
	var keep2 := e.spells.sustained_for(c, "crown_of_madness")
	assert_true(e.spells.use_sustained(c, str(keep2["id"]), []).ok)
	assert_eq(str(t.get_meta("crown_victim", "x")), "")


func test_an_ai_caster_still_picks_the_victim_itself() -> void:
	var e := TestCombat.open_field(4)
	var ch := TestChars.pregen("silvain_aster", 9)
	((ch.spellcasting[0] as Dictionary)["prepared"] as Array).append("crown_of_madness")
	var c := e.add(ch, &"enemy", Vector2i(0, 0))
	var t := _brute(e, Vector2i(5, 3), &"party")
	var hero := _brute(e, Vector2i(5, 4), &"party")
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "crown_of_madness", 2, [t]).ok)
	assert_true(e.compelled(t), "the crowned party member is played by the crown")
	while e.current() != t:
		e.end_turn()
	TestCombat.next_d20(e, 19)
	e.run_ai_turn()
	assert_true(hero.creature.hp < 200, "the AI's pick: a creature in its reach, its caster's foes first")


func test_the_view_picks_the_crowns_victim_after_its_target() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["crown_of_madness"], Vector2i(0, 0))
	var t := _brute(e, Vector2i(5, 3))
	var victim := _brute(e, Vector2i(6, 3))
	TestCombat.start_with(e, c)
	var cat := ActionCatalog.new(e)
	var a := cat.find(c, "spell:crown_of_madness")
	var picker := TargetPicker.new(e)
	assert_true(picker.second(c, a, t, 2))
	assert_eq(picker.step, "victim")
	assert_eq(str(picker.pick(c.cell, c)["do"]), "refuse", "not its charmer")
	assert_true(picker.undo(), "back to the target")
	assert_false(picker.active())
	assert_true(picker.second(c, a, t, 2))
	var none := picker.confirm()
	assert_eq(str(((none["action"] as Dictionary)["opts"] as Dictionary)["crown_victim"]), "", "Enter: no one")
	var cmd := picker.pick(victim.cell, victim)
	assert_eq(str(((cmd["action"] as Dictionary)["opts"] as Dictionary)["crown_victim"]), victim.id)
	assert_eq(cmd["targets"], [t])
	assert_true(cat.perform(c, cmd["action"] as Dictionary, cmd["targets"] as Array, Vector2.INF, Vector2.ZERO, 2).ok)
	assert_eq(str(t.get_meta("crown_victim", "")), victim.id)
	# On a later turn the keep-control action, with no target on the hotbar, still picks the victim here.
	while e.current() != c:
		e.end_turn()
	var keep := {}
	for x in cat.actions_for(c):
		if str(x["kind"]) == "sustain" and str(x["spell_id"]) == "crown_of_madness":
			keep = x
	assert_eq(str(keep.get("targeting", "")), "none")
	assert_true(picker.takes(c, keep))
	picker.begin(c, keep, 0)
	assert_eq(picker.step, "victim")
	assert_eq(picker.first, t)
	var kept := picker.pick(t.cell, t)
	assert_eq(kept["targets"], [], "a click on the crowned creature: no one")


# --- Maneuvering Attack ----------------------------------------------------------------------------

func test_maneuvering_attack_moves_the_ally_with_its_reaction_and_no_attack_from_the_target() -> void:
	var e := TestCombat.open_field(5)
	e.default_player_reaction = "never"
	var f := _battle_master(e, Vector2i(2, 3))
	var target := TestCombat.foe(e, "berserker", Vector2i(3, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(4, 3))
	var other := TestCombat.foe(e, "berserker", Vector2i(4, 4))
	TestCombat.start_with(e, f)
	assert_true(e.features.toggle_rider(f, "maneuver:maneuvering_attack").ok)
	TestCombat.next_d20(e, 19)
	var hit := e.attack(f, target, _melee(e, f))
	assert_true(hit.ok and hit.hit, hit.reason)
	assert_eq(ally.free_move_ft, 0, "no free movement the ally could never use")
	assert_false(e.movement.open_reaction_move().is_empty(), "the move is offered")
	assert_ne(e.movement.reaction_mover_why(f), "", "not the attacker itself")
	assert_eq(e.reaction_move(ally, Vector2i(8, 3)).reason, "Can't get there with 15 ft", "half its Speed")
	var r := e.reaction_move(ally, Vector2i(6, 1))
	assert_true(r.ok, r.reason)
	assert_eq(ally.cell, Vector2i(6, 1))
	assert_false(ally.reaction_available, "the ally's Reaction")
	assert_true(target.reaction_available, "no Opportunity Attack from the creature hit")
	assert_false(other.reaction_available, "another enemy still gets its Opportunity Attack")
	assert_true(e.movement.open_reaction_move().is_empty(), "taken")
	assert_false(e.reaction_move(ally, Vector2i(6, 2)).ok, "only once")


func test_the_offered_move_lapses_when_the_turn_moves_on() -> void:
	var e := TestCombat.open_field(5)
	var f := _battle_master(e, Vector2i(2, 3))
	var target := TestCombat.foe(e, "berserker", Vector2i(3, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(4, 3))
	TestCombat.start_with(e, f)
	e.movement.offer_reaction_move(f, target, "Maneuvering Attack")
	assert_eq(e.movement.reaction_mover_why(ally), "")
	e.end_turn()
	assert_true(e.movement.open_reaction_move().is_empty())
	assert_false(e.reaction_move(ally, Vector2i(5, 2)).ok)


func test_the_view_picks_the_maneuvering_ally_and_its_square() -> void:
	var e := TestCombat.open_field(5)
	e.default_player_reaction = "never"
	var f := _battle_master(e, Vector2i(2, 3))
	var target := TestCombat.foe(e, "berserker", Vector2i(3, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(4, 3))
	TestCombat.start_with(e, f)
	var picker := TargetPicker.new(e)
	assert_false(picker.begin_move(f), "nothing offered yet")
	e.movement.offer_reaction_move(f, target, "Maneuvering Attack")
	assert_true(picker.begin_move(f))
	assert_eq(picker.step, "square", "the only ally who can moves")
	assert_eq(picker.first, ally)
	var view := picker.show(Vector2i(5, 1), null)
	assert_true(Vector2i(5, 1) in (view["area"] as Array))
	assert_eq(str(picker.pick(Vector2i(9, 3), null)["do"]), "refuse", "too far")
	var cmd := picker.pick(Vector2i(5, 1), null)
	assert_eq(str(cmd["do"]), "move")
	assert_true(e.reaction_move(cmd["ally"] as Combatant, cmd["cell"] as Vector2i).ok)
	assert_eq(ally.cell, Vector2i(5, 1))
	# Backing out passes on the move.
	var picker2 := TargetPicker.new(e)
	e.movement.offer_reaction_move(f, target, "Maneuvering Attack")
	assert_false(picker2.begin_move(f), "the ally's Reaction is spent: no one can take it")
	assert_true(e.movement.open_reaction_move().is_empty(), "and the offer is passed on")


# --- Eldritch Blast ------------------------------------------------------------------------------------

## The attack rolls made at `t` since event `from`.
func _attacks_at(e: Encounter, from: int, t: Combatant) -> int:
	var n := 0
	for i in range(from, e.events.size()):
		var ev := e.events[i] as Dictionary
		if str(ev.get("type", "")) == "attack" and str(ev.get("target", "")) == t.id:
			n += 1
	return n


func test_eldritch_blast_takes_a_pick_for_each_beam() -> void:
	var e := TestCombat.open_field(3)
	var kip := TestCombat.hero(e, "kip_smudgewick", Vector2i(1, 3), 5)
	TestCombat.punching_bag(e, Vector2i(6, 3), 200)
	TestCombat.start_with(e, kip)
	var a := ActionCatalog.new(e).find(kip, "spell:eldritch_blast")
	assert_false(a.is_empty(), "Kip knows Eldritch Blast")
	assert_eq(str(a["targeting"]), "multi")
	assert_eq(int(a["count"]), 2, "two beams at character level 5")
	assert_true(bool(a["repeat"]), "both beams may go at one target")


func test_eldritch_blast_beams_go_where_they_are_aimed() -> void:
	var e := TestCombat.open_field(3)
	var kip := TestCombat.hero(e, "kip_smudgewick", Vector2i(1, 3), 5)
	var one := TestCombat.punching_bag(e, Vector2i(6, 2), 200)
	var two := TestCombat.punching_bag(e, Vector2i(6, 5), 200)
	TestCombat.start_with(e, kip)
	var mark := e.events.size()
	var r := e.spells.cast(kip, "eldritch_blast", 0, [one, two])
	assert_true(r.ok, r.reason)
	assert_eq(_attacks_at(e, mark, one), 1, "a beam at the first")
	assert_eq(_attacks_at(e, mark, two), 1, "a beam at the second")
	kip.action_available = true
	mark = e.events.size()
	assert_true(e.spells.cast(kip, "eldritch_blast", 0, [one]).ok)
	assert_eq(_attacks_at(e, mark, one), 2, "both beams at one target")
	kip.action_available = true
	assert_eq(e.spells.cast(kip, "eldritch_blast", 0, [one, two, one]).reason, "Eldritch Blast has 2 beams")
