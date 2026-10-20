extends TestCase
## Ireena's letters (Story Allies Presence Plan, package I3; narrative/allies/ireena_letters.dialogue, data/visits/ireena.json,
## docs/story/ireena_letters.md). While she shelters elsewhere (the Blue Water Inn, St. Andral's, the Krezkovs' house, her
## father's mansion once the party declined to take her) and the party is somewhere else, a courier finds the party outdoors
## with a letter in her hand after something big: the festival's end, the Abbot's bats, the werewolf den, the winery's wine,
## the light at Argynvostholt, the dinner at the castle. Each adds one to ireena_letters_unanswered; any check-in clears it
## and, when two or three were left, opens cold. At three, Strahd writes about her once and her trust falls by one.

const VISIT := "ireena_letter"
const SILENCE := "ireena_silence"
const LETTER := "allies/ireena_letters:letter"
const SILENCE_INTRO := "allies/ireena_letters:strahd_silence_intro"
const CHECKIN := "allies/ireena:checkin"
const ROAD := {"location": "svalich_crossroads"}
## What the letters may change besides the story's own flags (data/flags/allies_ireena.json).
const SIDE_FLAGS: Array[String] = ["ireena_letters_sent", "ireena_letters_unanswered", "ireena_cold_now", "ireena_sent_festival",
	"ireena_sent_abbot", "ireena_sent_den", "ireena_sent_wine", "ireena_sent_beacon", "ireena_sent_dinner",
	"ireena_strahd_wrote_silence", "ireena_trust"]


func _party(location: String = "svalich_crossroads") -> StoryState:
	return SideQuestPlay.party(["ilse_varga", "hedda_ironvow"], 6, location, 12)


## Ireena sheltering at `place` ("inn", "st_andrals", "krezk" or "mansion"), met.
func _left(st: StoryState, place: String = "inn") -> StoryState:
	st.set_flag("ireena_met")
	match place:
		"inn", "st_andrals":
			st.set_flag("ireena_sanctuary", place)
		"krezk":
			st.set_flag("ireena_in_krezk")
		"mansion":
			st.set_flag("ireena_escort", "declined")
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


## The flags that differ between two copies of the story's flags (the visits' own memory aside).
static func _changed(before: Dictionary, after: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k: Variant in after:
		if str(k) == "_strahd":
			continue
		if not before.has(k) or before[k] != after[k]:
			out.append(str(k))
	return out


## Each letter's event as story flags, and a phrase only that letter says.
func _events() -> Array[Dictionary]:
	return [
		{"id": "festival", "flags": {"festival_over": true, "vallaki_backed": "baron"}, "says": "half of them change the story at every milepost"},
		{"id": "abbot", "flags": {"abbot_told_strahd": true}, "says": "bats circle the high wall every night now"},
		{"id": "den", "flags": {"wolf_pack_leader": "emil"}, "says": "over a turnip cart"},
		{"id": "wine", "flags": {"winery_wine_flows": true}, "says": "a single cask by the door with no note"},
		{"id": "beacon", "flags": {"argynvost_beacon_lit": true}, "says": "the white light burning above Argynvostholt"},
		{"id": "dinner", "flags": {"strahd_invitation": "accepted"}, "says": "ate off his silver"},
	]


func _happen(st: StoryState, event: Dictionary) -> void:
	for k: Variant in (event["flags"] as Dictionary):
		st.set_flag(str(k), (event["flags"] as Dictionary)[k])


# --- When a courier comes -----------------------------------------------------------------------------------------------

func test_a_courier_comes_outdoors_while_she_shelters_elsewhere_and_something_has_happened() -> void:
	StrahdPresence.use({})
	var quiet := _left(_party())
	assert_true(StrahdPresence.due(quiet, "arrive", ROAD).is_empty(), "nothing has happened she would hear of")
	var st := _left(_party())
	st.set_flag("festival_over")
	var v := StrahdPresence.due(st, "arrive", ROAD)
	assert_eq(str(v.get("id", "")), VISIT)
	assert_true(StrahdPresence.is_ally(v), "an ally's visit, not Strahd's")
	assert_eq(str(StrahdPresence.begin(st, v).get("dialogue", "")), LETTER)
	var on_the_road := _left(_party())
	on_the_road.set_flag("festival_over")
	assert_eq(str(StrahdPresence.due(on_the_road, "travel", {"location": "", "outdoors": true}).get("id", "")), VISIT, "a leg of a journey too")


func test_no_letter_when_she_has_not_been_met_travels_with_the_party_or_is_in_the_castle() -> void:
	StrahdPresence.use({})
	var strangers := _party()
	strangers.set_flag("ireena_sanctuary", "inn")
	strangers.set_flag("festival_over")
	assert_true(StrahdPresence.due(strangers, "arrive", ROAD).is_empty(), "never met")
	var along := _left(_party())
	along.set_flag("festival_over")
	assert_true(along.add_guest("ireena"))
	assert_true(StrahdPresence.due(along, "arrive", ROAD).is_empty(), "already with them")
	var held := _left(_party())
	held.set_flag("festival_over")
	held.set_flag("ireena_held_by_strahd")
	held.set_flag("ireena_sanctuary", "taken")
	assert_true(StrahdPresence.due(held, "arrive", ROAD).is_empty(), "she is in the castle")
	var indoors := _left(_party("krezk_burgomaster_house"))
	indoors.set_flag("festival_over")
	assert_true(StrahdPresence.due(indoors, "arrive", {"location": "krezk_burgomaster_house"}).is_empty(), "a courier finds the party outdoors")


func test_no_letter_when_the_party_is_in_the_place_she_shelters_in() -> void:
	StrahdPresence.use({})
	for case: Array in [["inn", "vallaki"], ["st_andrals", "vallaki"], ["krezk", "krezk"], ["mansion", "village_of_barovia"]]:
		var here := _left(_party(str(case[1])), str(case[0]))
		here.set_flag("festival_over")
		here.set_flag("abbot_told_strahd")
		assert_true(StrahdPresence.due(here, "arrive", {"location": str(case[1])}).is_empty(), str(case[0]) + ": the party is where she is")
		var away := _left(_party(), str(case[0]))
		away.set_flag("festival_over")
		away.set_flag("abbot_told_strahd")
		assert_eq(str(StrahdPresence.due(away, "arrive", ROAD).get("id", "")), VISIT, str(case[0]) + ": and a letter when they are not")


func test_letters_are_forty_eight_hours_apart_and_stop_at_three_unanswered() -> void:
	StrahdPresence.use({})
	var st := _left(_party())
	st.set_flag("festival_over")
	assert_eq(str(StrahdPresence.due(st, "arrive", ROAD).get("id", "")), VISIT)
	SideQuestPlay.play(st, LETTER)
	st.set_flag("abbot_told_strahd")
	st.day += 1
	assert_true(StrahdPresence.due(st, "arrive", ROAD).is_empty(), "a day later is too soon")
	st.day += 1
	assert_eq(str(StrahdPresence.due(st, "arrive", ROAD).get("id", "")), VISIT, "two days on")
	SideQuestPlay.play(st, LETTER)
	st.set_flag("wolf_pack_leader", "none")
	st.day += 2
	assert_eq(str(StrahdPresence.due(st, "arrive", ROAD).get("id", "")), VISIT, "the third")
	SideQuestPlay.play(st, LETTER)
	assert_eq(int(st.get_flag("ireena_letters_unanswered", 0)), 3)
	st.set_flag("winery_wine_flows")
	st.day += 5
	assert_true(StrahdPresence.due(st, "arrive", ROAD).is_empty(), "three unanswered: she stops writing, however much has happened")


func test_every_letter_comes_once_and_at_most_six_in_a_playthrough() -> void:
	StrahdPresence.use({})
	var st := _left(_party())
	for e in _events():
		_happen(st, e)
	var sent: Array[String] = []
	for i in 10:
		st.day += 2
		var v := StrahdPresence.due(st, "arrive", ROAD)
		if v.is_empty():
			break
		SideQuestPlay.play(st, LETTER)
		st.set_flag("ireena_letters_unanswered", 0)   # a check-in between letters
		sent.append(str(v["id"]))
	assert_eq(sent.size(), 6, "six letters for six events")
	assert_eq(int(st.get_flag("ireena_letters_sent", 0)), 6)
	for e in _events():
		assert_true(bool(st.get_flag("ireena_sent_" + str(e["id"]), false)), str(e["id"]) + ": written")
	st.day += 5
	assert_true(StrahdPresence.due(st, "arrive", ROAD).is_empty(), "and no seventh")


# --- The letters ------------------------------------------------------------------------------------------------------------

func test_each_event_gets_its_own_letter_and_the_first_pending_in_the_storys_order_comes_first() -> void:
	for e in _events():
		var st := _left(_party())
		_happen(st, e)
		var beats := SideQuestPlay.play(st, LETTER)
		assert_eq(SideQuestPlay.missing(beats), "")
		assert_true(_says(beats, str(e["says"])), str(e["id"]) + ": her words")
		assert_true(bool(st.get_flag("ireena_sent_" + str(e["id"]), false)), str(e["id"]) + ": marked written")
		assert_eq(int(st.get_flag("ireena_letters_sent", 0)), 1)
		assert_eq(int(st.get_flag("ireena_letters_unanswered", 0)), 1)
	var both := _left(_party())
	_happen(both, _events()[0])
	_happen(both, _events()[1])
	assert_true(_says(SideQuestPlay.play(both, LETTER), "change the story at every milepost"), "the festival first")
	assert_true(_says(SideQuestPlay.play(both, LETTER), "bats circle the high wall"), "then the Abbot's bats")
	assert_eq(int(both.get_flag("ireena_letters_unanswered", 0)), 2)


func test_the_festival_and_the_den_letters_say_how_it_ended() -> void:
	for case: Array in [["baron", "smiling again at the point of a pike"], ["wachter", "Lady Wachter keeps the town"], ["neither", "only Father Lucian and Urwin Martikov keep the peace"]]:
		var st := _left(_party())
		st.set_flag("festival_over")
		st.set_flag("vallaki_backed", str(case[0]))
		assert_true(_says(SideQuestPlay.play(st, LETTER), str(case[1])), "festival: " + str(case[0]))
	for case: Array in [["emil", "keeps his teeth to the high timber"], ["kiril", "hunts at the castle's pleasure"], ["none", "both pack leaders are dead"]]:
		var st := _left(_party())
		st.set_flag("wolf_pack_leader", str(case[0]))
		assert_true(_says(SideQuestPlay.play(st, LETTER), str(case[1])), "den: " + str(case[0]))


func test_the_courier_is_the_place_she_is_in() -> void:
	for case: Array in [["inn", "carter's boy"], ["st_andrals", "carter's boy"], ["krezk", "grey-cloaked pilgrim"], ["mansion", "village child"]]:
		var st := _left(_party(), str(case[0]))
		st.set_flag("festival_over")
		assert_true(_says(SideQuestPlay.play(st, LETTER), str(case[1])), str(case[0]))


func test_no_letter_gives_the_party_anything_to_do_and_each_lets_them_go_two_ways() -> void:
	for e in _events():
		var st := _left(_party())
		_happen(st, e)
		var beats := SideQuestPlay.play(st, LETTER)
		assert_true(_ends(beats), str(e["id"]) + ": the scene ends")
		assert_true(_has_option(beats, "Keep it safe"), str(e["id"]))
		assert_true(_has_option(beats, "Tell the messenger"), str(e["id"]))
		var kept := _left(_party())
		_happen(kept, e)
		assert_true(_says(SideQuestPlay.play(kept, LETTER, ["Keep it safe"]), "tuck it dry inside your pack"), "kept")
		var told := _left(_party())
		_happen(told, e)
		assert_true(_says(SideQuestPlay.play(told, LETTER, ["Tell the messenger"]), "you will come as soon as the road allows"), "told")


func test_no_letter_moves_a_story_flag() -> void:
	for e in _events():
		var st := _left(_party())
		_happen(st, e)
		var before := st.flags.duplicate(true)
		SideQuestPlay.play(st, LETTER)
		for k in _changed(before, st.flags):
			assert_true(k in SIDE_FLAGS, str(e["id"]) + ": " + k + " is a side flag")


# --- The check-in ------------------------------------------------------------------------------------------------------------

func test_a_check_in_after_two_or_three_unanswered_letters_opens_cold_and_clears_the_count() -> void:
	var calm := _left(_party("vallaki_blue_water_inn"))
	var normal := SideQuestPlay.play(calm, CHECKIN)
	assert_true(_says(normal, "People usually check the locks"), "an ordinary first greeting")
	assert_false(_says(normal, "charcoal"))
	assert_false(_says(normal, "your graves"))
	var calm_trust := int(calm.get_flag("ireena_trust", 0))
	var two := _left(_party("vallaki_blue_water_inn"))
	two.set_flag("ireena_letters_unanswered", 2)
	var cold_two := SideQuestPlay.play(two, CHECKIN)
	assert_eq(SideQuestPlay.missing(cold_two), "")
	assert_true(_says(cold_two, "not a scrap of charcoal in reply"), "two letters")
	assert_false(_says(cold_two, "People usually check the locks"), "the cold greeting takes the usual one's place")
	assert_true(_says(cold_two, "dry glasses until midnight"), "and the check-in goes on into her days")
	assert_eq(int(two.get_flag("ireena_letters_unanswered", 0)), 0, "the count is cleared")
	assert_eq(int(two.get_flag("ireena_trust", 0)), calm_trust, "the coldness costs nothing")
	var three := _left(_party("vallaki_blue_water_inn"))
	three.set_flag("ireena_letters_unanswered", 3)
	var cold_three := SideQuestPlay.play(three, CHECKIN)
	assert_true(_says(cold_three, "I was starting to write the fourth to your graves"), "three letters")
	assert_true(_says(cold_three, "dry glasses until midnight"))
	assert_eq(int(three.get_flag("ireena_letters_unanswered", 0)), 0)
	assert_true(_ends(cold_three), "the check-in lets the party go")
	var one := _left(_party("vallaki_blue_water_inn"))
	one.set_flag("ireena_letters_unanswered", 1)
	var warm := SideQuestPlay.play(one, CHECKIN)
	assert_true(_says(warm, "People usually check the locks"), "one letter is not enough to be cold about")
	assert_eq(int(one.get_flag("ireena_letters_unanswered", 0)), 0, "but a check-in clears it too")


func test_the_cold_greeting_comes_at_the_church_at_krezk_and_at_the_mansion_too() -> void:
	for place: String in ["st_andrals", "krezk", "mansion"]:
		var st := _left(_party("village_of_barovia"), place)
		st.set_flag("ireena_letters_unanswered", 3)
		var beats := SideQuestPlay.play(st, CHECKIN)
		assert_true(_says(beats, "your graves"), place)
		assert_true(_ends(beats), place + ": and an exit")


# --- Strahd writes ------------------------------------------------------------------------------------------------------------

func test_three_unanswered_letters_bring_strahds_note_once() -> void:
	StrahdPresence.use({})
	var st := _left(_party())
	st.set_flag("strahd_watcher_seen")
	st.set_flag("ireena_letters_unanswered", 2)
	assert_true(StrahdPresence.due(st, "arrive", ROAD).is_empty(), "two is not three")
	st.set_flag("ireena_letters_unanswered", 3)
	var v := StrahdPresence.due(st, "arrive", ROAD)
	assert_eq(str(v.get("id", "")), SILENCE)
	assert_true(StrahdPresence.is_ally(v))
	assert_eq(str(StrahdPresence.begin(st, v).get("dialogue", "")), SILENCE_INTRO)
	st.day += 5
	var next := str(StrahdPresence.due(st, "arrive", ROAD).get("id", ""))
	assert_true(next != SILENCE and next != VISIT, "he writes once, and no more letters from her come (a later visit is his own: " + next + ")")
	var unseen := _left(_party())
	unseen.set_flag("ireena_letters_unanswered", 3)
	assert_true(StrahdPresence.due(unseen, "arrive", ROAD).is_empty(), "he writes only once he has been seen")


func test_his_note_lowers_her_trust_by_one_says_where_she_is_and_lets_the_party_burn_or_keep_it() -> void:
	for case: Array in [["inn", "so many windows"], ["st_andrals", "I listen from the street"], ["krezk", "pool that refuses to freeze"], ["mansion", "far too polite to knock"]]:
		var st := _left(_party(), str(case[0]))
		st.set_flag("ireena_trust", 2)
		st.set_flag("ireena_letters_unanswered", 3)
		var before := st.flags.duplicate(true)
		var beats := SideQuestPlay.play(st, SILENCE_INTRO)
		assert_eq(SideQuestPlay.missing(beats), "")
		assert_true(_says(beats, "She asks after you still, though rather less than she did"), str(case[0]))
		assert_true(_says(beats, str(case[1])), str(case[0]) + ": where she is")
		assert_true(_ends(beats), str(case[0]) + ": an exit")
		assert_eq(int(st.get_flag("ireena_trust", 0)), 1, str(case[0]) + ": trust falls by one")
		assert_true(bool(st.get_flag("ireena_strahd_wrote_silence", false)))
		for k in _changed(before, st.flags):
			assert_true(k in SIDE_FLAGS, str(case[0]) + ": " + k + " is a side flag")
	var burn := _left(_party())
	assert_true(_says(SideQuestPlay.play(burn, SILENCE_INTRO, ["Burn it"]), "uncoil"), "burned")
	var keep := _left(_party())
	assert_true(_says(SideQuestPlay.play(keep, SILENCE_INTRO, ["Keep it"]), "a cold that does not leave your skin"), "kept")


# --- The story bot ------------------------------------------------------------------------------------------------------------

func test_the_story_bot_leaves_each_letter_and_strahds_note_by_their_exit() -> void:
	for e in _events():
		var st := _left(_party())
		_happen(st, e)
		var r := DialogueRunner.new(st, DiceRoller.new(5))
		assert_true(r.start(LETTER))
		var b := r.next()
		for i in 20:
			if str(b["kind"]) == "options":
				break
			b = r.next()
		assert_eq(str(b["kind"]), "options", str(e["id"]) + " asks")
		assert_true(AllyVisitAnswer.exit_option(r, b["options"] as Array) >= 0, str(e["id"]) + ": the bot has a way out")
	var note := _left(_party())
	var r2 := DialogueRunner.new(note, DiceRoller.new(5))
	assert_true(r2.start(SILENCE_INTRO))
	var b2 := r2.next()
	for i in 20:
		if str(b2["kind"]) == "options":
			break
		b2 = r2.next()
	assert_eq(str(b2["kind"]), "options")
	assert_true(AllyVisitAnswer.exit_option(r2, b2["options"] as Array) >= 0, "and from Strahd's note")
