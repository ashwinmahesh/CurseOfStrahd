extends TestCase
## Bosses hit harder (owner, 2026-10-19: "the amount of damage bosses do should be ramped up ... maybe 25%";
## combat/difficulty.gd boss_damage and damage_factor, EncounterDamage.deal_damage): everything one of the game's bosses
## (Difficulty.boss_entry: narrative/combat/bosses.json by monster or name, or any foe with legendary actions) deals the other
## side is multiplied before the target's defenses, with a line in the log; their minions, ordinary foes, the party and
## a boss's own side keep the book's numbers, and so does Story.


func _blow(e: Encounter, source: Combatant, target: Combatant, parts: Array = [{"amount": 20, "type": "force"}]) -> int:
	target.creature.hp = target.creature.max_hp()
	var before := target.creature.hp
	e.deal_damage(source, target, parts, false, "a test blow")
	return before - target.creature.hp


func _field(mode: String = "balanced") -> Encounter:
	var e := TestCombat.open_field()
	e.difficulty = Difficulty.named(mode)
	return e


func _named(e: Encounter, id: String, as_name: String, cell: Vector2i) -> Combatant:
	var c := TestCombat.foe(e, id, cell)
	c.creature.name = as_name
	return c


func test_a_boss_with_legendary_actions_hits_a_quarter_harder() -> void:
	var e := _field()
	var hero := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(0, 0), 10)
	var strahd := TestCombat.foe(e, "strahd_von_zarovich", Vector2i(3, 3))
	assert_eq(_blow(e, strahd, hero), 25, "Strahd's 20 is 25")
	var entry := e.log.last()[0]
	assert_eq(str(entry["kind"]), "hit")
	assert_true((entry["details"] as Array).any(func(d: Variant) -> bool: return str(d) == "Boss: +5 damage (x1.25)"),
		"the log shows the extra")


func test_a_listed_boss_does_and_so_does_a_named_one() -> void:
	var e := _field()
	var hero := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(0, 0), 10)
	var izek := TestCombat.foe(e, "izek_strazni", Vector2i(2, 2))
	var mother := _named(e, "night_hag", "Morgantha", Vector2i(3, 2))
	var hag := TestCombat.foe(e, "night_hag", Vector2i(4, 2))
	var vasilka := _named(e, "flesh_golem", "Vasilka", Vector2i(5, 2))
	assert_eq(_blow(e, izek, hero), 25, "Izek, listed by monster")
	assert_eq(_blow(e, mother, hero), 25, "Morgantha, listed by name")
	assert_eq(_blow(e, vasilka, hero), 25, "Vasilka, listed by name")
	assert_eq(_blow(e, hag, hero), 20, "a night hag with no name is a hag")


func test_ordinary_foes_and_minions_keep_the_book() -> void:
	var e := _field()
	var hero := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(0, 0), 10)
	for id: String in ["wolf", "flesh_golem", "berserker", "vampire_spawn", "mongrelfolk"]:
		var foe := TestCombat.foe(e, id, Vector2i(3, 3))
		assert_eq(_blow(e, foe, hero), 20, "%s" % id)


func test_only_what_a_boss_deals_the_other_side_counts() -> void:
	var e := _field()
	var hero := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(0, 0), 10)
	var strahd := TestCombat.foe(e, "strahd_von_zarovich", Vector2i(3, 3))
	var spawn := TestCombat.foe(e, "vampire_spawn", Vector2i(4, 3))
	assert_eq(_blow(e, hero, strahd), 20, "the party hits a boss for what it rolls")
	assert_eq(_blow(e, strahd, spawn), 20, "a boss's blow on its own side (a Fireball that catches its spawn) is unchanged")
	assert_eq(_blow(e, null, hero), 20, "no source, no boss")


func test_every_part_grows_and_rounds_to_the_nearest() -> void:
	var e := _field()
	var hero := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(0, 0), 10)
	var strahd := TestCombat.foe(e, "strahd_von_zarovich", Vector2i(3, 3))
	var parts := [{"amount": 8, "type": "force"}, {"amount": 4, "type": "fire"}, {"amount": 2, "type": "radiant"}]
	assert_eq(_blow(e, strahd, hero, parts), 10 + 5 + 3, "8 -> 10, 4 -> 5, 2 -> 3")
	assert_eq(int((parts[0] as Dictionary)["amount"]), 8, "the caller's list is left as it was")


func test_the_targets_resistance_comes_after() -> void:
	var e := _field()
	var hero := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(0, 0), 10)
	var strahd := TestCombat.foe(e, "strahd_von_zarovich", Vector2i(3, 3))
	var flat := _blow(e, strahd, hero, [{"amount": 20, "type": "psychic"}])
	hero.creature.base_resistances.append("psychic")
	assert_eq(flat, 25)
	assert_eq(_blow(e, strahd, hero, [{"amount": 20, "type": "psychic"}]), 12, "25, halved and rounded down")


func test_the_modes() -> void:
	var want := {"story": 20, "balanced": 25, "tactician": 25, "honour": 25}
	for mode: String in want:
		var e := _field(mode)
		var hero := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(0, 0), 10)
		var strahd := TestCombat.foe(e, "strahd_von_zarovich", Vector2i(3, 3))
		assert_eq(_blow(e, strahd, hero), int(want[mode]), mode)
	assert_true(Difficulty.named("balanced").describe().has("Bosses hit 25% harder."), "the New game page says so")
	assert_false(Difficulty.named("story").describe().any(func(l: String) -> bool: return l.begins_with("Bosses hit")),
		"Story doesn't")
