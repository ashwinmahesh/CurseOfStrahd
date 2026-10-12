extends TestCase
## Dark One's Own Luck (Fiend 6, 2024 PHB): after seeing a failed saving throw or ability check, the warlock may add
## 1d10, Charisma modifier uses a Long Rest, once a roll. Owner (2026-10-12): it asks, it isn't automatic. In a fight a
## roll that can pause asks with the roll, the DC and the uses left; a roll that can't uses it only on Automatic; out
## of a fight a failed check offers it among the aids; a trap's save uses it only on Automatic. Kip is a level 6 Fiend.

const OWN := "dark_ones_own_luck"


## The swarm of ravens' Cacophony (a Wisdom save or Deafened) at `dc`.
func _ravens(e: Encounter, cell: Vector2i, dc: int) -> Combatant:
	var data := Compendium.shared().monster_data("swarm_of_ravens").duplicate(true)
	for a: Variant in data["actions"]:
		if str((a as Dictionary)["id"]) == "cacophony":
			((a as Dictionary)["save"] as Dictionary)["dc"] = dc
	return e.add(Monster.from_data(data), &"enemy", cell)


func _kip(e: Encounter) -> Combatant:
	var kip := TestCombat.hero(e, "kip_smudgewick", Vector2i(2, 2), 6)
	(kip.creature as Character).heroic_inspiration = false
	return kip


func _left(kip: Combatant) -> int:
	return (kip.creature as Character).resource_left(OWN)


func _wis(c: Combatant) -> int:
	return c.creature.save_bonus(&"wis").total()


func test_a_failed_save_in_a_fight_asks_with_the_roll_the_dc_and_the_uses_left() -> void:
	var e := TestCombat.open_field(3)
	var kip := _kip(e)
	var dc := _wis(kip) + 8
	var ravens := _ravens(e, Vector2i(3, 2), dc)
	TestCombat.start_with(e, ravens)
	var uses := _left(kip)
	assert_true(uses >= 1)
	TestCombat.next_d20(e, 2)
	var r := CombatResult.new()
	e.monster_actions.save_action(ravens, (ravens.creature as Monster).action("cacophony"), kip, r)
	assert_true(e.pending != null and e.pending.kind == OWN, "asked: %s" % (e.pending.kind if e.pending != null else "nothing"))
	if e.pending == null:
		return
	assert_true(e.pending.text.contains("vs DC %d" % dc), e.pending.text)
	assert_true(e.pending.cost.contains("%d left" % uses), e.pending.cost)
	assert_false(e.pending.spends_reaction)
	e.answer_reaction(true)
	assert_eq(_left(kip), uses - 1, "a use spent")
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("calls on the Dark One's luck")))


func test_declining_keeps_the_use() -> void:
	var e := TestCombat.open_field(3)
	var kip := _kip(e)
	var ravens := _ravens(e, Vector2i(3, 2), _wis(kip) + 8)
	TestCombat.start_with(e, ravens)
	var uses := _left(kip)
	TestCombat.next_d20(e, 2)
	e.monster_actions.save_action(ravens, (ravens.creature as Monster).action("cacophony"), kip, CombatResult.new())
	assert_true(e.pending != null and e.pending.kind == OWN)
	e.answer_reaction(false)
	assert_eq(_left(kip), uses)
	assert_true(kip.creature.has_condition(&"deafened"), "the failure stands")


func test_a_roll_that_cant_wait_uses_it_only_on_automatic() -> void:
	var e := TestCombat.open_field(3)
	var kip := _kip(e)
	TestCombat.start_with(e, kip)
	var uses := _left(kip)
	var dc := _wis(kip) + 8
	TestCombat.next_d20(e, 2)
	kip.creature.roll_save(e.dice, &"wis", dc)
	assert_eq(_left(kip), uses, "on Ask, never spent where it can't be asked")
	kip.reaction_rules[OWN] = "auto"
	TestCombat.next_d20(e, 2)
	var t := kip.creature.roll_save(e.dice, &"wis", dc)
	assert_eq(_left(kip), uses - 1, "on Automatic, used")
	assert_true(t.extra_label.contains("Dark One's Own Luck"), t.describe())


func test_out_of_a_fight_a_failed_check_offers_it_once_and_off_hides_it() -> void:
	var kip := TestChars.pregen("kip_smudgewick", 6)
	kip.finish_long_rest()
	var dc := kip.skill_bonus(&"persuasion").total() + 8
	var t := kip.roll_check(DiceRoller.new(TestChars.seed_for_d20(2)), &"persuasion", dc)
	assert_false(t.success)
	var ids := CheckAids.options(kip, t).map(func(a: Dictionary) -> String: return str(a["id"]))
	assert_true(OWN in ids, str(ids))
	var label := str(CheckAids.options(kip, t).filter(func(a: Dictionary) -> bool: return str(a["id"]) == OWN)[0]["label"])
	assert_true(label.contains("%d left" % kip.resource_left(OWN)), label)
	var uses := kip.resource_left(OWN)
	CheckAids.apply(OWN, kip, t, DiceRoller.new(7))
	assert_eq(kip.resource_left(OWN), uses - 1)
	assert_false(OWN in CheckAids.options(kip, t).map(func(a: Dictionary) -> String: return str(a["id"])), "once a roll")
	var t2 := kip.roll_check(DiceRoller.new(TestChars.seed_for_d20(2)), &"persuasion", dc)
	kip.reaction_rules[OWN] = "never"
	assert_false(OWN in CheckAids.options(kip, t2).map(func(a: Dictionary) -> String: return str(a["id"])), "Off hides it")


func test_a_traps_save_uses_it_only_on_automatic() -> void:
	var kip := TestChars.pregen("kip_smudgewick", 6)
	kip.finish_long_rest()
	var dc := kip.save_bonus(&"dex").total() + 8
	var t := kip.roll_save(DiceRoller.new(TestChars.seed_for_d20(2)), &"dex", dc)
	var uses := kip.resource_left(OWN)
	assert_false(CheckAids.own_luck_on_save(kip, t, DiceRoller.new(7)), "Ask: a falling hero can't be asked")
	assert_eq(kip.resource_left(OWN), uses)
	kip.reaction_rules[OWN] = "auto"
	assert_true(CheckAids.own_luck_on_save(kip, t, DiceRoller.new(7)))
	assert_eq(kip.resource_left(OWN), uses - 1)
