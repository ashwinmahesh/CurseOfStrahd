extends TestCase
## The Dancing Bear (docs/story/side_quests.md): Lavinia on the plank stage from level 3, the broken chain, the deer
## path up the stream, Bujor over the trapped cub (the whistle, and Marin's mark on the trap), both endings, Lavinia's
## thanks and Old Marin's confession.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "wren_featherfoot", "thistle"]
const CAMP := "tser_pool"
const DEN := "tser_woods_den"


func _exit_open(st: StoryState, location: String, exit_id: String) -> bool:
	for e: Variant in Compendium.shared().get_entry("locations", location)["exits"]:
		if str((e as Dictionary)["id"]) == exit_id:
			return StoryConditions.check(str((e as Dictionary).get("when", "")), st)
	return false


func test_lavinia_has_lost_her_bear() -> void:
	var st := SideQuestPlay.party(FOUR, 2, CAMP, 14)
	var beats := SideQuestPlay.play(st, "svalich_road/tser_camp:lavinia")
	assert_true(SideQuestPlay.text(beats).contains("Clap or don't"), "her old line before level 3")
	st = SideQuestPlay.party(FOUR, 3, CAMP, 14)
	assert_false(_exit_open(st, CAMP, "deer_path_up"))
	beats = SideQuestPlay.play(st, "svalich_road/tser_camp:lavinia", ["Look at the broken chain"], 2)
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("Bujor's gone"))
	assert_true(said.contains("Two notes, high then low"))
	assert_eq(st.quest_stage("the_dancing_bear"), "asked")
	assert_true(st.get_flag("lavinia_whistle", false))
	assert_true(_exit_open(st, CAMP, "deer_path_up"))


func test_bujor_stands_over_the_cub() -> void:
	var st := SideQuestPlay.party(FOUR, 3, DEN, 14)
	st.set_quest_stage("the_dancing_bear", "asked")
	st.set_flag("lavinia_whistle")
	assert_eq(SideQuestPlay.standing(st, DEN, "bujor"), "svalich_road/the_dancing_bear:den")
	var beats := SideQuestPlay.play(st, "svalich_road/the_dancing_bear:den", ["Blow Lavinia's whistle", "Open the trap"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("three slow circles"))
	assert_true(said.contains("things that aren't trees"))
	assert_eq(SideQuestPlay.combat_of(beats), "den_blights")
	assert_true(SideQuestPlay.has_foe(SideQuestPlay.encounter(st, DEN, "den_blights"), "vine_blight"))
	beats = SideQuestPlay.play(st, "svalich_road/the_dancing_bear:trap")
	assert_true(SideQuestPlay.text(beats).contains("an M, with a notch through it"))
	assert_true(st.get_flag("bear_trap_marked", false))


func test_bujor_comes_home_with_the_cub() -> void:
	var st := SideQuestPlay.party(FOUR, 3, DEN, 14)
	st.set_quest_stage("the_dancing_bear", "defended")
	st.gold = 0
	var beats := SideQuestPlay.play(st, "svalich_road/the_dancing_bear:den", ["Lead him home"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("the_dancing_bear"), "found")
	assert_eq(SideQuestPlay.standing(st, DEN, "bujor"), "", "he's gone down the path")
	st.location = CAMP
	assert_eq(SideQuestPlay.standing(st, CAMP, "bujor"), "svalich_road/the_dancing_bear:stage")
	beats = SideQuestPlay.play(st, "svalich_road/tser_camp:lavinia")
	assert_true(SideQuestPlay.text(beats).contains("You brought me two"))
	assert_eq(st.quest_stage("the_dancing_bear"), "done")
	assert_true(st.party_has_item("wind_fan"))
	assert_eq(roundi(st.gold), 60)


func test_bujor_goes_into_the_den_and_marin_pulls_his_traps() -> void:
	var st := SideQuestPlay.party(FOUR, 3, DEN, 14)
	st.set_quest_stage("the_dancing_bear", "defended")
	st.set_flag("bear_trap_marked")
	var beats := SideQuestPlay.play(st, "svalich_road/the_dancing_bear:den", ["Let them go"])
	assert_true(SideQuestPlay.text(beats).contains("he doesn't look back"))
	st.location = CAMP
	assert_eq(SideQuestPlay.standing(st, CAMP, "bujor"), "")
	beats = SideQuestPlay.play(st, "svalich_road/tser_camp:lavinia", ["Tell her whose trap"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("a better dancer than me"))
	assert_true(said.contains("The black carriage pays for live young"))
	beats = SideQuestPlay.play(st, "svalich_road/tser_camp:marin", ["Your mark was on the trap"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("A gold piece a pound"))
	assert_true(st.get_flag("marin_traps_pulled", false))
	beats = SideQuestPlay.play(st, "svalich_road/tser_camp:marin")
	assert_true(SideQuestPlay.text(beats).contains("All eleven"))
