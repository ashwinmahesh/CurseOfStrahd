extends TestCase
## Side quests that could be left stuck for good, round two (the side quest failure plan, package S2,
## docs/plans/gemini_sq_stuck_2/): each one now either stays finishable or closes. The Ravens' Ransom under Lady Wachter's
## rule, the Baron's Island once the bell has started, the Burgomaster's Son with no Cleric and no Abbot, the Hunter's Tower
## when the cards name Ezmerelda after the tower was searched, and the Dragon's Beacon when the oath is kept.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "ratatoille", "thistle"]
const NO_CLERIC: Array[String] = ["ilse_varga", "godrick_pendlebrook", "thistle", "wren_featherfoot"]
const V := "vallaki/"
const RAVENS := "vallaki/the_ravens_ransom:"
const MARTIKOVS := "vallaki/martikovs:"
const FISHER := "lake_zarovich/old_fisher:start"
const ANNA := "krezk/anna:start"
const ABBEY_EZMERELDA := "abbey_of_st_markovia/ezmerelda:start"
const CRADLE := "argynvostholt/beacon:cradle"


# --- The Ravens' Ransom ----------------------------------------------------------------------------------------------

## Bray is home at the Blue Water Inn and Lady Wachter rules Vallaki: Urwin and Danika end every talk at once.
func _ransom_home(wachter: bool, cleared: bool, party: Array[String] = FOUR) -> StoryState:
	var st := SideQuestPlay.party(party, 6, "vallaki_blue_water_inn", 12)
	st.set_flag("martikovs_met")
	st.set_flag("danika_met")
	st.set_flag("keepers_of_the_feather_met")
	if wachter:
		st.set_flag("vallaki_backed", "wachter")
	st.set_quest_stage("the_ravens_ransom", "asked")
	st.set_flag("fowlers_slain")
	st.set_quest_stage("the_ravens_ransom", "home")
	if cleared:
		st.set_flag("bray_cleared")
	else:
		st.set_flag("bray_charmed")
	st.gold = 0
	return st


func test_urwin_ends_every_talk_under_lady_wachter_so_danika_pays() -> void:
	var st := _ransom_home(true, true)
	var urwin := SideQuestPlay.play(st, MARTIKOVS + "urwin", ["About Bray"])
	assert_true(SideQuestPlay.text(urwin).contains("We'll still give you a bed"), "Urwin's only word under her rule")
	assert_eq(str(urwin[-1]["kind"]), "end", "and no menu: that is why the quest used to stick")
	assert_eq(st.quest_stage("the_ravens_ransom"), "home")
	var beats := SideQuestPlay.play(st, MARTIKOVS + "danika")
	assert_true(SideQuestPlay.text(beats).contains("You did this"), "she is still angry about the town")
	assert_eq(st.quest_stage("the_ravens_ransom"), "done", "and she still pays for her boy")
	assert_eq(roundi(st.gold), 200)
	assert_true(st.party_has_item("elven_chain"))
	var again := SideQuestPlay.play(st, MARTIKOVS + "danika")
	assert_eq(roundi(st.gold), 200, "paid once")
	assert_false(SideQuestPlay.text(again).contains("Bring him home"))


func test_bray_at_the_inn_fetches_his_mother_when_he_is_already_clear() -> void:
	var st := _ransom_home(true, true)
	assert_eq(SideQuestPlay.standing(st, "vallaki_blue_water_inn", "bray_martikov"), RAVENS + "bray")
	SideQuestPlay.play(st, RAVENS + "bray")
	assert_eq(st.quest_stage("the_ravens_ransom"), "done")
	assert_eq(roundi(st.gold), 200)
	assert_true(st.party_has_item("elven_chain"))


func test_a_charmed_bray_is_still_cleared_at_the_inn_and_danika_pays_under_wachter() -> void:
	var st := _ransom_home(true, false)
	# Liriel (leader) knows Remove Curse at level 6.
	var beats := SideQuestPlay.play(st, RAVENS + "bray", ["Break it with Remove Curse"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("goes and hits his brother"))
	assert_eq(st.quest_stage("the_ravens_ransom"), "done")
	assert_eq(roundi(st.gold), 200)
	assert_false(SideQuestPlay.text(beats).contains("Home, and himself"), "Urwin is not the one who pays under her rule")


func test_urwin_still_pays_when_the_town_is_not_wachters() -> void:
	var st := _ransom_home(false, true)
	var beats := SideQuestPlay.play(st, MARTIKOVS + "urwin", ["About Bray"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Home, and himself"))
	assert_eq(st.quest_stage("the_ravens_ransom"), "done")
	assert_eq(roundi(st.gold), 200)
	# Bray, talked to afterwards, is only a boy again.
	assert_false(SideQuestPlay.text(SideQuestPlay.play(st, RAVENS + "bray")).contains("Home, and himself"))


func test_during_the_festival_urwin_is_away_and_danika_pays_for_a_clear_bray() -> void:
	var st := _ransom_home(false, true)
	st.set_flag("festival_begun")
	assert_eq(SideQuestPlay.standing(st, "vallaki_blue_water_inn", "urwin_martikov"), "", "Urwin is out with the procession")
	SideQuestPlay.play(st, RAVENS + "bray")
	assert_eq(st.quest_stage("the_ravens_ransom"), "done")
	assert_eq(roundi(st.gold), 200)


# --- The Baron's Island ----------------------------------------------------------------------------------------------

func test_the_island_can_still_be_asked_after_the_bell_has_started() -> void:
	for stage: String in ["asked", "the_bell", "risen"]:
		var st := SideQuestPlay.party(FOUR, 5, "lake_zarovich", 14)
		st.set_quest_stage("bell_under_the_lake", stage)
		var beats := SideQuestPlay.play(st, FISHER, ["What's on that island"])
		assert_eq(SideQuestPlay.missing(beats), "", "bell at %s" % stage)
		assert_true(SideQuestPlay.text(beats).contains("It leaks on the left"), "bell at %s" % stage)
		assert_eq(st.quest_stage("the_barons_island"), "asked", "bell at %s" % stage)
	var silenced := SideQuestPlay.party(FOUR, 5, "lake_zarovich", 14)
	silenced.set_flag("bell_silenced")
	silenced.set_quest_stage("bell_under_the_lake", "silenced")
	var beats := SideQuestPlay.play(silenced, FISHER, ["What's on that island"])
	assert_eq(SideQuestPlay.missing(beats), "", "and after it is silenced")
	assert_eq(silenced.quest_stage("the_barons_island"), "asked")


func test_the_bell_talk_is_still_there_beside_the_island_question() -> void:
	var st := SideQuestPlay.party(FOUR, 5, "lake_zarovich", 14)
	st.set_quest_stage("bell_under_the_lake", "asked")
	var beats := SideQuestPlay.play(st, FISHER, ["bell"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Every night now, after the moon's up"))
	assert_eq(st.quest_stage("the_barons_island"), "", "asking about the bell does not start the island")


func test_the_bell_talk_goes_straight_through_when_the_island_cannot_be_asked() -> void:
	var low := SideQuestPlay.party(FOUR, 4, "lake_zarovich", 14)
	low.set_quest_stage("bell_under_the_lake", "asked")
	assert_true(SideQuestPlay.text(SideQuestPlay.play(low, FISHER)).contains("Every night now, after the moon's up"), "not before level 5")
	var council := SideQuestPlay.party(FOUR, 6, "lake_zarovich", 14)
	council.set_flag("vallaki_backed", "neither")
	council.set_quest_stage("bell_under_the_lake", "asked")
	assert_true(SideQuestPlay.text(SideQuestPlay.play(council, FISHER)).contains("Every night now, after the moon's up"), "not once the council has the town")
	var asked := SideQuestPlay.party(FOUR, 6, "lake_zarovich", 14)
	asked.set_quest_stage("bell_under_the_lake", "asked")
	asked.set_quest_stage("the_barons_island", "asked")
	assert_true(SideQuestPlay.text(SideQuestPlay.play(asked, FISHER)).contains("Every night now, after the moon's up"), "not twice")


# --- The Burgomaster's Son -------------------------------------------------------------------------------------------

func _frail_ilya(abbot: String, party: Array[String] = NO_CLERIC) -> StoryState:
	var st := SideQuestPlay.party(party, 7, "krezk_burgomaster_house", 11)
	st.set_flag("anna_met")
	st.set_flag("ilya_heard")
	st.set_flag("white_sun_water")
	st.set_flag("ilya_fate", "frail")
	st.set_quest_stage("the_burgomasters_son", "heard")
	st.set_quest_stage("the_burgomasters_son", "frail")
	match abbot:
		"slain":
			st.set_flag("abbot_fate", "slain")
			st.set_quest_stage("the_abbots_bride", "slain")
		"fled":
			st.set_flag("abbot_fate", "wedding")
			st.set_flag("abbot_told_strahd")
			st.set_quest_stage("the_abbots_bride", "fled")
	return st


func test_a_frail_ilya_recovers_when_the_abbot_is_gone_and_nobody_can_pray() -> void:
	for abbot: String in ["slain", "fled"]:
		var st := _frail_ilya(abbot)
		st.gold = 0
		var beats := SideQuestPlay.play(st, ANNA)
		assert_eq(SideQuestPlay.missing(beats), "", abbot)
		assert_eq(st.quest_stage("the_burgomasters_son"), "recovering", "abbot %s: the quest closes" % abbot)
		assert_eq(str(st.get_flag("ilya_fate", "")), "frail", "abbot %s: the main flag is never touched" % abbot)
		assert_false(bool(st.get_flag("ilya_died", false)), "and nobody died")
		var gold := st.gold
		SideQuestPlay.play(st, ANNA)
		assert_eq(st.gold, gold, "abbot %s: paid once" % abbot)


func test_a_frail_ilya_waits_for_the_abbot_while_he_is_still_at_his_abbey() -> void:
	var st := _frail_ilya("")
	SideQuestPlay.play(st, ANNA)
	assert_eq(st.quest_stage("the_burgomasters_son"), "frail", "the Abbot's hands could still finish it")
	var repentant := _frail_ilya("")
	repentant.set_flag("abbot_fate", "repentant")
	SideQuestPlay.play(repentant, ANNA)
	assert_eq(repentant.quest_stage("the_burgomasters_son"), "frail", "he is on his way down in the unveiling's own ending, not Anna's")


func test_a_party_with_a_cleric_keeps_the_prayer_instead_of_recovering() -> void:
	var st := _frail_ilya("slain", FOUR)   # Liriel is a Cleric
	st.gold = 0
	SideQuestPlay.play(st, ANNA)
	assert_eq(st.quest_stage("the_burgomasters_son"), "frail", "the prayer is on offer, so the quest waits for it")
	assert_eq(roundi(st.gold), 0)
	var beats := SideQuestPlay.play(st, ANNA, ["Let me pray over him"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("the_burgomasters_son"), "healed")
	assert_true(st.party_has_item("amulet_of_health"))


func test_a_cleric_who_joins_after_he_recovers_can_still_heal_him() -> void:
	var st := _frail_ilya("fled")
	SideQuestPlay.play(st, ANNA)
	assert_eq(st.quest_stage("the_burgomasters_son"), "recovering")
	st.party.append(Pregens.build("liriel_dawnsong", 7))
	var beats := SideQuestPlay.play(st, ANNA, ["Let me pray over him"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("the_burgomasters_son"), "healed", "one success ending can still be replaced by the better one")


# --- The Hunter's Tower ----------------------------------------------------------------------------------------------

func test_the_cards_naming_ezmerelda_after_the_tower_was_searched_end_the_quest_at_the_abbey() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 6, "abbey_of_st_markovia", 12)
	st.tarokka = {"ally": "mists"}   # Ezmerelda, waiting at the top of the abbey switchback
	st.set_quest_stage("the_hunters_tower", "heard")
	st.set_quest_stage("the_hunters_tower", "inside")
	var beats := SideQuestPlay.play(st, ABBEY_EZMERELDA, ["Garlic", "Hunt with us"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true("ezmerelda" in st.guest_ids, "she joins")
	assert_eq(st.quest_stage("the_hunters_tower"), "with_her", "and the tower's quest ends with her")


func test_the_abbey_join_leaves_the_tower_quest_alone_when_it_is_not_at_inside() -> void:
	for stage: String in ["", "heard", "asked", "told", "reunited"]:
		var st := SideQuestPlay.party(["ilse_varga"], 6, "abbey_of_st_markovia", 12)
		st.tarokka = {"ally": "mists"}
		if stage == "told" or stage == "reunited":
			st.set_quest_stage("the_hunters_tower", "heard")
		if stage != "":
			st.set_quest_stage("the_hunters_tower", stage)
		SideQuestPlay.play(st, ABBEY_EZMERELDA, ["Garlic", "Hunt with us"])
		assert_eq(st.quest_stage("the_hunters_tower"), stage, "stage %s stays" % stage)
	var gone := SideQuestPlay.party(["ilse_varga"], 6, "abbey_of_st_markovia", 12)
	gone.tarokka = {"ally": "mists"}
	gone.set_flag("rictavio_gone")
	gone.set_quest_stage("the_hunters_tower", "heard")
	gone.set_quest_stage("the_hunters_tower", "inside")
	SideQuestPlay.play(gone, ABBEY_EZMERELDA, ["Garlic", "Hunt with us"])
	assert_eq(gone.quest_stage("the_hunters_tower"), "inside", "he is upstairs in the tower: the reunion ends it, as at the shore")


# --- The Dragon's Beacon ---------------------------------------------------------------------------------------------

func _grudge_at_the_cradle() -> StoryState:
	var st := SideQuestPlay.party(FOUR, 7, "argynvostholt_beacon", 22)
	st.set_flag("argynvost_echo_met")
	st.set_flag("dragon_fire_kindled")
	st.set_flag("order_fate", "grudge")
	st.set_quest_stage("the_dark_beacon", "waiting")
	return st


func test_keeping_the_oath_at_the_cradle_closes_the_beacon_as_a_failure() -> void:
	var st := _grudge_at_the_cradle()
	var beats := SideQuestPlay.play(st, CRADLE, ["Lower the flame", "oath stands"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("the_dark_beacon"), "kept_dark")
	assert_eq(str(st.get_flag("order_fate", "")), "grudge", "the Order's fate is never touched")
	assert_false(bool(st.get_flag("argynvost_beacon_lit", false)))
	assert_true(bool(st.get_flag("beacon_oath_kept", false)))
	assert_false(bool(st.get_flag("dragon_fire_kindled", false)), "the flame is out")


func test_the_oath_is_asked_twice_and_waiting_leaves_the_beacon_open() -> void:
	var st := _grudge_at_the_cradle()
	var beats := SideQuestPlay.play(st, CRADLE, ["Lower the flame", "a little longer"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("the_dark_beacon"), "waiting", "backing off the second question changes nothing")
	assert_true(bool(st.get_flag("dragon_fire_kindled", false)))
	assert_false(bool(st.get_flag("beacon_oath_kept", false)))


func test_once_the_oath_is_kept_the_beacon_cannot_be_lit_and_the_echo_is_silent() -> void:
	var st := _grudge_at_the_cradle()
	SideQuestPlay.play(st, CRADLE, ["Lower the flame", "oath stands"])
	var cradle := SideQuestPlay.play(st, CRADLE)
	assert_false(SideQuestPlay.text(cradle).contains("silver flame leans"), "no flame to light it with")
	assert_eq(SideQuestPlay.combat_of(cradle), "")
	assert_eq(st.quest_stage("the_dark_beacon"), "kept_dark")
	assert_false(bool(st.get_flag("argynvost_beacon_lit", false)))
	# The bones can't be kindled again, with or without having met the echo, so the flame can't come back.
	st.location = "argynvostholt_mausoleum"
	var bones := SideQuestPlay.play(st, "argynvostholt/mausoleum:bones", ["Kindle a light"])
	assert_ne(SideQuestPlay.missing(bones), "", "no kindling after the oath")
	assert_false(bool(st.get_flag("dragon_fire_kindled", false)))
	var unmet := _grudge_at_the_cradle()
	unmet.set_flag("argynvost_echo_met", false)
	SideQuestPlay.play(unmet, CRADLE, ["Lower the flame", "oath stands"])
	unmet.location = "argynvostholt_mausoleum"
	assert_ne(SideQuestPlay.missing(SideQuestPlay.play(unmet, "argynvostholt/mausoleum:bones", ["There's something still burning", "Kindle a light"])), "",
		"nor by the Arcana route")
	# The echo says nothing more.
	var echo := SideQuestPlay.play(st, "argynvostholt/argynvost:start")
	assert_eq(str(echo[-1]["kind"]), "end")
	assert_false(SideQuestPlay.text(echo).contains("You swore with him"), "the frost holds no voice")


func test_breaking_the_oath_still_lights_the_beacon_as_before() -> void:
	var st := _grudge_at_the_cradle()
	var beats := SideQuestPlay.play(st, CRADLE, ["Light it"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(SideQuestPlay.combat_of(beats), "beacon_stand", "Vladimir stands against oathbreakers")
	assert_true(bool(st.get_flag("vladimir_pact_broken", false)))
	assert_eq(st.quest_stage("the_dark_beacon"), "waiting")
