extends TestCase
## NPC depth, batch 4c (docs/plans/npc_depth_and_quests.md): Granny Ash's riddles in The Fourth Sister (a way past the
## fight that a lost game gives back), and the rescued Vadu children in Krezk.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "ratatoille", "thistle"]
const S := "old_bonegrinder/the_fourth_sister:"
const K := "krezk/"


func _st(location: String = "old_bonegrinder_track", level: int = 7) -> StoryState:
	return SideQuestPlay.party(FOUR, level, location, 23)


func test_riddles_won_with_the_name_leave_the_old_way_unneeded() -> void:
	var st := _st()
	st.set_quest_stage("the_fourth_sister", "granny")
	st.set_flag("mouse_named")
	var gold := st.gold
	# One right (the river), one wrong, and the name: two of three.
	var beats := SideQuestPlay.play(st, S + "riddle_offer", ["A river", "A shadow", "Zamfira"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(SideQuestPlay.combat_of(beats), "")
	assert_eq(str(st.get_flag("mouse_fate", "")), "home")
	assert_eq(st.quest_stage("the_fourth_sister"), "home")
	assert_eq(st.gold, gold + 300.0, "Granny's basket is the forfeit")
	assert_true(SideQuestPlay.text(beats).contains("little Zamfira"))


func test_riddles_won_without_the_name_leave_her_with_the_keepers() -> void:
	var st := _st()
	st.set_quest_stage("the_fourth_sister", "granny")
	var beats := SideQuestPlay.play(st, S + "riddle_offer", ["A river", "An echo", "A pastry"])
	assert_eq(SideQuestPlay.combat_of(beats), "")
	assert_eq(str(st.get_flag("mouse_fate", "")), "keepers")
	assert_true(SideQuestPlay.text(beats).contains("little Mousie"), "she never learned the name Granny ate")


func test_riddles_lost_are_the_old_fight_and_never_a_dead_end() -> void:
	var st := _st()
	st.set_quest_stage("the_fourth_sister", "granny")
	st.set_flag("mouse_named")
	var beats := SideQuestPlay.play(st, S + "riddle_offer", ["A road", "A shadow", "Zamfira"])
	assert_eq(SideQuestPlay.combat_of(beats), "granny_ash", "one right of three: the old way")
	beats = SideQuestPlay.play(st, S + "riddle_offer", ["A road", "An echo", "A name"])
	assert_eq(SideQuestPlay.combat_of(beats), "granny_ash")
	# And the old options are still there beside the riddle option.
	var opts := SideQuestPlay.play(st, S + "offer", ["Take the basket"])
	assert_eq(SideQuestPlay.missing(opts), "")
	assert_eq(str(st.get_flag("mouse_fate", "")), "given")


func test_the_rescued_children_stand_in_krezk_by_day() -> void:
	var st := SideQuestPlay.party(FOUR, 7, "krezk", 11)
	assert_eq(SideQuestPlay.standing(st, "krezk", "ioana"), "", "not until the pack's children are free")
	st.set_flag("den_children_freed")
	for pair: Array in [["ioana", "ioana"], ["zamfir", "zamfir"], ["codruta", "codruta"]]:
		assert_eq(SideQuestPlay.standing(st, "krezk", str(pair[0])), K + "vadu_children:" + str(pair[1]))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, K + "vadu_children:ioana", ["Who cried"])).contains("loud lungs"))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, K + "vadu_children:zamfir", ["Ioana says"])).contains("It was me"), "the lie, kept between them")
	var beats := SideQuestPlay.play(st, K + "vadu_children:codruta", ["Where did you lose her"])
	assert_true(SideQuestPlay.text(beats).contains("gorse root"))
	st.set_flag("den_doll_found")
	beats = SideQuestPlay.play(st, K + "vadu_children:codruta", ["found your doll"])
	assert_true(st.get_flag("ana_doll_returned", false))
	assert_true(SideQuestPlay.text(beats).contains("rag doll"))
