extends TestCase
## Ireena at camp and in the fights she watches (Story Allies Presence Plan, package I4; narrative/camp/ireena.dialogue,
## narrative/banter/guest_ireena.dialogue, narrative/narrator/keeps_back.dialogue, docs/story/ireena_camp.md). While she travels
## with the party, a Long Rest at camp can bring seven talks, each once and the later part of the story first: the night before
## the castle, the Amber Temple's gift, the Pool of the White Sun, Izek's truth, Strahd at her window, her father's burial and
## the fights she has to watch. Nothing rolls and only her trust moves. She does not fight, so her road lines after a fight
## and the Narrator's lines in one are for someone who watched.

const FILE := "camp/ireena"
## The talks in the file's order, the later part of the story first, with the flags each waits for (besides her being along).
const TALKS: Array[String] = ["castle_eve", "amber", "pool", "izek", "window", "burial", "kept_back"]
const SIDE_FLAGS: Array[String] = ["ireena_trust"]


func _party(level: int = 9) -> StoryState:
	var st := SideQuestPlay.party(["liriel_dawnsong", "godrick_pendlebrook", "wren_featherfoot", "thistle"], level, "svalich_crossroads", 20)
	return st


func _along(level: int = 9) -> StoryState:
	var st := _party(level)
	assert_true(st.add_guest("ireena"), "Ireena joins")
	return st


## The story as it is when every talk is due.
func _everything(st: StoryState) -> StoryState:
	st.set_flag("burgomaster_buried")
	st.set_flag("strahd_window", "ward")
	st.set_flag("izek_told_truth")
	st.set_flag("ireena_pool_choice", "promised")
	st.set_flag("dark_gifts_taken", 1)
	return st


func _says(beats: Array[Dictionary], words: String) -> bool:
	return SideQuestPlay.text(beats).contains(words)


func _menu(beats: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for b in beats:
		if str(b.get("kind", "")) == "options":
			for o: Variant in b["options"] as Array:
				if bool((o as Dictionary).get("enabled", true)):
					out.append(str((o as Dictionary)["text"]))
	return out


func _ends(beats: Array[Dictionary]) -> bool:
	return not beats.is_empty() and str(beats[-1].get("kind", "")) == "end"


func _offered(st: StoryState) -> String:
	return str(CampTalk.offered(DialogueFile.load_key(FILE), st).get("ref", ""))


# --- When she asks ------------------------------------------------------------------------------------------------------------

func test_she_asks_only_while_she_is_along_and_by_her_first_name() -> void:
	var apart := _everything(_party())
	assert_eq(_offered(apart), "", "not along: no talk")
	var st := _everything(_along())
	assert_eq(_offered(st), FILE + ":talk_castle_eve")
	assert_eq(CampTalk.label_for("guest:ireena and flag.burgomaster_buried", st), "Ireena wants a word")
	assert_eq(str(CampTalk.who_asks("guest:ireena and level >= 4", st)["id"]), "guest_ireena", "the camp seats her by her creature's id")
	st.remove_guest("ireena")
	assert_eq(_offered(st), "", "sent home, she asks no more")


func test_each_talk_waits_for_what_it_is_about() -> void:
	var low := _along(3)
	assert_eq(_offered(low), "", "level 3 and nothing has happened: she has not asked yet")
	var kept := _along(4)
	assert_eq(_offered(kept), FILE + ":talk_kept_back", "after many fights at the side")
	var buried := _along(4)
	buried.set_flag("burgomaster_buried")
	assert_eq(_offered(buried), FILE + ":talk_burial", "the burial comes before the fights")
	var window := _along(4)
	window.set_flag("strahd_window", "faith")
	assert_eq(_offered(window), FILE + ":talk_window")
	var church := _along(4)
	church.set_flag("strahd_window", "church")
	assert_eq(_offered(church), FILE + ":talk_kept_back", "the churchyard gate is not a casement")
	var izek := _along(4)
	izek.set_flag("izek_told_truth")
	assert_eq(_offered(izek), FILE + ":talk_izek")
	var pool := _along(4)
	pool.set_flag("ireena_pool_choice", "stayed")
	assert_eq(_offered(pool), FILE + ":talk_pool")
	var amber := _along(4)
	amber.set_flag("dark_gifts_taken", 1)
	assert_eq(_offered(amber), FILE + ":talk_amber")
	var eve := _along(8)
	assert_eq(_offered(eve), FILE + ":talk_kept_back", "not yet the castle at level 8")
	var castle := _along(9)
	assert_eq(_offered(castle), FILE + ":talk_castle_eve", "the night before")
	castle.visited["castle_ravenloft_gates"] = true
	assert_eq(_offered(castle), FILE + ":talk_kept_back", "once inside it is too late for the night before")


func test_the_talks_come_one_a_night_the_later_story_first_each_once() -> void:
	var st := _everything(_along())
	var seen: Array[String] = []
	for i in 10:
		var ref := _offered(st)
		if ref == "":
			break
		seen.append(ref.get_slice(":", 1).trim_prefix("talk_"))
		CampTalk.mark(st, ref)
	assert_eq(seen, TALKS, "seven talks in the story's order, latest first")
	assert_eq(_offered(st), "", "and then she has said it all")


func test_the_camp_offers_her_beside_the_companions() -> void:
	var st := _everything(_along())
	var talks := CampSite.talks(st, {})
	assert_true(talks.has("guest_ireena"), "her bubble is over her creature's id")
	assert_eq(str(talks["guest_ireena"]), FILE + ":talk_castle_eve")
	var had := {"guest_ireena": true}
	assert_false(CampSite.talks(st, had).has("guest_ireena"), "one word an evening")


# --- The talks ----------------------------------------------------------------------------------------------------------------

func test_every_talk_ends_after_one_reply_whichever_option_is_chosen() -> void:
	for talk: String in TALKS:
		var st := _everything(_along())
		var first := SideQuestPlay.play(st, FILE + ":talk_" + talk)
		assert_eq(SideQuestPlay.missing(first), "", talk)
		assert_true(_ends(first), talk + ": ends")
		var opts := _menu(first)
		assert_eq(opts.size(), 2, talk + ": two things to say")
		for i in 2:
			var st2 := _everything(_along())
			var beats := SideQuestPlay.play(st2, FILE + ":talk_" + talk, [opts[i]])
			assert_eq(SideQuestPlay.missing(beats), "", talk + " option " + str(i))
			assert_true(_ends(beats), talk + " option " + str(i) + ": the scene ends")


func test_the_talks_only_move_her_trust_and_never_lower_it() -> void:
	var gains := {"castle_eve": [1, 1], "amber": [0, 0], "pool": [1, 1], "izek": [0, 1], "window": [1, 1], "burial": [1, 1], "kept_back": [1, 0]}
	for talk: String in TALKS:
		var opts := _menu(SideQuestPlay.play(_everything(_along()), FILE + ":talk_" + talk))
		for i in 2:
			var st := _everything(_along())
			var before := st.flags.duplicate(true)
			SideQuestPlay.play(st, FILE + ":talk_" + talk, [opts[i]])
			assert_eq(int(st.get_flag("ireena_trust", 0)), int((gains[talk] as Array)[i]), talk + " option " + str(i))
			for k: Variant in st.flags:
				if str(k) != "ireena_trust" and str(k) != "_strahd":
					assert_true(before.has(k) and before[k] == st.flags[k], talk + ": " + str(k) + " must not move")


func test_the_pool_has_two_openings_and_the_same_replies() -> void:
	var promised := _everything(_along())
	var p := SideQuestPlay.play(promised, FILE + ":talk_pool")
	assert_true(_says(p, "I have given my word to go back to the water"), "promised")
	assert_false(_says(p, "shut a door in the water"))
	var stayed := _everything(_along())
	stayed.set_flag("ireena_pool_choice", "stayed")
	var s := SideQuestPlay.play(stayed, FILE + ":talk_pool")
	assert_true(_says(s, "shut a door in the water"), "stayed")
	assert_false(_says(s, "I have given my word"))
	for choice: String in ["promised", "stayed"]:
		var st2 := _everything(_along())
		st2.set_flag("ireena_pool_choice", choice)
		assert_true(_says(SideQuestPlay.play(st2, FILE + ":talk_pool", ["What did he look like"]), "painted on chapel glass"), choice)
		var st3 := _everything(_along())
		st3.set_flag("ireena_pool_choice", choice)
		assert_true(_says(SideQuestPlay.play(st3, FILE + ":talk_pool", ["Your life belongs to you"]), "the name Father gave me"), choice)


func test_the_burial_talk_knows_a_hasty_burial() -> void:
	var hasty := _everything(_along())
	hasty.set_flag("burial_method", "hasty")
	var h := SideQuestPlay.play(hasty, FILE + ":talk_burial")
	assert_true(_says(h, "with no words and no prayer"), "hasty")
	assert_false(_says(h, "the words spoken over the soil"))
	var rites := _everything(_along())
	rites.set_flag("burial_method", "church_rites")
	var r := SideQuestPlay.play(rites, FILE + ":talk_burial")
	assert_true(_says(r, "the words spoken over the soil"))
	assert_false(_says(r, "with no words and no prayer"))


func test_she_never_names_the_devil_or_the_lost_names_and_nothing_rolls() -> void:
	var kept: Array[String] = []
	for line in FileAccess.get_file_as_string("res://narrative/camp/ireena.dialogue").split("\n"):
		if not line.begins_with("#"):
			kept.append(line)
	var text := "\n".join(kept)
	for banned: String in ["Strahd", "Tatyana", "Sergei"]:
		assert_false(text.contains(banned), "the camp file never says " + banned)
	assert_false(text.contains("DC "), "no skill check")
	assert_false(text.contains("{"), "no placeholder in a line that may be voiced")


# --- The fights she watches -----------------------------------------------------------------------------------------------

func test_her_lines_after_a_fight_are_a_watchers() -> void:
	var st := _along(6)
	var b := Banter.new()
	var said: Array[String] = []
	for i in 6:
		var lines := b.guest_next(st, "fight")
		if lines.is_empty():
			break
		assert_eq(str(lines[0]["speaker_id"]), "ireena")
		said.append(str(lines[0]["text"]))
	assert_eq(said.size(), 5, "five lines after a fight, each once")
	var all := " ".join(said)
	assert_true(all.contains("stand behind you and watch it fall"))
	assert_true(all.contains("not allowed to use it"))
	assert_true(all.contains("keep the ledger"))
	assert_true(all.contains("Anything but standing idle"))
	assert_true(all.contains("Say it plainly"), "the one that fits a watcher is kept")
	assert_false(all.contains("whatever's left when the glass breaks"), "the old line about a fighter is gone")
	assert_false(all.contains("terrible prophet"))


func test_the_narrator_has_four_more_for_the_back_of_a_fight() -> void:
	var df := DialogueFile.load_key("narrator/keeps_back")
	var later: Array[String] = []
	for s: Dictionary in df.nodes.get("combat:keeps_back:ireena", []):
		if str(s["t"]) == "variant":
			later.append(str(s["text"]))
	assert_eq(later.size(), 9, "five from the fights she keeps out of and four from the back of one")
	var all := " ".join(later)
	for words: String in ["sharp warning", "calls out across the din", "road-stone", "holds the lantern high"]:
		assert_true(all.contains(words), words)
	for t in later:
		assert_false(t.contains("{"), "no placeholder in a line that may be voiced")
		assert_true(t.split(" ").size() < 16, "a combat line is one sentence under 15 words: " + t)
