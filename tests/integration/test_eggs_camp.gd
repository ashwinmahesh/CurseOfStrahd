extends TestCase
## Package R6a of the small-winks plan (docs/story/eggs.md, docs/plans/gemini_eggs/r6a/): companions at camp, on the
## road and in dreams. Thistle and the dancing bear, Wren's unfinished song (and the inn's night after it), Quillon's
## colleague in red, the thing behind Ratatouille's eye, two banters (a thrown chair, a friend whose heart ran too hot)
## and a dream at the Amber Temple. Each waits where the player has to look, none moves a main story flag, and every
## conversation they touch keeps its way out.

const SIX: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille", "wren_featherfoot",
	"kip_smudgewick"]
const NO_COOK: Array[String] = ["godrick_pendlebrook", "silvain_aster", "thistle", "wren_featherfoot"]


func before_each() -> void:
	Achievements.path = "user://test_eggs_camp_%d.json" % OS.get_process_id()
	DirAccess.remove_absolute(Achievements.path)
	Achievements.clear_cache()


func after_each() -> void:
	DirAccess.remove_absolute(Achievements.path)
	Achievements.path = ""
	Achievements.clear_cache()


func _st(ids: Array[String], level: int = 9) -> StoryState:
	return SideQuestPlay.party(ids, level, "vallaki_blue_water_inn", 22)


## A camp file's talks before `talk` count as had, so the next one it offers is the one under test.
func _mark_before(st: StoryState, file: String, talk: String) -> void:
	for node in DialogueFile.load_key("camp/" + file).order:
		if node == talk:
			return
		if node.begins_with("talk_"):
			CampTalk.mark(st, "camp/%s:%s" % [file, node])


func _offered(st: StoryState, file: String) -> String:
	return str(CampTalk.offered(DialogueFile.load_key("camp/" + file), st).get("ref", ""))


## The party after The Dancing Bear is done, so Thistle's talk starts.
func _bear_done() -> StoryState:
	var st := _st(SIX)
	st.set_quest_stage("the_dancing_bear", "done")
	return st


## The party that has been to Vallaki, so Wren's talk starts.
func _vallaki() -> StoryState:
	var st := _st(SIX)
	st.visited["vallaki"] = true
	return st


func _ends(beats: Array[Dictionary]) -> bool:
	return str(beats[-1]["kind"]) == "end"


func _inspired(st: StoryState) -> bool:
	return st.party.all(func(c: Character) -> bool: return c.heroic_inspiration)


## Seeds for a d20 check in a conversation that pass and fail it (the first of each).
func _seeds_for(st_maker: Callable, ref: String, picks: Array[String], flag: String) -> Dictionary:
	var out := {}
	for seed in range(1, 60):
		var st: StoryState = st_maker.call()
		SideQuestPlay.play(st, ref, picks, seed)
		var key := "pass" if bool(st.get_flag(flag, false)) else "fail"
		if not out.has(key):
			out[key] = seed
		if out.size() == 2:
			break
	return out


# --- 5b: Thistle and the bear ----------------------------------------------------------------------------------------

func test_thistle_has_been_thinking_about_bujor_once_the_dancing_bear_is_done() -> void:
	var st := _st(SIX)
	_mark_before(st, "thistle", "talk_bujor")
	assert_ne(_offered(st, "thistle"), "camp/thistle:talk_bujor", "not before the bear's own story is over")
	st.set_quest_stage("the_dancing_bear", "done")
	assert_eq(_offered(st, "thistle"), "camp/thistle:talk_bujor")
	var lucky := Approval.score(st, "thistle")
	var beats := SideQuestPlay.play(st, "camp/thistle:talk_bujor", ["lucky to have you"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(_ends(beats))
	assert_eq(Approval.score(st, "thistle"), lucky + 1, "a kind word earns a little")
	var sworn := _bear_done()
	var sworn_start := Approval.score(sworn, "thistle")
	var oath := SideQuestPlay.play(sworn, "camp/thistle:talk_bujor", ["I swear it"])
	assert_eq(SideQuestPlay.missing(oath), "")
	assert_eq(Approval.score(sworn, "thistle"), sworn_start + 1, "so does keeping her secret")
	var teased := _bear_done()
	var teased_start := Approval.score(teased, "thistle")
	var tease := SideQuestPlay.play(teased, "camp/thistle:talk_bujor", ["tambourine"])
	assert_eq(SideQuestPlay.missing(tease), "")
	assert_true(_ends(tease))
	assert_eq(Approval.score(teased, "thistle"), teased_start, "teasing her earns nothing")
	var bare := SideQuestPlay.play(_bear_done(), "camp/thistle:talk_bujor")
	assert_eq(SideQuestPlay.missing(bare), "")
	assert_true(_ends(bare), "with nothing picked, the menu still ends")
	assert_true(SideQuestPlay.text(bare).contains("Keep your mouth shut"), "and it was the talk that played")


func test_thistle_speaks_of_the_bear_who_went_home_or_the_one_who_stayed_on() -> void:
	var home := _bear_done()
	home.set_flag("bujor_home")
	assert_true(SideQuestPlay.text(SideQuestPlay.play(home, "camp/thistle:talk_bujor")).contains("share my fire"))
	var gone := SideQuestPlay.text(SideQuestPlay.play(_bear_done(), "camp/thistle:talk_bujor"))
	assert_true(gone.contains("trade a stage for the deep woods"), gone)


# --- 11: Wren's unfinished song --------------------------------------------------------------------------------------

func _song(st: StoryState, picks: Array[String]) -> Array[Dictionary]:
	return SideQuestPlay.play(st, "camp/wren:talk_song", picks)


func test_wren_asks_for_a_last_verse_once_the_party_has_been_to_vallaki() -> void:
	var st := _st(SIX)
	_mark_before(st, "wren", "talk_song")
	assert_ne(_offered(st, "wren"), "camp/wren:talk_song", "not before Vallaki")
	st.visited["vallaki"] = true
	assert_eq(_offered(st, "wren"), "camp/wren:talk_song")
	st.set_flag("eggs_song_sung")
	assert_ne(_offered(st, "wren"), "camp/wren:talk_song", "he sings it once")


func test_the_three_lines_the_party_picks_are_the_three_he_sings() -> void:
	var st := _vallaki()
	var beats := _song(st, ["Hopeful", "Grim", "Silly"] as Array[String])
	assert_eq(SideQuestPlay.missing(beats), "")
	var text := SideQuestPlay.text(beats)
	assert_true(text.contains("We walk the mist until the morning light,"), text)
	assert_true(text.contains("Where every shadow sharpens for a fight,"), text)
	assert_true(text.contains("And trade the gloom for supper and a bite."), text)
	assert_false(text.contains("starving night") or text.contains("burning warm and bright"), "and only those")
	assert_eq(str(st.get_flag("eggs_song_1", "")), "hope")
	assert_eq(str(st.get_flag("eggs_song_2", "")), "grim")
	assert_eq(str(st.get_flag("eggs_song_3", "")), "silly")
	assert_true(bool(st.get_flag("eggs_song_sung", false)))
	assert_true(_ends(beats))
	assert_true(_inspired(st), "the whole party earns Heroic Inspiration")
	var again := _vallaki()
	var start := Approval.score(again, "wren_featherfoot")
	_song(again, ["Silly", "Silly", "Silly"] as Array[String])
	assert_eq(Approval.score(again, "wren_featherfoot"), start + 2)


func test_wren_can_be_told_not_tonight_and_the_song_stays_unsung() -> void:
	var st := _vallaki()
	var beats := _song(st, ["Not tonight"] as Array[String])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(_ends(beats))
	assert_true(SideQuestPlay.text(beats).contains("Three lines"), "it was the talk that played")
	assert_false(bool(st.get_flag("eggs_song_sung", false)))
	assert_false(_inspired(st))
	var bare := _song(_vallaki(), [] as Array[String])
	assert_true(_ends(bare), "with nothing picked, the first menu ends it too")
	assert_false(bool(st.get_flag("eggs_song_1", false)), "and nothing is chosen")


func test_the_blue_water_inn_joins_in_the_next_night_once_and_encore_is_earned() -> void:
	var st := _st(SIX)
	var who := st.party[0]
	var before := Narrator.new(1).line("rest:long:vallaki_blue_water_inn", st, who)
	assert_false(before.contains("squinting fiddler"), "not before the song is finished")
	st.set_flag("eggs_song_sung")
	var narrator := Narrator.new(2)
	assert_true(narrator.line("rest:long:vallaki_blue_water_inn", st, who).contains("squinting fiddler"), "the room joins in")
	assert_false(narrator.line("rest:long:vallaki_blue_water_inn", st, who).contains("squinting fiddler"), "once")
	var toasts: Array[String] = []
	var say := func(t: String) -> void: toasts.append(t)
	assert_eq(Achievements.check_story(st, say), ["Encore"] as Array[String])
	assert_true(Achievements.has("encore"))
	var row := Achievements.all().filter(func(a: Dictionary) -> bool: return str(a["id"]) == "encore")
	assert_eq(str((row[0] as Dictionary)["name"]), "Encore")


# --- 12: Quillon's colleague in red ----------------------------------------------------------------------------------

func test_quillon_describes_a_rival_who_sings_his_contracts_and_the_scene_still_ends() -> void:
	var st := _st(SIX)
	st.set_quest_stage("the_fine_print", "the_contract")
	var beats := SideQuestPlay.play(st, "camp/kip:quillon", ["Are there others"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var text := SideQuestPlay.text(beats)
	assert_true(text.contains("crimson waistcoat") and text.contains("light opera"), text)
	assert_true(bool(st.get_flag("eggs_quillon_rivals", false)))
	assert_true(_ends(beats), "and he still goes")
	var again := _st(SIX)
	again.set_flag("eggs_quillon_rivals")
	var asked := SideQuestPlay.play(again, "camp/kip:quillon", ["Are there others"])
	assert_ne(SideQuestPlay.missing(asked), "", "he is asked once")
	var bare := SideQuestPlay.play(_st(SIX), "camp/kip:quillon")
	assert_true(_ends(bare), "with nothing picked, the old menu still ends")


# --- 18: something behind the eye ------------------------------------------------------------------------------------

## Level 3, so a DC 10 check can fail on some seeds.
func _cook() -> StoryState:
	var st := _st(SIX, 3)
	_mark_before(st, "ratatoille", "talk_eye")
	return st


func test_ratatouille_worries_about_his_eye_only_after_the_marsh_or_the_reeds() -> void:
	var st := _cook()
	assert_ne(_offered(st, "ratatoille"), "camp/ratatoille:talk_eye", "not before the water")
	st.visited["lake_inlet"] = true
	assert_eq(_offered(st, "ratatoille"), "camp/ratatoille:talk_eye")
	var other := _cook()
	other.visited["berez_marsh_track"] = true
	assert_eq(_offered(other, "ratatoille"), "camp/ratatoille:talk_eye")
	st.set_flag("eggs_eye_checked")
	assert_ne(_offered(st, "ratatoille"), "camp/ratatoille:talk_eye", "he is looked at once")


func test_a_leech_under_the_lid_is_found_by_a_pass_and_the_failure_leaves_a_way_out() -> void:
	var maker := func() -> StoryState: return _cook()
	var picks: Array[String] = ["Look under the lid"]
	var seeds := _seeds_for(maker, "camp/ratatoille:eye", picks, "eggs_eye_checked")
	assert_true(seeds.has("pass") and seeds.has("fail"), "the DC 10 check goes both ways across the seeds: %s" % [seeds])
	var failed := _cook()
	var beats := SideQuestPlay.play(failed, "camp/ratatoille:eye", ["Look under the lid", "Leave it for now"], int(seeds["fail"]))
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(_ends(beats), "a miss still lets you go")
	assert_false(bool(failed.get_flag("eggs_eye_checked", false)))
	assert_true(SideQuestPlay.text(beats).contains("trussing a pheasant"))
	var found := _cook()
	found.set_flag("fennimore_met")
	var found_start := Approval.score(found, "ratatoille")
	var win := SideQuestPlay.play(found, "camp/ratatoille:eye", ["Look under the lid", "keep it for the stewpot"], int(seeds["pass"]))
	assert_eq(SideQuestPlay.missing(win), "")
	assert_true(SideQuestPlay.text(win).contains("marsh leech"))
	assert_true(bool(found.get_flag("eggs_eye_checked", false)), "part three of the sky-man's three")
	assert_eq(Approval.score(found, "ratatoille"), found_start, "teasing him earns nothing")
	assert_true(_ends(win))
	var kind := _cook()
	var kind_start := Approval.score(kind, "ratatoille")
	SideQuestPlay.play(kind, "camp/ratatoille:eye", ["Look under the lid", "Sit, and breathe"], int(seeds["pass"]))
	assert_eq(Approval.score(kind, "ratatoille"), kind_start + 1, "comforting him earns a little")


func test_the_hairpin_idea_needs_the_travel_writer_met_and_loops_back_to_the_menu() -> void:
	var met := _cook()
	met.set_flag("fennimore_met")
	var beats := SideQuestPlay.play(met, "camp/ratatoille:eye", ["hairpin", "Leave it for now"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("reduce their eyebrows to cinders"))
	assert_true(_ends(beats))
	var unmet := SideQuestPlay.play(_cook(), "camp/ratatoille:eye", ["hairpin"])
	assert_ne(SideQuestPlay.missing(unmet), "", "no hairpin story from a man you haven't met")


func test_silvain_has_the_same_worry_when_there_is_no_cook_and_says_so_with_no_approval() -> void:
	var st := _st(NO_COOK, 3)
	_mark_before(st, "silvain", "talk_eye")
	assert_ne(_offered(st, "silvain"), "camp/silvain:talk_eye")
	st.visited["berez_marsh_track"] = true
	assert_eq(_offered(st, "silvain"), "camp/silvain:talk_eye")
	var with_cook := _st(SIX)
	with_cook.party.append(Pregens.build("silvain_aster", 9))
	_mark_before(with_cook, "silvain", "talk_eye")
	with_cook.visited["berez_marsh_track"] = true
	assert_ne(_offered(with_cook, "silvain"), "camp/silvain:talk_eye", "the cook's worry comes first")
	var maker := func() -> StoryState: return _st(NO_COOK, 3)
	var picks: Array[String] = ["Look under the lid"]
	var seeds := _seeds_for(maker, "camp/silvain:eye", picks, "eggs_eye_checked")
	assert_true(seeds.has("pass") and seeds.has("fail"), str(seeds))
	var ok := _st(NO_COOK, 3)
	var beats := SideQuestPlay.play(ok, "camp/silvain:eye", ["Look under the lid", "Sit, and breathe"], int(seeds["pass"]))
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(ok.get_flag("eggs_eye_checked", false)))
	assert_true(_ends(beats))
	var miss := SideQuestPlay.play(_st(NO_COOK, 3), "camp/silvain:eye", ["Look under the lid", "Leave it for now"], int(seeds["fail"]))
	assert_true(_ends(miss), "a miss still lets you go")


func test_the_eyes_talk_knows_the_jar_only_if_the_party_stood_in_the_tower() -> void:
	var st := _cook()
	var plain := SideQuestPlay.text(SideQuestPlay.play(st, "camp/ratatoille:eye"))
	assert_false(plain.contains("jar marked DO NOT"), plain)
	assert_true(plain.contains("swim up into a man's eye"), plain)
	st.visited["van_richtens_tower_interior"] = true
	var read := SideQuestPlay.text(SideQuestPlay.play(st, "camp/ratatoille:eye"))
	assert_true(read.contains("jar marked DO NOT"), read)


# --- S3 and 28: banter -----------------------------------------------------------------------------------------------

func _banter(st: StoryState, node: String) -> String:
	var all := ""
	for l: Dictionary in Banter._lines("banter/party_six:" + node, st):
		all += str(l["text"]) + "\n"
	return all


func test_two_pairs_argue_about_the_thrown_chair_only_after_one_was_thrown() -> void:
	var st := _st(["ilse_varga", "wren_featherfoot", "godrick_pendlebrook", "liriel_dawnsong"])
	assert_eq(_banter(st, "ilse_wren_chair"), "", "no chair yet")
	assert_eq(_banter(st, "godrick_liriel_chair"), "")
	st.set_flag("eggs_threw_furniture")
	assert_true(_banter(st, "ilse_wren_chair").contains("standard infantry doctrine"))
	assert_true(_banter(st, "godrick_liriel_chair").contains("Sir Pellam"))
	var alone := _st(["ilse_varga", "godrick_pendlebrook"])
	alone.set_flag("eggs_threw_furniture")
	assert_eq(_banter(alone, "ilse_wren_chair"), "", "it needs both of them there")


func test_godrick_tells_thistle_about_the_woman_whose_heart_ran_too_hot() -> void:
	var st := _st(SIX)
	var text := _banter(st, "godrick_thistle_heart")
	assert_true(text.contains("scorched gauntlet") and text.contains("Blisters and all"), text)
	var without := _st(["godrick_pendlebrook", "wren_featherfoot"])
	assert_eq(_banter(without, "godrick_thistle_heart"), "")


# --- 21: the visitor with a borrowed face ---------------------------------------------------------------------------------

func test_the_amber_temple_dream_changes_once_a_dark_gift_is_taken() -> void:
	var st := _st(SIX)
	var who := st.party[0]
	var plain := Narrator.new(1).line("dream:amber_temple", st, who)
	assert_false(plain.contains("borrowed") or plain.contains("stranger wearing"), "before any gift: the old dream")
	st.set_flag("dark_gifts_taken", 1)
	var narrator := Narrator.new(2)
	var dream := narrator.line("dream:amber_temple", st, who)
	assert_true(dream.contains("stranger wearing the face you most miss"), dream)
	assert_false(narrator.line("dream:amber_temple", st, who).contains("stranger wearing"), "once")


func test_the_winks_set_only_side_flags_and_register_them() -> void:
	var own: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/flags/eggs_camp.json"))
	var ids: Array = (own["flags"] as Array).map(func(f: Variant) -> String: return str((f as Dictionary)["id"]))
	assert_eq(ids, ["eggs_song_1", "eggs_song_2", "eggs_song_3", "eggs_song_sung", "eggs_eye_checked", "eggs_quillon_rivals"])
	for f: Variant in own["flags"]:
		var id := str((f as Dictionary)["id"])
		assert_eq(str((f as Dictionary)["type"]), "string" if id in ["eggs_song_1", "eggs_song_2", "eggs_song_3"] else "bool")
