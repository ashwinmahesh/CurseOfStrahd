extends TestCase
## Height on the ground (F4, 2024 PHB): climbing costs 1 extra foot per foot (up or down), a creature pushed off a
## ledge falls (1d6 per 10 ft, Prone), one pushed into a map's open drop falls out of the fight, a creature that can fly
## or cling stops at the edge, Feather Fall and Slow Fall soften a fall, and a grappler drags what it holds (combat/grid.gd,
## combat/encounter_movement.gd, combat/encounter_grapples.gd).


func _none(_c: Vector2i) -> bool:
	return false


func test_climbing_costs_one_extra_foot_per_foot_up_or_down() -> void:
	var g := CombatGrid.from_rows([".2.1", "~2..", "...."])
	assert_eq(g.step_cost(Vector2i(0, 0), Vector2i(1, 0), 1, _none, _none), 25, "10 ft up: 5 ft across and 10 ft climbed at double")
	assert_eq(g.step_cost(Vector2i(1, 0), Vector2i(0, 0), 1, _none, _none), 25, "climbing 10 ft down costs the same")
	assert_eq(g.step_cost(Vector2i(2, 0), Vector2i(3, 0), 1, _none, _none), 5, "a 5 ft step is stairs")
	assert_eq(g.step_cost(Vector2i(0, 0), Vector2i(1, 0), 1, _none, _none, CombatGrid.MOVE_CLIMB), 15, "a Climb Speed pays nothing extra")
	assert_eq(g.step_cost(Vector2i(1, 1), Vector2i(0, 1), 1, _none, _none), 40, "climbing down into Difficult Terrain: 2 extra feet per foot")
	assert_eq(g.step_cost(Vector2i(0, 0), Vector2i(1, 0), 1, _none, _none, CombatGrid.MOVE_FLY), 5, "a flyer goes over")
	var deep := CombatGrid.from_rows(["4.."])
	assert_eq(deep.step_cost(Vector2i(0, 0), Vector2i(1, 0), 1, _none, _none), 45, "a 20 ft drop is climbed down, not refused")


func test_pushed_off_a_ledge_a_creature_falls_and_lands_prone() -> void:
	var e := TestCombat.encounter(["22.", "22.", "22."], 3)
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(0, 1))
	var bag := TestCombat.punching_bag(e, Vector2i(1, 1), 200)
	TestCombat.start_with(e, hero)
	var hp := bag.creature.hp
	assert_eq(e.forced_move(bag, e.center_of(hero), 5), 1)
	assert_eq(bag.cell, Vector2i(2, 1), "over the edge")
	assert_true(bag.creature.hp < hp and hp - bag.creature.hp <= 6, "1d6 for 10 ft")
	assert_true(bag.creature.has_condition(&"prone"), "lands Prone")


func test_a_push_into_a_cliff_face_stops() -> void:
	var e := TestCombat.encounter(["..2", "..2", "..2"], 3)
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(0, 1))
	var bag := TestCombat.punching_bag(e, Vector2i(1, 1), 200)
	TestCombat.start_with(e, hero)
	assert_eq(e.forced_move(bag, e.center_of(hero), 10), 0, "10 ft of rock above stops it like a wall")
	var step := TestCombat.encounter(["..1", "..1", "..1"], 3)
	var hero2 := TestCombat.hero(step, "ilse_varga", Vector2i(0, 1))
	var bag2 := TestCombat.punching_bag(step, Vector2i(1, 1), 200)
	TestCombat.start_with(step, hero2)
	assert_eq(step.forced_move(bag2, step.center_of(hero2), 5), 1, "up a 5 ft step it goes")


func _chasm() -> Encounter:
	var e := TestCombat.encounter(["......", "......", "      ", "      "], 5)
	e.grid.drop_ft = 200
	return e


func test_pushed_into_the_maps_drop_a_foe_falls_out_of_the_fight() -> void:
	var e := _chasm()
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(2, 0))
	var bag := TestCombat.punching_bag(e, Vector2i(2, 1), 500)
	TestCombat.start_with(e, hero)
	var hp := bag.creature.hp
	assert_eq(e.forced_move(bag, e.center_of(hero), 10), 1)
	assert_true(bag.has_meta("left_fight"), "out of the fight")
	assert_eq(bag.cell, SpellSpecials.BANISHED_CELL, "off the grid")
	assert_false(bag in e.order, "no more turns")
	assert_true(hp - bag.creature.hp >= 20, "20d6 for a 200 ft fall")
	assert_eq(e.outcome, "victory", "the last foe gone ends the fight")


func test_a_party_member_who_falls_away_no_longer_counts_and_stays_alive() -> void:
	var e := _chasm()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 1), 11)
	var hedda := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 0))
	var foe := TestCombat.foe(e, "zombie", Vector2i(2, 0))
	TestCombat.start_with(e, foe)
	ilse.creature.hp = 500
	e.forced_move(ilse, e.center_of(foe), 5)
	assert_true(ilse.has_meta("left_fight"))
	assert_false(ilse.creature.dead, "it lived through the fall")
	hedda.creature.hp = 0
	e._check_over()
	assert_eq(e.outcome, "defeat", "nobody is left up on the grid")


func test_a_creature_that_can_cling_or_fly_stops_at_the_edge() -> void:
	var e := _chasm()
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(2, 0))
	var spawn := TestCombat.foe(e, "vampire_spawn", Vector2i(2, 1))
	TestCombat.start_with(e, hero)
	assert_true(e.movement.catches_itself(spawn), "Spider Climb")
	assert_eq(e.forced_move(spawn, e.center_of(hero), 10), 0, "it clings to the edge")
	assert_false(spawn.has_meta("left_fight"))


func test_feather_fall_lands_it_unharmed_on_its_feet() -> void:
	var e := TestCombat.encounter(["4.", "4.", "4."], 2)
	var wizard := TestCombat.caster_with(e, ["feather_fall"], Vector2i(0, 0))
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(0, 2), 5)
	TestCombat.start_with(e, ilse)
	var slots := (wizard.creature as Character).slots_left(1)
	var hp := ilse.creature.hp
	assert_eq(e.fall(ilse, 20), 0)
	assert_eq(ilse.creature.hp, hp, "no damage")
	assert_false(ilse.creature.has_condition(&"prone"), "on its feet")
	assert_false(wizard.reaction_available, "the caster's Reaction")
	assert_eq((wizard.creature as Character).slots_left(1), slots - 1, "a level 1 slot")


func test_slow_fall_takes_five_times_the_monk_level_off() -> void:
	var e := TestCombat.open_field(4)
	var wren := TestCombat.hero(e, "wren_featherfoot", Vector2i(2, 2), 5)
	TestCombat.start_with(e, wren)
	var hp := wren.creature.hp
	assert_eq(e.fall(wren, 20), 0, "2d6 is at most 12, Slow Fall takes 25 off")
	assert_eq(wren.creature.hp, hp)
	assert_false(wren.reaction_available, "it used its Reaction")
	assert_false(wren.creature.has_condition(&"prone"), "no harm, no Prone")


func _grappling(bag_size: String = "medium") -> Dictionary:
	var e := TestCombat.open_field(6)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(2, 3), 200)
	bag.creature.size = StringName(bag_size)
	TestCombat.start_with(e, ilse)
	e.grapples[bag.id] = ilse.id
	bag.creature.add_condition(&"grappled", ilse.name())
	return {"e": e, "ilse": ilse, "bag": bag}


func test_a_grappler_drags_what_it_holds_at_double_cost() -> void:
	var g := _grappling()
	var e := g["e"] as Encounter
	var ilse := g["ilse"] as Combatant
	var bag := g["bag"] as Combatant
	assert_eq(e.grappling.drag_extra(ilse), 1, "a Medium creature costs 1 extra foot per foot")
	var reach := e.reachable_for(ilse)
	assert_true(reach.has(Vector2i(6, 3)) and not reach.has(Vector2i(7, 3)), "30 ft of Speed drags it 15 ft")
	var preview := ActionCatalog.new(e).move_preview(ilse, Vector2i(6, 3))
	assert_eq(int(preview["cost"]), 30, "the preview counts the drag")
	var r := e.move(ilse, Vector2i(6, 3))
	assert_true(r.ok, r.reason)
	assert_eq(ilse.movement_left, 0, "15 ft cost 30")
	assert_eq(bag.cell, Vector2i(5, 3), "pulled along into the square behind")
	assert_eq(str(e.grapples.get(bag.id, "")), ilse.id, "still held")


func test_a_tiny_creature_comes_along_for_free() -> void:
	var g := _grappling("tiny")
	var e := g["e"] as Encounter
	var ilse := g["ilse"] as Combatant
	assert_eq(e.grappling.drag_extra(ilse), 0)
	assert_true(e.reachable_for(ilse).has(Vector2i(9, 3)), "the full 30 ft")


func test_the_dragged_creature_draws_no_opportunity_attack() -> void:
	var g := _grappling()
	var e := g["e"] as Encounter
	var ilse := g["ilse"] as Combatant
	var bag := g["bag"] as Combatant
	var hedda := TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 3))
	hedda.reaction_rules["opportunity_attack"] = "auto"
	var hp := bag.creature.hp
	var r := e.move(ilse, Vector2i(5, 3))
	assert_true(r.ok and e.pending == null, "no prompt")
	assert_eq(bag.creature.hp, hp, "Hedda didn't swing at it: it didn't move on its own")
	assert_true(hedda.reaction_available)


func test_letting_go_and_being_pushed_apart_end_the_grapple() -> void:
	var g := _grappling()
	var e := g["e"] as Encounter
	var ilse := g["ilse"] as Combatant
	var bag := g["bag"] as Combatant
	var cat := ActionCatalog.new(e)
	var let_go := cat.find(ilse, "let_go:" + bag.id)
	assert_false(let_go.is_empty(), "a Let go entry on the hotbar")
	assert_true(cat.perform(ilse, let_go, []).ok)
	assert_false(e.grapples.has(bag.id))
	assert_false(bag.creature.has_condition(&"grappled"))
	var g2 := _grappling()
	var e2 := g2["e"] as Encounter
	var ilse2 := g2["ilse"] as Combatant
	var bag2 := g2["bag"] as Combatant
	e2.forced_move(bag2, e2.center_of(ilse2), 10)
	assert_false(e2.grapples.has(bag2.id), "pushed 10 ft away, out of the grapple's reach")


func test_the_drop_and_deep_water_survive_a_saved_fight() -> void:
	var e := TestCombat.encounter(["..w..", ".....", "     "], 7)
	e.grid.drop_ft = 200
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(0, 0))
	TestCombat.start_with(e, hero)
	var back := EncounterSnapshot.restore(EncounterSnapshot.capture(e), DiceRoller.new(7))
	assert_eq(back.grid.drop_ft, 200)
	assert_true(back.grid.has_flag(Vector2i(2, 0), CombatGrid.WATER), "deep water stays water")
	assert_eq(back.grid.drop_at(Vector2i(1, 2)), 200)
	assert_eq(back.grid.drop_at(Vector2i(2, 0)), 0, "water isn't a drop")
