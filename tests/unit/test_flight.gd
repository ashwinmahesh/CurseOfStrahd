extends TestCase
## Flying with a real height off the floor (F4 part 2, 2024 PHB): rising and sinking, out of melee reach, Opportunity
## Attacks for flying out of reach, passing over creatures and low cover, the ceiling, coming down when knocked Prone
## (unless it hovers), Fly's hovering, Levitate's lift and gentle descent, areas that reach only so high, and a carried
## creature let go of in the air (combat/encounter_movement.gd, combat/grid.gd, combat/spell_targeting.gd).


func _flyer(e: Encounter, cell: Vector2i, fly: int = 60) -> Combatant:
	var c := TestCombat.hero(e, "ilse_varga", cell, 5)
	var fx := Effect.new("Wings", &"spell", "test_wings").with_modifier("speed_set", {"kind": "fly", "value": fly})
	c.creature.add_effect(fx)
	c.movement_left = c.speed()
	return c


func _melee(e: Encounter, c: Combatant) -> Dictionary:
	for o in e.attack_options(c):
		if bool(o["melee"]):
			return o
	return {}


func test_a_flyer_rises_out_of_melee_reach_and_comes_back_down() -> void:
	var e := TestCombat.open_field(3)
	var c := _flyer(e, Vector2i(2, 2))
	var foe := TestCombat.foe(e, "zombie", Vector2i(6, 2))
	TestCombat.start_with(e, c)
	var left := c.movement_left
	var r := e.fly_vertical(c, 10)
	assert_true(r.ok, r.reason)
	assert_eq(c.altitude, 10)
	assert_eq(c.movement_left, left - 10, "1 ft of movement per foot")
	foe.cell = Vector2i(3, 2)
	assert_eq(e.distance(foe, c), 10, "10 ft up is 10 ft away")
	assert_true(e.attack_legal(foe, c, _melee(e, foe)).begins_with("Out of reach"), "a zombie can't reach it")
	assert_true(e.fly_vertical(c, -10).ok)
	assert_eq(c.altitude, 0)
	assert_eq(e.attack_legal(foe, c, _melee(e, foe)), "", "back on the floor, in reach")


func test_flying_up_out_of_reach_provokes() -> void:
	var e := TestCombat.open_field(3)
	var c := _flyer(e, Vector2i(2, 2))
	var foe := TestCombat.foe(e, "zombie", Vector2i(3, 2))
	foe.creature.hp = 100
	TestCombat.start_with(e, c)
	var hp := c.creature.hp
	TestCombat.next_d20(e, 18)
	var r := e.fly_vertical(c, 10)
	assert_true(r.ok, r.reason)
	assert_false(foe.reaction_available, "the zombie used its Reaction on the way up")
	assert_true(c.creature.hp < hp or e.log.entries.any(func(x: Dictionary) -> bool: return str(x["text"]).contains("Opportunity")), "an Opportunity Attack")


func test_aloft_it_passes_over_creatures_and_low_walls() -> void:
	var e := TestCombat.encounter(["......", ".===..", "......"], 3)
	var c := _flyer(e, Vector2i(0, 1))
	var ally := TestCombat.hero(e, "hedda_ironvow", Vector2i(5, 1))
	TestCombat.start_with(e, c)
	assert_false(e.reachable_for(c).has(Vector2i(2, 1)), "on the floor a low wall is in the way")
	assert_true(e.fly_vertical(c, 5).ok)
	assert_true(e.reachable_for(c).has(Vector2i(2, 1)), "5 ft up it flies over the wall")
	var r := e.move(c, Vector2i(5, 1))
	assert_true(r.ok, r.reason)
	assert_eq(c.cell, ally.cell, "and ends over Hedda's head")
	assert_false(EncounterMovement.overlaps_height(c, ally))


func test_the_ceiling_stops_it() -> void:
	var e := TestCombat.open_field(3)
	e.grid.ceiling_ft = 20
	var c := _flyer(e, Vector2i(2, 2))
	TestCombat.start_with(e, c)
	assert_true(e.fly_vertical(c, 30).ok)
	assert_eq(c.altitude, 15, "a Medium creature fits under a 20 ft ceiling 15 ft up")
	assert_eq(e.movement.vertical_why(c, 5), "The ceiling is in the way")


func test_knocked_prone_in_the_air_it_falls_unless_it_hovers() -> void:
	var e := TestCombat.open_field(3)
	var c := _flyer(e, Vector2i(2, 2))
	TestCombat.start_with(e, c)
	assert_true(e.fly_vertical(c, 20).ok)
	var hp := c.creature.hp
	c.creature.add_condition(&"prone", "test")
	e.movement.settle_all()
	assert_eq(c.altitude, 0, "down it comes")
	assert_true(c.creature.hp < hp, "2d6 for 20 ft")
	var e2 := TestCombat.open_field(3)
	var ghost := TestCombat.foe(e2, "wraith", Vector2i(2, 2))
	ghost.altitude = 10
	ghost.creature.add_condition(&"prone", "test")
	e2.movement.settle_all()
	assert_eq(ghost.altitude, 10, "a wraith hovers")


func test_the_fly_spell_hovers() -> void:
	var e := TestCombat.open_field(3)
	var c := TestCombat.caster_with(e, ["fly"], Vector2i(2, 2))
	TestCombat.start_with(e, c)
	var r := e.spells.cast(c, "fly", 3, [c])
	assert_true(r.ok, r.reason)
	assert_true(e.movement.can_fly(c))
	c.movement_left = c.speed()
	assert_true(e.fly_vertical(c, 15).ok)
	c.creature.add_condition(&"prone", "test")
	e.movement.settle_all()
	assert_eq(c.altitude, 15, "Fly lets it hover")


func test_levitate_lifts_its_target_and_lets_it_down_gently() -> void:
	var e := TestCombat.open_field(3)
	var c := TestCombat.caster_with(e, ["levitate"], Vector2i(2, 2))
	var foe := TestCombat.punching_bag(e, Vector2i(5, 2), 100)
	TestCombat.start_with(e, c)
	var r := e.spells.cast(c, "levitate", 2, [foe])
	assert_true(r.ok, r.reason)
	assert_eq(foe.altitude, 20, "20 ft up")
	var hp := foe.creature.hp
	c.creature.concentration.end("test")
	e.movement.settle_all()
	assert_eq(foe.altitude, 0)
	assert_eq(foe.creature.hp, hp, "floats down unhurt")
	assert_false(foe.creature.has_condition(&"prone"))


func test_an_area_on_the_ground_reaches_only_so_high() -> void:
	var e := TestCombat.open_field(3)
	var c := TestCombat.caster_with(e, ["fireball"], Vector2i(0, 0))
	var low := TestCombat.punching_bag(e, Vector2i(6, 4), 300)
	var high := TestCombat.punching_bag(e, Vector2i(7, 4), 300)
	high.altitude = 30
	TestCombat.start_with(e, c)
	var s := Compendium.shared().spell_data("fireball")
	assert_true(e.spells.targeting.reaches_height(c, s, low))
	assert_false(e.spells.targeting.reaches_height(c, s, high), "30 ft up is out of a 20 ft sphere on the ground")
	var hp := high.creature.hp
	var hp_low := low.creature.hp
	var r := e.spells.cast(c, "fireball", 3, [], Vector2(7.0, 5.0))
	assert_true(r.ok, r.reason)
	assert_eq(high.creature.hp, hp, "untouched")
	assert_true(low.creature.hp < hp_low, "the one on the ground burns")


func test_let_go_in_the_air_a_carried_creature_falls() -> void:
	var e := TestCombat.open_field(3)
	var c := _flyer(e, Vector2i(2, 2))
	var bag := TestCombat.punching_bag(e, Vector2i(3, 2), 200)
	TestCombat.start_with(e, c)
	e.grapples[bag.id] = c.id
	bag.creature.add_condition(&"grappled", c.name())
	assert_true(e.fly_vertical(c, 20).ok)
	assert_eq(bag.altitude, 20, "carried up")
	var hp := bag.creature.hp
	assert_true(e.release_grapple(c, bag).ok)
	e.movement.settle_all()
	assert_eq(bag.altitude, 0)
	assert_true(bag.creature.hp < hp, "dropped 20 ft")


func test_altitude_survives_a_saved_fight() -> void:
	var e := TestCombat.open_field(3)
	e.grid.ceiling_ft = 25
	var c := _flyer(e, Vector2i(2, 2))
	TestCombat.start_with(e, c)
	c.altitude = 10
	var back := EncounterSnapshot.restore(EncounterSnapshot.capture(e), DiceRoller.new(3))
	assert_eq(back.get_c(c.id).altitude, 10)
	assert_eq(back.grid.ceiling_ft, 25)


func test_held_to_speed_0_a_flyer_falls() -> void:
	var e := TestCombat.open_field(3)
	var c := _flyer(e, Vector2i(2, 2))
	TestCombat.start_with(e, c)
	assert_true(e.fly_vertical(c, 20).ok)
	c.creature.add_condition(&"restrained", "test")
	assert_eq(c.creature.speed("fly").total(), 0, "Speed 0 stops flying too")
	e.movement.settle_all()
	assert_eq(c.altitude, 0, "down it comes")


func test_it_cant_fly_down_onto_someones_head_and_lands_beside_them() -> void:
	var e := TestCombat.open_field(3)
	var c := _flyer(e, Vector2i(2, 2))
	var ally := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 2))
	TestCombat.start_with(e, c)
	assert_true(e.fly_vertical(c, 10).ok)
	assert_true(e.move(c, Vector2i(3, 2)).ok, "over Hedda's head")
	assert_eq(e.movement.vertical_why(c, -5), "")
	assert_true(e.fly_vertical(c, -10).ok)
	assert_eq(c.altitude, 5, "it stops just over her")
	assert_eq(e.movement.vertical_why(c, -5), "%s is in the way" % ally.name())
	assert_true(e.fly_vertical(c, 10).ok)
	c.creature.add_condition(&"prone", "test")
	e.movement.settle_all()
	assert_eq(c.altitude, 0)
	assert_ne(c.cell, ally.cell, "it lands beside her, not on her")


func test_a_body_drops_to_the_floor() -> void:
	var e := TestCombat.open_field(3)
	var bat := TestCombat.foe(e, "wraith", Vector2i(4, 2))
	bat.altitude = 20
	bat.creature.dead = true
	e.movement.settle_all()
	assert_eq(bat.altitude, 0)


func test_gaseous_form_still_flies() -> void:
	var e := TestCombat.open_field(3)
	var c := TestCombat.caster_with(e, ["gaseous_form"], Vector2i(2, 2))
	TestCombat.start_with(e, c)
	var r := e.spells.cast(c, "gaseous_form", 3, [c])
	assert_true(r.ok, r.reason)
	assert_eq(c.creature.speed().total(), 0, "no walking")
	assert_eq(c.creature.speed("fly").total(), 10, "a Fly Speed of 10 ft")


func test_the_ai_doesnt_plan_a_swing_at_a_flyer_out_of_reach() -> void:
	var e := TestCombat.open_field(3)
	var c := _flyer(e, Vector2i(2, 2))
	var zombie := TestCombat.foe(e, "zombie", Vector2i(3, 2))
	TestCombat.start_with(e, c)
	c.altitude = 15
	zombie.movement_left = zombie.speed()
	assert_ne(str(e.ai.plan_turn(zombie)["kind"]), "attack", "nothing it can reach")
	var ally := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3))
	assert_eq(e.ai.plan_turn(zombie).get("target"), ally, "it goes for the one on the floor")


func test_flying_up_can_be_taken_back() -> void:
	var e := TestCombat.open_field(3)
	var c := _flyer(e, Vector2i(2, 2))
	TestCombat.start_with(e, c)
	var left := c.movement_left
	assert_true(e.fly_vertical(c, 10).ok)
	assert_true(e.can_undo_move(c))
	var mark := e.events.size()
	assert_true(e.undo_move(c).ok)
	assert_eq(c.altitude, 0)
	assert_eq(c.movement_left, left)
	assert_true(e.events.slice(mark).any(func(ev: Dictionary) -> bool: return str(ev["type"]) == "altitude"), "the token comes back down")
