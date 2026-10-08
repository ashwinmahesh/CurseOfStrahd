extends TestCase
## The Fourth Sister (docs/story/side_quests.md): Vasile and Petre's rumour, Mouse on the miller's lane, Goodwife
## Sarnov's first baby, the name given back, Granny Ash on the birthday night, and the three endings (home, the
## Keepers, or the basket).

const SIX: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]


## Six weeks after the mill: Morgantha dead, the Sarnov children home.
func _after_the_mill(hour: int = 10) -> StoryState:
	var st := SideQuestPlay.party(SIX, 6, "old_bonegrinder_track", hour)
	st.set_flag("morgantha_slain")
	st.set_flag("children_rescued")
	st.set_flag("bonegrinder_children_fate", "home")
	st.set_flag("bonegrinder_fate", "destroyed")
	return st


func test_the_rumour_the_name_and_the_way_home() -> void:
	var st := _after_the_mill()
	st.location = "village_of_barovia"
	var beats := SideQuestPlay.play(st, "village_of_barovia/townsfolk:gossip")
	assert_true(SideQuestPlay.text(beats).contains("her husband's eyes"))
	assert_eq(st.quest_stage("the_fourth_sister"), "rumored")
	# The lane by day.
	st.location = "old_bonegrinder_track"
	assert_eq(SideQuestPlay.standing(st, "old_bonegrinder_track", "bonegrinder_mouse"), "old_bonegrinder/the_fourth_sister:mouse")
	beats = SideQuestPlay.play(st, "old_bonegrinder/the_fourth_sister:mouse", ["Who are you?", "Heard anything interesting?", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Granny's coming"))
	assert_eq(st.quest_stage("the_fourth_sister"), "granny")
	assert_true(SideQuestPlay.shown(st, "old_bonegrinder_track", "mouse_hut"))
	# Her mother, on her step.
	st.location = "village_of_barovia"
	assert_eq(SideQuestPlay.standing(st, "village_of_barovia", "goodwife_sarnov"), "old_bonegrinder/the_fourth_sister:mother")
	beats = SideQuestPlay.play(st, "old_bonegrinder/the_fourth_sister:mother", ["There's a girl", "Tell us about the baby", "Tell her"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Ilka and Toma, home"))
	assert_true(bool(st.get_flag("mouse_name_known", false)))
	assert_true(bool(st.get_flag("sarnov_told", false)))
	st.location = "old_bonegrinder_track"
	beats = SideQuestPlay.play(st, "old_bonegrinder/the_fourth_sister:mouse", ["Show us your left wrist", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("mouse_named", false)))
	# The birthday night.
	st.minute_of_day = 23 * 60
	assert_eq(SideQuestPlay.standing(st, "old_bonegrinder_track", "bonegrinder_mouse"), "old_bonegrinder/the_fourth_sister:birthday")
	beats = SideQuestPlay.play(st, "old_bonegrinder/the_fourth_sister:birthday", ["Stand between them"])
	assert_eq(SideQuestPlay.missing(beats), "", "named, there's no calling her back to do")
	assert_true(SideQuestPlay.text(beats).contains("My name's Zamfira"))
	assert_eq(SideQuestPlay.combat_of(beats), "granny_ash")
	var enc := SideQuestPlay.encounter(st, "old_bonegrinder_track", "granny_ash")
	assert_true(SideQuestPlay.has_foe(enc, "granny_ash"))
	assert_true(SideQuestPlay.xp(enc) >= 4400, "High for level 6: %d" % SideQuestPlay.xp(enc))
	st.set_flag("granny_ash_slain")
	st.set_quest_stage("the_fourth_sister", "granny_slain")
	assert_eq(SideQuestPlay.standing(st, "old_bonegrinder_track", "bonegrinder_mouse"), "old_bonegrinder/the_fourth_sister:dawn")
	st.gold = 0
	beats = SideQuestPlay.play(st, "old_bonegrinder/the_fourth_sister:dawn")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("coming up the lane at a run"), "her mother knew, and came")
	assert_true(said.contains("Toma's ears"))
	assert_eq(str(st.get_flag("mouse_fate", "")), "home")
	assert_eq(st.quest_stage("the_fourth_sister"), "home")
	assert_eq(roundi(st.gold), 300)
	assert_true(st.party_has_item("robe_of_eyes"))
	assert_eq(SideQuestPlay.standing(st, "old_bonegrinder_track", "bonegrinder_mouse"), "", "gone from the lane")
	st.minute_of_day = 10 * 60
	assert_eq(SideQuestPlay.standing(st, "old_bonegrinder_track", "bonegrinder_mouse"), "")
	assert_eq(SideQuestPlay.standing(st, "village_of_barovia", "bonegrinder_mouse"), "old_bonegrinder/the_fourth_sister:zamfira")
	beats = SideQuestPlay.play(st, "old_bonegrinder/the_fourth_sister:mother")
	assert_true(SideQuestPlay.text(beats).contains("I've three again"))
	beats = SideQuestPlay.play(st, "village_of_barovia/townsfolk:gossip")
	assert_true(SideQuestPlay.text(beats).contains("three children again"))


func test_unnamed_she_can_still_choose_and_the_keepers_take_her() -> void:
	var stayed := false
	for seed: int in [1, 2, 3, 5, 8, 13]:
		var st := _after_the_mill(23)
		st.set_flag("mouse_met")
		st.set_quest_stage("the_fourth_sister", "granny")
		var beats := SideQuestPlay.play(st, "old_bonegrinder/the_fourth_sister:birthday",
			["You don't have to go to her", "Stand between them"], seed)
		assert_eq(SideQuestPlay.missing(beats), "")
		assert_eq(SideQuestPlay.combat_of(beats), "granny_ash")
		if bool(st.get_flag("mouse_stayed", false)):
			stayed = true
			st.set_flag("granny_ash_slain")
			st.set_quest_stage("the_fourth_sister", "granny_slain")
			beats = SideQuestPlay.play(st, "old_bonegrinder/the_fourth_sister:dawn")
			assert_true(SideQuestPlay.text(beats).contains("I chose you"))
			assert_eq(str(st.get_flag("mouse_fate", "")), "keepers")
			assert_eq(st.quest_stage("the_fourth_sister"), "keepers")
			assert_true(st.party_has_item("robe_of_eyes"))
			break
	assert_true(stayed, "some roll holds her")


func test_the_basket() -> void:
	var st := _after_the_mill(23)
	st.set_flag("mouse_met")
	st.set_quest_stage("the_fourth_sister", "granny")
	st.gold = 0
	var beats := SideQuestPlay.play(st, "old_bonegrinder/the_fourth_sister:birthday", ["Hear what Granny's offering", "Take the basket"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(SideQuestPlay.combat_of(beats), "", "no fight")
	assert_eq(str(st.get_flag("mouse_fate", "")), "given")
	assert_eq(st.quest_stage("the_fourth_sister"), "given")
	assert_eq(roundi(st.gold), 300)
	assert_false(st.party_has_item("robe_of_eyes"), "the robe was never on offer")
	assert_eq(SideQuestPlay.standing(st, "old_bonegrinder_track", "bonegrinder_mouse"), "")


func test_no_mouse_while_morgantha_lives() -> void:
	var st := SideQuestPlay.party(SIX, 6, "old_bonegrinder_track", 10)
	assert_eq(SideQuestPlay.standing(st, "old_bonegrinder_track", "bonegrinder_mouse"), "")
	st.location = "village_of_barovia"
	var beats := SideQuestPlay.play(st, "village_of_barovia/townsfolk:gossip")
	assert_false(SideQuestPlay.text(beats).contains("her husband's eyes"))
	assert_eq(st.quest_stage("the_fourth_sister"), "")
