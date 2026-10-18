extends TestCase
## Escher's Petition (docs/story/side_quests.md): the petition in Escher's pocket from level 10, the rest of the
## count's answer under Insight, Escher at the south tower parapet by night and Querreth's fight, the dawn and both of
## its endings, and where Escher stands afterwards.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "wren_featherfoot", "thistle"]
const SUITE := "castle_ravenloft_spires_rooms"
const ROOFS := "castle_ravenloft_spires_roofs"


func test_escher_shows_his_petition_from_level_10() -> void:
	var st := SideQuestPlay.party(FOUR, 9, SUITE, 22)
	st.set_flag("escher_met")
	var beats := SideQuestPlay.play(st, "castle_ravenloft/spires_escher:start", ["What's that paper"])
	assert_ne(SideQuestPlay.missing(beats), "", "not before level 10")
	st = SideQuestPlay.party(FOUR, 10, SUITE, 22)
	st.set_flag("escher_met")
	assert_eq(SideQuestPlay.standing(st, ROOFS, "escher"), "", "not on the roof before he asks")
	beats = SideQuestPlay.play(st, "castle_ravenloft/spires_escher:start", ["What's that paper", "We'll come"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("Let me see the sun"))
	assert_true(said.contains("I've been early for nine years"))
	assert_eq(st.quest_stage("escher_petition"), "asked")
	# By night he's up at the parapet, not in his chair; by day he's in his chair, waiting.
	assert_eq(SideQuestPlay.standing(st, ROOFS, "escher"), "castle_ravenloft/escher_petition:roof")
	assert_eq(SideQuestPlay.standing(st, SUITE, "escher"), "")
	st.minute_of_day = 12 * 60
	assert_eq(SideQuestPlay.standing(st, ROOFS, "escher"), "")
	assert_eq(SideQuestPlay.standing(st, SUITE, "escher"), "castle_ravenloft/spires_escher:start")
	beats = SideQuestPlay.play(st, "castle_ravenloft/spires_escher:start", ["Goodbye"])
	assert_true(SideQuestPlay.text(beats).contains("in the good coat"))


func test_the_rest_of_the_answer() -> void:
	var st := SideQuestPlay.party(FOUR, 10, SUITE, 22)
	st.set_flag("escher_met")
	var beats := SideQuestPlay.play(st, "castle_ravenloft/escher_petition:note", ["We'll come anyway"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Bring your friends"))
	assert_true(st.get_flag("escher_note_read", false))
	assert_eq(st.quest_stage("escher_petition"), "asked")
	assert_eq(str(SideQuestPlay.encounter(st, ROOFS, "querreth").get("surprise", "")), "", "forewarned")


func test_querreth_comes_down_off_the_keep() -> void:
	var st := SideQuestPlay.party(FOUR, 10, ROOFS, 22)
	st.set_flag("escher_met")
	st.set_quest_stage("escher_petition", "asked")
	var beats := SideQuestPlay.play(st, "castle_ravenloft/escher_petition:roof")
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("I put on the good coat anyway"))
	assert_true(said.contains("The master grants the petition"))
	assert_eq(SideQuestPlay.combat_of(beats), "querreth")
	var enc := SideQuestPlay.encounter(st, ROOFS, "querreth")
	assert_true(SideQuestPlay.has_foe(enc, "querreth"))
	assert_true(SideQuestPlay.has_foe(enc, "One Who Asked"))
	assert_eq(str(enc.get("surprise", "")), "party", "caught unawares without the rest of the note")


func test_he_watches_the_sun_come_up() -> void:
	var st := SideQuestPlay.party(FOUR, 10, ROOFS, 22)
	st.set_flag("escher_met")
	st.set_quest_stage("escher_petition", "held")
	st.gold = 0
	assert_eq(SideQuestPlay.standing(st, ROOFS, "escher"), "castle_ravenloft/escher_petition:roof")
	var beats := SideQuestPlay.play(st, "castle_ravenloft/escher_petition:roof", ["Stand with him"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("I'd forgotten it was that colour"))
	assert_true(said.contains("Tell him it was worth it"))
	assert_eq(st.quest_stage("escher_petition"), "done")
	assert_true(st.get_flag("escher_saw_dawn", false))
	assert_true(st.party_has_item("helm_of_brilliance"))
	assert_eq(roundi(st.gold), 250)
	assert_eq(st.minute_of_day / 60, 6, "the dawn")
	assert_eq(SideQuestPlay.standing(st, ROOFS, "escher"), "")
	assert_eq(SideQuestPlay.standing(st, SUITE, "escher"), "", "gone from his chair")


func test_he_waits_for_a_dawn_the_count_isnt_in() -> void:
	var st := SideQuestPlay.party(FOUR, 10, ROOFS, 5)
	st.set_flag("escher_met")
	st.set_quest_stage("escher_petition", "held")
	st.gold = 0
	var beats := SideQuestPlay.play(st, "castle_ravenloft/escher_petition:wait")
	assert_true(SideQuestPlay.text(beats).contains("You do know how to sell a thing"))
	assert_eq(st.quest_stage("escher_petition"), "waited")
	assert_true(st.party_has_item("helm_of_brilliance"))
	assert_eq(roundi(st.gold), 250)
	st.minute_of_day = 12 * 60
	assert_eq(SideQuestPlay.standing(st, SUITE, "escher"), "castle_ravenloft/spires_escher:start")
	beats = SideQuestPlay.play(st, "castle_ravenloft/spires_escher:start", ["Goodbye"])
	assert_true(SideQuestPlay.text(beats).contains("dawn-sellers"))


## Stuck state (Side Quest Failure Plan, Part A): turning on Escher after agreeing to the petition left the quest open
## and a copy of him waiting on the roof at night. The petition now ends the moment the party draws steel on him.
func test_drawing_steel_on_escher_ends_the_petition() -> void:
	for stage: String in ["asked", "held"]:
		var st := SideQuestPlay.party(FOUR, 10, SUITE, 12)
		st.set_flag("escher_met")
		st.set_quest_stage("escher_petition", stage)
		var beats := SideQuestPlay.play(st, "castle_ravenloft/spires_escher:attack")
		assert_eq(SideQuestPlay.combat_of(beats), "escher_fight", stage)
		assert_eq(st.quest_stage("escher_petition"), "refused", "the %s petition ends with the fight" % stage)
		assert_true(st.quest_ended("escher_petition"))
		st.set_flag("escher_fight_won")
		st.minute_of_day = 22 * 60
		assert_eq(SideQuestPlay.standing(st, ROOFS, "escher"), "", "nobody waits on the roof for a petition that is over")
		assert_eq(SideQuestPlay.standing(st, SUITE, "escher"), "", "and he is not in his chair")


func test_threatening_escher_after_agreeing_ends_the_petition() -> void:
	var st := SideQuestPlay.party(FOUR, 10, SUITE, 12)
	st.set_flag("escher_met")
	st.set_quest_stage("escher_petition", "asked")
	var beats := SideQuestPlay.play(st, "castle_ravenloft/spires_escher:scared")
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("escher_petition"), "refused")
	assert_eq(st.attitude("escher"), "hostile")
	assert_true(bool(st.get_flag("escher_heart_told", false)), "he still tells them about the heart")
	st.minute_of_day = 22 * 60
	assert_eq(SideQuestPlay.standing(st, ROOFS, "escher"), "", "the roof is off")
	assert_eq(SideQuestPlay.standing(st, SUITE, "escher"), "castle_ravenloft/spires_escher:start", "he is back in his chair, cold")


func test_a_refused_petition_is_a_failure_and_cannot_be_asked_again() -> void:
	var quest := Compendium.shared().get_entry("quests", "escher_petition")
	var stages := {}
	for s: Variant in quest["stages"]:
		stages[str((s as Dictionary)["id"])] = s
	assert_true(stages.has("refused"))
	assert_eq(str((stages.get("refused", {}) as Dictionary).get("ends", "")), "failure")
	var st := SideQuestPlay.party(FOUR, 10, SUITE, 12)
	st.set_flag("escher_met")
	st.set_quest_stage("escher_petition", "refused")
	st.set_flag("escher_threatened")
	st.attitudes["escher"] = "hostile"
	var beats := SideQuestPlay.play(st, "castle_ravenloft/spires_escher:start", ["Leave him to sulk"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_false(SideQuestPlay.text(beats).contains("What's that paper"), "no second petition")
	assert_eq(st.quest_stage("escher_petition"), "refused")


func test_turning_on_escher_leaves_a_finished_petition_alone() -> void:
	# Escher waiting in his suite after the party talked him into a later dawn (success) stays a success.
	var st := SideQuestPlay.party(FOUR, 10, SUITE, 12)
	st.set_flag("escher_met")
	st.set_quest_stage("escher_petition", "waited")
	SideQuestPlay.play(st, "castle_ravenloft/spires_escher:attack")
	assert_eq(st.quest_stage("escher_petition"), "waited")
	# And with no petition at all, nothing is started.
	var fresh := SideQuestPlay.party(FOUR, 10, SUITE, 12)
	fresh.set_flag("escher_met")
	SideQuestPlay.play(fresh, "castle_ravenloft/spires_escher:attack")
	assert_eq(fresh.quest_stage("escher_petition"), "")
