extends TestCase
## The companions' personal quests (docs/story/personal_quests.md) and camp talks: each starts only with its pregen in
## the party, a custom hero in a pregen's place never answers for them, and stages never roll back.


func _party(without: String = "") -> StoryState:
	var st := StoryState.new()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		if id == without:
			st.party.append(_hero())
		else:
			st.party.append(Pregens.build(id, 5))
	return st


func _hero() -> Character:
	var b := CharacterBuilder.new(null, {"appearance": HeroLook.default_appearance("male", "fighter")})
	b.set_class("fighter")
	b.set_background("soldier")
	b.set_species("human")
	b.set_name("Ilse Varga")
	return b.preview()


## Runs a conversation to its end: option `pick` at the first menu, then the last option (the way out) at any later.
func _run(st: StoryState, ref: String, pick: int = 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start(ref), "starts " + ref)
	var b := r.next()
	var menus := 0
	for i in 200:
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


func test_the_arrival_starts_every_companions_quest() -> void:
	var st := _party()
	st.set_flag("mists_arrived", false)
	_run(st, "into_the_mists/arrival:hooks", 99)
	for q: String in ["kestrel_company", "the_locket", "cold_prayers", "aurels_last_chapter"]:
		assert_true(st.quests.has(q), q + " started")


func test_a_hero_in_ilses_place_starts_no_kestrel_quest() -> void:
	var st := _party("ilse_varga")
	_run(st, "into_the_mists/arrival:hooks", 99)
	assert_false(st.quests.has("kestrel_company"), "Ilse's quest needs Ilse")
	assert_true(st.quests.has("the_locket"), "Tamsin's still starts")
	assert_false(StoryConditions.check("name:ilse_varga", st), "the hero named Ilse Varga doesn't answer for her")
	var crossroads := Compendium.shared().get_entry("locations", "svalich_crossroads")
	for p: Variant in crossroads["props"]:
		if str((p as Dictionary)["id"]) == "kestrel_tally_crossroads":
			assert_false(StoryConditions.check(str((p as Dictionary)["when"]), st), "the tally is hidden without Ilse")


func test_stages_never_roll_back() -> void:
	var st := _party()
	st.set_quest_stage("kestrel_company", "the_letter")
	st.set_quest_stage("kestrel_company", "the_count")
	_run(st, "companions/kestrel:tally_crossroads")
	assert_eq(st.quest_stage("kestrel_company"), "the_count", "the first tally found late leaves the stage alone")
	assert_true(bool(st.get_flag("kestrel_tally_crossroads", false)), "but it was found")


func test_the_tallies_lead_to_jory() -> void:
	var st := _party()
	st.set_quest_stage("kestrel_company", "the_host")
	_run(st, "companions/kestrel:tally_crossroads")
	assert_eq(st.quest_stage("kestrel_company"), "the_tally")
	_run(st, "companions/kestrel:tally_tser")
	assert_eq(st.quest_stage("kestrel_company"), "the_count")
	_run(st, "companions/kestrel:jory", 0)
	assert_true(bool(st.get_flag("kestrel_jory_forgiven", false)), "Ilse forgave him")
	assert_true(bool(st.get_flag("kestrel_roll_kept", false)), "and has the roll")
	assert_eq(st.quest_stage("kestrel_company"), "the_deserter")


func test_the_locket_goes_to_sergei() -> void:
	var st := _party()
	st.set_quest_stage("the_locket", "her_name")
	var beats := _run(st, "companions/locket:pool", 0)
	assert_eq(str(st.get_flag("locket_fate", "")), "pool")
	assert_eq(st.quest_stage("the_locket"), "given_to_sergei")
	assert_true(beats.size() > 3, "the scene played")


func test_camp_talks_are_offered_once_and_only_with_their_companion() -> void:
	var st := _party()
	st.set_quest_stage("kestrel_company", "the_host")
	var talks := CampTalk.available(st)
	var refs: Array[String] = []
	for t in talks:
		refs.append(str(t["ref"]))
	assert_true("camp/ilse:talk_fever" in refs, "Ilse wants a word about the fever")
	for t in talks:
		if str(t["ref"]) == "camp/ilse:talk_fever":
			assert_eq(str(t["label"]), "Ilse wants a word")
	CampTalk.mark(st, "camp/ilse:talk_fever")
	for t in CampTalk.available(st):
		assert_ne(str(t["ref"]), "camp/ilse:talk_fever", "a talk plays once")
	var without := _party("ilse_varga")
	without.set_quest_stage("kestrel_company", "the_host")
	for t in CampTalk.available(without):
		assert_false(str(t["ref"]).begins_with("camp/ilse"), "no Ilse, no Ilse talks")


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
