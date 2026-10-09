extends TestCase
## Objects and surfaces in fights (F5, combat/encounter_objects.gd): Armor Class and Hit Points by the 2024 tables,
## Immunity to Poison and Psychic, doors, crates and webs broken, Fire Bolt setting a table alight, Fireball's area
## reaching objects, Oil on a creature and on the floor, a burning Web, the giant spider's web destroyed to free its
## prey, a chandelier dropped, Adamantine and the Sword of Sharpness against objects, the square menu, a saved fight,
## the scenery placed from a board, and the view.


func _place(e: Encounter, kind: String, cells: Array) -> BattleObject:
	var typed: Array[Vector2i] = []
	for c: Variant in cells:
		typed.append(c as Vector2i)
	return e.objects.add(kind, typed)


func test_armor_class_and_hit_points_follow_the_2024_tables() -> void:
	var e := TestCombat.open_field()
	var crate := _place(e, "crate", [Vector2i(5, 3)])
	assert_eq([crate.ac, crate.hp], [15, 4], "a crate: wood, Medium, fragile")
	var barrel := _place(e, "barrel", [Vector2i(6, 3)])
	assert_eq([barrel.ac, barrel.hp], [15, 18], "a barrel: wood, Medium, resilient")
	var gate := _place(e, "door_iron", [Vector2i(7, 3)])
	assert_eq([gate.ac, gate.hp], [19, 18], "an iron door: iron, Medium, resilient")
	assert_eq(_place(e, "gravestone", [Vector2i(8, 3)]).ac, 17, "stone")
	assert_eq(_place(e, "cart", [Vector2i(9, 3)]).hp, 27, "a cart: Large, resilient")
	var chain := _place(e, "chandelier", [Vector2i(2, 2)])
	assert_eq([chain.ac, chain.hp], [19, 5], "a chandelier's chain: iron, Tiny, resilient")
	assert_true(e.grid.has_flag(Vector2i(5, 3), CombatGrid.LOW), "a crate is low cover")
	assert_true(e.grid.has_flag(Vector2i(7, 3), CombatGrid.WALL), "a door fills its square")
	assert_false(e.grid.has_flag(Vector2i(2, 2), CombatGrid.LOW), "a chandelier hangs over its square")


func test_objects_take_no_poison_or_psychic_damage() -> void:
	var e := TestCombat.open_field()
	var barrel := _place(e, "barrel", [Vector2i(5, 3)])
	assert_eq(e.objects.damage(barrel, [{"amount": 10, "type": "poison"}, {"amount": 10, "type": "psychic"}], null, "test"), 0)
	assert_eq(barrel.hp, 18, "Immunity to Poison and Psychic")
	assert_eq(e.objects.damage(barrel, [{"amount": 5, "type": "slashing"}], null, "test"), 5)
	assert_eq(barrel.hp, 13)


func test_a_broken_door_opens_the_way() -> void:
	var e := TestCombat.encounter(["..........", "....#.....", "....#.....", "....#....."], 4)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(3, 2))
	TestCombat.foe(e, "wolf", Vector2i(8, 0))
	var door := _place(e, "door_wood", [Vector2i(4, 2)])
	TestCombat.start_with(e, ilse)
	TestCombat.next_d20(e, 19)
	var r := e.objects.attack(ilse, door.id, "weapon:greatsword")
	assert_true(r.ok and r.hit, r.reason)
	assert_true(door.hp < 18 and not ilse.action_available, "the blow lands, one attack of the Attack action")
	e.objects.damage(door, [{"amount": 20, "type": "bludgeoning"}], ilse, "test")
	assert_true(door.destroyed)
	assert_false(e.grid.has_flag(Vector2i(4, 2), CombatGrid.WALL), "the doorway is open")
	assert_true(e.reachable_for(ilse).has(Vector2i(5, 2)), "and passable")


func test_a_broken_crate_leaves_rubble() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	TestCombat.foe(e, "wolf", Vector2i(11, 7))
	var crate := _place(e, "crate", [Vector2i(3, 3)])
	TestCombat.start_with(e, ilse)
	assert_false(e.reachable_for(ilse).has(Vector2i(3, 3)), "a crate fills its square")
	TestCombat.next_d20(e, 19)
	assert_true(e.objects.attack(ilse, crate.id, "weapon:greatsword").hit)
	assert_true(crate.destroyed, "4 Hit Points: one blow")
	assert_false(e.grid.has_flag(Vector2i(3, 3), CombatGrid.LOW))
	assert_true(e.grid.has_flag(Vector2i(3, 3), CombatGrid.DIFFICULT), "rubble: Difficult Terrain")
	var reach := e.reachable_for(ilse)
	assert_eq(int((reach[Vector2i(3, 3)] as Dictionary)["cost"]), 10, "into the rubble at double cost")


func test_the_square_menu_attacks_what_stands_there() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	TestCombat.foe(e, "wolf", Vector2i(11, 7))
	var crate := _place(e, "crate", [Vector2i(3, 3)])
	TestCombat.start_with(e, ilse)
	var cat := ActionCatalog.new(e)
	var lines := cat.square_actions(ilse, crate.cells[0]).filter(func(x: Dictionary) -> bool: return str(x["label"]) == "Attack the crate: Greatsword")
	assert_eq(lines.size(), 1, "Attack the crate: Greatsword")
	assert_eq(e.objects.tooltip(crate.cells[0])["title"], "The crate")
	TestCombat.next_d20(e, 19)
	var r := cat.perform(ilse, (lines[0] as Dictionary)["action"] as Dictionary)
	assert_true(r.ok and crate.destroyed, r.reason)
	assert_true(e.objects.tooltip(crate.cells[0]).is_empty(), "nothing stands there now")


func test_a_chosen_attack_aims_at_the_object_on_a_clicked_square() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	TestCombat.foe(e, "wolf", Vector2i(11, 7))
	var barrel := _place(e, "barrel", [Vector2i(3, 3)])
	TestCombat.start_with(e, ilse)
	var cat := ActionCatalog.new(e)
	var aimed := e.objects.redirect(ilse, cat.find(ilse, "attack:weapon:greatsword"), Vector2i(3, 3))
	assert_true(bool(aimed["legal"]), str(aimed))
	TestCombat.next_d20(e, 19)
	assert_true(cat.perform(ilse, aimed).hit)
	assert_true(barrel.hp < 18)
	assert_true(e.objects.redirect(ilse, cat.find(ilse, "attack:weapon:greatsword"), Vector2i(8, 6)).is_empty(), "an empty square: nothing")


func test_fire_bolt_sets_a_table_alight_and_it_burns_each_round() -> void:
	var e := TestCombat.open_field()
	e.ambient_light = "dark"
	var c := TestCombat.caster_with(e, ["fire_bolt"], Vector2i(2, 3), 3)
	TestCombat.foe(e, "wolf", Vector2i(11, 7))
	var table := _place(e, "table", [Vector2i(6, 3)])
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 19)
	var r := e.spells.cast(c, "fire_bolt", 0, [], Vector2.INF, Vector2.ZERO, {"object": table.id})
	assert_true(r.ok and r.hit, r.reason)
	assert_true(table.hp < 18 and not table.destroyed, "1d10 Fire against 18 Hit Points")
	assert_true(table.burning, "a flammable object Fire Bolt hits catches fire")
	assert_eq(e.light_at(Vector2i(7, 3)), "bright", "the flames light the room round it")
	assert_eq(e.light_at(Vector2i(9, 3)), "dim")
	assert_eq(e.light_at(Vector2i(11, 3)), "dark")
	var hp := table.hp
	e.objects.round_started()
	assert_true(table.hp < hp, "the Burning condition: 1d4 Fire as each round begins")


func test_fireball_reaches_the_objects_in_its_area() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.high_caster(e, ["fireball"], Vector2i(0, 0))
	TestCombat.foe(e, "wolf", Vector2i(11, 0))
	var crate := _place(e, "crate", [Vector2i(6, 4)])
	var stone := _place(e, "gravestone", [Vector2i(7, 4)])
	var table := _place(e, "table", [Vector2i(5, 4)])
	TestCombat.start_with(e, c)
	var r := e.spells.cast(c, "fireball", 3, [], Vector2(6.5, 4.5))
	assert_true(r.ok, r.reason)
	assert_true(crate.destroyed, "8d6 Fire, no save for an object")
	assert_true(stone.hp < 18, "stone takes it too")
	assert_true(table.destroyed or table.burning, "a flammable object in the area catches fire")


func test_oil_thrown_at_a_creature_adds_five_fire() -> void:
	var e := TestCombat.open_field()
	var t := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(2, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(5, 3), 80)
	(t.creature as Character).add_item("oil", 2)
	var flasks := e.objects.count(t, "oil")
	TestCombat.start_with(e, t)
	var throw := ActionCatalog.new(e).find(t, "oil:throw")
	assert_true(bool(throw["legal"]) and str(throw["cost"]) == "action", str(throw))
	TestCombat.next_d20(e, 2)
	var r := e.objects.throw_oil(t, bag, null)
	assert_true(r.ok and r.hit, r.reason)
	assert_eq(e.objects.count(t, "oil"), flasks - 1, "a flask used")
	assert_true(bag.creature.effects.any(func(fx: Effect) -> bool: return bool(fx.data.get("oiled", false))), "covered in oil")
	e.deal_damage(null, bag, [{"amount": 1, "type": "fire"}], false, "a spark")
	assert_eq(bag.creature.hp, 74, "1 Fire, and 5 more from the burning oil")
	assert_false(bag.creature.effects.any(func(fx: Effect) -> bool: return bool(fx.data.get("oiled", false))), "the oil burns away")
	e.deal_damage(null, bag, [{"amount": 1, "type": "fire"}], false, "a spark")
	assert_eq(bag.creature.hp, 73)


func test_oil_poured_on_the_floor_burns_once_lit() -> void:
	var e := TestCombat.open_field()
	var t := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(2, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(5, 3), 80)
	var ch := t.creature as Character
	ch.add_item("oil", 1)
	ch.add_item("tinderbox")
	TestCombat.start_with(e, t)
	assert_eq(e.objects.pour_why(t, Vector2i(5, 5)), "Within 5 ft")
	assert_true(e.objects.pour_oil(t, Vector2i(3, 3)).ok)
	assert_false(t.action_available, "the Utilize action")
	assert_false(bool(e.objects.square_at(Vector2i(3, 3))["lit"]), "it doesn't burn until lit")
	var light := ActionCatalog.new(e).find(t, "oil:light")
	assert_true(bool(light["legal"]) and str(light["cost"]) == "bonus", str(light))
	assert_true(e.objects.light_oil(t, Vector2i(3, 3)).ok)
	assert_false(t.bonus_available, "a Tinderbox: a Bonus Action")
	e.end_turn()
	assert_eq(e.current(), bag)
	assert_true(e.move(bag, Vector2i(3, 3)).ok)
	assert_eq(bag.creature.hp, 75, "5 Fire entering it")
	e.end_turn()
	assert_eq(bag.creature.hp, 75, "once a turn")
	e.end_turn()
	e.end_turn()
	assert_eq(bag.creature.hp, 70, "ending its next turn there")
	assert_false(e.objects.square_at(Vector2i(3, 3)).is_empty(), "still burning")
	e.end_turn()
	assert_true(e.objects.square_at(Vector2i(3, 3)).is_empty(), "out at the end of the turn 2 rounds after it was lit")


func test_fire_burns_away_the_web_spell() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["web"], Vector2i(1, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(6, 3), 80)
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 2)
	assert_true(e.spells.cast(c, "web", 2, [], Vector2(6.5, 3.5)).ok)
	assert_true(bag.creature.has_condition(&"restrained"), "caught in the web")
	var web := e.spells.zones.object_of(c.id, "web")
	assert_true(Vector2i(6, 3) in web.cells)
	e.deal_damage(c, bag, [{"amount": 1, "type": "fire"}], false, "a torch")
	assert_false(Vector2i(6, 3) in web.cells, "the web on its square burns away")
	assert_false(bag.creature.has_condition(&"restrained"), "and holds it no longer")
	var fire := e.objects.square_at(Vector2i(6, 3))
	assert_true(bool(fire.get("lit", false)) and bool(fire.get("web", false)))
	var hp := bag.creature.hp
	e.end_turn()
	assert_eq(e.current(), bag)
	assert_true(bag.creature.hp < hp, "2d4 Fire to a creature starting its turn in the fire")


func test_the_giant_spiders_web_holds_until_it_is_destroyed() -> void:
	var e := TestCombat.open_field()
	var sp := TestCombat.foe(e, "giant_spider", Vector2i(8, 3))
	var h := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.start_with(e, sp)
	e.monster_actions.apply_riders(sp, h, (sp.creature as Monster).action("web")["on_fail"] as Array, {}, "Web")
	assert_true(h.creature.has_condition(&"restrained"))
	var web := e.objects.objects_at(h.cell)[0]
	assert_eq([web.ac, web.hp], [10, 5], "AC 10, 5 Hit Points")
	assert_eq(e.objects.damage(web, [{"amount": 9, "type": "bludgeoning"}], h, "a kick"), 0, "Immunity to Bludgeoning")
	assert_eq(e.objects.attack_why(h, web, e.option_by_id(h, "weapon:greatsword")), "", "the held creature can hack at it")
	e.objects.damage(web, [{"amount": 5, "type": "slashing"}], h, "a greatsword")
	assert_true(web.destroyed)
	assert_false(h.creature.has_condition(&"restrained"), "broken, the web lets go")


func test_a_chandelier_drops_on_whoever_is_below() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(6, 3), 80)
	var chandelier := _place(e, "chandelier", [Vector2i(6, 3), Vector2i(7, 3)])
	TestCombat.start_with(e, ilse)
	assert_true(e.objects.attack_why(ilse, chandelier, e.option_by_id(ilse, "weapon:greatsword")).contains("out of reach"), "a blade can't reach its chain")
	(ilse.creature as Character).equip("javelin", "main_hand")   # only a weapon in hand is thrown
	assert_eq(e.objects.attack_why(ilse, chandelier, e.option_by_id(ilse, "thrown:javelin")), "", "a thrown javelin can")
	bag.creature.add_condition(&"stunned", "test")   # fails Dexterity saves
	e.objects.damage(chandelier, [{"amount": 5, "type": "piercing"}], ilse, "a javelin")
	assert_true(chandelier.destroyed, "the chain breaks")
	assert_true(bag.creature.hp < 80, "it crashes down on the creature below")
	assert_true(bag.creature.has_condition(&"prone"))
	assert_true(e.grid.has_flag(Vector2i(7, 3), CombatGrid.DIFFICULT), "wreckage")


func test_adamantine_crits_objects_and_sharpness_maximizes_its_dice() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	TestCombat.foe(e, "wolf", Vector2i(11, 7))
	var ch := ilse.creature as Character
	ch.add_item("adamantine_weapon__greatsword")
	ch.add_item("sword_of_sharpness__longsword")
	ch.attuned.append("sword_of_sharpness__longsword")
	# Only equipped weapons attack: the greatsword in hand, the Sword of Sharpness in the other set.
	ch.equip("adamantine_weapon__greatsword", "main_hand")
	ch.weapon_set_2 = {"main_hand": "sword_of_sharpness__longsword"}
	var barrel := _place(e, "barrel", [Vector2i(3, 3)])
	var cart := _place(e, "cart", [Vector2i(3, 2)])
	TestCombat.start_with(e, ilse)
	TestCombat.next_d20(e, 15)
	var r := e.objects.attack(ilse, barrel.id, "weapon:adamantine_weapon__greatsword")
	assert_true(r.hit and r.critical, "an Adamantine weapon's hit on an object is a Critical Hit")
	var p := e.option_by_id(ilse, "weapon:sword_of_sharpness__longsword")["profile"] as WeaponProfile
	var dice := DiceRoller.parse_expr(p.damage_dice)
	ilse.action_available = true   # a second Attack action, for the test
	TestCombat.next_d20(e, 15)
	var r2 := e.objects.attack(ilse, cart.id, "weapon:sword_of_sharpness__longsword")
	assert_true(r2.hit, r2.reason)
	assert_eq(r2.damage, int(dice["count"]) * int(dice["sides"]) + int(dice["modifier"]) + p.damage_bonus.total(), "every weapon die at its maximum")


func test_a_saved_fight_keeps_its_objects_and_fires() -> void:
	var e := TestCombat.open_field()
	var t := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(2, 3))
	TestCombat.foe(e, "wolf", Vector2i(11, 7))
	var crate := _place(e, "crate", [Vector2i(3, 3)])
	var table := _place(e, "table", [Vector2i(4, 5)])
	var door := _place(e, "door_iron", [Vector2i(6, 6)])
	(t.creature as Character).add_item("oil", 1)
	e.objects.placed = true
	TestCombat.start_with(e, t)
	e.objects.damage(crate, [{"amount": 9, "type": "bludgeoning"}], t, "test")
	e.objects.ignite(table)
	assert_true(e.objects.pour_oil(t, Vector2i(2, 4)).ok)
	var back := JSON.parse_string(JSON.stringify(EncounterSnapshot.capture(e))) as Dictionary
	var e2 := EncounterSnapshot.restore(back, DiceRoller.new(1))
	assert_eq(e2.objects.list.size(), 3)
	assert_true(e2.objects.get_object(crate.id).destroyed)
	assert_true(e2.grid.has_flag(Vector2i(3, 3), CombatGrid.DIFFICULT) and not e2.grid.has_flag(Vector2i(3, 3), CombatGrid.LOW), "its rubble")
	assert_true(e2.objects.get_object(table.id).burning)
	assert_true(e2.grid.has_flag(Vector2i(6, 6), CombatGrid.WALL), "the door still stands")
	assert_eq(e2.objects.get_object(door.id).hp, 18)
	assert_false(e2.objects.square_at(Vector2i(2, 4)).is_empty(), "the oil on the floor")
	assert_true(e2.objects.placed, "not placed again")


func test_scenery_comes_from_the_board_and_the_view_shows_it_break() -> void:
	var e := TestCombat.encounter(["........", ".==.....", "........", ".....=..", "........"], 4)
	var board := ArenaBoard.build(e.grid)
	add_child(board)
	BattleScenery.from_board(e, board)
	var run := e.objects.blocking_at(Vector2i(1, 1))
	var lone := e.objects.blocking_at(Vector2i(5, 3))
	assert_true(run != null and lone != null)
	assert_eq(run.kind, "low_wall", "a run of '=' in the shrine yard: a low wall")
	assert_eq(lone.kind, "gravestone", "a lone one: a gravestone")
	BattleScenery.from_board(e, board)
	assert_eq(e.objects.list.size(), 3, "placed once")
	var view := ObjectView.create(board)
	add_child(view)
	view.sync(e.objects)
	e.objects.damage(lone, [{"amount": 50, "type": "bludgeoning"}], null, "test")
	view.sync(e.objects)
	for n: Variant in board.dressing.get(Vector2i(5, 3), []):
		assert_false((n as Node3D).visible, "what stood there is gone")
	var wreck := board.get_children().filter(func(n: Node) -> bool: return str(n.name).contains("Wreckage"))
	assert_true(wreck.size() >= 6, "and its wreckage lies there")
	var chandelier := _place(e, "chandelier", [Vector2i(3, 2)])
	view.sync(e.objects)
	var hung := view.get_children().filter(func(n: Node) -> bool: return n is Node3D and (n as Node3D).position.y > 2.0)
	assert_eq(hung.size(), 1, "a chandelier hangs up there")
	e.objects.damage(chandelier, [{"amount": 5, "type": "piercing"}], null, "test")
	view.sync(e.objects)
	assert_true(((hung[0] as Node3D).position.y) < 1.0, "and lies on the floor once its chain breaks")
	view.queue_free()
	board.queue_free()


func test_doors_and_art_name_their_kinds() -> void:
	var table := EncounterObjects.kinds()
	assert_eq(BattleScenery.door_kind({"id": "crypt_3", "label": "an iron crypt gate"}, table), "door_iron")
	assert_eq(BattleScenery.door_kind({"id": "dh_den_door", "label": "the den door"}, table), "door_wood")
	assert_eq(BattleScenery.kind_for_art("book_shelf_front", table), "shelves", "a front view is its piece")
	assert_eq(BattleScenery.kind_for_art("barrel", table), "barrel")
	assert_eq(BattleScenery.kind_for_art("amber_sarcophagus", table), "", "art no kind names stays whole")
	for theme: String in ["shrine_yard", "manor", "church", "village", "forest", "dungeon"]:
		var k := str((table["themes"] as Dictionary).get(theme, ""))
		assert_true((table["kinds"] as Dictionary).has(k), "%s's '=' squares: %s" % [theme, k])


## Every piece a board stands on a '=' square (catalog "low_cover" and the rooms' own "low_cover_rooms") names an
## object kind, so a fight can shove it, wreck it or hide behind it whatever the room dresses it as.
func test_every_low_cover_piece_is_a_fight_object() -> void:
	var table := EncounterObjects.kinds()
	var cat := SetDressing.catalog()
	var arts: Array[String] = []
	for list: Variant in (cat["low_cover"] as Dictionary).values():
		for a: Variant in list:
			arts.append(str(a))
	for rule: Variant in cat.get("low_cover_rooms", []):
		for list: Variant in ((rule as Array)[1] as Dictionary).values():
			for a: Variant in list:
				arts.append(str(a))
	assert_true(arts.size() > 20)
	for a in arts:
		assert_ne(BattleScenery.kind_for_art(a, table), "", "a '=' square's %s is something a fight can use" % a)
	# And the pieces the interiors stand on '=' squares by name (a guest room's washstand, Eva's reading table).
	for a: String in ["washstand", "reading_table", "rope_coils", "chest_iron", "festival_cloth", "coffin_lid", "toy_shelf",
			"shelf_goods", "oil_shelf", "bench", "stewpot", "cookpot"]:
		assert_ne(BattleScenery.kind_for_art(a, table), "", "%s is something a fight can use" % a)
