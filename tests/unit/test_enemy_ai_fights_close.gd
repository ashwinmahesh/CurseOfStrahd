extends TestCase
## Enemy AI (Ashwin, 2026-10-24): a monster whose melee does more than its ranged option goes in to melee, a foe beside a
## hero it can strike with its strongest attack doesn't leave for someone else when leaving would draw an Opportunity
## Attack, and an area a foe casts or breathes never takes in itself or its friends.


func _melee(id: String, bonus: int, damage: int) -> Dictionary:
	return {"id": id, "name": id.capitalize(), "kind": "melee", "attack": {"bonus": bonus, "reach": 5},
		"damage": [{"average": damage, "dice": "1d1+%d" % (damage - 1), "type": "bludgeoning"}]}


func _thrown(id: String, bonus: int, damage: int) -> Dictionary:
	return {"id": id, "name": id.capitalize(), "kind": "ranged", "attack": {"bonus": bonus, "range": [30, 60]},
		"damage": [{"average": damage, "dice": "1d1+%d" % (damage - 1), "type": "bludgeoning"}]}


func _body(ac: int, actions: Array) -> Monster:
	return TestChars.dummy(500, false, {"ac": ac, "actions": actions})


## The foe, a hero 20 ft off (so it has to choose to walk up) and the plan it makes: {e, foe, hero, plan, picked}.
func _plan_at_range(actions: Array) -> Dictionary:
	var e := TestCombat.open_field(3)
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(6, 3), 5)
	hero.creature.hp = 500
	var foe := e.add(_body(12, actions), &"enemy", Vector2i(2, 3))
	TestCombat.start_with(e, foe)
	var plan := e.ai.plan_turn(foe)
	var picked := "none"
	if str(plan.get("kind", "")) == "attack":
		picked = "melee" if bool(e.option_by_id(foe, str(plan["option"])).get("melee", false)) else "ranged"
	return {"e": e, "foe": foe, "hero": hero, "plan": plan, "picked": picked}


func test_a_melee_multiattack_beats_a_single_stronger_throw() -> void:
	# Two fists of 5 against a rock of 8: ten against eight, so it walks up.
	var f := _plan_at_range([
		{"id": "multiattack", "name": "Multiattack", "kind": "multiattack", "multiattack": [{"action": "fist", "count": 2}]},
		_melee("fist", 5, 5), _thrown("rock", 5, 8)])
	assert_eq(f["picked"], "melee", "the plan: %s" % str(f["plan"]))


func test_without_the_multiattack_the_stronger_throw_stands() -> void:
	var f := _plan_at_range([_melee("fist", 5, 5), _thrown("rock", 5, 8)])
	assert_eq(f["picked"], "ranged", "one fist of 5 against a rock of 8: it throws")


func test_a_single_stronger_melee_blow_is_preferred_too() -> void:
	var f := _plan_at_range([_melee("slam", 5, 12), _thrown("pebble", 5, 4)])
	assert_eq(f["picked"], "melee")


## A monster's Multiattack as damage: each entry's best choice (a melee one for `melee`, else a ranged one), as many times as it counts.
func _multi_total(e: Encounter, c: Combatant, melee: bool) -> float:
	var total := 0.0
	var m := c.creature as Monster
	for entry: Variant in m.action("multiattack").get("multiattack", []):
		var en := entry as Dictionary
		var choices: Array = [str(en["action"])]
		choices.append_array(en.get("or", []))
		var best := 0.0
		for cid: Variant in choices:
			var opt := e.option_by_id(c, "monster:" + str(cid))
			if not opt.is_empty() and bool(opt["melee"]) == melee:
				best = maxf(best, e.ai._avg(c, opt))
		total += best * int(en.get("count", 1))
	return total


## No monster with both a melee Multiattack worth clearly more than its best throw picks the throw from 20 ft off.
func test_no_monster_throws_when_its_melee_clearly_does_more() -> void:
	var odd: Array[String] = []
	var ids := (Compendium.shared().tables["monsters"] as Dictionary).keys()
	ids.sort()
	for id: Variant in ids:
		var mon := TestCombat.monster(str(id))
		var e := TestCombat.open_field(3)
		var hero := TestCombat.hero(e, "ilse_varga", Vector2i(6, 3), 5)
		hero.creature.hp = 500
		var foe := e.add(mon, &"enemy", Vector2i(2, 3))
		TestCombat.start_with(e, foe)
		var melee := 0.0
		var ranged := 0.0
		for o in e.ai._usable_options(foe):
			if bool(o["melee"]):
				melee = maxf(melee, maxf(e.ai._avg(foe, o), _multi_total(e, foe, true)))
			else:
				ranged = maxf(ranged, maxf(e.ai._avg(foe, o), _multi_total(e, foe, false)))
		if melee <= 0.0 or ranged <= 0.0 or melee < ranged * 1.3 or foe.speed() < 20:
			continue
		var plan := e.ai.plan_turn(foe)
		if str(plan.get("kind", "")) == "attack" and not bool(e.option_by_id(foe, str(plan["option"])).get("melee", false)):
			odd.append("%s (melee %.1f against %.1f)" % [id, melee, ranged])
	assert_eq(odd, [] as Array[String], "these throw from 20 ft with melee that clearly does more")


## Hero A (hard to hit) beside the foe, hero B (easy) a few squares off: the foe stays on A while A could strike it as it
## left, and goes to B when A has no Reaction.
func _two_heroes(a_reacts: bool) -> Dictionary:
	var e := TestCombat.open_field(5)
	var a := e.add(_body(30, [_melee("blade", 10, 10)]), &"party", Vector2i(5, 3))
	var b := e.add(_body(1, [_melee("blade", 10, 10)]), &"party", Vector2i(4, 7))
	var foe := e.add(_body(12, [_melee("maul", 5, 30)]), &"enemy", Vector2i(4, 3))
	TestCombat.start_with(e, foe)
	a.reaction_available = a_reacts
	b.reaction_available = false
	return {"e": e, "a": a, "b": b, "foe": foe, "plan": e.ai.plan_turn(foe)}


func test_a_foe_does_not_walk_off_a_hero_it_can_strike_when_that_draws_an_opportunity_attack() -> void:
	var f := _two_heroes(true)
	var plan := f["plan"] as Dictionary
	assert_eq(str(plan.get("kind", "")), "attack")
	assert_eq(plan["target"], f["a"], "it stays on the hero beside it: %s" % str(plan))
	assert_eq(plan["cell"], (f["foe"] as Combatant).cell, "and does not move")


func test_it_goes_when_the_hero_beside_it_cannot_strike_back() -> void:
	var f := _two_heroes(false)
	var plan := f["plan"] as Dictionary
	assert_eq(plan["target"], f["b"], "no Reaction beside it: the easy hero is the better target: %s" % str(plan))


# --- An area never takes in the caster or its friends ----------------------------------------------------------

## The squares' creatures an area plan would catch.
func _caught(e: Encounter, c: Combatant, s: Dictionary, p: Dictionary) -> Array[Combatant]:
	var point := p.get("point", Vector2.INF) as Vector2
	return e.spells.creatures_in(e.spells.area_for(c, s, point if point != Vector2.INF else e.center_of(c), p.get("direction", Vector2.ZERO) as Vector2))


## A mage (Fireball two a day) at `mage_cell`, a hero at (8, 3) and a goblin of its own side at `friend_cell`.
func _mage_scene(mage_cell: Vector2i, friend_cell: Vector2i) -> Dictionary:
	var rows: Array[String] = []
	for z in 10:
		rows.append("....................")
	var e := Encounter.new(CombatGrid.from_rows(rows), DiceRoller.new(5))
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(8, 3), 5)
	hero.creature.hp = 500
	var mage := TestCombat.foe(e, "mage", mage_cell)
	mage.creature.hp = 500
	var friend: Combatant = null
	if friend_cell != Vector2i(-1, -1):
		friend = TestCombat.foe(e, "goblin", friend_cell)
	TestCombat.start_with(e, mage)
	return {"e": e, "mage": mage, "hero": hero, "friend": friend}


func test_a_fireball_that_would_catch_a_friend_is_not_cast() -> void:
	# The goblin stands right beside the hero: no spot takes in the hero and leaves it out.
	var f := _mage_scene(Vector2i(0, 3), Vector2i(9, 3))
	var e := f["e"] as Encounter
	var plan := e.ai.spells.plan(f["mage"] as Combatant, 0.0)
	if not plan.is_empty():
		var s := Compendium.shared().spell_data(str(plan["spell"]))
		if s.has("area"):
			for v in _caught(e, f["mage"] as Combatant, s, plan):
				assert_true((f["mage"] as Combatant).hostile_to(v), "%s is its own side: %s" % [v.name(), str(plan)])


func test_a_fireball_is_placed_clear_of_the_caster() -> void:
	# The mage is 20 ft from the hero: a Fireball centred on the hero would burn the mage too, so it is placed a square past.
	var f := _mage_scene(Vector2i(4, 3), Vector2i(-1, -1))
	var e := f["e"] as Encounter
	var mage := f["mage"] as Combatant
	var s := Compendium.shared().spell_data("fireball")
	var plan := e.ai.spells._best_use(mage, "fireball")
	assert_false(plan.is_empty(), "there is still a spot that takes in the hero")
	var caught := _caught(e, mage, s, plan)
	assert_false(mage in caught, "the mage is out of its own blast")
	assert_true(f["hero"] in caught, "and the hero is in it")


func test_a_fireball_with_nobody_of_its_own_in_the_way_is_cast_as_before() -> void:
	var f := _mage_scene(Vector2i(0, 3), Vector2i(-1, -1))
	var e := f["e"] as Encounter
	var plan := e.ai.spells._best_use(f["mage"] as Combatant, "fireball")
	assert_false(plan.is_empty())
	assert_true(f["hero"] in _caught(e, f["mage"] as Combatant, Compendium.shared().spell_data("fireball"), plan))


func _breather(e: Encounter, cell: Vector2i) -> Combatant:
	var act := {"id": "breath", "name": "Breath", "kind": "save", "recharge": "5-6", "save": {"ability": "dex", "dc": 13, "success": "half"},
		"area": {"shape": "cone", "size": 30}, "targets": {"range": 30}, "damage": [{"average": 20, "dice": "1d1+19", "type": "fire"}]}
	return e.add(_body(12, [act]), &"enemy", cell)


func test_a_breath_that_would_catch_a_friend_is_not_used_and_one_that_is_clear_is() -> void:
	var rows: Array[String] = []
	for z in 10:
		rows.append("....................")
	var e := Encounter.new(CombatGrid.from_rows(rows), DiceRoller.new(5))
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(6, 3), 5)
	hero.creature.hp = 500
	var dragon := _breather(e, Vector2i(2, 3))
	var friend := TestCombat.foe(e, "goblin", Vector2i(5, 3))   # in the cone, between the two
	TestCombat.start_with(e, dragon)
	assert_true(e.ai._save_action_plan(dragon).is_empty(), "its friend stands in the cone")
	friend.cell = Vector2i(2, 8)   # well out of it
	assert_false(e.ai._save_action_plan(dragon).is_empty(), "with the friend clear of the cone it breathes")
