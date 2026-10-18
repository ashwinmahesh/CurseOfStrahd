extends TestCase
## NPC depth, batch 2 (docs/plans/npc_depth_and_quests.md): the Tser Pool camp and the Old Svalich Road. Called by Name
## by day, The Grey Mare's decoy, Stanimir's Fire, Radu's Unsellable Horse, Fennimore's Guide, Costica, and the camp's
## flavour. None of them is locked behind a roll: each plain option here is the "every roll failed" walk.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "ratatoille", "thistle"]
const WREN_FOUR: Array[String] = ["wren_featherfoot", "godrick_pendlebrook", "ratatoille", "thistle"]
const S := "svalich_road/"


func _st(hour: int = 10, location: String = "tser_pool") -> StoryState:
	return SideQuestPlay.party(FOUR, 4, location, hour)


func test_called_by_name_by_day_without_the_wisps() -> void:
	var st := _st(10, "tser_falls")
	st.set_quest_stage("called_by_name", "asked")
	var beats := SideQuestPlay.play(st, S + "called_by_name:falls", ["Call down to him", "Come back after dark"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("No lights drift in the grey daylight"), "by day: the ledge, the boy, no lights")
	assert_true(said.contains("do not say my name"), "he hails them")
	assert_eq(SideQuestPlay.combat_of(beats), "", "and walking away is fine")
	beats = SideQuestPlay.play(st, S + "called_by_name:climb_day")
	assert_true(SideQuestPlay.text(beats).contains("Hand over hand"))
	assert_true(SideQuestPlay.text(beats).contains("sounds like nobody at all"))
	assert_true(st.get_flag("nelu_saved", false))
	assert_eq(st.quest_stage("called_by_name"), "nelu_found")
	st.minute_of_day = 23 * 60
	beats = SideQuestPlay.play(st, S + "called_by_name:falls")
	assert_true(SideQuestPlay.text(beats).contains("empty"), "at night the gorge has nothing left to call with")
	assert_eq(SideQuestPlay.combat_of(beats), "")


func test_the_decoy_swaps_a_mare_for_a_play_horse() -> void:
	var st := _st(10)
	st.set_quest_stage("the_grey_mare", "asked")
	var beats := SideQuestPlay.play(st, S + "grey_mare:radu", ["anything shaped like a horse"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Winter Horse"))
	assert_true(st.get_flag("decoy_given", false))
	beats = SideQuestPlay.play(st, S + "grey_mare:swap_ok")
	assert_eq(SideQuestPlay.combat_of(beats), "", "the carriage takes the straw horse and goes")
	assert_true(st.get_flag("carriage_fooled", false) and st.get_flag("mare_saved", false))
	assert_eq(st.quest_stage("the_grey_mare"), "saved")
	st.gold = 0
	beats = SideQuestPlay.play(st, S + "grey_mare:radu", ["She's yours"])
	assert_true(SideQuestPlay.text(beats).contains("never bought one back with two yards of dirty canvas"))
	assert_eq(st.quest_stage("the_grey_mare"), "home")
	assert_eq(roundi(st.gold), 120)


func test_a_fumbled_swap_is_a_fight_with_the_mare_already_away() -> void:
	var st := _st(23, "svalich_crossroads")
	st.set_quest_stage("the_grey_mare", "asked")
	var beats := SideQuestPlay.play(st, S + "grey_mare:swap_fail")
	assert_eq(SideQuestPlay.combat_of(beats), "carriage_escort", "the failure path is the fight, still there to play")
	assert_true(st.get_flag("mare_saved", false), "and Steaua is home regardless")


func test_the_decoy_is_on_offer_before_any_calming_is_tried() -> void:
	# A failed one-try calm loses the mare; the swap is offered first, so no roll stands between her and home.
	var st := _st(23, "svalich_crossroads")
	st.set_quest_stage("the_grey_mare", "asked")
	st.set_flag("decoy_given")
	var beats := SideQuestPlay.play(st, S + "grey_mare:mare", ["Swap the Winter Horse", "Not yet"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("soot-blackened Winter Horse"))


func test_stanimirs_fire_lost_is_a_dance_and_still_a_cask() -> void:
	var st := _st(20)
	var beats := SideQuestPlay.play(st, S + "stanimirs_fire:offer", ["Tell it plainly", "Tell it plainly"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("worst and most joyful dancing"), "no good round: Lavinia's stage")
	assert_eq(st.quest_stage("stanimirs_fire"), "done")
	assert_true(st.party_has_item("stanimirs_plum_wine"), "and the cask comes anyway")


func test_stanimirs_fire_won_by_two_rounds_and_tipped_by_an_entertainer() -> void:
	var st := SideQuestPlay.party(WREN_FOUR, 4, "tser_pool", 20)
	st.set_flag("fire_score", 1)
	var beats := SideQuestPlay.play(st, S + "stanimirs_fire:vote")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("shameless cheating"), "Wren works the crowd")
	assert_true(said.contains("Take the cask"))
	assert_eq(st.quest_stage("stanimirs_fire"), "done")
	var plain := _st(20)
	plain.set_flag("fire_score", 2)
	beats = SideQuestPlay.play(plain, S + "stanimirs_fire:vote")
	assert_true(SideQuestPlay.text(beats).contains("Take the cask"), "two good rounds win it without help")


func test_radus_unsellable_horse_to_costica() -> void:
	var st := _st(10)
	var beats := SideQuestPlay.play(st, S + "radus_horse:dinte", ["Look from a safe distance"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("That is Dinte"), "Radu makes his offer at the pen")
	assert_eq(st.quest_stage("radus_unsellable_horse"), "offered")
	st.location = "svalich_crossroads"
	beats = SideQuestPlay.play(st, S + "costica:menu", ["want a horse"])
	assert_true(SideQuestPlay.text(beats).contains("never been able to afford"), "not without the horse")
	assert_eq(st.quest_stage("radus_unsellable_horse"), "offered")
	SideQuestPlay.play(st, S + "radus_horse:dinte_lead")
	st.gold = 0
	beats = SideQuestPlay.play(st, S + "costica:menu", ["want a horse"])
	assert_true(SideQuestPlay.text(beats).contains("does not bite a single thing"))
	assert_eq(roundi(st.gold), 3)
	assert_eq(st.quest_stage("radus_unsellable_horse"), "buyer_found")
	assert_false(SideQuestPlay.shown(st, "tser_pool", "tser_dinte"), "Dinte is gone from the pen")
	st.location = "tser_pool"
	beats = SideQuestPlay.play(st, S + "tser_camp:radu")
	assert_true(SideQuestPlay.text(beats).contains("in my version you are all seven feet tall"))
	assert_eq(st.quest_stage("radus_unsellable_horse"), "sold")
	assert_eq(roundi(st.gold), 18, "three from Costica, fifteen from Radu")


func test_radus_unsellable_horse_to_fennimore() -> void:
	var st := _st(10, "svalich_crossroads")
	st.set_quest_stage("radus_unsellable_horse", "offered")
	st.set_flag("dinte_led")
	st.gold = 0
	var beats := SideQuestPlay.play(st, S + "fennimore:menu", ["horse for sale"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Dinte bites him on the waistcoat at once"))
	assert_eq(roundi(st.gold), 25)


func test_fennimores_guide_and_the_stew() -> void:
	var st := _st(10, "svalich_crossroads")
	assert_eq(SideQuestPlay.standing(st, "svalich_crossroads", "fennimore"), S + "fennimore:start")
	var beats := SideQuestPlay.play(st, S + "fennimore:start", ["May we see the book", "find out about the stew"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Wolves."), "the Blue Water Inn: two stars")
	assert_eq(st.quest_stage("fennimores_guide"), "asked")
	st.location = "tser_pool"
	beats = SideQuestPlay.play(st, S + "tser_camp:dorina", ["What is really in the pot", "Taste the stew"])
	assert_eq(SideQuestPlay.missing(beats), "", "no roll needed: tasting is enough")
	assert_true(SideQuestPlay.text(beats).contains("my silver wedding spoon slipped"))
	assert_eq(st.quest_stage("fennimores_guide"), "known")
	st.location = "svalich_crossroads"
	st.gold = 0
	beats = SideQuestPlay.play(st, S + "fennimore:start", ["what is in the stew"])
	assert_true(SideQuestPlay.text(beats).contains("Ask for the bottom."))
	assert_eq(st.quest_stage("fennimores_guide"), "done")
	assert_eq(roundi(st.gold), 10)


func test_costica_and_the_crossroads_by_day() -> void:
	var st := _st(10, "svalich_crossroads")
	assert_eq(SideQuestPlay.standing(st, "svalich_crossroads", "costica"), S + "costica:start")
	st.minute_of_day = 21 * 60
	assert_eq(SideQuestPlay.standing(st, "svalich_crossroads", "costica"), "", "he goes home to his lunch")
	st.minute_of_day = 10 * 60
	var said := SideQuestPlay.text(SideQuestPlay.play(st, S + "costica:start", ["Goodbye"]))
	assert_true(said.contains("As a professional highwayman"))
	assert_true(st.get_flag("costica_met", false))
	st.gold = 5
	said = SideQuestPlay.text(SideQuestPlay.play(st, S + "costica:start", ["Hand over two gold", "Goodbye"]))
	assert_true(said.contains("tax you twice in one afternoon"))
	assert_eq(roundi(st.gold), 3)
	said = SideQuestPlay.text(SideQuestPlay.play(st, S + "costica:start", ["walk past"]))
	assert_true(said.contains("should I have pitched my voice lower"), "walking past him is an ending, not a fight")


func test_the_camps_flavour() -> void:
	var st := _st(12)
	var said := SideQuestPlay.text(SideQuestPlay.play(st, S + "tser_camp:zora", ["About the cord"]))
	assert_true(said.contains("a knot for every stranger"))
	said = SideQuestPlay.text(SideQuestPlay.play(st, S + "tser_camp:zora", ["About the cord"]))
	assert_true(said.contains("Your knots are still tight"), "and the second time, the count")
	said = SideQuestPlay.text(SideQuestPlay.play(st, S + "tser_camp:petru", ["can't sharpen"]))
	assert_true(said.contains("iron nobody has been patient enough to teach"))
	SideQuestPlay.play(st, S + "tser_camp:dorina", ["What's in the pot"])
	said = SideQuestPlay.text(SideQuestPlay.play(st, S + "tser_camp:dorina", ["Tell us about the pot"]))
	assert_true(said.contains("A pot like this is a family"))
