extends TestCase
## The Silver Hoard (docs/story/side_quests.md): Sir Godfrey on the Dragon's Tithe from level 9, the draught under the
## servants' table, the tithe-keeper on his chest (what Insight sees, and the dragon's last words), and the tithe chest:
## sent down to the valley, or kept.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "kip_smudgewick", "thistle"]
const HALL := "argynvostholt_hall"
const UNDERCROFT := "argynvostholt_undercroft"


func _exit_open(st: StoryState, location: String, exit_id: String) -> bool:
	for e: Variant in Compendium.shared().get_entry("locations", location)["exits"]:
		if str((e as Dictionary)["id"]) == exit_id:
			return StoryConditions.check(str((e as Dictionary).get("when", "")), st)
	return false


func test_godfrey_tells_of_the_dragons_tithe() -> void:
	var st := SideQuestPlay.party(FOUR, 8, "argynvostholt_upper", 20)
	st.set_flag("godfrey_met")
	var beats := SideQuestPlay.play(st, "argynvostholt/godfrey:menu", ["Where did he keep his hoard"])
	assert_ne(SideQuestPlay.missing(beats), "", "not before level 9")
	st = SideQuestPlay.party(FOUR, 9, "argynvostholt_upper", 20)
	st.set_flag("godfrey_met")
	assert_false(_exit_open(st, HALL, "stair_to_undercroft"))
	beats = SideQuestPlay.play(st, "argynvostholt/godfrey:menu", ["Where did he keep his hoard", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("The Dragon's Tithe"))
	assert_true(said.contains("I had his name a moment ago"))
	assert_eq(st.quest_stage("the_silver_hoard"), "asked")
	assert_true(_exit_open(st, HALL, "stair_to_undercroft"))


func test_a_draught_under_the_servants_table() -> void:
	var st := SideQuestPlay.party(FOUR, 8, HALL, 20)
	assert_false(SideQuestPlay.shown(st, HALL, "holt_tithe_draught"), "not before level 9")
	st = SideQuestPlay.party(FOUR, 9, HALL, 20)
	st.set_flag("order_fate", "rest")
	assert_true(SideQuestPlay.shown(st, HALL, "holt_tithe_draught"), "even with the knights at rest")
	var beats := SideQuestPlay.play(st, "argynvostholt/the_silver_hoard:draught")
	assert_true(SideQuestPlay.text(beats).contains("Somebody down there is counting"))
	assert_eq(st.quest_stage("the_silver_hoard"), "asked")
	assert_true(_exit_open(st, HALL, "stair_to_undercroft"))
	assert_false(SideQuestPlay.shown(st, HALL, "holt_tithe_draught"))


func test_the_tithe_keeper_wont_let_go() -> void:
	var st := SideQuestPlay.party(FOUR, 9, UNDERCROFT, 20)
	st.set_quest_stage("the_silver_hoard", "asked")
	assert_eq(SideQuestPlay.standing(st, UNDERCROFT, "gilded_knight"), "argynvostholt/the_silver_hoard:keeper")
	var beats := SideQuestPlay.play(st, "argynvostholt/the_silver_hoard:keeper", ["Godfrey sent us", "carry it down ourselves"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("Counted and sealed"))
	assert_true(said.contains("I'll not pay the count's people"))
	assert_eq(SideQuestPlay.combat_of(beats), "gilded_knight")
	var enc := SideQuestPlay.encounter(st, UNDERCROFT, "gilded_knight")
	assert_true(SideQuestPlay.has_foe(enc, "gilded_knight"))
	assert_true(SideQuestPlay.has_foe(enc, "An Escort's Harness"))
	beats = SideQuestPlay.play(st, "argynvostholt/the_silver_hoard:hands", ["carry it down ourselves"])
	assert_true(SideQuestPlay.text(beats).contains("cut nearly in two"))


func test_the_dragons_last_words() -> void:
	var st := SideQuestPlay.party(FOUR, 9, UNDERCROFT, 20)
	st.set_quest_stage("the_silver_hoard", "asked")
	var beats := SideQuestPlay.play(st, "argynvostholt/the_silver_hoard:keeper", ["Let them go home"])
	assert_ne(SideQuestPlay.missing(beats), "", "only with the dragon's words")
	st = SideQuestPlay.party(FOUR, 9, UNDERCROFT, 20)
	st.set_quest_stage("the_silver_hoard", "asked")
	st.set_flag("ioan_cleared")
	beats = SideQuestPlay.play(st, "argynvostholt/the_silver_hoard:keeper", ["Let them go home"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("You'll have to take it off me"))
	assert_true(st.get_flag("tithe_keeper_remembered", false))
	assert_eq(SideQuestPlay.combat_of(beats), "gilded_knight")
	var enc := SideQuestPlay.encounter(st, UNDERCROFT, "gilded_knight")
	assert_eq(int((enc["monsters"] as Array)[0].get("hp", 0)), 140, "he fights the silver, not you")


func test_sending_the_tithe_down_to_the_valley() -> void:
	var st := SideQuestPlay.party(FOUR, 9, UNDERCROFT, 20)
	st.set_quest_stage("the_silver_hoard", "fought")
	st.set_flag("gilded_knight_slain")
	st.set_flag("order_fate", "ride")
	st.gold = 0
	assert_eq(SideQuestPlay.standing(st, UNDERCROFT, "gilded_knight"), "")
	var beats := SideQuestPlay.play(st, "argynvostholt/the_silver_hoard:chest", ["Send it down"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("a little golden idol"))
	assert_true(said.contains("Leave the coins on the step anyway"))
	assert_eq(st.quest_stage("the_silver_hoard"), "delivered")
	assert_true(st.party_has_item("golden_idol_of_good_fortunes"))
	assert_eq(roundi(st.gold), 250)
	beats = SideQuestPlay.play(st, "argynvostholt/the_silver_hoard:chest")
	assert_true(SideQuestPlay.text(beats).contains("open and empty"))


func test_keeping_the_tithe() -> void:
	var st := SideQuestPlay.party(FOUR, 9, UNDERCROFT, 20)
	st.set_quest_stage("the_silver_hoard", "fought")
	st.set_flag("gilded_knight_slain")
	st.set_flag("order_fate", "rest")
	st.gold = 0
	var beats := SideQuestPlay.play(st, "argynvostholt/the_silver_hoard:chest", ["Keep it"])
	assert_true(SideQuestPlay.text(beats).contains("never seems to get any lighter"))
	assert_eq(st.quest_stage("the_silver_hoard"), "kept")
	assert_true(st.party_has_item("golden_idol_of_good_fortunes"))
	assert_eq(roundi(st.gold), 1200)
