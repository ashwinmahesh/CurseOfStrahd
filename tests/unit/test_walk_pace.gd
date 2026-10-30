extends TestCase
## Everyone walks 25% faster while exploring (owner 2026-10-18), all from WalkPace.FASTER; then the heroes 25% slower and
## enemies 15% faster (owner 2026-10-30), from WalkPace.HEROES and FOES. A fight's base square time is left alone and each
## side scales it. Only how the walk looks: the Speed stat, movement left and the AI's reach are not touched.

const EPS := 0.0001


func test_the_walk_is_a_quarter_faster_than_it_was() -> void:
	assert_between(WalkPace.FASTER, 1.25 - EPS, 1.25 + EPS, "one scale for every walker")
	assert_between(WalkPace.HEROES, 0.75 - EPS, 0.75 + EPS, "the heroes walk 25% slower")
	assert_between(WalkPace.FOES, 1.15 - EPS, 1.15 + EPS, "enemies walk 15% faster")
	# What each pace was before, in seconds a square (or squares a second, for the two that walk by speed).
	var party := 1.25 * 0.75
	assert_between(LocationView.STEP_TIME, 0.26 / party - EPS, 0.26 / party + EPS, "the party exploring")
	assert_between(LocationView.SNEAK_STEP_TIME, 0.46 / party - EPS, 0.46 / party + EPS, "the party sneaking")
	assert_between(LocationLead.NPC_STEP, 0.34 / party - EPS, 0.34 / party + EPS, "one leading the party")
	assert_between(PartyMember.SPEED, 2.8 * party - EPS, 2.8 * party + EPS, "the gray-box party")
	# Townsfolk keep the 25% faster alone.
	assert_between(NpcRoutes.STEP_TIME, 0.7 / 1.25 - EPS, 0.7 / 1.25 + EPS, "townsfolk on their rounds")
	assert_between(NpcWalker.SPEED, 1.12 * 1.25 - EPS, 1.12 * 1.25 + EPS, "the gray-box villager")


func test_a_fights_base_square_keeps_its_pace() -> void:
	assert_between(CombatView.STEP_TIME, 0.37 - EPS, 0.37 + EPS, "combat movement's base is left alone")


func _walker(side: StringName) -> Combatant:
	return Combatant.new(Monster.from_data(Compendium.shared().monster_data("commoner")), side, Vector2i.ZERO)


func test_each_side_walks_a_fight_at_its_own_pace() -> void:
	var cases := {&"party": WalkPace.HEROES, &"guest": WalkPace.HEROES, &"enemy": WalkPace.FOES, &"neutral": 1.0}
	for side: StringName in cases:
		assert_between(WalkPace.combat_scale(_walker(side)), float(cases[side]) - EPS, float(cases[side]) + EPS, "%s" % side)
	assert_eq(WalkPace.combat_scale(null), 1.0, "no one is left as it was")
	# A square, as the combat view times it: the base divided by the scale.
	var hero := CombatView.STEP_TIME / WalkPace.combat_scale(_walker(&"party"))
	var foe := CombatView.STEP_TIME / WalkPace.combat_scale(_walker(&"enemy"))
	assert_between(hero, 0.37 / 0.75 - EPS, 0.37 / 0.75 + EPS, "a hero's square")
	assert_between(foe, 0.37 / 1.15 - EPS, 0.37 / 1.15 + EPS, "a foe's square")
	assert_true(foe < hero, "foes close in faster than heroes walk")


func test_the_one_leading_is_still_no_quicker_than_the_party() -> void:
	assert_true(LocationLead.NPC_STEP >= LocationView.STEP_TIME, "the party keeps up with a lead")
	assert_true(NpcRoutes.STEP_TIME > LocationView.STEP_TIME, "a stroll stays slower than the party's walk")
