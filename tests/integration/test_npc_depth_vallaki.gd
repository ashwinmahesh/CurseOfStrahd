extends TestCase
## NPC depth, batch 3 (docs/plans/npc_depth_and_quests.md): Vallaki. Ribbons by forged list and hearing, Florin's
## Grandson, Emanoil Wants to Be Bitten, The Sun-Cake, and the town's flavour. The plain options here are the "every
## roll failed" walks: none of these needs a roll to finish, and a lost hearing is only the old fight.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "ratatoille", "thistle"]
const NO_COOK: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "thistle", "wren_featherfoot"]
const V := "vallaki/"


func _st(hour: int = 10, location: String = "vallaki", party: Array[String] = FOUR) -> StoryState:
	return SideQuestPlay.party(party, 5, location, hour)


func test_a_forged_list_and_a_hearing_that_wins_without_a_fight() -> void:
	var st := _st()
	st.set_quest_stage("ribbons", "asked")
	st.set_flag("ribbons_list_known")
	var beats := SideQuestPlay.play(st, V + "ribbons:lamp", ["Rewrite the list"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Zamfir the Glad"))
	assert_eq(st.quest_stage("ribbons"), "forged")
	beats = SideQuestPlay.play(st, V + "ribbons:lamp", ["Wait for morning"])
	assert_true(st.get_flag("forged_collected", false))
	SideQuestPlay.play(st, V + "ribbons:proof_clerk_ok")
	SideQuestPlay.play(st, V + "ribbons:proof_rider_ok")
	assert_eq(int(st.get_flag("ribbons_proofs", 0)), 2)
	beats = SideQuestPlay.play(st, V + "ribbons:hearing_intro")
	assert_eq(SideQuestPlay.combat_of(beats), "", "two proofs of three: the hearing is won")
	assert_true(SideQuestPlay.text(beats).contains("INSUFFICIENTLY SINCERE"))
	assert_true(st.get_flag("dobre_arrested", false))
	assert_eq(st.quest_stage("ribbons"), "sold_three_times")
	assert_eq(SideQuestPlay.standing(st, "vallaki", "vallaki_ribbon_girl").begins_with(V + "ribbons"), true)
	beats = SideQuestPlay.play(st, V + "ribbons:after", ["Give the lists to Father Lucian"])
	assert_eq(st.quest_stage("ribbons"), "done", "and the lists go to the town as before")


func test_a_lost_hearing_is_the_old_fight_and_never_a_dead_end() -> void:
	var st := _st()
	st.set_quest_stage("ribbons", "forged")
	st.set_flag("forged_collected")
	var beats := SideQuestPlay.play(st, V + "ribbons:sting", ["Bring Dobre before the Baron"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(SideQuestPlay.combat_of(beats), "ribbons_street", "no proofs, no roll: Dobre laughs it off and the street fight stands")


func test_florins_grandson_three_ways() -> void:
	for pick: Array in [["whole truth", "truth"], ["died, at peace", "lie"], ["well and warm", "half"]]:
		var st := _st(10, "village_church")
		var beats := SideQuestPlay.play(st, "village_of_barovia/indoor_folk:mihai", ["Tell us about your grandson", "We'll look for him"])
		assert_eq(SideQuestPlay.missing(beats), "")
		assert_eq(st.quest_stage("florins_grandson"), "asked")
		st.location = "vallaki_wachter_house"
		beats = SideQuestPlay.play(st, V + "florins_grandson:tudorel", ["come from Old Florin"])
		assert_true(SideQuestPlay.text(beats).contains("silver piece"), "he sends a coin by the carter")
		assert_eq(st.quest_stage("florins_grandson"), "found")
		st.location = "village_church"
		beats = SideQuestPlay.play(st, "village_of_barovia/indoor_folk:mihai", ["We found Tudorel", str(pick[0])])
		assert_eq(SideQuestPlay.missing(beats), "")
		assert_eq(st.quest_stage("florins_grandson"), "done")
		assert_eq(str(st.get_flag("florin_told", "")), str(pick[1]))


func test_florin_after_the_truth_gets_the_coin() -> void:
	var st := _st(10, "village_church")
	st.set_quest_stage("florins_grandson", "done")
	st.set_flag("florin_told", "truth")
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, "village_of_barovia/indoor_folk:mihai")).contains("smells of good tea"))
	st.set_flag("florin_told", "lie")
	assert_false(SideQuestPlay.text(SideQuestPlay.play(st, "village_of_barovia/indoor_folk:mihai")).contains("smells of good tea"), "he thinks the boy is dead")


func test_emanoil_by_day_and_three_endings() -> void:
	var st := _st(10)
	assert_eq(SideQuestPlay.standing(st, "vallaki", "emanoil"), V + "emanoil:start")
	st.minute_of_day = 22 * 60
	assert_eq(SideQuestPlay.standing(st, "vallaki", "emanoil"), "", "he is home in his coffin with the candle lit")
	st = _st(10)
	var beats := SideQuestPlay.play(st, V + "emanoil:start", ["write your letter"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("emanoil_wants_to_be_bitten"), "done")
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, V + "emanoil:start")).contains("an ode to your company"))
	var st2 := _st(10)
	beats = SideQuestPlay.play(st2, V + "emanoil:start", ["castle is really like", "Then read your poems"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("I only wished to be chosen"))
	assert_eq(st2.quest_stage("emanoil_wants_to_be_bitten"), "done")


func test_the_sun_cake_bought_and_baked_by_ratatouille() -> void:
	var st := _st(10, "vallaki_burgomaster_mansion")
	var beats := SideQuestPlay.play(st, V + "the_sun_cake:leontina", ["cooked somewhere grand"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("the_sun_cake"), "asked")
	assert_true(SideQuestPlay.text(beats).contains("scar") or SideQuestPlay.text(beats).contains("white line"))
	st.gold = 20
	SideQuestPlay.play(st, V + "the_sun_cake:marta_eggs", ["Pay the gold piece"])
	SideQuestPlay.play(st, V + "the_sun_cake:paraschiva_honey", ["Pay the two gold"])
	SideQuestPlay.play(st, V + "the_sun_cake:vadoma_saffron", ["Pay the five gold"])
	assert_eq(roundi(st.gold), 12, "1 + 2 + 5 gold")
	assert_true(st.get_flag("cake_eggs", false) and st.get_flag("cake_honey", false) and st.get_flag("cake_saffron", false))
	st.gold = 0
	beats = SideQuestPlay.play(st, V + "the_sun_cake:leontina", ["Let Ratatouille take over"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("eight crisp, golden points"))
	assert_eq(st.quest_stage("the_sun_cake"), "done")
	assert_eq(roundi(st.gold), 60)


func test_the_sun_cake_collapses_and_is_a_triumph_anyway() -> void:
	var st := _st(10, "vallaki_burgomaster_mansion", NO_COOK)
	st.set_quest_stage("the_sun_cake", "asked")
	st.set_flag("cake_eggs")
	st.set_flag("cake_honey")
	st.set_flag("cake_saffron")
	st.gold = 0
	var beats := SideQuestPlay.play(st, V + "the_sun_cake:leontina", ["Leave it to Leontina"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Liquid Dawn"))
	assert_eq(st.quest_stage("the_sun_cake"), "done")
	assert_eq(roundi(st.gold), 20)


func test_the_towns_flavour() -> void:
	var st := _st(10)
	var said := SideQuestPlay.text(SideQuestPlay.play(st, V + "baron:decree"))
	assert_true(said.contains("wipe their eyes"), "the first decree")
	said = SideQuestPlay.text(SideQuestPlay.play(st, V + "baron:decree"))
	assert_true(said.contains("dog in Vallaki shall wear"), "the second")
	st.set_flag("lydia_met")
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, V + "lydia:lydia_key")).contains("never counts the same man twice"))
	st.gold = 3
	said = SideQuestPlay.text(SideQuestPlay.play(st, V + "gate:guard_stop", ["Pay the gold piece"]))
	assert_true(said.contains("insufficient rejoicing"))
	assert_eq(roundi(st.gold), 2)
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, V + "townsfolk:anton_stocks")).contains("nobody asks you to smile"))
	said = SideQuestPlay.text(SideQuestPlay.play(st, V + "townsfolk:smaranda_parsley", ["Never mind"]))
	assert_true(said.contains("works as well as anything else"))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, V + "indoor_folk:varvara_milivoj")).contains("new leather boots"))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, V + "arasek:gunther_list")).contains("widows"))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, V + "vadoma:vadoma_cards")).contains("went quiet"))


func test_piccolo_takes_admission_once() -> void:
	var st := _st(10, "vallaki_blinsky_toys")
	st.gold = 4
	var beats := SideQuestPlay.play(st, V + "blinsky:piccolo", ["Let him keep it"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(roundi(st.gold), 3)
	assert_true(SideQuestPlay.text(beats).contains("could not say how the coin got there") or SideQuestPlay.text(beats).contains("cannot say how"))
	SideQuestPlay.play(st, V + "blinsky:piccolo")
	assert_eq(roundi(st.gold), 3, "once only")
	var poor := _st(10, "vallaki_blinsky_toys")
	poor.gold = 0
	beats = SideQuestPlay.play(poor, V + "blinsky:piccolo")
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(roundi(poor.gold), 0, "and nothing to take from the poor")
