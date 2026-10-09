extends TestCase
## The Drowned Library (docs/story/side_quests.md): Mordenkainen's dream once Khazan is unmade, the well-head on the
## shore of Lake Baratok, Xaver on top of the bookcase, the catalogue desk, and what's in its drawers.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "ratatoille", "thistle"]
const LIBRARY := "drowned_library"


func _exit_open(st: StoryState, location: String, exit_id: String) -> bool:
	for e: Variant in Compendium.shared().get_entry("locations", location)["exits"]:
		if str((e as Dictionary)["id"]) == exit_id:
			return StoryConditions.check(str((e as Dictionary).get("when", "")), st)
	return false


func test_mordenkainen_dreams_of_a_voice_up_a_well() -> void:
	var st := SideQuestPlay.party(FOUR, 10, "mount_baratok_hut", 14)
	st.set_flag("mordenkainen_restored")
	st.set_flag("corvina_name_known")
	st.set_quest_stage("the_name_over_the_door", "unmade")
	var beats := SideQuestPlay.play(st, "mount_baratok/the_mages_lost_pages:news")
	assert_true(SideQuestPlay.text(beats).contains("a voice coming up a well"))
	assert_eq(st.quest_stage("the_drowned_library"), "rumored")


func test_the_well_head_whispers() -> void:
	var st := SideQuestPlay.party(FOUR, 8, "van_richtens_tower", 14)
	assert_false(SideQuestPlay.shown(st, "van_richtens_tower", "vrt_wellhead"), "not before level 9")
	st = SideQuestPlay.party(FOUR, 9, "van_richtens_tower", 14)
	assert_true(SideQuestPlay.shown(st, "van_richtens_tower", "vrt_wellhead"))
	assert_false(_exit_open(st, "van_richtens_tower", "vrt_well_down"))
	var beats := SideQuestPlay.play(st, "van_richtens_tower/the_drowned_library:wellhead")
	assert_true(SideQuestPlay.text(beats).contains("Don't touch the desk"))
	assert_eq(st.quest_stage("the_drowned_library"), "asked")
	assert_true(_exit_open(st, "van_richtens_tower", "vrt_well_down"))


func test_xaver_and_the_desk() -> void:
	var st := SideQuestPlay.party(FOUR, 9, LIBRARY, 14)
	st.set_quest_stage("the_drowned_library", "asked")
	assert_eq(SideQuestPlay.standing(st, LIBRARY, "library_xaver"), "van_richtens_tower/the_drowned_library:xaver")
	var beats := SideQuestPlay.play(st, "van_richtens_tower/the_drowned_library:xaver", ["What happened to you", "Leave him"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("because it doesn't climb"))
	assert_true(said.contains("It's never been me"))
	beats = SideQuestPlay.play(st, "van_richtens_tower/the_drowned_library:desk", ["Open a drawer"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Every one of them has teeth"))
	assert_eq(SideQuestPlay.combat_of(beats), "the_index")
	var enc := SideQuestPlay.encounter(st, LIBRARY, "the_index")
	assert_true(SideQuestPlay.has_foe(enc, "the_index"))
	assert_true(SideQuestPlay.has_foe(enc, "A Reading Chair"))


func test_xaver_comes_down() -> void:
	var st := SideQuestPlay.party(FOUR, 9, LIBRARY, 14)
	st.set_quest_stage("the_drowned_library", "unfiled")
	st.set_flag("index_destroyed")
	st.set_flag("mordenkainen_restored")
	st.gold = 0
	var beats := SideQuestPlay.play(st, "van_richtens_tower/the_drowned_library:xaver")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("Do you know how big this room is"))
	assert_true(said.contains("tell the old man up the mountain"))
	assert_eq(st.quest_stage("the_drowned_library"), "done")
	assert_true(st.party_has_item("manual_of_quickness_of_action"))
	assert_eq(roundi(st.gold), 350)
	beats = SideQuestPlay.play(st, "van_richtens_tower/the_drowned_library:xaver")
	assert_true(SideQuestPlay.text(beats).contains("I've never read this one"))
