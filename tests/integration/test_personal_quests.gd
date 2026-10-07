extends TestCase
## The six companions' personal quests (docs/story/personal_quests.md) and camp talks: each starts only with its
## pregen in the party, a custom hero in a pregen's place never answers for them, and stages never roll back.

const SIX: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille", "wren_featherfoot",
	"kip_smudgewick"]


func _party(without: String = "", level: int = 5) -> StoryState:
	var st := StoryState.new()
	for id in SIX:
		if id == without:
			st.party.append(_hero())
		else:
			st.party.append(Pregens.build(id, level))
	return st


func _hero() -> Character:
	# A custom hero (build.appearance.custom, the character creator's mark) who even took Thistle's name.
	var b := CharacterBuilder.new(null, {"appearance": {"custom": true, "art": "hero_02", "voice": "hero_female"}})
	b.set_class("ranger")
	b.set_background("guide")
	b.set_species("human")
	b.set_name("Thistle")
	return b.preview()


## Runs a conversation to its end: option `pick` at the first menu, then the last option (the way out) at any later.
func _run(st: StoryState, ref: String, pick: int = 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start(ref), "starts " + ref)
	var b := r.next()
	var menus := 0
	for i in 300:
		out.append(b)
		match str(b["kind"]):
			"end":
				break
			"options":
				var n := (b["options"] as Array).size()
				b = r.choose(mini(pick, n - 1) if menus == 0 else n - 1)
				menus += 1
			_:
				b = r.next()
	return out


func _texts(beats: Array[Dictionary]) -> String:
	var all := ""
	for b in beats:
		all += str(b.get("text", "")) + "\n"
	return all


func test_the_arrival_starts_every_companions_quest() -> void:
	var st := _party()
	_run(st, "into_the_mists/arrival:hooks", 99)
	for q: String in ["the_ladle", "carry_the_dawn", "fens_trail", "a_seat_at_the_table", "the_last_lesson",
			"the_fine_print"]:
		assert_true(st.quests.has(q), q + " started")


func test_a_hero_in_thistles_place_starts_no_trail() -> void:
	var st := _party("thistle")
	_run(st, "into_the_mists/arrival:hooks", 99)
	assert_false(st.quests.has("fens_trail"), "Thistle's quest needs Thistle")
	assert_true(st.quests.has("the_ladle"), "Godrick's still starts")
	assert_false(StoryConditions.check("name:thistle", st), "the hero named Thistle doesn't answer for her")
	var crossroads := Compendium.shared().get_entry("locations", "svalich_crossroads")
	for p: Variant in crossroads["props"]:
		if str((p as Dictionary)["id"]) == "fen_blaze_crossroads":
			assert_false(StoryConditions.check(str((p as Dictionary)["when"]), st), "the blaze is hidden without Thistle")


func test_stages_never_roll_back() -> void:
	var st := _party()
	st.set_quest_stage("fens_trail", "the_trail")
	st.set_quest_stage("fens_trail", "the_wolf_road")
	_run(st, "companions/fen:blaze_crossroads")
	assert_eq(st.quest_stage("fens_trail"), "the_wolf_road", "the first blaze found late leaves the stage alone")
	assert_true(bool(st.get_flag("fen_blaze_crossroads", false)), "but it was found")


func test_fen_can_be_cured_by_whoever_knows_remove_curse() -> void:
	var st := _party("", 6)
	var liriel := st.find_member("name:liriel_dawnsong")
	assert_true(liriel.knows_spell("remove_curse"), "Liriel prepares Remove Curse by level 6")
	assert_true(StoryConditions.check("knows:remove_curse", st))
	st.set_quest_stage("fens_trail", "the_wolf_road")
	_run(st, "companions/fen:start", 0)
	assert_eq(str(st.get_flag("fen_fate", "")), "cured")
	assert_eq(st.quest_stage("fens_trail"), "fen_cured")


func test_godrick_is_knighted_once_the_order_remembers() -> void:
	var st := _party()
	st.set_quest_stage("the_ladle", "kept_faith")
	st.set_flag("godfrey_remembers", true)
	assert_false(st.party_has_item("weapon_plus_1"))
	var beats := _run(st, "companions/ladle:knighting")
	assert_eq(st.quest_stage("the_ladle"), "knighted")
	assert_true(_texts(beats).contains("ladle"), "the ladle comes up")
	assert_true(st.party_has_item("weapon_plus_1"), "Aldric's sword is his")


func test_kips_way_out_is_read_then_paid() -> void:
	var st := _party()
	st.set_quest_stage("the_fine_print", "the_assessor")
	var refs: Array[String] = []
	for t in CampTalk.available(st):
		refs.append(str(t["ref"]))
	assert_true("camp/kip:talk_reading" in refs, "Kip asks for help reading it")
	_run(st, "camp/kip:talk_reading")
	assert_eq(st.quest_stage("the_fine_print"), "the_small_print", "Ratatoille reads the clause")
	refs.clear()
	for t in CampTalk.available(st):
		refs.append(str(t["ref"]))
	assert_false("camp/kip:talk_settle" in refs, "no signature yet")
	st.set_flag("strahd_letter_kept", true)
	refs.clear()
	for t in CampTalk.available(st):
		refs.append(str(t["ref"]))
	assert_true("camp/kip:talk_settle" in refs, "the kept letter is Strahd's signature, freely given")
	_run(st, "camp/kip:talk_settle")
	assert_eq(st.quest_stage("the_fine_print"), "free")
	assert_true(bool(st.get_flag("kip_contract_void", false)))
	assert_false(bool(st.get_flag("strahd_letter_kept", false)), "Quillon took the letter")


func test_wren_learns_the_last_lesson_at_rahadin() -> void:
	var st := _party()
	st.set_quest_stage("the_last_lesson", "the_brother")
	_run(st, "companions/lesson:rahadin", 0)
	assert_eq(st.quest_stage("the_last_lesson"), "learned")


func test_camp_talks_are_offered_once_and_only_with_their_companion() -> void:
	var st := _party()
	st.set_quest_stage("the_ladle", "the_errand")
	var found := false
	for t in CampTalk.available(st):
		if str(t["ref"]) == "camp/godrick:talk_ladle":
			found = true
			assert_eq(str(t["label"]), "Godrick wants a word")
	assert_true(found, "Godrick wants a word about the ladle")
	CampTalk.mark(st, "camp/godrick:talk_ladle")
	for t in CampTalk.available(st):
		assert_ne(str(t["ref"]), "camp/godrick:talk_ladle", "a talk plays once")
	var without := _party("thistle")
	without.set_quest_stage("fens_trail", "the_trail")
	for t in CampTalk.available(without):
		assert_false(str(t["ref"]).begins_with("camp/thistle"), "no Thistle, no Thistle talks")


func test_every_camp_talk_opens_with_a_condition() -> void:
	for f in DirAccess.get_files_at(DialogueFile.ROOT + "camp"):
		if not f.ends_with(".dialogue"):
			continue
		var df := DialogueFile.load_key("camp/" + f.get_basename())
		assert_true(df != null and df.errors.is_empty(), "camp/%s parses" % f)
		var talks := 0
		for node in df.order:
			if node.begins_with("talk_"):
				talks += 1
				assert_true(CampTalk.opening_condition(df, node).contains("name:"), "%s:%s names its companion" % [f, node])
		assert_true(talks >= 2, "%s has talks" % f)


func test_an_old_save_keeps_the_first_fours_quests() -> void:
	# Owner (2026-10-06): the first four's data stays so saves from before the six still play; a quest whose data is
	# gone altogether is skipped rather than breaking the journal.
	var st := StoryState.new()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		st.party.append(Pregens.build(id, 3))
	_run(st, "into_the_mists/arrival:hooks", 99)
	st.quests["a_quest_nobody_wrote"] = {"stage": "begun", "history": ["begun"]}
	var back := StoryState.from_dict(st.to_dict())
	var ids: Array[String] = []
	for q in QuestLog.journal(back):
		ids.append(str(q["id"]))
	for q: String in ["kestrel_company", "the_locket", "cold_prayers", "aurels_last_chapter"]:
		assert_true(q in ids, q + " is still in the journal")
	assert_false("a_quest_nobody_wrote" in ids)
	assert_false(StoryConditions.check("name:thistle", back), "none of the six joins an old party")
