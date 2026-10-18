extends TestCase
## Side quests that could be left stuck (QA - Wiki Walkthrough Findings, round 7, 119 to 134): each one now either stays
## finishable or closes as a proper failure ("side quests can be lost", Ashwin 2026-10-18), and the other walkthrough
## findings on the same files hold. Florin's Grandson (Tudorel follows his household), The Sun-Cake (Marta, Vadoma, the
## haggle, whoever tastes it), Radu's Unsellable Horse, Fennimore's Guide, Exethanter's Notes, the Boyar's seals, Dumitru's
## Visitor and the Hunter's Ledger (Kiril in the den's reckoning, and the names a party spared).

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "ratatoille", "thistle"]
const NO_COOK: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "thistle", "wren_featherfoot"]
const V := "vallaki/"
const S := "svalich_road/"
const MIHAI := "village_of_barovia/indoor_folk:mihai"


func _st(hour: int = 10, location: String = "vallaki", level: int = 5, party: Array[String] = FOUR) -> StoryState:
	return SideQuestPlay.party(party, level, location, hour)


## The festival is over and the town went the given way: ["baron", "stocks"], ["wachter", "ruler"], ["neither", "exposed"]...
func _after_festival(st: StoryState, backed: String, wachter_fate: String) -> void:
	st.set_flag("festival_begun")
	st.set_flag("festival_over")
	st.set_flag("vallaki_backed", backed)
	st.set_flag("wachter_fate", wachter_fate)


# --- Florin's Grandson ---------------------------------------------------------------------------------------------

func test_tudorel_can_be_found_wherever_lady_wachters_household_ends_up() -> void:
	var house := "vallaki_wachter_house"
	var mansion := "vallaki_burgomaster_mansion"
	var cases := [
		# [backed, wachter_fate, where he stands, the dialogue there]
		["baron", "stocks", "vallaki", "tudorel_square"],
		["baron", "exiled", "vallaki", "tudorel_square"],
		["neither", "exposed", "vallaki", "tudorel_square"],
		["wachter", "ruler", mansion, "tudorel"],
		["neither", "free", house, "tudorel"],
	]
	for c: Array in cases:
		var st := _st()
		st.set_quest_stage("florins_grandson", "asked")
		_after_festival(st, str(c[0]), str(c[1]))
		var where := str(c[2])
		assert_eq(SideQuestPlay.standing(st, where, "tudorel"), V + "florins_grandson:" + str(c[3]),
			"%s/%s: Tudorel is at %s" % [c[0], c[1], where])
		for other: String in ["vallaki", mansion, house]:
			if other != where:
				assert_eq(SideQuestPlay.standing(st, other, "tudorel"), "", "%s/%s: and nowhere else (%s)" % [c[0], c[1], other])
		# The talk reaches Found and Florin can be told, whichever spot he is at.
		st.location = where
		var beats := SideQuestPlay.play(st, V + "florins_grandson:" + str(c[3]), ["come from Old Florin"])
		assert_eq(SideQuestPlay.missing(beats), "", "%s/%s: the Florin option is there" % [c[0], c[1]])
		assert_eq(st.quest_stage("florins_grandson"), "found")
		st.location = "village_church"
		SideQuestPlay.play(st, MIHAI, ["We found Tudorel", "whole truth"])
		assert_eq(st.quest_stage("florins_grandson"), "done", "%s/%s: and the quest finishes" % [c[0], c[1]])


func test_tudorel_in_the_square_introduces_himself_once() -> void:
	var st := _st()
	_after_festival(st, "baron", "stocks")
	var first := SideQuestPlay.text(SideQuestPlay.play(st, V + "florins_grandson:tudorel_square"))
	assert_true(first.contains("her ladyship is gone from the house"))
	assert_true(st.get_flag("tudorel_met", false))
	var again := SideQuestPlay.text(SideQuestPlay.play(st, V + "florins_grandson:tudorel_square"))
	assert_false(again.contains("her ladyship is gone from the house"), "only the menu the second time")


func test_tudorel_speaks_of_florin_only_while_the_quest_is_at_asked() -> void:
	var st := _st(10, "vallaki_wachter_house")
	st.set_flag("tudorel_met")
	var beats := SideQuestPlay.play(st, V + "florins_grandson:tudorel", ["come from Old Florin"])
	assert_ne(SideQuestPlay.missing(beats), "", "a party that never met Florin has nothing to say about him")
	assert_eq(st.quest_stage("florins_grandson"), "", "and the quest is not started or skipped past Asked")
	st.set_quest_stage("florins_grandson", "asked")
	beats = SideQuestPlay.play(st, V + "florins_grandson:tudorel", ["come from Old Florin"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("florins_grandson"), "found")
	beats = SideQuestPlay.play(st, V + "florins_grandson:tudorel", ["come from Old Florin"])
	assert_ne(SideQuestPlay.missing(beats), "", "nor once he is found")


func test_florin_and_tudorel_follow_the_lie() -> void:
	var st := _st(10, "village_church")
	st.set_quest_stage("florins_grandson", "done")
	st.set_flag("florin_told", "lie")
	var florin := SideQuestPlay.text(SideQuestPlay.play(st, MIHAI))
	assert_true(florin.contains("fresh tallow candle"), "Florin lights candles for the boy he thinks is dead")
	assert_false(florin.contains("I pray he doesn't"), "and no longer prays against his coming")
	assert_false(florin.contains("smells of good tea"), "no coin comes in his story")
	st.location = "vallaki_wachter_house"
	var tudorel := SideQuestPlay.text(SideQuestPlay.play(st, V + "florins_grandson:tudorel"))
	assert_true(tudorel.contains("clean end"), "Tudorel thanks them for the lie")
	assert_false(tudorel.contains("name on it"))
	for told: String in ["truth", "half"]:
		st.set_flag("florin_told", told)
		tudorel = SideQuestPlay.text(SideQuestPlay.play(st, V + "florins_grandson:tudorel"))
		assert_true(tudorel.contains("name on it"), "the other two keep the old thanks (%s)" % told)
		assert_true(SideQuestPlay.text(SideQuestPlay.play(st, MIHAI)).contains("smells of good tea"))


# --- The Sun-Cake -------------------------------------------------------------------------------------------------

func test_marta_still_sells_the_eggs_after_the_council_takes_the_town() -> void:
	var st := _st(10, "vallaki")
	_after_festival(st, "neither", "free")
	st.set_quest_stage("the_sun_cake", "asked")
	st.gold = 5
	var beats := SideQuestPlay.play(st, V + "townsfolk:goodwife", ["needs eggs for a sun-cake", "Pay the gold piece"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("No festival this week"), "her old line is kept")
	assert_true(st.get_flag("cake_eggs", false), "so the cake is not stuck at Asked")
	assert_eq(roundi(st.gold), 4)
	# Without the quest she is just the calm line and a goodbye.
	var plain := _st(10, "vallaki")
	_after_festival(plain, "neither", "free")
	beats = SideQuestPlay.play(plain, V + "townsfolk:goodwife", ["needs eggs for a sun-cake"])
	assert_ne(SideQuestPlay.missing(beats), "", "no egg option unless the cake is asked and the eggs not bought")


func test_the_cake_fails_when_vadoma_will_not_sell_the_saffron() -> void:
	var st := _st(10, "vallaki_vistani_camp")
	st.set_quest_stage("the_sun_cake", "asked")
	st.set_flag("tser_pool_brawl_won")
	var beats := SideQuestPlay.play(st, V + "vadoma:start")
	assert_true(SideQuestPlay.text(beats).contains("Every wagon in the valley knows what you did"), "her old refusal")
	assert_true(SideQuestPlay.text(beats).contains("oven can go cold"))
	assert_eq(st.quest_stage("the_sun_cake"), "failed")
	var stage := {}
	for s: Variant in Compendium.shared().get_entry("quests", "the_sun_cake")["stages"]:
		if str((s as Dictionary)["id"]) == "failed":
			stage = s as Dictionary
	assert_eq(str(stage.get("ends", "")), "failure", "a lost quest, not a stuck one")
	# Leontina closes it with no pay, and the sellers' options are gone.
	st.location = "vallaki_burgomaster_mansion"
	st.gold = 0
	beats = SideQuestPlay.play(st, V + "the_sun_cake:leontina")
	assert_true(SideQuestPlay.text(beats).contains("four hundred and fourteen"))
	assert_eq(roundi(st.gold), 0)
	assert_eq(st.quest_stage("the_sun_cake"), "failed")
	st.location = "vallaki"
	beats = SideQuestPlay.play(st, V + "townsfolk:goodwife", ["needs eggs for a sun-cake"])
	assert_ne(SideQuestPlay.missing(beats), "", "nobody sells for a lost cake")


func test_vadoma_after_the_brawl_does_not_fail_a_cake_that_is_not_in_need_of_saffron() -> void:
	var st := _st(10, "vallaki_vistani_camp")
	st.set_flag("tser_pool_brawl_won")
	SideQuestPlay.play(st, V + "vadoma:start")
	assert_eq(st.quest_stage("the_sun_cake"), "", "not asked: nothing to lose")
	st.set_quest_stage("the_sun_cake", "asked")
	st.set_flag("cake_saffron")
	SideQuestPlay.play(st, V + "vadoma:start")
	assert_eq(st.quest_stage("the_sun_cake"), "asked", "the saffron was bought before the brawl")


func test_the_cake_warns_about_the_vistani_and_fails_only_after_the_brawl() -> void:
	var st := _st(10, "vallaki_burgomaster_mansion")
	var beats := SideQuestPlay.play(st, V + "the_sun_cake:leontina", ["cooked somewhere grand"])
	assert_true(SideQuestPlay.text(beats).contains("Mind your manners at the camp"), "the warning is in the ask")
	# A peaceful camp: Vadoma sells and the quest runs on.
	st.location = "vallaki_vistani_camp"
	st.gold = 10
	SideQuestPlay.play(st, V + "vadoma:start", ["saffron for a sun-cake", "Pay the five gold"])
	assert_true(st.get_flag("cake_saffron", false))
	assert_eq(st.quest_stage("the_sun_cake"), "asked")


func test_the_haggle_needs_the_gold_it_costs() -> void:
	var st := _st(10, "vallaki_vistani_camp")
	st.set_quest_stage("the_sun_cake", "asked")
	st.gold = 2
	var beats := SideQuestPlay.play(st, V + "the_sun_cake:vadoma_saffron", ["Haggle"])
	assert_ne(SideQuestPlay.missing(beats), "", "two gold cannot pay a haggled three")
	assert_eq(roundi(st.gold), 2)
	st.gold = 3
	beats = SideQuestPlay.play(st, V + "the_sun_cake:vadoma_saffron", ["Haggle"])
	assert_eq(SideQuestPlay.missing(beats), "", "three can")


func test_the_cake_is_tasted_by_whoever_rules_the_mansion() -> void:
	var cases := [
		# [backed, fate, result pick, a phrase of the taster, gold]
		["wachter", "ruler", "Let Ratatouille take over", "Leontina has outdone herself", 60],
		["wachter", "ruler", "Leave it to Leontina", "sun that has chosen to lie down", 20],
		["neither", "free", "Let Ratatouille take over", "here is the first with corners", 60],
		["neither", "free", "Leave it to Leontina", "glorious golden sea", 20],
		["baron", "stocks", "Let Ratatouille take over", "Like rays of glory", 60],
		["baron", "stocks", "Leave it to Leontina", "Liquid Dawn", 20],
	]
	for c: Array in cases:
		var st := _st(10, "vallaki_burgomaster_mansion", 5, FOUR if str(c[2]).contains("Ratatouille") else NO_COOK)
		_after_festival(st, str(c[0]), str(c[1]))
		st.set_quest_stage("the_sun_cake", "asked")
		st.set_flag("cake_eggs")
		st.set_flag("cake_honey")
		st.set_flag("cake_saffron")
		st.gold = 0
		var beats := SideQuestPlay.play(st, V + "the_sun_cake:leontina", [str(c[2])])
		assert_eq(SideQuestPlay.missing(beats), "", "%s: %s" % [c[0], c[2]])
		var said := SideQuestPlay.text(beats)
		assert_true(said.contains(str(c[3])), "%s/%s: %s" % [c[0], c[2], c[3]])
		assert_eq(st.quest_stage("the_sun_cake"), "done")
		assert_eq(roundi(st.gold), int(c[4]), "%s/%s: the same pay" % [c[0], c[2]])
	# Before the festival, and on the Baron's own path, it is the Baron who tastes; never a stranger.
	var wachter := _st(10, "vallaki_burgomaster_mansion")
	_after_festival(wachter, "wachter", "ruler")
	wachter.set_quest_stage("the_sun_cake", "asked")
	for f: String in ["cake_eggs", "cake_honey", "cake_saffron"]:
		wachter.set_flag(f)
	assert_false(SideQuestPlay.text(SideQuestPlay.play(wachter, V + "the_sun_cake:leontina", ["Let Ratatouille take over"])).contains("The Baron takes a forkful"))


# --- Radu's Unsellable Horse ---------------------------------------------------------------------------------------

func test_dinte_is_not_offered_by_a_camp_that_has_turned_and_does_not_linger_once_led_out() -> void:
	for flag: String in ["tser_pool_brawl_won", "vistani_turned_hostile"]:
		var st := _st(10, "tser_pool", 6)
		assert_true(SideQuestPlay.shown(st, "tser_pool", "tser_dinte"), "in a friendly camp he is in the pen")
		st.set_flag(flag)
		assert_false(SideQuestPlay.shown(st, "tser_pool", "tser_dinte"), "%s: no new offer from an empty camp" % flag)
		st.set_quest_stage("radus_unsellable_horse", "offered")
		assert_true(SideQuestPlay.shown(st, "tser_pool", "tser_dinte"), "%s: but an offer already made can still be led out" % flag)
		st.set_flag("dinte_led")
		assert_false(SideQuestPlay.shown(st, "tser_pool", "tser_dinte"), "%s: and once led out he is out of the pen" % flag)


func test_a_horse_sold_while_the_camp_is_hostile_closes_as_a_failure() -> void:
	for buyer: String in ["costica", "fennimore"]:
		var st := _st(10, "svalich_crossroads", 6)
		st.set_flag("vistani_turned_hostile")
		st.set_quest_stage("radus_unsellable_horse", "offered")
		st.set_flag("dinte_led")
		st.gold = 0
		var beats := SideQuestPlay.play(st, S + buyer + ":menu", ["horse"])
		assert_eq(SideQuestPlay.missing(beats), "", buyer)
		assert_eq(st.quest_stage("radus_unsellable_horse"), "unpaid", "%s: sold, but nobody is left to pay" % buyer)
		assert_true(SideQuestPlay.text(beats).contains("nobody") or SideQuestPlay.text(beats).contains("no one waiting"))
		assert_false(SideQuestPlay.text(beats).contains("I have owned that horse for three years"), "Radu is not there to say it")
		assert_eq(roundi(st.gold), 3 if buyer == "costica" else 25, "the buyer's own gold is theirs")
		var unpaid := {}
		for s: Variant in Compendium.shared().get_entry("quests", "radus_unsellable_horse")["stages"]:
			if str((s as Dictionary)["id"]) == "unpaid":
				unpaid = s as Dictionary
		assert_eq(str(unpaid.get("ends", "")), "failure")


func test_a_found_buyer_cannot_strand_the_quest_when_the_camp_turns_afterwards() -> void:
	for buyer: String in ["costica", "fennimore"]:
		var st := _st(10, "svalich_crossroads", 6)
		st.set_quest_stage("radus_unsellable_horse", "buyer_found")
		st.set_flag("dinte_sold")
		var beats := SideQuestPlay.play(st, S + buyer + ":menu", ["no one left to pay"])
		assert_ne(SideQuestPlay.missing(beats), "", "%s: not while Radu is still there to pay" % buyer)
		assert_eq(st.quest_stage("radus_unsellable_horse"), "buyer_found")
		st.set_flag("tser_pool_brawl_won")
		beats = SideQuestPlay.play(st, S + buyer + ":menu", ["no one left to pay"])
		assert_eq(SideQuestPlay.missing(beats), "", buyer)
		assert_eq(st.quest_stage("radus_unsellable_horse"), "unpaid")
		assert_true(SideQuestPlay.text(beats).contains("empty palm"))


func test_a_friendly_camp_still_pays_the_old_way() -> void:
	var st := _st(10, "svalich_crossroads", 6)
	st.set_quest_stage("radus_unsellable_horse", "offered")
	st.set_flag("dinte_led")
	st.gold = 0
	SideQuestPlay.play(st, S + "costica:menu", ["want a horse"])
	assert_eq(st.quest_stage("radus_unsellable_horse"), "buyer_found")
	st.location = "tser_pool"
	SideQuestPlay.play(st, S + "tser_camp:radu")
	assert_eq(st.quest_stage("radus_unsellable_horse"), "sold")


# --- Fennimore's Guide ---------------------------------------------------------------------------------------------

func test_fennimore_warns_about_the_camp_and_lets_go_of_the_guide_when_it_turns() -> void:
	var st := _st(10, "svalich_crossroads", 6)
	var said := SideQuestPlay.text(SideQuestPlay.play(st, S + "fennimore:start", ["May we see the book", "find out about the stew"]))
	assert_true(said.contains("Do mind your manners by the wagons"), "he warns before the quest starts")
	assert_eq(st.quest_stage("fennimores_guide"), "asked")
	# Now the camp turns on the party before Dorina is asked.
	st.set_flag("vistani_turned_hostile")
	var beats := SideQuestPlay.play(st, S + "fennimore:start", ["turned on us"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("plum?"))
	assert_eq(st.quest_stage("fennimores_guide"), "unverified")
	assert_eq(roundi(st.gold), 0, "no ten gold for a question mark")
	var stage := {}
	for s: Variant in Compendium.shared().get_entry("quests", "fennimores_guide")["stages"]:
		if str((s as Dictionary)["id"]) == "unverified":
			stage = s as Dictionary
	assert_eq(str(stage.get("ends", "")), "failure")
	# He has an exit and talks on.
	beats = SideQuestPlay.play(st, S + "fennimore:start", ["Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")


func test_fennimore_does_not_start_the_guide_for_a_camp_that_has_already_turned() -> void:
	for flag: String in ["tser_pool_brawl_won", "vistani_turned_hostile"]:
		var st := _st(10, "svalich_crossroads", 6)
		st.set_flag(flag)
		var beats := SideQuestPlay.play(st, S + "fennimore:start", ["May we see the book", "find out about the stew"])
		assert_ne(SideQuestPlay.missing(beats), "", "%s: no stew to find out about" % flag)
		assert_eq(st.quest_stage("fennimores_guide"), "")


func test_fennimore_still_pays_for_a_stew_found_out_before_the_camp_turned() -> void:
	var st := _st(10, "svalich_crossroads", 6)
	st.set_quest_stage("fennimores_guide", "known")
	st.set_flag("tser_pool_brawl_won")
	st.gold = 0
	var beats := SideQuestPlay.play(st, S + "fennimore:start", ["what is in the stew"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("fennimores_guide"), "done")
	assert_eq(roundi(st.gold), 10)
	assert_true(SideQuestPlay.text(beats).contains("start the next chapter"), "he stays by his signpost")
	assert_false(SideQuestPlay.text(beats).contains("off toward Vallaki"))


func test_stanimirs_fire_is_offered_only_while_lavinia_is_in_the_camp() -> void:
	for hour: int in [2, 8, 23]:
		var st := _st(hour, "tser_pool", 4)
		st.set_flag("stanimir_tale_heard")
		var beats := SideQuestPlay.play(st, S + "stanimir:menu", ["tale of our own"])
		assert_ne(SideQuestPlay.missing(beats), "", "%d:00: Lavinia is not up to speak in the forfeit" % hour)
	for hour: int in [10, 20]:
		var st := _st(hour, "tser_pool", 4)
		st.set_flag("stanimir_tale_heard")
		var beats := SideQuestPlay.play(st, S + "stanimir:menu", ["tale of our own"])
		assert_eq(SideQuestPlay.missing(beats), "", "%d:00: the fire is on offer" % hour)


# --- Exethanter's Notes --------------------------------------------------------------------------------------------

func test_smashing_the_phylactery_loses_an_open_notes_quest_rather_than_sticking_it() -> void:
	var st := _st(10, "amber_temple_library", 9)
	st.set_flag("exethanter_met")
	st.set_quest_stage("exethanters_notes", "asked")
	var beats := SideQuestPlay.play(st, "amber_temple/exethanter:lid_smash")
	assert_true(SideQuestPlay.text(beats).contains("slide silently to the stone floor"))
	assert_eq(st.quest_stage("exethanters_notes"), "lost")
	assert_eq(str(st.get_flag("exethanter_phylactery", "")), "smashed")
	var stage := {}
	for s: Variant in Compendium.shared().get_entry("quests", "exethanters_notes")["stages"]:
		if str((s as Dictionary)["id"]) == "lost":
			stage = s as Dictionary
	assert_eq(str(stage.get("ends", "")), "failure")
	beats = SideQuestPlay.play(st, "amber_temple/exethanter:start")
	assert_true(SideQuestPlay.text(beats).contains("Leave those five on the stones"))
	assert_eq(SideQuestPlay.missing(beats), "")


func test_smashing_the_phylactery_before_the_notes_do_not_start_them_and_they_do_not_outlive_him() -> void:
	var st := _st(10, "amber_temple_library", 9)
	st.set_flag("exethanter_met")
	SideQuestPlay.play(st, "amber_temple/exethanter:lid_smash")
	assert_eq(st.quest_stage("exethanters_notes"), "", "no quest was started to be lost")
	var beats := SideQuestPlay.play(st, "amber_temple/exethanter:start", ["so many notes"])
	assert_ne(SideQuestPlay.missing(beats), "", "after he is released the notes are not on offer")
	assert_eq(st.quest_stage("exethanters_notes"), "")
	assert_false(SideQuestPlay.text(beats).contains("Leave those five on the stones"))


# --- The Boyar's seals ---------------------------------------------------------------------------------------------

func test_the_boyar_names_only_the_seals_still_wanted() -> void:
	var st := _st(10, "castle_ravenloft_court", 9)
	st.set_quest_stage("boyars_petition", "asked")
	var beats := SideQuestPlay.play(st, "castle_ravenloft/household:crainic_menu", ["Which seals"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var all := SideQuestPlay.text(beats)
	for who: String in ["Ghenadie", "Anghel Daskal", "Nicodim", "Vlaicu"]:
		assert_true(all.contains(who), "none yet: the whole form names " + who)
	st.set_flag("seal_valet")
	st.set_flag("seal_lamp")
	st.set_flag("petition_seals", 2)
	var said := SideQuestPlay.text(SideQuestPlay.play(st, "castle_ravenloft/household:crainic_menu", ["Which seals"]))
	assert_true(said.contains("Anghel Daskal") and said.contains("Nicodim"), "the chancery and chapel are wanted")
	assert_false(said.contains("Ghenadie") or said.contains("Vlaicu"), "the valet's and lamplighter's are held")
	st.set_flag("seal_secretary")
	st.set_flag("seal_verger")
	st.set_flag("petition_seals", 4)
	var done := SideQuestPlay.play(st, "castle_ravenloft/household:crainic_menu", ["Which seals"])
	assert_ne(SideQuestPlay.missing(done), "", "with all four there is nothing left to ask about")


# --- Dumitru's Visitor ---------------------------------------------------------------------------------------------

func test_fennimore_is_at_krezks_gate_only_when_dumitru_is() -> void:
	var st := _st(12, "krezk", 6)
	st.set_flag("krezk_gate_open")
	st.set_flag("fennimore_to_krezk")
	st.set_quest_stage("dumitrus_visitor", "fennimore")
	var day_there := false
	for day in range(1, 12):
		st.day = day
		st.minute_of_day = 12 * 60
		if SideQuestPlay.standing(st, "krezk", "krezk_gate_boy") != "":
			day_there = true
			assert_eq(SideQuestPlay.standing(st, "krezk", "fennimore"), "krezk/dumitrus_visitor:fennimore_visit", "noon on a fair day: both there")
		st.minute_of_day = 22 * 60
		assert_eq(SideQuestPlay.standing(st, "krezk", "krezk_gate_boy"), "", "night: Dumitru is in")
		assert_eq(SideQuestPlay.standing(st, "krezk", "fennimore"), "", "night: so is the visit (day %d)" % day)
	assert_true(day_there, "some day has fair weather")


func test_dumitru_remembers_a_visit_only_if_one_happened() -> void:
	# The friends story is told at the Fennimore stage: the quest ends and Fennimore never comes.
	var st := _st(12, "krezk", 6)
	st.set_flag("fennimore_to_krezk")
	st.set_quest_stage("dumitrus_visitor", "fennimore")
	SideQuestPlay.play(st, "krezk/dumitrus_visitor:cousins_ok")
	assert_eq(st.quest_stage("dumitrus_visitor"), "done")
	var greeting := SideQuestPlay.text(SideQuestPlay.play(st, "krezk/townsfolk:gate_boy"))
	assert_false(greeting.contains("Four stars"), "no visit, no Fennimore's four stars")
	assert_true(greeting.contains("don't even have to knock"))
	assert_false(SideQuestPlay.text(SideQuestPlay.play(st, "krezk/townsfolk:gate_boy")).contains("two-page Sunday"))
	# The real visit.
	var real := _st(12, "krezk", 6)
	real.set_flag("fennimore_to_krezk")
	real.set_quest_stage("dumitrus_visitor", "fennimore")
	SideQuestPlay.play(real, "krezk/dumitrus_visitor:fennimore_visit")
	assert_eq(real.quest_stage("dumitrus_visitor"), "done")
	assert_true(real.get_flag("fennimore_visited_krezk", false))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(real, "krezk/townsfolk:gate_boy")).contains("Four stars"))


# --- The Hunter's Ledger -------------------------------------------------------------------------------------------

const NAMES: Array[String] = ["falls", "wagon", "fowlers", "vine", "morgantha", "wint", "huntsman", "grandsire", "kiril",
	"khazan", "lysaga", "sarkhaza", "eye"]


## The story flag each name's death sets (the ledger reads these, and pays once `ledger_paid_<name>` is set).
const KILLED := {"falls": "falls_werewolf_slain", "wagon": "wagon_slain", "fowlers": "fowlers_slain", "vine": "vine_mother_slain",
	"morgantha": "morgantha_slain", "wint": "yester_hill_resolved", "huntsman": "huntsman_slain", "grandsire": "grandsire_slain",
	"kiril": "kiril_defeated", "khazan": "khazan_destroyed", "lysaga": "lysaga_dead", "sarkhaza": "sarkhaza_slain",
	"eye": "eye_below_slain"}


## A party at `level` whose ledger has been paid for these names (killed and paid).
func _ledger(level: int, paid: Array[String]) -> StoryState:
	var st := _st(10, "van_richtens_tower", level)
	st.set_quest_stage("hunters_ledger", "paying")
	st.set_flag("ezmerelda_ledger_shown")
	for n in paid:
		st.set_flag("ledger_paid_" + n)
		st.set_flag(str(KILLED[n]))
	st.set_flag("ezmerelda_ledger_paid", paid.size())
	st.set_flag("ezmerelda_ledger_gift_a")
	st.set_flag("ezmerelda_ledger_gift_b")
	return st


func test_the_ledger_pays_for_kiril_killed_in_the_dens_reckoning() -> void:
	var st := _ledger(7, [])
	st.set_flag("den_broken")
	var beats := SideQuestPlay.play(st, "allies/ezmerelda:ledger", ["Kiril is dead in his den"])
	assert_eq(SideQuestPlay.missing(beats), "", "den_broken counts as his death")
	assert_true(st.get_flag("ledger_paid_kiril", false))
	assert_eq(int(st.get_flag("ezmerelda_ledger_paid", 0)), 1)
	# She no longer briefs him as alive, nor tells her leg's story as if he were.
	var other := _ledger(7, [])
	other.set_flag("den_broken")
	other.set_flag("ledger_paid_kiril")
	beats = SideQuestPlay.play(other, "allies/ezmerelda:ledger", ["Tell us about Kiril"])
	assert_ne(SideQuestPlay.missing(beats), "", "not offered as a hunt once he is dead")
	var leg := SideQuestPlay.text(SideQuestPlay.play(other, "allies/ezmerelda:leg"))
	assert_true(leg.contains("With the wolf dead"))


func test_the_ledger_closes_at_what_is_left_when_the_rest_were_spared() -> void:
	var paid: Array[String] = []
	for n in NAMES:
		if not n in ["morgantha", "grandsire", "kiril", "lysaga"]:
			paid.append(n)
	var st := _ledger(9, paid)
	st.set_flag("wolf_pack_leader", "kiril")
	st.set_quest_stage("the_packs_runt", "given")
	st.set_flag("bonegrinder_fate", "bargain")
	st.set_flag("lysaga_fate", "bargained")
	# Under level 9 the book still has hunts she would send them on; at 9 there is nothing but the spared.
	var beats := SideQuestPlay.play(st, "allies/ezmerelda:ledger", ["Leave the ledger open"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	for phrase: String in ["Kiril Stoyanovich stays in ink", "The Grandsire in Krezk stays open too", "Morgantha's line stays unmarked", "Baba Lysaga stays on the page"]:
		assert_true(said.contains(phrase), phrase)
	assert_eq(st.quest_stage("hunters_ledger"), "paying", "leaving it open changes nothing")
	beats = SideQuestPlay.play(st, "allies/ezmerelda:ledger", ["Close the book"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("hunters_ledger"), "ledger_closed")
	var stage := {}
	for s: Variant in Compendium.shared().get_entry("quests", "hunters_ledger")["stages"]:
		if str((s as Dictionary)["id"]) == "ledger_closed":
			stage = s as Dictionary
	assert_eq(str(stage.get("ends", "")), "failure")
	# Once closed she does not ask again, and a kill she hears of later is still paid and can still finish the book.
	beats = SideQuestPlay.play(st, "allies/ezmerelda:ledger")
	assert_false(SideQuestPlay.text(beats).contains("we close the ledger"))
	st.set_flag("kiril_defeated")
	for n: String in ["morgantha", "grandsire", "lysaga"]:
		st.set_flag("ledger_paid_" + n)
	st.set_flag("ezmerelda_ledger_paid", 12)
	SideQuestPlay.play(st, "allies/ezmerelda:ledger", ["Kiril is dead in his den"])
	assert_eq(st.quest_stage("hunters_ledger"), "ledger_struck", "a name struck later is a way back to success")


func test_the_ledger_is_not_closed_on_a_party_that_spared_nobody() -> void:
	var paid: Array[String] = []
	for n in NAMES:
		if n != "eye":
			paid.append(n)
	var st := _ledger(9, paid)
	var said := SideQuestPlay.text(SideQuestPlay.play(st, "allies/ezmerelda:ledger", ["That's enough names"]))
	assert_false(said.contains("we close the ledger"), "the Eye Below is still a hunt, not a spared name")
	var low := _ledger(8, paid)
	for n: String in ["morgantha", "grandsire", "kiril", "lysaga"]:
		low.set_flag("ledger_paid_" + n)
	low.set_flag("wolf_pack_leader", "kiril")
	assert_false(SideQuestPlay.text(SideQuestPlay.play(low, "allies/ezmerelda:ledger", ["That's enough names"])).contains("we close the ledger"),
		"below level 9 she still has hunts to send them on")


func test_the_ledgers_hints_name_only_what_works() -> void:
	var half := {}
	for s: Variant in Compendium.shared().get_entry("quests", "hunters_ledger")["stages"]:
		if str((s as Dictionary)["id"]) == "half_struck":
			half = s as Dictionary
	assert_false(str(half["hint"]).contains("on the road beside her"), "the road meetings have no ledger option")
	assert_true(str(half["hint"]).contains("clicking on her"))
