extends TestCase
## What creatures do with the battlefield's objects (F5 piece 3, combat/object_actions.gd and combat/object_fire.gd):
## doors opened and shut with the free object interaction (a locked one stays shut), a crate shoved into a creature, off
## a ledge onto one below and over a chasm's edge, a bookcase and a brazier pushed over, a chair and a thing from the
## ground thrown, fire spreading as a round ends, a barrel of lamp oil bursting (and spilling when broken otherwise),
## creatures flying above all of it left alone, a saved fight keeping it, and the view moving and wrecking the art.


func _place(e: Encounter, kind: String, cell: Vector2i, extra: Dictionary = {}) -> BattleObject:
	var one: Array[Vector2i] = [cell]
	return e.objects.add(kind, one, extra)


## A foe that fails every Strength and Dexterity save.
func _stunned_bag(e: Encounter, cell: Vector2i) -> Combatant:
	var bag := TestCombat.punching_bag(e, cell, 80)
	bag.creature.add_condition(&"stunned", "test")
	return bag


func _option(e: Encounter, c: Combatant, prefix: String) -> Dictionary:
	for o in e.attack_options(c):
		if str(o["id"]).begins_with(prefix):
			return o
	return {}


func test_a_door_opens_and_shuts_with_the_free_object_interaction() -> void:
	var e := TestCombat.encounter(["....#....", ".........", "....#....", ".........", "....#...."], 4)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(3, 1))
	TestCombat.foe(e, "wolf", Vector2i(8, 4))
	var door := _place(e, "door_wood", Vector2i(4, 1), {"name": "the cellar door"})
	var gate := _place(e, "door_iron", Vector2i(4, 3), {"name": "the iron gate", "locked": true})
	TestCombat.start_with(e, ilse)
	assert_true(e.grid.has_flag(Vector2i(4, 1), CombatGrid.WALL), "a shut door fills its doorway")
	var cat := ActionCatalog.new(e)
	var open := cat.find(ilse, "door:" + door.id)
	assert_eq(str(open["label"]), "Open the cellar door")
	assert_true(bool(open["legal"]) and str(open["cost"]) == "free", str(open))
	assert_true(cat.perform(ilse, open).ok)
	assert_true(door.open and not e.grid.has_flag(Vector2i(4, 1), CombatGrid.WALL), "open: the way through")
	assert_false(ilse.free_interaction_available, "the free object interaction")
	assert_true(e.reachable_for(ilse).has(Vector2i(5, 1)))
	assert_true(e.objects.blocking_at(Vector2i(4, 1)) == null, "an open door fills nothing")
	var shut := cat.find(ilse, "door:" + door.id)
	assert_eq(str(shut["label"]), "Shut the cellar door")
	assert_eq(str(shut["cost"]), "action", "the next one is the Utilize action")
	var bag := TestCombat.punching_bag(e, Vector2i(4, 1))
	assert_true(e.objects.actions.door_why(ilse, door).ends_with("stands in the doorway"), "not on someone")
	bag.cell = Vector2i(6, 1)
	assert_true(e.objects.actions.toggle_door(ilse, door.id).ok)
	assert_false(ilse.action_available)
	assert_true(not door.open and e.grid.has_flag(Vector2i(4, 1), CombatGrid.WALL), "shut again")
	ilse.cell = Vector2i(3, 3)
	ilse.free_interaction_available = true
	assert_eq(e.objects.actions.door_why(ilse, gate), "Locked", "a locked door stays shut")
	var menu := cat.square_actions(ilse, Vector2i(4, 3))
	assert_true(menu.any(func(x: Dictionary) -> bool: return str(x["label"]) == "Open the iron gate" and not bool(x["enabled"])))


func test_a_shoved_crate_slides_and_knocks_down_whoever_it_hits() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	var crate := _place(e, "crate", Vector2i(3, 3))
	var bag := _stunned_bag(e, Vector2i(5, 3))
	TestCombat.start_with(e, ilse)
	var cat := ActionCatalog.new(e)
	var line := cat.square_actions(ilse, Vector2i(3, 3)).filter(func(x: Dictionary) -> bool: return str(x["label"]).begins_with("Shove the crate"))
	assert_eq(line.size(), 1, "Shove the crate (Athletics DC 8)")
	TestCombat.next_d20(e, 19)
	assert_true(cat.perform(ilse, (line[0] as Dictionary)["action"] as Dictionary).ok)
	assert_eq(crate.cells[0], Vector2i(4, 3), "5 ft straight away")
	assert_false(e.grid.has_flag(Vector2i(3, 3), CombatGrid.LOW))
	assert_true(e.grid.has_flag(Vector2i(4, 3), CombatGrid.LOW))
	assert_false(ilse.action_available, "one attack of the Attack action")
	assert_eq(crate.home, Vector2i(3, 3), "where it stood when the fight began")
	ilse.cell = Vector2i(3, 3)
	ilse.action_available = true
	ilse.attacks_left = 0
	TestCombat.next_d20(e, 19)
	assert_true(e.objects.actions.shove(ilse, crate.id).ok)
	assert_eq(crate.cells[0], Vector2i(4, 3), "it stops against the creature")
	assert_true(bag.creature.hp < 80, "a knock")
	assert_true(bag.creature.has_condition(&"prone"), "and down it goes")
	var wall := TestCombat.encounter(["....#", "....#", "....#"], 4)
	var hedda := TestCombat.hero(wall, "hedda_ironvow", Vector2i(2, 1))
	var box := _place(wall, "crate", Vector2i(3, 1))
	TestCombat.foe(wall, "wolf", Vector2i(0, 0))
	TestCombat.start_with(wall, hedda)
	assert_eq(wall.objects.actions.shove_why(hedda, box), "A wall is in the way")
	assert_eq(wall.objects.actions.shove_why(hedda, _place(wall, "gravestone", Vector2i(1, 1))), "Too heavy or fixed to shove")


func test_a_crate_shoved_off_a_ledge_falls_on_whoever_is_below_but_not_on_a_flyer() -> void:
	var e := TestCombat.encounter(["22....", "22....", "22....", "22...."], 4)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(0, 1))
	var hedda := TestCombat.hero(e, "hedda_ironvow", Vector2i(0, 3))
	var crate := _place(e, "crate", Vector2i(1, 1))
	var barrel := _place(e, "barrel", Vector2i(1, 3))
	var bag := _stunned_bag(e, Vector2i(2, 1))
	var owl := TestCombat.foe(e, "giant_owl", Vector2i(2, 3))
	owl.altitude = 10
	TestCombat.start_with(e, ilse)
	var to := e.objects.actions.shove_to(ilse, crate)
	assert_eq(int(to["fall"]), 10, "a 10 ft drop")
	e.objects.actions.push(crate, to, ilse)
	assert_true(bag.creature.hp < 80, "1d6 for the 10 ft it fell")
	assert_true(bag.creature.has_condition(&"prone"))
	assert_true(crate.destroyed, "it breaks on the creature below")
	assert_true(e.grid.has_flag(Vector2i(2, 1), CombatGrid.DIFFICULT), "its rubble")
	var owl_hp := owl.creature.hp
	var to2 := e.objects.actions.shove_to(hedda, barrel)
	assert_true(to2["who"] == null, "a flyer over the square is above it")
	e.objects.actions.push(barrel, to2, hedda)
	assert_eq(owl.creature.hp, owl_hp, "the owl isn't hit")
	assert_eq(barrel.cells[0], Vector2i(2, 3), "the barrel lands on the floor under it")
	assert_true(barrel.hp < 18 and not barrel.destroyed, "1d6 for its own fall")
	assert_true(e.grid.has_flag(Vector2i(2, 3), CombatGrid.LOW))


func test_a_crate_shoved_over_a_chasms_edge_is_gone() -> void:
	var e := TestCombat.encounter(["......", "......", "      ", "      "], 4)
	e.grid.drop_ft = 200
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 0))
	var crate := _place(e, "crate", Vector2i(2, 1))
	TestCombat.foe(e, "wolf", Vector2i(5, 0))
	TestCombat.start_with(e, ilse)
	var to := e.objects.actions.shove_to(ilse, crate)
	assert_eq(str(to["gone"]), "drop")
	e.objects.actions.push(crate, to, ilse)
	assert_true(crate.destroyed, "over the edge: gone")
	assert_false(e.grid.has_flag(Vector2i(2, 1), CombatGrid.LOW), "its square is open")


func test_a_bookcase_pushed_over_falls_across_two_squares() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	var shelves := _place(e, "shelves", Vector2i(3, 3))
	var crate := _place(e, "crate", Vector2i(4, 3))
	var bag := _stunned_bag(e, Vector2i(5, 3))
	var far := TestCombat.punching_bag(e, Vector2i(6, 3), 80)
	TestCombat.start_with(e, ilse)
	var cat := ActionCatalog.new(e)
	var push := cat.square_actions(ilse, Vector2i(3, 3)).filter(func(x: Dictionary) -> bool: return str(x["label"]).begins_with("Push the shelves over"))
	assert_eq(push.size(), 1, "Push the shelves over (Athletics DC 12)")
	var line: Array[Vector2i] = [Vector2i(4, 3), Vector2i(5, 3)]
	assert_eq(e.objects.actions.topple_line(ilse, shelves), line, "two squares straight away")
	TestCombat.next_d20(e, 19)
	assert_true(cat.perform(ilse, (push[0] as Dictionary)["action"] as Dictionary).ok)
	assert_false(ilse.action_available, "the Utilize action")
	assert_true(shelves.destroyed and not e.grid.has_flag(Vector2i(3, 3), CombatGrid.LOW), "it went over")
	assert_true(bag.creature.hp < 80 and bag.creature.has_condition(&"prone"), "1d10 and Prone on a failed Dexterity save")
	assert_eq(far.creature.hp, 80, "two squares long: no further")
	assert_true(crate.destroyed or crate.hp < 4, "the crate under it takes the blow too")
	assert_true(e.grid.has_flag(Vector2i(5, 3), CombatGrid.DIFFICULT), "rubble where it lies")
	assert_eq(shelves.wreck, line)
	# Against a wall it's pulled down the other way, and the one pulling steps clear.
	var hall := TestCombat.encounter(["#####", ".....", ".....", "....."], 4)
	var hedda2 := TestCombat.hero(hall, "hedda_ironvow", Vector2i(2, 2))
	var case := _place(hall, "shelves", Vector2i(2, 1))
	var under := _stunned_bag(hall, Vector2i(2, 3))
	TestCombat.start_with(hall, hedda2)
	var pulled: Array[Vector2i] = [Vector2i(2, 2), Vector2i(2, 3)]
	assert_eq(hall.objects.actions.topple_line(hedda2, case), pulled, "pulled down away from the wall")
	var hedda_hp := hedda2.creature.hp
	hall.objects.actions.fall_over(case, pulled, hedda2, [])
	assert_eq(hedda2.creature.hp, hedda_hp, "the one pulling steps clear")
	assert_true(under.creature.hp < 80 and under.creature.has_condition(&"prone"))
	# A brazier spills its coals; a flyer over the squares is above the fall.
	var hedda := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 6))
	var brazier := _place(e, "brazier", Vector2i(3, 6))
	var owl := TestCombat.foe(e, "giant_owl", Vector2i(4, 6))
	owl.altitude = 10
	var owl_hp := owl.creature.hp
	e.objects.actions.fall_over(brazier, e.objects.actions.topple_line(hedda, brazier), hedda, [])
	assert_eq(owl.creature.hp, owl_hp, "the owl flies above it")
	assert_true(bool(e.objects.square_at(Vector2i(4, 6)).get("lit", false)), "burning coals")


func test_a_chair_and_a_thing_on_the_ground_are_thrown() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	var chair := _place(e, "chair", Vector2i(3, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(6, 3), 80)
	TestCombat.start_with(e, ilse)
	var flung := _option(e, ilse, "improvised:o:" + chair.id)
	assert_false(flung.is_empty(), "a chair within reach is a weapon")
	var p := flung["profile"] as WeaponProfile
	assert_eq([p.damage_dice, p.normal_range, p.long_range], ["1d4", 20, 60], "an improvised weapon")
	assert_false(p.proficient, "no Proficiency Bonus without proficiency in improvised weapons")
	TestCombat.next_d20(e, 19)
	var r := e.attack(ilse, bag, str(flung["id"]))
	assert_true(r.ok and r.hit, r.reason)
	assert_true(chair.destroyed and not e.grid.has_flag(Vector2i(3, 3), CombatGrid.LOW), "it breaks where it lands")
	assert_false(ilse.free_interaction_available, "picked up with the free object interaction")
	e.ground.land(ilse, "javelin", {}, "", null, Vector2i(2, 4))
	var javelin := _option(e, ilse, "improvised:g:")
	assert_false(javelin.is_empty())
	assert_eq((javelin["profile"] as WeaponProfile).damage_dice, "1d6", "a thrown weapon from the ground is itself")
	assert_eq(e.attack_legal(ilse, bag, javelin), "No free object interaction left to pick it up")
	ilse.free_interaction_available = true
	ilse.action_available = true
	TestCombat.next_d20(e, 19)
	assert_true(e.attack(ilse, bag, str(javelin["id"])).ok)
	assert_eq(e.ground.items.size(), 1)
	assert_eq(e.ground.items[0]["cell"], bag.cell, "it comes down by its target")


func test_fire_spreads_as_the_round_ends() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(0, 0))
	TestCombat.foe(e, "wolf", Vector2i(11, 7))
	var table := _place(e, "table", Vector2i(3, 3))
	var crate := _place(e, "crate", Vector2i(3, 4))
	var stone := _place(e, "gravestone", Vector2i(2, 3))
	var far := _place(e, "crate", Vector2i(6, 3))
	e.objects.squares.append({"cell": Vector2i(4, 3), "oil": true, "lit": false, "hit": {}})
	TestCombat.start_with(e, ilse)
	e.objects.ignite(table)
	# A d6 of 4 or more for the crate beside it.
	for s in range(1, 500):
		if DiceRoller.new(s).roll_one(6) >= ObjectFire.SPREAD_ON:
			e.dice.reseed(s)
			break
	e.objects.fire.spread()
	assert_true(bool(e.objects.square_at(Vector2i(4, 3))["lit"]), "the oil beside it lights")
	assert_true(crate.burning, "the crate beside it catches")
	assert_false(stone.burning, "stone doesn't burn")
	assert_false(far.burning, "only what's beside a fire")


func test_a_barrel_of_lamp_oil_bursts_when_fire_reaches_it() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 3))
	var barrel := _place(e, "oil_barrel", Vector2i(5, 3))
	var next := _place(e, "oil_barrel", Vector2i(7, 3))
	var spare := _place(e, "oil_barrel", Vector2i(10, 6))
	var bag := _stunned_bag(e, Vector2i(6, 3))
	var owl := TestCombat.foe(e, "giant_owl", Vector2i(5, 4))
	owl.altitude = 30
	TestCombat.start_with(e, ilse)
	var hp := ilse.creature.hp
	var owl_hp := owl.creature.hp
	assert_true(barrel.describe().has("Bursts into flame if fire reaches it"))
	e.objects.damage(barrel, [{"amount": 1, "type": "fire"}], ilse, "a torch")
	assert_true(barrel.destroyed, "it bursts")
	assert_true(next.destroyed, "the barrel beside it goes up too")
	assert_true(bag.creature.hp < 80, "2d6 Fire on a failed Dexterity save")
	assert_eq(ilse.creature.hp, hp, "20 ft away: out of it")
	assert_eq(owl.creature.hp, owl_hp, "30 ft up: out of it")
	assert_true(bool(e.objects.square_at(Vector2i(4, 3)).get("lit", false)), "the oil burns on the floor round it")
	assert_false(spare.destroyed, "out of reach")
	e.objects.damage(spare, [{"amount": 40, "type": "slashing"}], ilse, "an axe")
	assert_true(spare.destroyed)
	var spill := e.objects.square_at(Vector2i(10, 6))
	assert_true(bool(spill.get("oil", false)) and not bool(spill.get("lit", false)), "broken open, it spills its oil")


func test_burning_oil_burns_only_creatures_on_the_floor() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(0, 0))
	var bag := TestCombat.punching_bag(e, Vector2i(3, 3), 80)
	var owl := TestCombat.foe(e, "giant_owl", Vector2i(3, 3))
	owl.altitude = 10
	TestCombat.start_with(e, ilse)
	e.objects.burning_square(Vector2i(3, 3), "test")
	var owl_hp := owl.creature.hp
	e.objects.turn_end(owl)
	e.objects.turn_end(bag)
	assert_eq(owl.creature.hp, owl_hp, "flying over it")
	assert_eq(bag.creature.hp, 75, "5 Fire to one standing in it")


func test_a_saved_fight_keeps_doors_moved_things_and_wreckage() -> void:
	var e := TestCombat.encounter(["....#.......", "............", "....#.......", "............"], 4)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	TestCombat.foe(e, "wolf", Vector2i(11, 0))
	var door := _place(e, "door_wood", Vector2i(4, 1))
	var crate := _place(e, "crate", Vector2i(6, 3))
	var shelves := _place(e, "shelves", Vector2i(8, 1))
	e.objects.placed = true
	TestCombat.start_with(e, ilse)
	e.objects.actions.set_door(door, true)
	e.objects.actions.push(crate, {"cell": Vector2i(7, 3), "who": null, "fall": 0, "gone": "", "why": ""}, ilse)
	var line: Array[Vector2i] = [Vector2i(9, 1), Vector2i(10, 1)]
	e.objects.actions.fall_over(shelves, line, ilse, [])
	var back := JSON.parse_string(JSON.stringify(EncounterSnapshot.capture(e))) as Dictionary
	var e2 := EncounterSnapshot.restore(back, DiceRoller.new(1))
	assert_true(e2.objects.get_object(door.id).open, "the door stands open")
	assert_false(e2.grid.has_flag(Vector2i(4, 1), CombatGrid.WALL))
	var crate2 := e2.objects.get_object(crate.id)
	assert_eq([crate2.cells[0], crate2.home], [Vector2i(7, 3), Vector2i(6, 3)], "where it was shoved, and where it began")
	assert_true(e2.grid.has_flag(Vector2i(7, 3), CombatGrid.LOW) and not e2.grid.has_flag(Vector2i(6, 3), CombatGrid.LOW))
	assert_eq(e2.objects.get_object(shelves.id).wreck, line, "its wreckage where it fell")
	assert_eq(e2.objects.get_object(shelves.id).moves, "topple")
	# A crate on a raised square keeps the square's height (its letter is '=').
	var dais := TestCombat.encounter(["11..", "11..", "...."], 4)
	TestCombat.hero(dais, "ilse_varga", Vector2i(3, 2))
	TestCombat.foe(dais, "wolf", Vector2i(3, 0))
	_place(dais, "crate", Vector2i(1, 1))
	var dais2 := EncounterSnapshot.restore(JSON.parse_string(JSON.stringify(EncounterSnapshot.capture(dais))) as Dictionary, DiceRoller.new(1))
	assert_eq(dais2.grid.height(Vector2i(1, 1)), 5, "still 5 ft up under the crate")
	assert_eq(dais2.grid.height(Vector2i(0, 1)), 5)


func test_the_view_moves_shoved_art_and_wrecks_what_fell() -> void:
	var e := TestCombat.encounter(["........", "........", "........", "........", "........", "........"], 4)
	e.grid.set_flag(Vector2i(4, 4), CombatGrid.LOW, true)
	var board := ArenaBoard.build(e.grid, "shop")
	add_child(board)
	BattleScenery.from_board(e, board)
	var crate := e.objects.blocking_at(Vector2i(4, 4))
	assert_true(crate != null and crate.kind == "crate", "the shop's crate")
	var view := ObjectView.create(board)
	add_child(view)
	view.sync(e.objects)
	var art: Array = board.dressing.get(Vector2i(4, 4), [])
	assert_false(art.is_empty())
	var piece := art[0] as Node3D
	var x := piece.position.x
	e.objects.actions.push(crate, {"cell": Vector2i(5, 4), "who": null, "fall": 0, "gone": "", "why": ""}, null)
	view.sync(e.objects)
	assert_false(board.dressing.has(Vector2i(4, 4)), "the square it left")
	assert_eq(board.dressing.get(Vector2i(5, 4), []), art, "its pieces go with it")
	assert_between(piece.position.x, x + 0.99, x + 1.01, "a square over")
	assert_eq(piece.get_meta("moved_cell"), Vector2i(5, 4), "for the rest of the visit")
	var shelves := _place(e, "shelves", Vector2i(2, 2))
	var line: Array[Vector2i] = [Vector2i(3, 2), Vector2i(4, 2)]
	e.objects.actions.fall_over(shelves, line, null, [])
	view.sync(e.objects)
	assert_true(board.get_node_or_null("Wreckage_4_2_0") != null, "wreckage where it fell")
	view.queue_free()
	board.queue_free()
