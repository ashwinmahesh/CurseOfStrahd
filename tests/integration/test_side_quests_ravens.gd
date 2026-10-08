extends TestCase
## The Ravens' Ransom (docs/story/side_quests.md): Urwin's quiet news once the party knows what the Martikovs are, the
## cage on the hill trail, the fowlers (ready or not), the marks on Bray's wrist, the two ways to clear them, and Urwin's
## thanks paid once. Beating the fowlers is a mark on Strahd's attention.

const SIX: Array[String] = ["liriel_dawnsong", "thistle", "godrick_pendlebrook", "ratatoille"]


func _inn() -> StoryState:
	var st := SideQuestPlay.party(SIX, 6, "vallaki_blue_water_inn", 12)
	st.set_flag("martikovs_met")
	st.set_flag("danika_met")
	return st


func test_no_news_until_the_keepers_are_known() -> void:
	var st := _inn()
	SideQuestPlay.play(st, "vallaki/martikovs:urwin", ["Heard anything interesting?", "Goodbye"])
	assert_eq(st.quest_stage("the_ravens_ransom"), "")


func test_the_cage_the_fowlers_and_bray_cleared_on_the_trail() -> void:
	var st := _inn()
	st.set_flag("keepers_of_the_feather_met")
	var beats := SideQuestPlay.play(st, "vallaki/martikovs:urwin", ["Heard anything interesting?", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Bray didn't come home"))
	assert_eq(st.quest_stage("the_ravens_ransom"), "asked")
	beats = SideQuestPlay.play(st, "vallaki/martikovs:danika", ["About Bray"])
	assert_true(SideQuestPlay.text(beats).contains("Then I'll feed him"))
	st.location = "lake_zarovich_trail"
	st.minute_of_day = 22 * 60
	assert_true(SideQuestPlay.shown(st, "lake_zarovich_trail", "raven_cage"))
	beats = SideQuestPlay.play(st, "vallaki/the_ravens_ransom:cage", ["Walk up and open the cage"])
	assert_eq(SideQuestPlay.combat_of(beats), "raven_trap")
	var enc := SideQuestPlay.encounter(st, "lake_zarovich_trail", "raven_trap")
	assert_eq(str(enc["surprise"]), "party", "walking straight up, the fowlers have the jump")
	assert_true(SideQuestPlay.has_foe(enc, "The Count's Fowler"))
	st.set_flag("fowlers_slain")
	assert_true(StoryConditions.check("attention >= 1", st), "the castle marks whoever killed its fowlers")
	# Liriel (leader) knows Remove Curse at level 6.
	beats = SideQuestPlay.play(st, "vallaki/the_ravens_ransom:cage", ["Watch where he keeps looking", "Break it with Remove Curse"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("It's very big"))
	assert_true(bool(st.get_flag("bray_cleared", false)))
	assert_eq(st.quest_stage("the_ravens_ransom"), "home")
	st.location = "vallaki_blue_water_inn"
	assert_eq(SideQuestPlay.standing(st, "vallaki_blue_water_inn", "bray_martikov"), "vallaki/the_ravens_ransom:bray")
	st.gold = 0
	beats = SideQuestPlay.play(st, "vallaki/martikovs:urwin", ["About Bray"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Home, and himself"))
	assert_eq(st.quest_stage("the_ravens_ransom"), "done")
	assert_eq(roundi(st.gold), 200)
	assert_true(st.party_has_item("elven_chain"))
	beats = SideQuestPlay.play(st, "vallaki/martikovs:urwin", ["About Bray"])
	assert_true(SideQuestPlay.missing(beats).contains("About Bray"), "thanked once")


func test_taken_home_charmed_and_cleared_at_the_inn() -> void:
	var st := _inn()
	st.set_flag("keepers_of_the_feather_met")
	st.set_quest_stage("the_ravens_ransom", "asked")
	st.location = "lake_zarovich_trail"
	st.set_flag("fowlers_slain")
	var beats := SideQuestPlay.play(st, "vallaki/the_ravens_ransom:cage", ["Take him home"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("bray_charmed", false)))
	st.location = "vallaki_blue_water_inn"
	beats = SideQuestPlay.play(st, "vallaki/martikovs:urwin", ["About Bray", "Goodbye"])
	assert_true(SideQuestPlay.text(beats).contains("something's listening through him"))
	assert_eq(st.quest_stage("the_ravens_ransom"), "home", "not paid while he's still listening")
	st.gold = 0
	beats = SideQuestPlay.play(st, "vallaki/the_ravens_ransom:bray", ["Break it with Remove Curse"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("goes and hits his brother"))
	assert_eq(st.quest_stage("the_ravens_ransom"), "done")
	assert_eq(roundi(st.gold), 200)
	assert_true(st.party_has_item("elven_chain"))
