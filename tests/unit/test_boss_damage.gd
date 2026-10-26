extends TestCase
## Bosses hit harder (owner, 2026-10-19: "the amount of damage bosses do should be ramped up ... maybe 25%";
## combat/difficulty.gd boss_damage and damage_factor, EncounterDamage.deal_damage): everything one of the game's bosses
## (Difficulty.boss_entry: narrative/combat/bosses.json by monster or name, or any foe with legendary actions) deals the other
## side is multiplied before the target's defenses, with a line in the log; their minions, ordinary foes, the party and
## a boss's own side keep the book's numbers, and so does Story. Bosses also hit more often on Balanced (owner,
## 2026-10-25: "+1 to bosses before level 5, +2 from 5-8, and +3 for 9-11"): boss_bonus to their attack rolls and DCs by
## the lowest hero's level, +3 on from 12; Tactician and Honour give every foe +2 instead.


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


# --- To hit and DCs --------------------------------------------------------------------------------------------------


func _bonus(c: Combatant, stat: StringName) -> int:
	var total := 0
	var ctx := c.creature.formula_context()
	for m in c.creature.modifiers_for(stat):
		total += c.creature.mod_value(m, ctx)
	return total


func test_on_balanced_bosses_hit_more_often_as_the_party_grows() -> void:
	for pair: Array in [[1, 1], [4, 1], [5, 2], [8, 2], [9, 3], [11, 3], [12, 3]]:
		var e := _field()
		TestCombat.hero(e, "godrick_pendlebrook", Vector2i(0, 0), int(pair[0]))
		var strahd := TestCombat.foe(e, "strahd_von_zarovich", Vector2i(3, 3))
		var mother := _named(e, "night_hag", "Morgantha", Vector2i(5, 3))
		var hag := TestCombat.foe(e, "night_hag", Vector2i(7, 3))
		var wolf := TestCombat.foe(e, "wolf", Vector2i(9, 3))
		e.difficulty.prepare(e)
		var at := "at level %d" % int(pair[0])
		for stat: StringName in [&"attack", &"spell_attack", &"spell_dc"]:
			assert_eq(_bonus(strahd, stat), int(pair[1]), "Strahd, %s %s" % [stat, at])
			assert_eq(_bonus(mother, stat), int(pair[1]), "Morgantha, listed by name, %s %s" % [stat, at])
			assert_eq(_bonus(hag, stat), 0, "a night hag with no name, %s %s" % [stat, at])
			assert_eq(_bonus(wolf, stat), 0, "a wolf, %s %s" % [stat, at])
		assert_eq(e.monster_actions.dc_bonus(strahd), int(pair[1]), "his own actions' DCs (Charm) too, %s" % at)


func test_the_lowest_hero_sets_the_step() -> void:
	var e := _field()
	TestCombat.hero(e, "godrick_pendlebrook", Vector2i(0, 0), 9)
	TestCombat.hero(e, "liriel_dawnsong", Vector2i(1, 0), 4)
	var strahd := TestCombat.foe(e, "strahd_von_zarovich", Vector2i(3, 3))
	e.difficulty.prepare(e)
	assert_eq(_bonus(strahd, &"attack"), 1, "a level 4 hero beside a level 9 one: +1, as the fights' level versions count")
	assert_true(Difficulty.named("balanced").describe().has(
		"Bosses' attack rolls and the DCs of their spells and abilities: +1 to level 4, +2 at levels 5-8, +3 from level 9."),
		"the New game page says so")


func test_the_boss_bonus_by_mode() -> void:
	var want := {"story": [0, 0], "balanced": [3, 0], "tactician": [2, 2], "honour": [2, 2]}
	for mode: String in want:
		var e := _field(mode)
		TestCombat.hero(e, "godrick_pendlebrook", Vector2i(0, 0), 10)
		var strahd := TestCombat.foe(e, "strahd_von_zarovich", Vector2i(3, 3))
		var wolf := TestCombat.foe(e, "wolf", Vector2i(9, 3))
		e.difficulty.prepare(e)
		assert_eq(_bonus(strahd, &"attack"), int((want[mode] as Array)[0]), "%s at level 10: Strahd" % mode)
		assert_eq(_bonus(wolf, &"attack"), int((want[mode] as Array)[1]), "%s at level 10: a wolf" % mode)
