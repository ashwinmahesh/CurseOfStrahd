extends TestCase
## The Squire (docs/story/side_quests.md): the Vallaki gate's news and Sir Godfrey's, Cosmin on the squires' graves,
## Ioan's words on the last headstone, Godfrey remembering whom he sent, the vigil after dark, and Ioan's shield given
## once.

const SIX: Array[String] = ["godrick_pendlebrook", "thistle", "liriel_dawnsong", "ratatoille"]


func _holt(hour: int = 12) -> StoryState:
	var st := SideQuestPlay.party(SIX, 8, "argynvostholt", hour)
	st.set_flag("godfrey_met")
	return st


func test_the_graves_the_stone_the_vigil() -> void:
	var st := _holt()
	st.location = "vallaki"
	var beats := SideQuestPlay.play(st, "vallaki/gate:news")
	assert_true(SideQuestPlay.text(beats).contains("Cosmin"))
	st.location = "argynvostholt_upper"
	beats = SideQuestPlay.play(st, "argynvostholt/godfrey:start", ["Heard anything interesting?", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("the_squire"), "rumored")
	st.location = "argynvostholt"
	assert_eq(SideQuestPlay.standing(st, "argynvostholt", "argynvostholt_cosmin"), "argynvostholt/the_squire:cosmin")
	# The stone: try a few dice until someone reads it.
	var read := false
	for seed: int in [1, 2, 3, 5, 8]:
		beats = SideQuestPlay.play(st, "argynvostholt/the_squire:cosmin", ["Why do you want it", "Look at the last headstone", "Goodbye"], seed)
		if bool(st.get_flag("ioan_stone_read", false)):
			read = true
			assert_true(SideQuestPlay.text(beats).contains("I ride tonight with my lord's last word"))
			break
	assert_true(read, "some roll reads the stone")
	assert_eq(st.quest_stage("the_squire"), "met")
	assert_false(SideQuestPlay.text(SideQuestPlay.play(st, "argynvostholt/the_squire:cosmin")).contains("Stand the vigil"), "not before the truth, and not by day")
	# Godfrey remembers, with the stone to jog him.
	st.location = "argynvostholt_upper"
	beats = SideQuestPlay.play(st, "argynvostholt/godfrey:start", ["Do you remember a squire called Ioan?", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("I sent Ioan"))
	assert_eq(st.quest_stage("the_squire"), "truth")
	# The vigil.
	st.location = "argynvostholt"
	st.minute_of_day = 2 * 60
	beats = SideQuestPlay.play(st, "argynvostholt/the_squire:cosmin", ["Stand the vigil with him"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(SideQuestPlay.combat_of(beats), "squires_vigil")
	var enc := SideQuestPlay.encounter(st, "argynvostholt", "squires_vigil")
	assert_true(SideQuestPlay.has_foe(enc, "The Gate Warden"))
	assert_true(SideQuestPlay.xp(enc) >= 6800, "Moderate or more for level 8: %d" % SideQuestPlay.xp(enc))
	st.set_flag("squires_vigil_won")
	st.gold = 0
	beats = SideQuestPlay.play(st, "argynvostholt/the_squire:cosmin")
	assert_true(SideQuestPlay.text(beats).contains("stood the vigil. Squire."))
	assert_eq(st.quest_stage("the_squire"), "done")
	assert_eq(roundi(st.gold), 150)
	assert_true(st.party_has_item("arrow_catching_shield"))
	assert_eq(SideQuestPlay.standing(st, "argynvostholt", "argynvostholt_cosmin"), "argynvostholt/the_squire:cosmin")
	beats = SideQuestPlay.play(st, "argynvostholt/the_squire:cosmin")
	assert_true(SideQuestPlay.text(beats).contains("first living one"))
	assert_eq(roundi(st.gold), 150, "paid once")


func test_the_dragons_words_are_enough_for_godfrey() -> void:
	var st := _holt()
	st.location = "argynvostholt_upper"
	st.set_flag("cosmin_met")
	st.set_flag("vladimir_last_words_known")
	st.set_quest_stage("the_squire", "met")
	var beats := SideQuestPlay.play(st, "argynvostholt/godfrey:start", ["Do you remember a squire called Ioan?", "Goodbye"])
	assert_true(SideQuestPlay.text(beats).contains("Let them go home"))
	assert_true(bool(st.get_flag("ioan_cleared", false)))


func test_once_the_order_rests_there_is_no_boy() -> void:
	var st := _holt()
	st.set_flag("order_fate", "rest")
	assert_eq(SideQuestPlay.standing(st, "argynvostholt", "argynvostholt_cosmin"), "")
	st.location = "vallaki"
	var beats := SideQuestPlay.play(st, "vallaki/gate:news")
	assert_false(SideQuestPlay.text(beats).contains("Cosmin"))
