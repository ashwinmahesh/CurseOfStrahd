extends TestCase
## Two companion quests that could never finish (Side Quest Failure Plan, Part A; docs/story/personal_quests.md):
## Godrick's A Knight, More or Less once the beacon had lit without Sir Godfrey's accolade, and Wren's The Last Lesson
## once Rahadin was dead before Wren's scene. Each now closes as a failure in a camp talk, and only then.

const SIX: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille", "wren_featherfoot",
	"kip_smudgewick"]
const BEACON := "argynvostholt_beacon"
const UPPER := "argynvostholt_upper"
const COURT := "castle_ravenloft_court"


func _party(location: String) -> StoryState:
	return SideQuestPlay.party(SIX, 9, location, 22)


## A camp file's talks before `talk` count as had, so the next one it offers is the one under test.
func _mark_before(st: StoryState, file: String, talk: String) -> void:
	for node in DialogueFile.load_key("camp/" + file).order:
		if node == talk:
			return
		if node.begins_with("talk_"):
			CampTalk.mark(st, "camp/%s:%s" % [file, node])


func _offered(st: StoryState, file: String) -> String:
	return str(CampTalk.offered(DialogueFile.load_key("camp/" + file), st).get("ref", ""))


func _ends(quest: String, stage: String) -> String:
	for s: Variant in Compendium.shared().get_entry("quests", quest)["stages"]:
		if str((s as Dictionary)["id"]) == stage:
			return str((s as Dictionary).get("ends", ""))
	return "no such stage"


# --- A Knight, More or Less ------------------------------------------------------------------------------------------

## The beacon only knights Godrick if Godfrey saw the sword (beacon:godfrey_check). Lit before that, the Order goes home
## and Godfrey with it: his room is empty and nothing else in the story could finish the quest.
func _lit_without_the_sword(stage: String = "the_errand") -> StoryState:
	var st := _party(BEACON)
	st.set_quest_stage("the_ladle", stage)
	st.set_flag("godfrey_met")
	st.set_flag("argynvost_beacon_lit")
	st.set_flag("order_fate", "rest")
	SideQuestPlay.play(st, "argynvostholt/beacon:godfrey_check")
	return st


func test_the_beacon_before_the_sword_strands_the_ladle() -> void:
	var st := _lit_without_the_sword()
	assert_eq(st.quest_stage("the_ladle"), "the_errand", "no accolade at the beacon")
	assert_eq(SideQuestPlay.standing(st, UPPER, "sir_godfrey_gwilym"), "", "and Godfrey is gone from his room")
	assert_eq(SideQuestPlay.standing(st, "argynvostholt", "sir_godfrey_gwilym"), "", "and from the steps")


func test_godrick_is_unknighted_in_a_camp_talk() -> void:
	for stage: String in ["the_errand", "the_order_found", "the_deserter", "kept_faith"]:
		var st := _lit_without_the_sword(stage)
		assert_true(DialogueFile.load_key("camp/godrick").nodes.has("talk_unknighted"), "the talk exists")
		_mark_before(st, "godrick", "talk_unknighted")
		assert_eq(_offered(st, "godrick"), "camp/godrick:talk_unknighted", "offered from %s" % stage)
		var beats := SideQuestPlay.play(st, "camp/godrick:talk_unknighted")
		assert_eq(SideQuestPlay.missing(beats), "")
		assert_eq(st.quest_stage("the_ladle"), "unknighted", stage)
		assert_true(st.quest_ended("the_ladle"))
		CampTalk.mark(st, "camp/godrick:talk_unknighted")
		assert_ne(_offered(st, "godrick"), "camp/godrick:talk_unknighted", "it plays once")
		assert_ne(_offered(st, "godrick"), "camp/godrick:talk_knighted", "and he isn't treated as knighted")


func test_unknighted_is_a_failure_that_does_not_read_as_knighted() -> void:
	assert_eq(_ends("the_ladle", "unknighted"), "failure")
	assert_eq(_ends("the_ladle", "knighted"), "success")
	var st := _party(BEACON)
	st.set_quest_stage("the_ladle", "kept_faith")
	st.set_quest_stage("the_ladle", "unknighted")
	# Strahd's dinner talk and the party's morning banter read `>= knighted` for "Sir Godrick, of the Order".
	assert_false(StoryConditions.check("quest.the_ladle >= knighted", st))
	assert_false(StoryConditions.check("quest.the_ladle == knighted", st))
	assert_true(StoryConditions.check("quest.the_ladle == unknighted", st))
	# A later accolade (Godfrey still travelling with the party) can still finish it.
	SideQuestPlay.play(st, "companions/ladle:knighting")
	assert_eq(st.quest_stage("the_ladle"), "knighted")


func test_godrick_is_not_unknighted_while_godfrey_can_still_knight_him() -> void:
	var talk := "camp/godrick:talk_unknighted"
	var cond := CampTalk.opening_condition(DialogueFile.load_key("camp/godrick"), "talk_unknighted")
	assert_ne(cond, "", "the talk opens with a condition")
	var base := func() -> StoryState:
		var st := _party(BEACON)
		st.set_quest_stage("the_ladle", "the_deserter")
		st.set_flag("argynvost_beacon_lit")
		_mark_before(st, "godrick", "talk_unknighted")
		return st
	var st: StoryState = base.call()
	assert_eq(_offered(st, "godrick"), talk, "the plain case holds")
	st = base.call()
	st.flags.erase("argynvost_beacon_lit")
	assert_ne(_offered(st, "godrick"), talk, "the beacon is dark: Godfrey is in his room")
	st = base.call()
	st.guest_ids.append("sir_godfrey_gwilym")
	assert_ne(_offered(st, "godrick"), talk, "Godfrey travels with the party")
	st = base.call()
	st.set_quest_stage("the_ladle", "knighted")
	assert_ne(_offered(st, "godrick"), talk, "already knighted")
	st = base.call()
	st.set_quest_stage("the_ladle", "unknighted")
	assert_ne(_offered(st, "godrick"), talk, "already unknighted")
	st = base.call()
	st.quests.erase("the_ladle")
	assert_ne(_offered(st, "godrick"), talk, "the quest never began")
	var away := SideQuestPlay.party(["liriel_dawnsong", "thistle"], 9, BEACON, 22)
	away.set_quest_stage("the_ladle", "the_deserter")
	away.set_flag("argynvost_beacon_lit")
	assert_false(StoryConditions.check(cond, away), "no Godrick, no talk")


func test_the_beacon_still_knights_godrick_when_godfrey_saw_the_sword() -> void:
	var st := _party(BEACON)
	st.set_quest_stage("the_ladle", "the_order_found")
	for f: String in ["godfrey_met", "ladle_sword_shown", "argynvost_beacon_lit"]:
		st.set_flag(f)
	SideQuestPlay.play(st, "argynvostholt/beacon:godfrey_check")
	assert_eq(st.quest_stage("the_ladle"), "knighted")
	_mark_before(st, "godrick", "talk_unknighted")
	assert_ne(_offered(st, "godrick"), "camp/godrick:talk_unknighted")


func test_godrick_stops_asking_about_the_orders_books_once_it_has_gone_home() -> void:
	# His reading talk is about the Order's oaths written down: it waits for an Order that is still there.
	var cond := CampTalk.opening_condition(DialogueFile.load_key("camp/godrick"), "talk_letters")
	var st := _party(BEACON)
	st.set_quest_stage("the_ladle", "the_deserter")
	assert_true(StoryConditions.check(cond, st), "while the Order is there to be asked")
	st.set_quest_stage("the_ladle", "unknighted")
	assert_false(StoryConditions.check(cond, st), "not after it has gone home without him")
