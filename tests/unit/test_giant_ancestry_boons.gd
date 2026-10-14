extends TestCase
## The goliath's Giant Ancestry boons in a fight (owner report 2026-10-12: Cloud's Jaunt couldn't be used). Cloud's
## Jaunt picks its square like Misty Step and spends nothing on a square it can't reach; the others land as written.


func _goliath(e: Encounter, giant: String, cell: Vector2i) -> Combatant:
	var ch := TestChars.custom("fighter", "goliath", 5, {"species.giant_ancestry": [giant]})
	ch.finish_long_rest()
	return e.add(ch, &"party", cell)


func _hit(e: Encounter, g: Combatant, t: Combatant) -> CombatResult:
	var opt := ""
	for o in e.attack_options(g):
		if bool(o["melee"]) and str(o["kind"]) == "weapon":
			opt = str(o["id"])
	TestCombat.next_d20(e, 18)
	return e.attack(g, t, opt)


func test_clouds_jaunt_picks_a_square_within_30_ft() -> void:
	var e := TestCombat.open_field(4)
	var g := _goliath(e, "cloud_giant", Vector2i(1, 1))
	TestCombat.foe(e, "zombie", Vector2i(11, 7))
	TestCombat.start_with(e, g)
	var cat := ActionCatalog.new(e)
	var a := cat.find(g, "feat:clouds_jaunt")
	assert_false(a.is_empty(), "on the bar")
	assert_eq(str(a["targeting"]), "place", "the square picker, as Misty Step's")
	assert_eq(int(a["range"]), 30)
	assert_true(bool(a["legal"]), str(a.get("reason", "")))
	var ch := g.creature as Character
	var uses := ch.resource_left("giant_ancestry")
	var far := cat.perform(g, a, [], Vector2(9.5, 1.5))
	assert_false(far.ok, "40 ft is too far")
	assert_eq(ch.resource_left("giant_ancestry"), uses, "nothing spent on a square it can't reach")
	assert_true(g.bonus_available, "the Bonus Action is still there")
	var r := cat.perform(g, cat.find(g, "feat:clouds_jaunt"), [], Vector2(7.5, 1.5))
	assert_true(r.ok, r.reason)
	assert_eq(g.cell, Vector2i(7, 1), "30 ft away")
	assert_eq(ch.resource_left("giant_ancestry"), uses - 1)
	assert_false(g.bonus_available)


func test_frosts_chill_slows_and_hills_tumble_knocks_prone() -> void:
	var e := TestCombat.open_field(4)
	var frost := _goliath(e, "frost_giant", Vector2i(2, 2))
	var hill := _goliath(e, "hill_giant", Vector2i(2, 4))
	var a := TestCombat.punching_bag(e, Vector2i(3, 2), 200)
	var b := TestCombat.punching_bag(e, Vector2i(3, 4), 200)
	TestCombat.start_with(e, frost)
	assert_true(e.features.toggle_rider(frost, "giant:frosts_chill").ok)
	assert_true(_hit(e, frost, a).hit)
	assert_true(a.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == "frosts_chill"), "its Speed drops 10 ft")
	e.turn_index = e.order.find(hill)
	hill.action_available = true
	hill.attacks_left = 0
	assert_true(e.features.toggle_rider(hill, "giant:hills_tumble").ok)
	assert_true(_hit(e, hill, b).hit)
	assert_true(b.creature.has_condition(&"prone"), "knocked Prone")


func test_stones_endurance_and_storms_thunder_answer_a_blow() -> void:
	var e := TestCombat.open_field(4)
	var stone := _goliath(e, "stone_giant", Vector2i(2, 2))
	var storm := _goliath(e, "storm_giant", Vector2i(2, 5))
	var orc := TestCombat.foe(e, "ogre", Vector2i(3, 3))
	orc.creature.hp = 300
	TestCombat.start_with(e, orc)
	stone.reaction_rules["stones_endurance"] = "auto"
	storm.reaction_rules["storms_thunder"] = "auto"
	var opt := ""
	for o in e.attack_options(orc):
		if bool(o["melee"]):
			opt = str(o["id"])
	TestCombat.next_d20(e, 18)
	e.attack(orc, stone, opt)
	while e.pending != null:
		e.answer_reaction(true)
	assert_eq((stone.creature as Character).resource_left("giant_ancestry"), (stone.creature as Character).resource_max("giant_ancestry") - 1, "Stone's Endurance used")
	orc.attacks_left = 1
	var hp := orc.creature.hp
	TestCombat.next_d20(e, 18)
	e.attack(orc, storm, opt)
	while e.pending != null:
		e.answer_reaction(true)
	assert_true(orc.creature.hp < hp, "Storm's Thunder struck back")


## Large Form only in a big enough space (2024; owner report 2026-10-13: with no room to grow it still took his Bonus
## Action): with no clear 10-ft square it's greyed out with the reason and spends nothing; beside a wall it grows into
## the free corner that keeps it on its square.
func test_large_form_needs_room_and_spends_nothing_without_it() -> void:
	var e := TestCombat.encounter(["#######", "#.....#", "#######"], 4)
	var g := _goliath(e, "stone_giant", Vector2i(2, 1))
	TestCombat.foe(e, "zombie", Vector2i(5, 1))
	TestCombat.start_with(e, g)
	var cat := ActionCatalog.new(e)
	var a := cat.find(g, "feat:large_form")
	assert_false(a.is_empty(), "on the bar")
	assert_false(bool(a["legal"]), "a corridor 5 ft wide")
	assert_true(str(a.get("reason", "")).contains("No room to grow"), str(a.get("reason", "")))
	var ch := g.creature as Character
	var uses := ch.resource_left("large_form")
	var speed := g.speed()
	assert_false(cat.perform(g, a, [], Vector2.INF).ok)
	assert_eq(ch.resource_left("large_form"), uses, "the use is kept")
	assert_true(g.bonus_available, "and the Bonus Action")
	assert_eq(g.creature.size, &"medium")
	assert_eq(g.speed(), speed, "no +10 ft Speed without the growth")
	var e2 := TestCombat.open_field(4)
	var g2 := _goliath(e2, "stone_giant", Vector2i(11, 7))
	TestCombat.foe(e2, "zombie", Vector2i(1, 1))
	TestCombat.start_with(e2, g2)
	var cat2 := ActionCatalog.new(e2)
	var r := cat2.perform(g2, cat2.find(g2, "feat:large_form"), [], Vector2.INF)
	assert_true(r.ok, r.reason)
	assert_eq(g2.creature.size, &"large")
	assert_eq(g2.cell, Vector2i(10, 6), "grown into the corner of the field, still on its square")
	assert_true(Vector2i(11, 7) in g2.footprint())
	assert_false(g2.bonus_available)
	assert_eq((g2.creature as Character).resource_left("large_form"), 0)
