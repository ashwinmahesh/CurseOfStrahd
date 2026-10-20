extends TestCase
## Ezmerelda at camp, Madam Eva's card and the castle plan (Story Allies Presence Plan, package M3; narrative/camp/ezmerelda.dialogue,
## narrative/allies/ezmerelda_castle.dialogue, narrative/svalich_road/madam_eva.dialogue, narrative/banter/guest_ezmerelda.dialogue,
## docs/story/ezmerelda_camp.md). While she travels with the party, a Long Rest at camp can bring five talks (the night before the
## castle, the werewolf den's end, her teacher found, her people at Tser Pool, and her fear), each once and the later part of the
## story first. Madam Eva reads one card for her alone. At the castle the first time they come near the drawbridge (or the keep's
## crest, when the carriage set them down) she gives her plan, which unlocks her two lines in the catacombs and the tombs.

const FILE := "camp/ezmerelda"
const TALKS: Array[String] = ["castle_eve", "leg", "rudolph", "wagons", "fear"]
const EVA := "svalich_road/madam_eva"


func _party(level: int = 9) -> StoryState:
	return SideQuestPlay.party(["liriel_dawnsong", "godrick_pendlebrook", "wren_featherfoot", "thistle"], level, "svalich_crossroads", 20)


func _along(level: int = 9) -> StoryState:
	var st := _party(level)
	assert_true(st.add_guest("ezmerelda"), "Ezmerelda joins")
	return st


## The story as it is when every talk is due.
func _everything(st: StoryState) -> StoryState:
	st.set_flag("wolf_pack_leader", "emil")
	st.set_flag("rictavio_unmasked")
	st.visited["tser_pool"] = true
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


func _has_option(beats: Array[Dictionary], words: String) -> bool:
	for t in _menu(beats):
		if t.contains(words):
			return true
	return false


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
	assert_eq(CampTalk.label_for("guest:ezmerelda and level >= 6", st), "Ezmerelda wants a word")
	assert_eq(str(CampTalk.who_asks("guest:ezmerelda and level >= 6", st)["id"]), "guest_ezmerelda")
	st.remove_guest("ezmerelda")
	assert_eq(_offered(st), "", "sent home, she asks no more")


func test_each_talk_waits_for_what_it_is_about() -> void:
	var nothing := _along(5)
	assert_eq(_offered(nothing), "", "level 5 and nothing has happened")
	var fear := _along(6)
	assert_eq(_offered(fear), FILE + ":talk_fear", "after hard fights")
	var wagons := _along(5)
	wagons.visited["tser_pool"] = true
	assert_eq(_offered(wagons), FILE + ":talk_wagons")
	var rudolph := _along(5)
	rudolph.set_flag("van_richten_reunited")
	assert_eq(_offered(rudolph), FILE + ":talk_rudolph", "reunited")
	var unmasked := _along(5)
	unmasked.set_flag("rictavio_unmasked")
	assert_eq(_offered(unmasked), FILE + ":talk_rudolph", "or found out")
	var leg := _along(5)
	leg.set_flag("wolf_pack_leader", "none")
	assert_eq(_offered(leg), FILE + ":talk_leg", "the den is settled")
	var eve := _along(9)
	assert_eq(_offered(eve), FILE + ":talk_castle_eve", "the night before")
	eve.visited["castle_ravenloft_gates"] = true
	assert_eq(_offered(eve), FILE + ":talk_fear", "once at the castle it is too late for the night before")


func test_the_talks_come_one_a_night_the_later_story_first_each_once() -> void:
	var st := _everything(_along())
	var seen: Array[String] = []
	for i in 10:
		var ref := _offered(st)
		if ref == "":
			break
		seen.append(ref.get_slice(":", 1).trim_prefix("talk_"))
		CampTalk.mark(st, ref)
	assert_eq(seen, TALKS, "five talks in the story's order, latest first")
	assert_eq(_offered(st), "")


func test_the_camp_offers_her_beside_the_companions() -> void:
	var st := _everything(_along())
	var talks := CampSite.talks(st, {})
	assert_true(talks.has("guest_ezmerelda"))
	assert_eq(str(talks["guest_ezmerelda"]), FILE + ":talk_castle_eve")
	assert_false(CampSite.talks(st, {"guest_ezmerelda": true}).has("guest_ezmerelda"), "one word an evening")


# --- The talks ----------------------------------------------------------------------------------------------------------------

func test_every_talk_ends_after_one_reply_whichever_option_is_chosen_and_nothing_changes() -> void:
	for talk: String in TALKS:
		var first := SideQuestPlay.play(_everything(_along()), FILE + ":talk_" + talk)
		assert_eq(SideQuestPlay.missing(first), "", talk)
		assert_true(_ends(first), talk + ": ends")
		var opts := _menu(first)
		assert_eq(opts.size(), 2, talk + ": two things to say")
		for i in 2:
			var st := _everything(_along())
			var before := st.flags.duplicate(true)
			var beats := SideQuestPlay.play(st, FILE + ":talk_" + talk, [opts[i]])
			assert_eq(SideQuestPlay.missing(beats), "", talk + " option " + str(i))
			assert_true(_ends(beats), talk + " option " + str(i) + ": the scene ends")
			for k: Variant in st.flags:
				if str(k) != "_strahd":
					assert_true(before.has(k) and before[k] == st.flags[k], talk + ": " + str(k) + " must not move")


func test_the_leg_talk_knows_whether_kiril_lives() -> void:
	var alive := _everything(_along())
	alive.set_flag("wolf_pack_leader", "kiril")
	var a := SideQuestPlay.play(alive, FILE + ":talk_leg")
	assert_true(_says(a, "Kiril is still out in those hills"), "alive")
	assert_false(_says(a, "Kiril is dead"))
	for leader: String in ["emil", "none"]:
		var done := _everything(_along())
		done.set_flag("wolf_pack_leader", leader)
		var d := SideQuestPlay.play(done, FILE + ":talk_leg")
		assert_true(_says(d, "Kiril is dead in the hills"), leader)
		assert_false(_says(d, "still out in those hills"))
	for leader: String in ["kiril", "emil"]:
		var st := _everything(_along())
		st.set_flag("wolf_pack_leader", leader)
		assert_true(_says(SideQuestPlay.play(st, FILE + ":talk_leg", ["finish him yourself"]), "bigger teeth to pull"), leader)
		var st2 := _everything(_along())
		st2.set_flag("wolf_pack_leader", leader)
		assert_true(_says(SideQuestPlay.play(st2, FILE + ":talk_leg", ["that night"]), "tie your own tourniquet"), leader)


func test_she_never_names_the_count_and_nothing_rolls() -> void:
	for path: String in ["res://narrative/camp/ezmerelda.dialogue", "res://narrative/allies/ezmerelda_castle.dialogue"]:
		var kept: Array[String] = []
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if not line.begins_with("#"):
				kept.append(line)
		var text := "\n".join(kept)
		assert_false(text.contains("Strahd"), path + ": never his name")
		assert_false(text.contains("DC "), path + ": no skill check")
		assert_false(text.contains("{"), path + ": no placeholder in a line that may be voiced")


# --- Madam Eva's card ---------------------------------------------------------------------------------------------------------

func test_eva_reads_one_card_for_her_once_the_reading_is_done_and_she_is_along() -> void:
	var apart := _party()
	apart.set_flag("eva_reading_done")
	assert_false(_has_option(SideQuestPlay.play(apart, EVA + ":again_menu"), "Ezmerelda is with us"), "not along: no offer")
	var st := _along()
	st.set_flag("eva_reading_done")
	var menu := SideQuestPlay.play(st, EVA + ":again_menu")
	assert_true(_has_option(menu, "Ezmerelda is with us"), "along: Eva will read for her")
	assert_true(_ends(menu), "and the menu still lets the party go")
	var beats := SideQuestPlay.play(st, EVA + ":again_menu", ["Ezmerelda is with us"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(_says(beats, "Come out of the draft, child"))
	assert_true(_says(beats, "an empty wooden chair beside a cold hearth"))
	assert_true(_says(beats, "one sausage a week is an insult to my camp"))
	assert_true(bool(st.get_flag("eva_card_for_ezmerelda", false)))
	assert_true(_ends(beats), "the scene returns to Eva's menu and ends with goodbye")
	assert_false(_has_option(SideQuestPlay.play(st, EVA + ":again_menu"), "Ezmerelda is with us"), "once")


func test_eva_card_has_two_ways_to_take_it() -> void:
	var a := _along()
	a.set_flag("eva_reading_done")
	var ra := SideQuestPlay.play(a, EVA + ":again_menu", ["Ezmerelda is with us", "what the card means"])
	assert_true(_says(ra, "The cards do not mean. The cards are patient, and they wait."))
	var b := _along()
	b.set_flag("eva_reading_done")
	var rb := SideQuestPlay.play(b, EVA + ":again_menu", ["Ezmerelda is with us", "eat something"])
	assert_true(_says(rb, "half a loaf from Stanimir's cart"))
	assert_true(bool(a.get_flag("eva_reading_done", false)) and bool(b.get_flag("eva_reading_done", false)), "the reading stays done")


func test_eva_card_changes_only_its_own_flag() -> void:
	var st := _along()
	st.set_flag("eva_reading_done")
	var before := st.flags.duplicate(true)
	SideQuestPlay.play(st, EVA + ":ezmerelda_card")
	for k: Variant in st.flags:
		if str(k) != "_strahd" and not before.has(k):
			assert_eq(str(k), "eva_card_for_ezmerelda", "only the card's own flag is new")


# --- The plan at the castle ---------------------------------------------------------------------------------------------------

func test_the_plan_gives_four_rules_two_ways_to_answer_and_sets_its_flag() -> void:
	for node: String in ["plan", "plan_keep"]:
		var st := _along()
		var first := SideQuestPlay.play(st, "allies/ezmerelda_castle:" + node)
		assert_eq(SideQuestPlay.missing(first), "", node)
		assert_true(_says(first, "Paper plans die on the drawbridge"), node)
		assert_true(_says(first, "if I tell you to run"), node + ": the fourth rule")
		assert_true(_ends(first), node)
		assert_true(bool(st.get_flag("ezmerelda_castle_plan", false)), node + ": the plan is told")
		assert_eq(_menu(first).size(), 2, node + ": two answers")
		var st_a := _along()
		assert_true(_says(SideQuestPlay.play(st_a, "allies/ezmerelda_castle:" + node, ["Lead on"]), "the tuition goes up"), node)
		var st_b := _along()
		assert_true(_says(SideQuestPlay.play(st_b, "allies/ezmerelda_castle:" + node, ["falls apart"]), "I improvise, very loudly"), node)
	assert_true(_says(SideQuestPlay.play(_along(), "allies/ezmerelda_castle:plan"), "rusted chains of the drawbridge"), "at the bridge")
	assert_true(_says(SideQuestPlay.play(_along(), "allies/ezmerelda_castle:plan_keep"), "high carved doors of the keep"), "at the keep")


func test_the_plan_unlocks_her_lines_in_the_catacombs_and_the_tombs() -> void:
	var b := Banter.new()
	var told := _along()
	told.set_flag("ezmerelda_castle_plan")
	told.location = "castle_ravenloft_catacombs"
	var lines := b.guest_next(told, "enter")
	assert_false(lines.is_empty(), "a line on entering the catacombs")
	assert_eq(str(lines[0]["speaker_id"]), "ezmerelda")
	assert_true(str(lines[0]["text"]).contains("The dead keep better hours than the living"))
	told.location = "castle_ravenloft_catacombs_tombs"
	var tombs := b.guest_next(told, "enter")
	assert_true(not tombs.is_empty() and str(tombs[0]["text"]).contains("I hate tombs"), "and in the tombs")
	var untold := _along()
	untold.location = "castle_ravenloft_catacombs"
	var other := Banter.new().guest_next(untold, "enter")
	assert_true(other.is_empty() or not str(other[0]["text"]).contains("The dead keep better hours"), "no plan, no line")
