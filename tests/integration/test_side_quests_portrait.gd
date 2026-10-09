extends TestCase
## The Count's Portraitist (docs/story/side_quests.md): Haralamb at his door on the east row in the evening, his eleven
## nights at the castle and the paint on his hands, the studio door, the count speaking out of the great canvas, and
## Haralamb's thanks once it has burned.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "ratatoille", "thistle"]


func _exit_open(st: StoryState, location: String, exit_id: String) -> bool:
	for e: Variant in Compendium.shared().get_entry("locations", location)["exits"]:
		if str((e as Dictionary)["id"]) == exit_id:
			return StoryConditions.check(str((e as Dictionary).get("when", "")), st)
	return false


func test_haralamb_at_his_door() -> void:
	var st := SideQuestPlay.party(FOUR, 8, "vallaki", 19)
	assert_ne(SideQuestPlay.standing(st, "vallaki", "vallaki_sun_painter"), "vallaki/the_counts_portraitist:painter", "not before level 9")
	st = SideQuestPlay.party(FOUR, 9, "vallaki", 19)
	assert_eq(SideQuestPlay.standing(st, "vallaki", "vallaki_sun_painter"), "vallaki/the_counts_portraitist:painter")
	assert_false(_exit_open(st, "vallaki", "painter_door"))
	var beats := SideQuestPlay.play(st, "vallaki/the_counts_portraitist:painter", ["Your hands", "Look at the paint"], 4)
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("Eleven nights"))
	assert_true(said.contains("The big one's against the far wall"))
	assert_eq(st.quest_stage("the_counts_portraitist"), "asked")
	assert_true(_exit_open(st, "vallaki", "painter_door"))


func test_the_count_speaks_out_of_the_canvas() -> void:
	var st := SideQuestPlay.party(FOUR, 9, "vallaki_painters_studio", 20)
	st.set_quest_stage("the_counts_portraitist", "asked")
	st.set_flag("likeness_known")
	var beats := SideQuestPlay.play(st, "vallaki/the_counts_portraitist:canvas", ["Who are you talking to"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("Tell Haralamb his work pleases me"))
	assert_true(said.contains("A window"))
	assert_eq(SideQuestPlay.combat_of(beats), "counts_likeness")
	assert_true(SideQuestPlay.has_foe(SideQuestPlay.encounter(st, "vallaki_painters_studio", "counts_likeness"), "the_counts_likeness"))


func test_haralambs_thanks() -> void:
	var st := SideQuestPlay.party(FOUR, 9, "vallaki", 19)
	st.set_quest_stage("the_counts_portraitist", "burned")
	st.set_flag("painter_told")
	st.set_flag("likeness_burned")
	st.gold = 0
	var beats := SideQuestPlay.play(st, "vallaki/the_counts_portraitist:painter")
	assert_true(SideQuestPlay.text(beats).contains("a very bad varnish"))
	assert_eq(st.quest_stage("the_counts_portraitist"), "done")
	assert_true(st.party_has_item("marvelous_pigments"))
	assert_eq(roundi(st.gold), 150)
	beats = SideQuestPlay.play(st, "vallaki/the_counts_portraitist:painter")
	assert_true(SideQuestPlay.text(beats).contains("came out looking like a dog"))
	st.location = "vallaki_painters_studio"
	beats = SideQuestPlay.play(st, "vallaki/the_counts_portraitist:canvas")
	assert_true(SideQuestPlay.text(beats).contains("nothing in it"))
