extends TestCase
## NPC depth, batch 6 (docs/plans/npc_depth_and_quests.md): Castle Ravenloft. The Boyar's Petition (four seals for four small
## things, then the Steward, then the Boyar), Gogu the gargoyle afraid of heights, the household's wants and secrets, the
## Goat in the great entry and Fennimore's last chapter. Nothing here needs a roll that has no way on.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "ratatoille", "thistle"]
const C := "castle_ravenloft/"


func _st(location: String = "castle_ravenloft_court", hour: int = 21) -> StoryState:
	return SideQuestPlay.party(FOUR, 10, location, hour)


func test_the_boyars_petition_four_seals_the_steward_and_the_boyar() -> void:
	var st := _st()
	var beats := SideQuestPlay.play(st, C + "household:crainic", ["What does a petition need"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("boyars_petition"), "asked")
	# Each servant lends a seal for one small thing, and the first "no" costs nothing.
	var asks: Array = [["household:ghenadie", "seal_valet", "Sit on the edge"], ["household:daskal", "seal_secretary", "Take the quill"],
		["household:nicodim", "seal_verger", "Stand by the font"], ["household:vlaicu", "seal_lamp", "Climb the stair"]]
	for row: Array in asks:
		beats = SideQuestPlay.play(st, C + str(row[0]), ["petition needs your seal", "Not just now"])
		assert_eq(SideQuestPlay.missing(beats), "", str(row[0]))
		assert_false(st.get_flag(str(row[1]), false), "not before they are asked to")
		beats = SideQuestPlay.play(st, C + str(row[0]), ["petition needs your seal", str(row[2])])
		assert_eq(SideQuestPlay.missing(beats), "", str(row[0]))
		assert_true(st.get_flag(str(row[1]), false), str(row[0]))
	assert_eq(int(st.get_flag("petition_seals", 0)), 4)
	SideQuestPlay.play(st, C + "household:crainic", ["We have the four seals"])
	assert_eq(st.quest_stage("boyars_petition"), "sealed")
	st.location = "castle_ravenloft_main_floor"
	SideQuestPlay.play(st, C + "gates_household:steward", ["sealed and wants receiving"])
	assert_eq(st.quest_stage("boyars_petition"), "received")
	var gold := st.gold
	st.location = "castle_ravenloft_court"
	beats = SideQuestPlay.play(st, C + "household:crainic", ["has received your petition"])
	assert_eq(st.quest_stage("boyars_petition"), "done")
	assert_eq(st.gold, gold + 120.0)
	assert_true(SideQuestPlay.text(beats).contains("Lake Zarovich"), "the stone is under the lake and he is satisfied")
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, C + "household:crainic", ["Leave him"])).contains("turnips"), "and afterwards")


func test_gogu_is_carried_down_and_his_ledge_changes() -> void:
	var st := _st("castle_ravenloft_spires_roofs", 14)
	assert_eq(SideQuestPlay.standing(st, "castle_ravenloft_spires_roofs", "gogu"), C + "gogu:start")
	assert_eq(SideQuestPlay.standing(st, "castle_ravenloft_gates", "gogu"), "")
	var beats := SideQuestPlay.play(st, C + "gogu:start", ["What do you want", "Do things fall", "carry you down", "Not just yet"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(st.get_flag("gogu_want_heard", false))
	# The lift is a roll, and a failed one is only a drop of two feet and a second try.
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, C + "gogu:carry_slip")).contains("two feet"))
	assert_false(st.get_flag("gogu_lowered", false))
	SideQuestPlay.play(st, C + "gogu:carry_ok")
	assert_true(st.get_flag("gogu_lowered", false))
	assert_eq(SideQuestPlay.standing(st, "castle_ravenloft_spires_roofs", "gogu"), "", "off the roof")
	assert_eq(SideQuestPlay.standing(st, "castle_ravenloft_gates", "gogu"), C + "gogu:low")
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, C + "gogu:low")).contains("ravens"))
	st = _st("castle_ravenloft_spires_roofs", 14)
	SideQuestPlay.play(st, C + "gogu:ravens")
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, C + "gogu:secret_ok")).contains("loose roof-slate"))
	assert_true(st.get_flag("gogu_secret_known", false))


func test_the_courts_wants_and_secrets() -> void:
	var st := _st("castle_ravenloft_main_floor")
	assert_ne(SideQuestPlay.missing(SideQuestPlay.play(st, C + "household:thale", ["your horses"])), "", "the horses come after the carriage")
	SideQuestPlay.play(st, C + "household:thale_doors")
	assert_true(st.get_flag("thale_carriage_known", false))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, C + "household:thale", ["your horses"])).contains("cards"))
	SideQuestPlay.play(st, C + "household:brandt_who")
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, C + "household:brandt_priest_ok")).contains("priest"))
	assert_true(st.get_flag("brandt_priest_known", false))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, C + "household:brandt_priest_miss")).length() > 10)
	SideQuestPlay.play(st, C + "gates_household:steward_staff")
	assert_true(st.get_flag("steward_staff_asked", false))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, C + "gates_household:steward_place_ok")).contains("laid a quiet place"))
	SideQuestPlay.play(st, C + "court_household:helga", ["What do you want most"])
	assert_true(st.get_flag("helga_want_heard", false))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, C + "court_household:helga_price_ok")).contains("ribbon"))
	SideQuestPlay.play(st, C + "household:celestine_described")
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, C + "household:celestine", ["made people laugh"])).contains("harpsichord"))


func test_lief_saved_the_gate_a_coin_a_year_and_the_dead_halberdier_takes_it() -> void:
	var st := _st("castle_ravenloft_court")
	SideQuestPlay.play(st, C + "court_lief:lief_inkwell_ok")
	assert_true(st.get_flag("lief_inkwell_known", false))
	SideQuestPlay.play(st, C + "court_lief:after_menu", ["forty-one coins"])
	assert_true(st.get_flag("lief_toll_given", false))
	st.location = "castle_ravenloft_gates"
	var beats := SideQuestPlay.play(st, C + "household:halberdier", ["Pay him the toll"])
	assert_true(st.get_flag("lief_toll_paid", false))
	assert_true(SideQuestPlay.text(beats).contains("forty coppers"))
	assert_ne(SideQuestPlay.missing(SideQuestPlay.play(st, C + "household:halberdier", ["Pay him the toll"])), "", "once")


func test_the_goat_in_the_great_entry_and_fennimores_last_chapter() -> void:
	var st := _st("castle_ravenloft_main_floor")
	assert_eq(SideQuestPlay.standing(st, "castle_ravenloft_main_floor", "barovia_goat"), C + "last_chapters:goat")
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, C + "last_chapters:goat")).contains("Hall Broom"))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, C + "last_chapters:goat_speaks")).contains("hunting scene"))
	var g := _st("castle_ravenloft_gates", 17)
	assert_eq(SideQuestPlay.standing(g, "castle_ravenloft_gates", "fennimore"), "", "not until his first chapter is done")
	g.set_quest_stage("fennimores_guide", "done")
	assert_eq(SideQuestPlay.standing(g, "castle_ravenloft_gates", "fennimore"), C + "last_chapters:fennimore")
	var beats := SideQuestPlay.play(g, C + "last_chapters:fennimore", ["How is the book", "going in"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Castle Ravenloft: two stars"))
	assert_true(g.get_flag("fennimore_castle_done", false))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(g, C + "last_chapters:fennimore")).contains("appendix"))
