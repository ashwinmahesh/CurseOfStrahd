extends TestCase
## NPC depth, batch 5 (docs/plans/npc_depth_and_quests.md): Argynvostholt, the Tsolenka watch and the Amber Temple. The Squire's
## hearing (a way past the vigil that a lost vote gives back), Sir Ottokar the Late, the Phantom Warden and Watchman, and
## Exethanter's Notes (a gentle puzzle with an Investigation shortcut and no penalty).

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "ratatoille", "thistle"]
const A := "argynvostholt/"


func _st(location: String = "argynvostholt", hour: int = 11, level: int = 8) -> StoryState:
	return SideQuestPlay.party(FOUR, level, location, hour)


func test_the_squire_wins_his_hearing_on_the_evidence_alone() -> void:
	var st := _st()
	st.set_quest_stage("the_squire", "truth")
	st.set_flag("ioan_stone_read")
	st.set_flag("vladimir_last_words_known")
	var gold := st.gold
	var beats := SideQuestPlay.play(st, A + "the_squire:cosmin", ["hear Ioan's case", "Read the words", "dragon's last words", "Ask Sir Godfrey", "That is all"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(SideQuestPlay.combat_of(beats), "", "no fight")
	assert_eq(int(st.get_flag("hearing_votes", 0)), 3)
	assert_eq(st.quest_stage("the_squire"), "done")
	assert_eq(st.gold, gold + 150.0, "the same reward as the vigil")
	assert_true(SideQuestPlay.text(beats).contains("Did I miss it?"), "Sir Ottokar rides in as the vote is called")


func test_a_lost_hearing_gives_the_vigil_back() -> void:
	var st := _st("argynvostholt", 22)
	st.set_quest_stage("the_squire", "truth")
	var beats := SideQuestPlay.play(st, A + "the_squire:cosmin", ["hear Ioan's case", "Ask Sir Godfrey", "That is all"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("the_squire"), "truth", "one vote of three: the table is not moved")
	assert_true(st.get_flag("hearing_held", false))
	assert_eq(SideQuestPlay.combat_of(SideQuestPlay.play(st, A + "the_squire:vigil")), "squires_vigil", "and the night's vigil is still open")
	# One hearing, not a way to keep asking.
	var again := SideQuestPlay.play(st, A + "the_squire:cosmin", ["hear Ioan's case"])
	assert_ne(SideQuestPlay.missing(again), "")


func test_the_hearing_votes_count_each_proof_once() -> void:
	var st := _st()
	st.set_quest_stage("the_squire", "truth")
	st.set_flag("hearing_votes", 2)
	assert_eq(SideQuestPlay.combat_of(SideQuestPlay.play(st, A + "the_squire:hearing_vote")), "")
	assert_eq(st.quest_stage("the_squire"), "truth", "two is not three")
	st.set_flag("hearing_votes", 3)
	SideQuestPlay.play(st, A + "the_squire:hearing_vote")
	assert_eq(st.quest_stage("the_squire"), "done")


func test_sir_ottokar_turns_up_after_every_fight_and_asks_if_he_missed_it() -> void:
	var st := _st()
	assert_eq(SideQuestPlay.standing(st, "argynvostholt", "sir_ottokar"), "", "he is late: nobody yet")
	st.set_flag("courtyard_phantoms_defeated")
	assert_eq(SideQuestPlay.standing(st, "argynvostholt", "sir_ottokar"), A + "ottokar:start")
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, A + "ottokar:start", ["Farewell"])).contains("Did I miss it?"))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, A + "ottokar:start", ["Farewell"])).contains("Did I miss it"), "and again")
	assert_ne(SideQuestPlay.missing(SideQuestPlay.play(st, A + "ottokar:start", ["farmer"])), "")
	SideQuestPlay.play(st, A + "ottokar:start", ["What do you want"])
	assert_true(st.get_flag("ottokar_wanted", false))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, A + "ottokar:secret_ok")).contains("farmer's wife"))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, A + "ottokar:secret_miss")).length() > 10, "a missed roll still gets an answer")
	st.set_flag("order_fate", "rest")
	assert_eq(SideQuestPlay.standing(st, "argynvostholt", "sir_ottokar"), "", "he goes with the Order once it rests")


func test_the_warden_and_the_watchman_have_a_secret_apiece() -> void:
	var st := _st("argynvostholt_mausoleum", 11)
	var text := SideQuestPlay.text(SideQuestPlay.play(st, A + "mausoleum:warden", ["keep this door"]))
	assert_true(text.contains("third watch"))
	assert_true(st.get_flag("warden_why_heard", false))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, A + "mausoleum:warden_secret_ok")).contains("herald"))
	assert_true(st.get_flag("warden_secret_known", false))
	var w := _st("tsolenka_pass_guard_tower", 11)
	SideQuestPlay.play(w, "tsolenka_pass/watch:watchman", ["any word at all"])
	assert_true(w.get_flag("watchman_nodded", false))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(w, "tsolenka_pass/watch:watchman", ["Press him"])).contains("winter bird"))


func test_exethanters_notes_in_order_and_with_wrong_guesses_on_the_way() -> void:
	var st := _st("amber_temple_entrance", 11, 10)
	var beats := SideQuestPlay.play(st, "amber_temple/exethanter:menu", ["doing this morning", "The scrap about the well", "small word of kindling", "grey tin", "waiting for the whistle"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("exethanters_notes"), "done")
	assert_true(SideQuestPlay.text(beats).contains("Tea. I was making tea."))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, "amber_temple/exethanter:menu", ["kettle still warm"])).contains("left cuff"))
	# Wrong scraps only earn a mild correction and the same step again.
	var w := _st("amber_temple_entrance", 11, 10)
	beats = SideQuestPlay.play(w, "amber_temple/exethanters_notes:step_1", ["waiting for the whistle", "pouring", "The scrap about the well", "pouring", "small word of kindling", "grey tin", "waiting for the whistle"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(w.quest_stage("exethanters_notes"), "done", "any order of trying ends the same way")
