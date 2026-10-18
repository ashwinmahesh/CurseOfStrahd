extends TestCase
## The Tser Pool camp turning on the party (Side Quest Failure Plan, package T1; QA round 7): the four quests that end
## with a camp NPC who is gone once `tser_pool_brawl_won` or `vistani_turned_hostile` is set (Called by Name, The
## Dancing Bear, The Grey Mare, The Hanged Man at the Crossroads) each find a way on or close as a failure at a place the
## party can still reach: Nelu among the Vallaki Vistani, the empty plank stage, the empty pen, and Arrigal taking Nicu's
## news. Side quests only read the camp's flags; none of these sets a main flag.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "ratatoille", "thistle"]
const S := "svalich_road/"
const POOL := "tser_pool"
const VISTANI := "vallaki_vistani_camp"
const GONE: Array[String] = ["tser_pool_brawl_won", "vistani_turned_hostile"]


func _st(location: String = POOL, hour: int = 10, level: int = 5) -> StoryState:
	return SideQuestPlay.party(FOUR, level, location, hour)


func _stage_ends(quest_id: String, stage_id: String) -> String:
	for s: Variant in Compendium.shared().get_entry("quests", quest_id)["stages"]:
		if str((s as Dictionary)["id"]) == stage_id:
			return str((s as Dictionary).get("ends", ""))
	return "missing"


# --- Called by Name ------------------------------------------------------------------------------------------------

func test_nelu_is_among_the_vallaki_vistani_when_there_is_no_fire_to_bring_him_to() -> void:
	for flag: String in GONE:
		var st := _st(VISTANI)
		st.set_quest_stage("called_by_name", "nelu_found")
		st.set_flag("nelu_saved")
		assert_eq(SideQuestPlay.standing(st, VISTANI, "tser_nelu"), "", "%s: while Tobar's camp stands he goes home to it" % flag + " (flag unset)")
		st.set_flag(flag)
		assert_eq(SideQuestPlay.standing(st, POOL, "tser_tobar"), "", "%s: Tobar is not there to take him" % flag)
		assert_eq(SideQuestPlay.standing(st, VISTANI, "tser_nelu"), S + "called_by_name:nelu_away", "%s: so he waits at the other camp" % flag)
		var beats := SideQuestPlay.play(st, S + "called_by_name:nelu_away")
		assert_eq(SideQuestPlay.missing(beats), "")
		assert_eq(st.quest_stage("called_by_name"), "no_fire", "%s: the quest closes" % flag)
		assert_eq(_stage_ends("called_by_name", "no_fire"), "failure")
		assert_eq(SideQuestPlay.combat_of(beats), "")
		assert_eq(SideQuestPlay.standing(st, VISTANI, "tser_nelu"), S + "called_by_name:nelu_away", "and he stays")
		var again := SideQuestPlay.text(SideQuestPlay.play(st, S + "called_by_name:nelu_away"))
		assert_false(again == "", "%s: he has something to say on a later visit" % flag)
		assert_eq(st.quest_stage("called_by_name"), "no_fire")


func test_nelu_is_only_at_the_vallaki_camp_for_a_quest_that_got_him_out() -> void:
	var st := _st(VISTANI)
	st.set_flag("tser_pool_brawl_won")
	assert_eq(SideQuestPlay.standing(st, VISTANI, "tser_nelu"), "", "never rescued: he is still on the ledge")
	st.set_quest_stage("called_by_name", "asked")
	assert_eq(SideQuestPlay.standing(st, VISTANI, "tser_nelu"), "")
	var home := _st(VISTANI)
	home.set_flag("tser_pool_brawl_won")
	home.set_flag("nelu_saved")
	home.set_quest_stage("called_by_name", "home")
	assert_eq(SideQuestPlay.standing(home, VISTANI, "tser_nelu"), "", "already home before the camp turned: nothing to close")


func test_a_camp_that_still_stands_takes_nelu_the_old_way() -> void:
	var st := _st(POOL)
	st.set_quest_stage("called_by_name", "nelu_found")
	st.set_flag("nelu_saved")
	st.gold = 0
	SideQuestPlay.play(st, S + "tser_camp:tobar")
	assert_eq(st.quest_stage("called_by_name"), "home")
	assert_eq(roundi(st.gold), 100)


# --- The Dancing Bear ----------------------------------------------------------------------------------------------

func test_with_no_stage_to_bring_him_to_bujor_stays_in_the_den() -> void:
	for flag: String in GONE:
		var st := _st("tser_woods_den")
		st.set_quest_stage("the_dancing_bear", "defended")
		st.set_flag(flag)
		var beats := SideQuestPlay.play(st, S + "the_dancing_bear:den", ["Lead him home"])
		assert_ne(SideQuestPlay.missing(beats), "", "%s: there is nobody at the stage to lead him home to" % flag)
		assert_eq(st.quest_stage("the_dancing_bear"), "defended")
		beats = SideQuestPlay.play(st, S + "the_dancing_bear:den", ["Let them go into the den"])
		assert_eq(SideQuestPlay.missing(beats), "", flag)
		assert_eq(st.quest_stage("the_dancing_bear"), "no_stage", "%s: the cub and Bujor go in, the quest closes" % flag)
		assert_eq(_stage_ends("the_dancing_bear", "no_stage"), "failure")
		assert_true(st.get_flag("bujor_free", false))


func test_a_standing_camp_still_takes_bujor_home_or_lets_him_go() -> void:
	for pick: String in ["Lead him home", "Let them go into the den"]:
		var st := _st("tser_woods_den")
		st.set_quest_stage("the_dancing_bear", "defended")
		var beats := SideQuestPlay.play(st, S + "the_dancing_bear:den", [pick])
		assert_eq(SideQuestPlay.missing(beats), "", pick)
		assert_eq(st.quest_stage("the_dancing_bear"), "found", pick)


func test_the_empty_plank_stage_closes_a_dancing_bear_that_was_waiting_for_lavinia() -> void:
	for flag: String in GONE:
		var st := _st(POOL)
		st.set_quest_stage("the_dancing_bear", "found")
		assert_false(SideQuestPlay.shown(st, POOL, "tser_stage_empty"), "a camp that stands has Lavinia on it")
		st.set_flag(flag)
		assert_true(SideQuestPlay.shown(st, POOL, "tser_stage_empty"), flag)
		var beats := SideQuestPlay.play(st, S + "the_dancing_bear:stage_empty")
		assert_eq(SideQuestPlay.missing(beats), "")
		assert_eq(st.quest_stage("the_dancing_bear"), "no_stage", flag)
	var done := _st(POOL)
	done.set_flag("tser_pool_brawl_won")
	done.set_quest_stage("the_dancing_bear", "done")
	assert_false(SideQuestPlay.shown(done, POOL, "tser_stage_empty"), "nothing to close once it is done")
	var none := _st(POOL)
	none.set_flag("tser_pool_brawl_won")
	assert_false(SideQuestPlay.shown(none, POOL, "tser_stage_empty"), "or when it was never taken")


# --- The Grey Mare -------------------------------------------------------------------------------------------------

func test_steaua_saved_is_found_in_the_empty_pen() -> void:
	for flag: String in GONE:
		var st := _st(POOL)
		st.set_quest_stage("the_grey_mare", "carriage_beaten")
		st.set_flag("mare_saved")
		st.gold = 0
		assert_false(SideQuestPlay.shown(st, POOL, "tser_pen_empty"), "Radu's camp stands: Radu has the pen")
		st.set_flag(flag)
		assert_eq(SideQuestPlay.standing(st, POOL, "tser_radu"), "", "Radu is gone")
		assert_true(SideQuestPlay.shown(st, POOL, "tser_pen_empty"), flag)
		var beats := SideQuestPlay.play(st, S + "grey_mare:pen_empty")
		assert_eq(SideQuestPlay.missing(beats), "")
		assert_eq(st.quest_stage("the_grey_mare"), "home", "%s: grey and alone in the pen is still home" % flag)
		assert_eq(roundi(st.gold), 120, "the castle's purse is still in the pen; the bride-price rod went with Radu")
		assert_false(st.party_has_item("rod_of_the_pact_keeper_plus_1"))
		assert_false(SideQuestPlay.shown(st, POOL, "tser_pen_empty"), "and it is done")


func test_steaua_lost_leaves_an_empty_pen_and_a_closed_quest() -> void:
	var st := _st(POOL)
	st.set_flag("tser_pool_brawl_won")
	st.set_quest_stage("the_grey_mare", "carriage_beaten")
	st.set_flag("mare_lost")
	st.gold = 0
	assert_true(SideQuestPlay.shown(st, POOL, "tser_pen_empty"))
	var beats := SideQuestPlay.play(st, S + "grey_mare:pen_empty")
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("the_grey_mare"), "empty_pen")
	assert_eq(_stage_ends("the_grey_mare", "empty_pen"), "failure")
	assert_eq(roundi(st.gold), 0, "nobody pays for a mare nobody can tell")
	assert_false(SideQuestPlay.shown(st, POOL, "tser_pen_empty"))


func test_radu_still_pays_for_the_mare_when_his_camp_stands() -> void:
	var st := _st(POOL)
	st.set_quest_stage("the_grey_mare", "carriage_beaten")
	st.set_flag("mare_saved")
	st.set_flag("carriage_beaten")
	st.gold = 0
	SideQuestPlay.play(st, S + "tser_camp:radu", ["yours, Radu"])
	assert_eq(st.quest_stage("the_grey_mare"), "home")
	assert_eq(roundi(st.gold), 120)


# --- The Hanged Man at the Crossroads ------------------------------------------------------------------------------

func test_arrigal_takes_nicus_news_when_the_camp_that_wanted_it_is_gone() -> void:
	for stage: String in ["buried", "risen"]:
		var st := _st(VISTANI)
		st.set_quest_stage("the_hanged_vistana", stage)
		var beats := SideQuestPlay.play(st, "vallaki/vistani_camp:arrigal", ["what became of Nicu"])
		assert_ne(SideQuestPlay.missing(beats), "", "%s: while Luminita and Stanimir are at the pool they are told first" % stage)
		assert_eq(st.quest_stage("the_hanged_vistana"), stage)
		st.set_flag("tser_pool_brawl_won")
		beats = SideQuestPlay.play(st, "vallaki/vistani_camp:arrigal", ["what became of Nicu"])
		assert_eq(SideQuestPlay.missing(beats), "", stage)
		assert_eq(st.quest_stage("the_hanged_vistana"), "told", "%s: the Vallaki Vistani take the news" % stage)
		assert_true(st.get_flag("nicu_kin_told", false))
		assert_eq(SideQuestPlay.combat_of(beats), "")


func test_arrigal_has_no_news_to_take_for_a_man_nobody_found() -> void:
	var st := _st(VISTANI)
	st.set_flag("tser_pool_brawl_won")
	st.set_quest_stage("the_hanged_vistana", "asked")
	var beats := SideQuestPlay.play(st, "vallaki/vistani_camp:arrigal", ["what became of Nicu"])
	assert_ne(SideQuestPlay.missing(beats), "", "nothing to tell before the crossroads")
	assert_eq(st.quest_stage("the_hanged_vistana"), "asked")


func test_luminita_still_hears_it_first_when_her_camp_stands() -> void:
	var st := _st(POOL)
	st.set_quest_stage("the_hanged_vistana", "buried")
	st.set_flag("nicu_cut_down")
	assert_eq(SideQuestPlay.standing(st, POOL, "luminita"), S + "luminita:start")
	SideQuestPlay.play(st, S + "luminita:start", ["Hanged"])
	assert_eq(st.quest_stage("the_hanged_vistana"), "told")
