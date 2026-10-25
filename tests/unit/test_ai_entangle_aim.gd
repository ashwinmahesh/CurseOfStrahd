extends TestCase
## A vine blight's Entangling Plants holds everyone in its square, its own side included. It goes where it catches more
## of the party and none of its friends (2026-10-13: at the Yester Hill summit the blights kept rooting Wintersplinter itself;
## a friend of any strength since 2026-10-24), and waits rather than hold one.


static func _field() -> Encounter:
	var rows: Array[String] = []
	for z in 10:
		rows.append("....................")
	return TestCombat.encounter(rows)


static func _caught(e: Encounter, vb: Combatant, plan: Dictionary) -> Array[Combatant]:
	var s := Compendium.shared().spell_data(str(plan["spell"]))
	return e.spells.creatures_in(e.spells.area_for(vb, s, plan["point"] as Vector2, Vector2.RIGHT))


func test_the_vines_take_the_heroes_and_leave_the_tree_out() -> void:
	var e := _field()
	var godrick := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(10, 4), 6)
	var liriel := TestCombat.hero(e, "liriel_dawnsong", Vector2i(11, 4), 6)
	var tree := TestCombat.foe(e, "tree_blight", Vector2i(10, 6))
	var vb := TestCombat.foe(e, "vine_blight", Vector2i(3, 4))
	TestCombat.start_with(e, vb)
	var plan := e.ai._recharge_spell_plan(vb)
	assert_false(plan.is_empty(), "two heroes side by side are worth it")
	var caught := _caught(e, vb, plan)
	assert_true(godrick in caught and liriel in caught, "both heroes: %s" % plan.get("point"))
	assert_false(tree in caught, "not the tree blight just below them")


func test_the_vines_wait_rather_than_hold_a_stronger_friend() -> void:
	var e := _field()
	TestCombat.hero(e, "godrick_pendlebrook", Vector2i(10, 4), 6)
	TestCombat.hero(e, "liriel_dawnsong", Vector2i(11, 4), 6)
	TestCombat.foe(e, "berserker", Vector2i(9, 4))
	TestCombat.foe(e, "berserker", Vector2i(12, 4))
	var vb := TestCombat.foe(e, "vine_blight", Vector2i(3, 4))
	TestCombat.start_with(e, vb)
	assert_true(e.ai._recharge_spell_plan(vb).is_empty(), "a berserker on either side is in every square that holds a hero")


## Not even a lesser friend (a twig blight) is caught along with the party any more (Ashwin, 2026-10-24: an area never takes in
## the caster's friends): the cube can't leave both twig blights out, so the vines wait.
func test_the_vines_wait_rather_than_hold_even_a_twig_blight() -> void:
	var e := _field()
	TestCombat.hero(e, "godrick_pendlebrook", Vector2i(10, 4), 6)
	TestCombat.hero(e, "liriel_dawnsong", Vector2i(11, 4), 6)
	TestCombat.foe(e, "twig_blight", Vector2i(9, 4))
	TestCombat.foe(e, "twig_blight", Vector2i(12, 4))
	var vb := TestCombat.foe(e, "vine_blight", Vector2i(3, 4))
	TestCombat.start_with(e, vb)
	assert_true(e.ai._recharge_spell_plan(vb).is_empty(), "a twig blight on each side: no square leaves both out")