extends TestCase
## Strahd's presence (ADR 0014; story/strahd_presence.gd, data/strahd/visits.json, narrative/strahd/): a visit fires
## once on its trigger and condition (not on another event, not too early, not on holy ground, not too soon after the
## last), its steps follow one another (his conversation, then his fight, then his parting words), his fights find
## open floor for their foes and end with his withdrawal and its flag, the conversations set what the rest of the
## campaign reads (the window, the carriage, the parley's price), and the game's hooks play it all: a journey, a rest,
## an arrival. Ally visits (data/visits/, a friend's letter or road meeting) share the engine: they skip his wards and his
## attention, keep his spacing and his quiet places, and the story bot answers their conversations by the exit.

const ROAD := {"location": "", "outdoors": true}
const ALLY_DIR := "user://test_ally_visits"
## A conversation of an ally's visit: its first options go deeper, and the way out is the last.
const LETTER := """~ letter
Narrator: A courier holds out a letter in a hand you know.
* Open it and read it aloud. -> read
* Ask the courier who paid for the road. -> ask
* Put it away. -> END

~ read
Narrator: It is long, and it ends mid-sentence.
* Go on. -> ask

~ ask
Narrator: The courier shrugs.
* Another question. -> read
* Goodbye. -> END

~ sealed
Narrator: A letter, sealed with wax.
* Burn it. -> burned
* [Persuasion DC 10] Talk the courier into reading it. -> kept | burned
* Keep it. -> kept

~ burned
set test_letter_burned
-> END

~ kept
set test_letter_kept
Narrator: It is warm against you.
-> END

~ doorstep
Narrator: He is at the door.
* Fight him. -> brawl
* Shut the door. -> shut

~ brawl
combat strahd_at_the_window

~ shut
Narrator: The door closes.
-> via

~ via
-> END
"""

var root: Node = null
var _saved := {}


func before_each() -> void:
	StrahdPresence.use({})
	DialogueFile.register(DialogueFile.parse(LETTER, "test_allies/letter"))


func after_each() -> void:
	StrahdPresence.use({})
	StrahdPresence.use_attention({})
	if DirAccess.dir_exists_absolute(ALLY_DIR):
		for f: String in DirAccess.get_files_at(ALLY_DIR):
			DirAccess.remove_absolute(ALLY_DIR.path_join(f))
		DirAccess.remove_absolute(ALLY_DIR)
	if root != null:
		root.queue_free()
		root = null
		await get_tree().process_frame
	var c := Compendium.shared()
	for k: String in _saved:
		c.tables[k] = _saved[k]
	for id: String in ["test_hall", "test_town", "test_road_map"]:
		(c.tables["locations"] as Dictionary).erase(id)


func _party(level: int = 3) -> StoryState:
	var st := StoryState.new()
	for id: String in ["ilse_varga", "hedda_ironvow"]:
		var ch := TestChars.pregen(id, level)
		ch.finish_long_rest()
		st.party.append(ch)
	st.minute_of_day = 12 * 60
	return st


## Plays a conversation to its end without the UI: each menu takes the first option containing the next text of
## `picks` (else its first option). Returns the text of every option shown.
func _play(st: StoryState, ref: String, picks: Array[String] = []) -> Array[String]:
	var r := DialogueRunner.new(st, DiceRoller.new(5))
	var seen: Array[String] = []
	if not r.start(ref):
		fail("no conversation at %s" % ref)
		return seen
	var b := r.next()
	var used := 0
	for i in 400:
		var kind := str(b["kind"])
		if kind == "end":
			return seen
		if kind == "options":
			var opts := b["options"] as Array
			var pick := 0
			for j in opts.size():
				seen.append(str((opts[j] as Dictionary)["text"]))
				if used < picks.size() and str((opts[j] as Dictionary)["text"]).containsn(picks[used]) and pick == 0:
					pick = j
			if used < picks.size():
				used += 1
			b = r.choose(pick)
			continue
		b = r.next()
	fail("%s never ended" % ref)
	return seen


# --- When visits happen ---------------------------------------------------------------------------

func test_the_watcher_comes_once_on_the_road_after_the_burial() -> void:
	var st := _party()
	assert_true(StrahdPresence.due(st, "travel", ROAD).is_empty(), "nothing before the burial")
	st.set_flag("burgomaster_buried", true)
	assert_true(StrahdPresence.due(st, "arrive", {"location": "village_of_barovia"}).is_empty(), "the watcher is on the road, not on arriving")
	var v := StrahdPresence.due(st, "travel", ROAD)
	assert_eq(str(v.get("id", "")), "watcher")
	assert_eq(StrahdPresence.times(st, "watcher"), 1)
	assert_eq(str(StrahdPresence.begin(st, v).get("dialogue", "")), "strahd/visits:watcher")
	st.day += 3
	assert_true(StrahdPresence.due(st, "travel", ROAD).is_empty(), "once only")
	_play(st, "strahd/visits:watcher")
	assert_true(bool(st.get_flag("strahd_watcher_seen")), "the watcher is seen, and the later visits can follow")


func test_the_night_visit_needs_a_rest_through_the_night_from_the_fourth_day() -> void:
	var st := _party()
	st.set_flag("strahd_watcher_seen", true)
	var inn := {"location": "vallaki_blue_water_inn", "night": true}
	assert_true(StrahdPresence.due(st, "rest", inn).is_empty(), "too early: day 1")
	st.day = 4
	assert_true(StrahdPresence.due(st, "rest", {"location": "vallaki_blue_water_inn", "night": false}).is_empty(), "a rest by day")
	assert_true(StrahdPresence.due(st, "rest", {"location": "vallaki_st_andrals", "night": true}).is_empty(), "never on holy ground")
	assert_true(StrahdPresence.due(st, "arrive", inn).is_empty(), "it waits for a rest")
	assert_eq(str(StrahdPresence.due(st, "rest", inn).get("id", "")), "night_visit")
	st.day = 9
	assert_true(StrahdPresence.due(st, "rest", inn).is_empty(), "once only")
	assert_true(StrahdPresence.night_between(22 * 60, 30 * 60), "a rest from ten at night runs through the night")
	assert_false(StrahdPresence.night_between(8 * 60, 16 * 60), "a rest from eight in the morning doesn't")


func test_cooldowns_limits_the_gap_and_quiet_places() -> void:
	StrahdPresence.use({"id": "visits", "summary": "", "gap_hours": 10, "quiet_regions": ["krezk"], "quiet_at": ["vallaki_st_andrals"],
		"visits": [
			{"id": "often", "summary": "", "trigger": {"on": ["arrive"]}, "cooldown_hours": 24, "max": 2},
			{"id": "church", "summary": "", "trigger": {"on": ["arrive"], "at": ["vallaki_st_andrals"]}, "once": true, "urgent": true},
			{"id": "later", "summary": "", "trigger": {"on": ["days"], "days": 5}, "once": true, "urgent": true}]})
	var st := _party()
	var town := {"location": "vallaki"}
	assert_true(StrahdPresence.due(st, "arrive", {"location": "krezk"}).is_empty(), "a quiet region")
	assert_eq(str(StrahdPresence.due(st, "arrive", town).get("id", "")), "often")
	st.minute_of_day += 2 * 60
	assert_eq(str(StrahdPresence.due(st, "arrive", {"location": "vallaki_st_andrals"}).get("id", "")), "church",
		"holy ground is quiet unless a visit names it; urgent ignores the gap")
	st.advance_minutes(11 * 60)
	assert_true(StrahdPresence.due(st, "arrive", town).is_empty(), "past the gap but not the cooldown")
	st.day += 1
	assert_eq(str(StrahdPresence.due(st, "arrive", town).get("id", "")), "often", "the cooldown is over")
	st.day += 2
	assert_true(StrahdPresence.due(st, "arrive", town).is_empty(), "max reached")
	st.day = 6
	assert_eq(str(StrahdPresence.due(st, "rest", town).get("id", "")), "later", "`days` fires at any event once the day comes")
	assert_true(StrahdPresence.due(st, "travel", ROAD).is_empty())


# --- A visit's steps ------------------------------------------------------------------------------

func test_the_test_of_strength_talk_then_fight_then_parting_words() -> void:
	var st := _party(7)
	st.set_flag("strahd_watcher_seen", true)
	st.minute_of_day = 23 * 60
	var v := StrahdPresence.due(st, "travel", {"location": "", "outdoors": true, "night": true})
	assert_eq(str(v.get("id", "")), "test_of_strength")
	var step := StrahdPresence.begin(st, v)
	assert_eq(str(step.get("dialogue", "")), "strahd/visits:test")
	assert_false(step.has("encounter"), "he talks first")
	assert_true(StrahdPresence.after_dialogue(st, "strahd/other:node").is_empty(), "another conversation ending changes nothing")
	_play(st, "strahd/visits:test", ["Draw steel"])
	assert_eq(str(st.get_flag("strahd_test", "")), "fought")
	var fight := StrahdPresence.after_dialogue(st, "strahd/visits:test")
	var enc := fight.get("encounter", {}) as Dictionary
	assert_eq(str(enc.get("id", "")), "strahd_test_of_strength")
	var w := enc.get("withdraw", {}) as Dictionary
	assert_eq(str(w.get("who", "")), "strahd_von_zarovich")
	assert_eq(str(w.get("flag", "")), "strahd_withdrew")
	assert_true(StrahdPresence.after_dialogue(st, "strahd/visits:test").is_empty(), "the next step is given once")
	var after := StrahdPresence.after_encounter(st, "victory")
	assert_eq(str(after.get("dialogue", "")), "strahd/visits:test_after")
	_play(st, "strahd/visits:test_after")
	assert_true(bool(st.get_flag("strahd_withdrew")))
	assert_true(StrahdPresence.after_dialogue(st, "strahd/visits:test_after").is_empty(), "and that's the end of it")
	assert_true((StrahdPresence.memory(st)["pending"] as Dictionary).is_empty())


func test_talking_him_out_of_it_means_no_fight_and_losing_means_no_parting_words() -> void:
	var st := _party(7)
	StrahdPresence.begin(st, StrahdPresence.visit("test_of_strength"))
	st.set_flag("strahd_test", "talked")
	assert_true(StrahdPresence.after_dialogue(st, "strahd/visits:test").is_empty(), "no fight")
	StrahdPresence.begin(st, StrahdPresence.visit("test_of_strength"))
	st.set_flag("strahd_test", "fought")
	assert_true(StrahdPresence.after_dialogue(st, "strahd/visits:test").has("encounter"))
	assert_true(StrahdPresence.after_encounter(st, "defeat").is_empty())


func test_his_fights_find_open_floor_near_the_party() -> void:
	var rows: Array = ["############", "#......#...#", "#......#...#", "#......#...#", "#......#...#", "#......#...#", "############"]
	var taken: Array[Vector2i] = [Vector2i(2, 3), Vector2i(3, 3)]
	var enc := {"id": "t", "monsters": [{"monster": "strahd_von_zarovich"}, {"monster": "dire_wolf"}, {"monster": "dire_wolf"},
		{"monster": "wolf", "cell": [1, 1]}]}
	var out := StrahdPresence.placed(enc, rows, taken, Vector2i(2, 3))
	var mons := out["monsters"] as Array
	assert_eq(mons.size(), 4, "everyone found room")
	assert_eq(str((mons[3] as Dictionary)["cell"]), str([1, 1]), "a cell the data gives is kept")
	var seen := {}
	for m: Variant in mons:
		var md := m as Dictionary
		var size := CombatGrid.size_cells_for(StringName(str(Compendium.shared().monster_data(str(md["monster"])).get("size", "medium"))))
		var a := Vector2i(int((md["cell"] as Array)[0]), int((md["cell"] as Array)[1]))
		for f in CombatGrid.footprint(a, size):
			assert_true(str(rows[f.y])[f.x] == ".", "%s stands on open floor at %s" % [md["monster"], f])
			assert_true(f.x <= 6, "%s is on the party's side of the wall" % md["monster"])
			assert_false(f in taken, "not on the party")
			assert_false(seen.has(f), "nobody overlaps at %s" % f)
			seen[f] = true


# --- What the conversations decide ----------------------------------------------------------------

func test_at_the_night_visit_he_calls_someone_who_isnt_on_watch_to_kneel() -> void:
	var st := _party()
	st.set_flag("strahd_watcher_seen", true)
	st.leader = 0
	_play(st, "strahd/visits:night", ["Wake the others"])
	assert_eq(str(st.get_flag("strahd_knelt", "")), "hedda_ironvow", "Ilse is the one awake, so he calls Hedda")
	var refs := CampTalk.available(st).map(func(t: Dictionary) -> String: return str(t["ref"]))
	assert_true("camp/hedda:talk_knelt" in refs, "Hedda talks about it at the next camp")
	assert_false("camp/ilse:talk_knelt" in refs)
	var other := _party()
	other.set_flag("strahd_watcher_seen", true)
	other.leader = 1
	_play(other, "strahd/visits:night", ["Wake the others"])
	assert_eq(str(other.get_flag("strahd_knelt", "")), "ilse_varga", "with Hedda on watch, he calls Ilse")


func test_every_answer_at_the_burial_but_a_bow_costs_ismark_his_breath() -> void:
	for pick: String in ["under our protection", "Attack him", "Say nothing"]:
		var st := _party()
		_play(st, "village_of_barovia/burial:strahd_arrives", [pick])
		assert_true(bool(st.get_flag("ismark_choked", false)), pick)
	var bowed := _party()
	_play(bowed, "village_of_barovia/burial:strahd_arrives", ["Bow"])
	assert_false(bool(bowed.get_flag("ismark_choked", false)), "a bow spares him")


func test_letting_ireena_go_at_the_inn_gives_her_to_him() -> void:
	var st := _party()
	st.set_flag("ireena_sanctuary", "inn")
	st.set_flag("ismark_guards_ireena", true)
	_play(st, "strahd/ireena:inn", ["Let her go"])
	assert_eq(str(st.get_flag("strahd_window", "")), "taken")
	assert_true(bool(st.get_flag("ireena_held_by_strahd")))
	assert_eq(str(st.get_flag("ireena_sanctuary", "")), "taken", "she is gone from the inn")
	assert_true("ismark" in st.guest_ids, "Ismark wakes and comes with the party to bring her back")


func test_two_missteps_at_the_window_and_she_goes() -> void:
	var st := _party()
	st.set_flag("ireena_in_krezk", true)
	st.set_flag("strahd_window_pull", 2)
	_play(st, "strahd/ireena:pulled")
	assert_true(bool(st.get_flag("ireena_held_by_strahd")))
	assert_false(bool(st.get_flag("ireena_in_krezk")), "she is gone from Krezk")


func test_a_cleric_turns_him_from_the_window_and_ireena_comes_along() -> void:
	var st := _party()
	st.set_flag("ireena_sanctuary", "inn")
	var menu := _play(st, "strahd/ireena:inn", ["call on your god", "Come with us"])
	assert_true(menu.has("Go for him."), "a fight is always a way on")
	assert_false(menu.has("Raise the Holy Symbol of Ravenkind."), "the symbol only if someone carries it")
	assert_eq(str(st.get_flag("strahd_window", "")), "faith")
	assert_false(bool(st.get_flag("ireena_held_by_strahd")))
	assert_true("ireena" in st.guest_ids, "she rejoins the party (vallaki/ireena:rejoin)")
	assert_eq(str(st.get_flag("ireena_sanctuary", "")), "with_party")


func test_the_carriage_takes_the_party_to_the_castle_and_comes_back_if_refused() -> void:
	var st := _party(9)
	st.set_flag("strahd_watcher_seen", true)
	var road := {"location": "svalich_crossroads"}
	var v := StrahdPresence.due(st, "arrive", road)
	assert_eq(str(v.get("id", "")), "invitation")
	StrahdPresence.begin(st, v)
	_play(st, "strahd/letters:invitation", ["Not tonight"])
	assert_eq(str(st.get_flag("strahd_invitation", "")), "declined")
	assert_true(StrahdPresence.after_dialogue(st, "strahd/letters:invitation").is_empty(), "no ride")
	st.day += 1
	assert_true(StrahdPresence.due(st, "arrive", road).is_empty(), "it waits two days")
	st.day += 1
	assert_eq(str(StrahdPresence.due(st, "arrive", road).get("id", "")), "first_letter", "the third day: his first letter")
	v = StrahdPresence.due(st, "arrive", road)
	assert_eq(str(v.get("id", "")), "invitation", "then the carriage again, close behind (urgent)")
	StrahdPresence.begin(st, v)
	_play(st, "strahd/letters:invitation", ["Get in"])
	assert_eq(str(st.get_flag("strahd_invitation", "")), "accepted")
	assert_eq(str(StrahdPresence.after_dialogue(st, "strahd/letters:invitation").get("go", "")), "castle_ravenloft_gates:default")
	st.day += 5
	assert_true(StrahdPresence.due(st, "arrive", road).is_empty(), "accepted: no more carriages")


func test_the_parley_names_his_price_and_offers_ireena_only_when_she_is_there_or_his() -> void:
	var st := _party(10)
	var menu := _play(st, "strahd/final:parley", ["We yield"])
	assert_false(menu.has("Take her, then. Let us go."), "no Ireena to offer")
	assert_eq(str(st.get_flag("strahd_parley", "")), "yield")
	st = _party(10)
	st.add_guest("ireena")
	menu = _play(st, "strahd/final:parley", ["Take her"])
	assert_true(menu.has("Take her, then. Let us go."))
	assert_eq(str(st.get_flag("strahd_parley", "")), "ireena")
	st = _party(10)
	st.set_flag("ireena_held_by_strahd", true)
	menu = _play(st, "strahd/final:parley", ["end you"])
	assert_true(menu.has("Take her, then. Let us go."), "he holds her")
	assert_eq(str(st.get_flag("strahd_parley", "")), "fight")


# --- His fight ends with his withdrawal -------------------------------------------------------------

func test_the_test_of_strength_ends_with_his_withdrawal_and_flag() -> void:
	var then := (StrahdPresence.visit("test_of_strength")["then"] as Array)[0] as Dictionary
	var spec := then["encounter"] as Dictionary
	var rows: Array[String] = []
	for z in 14:
		rows.append("................")
	var e := TestCombat.encounter(rows, 4)
	var taken: Array[Vector2i] = []
	var i := 0
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var cell := Vector2i(2 + i, 7)
		TestCombat.hero(e, id, cell, 7)
		taken.append(cell)
		i += 1
	var placed := StrahdPresence.placed(spec, rows, taken, Vector2i(3, 7))
	var strahd: Combatant = null
	for m: Variant in placed["monsters"]:
		var md := m as Dictionary
		var c := TestCombat.foe(e, str(md["monster"]), Vector2i(int((md["cell"] as Array)[0]), int((md["cell"] as Array)[1])))
		if str(md["monster"]) == "strahd_von_zarovich":
			strahd = c
	assert_true(strahd != null, "Strahd is in his fight")
	if strahd == null:
		return
	e.legendary.set_withdraw(placed["withdraw"])
	var res := PartyAutopilot.new(e).run(12)
	assert_eq(str(e.legendary.departed.get(strahd.id, "")), "withdraw", "he leaves the fight (%s)" % res)
	assert_true(bool(e.legendary.story_flags.get("strahd_withdrew", false)), "and the story learns it")
	assert_true(strahd.creature.hp > 0, "leaving is not dying")
	# He fights his visits until beaten, with no round limit (owner, 2026-10-13; boss-roc 53664fd9d).
	assert_false((placed["withdraw"] as Dictionary).has("after_rounds"), "no round limit: he goes when beaten")


# --- The game's hooks -------------------------------------------------------------------------------

func _start_scene() -> void:
	var c := Compendium.shared()
	for k: String in ["travel", "random_encounters"]:
		_saved[k] = (c.tables.get(k, {}) as Dictionary).duplicate()
	var hall := {"id": "test_hall", "name": "Test Hall", "region": "test", "summary": "",
		"map": {"rows": ["#######", "#.....#", "#......", "#.....#", "#######"], "outdoors": true}, "spawns": {"default": [2, 2]},
		"exits": [{"id": "road", "cell": [6, 2], "to": "travel", "label": "The road"}]}
	c.tables["locations"]["test_hall"] = hall
	var town := hall.duplicate(true)
	town["id"] = "test_town"
	c.tables["locations"]["test_town"] = town
	c.tables["locations"]["test_road_map"] = {"id": "test_road_map", "name": "A Road", "region": "test", "summary": "",
		"map": {"rows": ["############", "#..........#", "#..........#", "#..........#", "#..........#", "############"], "outdoors": true},
		"spawns": {"default": [2, 2]}}
	c.tables["travel"] = {"barovia": {"id": "barovia", "name": "Test", "places": [
		{"id": "hall", "name": "Hall", "location": "test_hall", "pos": [0.2, 0.5], "region": "test"},
		{"id": "mid", "name": "Crossroads", "location": "test_road_map", "pos": [0.5, 0.5], "region": "test"},
		{"id": "town", "name": "Town", "location": "test_town", "pos": [0.8, 0.5], "region": "test"}],
		"roads": [{"id": "r1", "from": "hall", "to": "mid", "hours": 2, "table": "test_quiet_road"},
			{"id": "r2", "from": "mid", "to": "town", "hours": 3}]}}
	c.tables["random_encounters"] = {"test_quiet_road": {"id": "test_quiet_road", "map": "test_road_map", "chance_day": 0.0,
		"chance_night": 0.0, "entries": [{"weight": 1, "monsters": [{"monster": "wolf", "cell": [9, 2]}]}]}}
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_hall"
	GameState.story.visited["test_hall"] = true
	GameState.story.visited["test_road_map"] = true
	GameState.story.minute_of_day = 12 * 60
	Dice.reseed(2)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


## Clicks through the open conversation, taking the first option each time. Returns its first node's file:node.
func _talk_through() -> String:
	var d := root.get("dialogue") as DialogueUI
	if d == null:
		return ""
	var ref := "%s:%s" % [d.runner.file.key, d.runner.node]
	for i in 300:
		if root.get("dialogue") == null:
			break
		if bool(d.get("_waiting_continue")):
			d.call("_advance")
		elif not d.options_shown.is_empty():
			d.call("_choose", 0)
		await get_tree().process_frame
	await _frames(4)
	return ref


func test_the_game_plays_visits_on_the_road_at_a_rest_and_on_arriving() -> void:
	await _start_scene()
	var st := GameState.story
	st.set_flag("burgomaster_buried", true)
	# A journey: the watcher stops it on the road; when he's gone, the journey goes on.
	root.call("travel", "hall", "town")
	await _frames(3)
	assert_eq(_view().loc_id, "test_road_map", "stopped on the road's map")
	assert_eq(await _talk_through(), "strahd/visits:watcher")
	assert_true(bool(st.get_flag("strahd_watcher_seen")))
	await _frames(6)
	assert_eq(_view().loc_id, "test_town", "and on to town")
	assert_true(st.travel_resume.is_empty())
	# A Long Rest through the night, days later: he is there when the one on watch wakes.
	st.day = 4
	st.minute_of_day = 6 * 60
	root.call("open_screen", "rest", 0)
	root.call("strahd_after_rest", 8 * 60)
	await _frames(2)
	assert_true(root.get("screen") is RestScreen, "he waits while the rest screen is open (its night, its words, its spells)")
	assert_true(root.get("dialogue") == null, "no visit yet")
	root.call("close_screen")
	await _frames(3)
	assert_eq(await _talk_through(), "strahd/visits:night")
	assert_eq(str(st.get_flag("strahd_night_visit", "")), "woke")
	# A visit's fight where the party stands, then his parting words.
	StrahdPresence.use({"id": "visits", "summary": "", "visits": [{"id": "pack", "summary": "", "trigger": {"on": ["arrive"]}, "once": true,
		"encounter": {"id": "strahd_test_pack", "monsters": [{"monster": "wolf"}, {"monster": "wolf"}], "after": "strahd/visits:test_after"}},
		{"id": "ride", "summary": "", "trigger": {"on": ["arrive"]}, "once": true, "urgent": true, "dialogue": "strahd/letters:invitation",
		"then": [{"when": "flag.strahd_invitation == \"accepted\"", "go": "test_hall:default"}]}]})
	root.call("enter_location", "test_road_map", "default")
	await _frames(3)
	assert_true(_view().in_combat, "the visit's fight starts on arriving")
	var cv := _view().combat_view
	var foes := 0
	for c in cv.e.combatants:
		if c.side == &"enemy":
			foes += 1
			assert_true(_view().grid.in_bounds(c.cell), "placed on the map")
			cv.e.deal_damage(null, c, [{"amount": 100, "type": "slashing"}], false, "test")
	assert_eq(foes, 2)
	cv.finished.emit("victory")
	await _frames(4)
	assert_eq(await _talk_through(), "strahd/visits:test_after", "his parting words after the fight")
	# An arrival: the carriage (here to the hall), taken by getting in.
	root.call("enter_location", "test_town", "default")
	await _frames(3)
	assert_eq(await _talk_through(), "strahd/letters:invitation")
	assert_eq(str(st.get_flag("strahd_invitation", "")), "accepted")
	assert_eq(_view().loc_id, "test_hall", "the carriage takes the party where the visit says")



## A visit due while the spoils of a fight are still open waits for them to be taken, then plays: the loot window
## never swallows it.
func test_a_visit_waits_for_the_spoils_window() -> void:
	await _start_scene()
	var st := GameState.story
	st.set_flag("burgomaster_buried", true)
	StrahdPresence.use({"id": "visits", "summary": "", "visits": [{"id": "ride", "summary": "", "trigger": {"on": ["arrive"]},
		"once": true, "urgent": true, "dialogue": "strahd/letters:invitation"}]})
	root.call("_open_loot", "fight:test", [{"id": "potion_of_healing", "qty": 1}], 5.0)
	await _frames(2)
	assert_true(root.get("loot") != null, "the spoils are open")
	root.call("enter_location", "test_town", "default")
	await _frames(3)
	assert_true(root.get("dialogue") == null, "he waits while the spoils are open")
	(root.get("loot") as LootWindow).call("_close")
	await _frames(4)
	assert_eq(await _talk_through(), "strahd/letters:invitation", "then he comes")


# --- Ally visits (data/visits/): a friend's letter or road meeting, on the same engine ----------------

func _his(id: String, extra: Dictionary = {}) -> Dictionary:
	var v := {"id": id, "summary": "", "trigger": {"on": ["arrive"]}, "max": 20, "dialogue": "test_allies/letter:letter"}
	v.merge(extra, true)
	return v


func _hers(id: String, extra: Dictionary = {}) -> Dictionary:
	var v := _his(id, extra)
	v["ally"] = true   # the loader's mark (the files don't carry it)
	return v


func _pack(visits: Array, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": "visits", "summary": "", "gap_hours": 12, "visits": visits}
	d.merge(extra, true)
	return d


func _write(path: String, body: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(body if body is String else JSON.stringify(body))
	f.close()


func test_ally_visits_load_from_a_folder_marked_and_in_name_order() -> void:
	DirAccess.make_dir_recursive_absolute(ALLY_DIR)
	_write(ALLY_DIR.path_join("zofia.json"), {"id": "zofia", "summary": "", "visits": [
		{"id": "z1", "summary": "", "trigger": {"on": ["arrive"]}, "once": true}]})
	_write(ALLY_DIR.path_join("anna.json"), {"id": "anna", "summary": "", "visits": [
		{"id": "a1", "summary": "", "trigger": {"on": ["rest"]}, "once": true},
		{"id": "a2", "summary": "", "trigger": {"on": ["travel"]}, "max": 2}]})
	_write(ALLY_DIR.path_join("notes.txt"), "not a visit file")
	var got := StrahdPresence.ally_visits(ALLY_DIR)
	assert_eq(got.map(func(v: Dictionary) -> String: return str(v["id"])), ["a1", "a2", "z1"], "files in name order, a file's visits in order")
	for v in got:
		assert_true(StrahdPresence.is_ally(v), "%s is marked an ally's" % v["id"])
	assert_true(StrahdPresence.ally_visits("user://no_such_visits").is_empty(), "no folder, no visits")
	# The game's own list: his visits first, then every file of data/visits/, and only the latter marked.
	var all := StrahdPresence.data()["visits"] as Array
	assert_eq(str((all[0] as Dictionary)["id"]), "watcher", "his come first")
	var allies := StrahdPresence.ally_visits()
	var his := ((JSON.parse_string(FileAccess.get_file_as_string(StrahdPresence.PATH)) as Dictionary)["visits"] as Array).size()
	assert_eq(all.size(), his + allies.size(), "his file's visits and the ally files' visits, nothing else")
	for v: Variant in all:
		var vis := v as Dictionary
		assert_eq(StrahdPresence.is_ally(vis), allies.any(func(a: Dictionary) -> bool: return a["id"] == vis["id"]),
			"%s: marked an ally's only if it came from data/visits/" % vis["id"])


func test_an_ally_visit_is_not_hidden_by_the_wards_that_hide_the_party_from_strahd() -> void:
	StrahdPresence.use(_pack([_his("his"), _hers("hers")]))
	var st := _party()
	st.active_spells["nondetection"] = {"until": st.total_minutes() + 600}
	assert_true(Wards.hides_from_strahd(st, "vallaki") != "", "Nondetection hides them from him")
	assert_eq(str(StrahdPresence.due(st, "arrive", {"location": "vallaki"}).get("id", "")), "hers", "his can wait; a friend's can't be warded off")
	var open := _party()
	assert_eq(str(StrahdPresence.due(open, "arrive", {"location": "vallaki"}).get("id", "")), "his", "unwarded, file order: his first")


func test_an_ally_visit_waits_the_plain_gap_however_much_he_has_noticed_and_shares_his_last_visit() -> void:
	StrahdPresence.use_attention({"tiers": [{"id": "unnoticed", "min": 0, "gap": 1.0}, {"id": "hunted", "min": 1, "gap": 0.5}],
		"marks": [{"id": "m", "when": "flag.test_mark", "points": 1, "summary": ""}]})
	StrahdPresence.use(_pack([_hers("hers"), _his("his")]))
	var st := _party()
	st.set_flag("test_mark")   # hunted: his visits come after six hours, not twelve
	var town := {"location": "vallaki"}
	assert_eq(str(StrahdPresence.due(st, "arrive", town).get("id", "")), "hers", "the first, in file order")
	st.advance_minutes(7 * 60)
	assert_eq(str(StrahdPresence.due(st, "arrive", town).get("id", "")), "his", "seven hours on, his is allowed (hunted) and hers isn't (twelve)")
	st.advance_minutes(5 * 60)
	assert_true(StrahdPresence.due(st, "arrive", town).is_empty(), "five hours after his: neither (the wait counts from the last visit, whoever's)")
	st.advance_minutes(7 * 60)
	assert_eq(str(StrahdPresence.due(st, "arrive", town).get("id", "")), "hers", "twelve hours after his: a friend again")
	st.advance_minutes(5 * 60)
	assert_true(StrahdPresence.due(st, "arrive", town).is_empty(), "and his waits on hers: no letter and vampire in one breath")


func test_an_urgent_ally_visit_ignores_the_gap_as_his_do() -> void:
	StrahdPresence.use(_pack([_his("his"), _hers("late", {"urgent": true, "trigger": {"on": ["rest"]}})]))
	var st := _party()
	var town := {"location": "vallaki"}
	assert_eq(str(StrahdPresence.due(st, "arrive", town).get("id", "")), "his")
	st.advance_minutes(60)
	assert_eq(str(StrahdPresence.due(st, "rest", town).get("id", "")), "late", "an hour on, urgent")


func test_an_ally_visit_keeps_the_quiet_regions_and_holy_ground() -> void:
	StrahdPresence.use(_pack([_hers("hers"), _hers("at_church", {"trigger": {"on": ["arrive"], "at": ["vallaki_st_andrals"]}})],
		{"quiet_regions": ["krezk"], "quiet_at": ["vallaki_st_andrals"]}))
	var st := _party()
	assert_true(StrahdPresence.due(st, "arrive", {"location": "krezk"}).is_empty(), "a quiet region is quiet for friends too")
	assert_true(StrahdPresence.find(st, "arrive", {"location": "krezk"}).is_empty())
	assert_eq(str(StrahdPresence.due(st, "arrive", {"location": "vallaki_st_andrals"}).get("id", "")), "at_church", "holy ground, unless the visit names it")
	st.advance_minutes(12 * 60)
	assert_eq(str(StrahdPresence.due(st, "arrive", {"location": "vallaki"}).get("id", "")), "hers")


func test_an_ally_visit_plays_its_steps_and_says_so_while_its_conversation_is_open() -> void:
	StrahdPresence.use(_pack([_hers("hers", {"then": [{"when": "flag.test_letter_kept", "go": "vallaki:default"}]}), _his("his", {"trigger": {"on": ["rest"]}})]))
	var st := _party()
	var v := StrahdPresence.due(st, "arrive", {"location": "vallaki"})
	assert_eq(str(v["id"]), "hers")
	assert_eq(StrahdPresence.times(st, "hers"), 1)
	assert_true(StrahdPresence.ally_playing(st, "test_allies/letter:letter").is_empty(), "not before it begins")
	var step := StrahdPresence.begin(st, v)
	assert_eq(str(step["dialogue"]), "test_allies/letter:letter")
	assert_eq(str(StrahdPresence.ally_playing(st, "test_allies/letter:letter")["id"]), "hers", "now it is playing")
	assert_true(StrahdPresence.ally_playing(st, "test_allies/letter:read").is_empty(), "only its own conversation")
	st.set_flag("test_letter_kept")
	assert_eq(str(StrahdPresence.after_dialogue(st, "test_allies/letter:letter").get("go", "")), "vallaki:default", "then what follows")
	assert_true(StrahdPresence.ally_playing(st, "test_allies/letter:letter").is_empty(), "and it is over")
	StrahdPresence.begin(st, StrahdPresence.visit("his"))
	assert_true(StrahdPresence.ally_playing(st, "test_allies/letter:letter").is_empty(), "his visits are never an ally's")


# --- The story bot's answer to an ally visit --------------------------------------------------------

## The menu of `ref` (its lines read through), and the index AllyVisitAnswer picks from it.
func _exit_of(ref: String) -> Dictionary:
	var r := DialogueRunner.new(_party(), DiceRoller.new(5))
	if not r.start(ref):
		fail("no conversation at %s" % ref)
		return {}
	var b := r.next()
	for i in 20:
		if str(b["kind"]) == "options":
			var opts := b["options"] as Array
			var at := AllyVisitAnswer.exit_option(r, opts)
			return {"at": at, "text": str((opts[at] as Dictionary)["text"]) if at >= 0 else ""}
		b = r.next()
	fail("%s never asked" % ref)
	return {}


func test_the_bot_leaves_an_ally_visit_by_the_option_that_ends_it() -> void:
	assert_eq(_exit_of("test_allies/letter:letter")["text"], "Put it away.", "an option that ends outright, though others come first")
	assert_eq(_exit_of("test_allies/letter:ask")["text"], "Goodbye.")


func test_the_bot_takes_the_last_way_out_that_asks_nothing_more_and_never_a_check() -> void:
	assert_eq(_exit_of("test_allies/letter:sealed")["text"], "Keep it.", "burn or keep both end it; a check could fail")
	assert_eq(_exit_of("test_allies/letter:doorstep")["text"], "Shut the door.", "a fight is not a way out; a node that jumps on to the end is")


func test_the_bot_has_no_exit_to_take_from_a_menu_that_only_goes_deeper() -> void:
	assert_eq(_exit_of("test_allies/letter:read")["at"], -1, "'Go on' leads to another menu")
	assert_true(AllyVisitAnswer.leaves("test_allies/letter", "kept"), "a node that sets a flag and ends")
	assert_true(AllyVisitAnswer.leaves("test_allies/letter", "shut"), "a jump to a node that ends")
	assert_false(AllyVisitAnswer.leaves("test_allies/letter", "brawl"), "a fight")
	assert_false(AllyVisitAnswer.leaves("test_allies/letter", "ask"), "a menu")
	assert_false(AllyVisitAnswer.leaves("test_allies/letter", "nowhere"), "a node that isn't there")


# --- The game's hooks play an ally visit ------------------------------------------------------------

func test_the_game_plays_an_ally_visit_and_the_bot_answers_it_by_the_exit_but_not_other_talk() -> void:
	await _start_scene()
	var st := GameState.story
	StrahdPresence.use(_pack([_hers("hers", {"once": true}), _his("his", {"trigger": {"on": ["rest"]}})]))
	root.call("enter_location", "test_town", "default")
	await _frames(3)
	assert_true(root.get("dialogue") != null, "the visit's conversation opens on arriving")
	var bot := StoryBot.new(self, root)
	await bot.settle()
	assert_eq(str(bot.ally_visits), str(["hers"]), "the bot knew it for an ally's")
	assert_true(bot.trace.any(func(t: String) -> bool: return t.ends_with("says: Put it away.")), "and left by the exit: %s" % str(bot.trace))
	assert_false(bot.trace.any(func(t: String) -> bool: return t.ends_with("says: Open it and read it aloud.")), "without reading it")
	assert_true(root.get("dialogue") == null, "the conversation is over")
	assert_true((StrahdPresence.memory(st)["pending"] as Dictionary).is_empty(), "and the visit with it")
	# The same conversation, started by the player walking up to someone, is answered the ordinary way.
	root.call("start_dialogue", "test_allies/letter:letter", "")
	await _frames(2)
	await bot.settle()
	assert_true(bot.trace.any(func(t: String) -> bool: return t.ends_with("says: Open it and read it aloud.")), "an ordinary talk takes the first option not taken yet")
	assert_eq(str(bot.ally_visits), str(["hers"]), "and is no ally visit")

