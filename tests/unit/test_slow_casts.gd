extends TestCase
## Spells too slow to cast in a fight that couldn't be cast anywhere in the campaign either (Ashwin's "fix the remaining
## bugs for spells", 2026-10-12): Prayer of Healing, Regenerate and Foresight are cast outside fights from the character
## sheet, their minutes passing on the clock; Animate Dead and Create Undead are cast while exploring, and their dead
## follow their caster for a day and join each fight.


func _caster(cls: String, level: int, spells: Array) -> Character:
	var ch := TestChars.custom(cls, "human", level)
	var prepared := (ch.spellcasting[0] as Dictionary)["prepared"] as Array
	for s: Variant in spells:
		if not str(s) in prepared:
			prepared.append(str(s))
	TestCombat.give_components(ch, spells)
	ch.finish_long_rest()
	return ch


func _undead_with(e: Encounter, summoner: Combatant, monster: String) -> int:
	var n := 0
	for c in e.combatants:
		if c.creature is Monster and str((c.creature as Monster).data.get("id", "")) == monster and str(c.get_meta("summoner", "")) == summoner.id:
			n += 1
	return n


func test_prayer_of_healing_outside_a_fight() -> void:
	var st := StoryState.new()
	var cleric := _caster("cleric", 5, ["prayer_of_healing"])
	var fighter := TestChars.pregen("ilse_varga", 5)
	st.party.append(cleric)
	st.party.append(fighter)
	fighter.hp = 5
	var o := {}
	for x in FieldCasting.options(st.party, cleric, DiceRoller.new(1)):
		if str(x["id"]) == "prayer_of_healing":
			o = x
	assert_false(o.is_empty(), "on the sheet")
	assert_true(bool(o["legal"]), str(o.get("reason", "")))
	var before := st.total_minutes()
	var targets: Array[Character] = [fighter]
	var res := FieldCasting.cast(st.party, cleric, "prayer_of_healing", 0, targets, DiceRoller.new(2), st)
	assert_true(bool(res["ok"]), str(res["text"]))
	assert_true(fighter.hp > 5, "healed")
	assert_eq(st.total_minutes() - before, 10, "ten minutes of prayer")


func test_animate_dead_raises_a_skeleton_that_joins_the_days_fights() -> void:
	var st := StoryState.new()
	var wiz := _caster("wizard", 5, ["animate_dead"])
	st.party.append(wiz)
	var res := FieldCasting.cast_utility(st, wiz, "animate_dead", false, 0, "", "skeleton")
	assert_true(bool(res["ok"]), str(res["text"]))
	var e := TestCombat.open_field()
	var c := e.add(wiz, &"party", Vector2i(2, 2))
	FieldCasting.bring_risen(e, st)
	assert_eq(_undead_with(e, c, "skeleton"), 1, "a skeleton beside its caster")
	st.advance_minutes(25 * 60)
	var e2 := TestCombat.open_field()
	var c2 := e2.add(wiz, &"party", Vector2i(2, 2))
	FieldCasting.bring_risen(e2, st)
	assert_eq(_undead_with(e2, c2, "skeleton"), 0, "a day later it's done")


func test_create_undead_only_at_night_and_three_ghouls() -> void:
	var st := StoryState.new()
	var wiz := _caster("wizard", 11, ["create_undead"])
	st.party.append(wiz)
	st.minute_of_day = 12 * 60
	assert_false(bool(FieldCasting.cast_utility(st, wiz, "create_undead", false)["ok"]), "not by day")
	st.minute_of_day = 23 * 60
	var res := FieldCasting.cast_utility(st, wiz, "create_undead", false)
	assert_true(bool(res["ok"]), str(res["text"]))
	var e := TestCombat.open_field()
	var c := e.add(wiz, &"party", Vector2i(2, 2))
	FieldCasting.bring_risen(e, st)
	assert_eq(_undead_with(e, c, "ghoul"), 3)
