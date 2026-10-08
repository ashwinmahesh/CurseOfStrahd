extends TestCase
## High ground (owner's house rule, 2026-10-07, from Baldur's Gate 3): a ranged attack from 10 ft or more above its target
## gets +2 to hit, one from 10 ft or more below gets -2; melee attacks and a 5 ft step don't count
## (EncounterSight.height_edge, EncounterAttacks).


func _ranged(e: Encounter, c: Combatant) -> Dictionary:
	for o in e.attack_options(c):
		if not bool(o["melee"]) and str(o["kind"]) == "weapon":
			return o
	return {}


func _melee(e: Encounter, c: Combatant) -> Dictionary:
	for o in e.attack_options(c):
		if bool(o["melee"]):
			return o
	return {}


func test_a_ranged_attack_from_10_ft_above_gets_2_and_from_below_loses_2() -> void:
	var e := TestCombat.encounter(["22.....", "22.....", "22....."], 2)
	var archer := TestCombat.hero(e, "thistle", Vector2i(0, 1))
	var foe := TestCombat.punching_bag(e, Vector2i(5, 1), 200)
	TestCombat.start_with(e, archer)
	var bow := _ranged(e, archer)
	assert_false(bow.is_empty(), "Thistle has a longbow")
	assert_eq(int(e.attack_situation(archer, foe, bow)["height_bonus"]), 2, "from the ledge")
	assert_eq(int(e.attack_situation(foe, archer, bow)["height_bonus"]), -2, "up at the ledge")
	var level := TestCombat.encounter(["11.....", "11.....", "11....."], 2)
	var a2 := TestCombat.hero(level, "thistle", Vector2i(0, 1))
	var f2 := TestCombat.punching_bag(level, Vector2i(5, 1), 200)
	TestCombat.start_with(level, a2)
	assert_eq(int(level.attack_situation(a2, f2, _ranged(level, a2))["height_bonus"]), 0, "a 5 ft step isn't high ground")


func test_melee_gets_nothing_from_height() -> void:
	var e := TestCombat.encounter(["2.", "2."], 2)
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(0, 0))
	var foe := TestCombat.punching_bag(e, Vector2i(1, 0), 200)
	TestCombat.start_with(e, hero)
	assert_eq(int(e.attack_situation(hero, foe, _melee(e, hero))["height_bonus"]), 0)


func test_the_bonus_is_on_the_roll_and_in_the_odds() -> void:
	var e := TestCombat.encounter(["22.....", "22.....", "22....."], 2)
	var archer := TestCombat.hero(e, "thistle", Vector2i(0, 1))
	var foe := TestCombat.punching_bag(e, Vector2i(5, 1), 200)
	TestCombat.start_with(e, archer)
	var bow := _ranged(e, archer)
	var flat := TestCombat.encounter([".......", ".......", "......."], 2)
	var a2 := TestCombat.hero(flat, "thistle", Vector2i(0, 1))
	var f2 := TestCombat.punching_bag(flat, Vector2i(5, 1), 200)
	TestCombat.start_with(flat, a2)
	var high := int(e.hit_chance(archer, foe, bow)["needs"])
	var level := int(flat.hit_chance(a2, f2, _ranged(flat, a2))["needs"])
	assert_true(high == level - 2 or high == 2, "needs 2 less from above (%d vs %d)" % [high, level])
	var before := e.log.entries.size()
	e.attack(archer, foe, str(bow["id"]))
	var found := false
	for i in range(before, e.log.entries.size()):
		for d: Variant in e.log.entries[i].get("details", []):
			if str(d).contains("High ground"):
				found = true
	assert_true(found, "the roll says why")
