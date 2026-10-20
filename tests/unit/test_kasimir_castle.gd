extends TestCase
## Kasimir at Castle Ravenloft (Story Allies Presence Plan, package K2; narrative/allies/kasimir_castle.dialogue,
## narrative/camp/kasimir_velikov.dialogue, narrative/castle_ravenloft/gates_dinner.dialogue, catacombs_coffin.dialogue,
## data/locations/castle_ravenloft_gates.json, docs/story/kasimir_castle.md). If he made the bargain at the Amber Temple and walks to the
## castle with the party he will not go in: he leaves the party at the chasm's edge or at the dinner and sits by the road below the
## drawbridge, counting his last year, where the party can talk to him (and buy a scroll). Three camp talks; his word over the coffin.
## The crypt scene and the knot errand for a sister laid to rest wait for the castle's crypts stair.

const GATES := "castle_ravenloft_gates"
const CAMP := "vallaki_vistani_camp"
const ROAD := "allies/kasimir_castle:gates_road"
const TAIL := "allies/kasimir_castle:farewell_tail"
const HUB := "allies/kasimir_castle:gates"
const FILE := "camp/kasimir_velikov"
const TALKS: Array[String] = ["castle_eve", "counting", "peace"]


func _party(location: String = GATES, level: int = 9) -> StoryState:
	return SideQuestPlay.party(["ilse_varga", "hedda_ironvow"], level, location, 20)


## He made the bargain, travels with the party and has not yet left them.
func _bargain(st: StoryState) -> StoryState:
	st.set_flag("kasimir_bargain", "made")
	st.set_flag("patrina_fate", "restored")
	assert_true(st.add_guest("kasimir_velikov"))
	return st


func _peace(st: StoryState) -> StoryState:
	st.set_flag("kasimir_at_peace")
	st.set_flag("patrina_fate", "rest")
	assert_true(st.add_guest("kasimir_velikov"))
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


# --- At the chasm's edge --------------------------------------------------------------------------------------------------------

func test_he_stops_at_the_chasm_and_leaves_the_party_either_way_he_is_answered() -> void:
	for pick: String in ["We will tell her you are here", "You could come in with us"]:
		var st := _bargain(_party())
		var beats := SideQuestPlay.play(st, ROAD, [pick])
		assert_eq(SideQuestPlay.missing(beats), "", pick)
		assert_true(_says(beats, "I will wait for her on this side of the ditch"), pick)
		assert_true(_says(beats, "I will be here counting the mornings"), pick + ": the tail")
		assert_true(_ends(beats), pick)
		assert_true(bool(st.get_flag("kasimir_at_gates", false)), pick)
		assert_false("kasimir_velikov" in st.guest_ids, pick + ": he has left the party")
	var a := _bargain(_party())
	assert_true(_says(SideQuestPlay.play(a, ROAD, ["tell her you are here"]), "do not say my name twice"))
	var b := _bargain(_party())
	assert_true(_says(SideQuestPlay.play(b, ROAD, ["come in with us"]), "I would rather sit in the rain"))


func test_he_changes_only_his_own_flag_and_the_party() -> void:
	var st := _bargain(_party())
	var before := st.flags.duplicate(true)
	SideQuestPlay.play(st, ROAD)
	for k: Variant in st.flags:
		if str(k) != "_strahd":
			assert_true(before.has(k) or str(k) == "kasimir_at_gates", str(k) + " is new")


# --- At the dinner ------------------------------------------------------------------------------------------------------------

func test_at_the_dinner_the_host_greets_him_and_he_goes_to_wait_at_the_gate() -> void:
	var st := _bargain(_party())
	st.set_flag("strahd_invitation", "accepted")
	var beats := SideQuestPlay.play(st, "castle_ravenloft/gates_dinner:start", ["Excuse yourselves"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(_says(beats, "Welcome to my table, Master Velikov. Your sister arrived ahead of you."))
	assert_true(_says(beats, "A clever guest knows when to come home"))
	assert_true(_says(beats, "I will take the air by your gate until my sister has time for her brother"))
	assert_true(_says(beats, "I will be here counting the mornings"))
	assert_true(bool(st.get_flag("kasimir_at_gates", false)))
	assert_false("kasimir_velikov" in st.guest_ids, "he left the table")
	assert_true(_says(beats, "Places are laid for each of you"), "and the dinner goes on for the others")


func test_a_kasimir_at_peace_keeps_his_chair_and_a_stranger_gets_nothing_of_it() -> void:
	var peace := _peace(_party())
	peace.set_flag("strahd_invitation", "accepted")
	var p := SideQuestPlay.play(peace, "castle_ravenloft/gates_dinner:start", ["Excuse yourselves"])
	assert_true(_says(p, "you finally take a chair at my board with a quiet mind"))
	assert_true(_says(p, "I did not come up the hill for the soup, my lord"))
	assert_true("kasimir_velikov" in peace.guest_ids, "he stays")
	assert_false(bool(peace.get_flag("kasimir_at_gates", false)))
	var open := _party()
	open.set_flag("strahd_invitation", "accepted")
	assert_true(open.add_guest("kasimir_velikov"))
	var o := SideQuestPlay.play(open, "castle_ravenloft/gates_dinner:start", ["Excuse yourselves"])
	assert_false(_says(o, "Master Velikov"), "his sister's story is not told yet")
	assert_true("kasimir_velikov" in open.guest_ids)
	var none := _party()
	none.set_flag("strahd_invitation", "accepted")
	assert_false(_says(SideQuestPlay.play(none, "castle_ravenloft/gates_dinner:start", ["Excuse yourselves"]), "Velikov"))


# --- The coffin -----------------------------------------------------------------------------------------------------------------

func test_he_has_a_word_over_the_coffin_only_when_he_is_there() -> void:
	var asleep := _party("castle_ravenloft_catacombs_strahd")
	assert_true(asleep.add_guest("kasimir_velikov"))
	var a := SideQuestPlay.play(asleep, "castle_ravenloft/catacombs_coffin:asleep")
	assert_true(_says(a, "stayed as your tenants. You look very small in the dark, my lord."))
	var resting := _party("castle_ravenloft_catacombs_strahd")
	assert_true(resting.add_guest("kasimir_velikov"))
	var r := SideQuestPlay.play(resting, "castle_ravenloft/catacombs_coffin:resting")
	assert_true(_says(r, "your tenants are almost gone"))
	var alone := _party("castle_ravenloft_catacombs_strahd")
	assert_false(_says(SideQuestPlay.play(alone, "castle_ravenloft/catacombs_coffin:asleep"), "tenants"))
	assert_false(_says(SideQuestPlay.play(alone, "castle_ravenloft/catacombs_coffin:resting"), "tenants"))


# --- By the road ----------------------------------------------------------------------------------------------------------------

func test_he_sits_below_the_drawbridge_and_not_at_the_camp_once_he_has_left() -> void:
	var st := _party()
	assert_eq(SideQuestPlay.standing(st, GATES, "kasimir_velikov"), "", "not before")
	assert_eq(SideQuestPlay.standing(st, CAMP, "kasimir_velikov"), "vallaki/kasimir:start", "at the camp as ever")
	st.set_flag("kasimir_at_gates")
	assert_eq(SideQuestPlay.standing(st, GATES, "kasimir_velikov"), HUB)
	assert_eq(SideQuestPlay.standing(st, CAMP, "kasimir_velikov"), "", "and gone from the camp")
	var along := _party()
	along.set_flag("kasimir_at_gates")
	assert_true(along.add_guest("kasimir_velikov"))
	assert_eq(SideQuestPlay.standing(along, GATES, "kasimir_velikov"), "", "asked along again he stands nowhere")
	var rows := Compendium.shared().get_entry("locations", GATES)["map"]["rows"] as Array
	for n: Variant in Compendium.shared().get_entry("locations", GATES)["npcs"]:
		if str((n as Dictionary)["npc"]) == "kasimir_velikov":
			var cell := (n as Dictionary)["cell"] as Array
			assert_eq(str((rows[int(cell[1])] as String)[int(cell[0])]), ".", "open floor")


func test_the_hub_counts_days_carries_nothing_and_sells_scrolls() -> void:
	var st := _party()
	st.set_flag("kasimir_at_gates")
	var menu := SideQuestPlay.play(st, HUB)
	assert_true(_says(menu, "keeping tally of the sky"))
	assert_true(_ends(menu))
	assert_true(_says(SideQuestPlay.play(st, HUB, ["How long do you have left"]), "I tie a knot in the cord each time the fog pales"))
	var msg := SideQuestPlay.play(st, HUB, ["anything we should tell her"])
	assert_true(_says(msg, "Tell her my hands were empty, and that I know now which was heavier."))
	assert_true(_says(msg, "Do not carry any token from me"))
	assert_true(_says(SideQuestPlay.play(st, HUB, ["scrolls to sell"]), "Your coin is welcome"))


# --- Camp talks -----------------------------------------------------------------------------------------------------------------

func test_he_asks_for_a_word_at_camp_the_later_story_first_and_each_once() -> void:
	var apart := _party()
	apart.set_flag("kasimir_bargain", "made")
	assert_eq(_offered(apart), "", "not along")
	var st := _bargain(_party())
	assert_eq(_offered(st), FILE + ":talk_castle_eve", "the night before")
	assert_eq(CampTalk.label_for("guest:kasimir_velikov and level >= 9", st), "Kasimir wants a word")
	assert_eq(str(CampTalk.who_asks("guest:kasimir_velikov and level >= 9", st)["id"]), "guest_kasimir_velikov")
	var seen: Array[String] = []
	for i in 6:
		var ref := _offered(st)
		if ref == "":
			break
		seen.append(ref.get_slice(":", 1).trim_prefix("talk_"))
		CampTalk.mark(st, ref)
	assert_eq(seen, ["castle_eve", "counting"] as Array[String], "the bargain's two")
	var peaceful := _peace(_party())
	var seen2: Array[String] = []
	for i in 6:
		var ref2 := _offered(peaceful)
		if ref2 == "":
			break
		seen2.append(ref2.get_slice(":", 1).trim_prefix("talk_"))
		CampTalk.mark(peaceful, ref2)
	assert_eq(seen2, ["castle_eve", "peace"] as Array[String], "the peaceful one's two")
	var early := _peace(_party("vallaki", 6))
	assert_eq(_offered(early), FILE + ":talk_peace", "before level 9 only the quiet after")


func test_every_talk_ends_after_one_reply_and_changes_nothing() -> void:
	for talk: String in TALKS:
		var base := _bargain(_party()) if talk != "peace" else _peace(_party())
		var first := SideQuestPlay.play(base, FILE + ":talk_" + talk)
		assert_eq(SideQuestPlay.missing(first), "", talk)
		assert_true(_ends(first), talk)
		var opts := _menu(first)
		assert_eq(opts.size(), 2, talk)
		for i in 2:
			var st := _bargain(_party()) if talk != "peace" else _peace(_party())
			var before := st.flags.duplicate(true)
			var beats := SideQuestPlay.play(st, FILE + ":talk_" + talk, [opts[i]])
			assert_eq(SideQuestPlay.missing(beats), "", talk + str(i))
			assert_true(_ends(beats), talk + str(i))
			for k: Variant in st.flags:
				if str(k) != "_strahd":
					assert_true(before.has(k) and before[k] == st.flags[k], talk + ": " + str(k) + " must not move")


func test_none_of_it_names_the_count() -> void:
	for path: String in ["res://narrative/allies/kasimir_castle.dialogue", "res://narrative/camp/kasimir_velikov.dialogue"]:
		var kept: Array[String] = []
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if not line.begins_with("#"):
				kept.append(line)
		var text := "\n".join(kept)
		assert_false(text.contains("Strahd"), path)
		assert_false(text.contains("DC "), path)
		assert_false(text.contains("{"), path)
