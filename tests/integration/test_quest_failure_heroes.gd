extends TestCase
## Side Quest Failure Plan, package F2: a companion's personal quest fails when the hero is lost for good (`fallen:<hero>`),
## Carry the Dawn fails when Liriel herself takes a dark gift (`gifted:liriel_dawnsong`, Ashwin 2026-10-19), the gift and
## altar pickers mark a name whose quest the pick would close, and three stuck states fixed in play close in older saves
## too (Escher's Petition, Exethanter's Notes, The Hunter's Tower).

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "thistle", "wren_featherfoot"]

## Each companion's quest, by the pregen whose quest it is.
const QUESTS := {
	"ratatoille": "a_seat_at_the_table", "silvain_aster": "aurels_last_chapter", "liriel_dawnsong": "carry_the_dawn",
	"hedda_ironvow": "cold_prayers", "thistle": "fens_trail", "ilse_varga": "kestrel_company",
	"kip_smudgewick": "the_fine_print", "godrick_pendlebrook": "the_ladle", "wren_featherfoot": "the_last_lesson",
	"tamsin_tealeaf": "the_locket",
}


func _st(party: Array[String] = FOUR) -> StoryState:
	return SideQuestPlay.party(party, 9, "amber_temple_vault", 12)


func _member(st: StoryState, id: String) -> Character:
	for ch in st.party:
		if ch.id == id:
			return ch
	return null


func _reload(st: StoryState) -> StoryState:
	return StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)


# --- A hero lost for good ------------------------------------------------------------------------------------------

func test_every_companion_quest_has_a_lost_ending_before_its_others() -> void:
	for hero: String in QUESTS:
		var qid := str(QUESTS[hero])
		var q := Compendium.shared().get_entry("quests", qid)
		var ids: Array = (q["stages"] as Array).map(func(s: Variant) -> String: return str((s as Dictionary)["id"]))
		var lost := ids.find("lost")
		assert_true(lost > 0, "%s has a `lost` stage" % qid)
		var stage := (q["stages"] as Array)[lost] as Dictionary
		assert_eq(str(stage["ends"]), "failure", "%s: lost is a failure" % qid)
		# Every success ending comes after it, so `quest.<id> >= <success>` never reads a lost hero as a finished one.
		for i in lost:
			assert_eq(str(((q["stages"] as Array)[i] as Dictionary).get("ends", "")), "", "%s: only open stages before lost" % qid)
		var rules := QuestClosures.rules(qid).filter(func(r: Dictionary) -> bool: return str(r["stage"]) == "lost")
		assert_eq(rules.size(), 1, "%s: one rule closes it" % qid)
		assert_eq(str(rules[0]["when"]), "fallen:%s" % hero)
		assert_true(bool(rules[0].get("old_saves", false)), "%s: an older save with the hero gone closes on load" % qid)


func test_a_hero_lost_for_good_fails_their_quest() -> void:
	var st := _st()
	st.set_quest_stage("fens_trail", "the_blazes")
	st.set_quest_stage("the_ladle", "the_order_found")
	assert_false(StoryConditions.check("fallen:thistle", st))
	st.lose_member(_member(st, "thistle"), "gave their life on the altar beneath Death House")
	assert_true(StoryConditions.check("fallen:thistle", st))
	assert_false(StoryConditions.check("fallen:godrick_pendlebrook", st), "only the one lost")
	assert_eq(QuestClosures.sweep(st), ["Quest failed: %s" % Compendium.shared().display_name("quests", "fens_trail")] as Array[String])
	assert_eq(st.quest_stage("fens_trail"), "lost")
	assert_eq(st.quest_stage("the_ladle"), "the_order_found", "Godrick's quest goes on")
	assert_false(StoryConditions.check("quest.fens_trail >= fen_cured", st), "a lost Thistle didn't cure anyone")


func test_a_dead_hero_awaiting_a_raise_keeps_their_quest() -> void:
	var st := _st()
	st.set_quest_stage("fens_trail", "the_blazes")
	var thistle := _member(st, "thistle")
	thistle.hp = 0
	thistle.dead = true
	assert_true(QuestClosures.sweep(st).is_empty(), "dead isn't lost: she can still be raised")
	assert_eq(st.quest_stage("fens_trail"), "the_blazes")


func test_an_older_save_with_the_hero_lost_closes_on_load() -> void:
	var st := _st()
	st.set_quest_stage("the_last_lesson", "the_brother")
	st.lose_member(_member(st, "wren_featherfoot"), "was taken by the Deck of Many Things")
	var back := _reload(st)
	assert_eq(back.quest_stage("the_last_lesson"), "lost", "journal only, as the save loads")


func test_the_lost_rule_is_valid_for_the_old_save_companions_too() -> void:
	var st := _st(["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"])
	st.set_quest_stage("kestrel_company", "the_host")
	st.set_quest_stage("the_locket", "her_face")
	st.lose_member(_member(st, "tamsin_tealeaf"), "gave their life on the altar beneath Death House")
	QuestClosures.sweep(st)
	assert_eq(st.quest_stage("the_locket"), "lost")
	assert_eq(st.quest_stage("kestrel_company"), "the_host")


# --- Liriel and the amber ------------------------------------------------------------------------------------------

func test_a_dark_gift_on_liriel_ends_carry_the_dawn() -> void:
	var st := _st()
	st.set_quest_stage("carry_the_dawn", "the_fall")
	_member(st, "thistle").accept_dark_gift("gift_of_fekre")
	assert_false(StoryConditions.check("gifted:liriel_dawnsong", st))
	assert_true(QuestClosures.sweep(st).is_empty(), "a gift on someone else changes nothing")
	_member(st, "liriel_dawnsong").accept_dark_gift("gift_of_zantras")
	assert_true(StoryConditions.check("gifted:liriel_dawnsong", st))
	assert_eq(QuestClosures.sweep(st), ["Quest failed: Carry the Dawn"] as Array[String])
	assert_eq(st.quest_stage("carry_the_dawn"), "dawn_lost")
	assert_false(SideQuestPlay.shown(st, "castle_ravenloft_chapel", "crg_chapel_dawn_step_liriel"),
		"the altar step never offers her the hymn")


func test_the_chapel_still_waits_for_a_liriel_who_kept_faith() -> void:
	var st := _st()
	st.set_quest_stage("carry_the_dawn", "faith_kept")
	assert_true(SideQuestPlay.shown(st, "castle_ravenloft_chapel", "crg_chapel_dawn_step_liriel"))


func test_the_journal_warns_once_the_temple_has_been_seen() -> void:
	var st := _st()
	st.set_quest_stage("carry_the_dawn", "the_angel")
	assert_eq(QuestClosures.warning(st, "carry_the_dawn"), "", "no talk of amber before the party has seen any")
	st.visited["amber_temple_entrance"] = true
	assert_eq(QuestClosures.warning(st, "carry_the_dawn"), "The things in the amber would gladly sell Liriel a darker fire.")


func test_liriel_says_so_at_the_first_voice_and_only_once() -> void:
	var st := _st()
	st.set_quest_stage("carry_the_dawn", "the_fall")
	var beats := SideQuestPlay.play(st, "amber_temple/vestiges:fekre_call")
	assert_true(SideQuestPlay.text(beats).contains("A light I bought from this amber"), SideQuestPlay.text(beats))
	assert_true(bool(st.get_flag("liriel_amber_warned")))
	var again := SideQuestPlay.play(st, "amber_temple/vestiges:zantras_call")
	assert_false(SideQuestPlay.text(again).contains("A light I bought from this amber"), "once")


func test_the_gift_picker_marks_liriel_and_no_one_else() -> void:
	var st := _st()
	st.set_quest_stage("carry_the_dawn", "the_fall")
	DialogueFile.register(DialogueFile.parse("~ offer\nNarrator: It offers.\ndark_gift gift_of_fekre\n-> END\n", "test/f2gift"))
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start("test/f2gift:offer"))
	assert_eq(str(r.next()["kind"]), "line")
	var pick := r.next()
	assert_eq(str(pick["kind"]), "pick_member")
	var ends := pick["ends"] as Array
	assert_eq(ends.size(), (pick["members"] as Array).size(), "one list per name, No one included")
	for i in st.party.size():
		var want: Array[String] = []
		if st.party[i].id == "liriel_dawnsong":
			want.append("Carry the Dawn")
		assert_eq(ends[i], want, st.party[i].id)
	assert_eq(ends[-1], [] as Array[String], "No one closes nothing")


func test_the_altar_marks_whoever_has_an_open_quest() -> void:
	var st := _st()
	st.set_quest_stage("fens_trail", "the_trail")
	st.set_quest_stage("the_ladle", "the_errand")
	DialogueFile.register(DialogueFile.parse("~ altar\nNarrator: The altar waits.\nsacrifice\n-> END\n", "test/f2altar"))
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start("test/f2altar:altar"))
	assert_eq(str(r.next()["kind"]), "line")
	var pick := r.next()
	assert_eq(str(pick["kind"]), "pick_member")
	for i in st.party.size():
		var id := st.party[i].id
		var want: Array[String] = []
		if id == "thistle":
			want = ["Grandda's Trail"]
		elif id == "godrick_pendlebrook":
			want = ["A Knight, More or Less"]
		assert_eq((pick["ends"] as Array)[i], want, id)


# --- Stuck states an older save may already be in --------------------------------------------------------------------

func test_escher_turned_on_in_an_older_save_closes_his_petition() -> void:
	var st := _st()
	st.set_quest_stage("escher_petition", "asked")
	st.set_flag("escher_fight_won")
	assert_eq(_reload(st).quest_stage("escher_petition"), "refused")
	var held := _st()
	held.set_quest_stage("escher_petition", "held")
	held.attitudes["escher"] = "hostile"
	assert_eq(_reload(held).quest_stage("escher_petition"), "refused")
	var kind := _st()
	kind.set_quest_stage("escher_petition", "asked")
	assert_eq(_reload(kind).quest_stage("escher_petition"), "asked", "a petition nobody spoiled waits for the roof")


func test_exethanters_notes_go_with_his_phylactery_in_an_older_save() -> void:
	var st := _st()
	st.set_quest_stage("exethanters_notes", "asked")
	st.set_flag("exethanter_phylactery", "smashed")
	assert_eq(_reload(st).quest_stage("exethanters_notes"), "lost")


func test_the_hunters_tower_ends_with_ezmerelda_along_in_an_older_save() -> void:
	var st := _st()
	st.set_quest_stage("the_hunters_tower", "inside")
	st.add_guest("ezmerelda")
	assert_eq(_reload(st).quest_stage("the_hunters_tower"), "with_her")
	var home := _st()
	home.set_quest_stage("the_hunters_tower", "inside")
	home.add_guest("ezmerelda")
	home.set_flag("rictavio_gone")
	assert_eq(_reload(home).quest_stage("the_hunters_tower"), "inside", "with Van Richten home, the reunion ends it")
