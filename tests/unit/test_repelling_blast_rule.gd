extends TestCase
## Repelling Blast is optional (owner, 2026-10-12; the 2024 invocation says the warlock "can" push): a rule on the
## Reactions tab, Automatic (push) by default, Off to leave the creature where it stands.


func _kip(e: Encounter) -> Combatant:
	return TestCombat.hero(e, "kip_smudgewick", Vector2i(2, 3), 5)


func test_the_push_is_a_rule_on_the_reactions_tab_pushing_by_default() -> void:
	var e := TestCombat.open_field(3)
	var kip := _kip(e)
	var bag := TestCombat.punching_bag(e, Vector2i(5, 3), 300)
	TestCombat.start_with(e, kip)
	var cat := ActionCatalog.new(e)
	var rule := {}
	for s in cat.slots(kip, ActionCatalog.REACTIONS):
		if str(s["label"]) == "Repelling Blast":
			rule = s
	assert_true(bool(rule.get("toggle", false)), "a Repelling Blast toggle")
	assert_eq(str(rule["sub"]), "Automatic", "pushing to start with")
	TestCombat.next_d20(e, 19)
	assert_true(e.spells.cast(kip, "eldritch_blast", 0, [bag]).ok)
	assert_true(bag.cell.x > 5, "pushed: %s" % bag.cell)


func test_off_leaves_the_target_where_it_stands() -> void:
	var e := TestCombat.open_field(3)
	var kip := _kip(e)
	var bag := TestCombat.punching_bag(e, Vector2i(5, 3), 300)
	TestCombat.start_with(e, kip)
	var cat := ActionCatalog.new(e)
	assert_true(cat.set_rule(kip, cat.find(kip, "feat:reaction_policy:repelling_blast:never")).ok, "set Off")
	TestCombat.next_d20(e, 19)
	var hp := bag.creature.hp
	assert_true(e.spells.cast(kip, "eldritch_blast", 0, [bag]).ok)
	assert_true(bag.creature.hp < hp, "the blast still hits")
	assert_eq(bag.cell, Vector2i(5, 3), "but doesn't push")
