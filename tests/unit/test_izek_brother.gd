extends TestCase
## Izek after the truth (Story Allies Presence Plan, package Z2; narrative/allies/izek.dialogue, narrative/camp/izek.dialogue,
## narrative/banter/guest_izek.dialogue, docs/story/izek_brother.md). Told that Ireena is his sister, he leaves the Baron and can be
## found: in the woods past Lake Zarovich, then at Kolyan's grave, then (if the party asks) sitting at Ireena's door, and falling in
## behind her when she travels with the party. Three scenes between the two; a way to take the window from Strahd; epilogues.

const WOODS := "allies/izek:woods"
const GRAVE := "allies/izek:grave"
const GUARD := "allies/izek:guard"
const TRAIL := "lake_zarovich_trail"
const VILLAGE := "village_of_barovia"
## Where Ireena can shelter, with the flags that say so and Izek's place there.
const REFUGES: Array = [
	["vallaki_blue_water_inn", {"ireena_sanctuary": "inn"}],
	["vallaki_st_andrals", {"ireena_sanctuary": "st_andrals"}],
	["krezk_burgomaster_house", {"ireena_in_krezk": true}],
	["burgomaster_mansion", {"ireena_escort": "declined"}],
]
## What the scenes may change besides the story's own flags (data/flags/allies_izek.json and Ireena's trust).
const SIDE_FLAGS: Array[String] = ["izek_woods_met", "izek_grave_met", "izek_knows_rider", "izek_guards_ireena", "izek_sister_1",
	"izek_sister_2", "izek_sister_3", "ireena_birth_name_kept", "ireena_trust"]


func _party(location: String = TRAIL, hour: int = 12) -> StoryState:
	return SideQuestPlay.party(["ilse_varga", "hedda_ironvow"], 6, location, hour)


## Izek has been told Ireena is his sister.
func _told(st: StoryState) -> StoryState:
	st.set_flag("ireena_met")
	st.set_flag("izek_saw_ireena")
	st.set_flag("izek_sister_truth")
	st.set_flag("izek_told_truth")
	return st


## ... and sits at her door, wherever she shelters (`place` is an index of REFUGES).
func _guarding(st: StoryState, place: int = 0) -> StoryState:
	_told(st)
	st.set_flag("izek_guards_ireena")
	var flags := REFUGES[place][1] as Dictionary
	for k: Variant in flags:
		st.set_flag(str(k), flags[k])
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


func _changed(before: Dictionary, after: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k: Variant in after:
		if str(k) == "_strahd":
			continue
		if not before.has(k) or before[k] != after[k]:
			out.append(str(k))
	return out


# --- Where he stands ----------------------------------------------------------------------------------------------------------

func test_he_stands_in_the_woods_for_a_day_and_then_at_the_grave() -> void:
	var untold := _party()
	assert_eq(SideQuestPlay.standing(untold, TRAIL, "izek"), "", "not told: still the Baron's")
	var dead := _told(_party())
	dead.set_flag("izek_dead")
	assert_eq(SideQuestPlay.standing(dead, TRAIL, "izek"), "", "dead")
	var st := _told(_party())
	assert_eq(SideQuestPlay.standing(st, TRAIL, "izek"), WOODS, "told: digging in the woods")
	assert_eq(SideQuestPlay.standing(st, VILLAGE, "izek"), "", "and not at the grave")
	st.set_flag("izek_woods_met", st.total_minutes())
	assert_eq(SideQuestPlay.standing(st, TRAIL, "izek"), WOODS, "the day he was found")
	assert_eq(SideQuestPlay.standing(st, VILLAGE, "izek"), "")
	st.day += 1
	assert_eq(SideQuestPlay.standing(st, TRAIL, "izek"), "", "a day on he has gone")
	assert_eq(SideQuestPlay.standing(st, VILLAGE, "izek"), GRAVE, "to the burgomaster's grave")
	st.set_flag("izek_guards_ireena")
	assert_eq(SideQuestPlay.standing(st, VILLAGE, "izek"), "", "at her door he is not at the grave")
	var along := _told(_party())
	assert_true(along.add_guest("izek"))
	assert_eq(SideQuestPlay.standing(along, TRAIL, "izek"), "", "with the party he stands nowhere")


func test_he_sits_at_her_door_wherever_she_shelters_and_not_when_she_travels_or_is_taken() -> void:
	for i in REFUGES.size():
		var place := str((REFUGES[i] as Array)[0])
		var st := _guarding(_party(place), i)
		assert_eq(SideQuestPlay.standing(st, place, "izek"), GUARD, place + ": at her door")
		var along := _guarding(_party(place), i)
		assert_true(along.add_guest("ireena"))
		assert_eq(SideQuestPlay.standing(along, place, "izek"), "", place + ": she travels, he is not left behind alone")
		var held := _guarding(_party(place), i)
		held.set_flag("ireena_held_by_strahd")
		assert_eq(SideQuestPlay.standing(held, place, "izek"), "", place + ": she is in the castle")
		var dead := _guarding(_party(place), i)
		dead.set_flag("izek_dead")
		assert_eq(SideQuestPlay.standing(dead, place, "izek"), "", place + ": dead")
		var apart := _told(_party(place))
		for k: Variant in ((REFUGES[i] as Array)[1] as Dictionary):
			apart.set_flag(str(k), ((REFUGES[i] as Array)[1] as Dictionary)[k])
		assert_eq(SideQuestPlay.standing(apart, place, "izek"), "", place + ": not asked, not there")
	var other := _guarding(_party("vallaki_st_andrals"), 0)
	assert_eq(SideQuestPlay.standing(other, "vallaki_st_andrals", "izek"), "", "he sits where she is, not at the church when she lodges at the inn")


func test_no_letter_from_ireena_while_izek_holds_her() -> void:
	StrahdPresence.use({})
	var st := _told(_party("svalich_crossroads"))
	st.flags.erase("izek_told_truth")
	st.set_flag("ireena_sanctuary", "inn")
	st.set_flag("festival_over")
	assert_eq(str(StrahdPresence.due(st, "arrive", {"location": "svalich_crossroads"}).get("id", "")), "ireena_letter", "ordinarily she writes")
	var held := _told(_party("svalich_crossroads"))
	held.flags.erase("izek_told_truth")
	held.set_flag("ireena_sanctuary", "inn")
	held.set_flag("festival_over")
	held.set_flag("izek_holds_ireena")
	assert_true(StrahdPresence.due(held, "arrive", {"location": "svalich_crossroads"}).is_empty(), "not from his room")


func test_every_placement_stands_on_open_floor() -> void:
	for loc: String in [TRAIL, VILLAGE, "vallaki_blue_water_inn", "vallaki_st_andrals", "krezk_burgomaster_house", "burgomaster_mansion"]:
		var entry := {}
		for n: Variant in Compendium.shared().get_entry("locations", loc)["npcs"]:
			if str((n as Dictionary)["npc"]) == "izek":
				entry = n as Dictionary
		assert_false(entry.is_empty(), loc)
		var cell := entry["cell"] as Array
		var rows := Compendium.shared().get_entry("locations", loc)["map"]["rows"] as Array
		assert_eq(str((rows[int(cell[1])] as String)[int(cell[0])]), ".", loc + ": open floor")


# --- The woods and the rider --------------------------------------------------------------------------------------------------

func test_the_woods_first_meeting_stamps_the_day_and_every_branch_has_an_exit() -> void:
	var st := _told(_party())
	var first := SideQuestPlay.play(st, WOODS)
	assert_eq(SideQuestPlay.missing(first), "")
	assert_true(_says(first, "digs with his bare claws"))
	assert_true(_ends(first))
	assert_true(int(st.get_flag("izek_woods_met", 0)) > 0, "stamped with the game minute")
	assert_false(_has_option(first, "Emil saw"), "nothing about the rider unless Emil's account was heard")
	var again := SideQuestPlay.play(st, WOODS)
	assert_true(_says(again, "The dirt isn't finished with me yet"))
	for pick: String in ["What are you digging for", "Ireena asked after you"]:
		var beats := SideQuestPlay.play(_told(_party()), WOODS, [pick])
		assert_eq(SideQuestPlay.missing(beats), "", pick)
		assert_true(_ends(beats), pick)
	assert_true(_says(SideQuestPlay.play(_told(_party()), WOODS, ["digging for"]), "bone button"))
	assert_true(_says(SideQuestPlay.play(_told(_party()), WOODS, ["asked after you"]), "Tomorrow I will go down to Barovia"))


func test_what_emil_saw_can_be_told_from_the_woods_the_grave_a_post_or_the_road() -> void:
	var woods := _told(_party())
	woods.set_flag("izek_rider_heard")
	var w := SideQuestPlay.play(woods, WOODS, ["Emil saw"])
	assert_true(_says(w, "Not the pack, then. The castle."))
	assert_true(bool(woods.get_flag("izek_knows_rider", false)))
	assert_true(_ends(w))
	var grave := _told(_party(VILLAGE))
	grave.set_flag("izek_rider_heard")
	assert_true(_says(SideQuestPlay.play(grave, GRAVE, ["Emil saw"]), "Not the pack, then"), "at the grave")
	var post := _guarding(_party("vallaki_blue_water_inn"))
	post.set_flag("izek_rider_heard")
	assert_true(_says(SideQuestPlay.play(post, GUARD, ["Emil saw"]), "Not the pack, then"), "at his post")
	var road := _told(_party())
	road.set_flag("izek_rider_heard")
	assert_true(road.add_guest("izek"))
	assert_true(_says(SideQuestPlay.play(road, "allies/izek:talk", ["Emil saw"]), "Not the pack, then"), "on the road")
	var told := _told(_party())
	told.set_flag("izek_rider_heard")
	told.set_flag("izek_knows_rider")
	assert_false(_has_option(SideQuestPlay.play(told, WOODS), "Emil saw"), "once")


func test_emils_account_lets_the_party_tell_him() -> void:
	var st := _party("werewolf_den")
	st.set_flag("izek_story_heard")
	SideQuestPlay.play(st, "werewolf_den/emil:lake_night")
	assert_true(bool(st.get_flag("izek_rider_heard", false)))


# --- The grave ----------------------------------------------------------------------------------------------------------------

func test_at_the_grave_he_can_be_asked_to_guard_her_door_only_where_she_shelters() -> void:
	var st := _told(_party(VILLAGE))
	st.set_flag("izek_woods_met", st.total_minutes())
	var first := SideQuestPlay.play(st, GRAVE)
	assert_true(_says(first, "Kolyan, was it"))
	assert_true(bool(st.get_flag("izek_grave_met", false)))
	assert_false(_says(first, "Ismark the Lesser"), "no Ismark")
	assert_false(_has_option(first, "Go and sit by Ireena's door"), "she is nowhere he could guard her")
	assert_true(_says(SideQuestPlay.play(st, GRAVE), "State your business"), "later")
	for i in REFUGES.size():
		var s := _told(_party(VILLAGE))
		for k: Variant in ((REFUGES[i] as Array)[1] as Dictionary):
			s.set_flag(str(k), ((REFUGES[i] as Array)[1] as Dictionary)[k])
		var menu := SideQuestPlay.play(s, GRAVE)
		assert_true(_has_option(menu, "Go and sit by Ireena's door"), str((REFUGES[i] as Array)[0]))
		var beats := SideQuestPlay.play(s, GRAVE, ["Go and sit by Ireena's door"])
		assert_true(_says(beats, "Give me the door"))
		assert_true(_ends(beats))
		assert_true(bool(s.get_flag("izek_guards_ireena", false)))
	var held := _told(_party(VILLAGE))
	held.set_flag("ireena_sanctuary", "taken")
	held.set_flag("ireena_held_by_strahd")
	assert_false(_has_option(SideQuestPlay.play(held, GRAVE), "Go and sit by Ireena's door"), "not while she is in the castle")


func test_ismark_and_izek_measure_each_other_at_the_grave() -> void:
	var st := _told(_party(VILLAGE))
	assert_true(st.add_guest("ismark"))
	var beats := SideQuestPlay.play(st, GRAVE)
	assert_true(_says(beats, "They call me Ismark the Lesser"))
	assert_true(_says(beats, "You kept her alive when I wasn't there"))


func test_with_ireena_along_he_walks_behind_her_and_she_can_speak_to_him() -> void:
	var st := _told(_party(VILLAGE))
	assert_true(st.add_guest("ireena"))
	var menu := SideQuestPlay.play(st, GRAVE)
	assert_true(_has_option(menu, "Let her speak to him"), "the first doll")
	assert_false(_has_option(menu, "Go and sit by Ireena's door"), "she is with the party")
	var beats := SideQuestPlay.play(st, GRAVE, ["Walk with us"])
	assert_true(_says(beats, "Then I walk a step behind her"))
	assert_true("izek" in st.guest_ids, "a guest now")
	assert_true(bool(st.get_flag("izek_guards_ireena", false)))
	assert_eq(st.guest_stays("izek"), "Izek won't leave his sister.", "he stays with her")
	var doll := _told(_party(VILLAGE))
	assert_true(doll.add_guest("ireena"))
	assert_true(_says(SideQuestPlay.play(doll, GRAVE, ["Let her speak to him"]), "the scowl of a Vallaki turnip"))


# --- At her door --------------------------------------------------------------------------------------------------------------

func test_at_her_door_he_has_a_line_for_each_place_and_a_menu_with_an_exit() -> void:
	for i in REFUGES.size():
		var place := str((REFUGES[i] as Array)[0])
		var st := _guarding(_party(place), i)
		var beats := SideQuestPlay.play(st, GUARD)
		assert_eq(SideQuestPlay.missing(beats), "", place)
		assert_true(_says(beats, ["tilted chair", "nave wall", "boundary post", "barred shutters"][i]), place + ": his place")
		assert_true(_says(beats, "The door is shut. Keep your voice down."), place)
		assert_true(_ends(beats), place + ": an exit")
		assert_true(_has_option(beats, "Is there something you two haven't said"), place)
		assert_true(_says(SideQuestPlay.play(st, GUARD, ["How is she doing"]), "I heard her turn twice"), place)


func test_the_three_scenes_come_in_order_and_the_name_is_hers_to_keep() -> void:
	for pick: String in ["It is your name to keep", "You can carry both names"]:
		var st := _guarding(_party("vallaki_blue_water_inn"))
		var before := st.flags.duplicate(true)
		var first := SideQuestPlay.play(st, GUARD, ["Is there something you two", "(Say nothing"])
		assert_true(_says(first, "the scowl of a Vallaki turnip"), "the doll")
		assert_true(bool(st.get_flag("izek_sister_1", false)))
		assert_false(bool(st.get_flag("izek_sister_2", false)))
		var second := SideQuestPlay.play(st, GUARD, ["Is there something you two", "What little he remembers"])
		assert_true(_says(second, "What were our mother and father like"), "the parents")
		assert_true(bool(st.get_flag("izek_sister_2", false)))
		var third := SideQuestPlay.play(st, GUARD, ["Is there something you two", pick])
		assert_true(_says(third, "It was Viorela"), "the name")
		assert_true(bool(st.get_flag("izek_sister_3", false)))
		assert_eq(str(st.get_flag("ireena_birth_name_kept", "")), "ireena" if pick.begins_with("It is") else "both")
		assert_eq(int(st.get_flag("ireena_trust", 0)), 3, "each scene adds one")
		assert_false(_has_option(SideQuestPlay.play(st, GUARD), "Is there something you two"), "nothing left unsaid")
		for k in _changed(before, st.flags):
			assert_true(k in SIDE_FLAGS, k + " is a side flag")


func test_the_scenes_end_by_either_option() -> void:
	for scene: String in ["sister_1", "sister_2", "sister_3"]:
		var opts := _menu(SideQuestPlay.play(_guarding(_party("vallaki_blue_water_inn")), "allies/izek:" + scene))
		assert_eq(opts.size(), 2, scene)
		for i in 2:
			var beats := SideQuestPlay.play(_guarding(_party("vallaki_blue_water_inn")), "allies/izek:" + scene, [opts[i]])
			assert_eq(SideQuestPlay.missing(beats), "", scene + str(i))
			assert_true(_ends(beats), scene + str(i))


# --- On the road ----------------------------------------------------------------------------------------------------------------

func test_a_click_opens_his_talk_and_it_changes_when_the_doll_is_given() -> void:
	assert_eq(GuestTalk.ref_for("izek"), "allies/izek:talk")
	var st := _told(_party())
	assert_true(st.add_guest("izek"))
	var menu := SideQuestPlay.play(st, "allies/izek:talk")
	assert_true(_ends(menu))
	assert_false(_has_option(menu, "What will you do about the castle"), "not until he knows about the rider")
	assert_false(_has_option(menu, "Is there something you two"), "Ireena is not along")
	assert_true(_says(SideQuestPlay.play(st, "allies/izek:talk", ["dolls"]), "wrapped in oilcloth inside my coat"))
	st.set_flag("izek_sister_1")
	assert_true(_says(SideQuestPlay.play(st, "allies/izek:talk", ["dolls"]), "Now she has it, and my coat is lighter"))
	assert_false(_says(SideQuestPlay.play(st, "allies/izek:talk", ["dolls"]), "wrapped in oilcloth"))
	assert_true(_says(SideQuestPlay.play(st, "allies/izek:talk", ["arm"]), "singed mutton"))
	st.set_flag("izek_knows_rider")
	assert_true(_says(SideQuestPlay.play(st, "allies/izek:talk", ["castle"]), "burn the thing that has been walking through her sleep"))
	assert_true(st.add_guest("ireena"))
	assert_true(_has_option(SideQuestPlay.play(st, "allies/izek:talk"), "Is there something you two"))


func test_he_falls_in_behind_her_when_she_rejoins_from_every_place() -> void:
	for case: Array in [["vallaki/ireena:rejoin", 0], ["vallaki/ireena:rejoin", 1], ["krezk/ireena:rejoin", 2]]:
		var st := _guarding(_party(str((REFUGES[int(case[1])] as Array)[0])), int(case[1]))
		var beats := SideQuestPlay.play(st, str(case[0]))
		assert_true("ireena" in st.guest_ids, str(case[0]))
		assert_true("izek" in st.guest_ids, str(case[0]) + ": he follows her")
		assert_true(_says(beats, "She walks, I walk"), str(case[0]))
	var home := _guarding(_party("burgomaster_mansion"), 3)
	SideQuestPlay.play(home, "village_of_barovia/ireena:accept")
	assert_true("izek" in home.guest_ids, "from the mansion")
	var alone := _told(_party("vallaki_blue_water_inn"))
	alone.set_flag("ireena_sanctuary", "inn")
	SideQuestPlay.play(alone, "vallaki/ireena:rejoin")
	assert_false("izek" in alone.guest_ids, "not asked, not along")


func test_when_both_travel_the_camp_offers_the_three_scenes_in_order() -> void:
	var st := _told(_party())
	assert_true(st.add_guest("ireena"))
	assert_true(st.add_guest("izek"))
	var df := DialogueFile.load_key("camp/izek")
	var seen: Array[String] = []
	for i in 5:
		var ref := str(CampTalk.offered(df, st).get("ref", ""))
		if ref == "":
			break
		seen.append(ref.get_slice(":", 1))
		assert_eq(str(CampTalk.who_asks("guest:izek and guest:ireena", st)["id"]), "guest_izek", "he asks")
		SideQuestPlay.play(st, ref)
		CampTalk.mark(st, ref)
	assert_eq(seen, ["talk_sister_1", "talk_sister_2", "talk_sister_3"] as Array[String])
	assert_eq(CampTalk.label_for("guest:izek and guest:ireena", st), "Izek wants a word")
	var one := _told(_party())
	assert_true(one.add_guest("izek"))
	assert_eq(str(CampTalk.offered(df, one).get("ref", "")), "", "without her there is nothing to say")


func test_his_lines_on_the_road() -> void:
	var st := _told(_party("vallaki"))
	assert_true(st.add_guest("izek"))
	var b := Banter.new()
	var lines := b.guest_next(st, "enter")
	assert_true(not lines.is_empty() and str(lines[0]["text"]).contains("That fat fool can hang his own lanterns"))
	var said: Array[String] = []
	for i in 6:
		var fight := b.guest_next(st, "fight")
		if fight.is_empty():
			break
		assert_eq(str(fight[0]["speaker_id"]), "izek")
		said.append(str(fight[0]["text"]))
	assert_eq(said.size(), 1, "one after a fight without Ireena along: the arm")
	assert_true(" ".join(said).contains("Don't look at the arm"))
	var idle := b.guest_next(st, "idle")
	assert_false(idle.is_empty())
	st.set_flag("izek_sister_1")
	var after := Banter.new()
	var texts: Array[String] = []
	for i in 6:
		var l := after.guest_next(st, "idle")
		if l.is_empty():
			break
		texts.append(str(l[0]["text"]))
	assert_false(" ".join(texts).contains("I keep one in my coat"), "the doll is hers now")


# --- Strahd at her window -----------------------------------------------------------------------------------------------------

func test_izek_can_take_the_window_and_the_story_goes_on_as_if_it_were_held() -> void:
	for scene: Array in [["strahd/ireena:inn", "vallaki_blue_water_inn", 0, "Blue Water Inn"], ["strahd/ireena:krezk", "krezk_burgomaster_house", 2, "upper room"]]:
		var st := _guarding(_party(str(scene[1])), int(scene[2]))
		var beats := SideQuestPlay.play(st, str(scene[0]), ["Let Izek take the window"])
		assert_eq(SideQuestPlay.missing(beats), "", str(scene[0]))
		assert_true(_says(beats, "wide awake in the doorway"), str(scene[0]))
		assert_true(_says(beats, "The brother. How very warm you keep her threshold."), str(scene[0]))
		assert_eq(str(st.get_flag("strahd_window", "")), "izek", str(scene[0]))
		assert_true(_says(beats, "I was going to go. I wanted to."), "and she says what she says when it is held")
		assert_false(bool(st.get_flag("ireena_held_by_strahd", false)), "nobody is taken")
		var without := _told(_party(str(scene[1])))
		without.set_flag("ireena_sanctuary", "inn")
		without.set_flag("ireena_in_krezk", int(scene[2]) == 2)
		assert_false(_has_option(SideQuestPlay.play(without, str(scene[0])), "Let Izek take the window"), str(scene[0]) + ": only while he guards her")


func test_every_reader_of_the_window_treats_izek_as_a_window_that_was_met() -> void:
	var st := _party()
	st.set_flag("strahd_window", "izek")
	assert_true(StoryConditions.check("flag.strahd_window and flag.strahd_window != \"taken\"", st), "Strahd's attention and her first letter")
	assert_false(StoryConditions.check("flag.strahd_window == \"fight\"", st), "and no fight to withdraw from")


# --- Ireena's hint, and the epilogues -----------------------------------------------------------------------------------------

func test_ireena_tells_of_the_lake_trail_until_the_party_has_found_him() -> void:
	var st := _told(_party("vallaki_blue_water_inn"))
	st.set_flag("ireena_sanctuary", "inn")
	assert_true(_says(SideQuestPlay.play(st, "allies/ireena:checkin"), "on the lake trail past the hills"))
	var met := _told(_party("vallaki_blue_water_inn"))
	met.set_flag("ireena_sanctuary", "inn")
	met.set_flag("izek_woods_met", met.total_minutes())
	assert_false(_says(SideQuestPlay.play(met, "allies/ireena:checkin"), "on the lake trail past the hills"), "once found, nothing to tell")


func test_the_epilogues_say_what_became_of_him() -> void:
	var cases := [
		["flag.izek_guards_ireena and flag.ireena_birth_name_kept == both", "he says Viorela, and she answers", "strahd_destroyed", {"izek_guards_ireena": true, "ireena_birth_name_kept": "both"}],
		["guarding", "He sits by her door still", "strahd_destroyed", {"izek_guards_ireena": true}],
		["told", "built a cabin near the woods past Lake Zarovich", "strahd_destroyed", {"izek_told_truth": true}],
		["spurned", "refuses his captain the only reward he asked for", "strahd_destroyed", {"izek_spurned": true}],
		["dead, told", "knowing she had a brother", "strahd_destroyed", {"izek_dead": true, "izek_sister_truth": true}],
		["dead", "never knew she had another brother", "strahd_destroyed", {"izek_dead": true}],
		["guarding, dark", "Izek sits awake across Ireena's threshold", "strahd_triumphant", {"izek_guards_ireena": true}],
		["told, dark", "the castle's black carriage", "strahd_triumphant", {"izek_told_truth": true}],
		["dead, dark", "never knew the brother who dreamed her face", "strahd_triumphant", {"izek_dead": true}],
	]
	for c: Array in cases:
		var st := _party()
		for k: Variant in (c[3] as Dictionary):
			st.set_flag(str(k), (c[3] as Dictionary)[k])
		var slide := {}
		for s in Endings.slides(Endings.get_ending(str(c[2])), st):
			if str(s["topic"]) == "izek":
				slide = s
		assert_false(slide.is_empty(), str(c[0]))
		assert_true(str(slide.get("text", "")).contains(str(c[1])), str(c[0]) + ": " + str(slide.get("text", "")))
	var nobody := _party()
	for s in Endings.slides(Endings.get_ending("strahd_destroyed"), nobody):
		assert_ne(str(s["topic"]), "izek", "no slide for an Izek the party never met")


func test_none_of_it_names_the_count_or_moves_a_story_flag() -> void:
	var text := FileAccess.get_file_as_string("res://narrative/allies/izek.dialogue")
	var kept: Array[String] = []
	for line in text.split("\n"):
		if not line.begins_with("#"):
			kept.append(line)
	var spoken := "\n".join(kept)
	assert_false(spoken.contains("Strahd"), "never his name")
	assert_false(spoken.contains("DC "), "nothing rolls")
	assert_false(spoken.contains("{"), "no placeholder in a line that may be voiced")
	assert_eq(spoken.count("Viorela"), 2, "the name only in the scene that tells it")
