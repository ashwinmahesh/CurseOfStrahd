extends TestCase
## The Sunsword's own lines (NPC plan Part D, docs/story/the_sunsword.md): it speaks only while somebody carries it, as a guest
## in the road banter, in a fight, at camp and in the count's scenes, and never says his name.

const PARTY: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "wren_featherfoot", "thistle"]
const FILES: Array[String] = ["res://narrative/banter/guest_sunsword.dialogue", "res://narrative/narrator/sunsword.dialogue",
	"res://narrative/camp/sunsword.dialogue", "res://narrative/strahd/attention.dialogue", "res://narrative/strahd/final.dialogue",
	"res://narrative/castle_ravenloft/gates_dinner.dialogue", "res://narrative/castle_ravenloft/catacombs_coffin.dialogue",
	"res://narrative/krezk/pool.dialogue"]


func _st(location: String = "vallaki", level: int = 6) -> StoryState:
	return SideQuestPlay.party(PARTY, level, location, 12)


func _carried(location: String = "vallaki", level: int = 6) -> StoryState:
	var st := _st(location, level)
	st.give_item("sunsword", 1, st.party[0])
	return st


func test_it_speaks_as_a_guest_only_while_carried() -> void:
	var st := _st()
	var b := Banter.new()
	for moment: String in ["enter", "fight", "idle"]:
		assert_true(b.guest_next(st, moment).is_empty(), "nobody carries it (%s)" % moment)
	st = _carried()
	b = Banter.new()
	var lines := b.guest_next(st, "enter")
	assert_false(lines.is_empty())
	assert_eq(str(lines[0]["speaker_id"]), "sunsword")
	assert_true(str(lines[0]["text"]).contains("dust on my pommel"), "found, and waking first")
	assert_true(st.get_flag("sunsword_woke", false))
	lines = b.guest_next(st, "enter")
	assert_true(str(lines[0]["text"]).contains("accept your service"), "then the attunement")
	assert_false(b.guest_next(st, "idle").is_empty(), "something on a long walk")


func test_in_the_stash_it_only_complains() -> void:
	var st := _st()
	st.give_item("sunsword", 1)   # the party's stash
	var b := Banter.new()
	assert_true(b.guest_next(st, "enter").is_empty())
	var lines := b.guest_next(st, "idle")
	assert_eq(lines.size(), 2)
	assert_true(str(lines[0]["text"]).contains("salt herring"))
	assert_true(b.guest_next(st, "idle").is_empty(), "once")


func test_it_knows_the_places_it_knows() -> void:
	var st := _carried("krezk_pool_of_the_white_sun")
	var b := Banter.new()
	b.guest_next(st, "enter")   # waking
	b.guest_next(st, "enter")   # attuning
	var lines := b.guest_next(st, "enter")
	assert_true(str(lines[0]["text"]).contains("I know this water"))
	st.location = "castle_ravenloft_catacombs_tombs"
	assert_true(str(b.guest_next(st, "enter")[0]["text"]).contains("Be quiet here"))


func test_a_crit_a_kill_and_a_fall_have_its_word() -> void:
	var st := _carried()
	var n := Narrator.new()
	for key: String in ["combat:crit", "combat:kill", "combat:fall", "combat:sunsword_start", "combat:sunsword_victory"]:
		var text := n.line(key, st, st.party[0], {"round": 1, "fight": "a"})
		assert_true(text.begins_with("Sunsword:"), "%s: %s" % [key, text])
	var plain := _st()
	assert_eq(Narrator.new().line("combat:sunsword_start", plain), "", "not unless it is carried")
	assert_false(Narrator.new().line("combat:crit", plain, plain.party[0], {"round": 1, "fight": "a"}).begins_with("Sunsword:"))


func test_a_camp_talk_about_being_broken() -> void:
	var low := _carried("vallaki", 7)
	assert_false(CampTalk.available(low).any(func(t: Dictionary) -> bool: return str(t["label"]) == "Sunsword wants a word"), "not before level 8")
	var st := _carried("vallaki", 8)
	var ref := ""
	for t: Dictionary in CampTalk.available(st):
		if str(t["label"]) == "Sunsword wants a word":
			ref = str(t["ref"])
	assert_ne(ref, "", "offered at level 8")
	# At camp it asks through whoever carries it (the camp seats an asker by id).
	assert_eq(CampSite.asker(st, ref), st.party[0].id)
	assert_eq(CampTalk.who_asks("item:sunsword and level >= 8", _st()), {}, "nobody carries it, nobody asks")
	var beats := SideQuestPlay.play(st, ref.replace("camp/sunsword:talk_fear", "camp/sunsword:fear"), ["steady on your grip"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("broken a second time"))


func test_it_answers_the_count_and_the_wedding_question() -> void:
	var st := _carried("castle_ravenloft_main_floor", 10)
	var beats := SideQuestPlay.play(st, "strahd/final:parley", ["Goodbye"])
	assert_true(SideQuestPlay.text(beats).contains("thief who outlived the witnesses"))
	beats = SideQuestPlay.play(st, "strahd/final:give_ireena")
	assert_true(SideQuestPlay.text(beats).contains("four feet of morning light"))
	beats = SideQuestPlay.play(st, "castle_ravenloft/catacombs_coffin:sunsword")
	assert_true(SideQuestPlay.text(beats).contains("It is done, my prince"))
	var plain := _st("castle_ravenloft_main_floor", 10)
	assert_false(SideQuestPlay.text(SideQuestPlay.play(plain, "strahd/final:give_ireena")).contains("four feet of morning light"), "only while carried")


func test_it_never_says_his_name_and_has_a_face() -> void:
	assert_true(ArtPaths.exists("art/portraits/sunsword.png"), "its portrait is the item's icon, larger")
	assert_false(Compendium.shared().get_entry("npcs", "sunsword").is_empty())
	for path: String in FILES:
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			if line.begins_with("Sunsword") or line.begins_with("| [item:sunsword]"):
				assert_false(line.contains("Strahd"), "%s: %s" % [path, line])
				assert_true(line.length() < 260, "%s: %s" % [path, line])
