extends TestCase
## Spells that help a check (Ashwin's answer to the spell audit, 2026-10-12): a cantrip its caster knows gives
## Advantage on one skill outside fights (CheckAids.CANTRIP_AIDS); Detect Thoughts, the disguises, the illusions and
## the rest give it while they run (FieldCasting.CHECK_AIDS); Zone of Amicability floors a check to influence at 10;
## Druidcraft reads tomorrow's weather.


func _caster(cls: String, level: int, spells: Array) -> Character:
	var ch := TestChars.custom(cls, "human", level)
	var prepared := (ch.spellcasting[0] as Dictionary)["prepared"] as Array
	for s: Variant in spells:
		if not str(s) in prepared:
			prepared.append(str(s))
	TestCombat.give_components(ch, spells)
	ch.finish_long_rest()
	return ch


func _party(ch: Character) -> StoryState:
	var st := StoryState.new()
	st.party.append(ch)
	st.party.append(TestChars.pregen("ilse_varga", 5))
	st.location = "vallaki"
	return st


func test_a_known_cantrip_helps_its_skill() -> void:
	var cleric := _caster("cleric", 3, [])
	var cantrips := ((cleric.spellcasting[0] as Dictionary).get("cantrips", []) as Array)
	if not "thaumaturgy" in cantrips:
		cantrips.append("thaumaturgy")
	assert_true(cleric.knows_spell("thaumaturgy"))
	assert_eq(CheckAids.before_check(cleric, &"intimidation"), ["Thaumaturgy"] as Array[String])
	assert_true(CheckAids.before_check(cleric, &"persuasion").is_empty(), "only its own skill")
	var t := cleric.roll_check(DiceRoller.new(3), &"intimidation", 12, CheckAids.before_check(cleric, &"intimidation"))
	assert_true("Thaumaturgy" in t.advantage_sources)
	assert_true(CheckAids.before_check(TestChars.pregen("ilse_varga", 5), &"intimidation").is_empty(), "a fighter has no cantrip for it")


func test_detect_thoughts_helps_insight_while_it_runs() -> void:
	var wiz := _caster("wizard", 5, ["detect_thoughts"])
	var st := _party(wiz)
	assert_true(bool(FieldCasting.cast_utility(st, wiz, "detect_thoughts", false)["ok"]))
	var t := wiz.roll_check(DiceRoller.new(4), &"insight", 12)
	assert_true("Detect Thoughts" in t.advantage_sources, str(t.advantage_sources))
	st.advance_minutes(5)
	assert_false("Detect Thoughts" in wiz.roll_check(DiceRoller.new(4), &"insight", 12).advantage_sources, "a minute, and it's gone")


func test_seeming_disguises_the_whole_party() -> void:
	var wiz := _caster("wizard", 9, ["seeming"])
	var st := _party(wiz)
	assert_true(bool(FieldCasting.cast_utility(st, wiz, "seeming", false)["ok"]))
	for ch in st.party:
		assert_true("Seeming" in ch.roll_check(DiceRoller.new(2), &"deception", 12).advantage_sources, ch.name)


func test_zone_of_amicability_floors_a_check_to_influence() -> void:
	var bard := _caster("bard", 7, ["zone_of_amicability"])
	var st := _party(bard)
	assert_true(bool(FieldCasting.cast_utility(st, bard, "zone_of_amicability", false)["ok"]))
	var low := DiceRoller.new(TestChars.seed_for_d20(2))
	var t := bard.roll_check(low, &"persuasion", 30)
	assert_eq(t.kept, 10, "a 2 counts as a 10")
	var low2 := DiceRoller.new(TestChars.seed_for_d20(2))
	assert_eq(bard.roll_check(low2, &"arcana", 30).kept, 2, "not a check to influence")


func test_druidcraft_reads_tomorrows_weather() -> void:
	var druid := _caster("druid", 1, [])
	var cantrips := ((druid.spellcasting[0] as Dictionary).get("cantrips", []) as Array)
	if not "druidcraft" in cantrips:
		cantrips.append("druidcraft")
	var st := _party(druid)
	var res := FieldCasting.cast_utility(st, druid, "druidcraft", false)
	assert_true(bool(res["ok"]), str(res["text"]))
	assert_true(str(res["text"]).contains("tomorrow brings"), str(res["text"]))
	assert_eq(CheckAids.before_check(druid, &"nature"), ["Druidcraft"] as Array[String])
