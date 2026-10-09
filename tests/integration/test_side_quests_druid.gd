extends TestCase
## The Druid Who Came Back (docs/story/side_quests.md): Davian's lantern on Yester Hill, whoever came back to plant on the
## burned crown (Ruxandra if she was spared, Kostin if he walked away doubting, else Zorica), the Ash Effigy and who
## stands beside it, and Davian paying once the lantern's out.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "ratatoille", "thistle"]


func _crown(level: int = 8) -> StoryState:
	var st := SideQuestPlay.party(FOUR, level, "yester_hill_gulthias_tree", 22)
	st.set_flag("yester_hill_resolved")
	st.set_flag("gulthias_tree_burned")
	st.set_quest_stage("the_druid_who_came_back", "rumored")
	return st


func _has(enc: Dictionary, who: String) -> bool:
	return SideQuestPlay.has_foe(enc, who)


func test_davians_lantern() -> void:
	var st := SideQuestPlay.party(FOUR, 8, "wizard_of_wines", 12)
	st.set_flag("winery_reclaimed")
	st.set_flag("gulthias_tree_burned")
	st.set_quest_stage("the_black_row", "asked")
	var beats := SideQuestPlay.play(st, "wizard_of_wines/the_black_row:davian_news")
	assert_true(SideQuestPlay.text(beats).contains("lantern on Yester Hill"))
	assert_eq(st.quest_stage("the_druid_who_came_back"), "rumored")
	# Not before the tree has burned.
	var early := SideQuestPlay.party(FOUR, 8, "wizard_of_wines", 12)
	early.set_quest_stage("the_black_row", "asked")
	beats = SideQuestPlay.play(early, "wizard_of_wines/the_black_row:davian_news")
	assert_false(SideQuestPlay.text(beats).contains("lantern"))
	# Paid once the effigy is down.
	st.set_quest_stage("the_druid_who_came_back", "burned")
	st.gold = 0
	beats = SideQuestPlay.play(st, "wizard_of_wines/the_black_row:davian_news")
	assert_true(SideQuestPlay.text(beats).contains("postpone it"))
	assert_eq(st.quest_stage("the_druid_who_came_back"), "done")
	assert_eq(roundi(st.gold), 300)
	assert_true(st.party_has_item("daerns_instant_fortress"))
	beats = SideQuestPlay.play(st, "wizard_of_wines/the_black_row:davian_news")
	assert_eq(roundi(st.gold), 300, "paid once")


func test_who_came_back() -> void:
	var st := _crown()
	assert_eq(SideQuestPlay.standing(st, "yester_hill_gulthias_tree", "yester_zorica"), "yester_hill/the_druid_who_came_back:zorica")
	st.minute_of_day = 12 * 60
	assert_eq(SideQuestPlay.standing(st, "yester_hill_gulthias_tree", "yester_zorica"), "", "only by night")
	st.minute_of_day = 22 * 60
	st.set_flag("kostin_doubts")
	assert_eq(SideQuestPlay.standing(st, "yester_hill_gulthias_tree", "kostin"), "yester_hill/the_druid_who_came_back:kostin")
	assert_eq(SideQuestPlay.standing(st, "yester_hill_gulthias_tree", "yester_zorica"), "")
	st.set_flag("yester_druids_fate", "spared")
	assert_eq(SideQuestPlay.standing(st, "yester_hill_gulthias_tree", "ruxandra"), "yester_hill/the_druid_who_came_back:ruxandra")
	assert_eq(SideQuestPlay.standing(st, "yester_hill_gulthias_tree", "kostin"), "")
	var beats := SideQuestPlay.play(st, "yester_hill/the_druid_who_came_back:ruxandra")
	assert_true(SideQuestPlay.text(beats).contains("The tree calls us back"))
	assert_eq(SideQuestPlay.combat_of(beats), "ash_effigy")
	assert_true(_has(SideQuestPlay.encounter(st, "yester_hill_gulthias_tree", "ash_effigy"), "Mother Ruxandra"))


func test_kostins_tree() -> void:
	var st := _crown()
	st.set_flag("kostin_doubts")
	var beats := SideQuestPlay.play(st, "yester_hill/the_druid_who_came_back:kostin", ["Look at the sapling"], 3)
	assert_true(SideQuestPlay.text(beats).contains("I brought one back"))
	beats = SideQuestPlay.play(st, "yester_hill/the_druid_who_came_back:kostin", ["Pull the sapling up"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("like a vein out of an arm"))
	assert_eq(st.quest_stage("the_druid_who_came_back"), "found")
	assert_eq(SideQuestPlay.combat_of(beats), "ash_effigy")
	var enc := SideQuestPlay.encounter(st, "yester_hill_gulthias_tree", "ash_effigy")
	assert_true(_has(enc, "ash_effigy") and not _has(enc, "druid"), "Kostin stands aside")
	st.set_flag("ash_effigy_slain")
	assert_eq(SideQuestPlay.standing(st, "yester_hill_gulthias_tree", "kostin"), "yester_hill/the_druid_who_came_back:kostin_after")
	beats = SideQuestPlay.play(st, "yester_hill/the_druid_who_came_back:kostin_after")
	assert_true(SideQuestPlay.text(beats).contains("Someone has to watch this hill"))


func test_zorica_talked_down_or_not() -> void:
	var st := _crown(7)
	var beats := SideQuestPlay.play(st, "yester_hill/the_druid_who_came_back:zorica", ["It drank your teacher"], 6)
	assert_eq(SideQuestPlay.combat_of(beats), "ash_effigy")
	assert_true(st.get_flag("zorica_asked", false), "one try")
	var enc := SideQuestPlay.encounter(st, "yester_hill_gulthias_tree", "ash_effigy")
	assert_eq(_has(enc, "Zorica"), not bool(st.get_flag("zorica_stood_down", false)), "she fights unless she put the spade down")
	var fresh := _crown(7)
	beats = SideQuestPlay.play(fresh, "yester_hill/the_druid_who_came_back:zorica", ["Pull the cutting up"])
	assert_true(_has(SideQuestPlay.encounter(fresh, "yester_hill_gulthias_tree", "ash_effigy"), "Zorica"))
