extends TestCase
## Storyline QA (2026-10-12): the Wiki lane's third round of findings ("QA - Wiki Walkthrough Findings" in the vault,
## #81-#90), each played the way a party meets it. Finding 87, Kip's second reading, is in test_story_fixes_north.


## Finding 81: a frail Ilya couldn't be prayed over, and the prayer is what finishes his cure.
func test_a_cleric_finishes_a_frail_ilyas_cure() -> void:
	var st := SideQuestPlay.party(["liriel_dawnsong"], 6, "krezk_burgomasters_house", 12)
	st.set_quest_stage("the_burgomasters_son", "heard")
	st.set_flag("ilya_heard")
	st.set_flag("ilya_fate", "frail")
	st.set_quest_stage("the_burgomasters_son", "frail")
	var beats := SideQuestPlay.play(st, "krezk/anna:menu", ["Let me pray over him"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("the_burgomasters_son"), "healed")
	st.set_flag("ilya_fate", "healed")
	beats = SideQuestPlay.play(st, "krezk/anna:menu", ["Let me pray over him"])
	assert_ne(SideQuestPlay.missing(beats), "", "not once he's well")


## Finding 82: Cosmin, going home, says goodbye as he packs before he leaves the graves.
func test_cosmin_packs_before_he_goes() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 8, "argynvostholt", 12)
	st.set_quest_stage("the_squire", "met")
	st.set_quest_stage("the_squire", "gone_home")
	assert_eq(SideQuestPlay.standing(st, "argynvostholt", "argynvostholt_cosmin"), "argynvostholt/the_squire:cosmin", "still at the graves")
	var said := SideQuestPlay.text(SideQuestPlay.play(st, "argynvostholt/the_squire:cosmin"))
	assert_true(said.contains("He's packing the horse blanket"), said)
	assert_eq(SideQuestPlay.standing(st, "argynvostholt", "argynvostholt_cosmin"), "", "and then gone")


## Finding 83: Argynvost asked for his skull home, and nothing took it there.
func test_argynvosts_skull_goes_home() -> void:
	var st := SideQuestPlay.party(["godrick_pendlebrook"], 9, "castle_ravenloft_court", 12)
	st.set_flag("argynvost_skull_known")
	var beats := SideQuestPlay.play(st, "castle_ravenloft/court_skull:skull", ["Lift it down"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("argynvost_skull_taken", false)))
	st.set_flag("dragon_fire_kindled")
	st.set_flag("argynvost_beacon_lit")
	st.location = "argynvostholt_mausoleum"
	beats = SideQuestPlay.play(st, "argynvostholt/mausoleum:bones", ["Lay his skull"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("argynvost_skull_home", false)))
	assert_true(SideQuestPlay.text(beats).contains("isn't going out again"))
	var slides := Endings.slides(Endings.get_ending("strahd_destroyed"), st)
	assert_true(slides.any(func(sl: Dictionary) -> bool: return str(sl["text"]).contains("bones lie whole again")),
		"the epilogue remembers")


## Findings 84, 88, 89: at the beacon Godfrey takes the sword from Godrick's hands, a Close Godrick names his
## fellowship, and when the cards named Godfrey he doesn't climb the stair a second time.
func test_the_beacon_knighting_with_a_fellowship() -> void:
	var st := SideQuestPlay.party(["godrick_pendlebrook"], 8, "argynvostholt_beacon", 22)
	st.set_quest_stage("the_ladle", "kept_faith")
	for f: String in ["godfrey_met", "ladle_sword_shown"]:
		st.set_flag(f)
	st.approval["godrick_pendlebrook"] = {"score": 30, "memories": []}
	st.tarokka = {"ally": "ghost"}   # Sir Godfrey
	var beats := SideQuestPlay.play(st, "argynvostholt/beacon:godfrey_check", ["Ride with us"])
	var said := SideQuestPlay.text(beats)
	assert_eq(st.quest_stage("the_ladle"), "knighted")
	assert_true(said.contains("takes Sir Aldric's sword from Godrick's hands"), said)
	assert_false(said.contains("across his arms"))
	assert_true(said.contains("names his fellowship"), "Close: the fellowship")
	assert_true(st.party_has_item("weapon_plus_2"))
	assert_false(said.contains("Steps on the stair"), "he's up here already")
	assert_true("sir_godfrey_gwilym" in st.guest_ids, "and rides with the party")


## Finding 85: freeing Dragos after the Rag Queen burned still had him beg the party to burn it.
func test_dragos_thanks_a_party_that_already_burned_the_queen() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 7, "krezk", 12)
	st.set_flag("rag_queen_beaten")
	var said := SideQuestPlay.text(SideQuestPlay.play(st, "krezk/one_horned_billy:freed"))
	assert_false(said.contains("Burn it. Please."), said)
	assert_true(said.contains("You burned it. You let her out."), said)
	assert_true(bool(st.get_flag("rag_queen_paid", false)))


## Finding 90: with the Abbot's fate settled before Liriel heard of the bride, The Fall could never come.
func test_liriel_reaches_the_fall_after_the_wedding() -> void:
	var st := SideQuestPlay.party(["liriel_dawnsong"], 7, "abbey_of_st_markovia_chapel", 12)
	st.set_quest_stage("carry_the_dawn", "the_angel")
	st.set_flag("abbot_met")
	st.set_flag("abbot_bride_revealed")
	st.set_flag("abbot_fate", "wedding")
	SideQuestPlay.play(st, "abbey_of_st_markovia/abbot:start")
	assert_eq(st.quest_stage("carry_the_dawn"), "the_fall")
	var away := SideQuestPlay.party(["liriel_dawnsong"], 7, "krezk", 22)
	away.set_quest_stage("carry_the_dawn", "the_angel")
	away.set_flag("abbot_fate", "slain")
	var cond := CampTalk.opening_condition(DialogueFile.load_key("camp/liriel"), "talk_faith")
	assert_true(StoryConditions.check(cond, away), "her talk after his fate, wherever she learned of it: %s" % cond)


## Finding 87, wider: any camp node that opened with an `if` was offered as a talk, so Kip's settling-up (and Hedda's,
## Liriel's, Tamsin's, Thistle's and Wren's quest endings) came up at the first rest as "Someone wants a word".
func test_only_talks_are_offered_at_camp() -> void:
	var st := SideQuestPlay.party(["ilse_varga", "kip_smudgewick"], 1, "village_of_barovia", 22)
	for talk in CampTalk.available(st):
		assert_true(str(talk["ref"]).get_slice(":", 1).begins_with("talk_"), "%s isn't a talk" % talk["ref"])
	st.quests.clear()
	var refs := CampTalk.available(st).map(func(t: Dictionary) -> String: return str(t["ref"]))
	assert_false("camp/kip:settle" in refs, str(refs))
