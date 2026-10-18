extends TestCase
## Ireena's check-in hub (Story Allies Presence Plan, package I1; narrative/allies/ireena.dialogue, docs/story/ireena_checkin.md).
## One conversation opened from where she is: the Blue Water Inn, St. Andral's, the Krezkovs' house, the mansion once the party
## left her there, and (her `guest_talk`) on the road. It plays a line of her days there (a stage per visit to that place),
## up to three news items a visit (the later parts of the story first, each once), offers up to three of her own topics, and
## ends: there is no roll in it, and it moves only the side flags in data/flags/allies_ireena.json.

const HUB := "allies/ireena:checkin"
const BYE := "Keep safe until we get back."
const MOVE_ON := "Let's keep moving."
const MIND := "Is something on your mind?"
const ELSE := "Let's talk about something else."
const SIDE_FLAGS := "res://data/flags/allies_ireena.json"
const PLACES: Array[String] = ["inn", "church", "krezk", "mansion", "road"]


func after_each() -> void:
	StrahdPresence.use_attention({})
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame


## The four pregens at level 8, with a cleric among them.
func _party() -> StoryState:
	var st := StoryState.new()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		st.party.append(Pregens.build(id, 8))
	return st


## A party with Ireena where `place` says: the inn, the church, Krezk, the mansion (declined), or travelling.
func _at(place: String) -> StoryState:
	var st := _party()
	match place:
		"inn":
			st.set_flag("ireena_sanctuary", "inn")
		"church":
			st.set_flag("ireena_sanctuary", "st_andrals")
		"krezk":
			st.set_flag("ireena_in_krezk")
		"mansion":
			st.set_flag("ireena_escort", "declined")
		"road":
			st.add_guest("ireena")
	return st


## Plays `ref`, taking at each menu the option that begins like the next entry of `script` (a menu with no entry left stays
## open). A script entry no option fits fails the test and stops. Returns every beat; the last is the end beat when the
## conversation reached its end.
func _play(st: StoryState, ref: String, script: Array[String] = [], seed_value: int = 1) -> Array[Dictionary]:
	var beats: Array[Dictionary] = []
	var r := DialogueRunner.new(st, DiceRoller.new(seed_value))
	assert_true(r.start(ref), "starts " + ref)
	var b := r.next()
	var at := 0
	for i in 400:
		beats.append(b)
		var kind := str(b.get("kind", ""))
		if kind == "end":
			break
		if kind == "options":
			if at >= script.size():
				break
			var pick := -1
			var opts := b["options"] as Array
			for j in opts.size():
				if pick < 0 and str((opts[j] as Dictionary)["text"]).begins_with(script[at]):
					pick = j
			if pick < 0:
				fail("'%s' is not offered (menu: %s)" % [script[at], str(_texts(b))])
				break
			at += 1
			b = r.choose(pick)
		else:
			b = r.next()
	return beats


static func _texts(options_beat: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for o: Variant in options_beat["options"] as Array:
		out.append(str((o as Dictionary)["text"]))
	return out


## The options beats of a play, as lists of option texts, in order.
static func _menus(beats: Array[Dictionary]) -> Array:
	var out: Array = []
	for b in beats:
		if str(b.get("kind", "")) == "options":
			out.append(_texts(b))
	return out


static func _said(beats: Array[Dictionary], words: String) -> bool:
	for b in beats:
		if str(b.get("kind", "")) == "line" and str(b.get("text", "")).contains(words):
			return true
	return false


static func _ended(beats: Array[Dictionary]) -> bool:
	return not beats.is_empty() and str(beats[-1].get("kind", "")) == "end"


## A check-in that ends at once: the place's goodbye.
func _checkin(st: StoryState, more: Array[String] = []) -> Array[Dictionary]:
	var bye := MOVE_ON if "ireena" in st.guest_ids else BYE
	var script: Array[String] = []
	script.append_array(more)
	script.append(bye)
	return _play(st, HUB, script)


# --- Where the hub opens ---------------------------------------------------------------------------------------------------

func test_a_click_on_her_on_the_road_opens_the_hub() -> void:
	assert_eq(str(Compendium.shared().get_entry("npcs", "ireena").get("guest_talk", "")), HUB, "guest_talk names the hub")
	assert_true(DialogueRunner.new(_party(), DiceRoller.new(1)).start(HUB), "and it starts")


func test_each_refuge_menu_carries_one_option_into_the_hub() -> void:
	var cases: Array[Array] = [
		["vallaki/ireena:at_inn", "inn", "How are you holding up under the Martikovs' roof?"],
		["vallaki/ireena:at_church", "church", "How are you holding up here at the church?"],
		["krezk/ireena:at_krezk", "krezk", "How are they treating you behind Krezk's wall?"],
		["village_of_barovia/ireena:declined", "mansion", "How are you holding up in the old house?"],
	]
	for c in cases:
		var st := _at(c[1] as String)
		var beats := _play(st, c[0] as String, [c[2] as String, BYE])
		var first := _menus(beats)[0] as Array
		assert_eq(first.count(c[2]), 1, "%s: the option is there exactly once (%s)" % [c[0], str(first)])
		assert_eq((first as Array).filter(func(t: String) -> bool: return t.begins_with("How are")).size(), 1, "%s: and it is the only one of its kind" % c[0])
		assert_true(_ended(beats), "%s: the check-in ends" % c[0])
		assert_eq(int(st.get_flag("ireena_checkins", 0)), 1, "%s: it counts a check-in" % c[0])


# --- Her days: a stage a visit ---------------------------------------------------------------------------------------------

func test_the_line_of_her_days_moves_on_with_each_visit_to_a_place() -> void:
	var stages := {
		"inn": ["I dry glasses until midnight", "three black feathers", "aren't simple innkeepers"],
		"church": ["ring the vespers bell", "my own head makes plenty of noise", "footwork against the churchyard posts"],
		"krezk": ["a morning watch on the wall", "sit by little Ilya's bed", "I never look down into the water"],
		"mansion": ["stew from the tavern", "talk to the panelling", "sorting Father's ledgers"],
		"road": ["who snores", "middle watch tonight", "dark edge of the trees"],
	}
	var goodbyes := {"inn": "keep something hot by the hearth", "church": "saint's bones only reach", "krezk": "Tell Dmitri at the gate",
		"mansion": "three knocks", "road": "Lead on, then"}
	for place in PLACES:
		var st := _at(place)
		for visit in 4:
			var beats := _checkin(st)
			var want := (stages[place] as Array)[mini(visit, 2)] as String
			assert_true(_said(beats, want), "%s, visit %d: '%s'" % [place, visit + 1, want])
			assert_eq(int(st.get_flag("ireena_visits_" + place, 0)), visit + 1, "%s: the visit is counted" % place)
			assert_true(_said(beats, goodbyes[place] as String), "%s: she says goodbye" % place)
			assert_true(_ended(beats), "%s: the visit ends" % place)
		assert_eq(int(st.get_flag("ireena_checkins", 0)), 4, "%s: four check-ins" % place)
		assert_eq(int(st.get_flag("ireena_trust", 0)), 1, "%s: trust rose once, on the first visit there" % place)


func test_trust_rises_once_for_each_place_she_is_checked_on() -> void:
	var st := _at("inn")
	_checkin(st)
	_checkin(st)
	assert_eq(int(st.get_flag("ireena_trust", 0)), 1, "a second visit to the same place adds nothing")
	st.set_flag("ireena_sanctuary", "st_andrals")
	_checkin(st)
	assert_eq(int(st.get_flag("ireena_trust", 0)), 2, "another place adds one")
	st.add_guest("ireena")
	_checkin(st)
	assert_eq(int(st.get_flag("ireena_trust", 0)), 3, "and so does the first talk on the road")


func test_the_greeting_is_for_a_refuge_and_follows_the_count() -> void:
	var st := _at("inn")
	assert_true(_said(_checkin(st), "check the locks"), "the first check-in")
	assert_true(_said(_checkin(st), "Back with all your limbs"), "the second")
	assert_true(_said(_checkin(st), "wet wool and trouble"), "the third and later")
	var road := _at("road")
	var beats := _checkin(road)
	assert_false(_said(beats, "check the locks"), "on the road she doesn't greet the party as if it had come in")


func test_the_variants_of_her_days() -> void:
	var inn := _at("inn")
	inn.set_flag("keepers_of_the_feather_met")
	for i in 3:
		_checkin(inn)
	var keepers := _checkin(inn)
	assert_true(_said(keepers, "come down from the eaves"), "the Keepers' friends are told what the family are")
	assert_false(_said(keepers, "aren't simple innkeepers"), "instead of the suspicion")
	var well := _at("krezk")
	well.set_flag("ilya_fate", "healed")
	_checkin(well)
	assert_true(_said(_checkin(well), "follows me along the path"), "Ilya well: he follows her")
	var pool := _at("krezk")
	pool.set_flag("ireena_pool_vision")
	_checkin(pool)
	_checkin(pool)
	assert_true(_said(_checkin(pool), "stopped asking about the pool"), "after the pool she is past not knowing why")


# --- News ------------------------------------------------------------------------------------------------------------------

func test_news_is_three_at_a_time_newest_first_and_once() -> void:
	var st := _at("inn")
	st.set_flag("eva_reading_done")
	st.set_flag("bones_returned")
	st.set_flag("vallaki_backed", "neither")
	st.set_flag("izek_told_truth")
	st.set_flag("winery_wine_flows")
	var first := _checkin(st)
	assert_true(_said(first, "Wizard of Wines") and _said(first, "walked away from the Baron's service") and _said(first, "running the town now"),
		"the wine, Izek and the festival, the three latest")
	assert_false(_said(first, "back in the crypt") or _said(first, "fortune-tellers"), "the bones and the reading wait")
	assert_eq(int(st.get_flag("ireena_news_now", 0)), 3, "three told")
	var second := _checkin(st)
	assert_true(_said(second, "back in the crypt") and _said(second, "fortune-tellers"), "next time the other two")
	assert_false(_said(second, "Wizard of Wines") or _said(second, "running the town now"), "and none twice")
	assert_eq(int(st.get_flag("ireena_news_now", 0)), 2, "the count starts over each visit")
	var third := _checkin(st)
	assert_false(_said(third, "back in the crypt") or _said(third, "walked away from the Baron's service"), "nothing is told a third time")
	assert_eq(int(st.get_flag("ireena_news_now", 0)), 0)
	st.set_flag("abbot_fate", "slain")
	assert_true(_said(_checkin(st), "his needlework"), "new news turns up on the next visit")


## (flags to set, a phrase her reaction has). Items are named "item:<id>"; "attention" raises Strahd's attention to the top.
func _news_cases() -> Array[Array]:
	return [
		[{"strahd_invitation": "accepted"}, "silver table"], [{"strahd_invitation": "declined"}, "empty black carriage"],
		[{"attention": true}, "knows your names"], [{"dark_gifts_taken": 1}, "old sweet resin"],
		[{"mordenkainen_restored": true}, "madman on the mountain"],
		[{"lysaga_dead": true, "marina_truth_known": true}, "let him drown a whole village"],
		[{"marina_truth_known": true}, "keep the devil's heart tidy"], [{"lysaga_dead": true}, "one less nursemaid"],
		[{"item:sunsword": true}, "shadows in the corners"], [{"item:holy_symbol_of_ravenkind": true}, "a light that actually answers"],
		[{"item:tome_of_strahd": true}, "strapped shut"], [{"argynvost_beacon_lit": true}, "western ridge"],
		[{"abbot_fate": "wedding"}, "Vasilka together"], [{"abbot_fate": "repentant"}, "answer for what he made"],
		[{"abbot_fate": "broken"}, "stones of his altar"], [{"abbot_fate": "slain"}, "his needlework"],
		[{"van_richten_reunited": true}, "made up after twelve years"],
		[{"bonegrinder_fate": "destroyed"}, "no more children into their pies"], [{"bonegrinder_fate": "broken"}, "no more children into their pies"],
		[{"bonegrinder_fate": "bella"}, "bargains with monsters"], [{"bonegrinder_fate": "bargain"}, "bargains with monsters"],
		[{"bonegrinder_fate": "abandoned"}, "left the children behind"],
		[{"wolf_pack_leader": "emil"}, "won't answer the lord of the castle"], [{"wolf_pack_leader": "kiril"}, "the other still hunts"],
		[{"wolf_pack_leader": "none"}, "scattered into the hills"],
		[{"den_children_freed": true}, "back from the caves"], [{"yester_hill_resolved": true}, "wooden giant"],
		[{"winery_wine_flows": true}, "Wizard of Wines"],
		[{"izek_told_truth": true}, "word brother"], [{"izek_dead": true}, "door slammed shut"],
		[{"izek_dead": true, "izek_sister_truth": true}, "took my name with him"],
		[{"vallaki_backed": "baron"}, "another festival for the dark"], [{"vallaki_backed": "wachter"}, "larger cage"],
		[{"vallaki_backed": "neither"}, "running the town now"],
		[{"bones_returned": true}, "back in the crypt"], [{"eva_reading_done": true}, "fortune-tellers"],
	]


func test_every_piece_of_news_has_her_reaction() -> void:
	StrahdPresence.use_attention({"tiers": [{"id": "unnoticed", "min": 0, "gap": 1.0}, {"id": "hunted", "min": 5, "gap": 0.5}],
		"marks": [{"id": "m", "when": "flag.test_mark", "points": 5, "summary": ""}]})
	for c in _news_cases():
		var st := _at("church")
		for k: String in (c[0] as Dictionary).keys():
			var v: Variant = (c[0] as Dictionary)[k]
			if k == "attention":
				st.set_flag("test_mark")
			elif k.begins_with("item:"):
				st.party[0].add_item(k.trim_prefix("item:"))
			else:
				st.set_flag(k, v)
		var beats := _checkin(st)
		assert_true(_said(beats, c[1] as String), "%s: '%s'" % [str(c[0]), c[1]])
		assert_eq(int(st.get_flag("ireena_news_now", 0)), 1, "%s: it is the only news" % str(c[0]))
		assert_true(_ended(beats), "%s: the check-in ends" % str(c[0]))


func test_with_no_news_she_has_none() -> void:
	var st := _at("church")
	_checkin(st)
	assert_eq(int(st.get_flag("ireena_news_now", 0)), 0, "nothing has happened, nothing is told")


# --- What is on her mind ---------------------------------------------------------------------------------------------------

func test_her_topics_are_the_three_newest_each_heard_once() -> void:
	var st := _at("krezk")
	st.set_flag("ireena_pool_vision")
	st.set_flag("izek_saw_ireena")
	var beats := _play(st, HUB, [MIND, "What are you making of", MIND, ELSE, BYE])
	var menus := _menus(beats)
	var topics := menus[1] as Array
	assert_true(topics.has("What are you making of what you remembered at the pool?") and topics.has("Is Izek on your mind?")
		and topics.has("Have you had the dream of the lake again?"), "Tatyana, Izek and the dream first (%s)" % str(topics))
	assert_false(topics.has("How are your nights, with the marks on your neck?") or topics.has("Are you thinking about your father?"),
		"the two oldest wait")
	assert_true(bool(st.get_flag("ireena_heard_tatyana", false)), "the pool topic was heard")
	var again := menus[3] as Array
	assert_false(again.has("What are you making of what you remembered at the pool?"), "and is not offered again")
	assert_true(again.has("How are your nights, with the marks on your neck?"), "the next oldest comes up in its place")
	assert_false(again.has("Are you thinking about your father?"), "never more than three")
	assert_true(_ended(beats))


func test_her_topics_run_out() -> void:
	var st := _at("church")
	var beats := _play(st, HUB, [MIND, "Have you had the dream", MIND, "How are your nights", MIND, "Are you thinking about your father", BYE])
	assert_true(_ended(beats))
	assert_eq(int(st.get_flag("ireena_topics_now", 0)), 0, "nothing left to offer")
	var last := _menus(beats)[-1] as Array
	assert_false(last.has(MIND), "so the question is gone from the menu (%s)" % str(last))
	for k: String in ["dreams", "bites", "father"]:
		assert_true(bool(st.get_flag("ireena_heard_" + k, false)), k + " heard")
	assert_false(bool(st.get_flag("ireena_heard_tatyana", false)), "the pool topic needs the pool")
	assert_false(bool(st.get_flag("ireena_heard_izek_mind", false)), "the Izek topic needs Izek")


func test_each_topic_reads_by_what_happened() -> void:
	var cases: Array[Array] = [
		[{"burial_method": "church_rites"}, "Are you thinking about your father?", "Father Donavich got Father"],
		[{"burial_method": "cleric_rites"}, "Are you thinking about your father?", "Your cleric spoke the rites"],
		[{"burial_method": "hasty"}, "Are you thinking about your father?", "ground fast, without a prayer"],
		[{"burial_method": "lay_rites"}, "Are you thinking about your father?", "None of you were priests"],
		[{}, "Are you thinking about your father?", "None of you were priests"],
		[{}, "How are your nights", "check the latch twice"],
		[{}, "Have you had the dream", "dark lake"],
		[{"izek_saw_ireena": true}, "Is Izek on your mind?", "bolt of cloth"],
		[{"izek_saw_ireena": true, "izek_sister_truth": true}, "Is Izek on your mind?", "call a stranger"],
		[{"izek_saw_ireena": true, "izek_dead": true}, "Is Izek on your mind?", "under the dirt"],
		[{"ireena_pool_vision": true, "ireena_pool_choice": "promised"}, "What are you making of", "I promised Sergei"],
		[{"ireena_pool_vision": true, "ireena_pool_choice": "stayed"}, "What are you making of", "washbasin"],
		[{"ireena_pool_vision": true}, "What are you making of", "two women's lives"],
	]
	for c in cases:
		var st := _at("inn")
		for k: String in (c[0] as Dictionary).keys():
			st.set_flag(k, (c[0] as Dictionary)[k])
		var beats := _play(st, HUB, [MIND, c[1] as String, BYE])
		assert_true(_said(beats, c[2] as String), "%s: '%s'" % [str(c[0]), c[2]])
		assert_true(_ended(beats), "%s: it ends" % str(c[0]))


# --- Taking her along, and the ways out ------------------------------------------------------------------------------------

func test_taking_her_along_goes_through_the_existing_rejoin_nodes() -> void:
	var inn := _at("inn")
	var beats := _play(inn, HUB, ["Come with us again."])
	assert_true(_ended(beats))
	assert_true("ireena" in inn.guest_ids, "she joins from the inn")
	assert_eq(str(inn.get_flag("ireena_sanctuary", "")), "with_party")
	var church := _at("church")
	_play(church, HUB, ["Come with us again."])
	assert_true("ireena" in church.guest_ids, "and from the church")
	var krezk := _at("krezk")
	_play(krezk, HUB, ["Come with us again, Ireena."])
	assert_true("ireena" in krezk.guest_ids, "and from Krezk")
	assert_false(bool(krezk.get_flag("ireena_in_krezk", false)), "no longer in Krezk")
	var mansion := _at("mansion")
	var asked := _play(mansion, HUB, ["We'll take you after all.", "We'll take you after all. Vallaki.", "Someone should stay"])
	assert_true(_ended(asked))
	assert_true("ireena" in mansion.guest_ids, "and from the mansion, through her escort question")
	assert_eq(str(mansion.get_flag("ireena_escort", "")), "accepted")
	var road := _at("road")
	for menu: Variant in _menus(_checkin(road)):
		assert_false((menu as Array).any(func(t: String) -> bool: return t.begins_with("Come with us") or t.begins_with("We'll take you")),
			"on the road she is already with them")


func test_every_visit_has_a_way_out_even_where_she_stands_nowhere_we_know() -> void:
	var nowhere := _party()
	var beats := _play(nowhere, HUB, [BYE])
	assert_true(_ended(beats), "no place at all: it still ends")
	for place in PLACES:
		assert_true(_ended(_checkin(_at(place))), place + " ends")


# --- What it touches ---------------------------------------------------------------------------------------------------------

func test_a_check_in_moves_only_her_side_flags_and_asks_for_no_roll() -> void:
	var registry: Dictionary = {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SIDE_FLAGS))
	assert_true(parsed is Dictionary, "the side flag file reads")
	for f: Variant in (parsed as Dictionary)["flags"] as Array:
		registry[str((f as Dictionary)["id"])] = true
	var st := _at("inn")
	st.set_flag("pre_existing_story_flag")
	for k: String in ["eva_reading_done", "bones_returned", "izek_told_truth", "winery_wine_flows", "ireena_pool_vision", "izek_saw_ireena"]:
		st.set_flag(k)
	var before := st.flags.duplicate(true)
	_play(st, HUB, [MIND, "What are you making of", MIND, "Is Izek", MIND, "Have you had the dream", MIND, "How are your nights", MIND, "Are you thinking", BYE])
	for i in 3:
		_play(st, HUB, [BYE])
	for k: String in st.flags.keys():
		if not before.has(k):
			assert_true(registry.has(k), "%s is a registered side flag" % k)
		elif not registry.has(k):
			assert_eq(st.flags[k], before[k], "%s, a story flag, is untouched" % k)
	var file := FileAccess.get_file_as_string("res://narrative/allies/ireena.dialogue")
	assert_false(file.contains(" DC "), "no check in the hub: a failed one would be spent")
	assert_false(file.contains("{name}"), "no line that couldn't be voiced")
	for line in file.split("\n"):
		if line.begins_with("Ireena"):
			assert_true(line.begins_with("Ireena:") or line.begins_with("Ireena ["), "a malformed line: " + line)
			assert_false(line.to_lower().contains("strahd"), "she never says his name: " + line)
	assert_true(registry.size() > 30, "the side flags are registered")
