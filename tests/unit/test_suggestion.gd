extends TestCase
## Suggestion's four suggestions in a fight (Ashwin, 2026-10-12: game-ready ones, like Command's words): "Stand aside"
## stops it fighting, "Go home" walks it out of the fight, "Put that down and sit" sits it down, "Come with me" brings
## it to the caster. Hurting it ends the suggestion; a creature with no language can't take one.


func _suggest(e: Encounter, c: Combatant, targets: Array, kind: String, spell: String = "suggestion") -> void:
	TestCombat.next_d20(e, 2)
	var r := e.spells.cast(c, spell, 6 if spell == "mass_suggestion" else 2, targets, Vector2.INF, Vector2.ZERO, {"choice": kind})
	assert_true(r.ok, r.reason)


## A foe that speaks Common and fails every Wisdom save.
func _weak_willed(e: Encounter, cell: Vector2i) -> Combatant:
	return e.add(TestChars.dummy(60, false, {"type": "humanoid", "languages": ["Common"],
		"abilities": {"str": 10, "dex": 10, "con": 10, "int": 10, "wis": 1, "cha": 10}}), &"enemy", cell)


func _bandit_turn(e: Encounter, b: Combatant) -> void:
	e.end_turn()
	assert_eq(e.current().id, b.id)
	e.run_ai_turn()


func test_stand_aside_stops_it_fighting_until_its_hurt() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["suggestion"], Vector2i(2, 3))
	var b := TestCombat.foe(e, "bandit", Vector2i(3, 3))
	TestCombat.start_with(e, c)
	_suggest(e, c, [b], "stand_aside")
	assert_true(b.creature.has_condition(&"charmed"))
	assert_true(b.creature.has_flag("indifferent") and b.creature.has_flag("no_opportunity_attacks"))
	var hp := c.creature.hp
	_bandit_turn(e, b)
	assert_eq(c.creature.hp, hp, "it doesn't fight")
	e.deal_damage(c, b, [{"amount": 1, "type": "force"}], false, "Test")
	assert_false(b.creature.has_flag("indifferent"), "hurt by the caster's side, it's free of it")
	assert_false(b.creature.has_condition(&"charmed"))


func test_go_home_walks_it_out_of_the_fight() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["suggestion"], Vector2i(1, 3))
	var b := TestCombat.foe(e, "bandit", Vector2i(3, 3))
	TestCombat.foe(e, "bandit", Vector2i(10, 7))
	TestCombat.start_with(e, c)
	_suggest(e, c, [b], "go_home")
	assert_true(b.creature.has_flag("suggest_leave"))
	for i in 3:
		if b.has_meta("left_fight"):
			break
		while e.current().id != b.id:
			e.end_turn()
		e.run_ai_turn()
	assert_true(b.has_meta("left_fight"), "gone home")
	assert_eq(c.creature.hp, c.creature.max_hp(), "without a blow")


func test_put_that_down_and_sit() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["suggestion"], Vector2i(2, 3))
	var b := TestCombat.foe(e, "bandit", Vector2i(3, 3))
	TestCombat.start_with(e, c)
	_suggest(e, c, [b], "sit")
	var hp := c.creature.hp
	_bandit_turn(e, b)
	assert_true(b.creature.has_condition(&"prone"), "it sits")
	assert_eq(b.cell, Vector2i(3, 3))
	assert_eq(c.creature.hp, hp)
	_bandit_turn(e, b)
	assert_true(b.creature.has_condition(&"prone"), "and stays sitting")
	assert_eq(c.creature.hp, hp)


func test_come_with_me_brings_it_to_the_caster() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["suggestion"], Vector2i(1, 3))
	var b := TestCombat.foe(e, "bandit", Vector2i(7, 3))
	TestCombat.start_with(e, c)
	_suggest(e, c, [b], "follow")
	var hp := c.creature.hp
	_bandit_turn(e, b)
	assert_true(e.distance(b, c) <= 5, "beside its caster: %d ft" % e.distance(b, c))
	assert_eq(c.creature.hp, hp, "and nothing else")


func test_a_creature_with_no_language_cant_take_one() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["suggestion"], Vector2i(2, 3))
	var w := TestCombat.foe(e, "wolf", Vector2i(3, 3))
	var b := TestCombat.foe(e, "bandit", Vector2i(3, 5))
	TestCombat.start_with(e, c)
	var cat := ActionCatalog.new(e)
	var a := {}
	for x in cat.actions_for(c):
		if str(x.get("spell_id", "")) == "suggestion":
			a = x
	assert_false(a.is_empty())
	assert_eq(cat.target_why(c, a, w), "Wolf can't understand you")
	assert_eq(cat.target_why(c, a, b), "")
	assert_eq(str(((a["choices"] as Array)[0] as Dictionary)["label"]), "\"Stand aside. This isn't your fight.\"")
	_suggest(e, c, [w], "sit")
	assert_false(w.creature.has_condition(&"charmed"))


func test_mass_suggestion_sends_them_all_home() -> void:
	var e := TestCombat.open_field()
	var wiz := TestChars.custom("wizard", "human", 11)
	((wiz.spellcasting[0] as Dictionary)["prepared"] as Array).append("mass_suggestion")
	var c := e.add(wiz, &"party", Vector2i(1, 3))
	var b1 := _weak_willed(e, Vector2i(4, 2))
	var b2 := _weak_willed(e, Vector2i(4, 4))
	TestCombat.start_with(e, c)
	assert_true(wiz.slots_left(6) > 0, "an 11th-level wizard has a 6th-level slot")
	TestCombat.next_d20(e, 2)
	var r := e.spells.cast(c, "mass_suggestion", 6, [b1, b2], Vector2.INF, Vector2.ZERO, {"choice": "go_home"})
	assert_true(r.ok, r.reason)
	assert_true(b1.creature.has_flag("suggest_leave") and b2.creature.has_flag("suggest_leave"), "both go home")
