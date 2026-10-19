extends TestCase
## Travel (ADR 0010): the quickest known road, time passing, a random fight on the road's map that ends with the
## journey going on, a quiet road, places appearing on the map once known, and day and night outdoors.

var root: Node
var _saved := {}


func before_each() -> void:
	var c := Compendium.shared()
	_saved = {"travel": (c.tables.get("travel", {}) as Dictionary).duplicate(), "random_encounters": (c.tables.get("random_encounters", {}) as Dictionary).duplicate()}
	var hall := {"id": "test_hall", "name": "Test Hall", "region": "test", "summary": "",
		"map": {"rows": ["#######", "#.....#", "#......", "#.....#", "#######"], "outdoors": true}, "spawns": {"default": [2, 2]},
		"exits": [{"id": "road", "cell": [6, 2], "to": "travel", "label": "The road"}]}
	c.tables["locations"]["test_hall"] = hall
	var town := hall.duplicate(true)
	town["id"] = "test_town"
	town["name"] = "Test Town"
	c.tables["locations"]["test_town"] = town
	var ambush := {"id": "test_ambush", "name": "A Road", "region": "test", "summary": "",
		"map": {"rows": ["##########", "#........#", "#........#", "#........#", "##########"], "outdoors": true}, "spawns": {"default": [2, 2]}}
	c.tables["locations"]["test_ambush"] = ambush
	c.tables["travel"] = {"barovia": {"id": "barovia", "name": "Test", "places": [
		{"id": "hall", "name": "Hall", "location": "test_hall", "pos": [0.2, 0.5], "region": "test"},
		{"id": "mid", "name": "Crossroads", "location": "test_ambush", "pos": [0.5, 0.5], "region": "test"},
		{"id": "town", "name": "Town", "location": "test_town", "pos": [0.8, 0.5], "region": "test", "when": "flag.heard_of_town"},
		{"id": "far", "name": "Far", "location": "test_town", "pos": [0.8, 0.9], "region": "test", "when": "false"}],
		"roads": [{"id": "r1", "from": "hall", "to": "mid", "hours": 2, "table": "test_road"},
			{"id": "r2", "from": "mid", "to": "town", "hours": 3},
			{"id": "r3", "from": "hall", "to": "town", "hours": 9}]}}
	c.tables["random_encounters"] = {"test_road": {"id": "test_road", "map": "test_ambush", "chance_day": 1.0, "chance_night": 1.0,
		"entries": [{"weight": 1, "monsters": [{"monster": "wolf", "cell": [7, 2]}], "text": "Wolves."}]}}
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_hall"
	GameState.story.visited["test_hall"] = true
	Dice.reseed(2)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


func after_each() -> void:
	var c := Compendium.shared()
	c.tables["travel"] = _saved["travel"]
	c.tables["random_encounters"] = _saved["random_encounters"]
	for id: String in ["test_hall", "test_town", "test_ambush", "test_glade"]:
		c.tables["locations"].erase(id)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func test_routes_follow_known_roads_and_places_appear_when_known() -> void:
	var st := GameState.story
	var known: Array = Travel.known(st).map(func(p: Dictionary) -> String: return str(p["id"]))
	assert_eq(known, ["hall", "mid"], "where we've been, and places everyone knows (no condition)")
	st.set_flag("heard_of_town", true)
	known = Travel.known(st).map(func(p: Dictionary) -> String: return str(p["id"]))
	assert_eq(known, ["hall", "mid", "town"])
	var legs := Travel.route("hall", "town", st)
	assert_eq(legs.size(), 2, "two roads (5 hours) beat the long one (9)")
	assert_eq(Travel.hours(legs), 5.0)


func test_a_fight_on_the_road_then_the_journey_goes_on() -> void:
	var st := GameState.story
	st.visited["test_ambush"] = true
	st.set_flag("heard_of_town", true)
	var start := st.total_minutes()
	_view().walk_to(Vector2i(6, 2))
	for i in 200:
		if root.get("screen") is TravelScreen:
			break
		await get_tree().process_frame
	var map := root.get("screen") as TravelScreen
	assert_true(map != null, "the road out of town opens the map")
	map.select("town")
	map.travel_chosen.emit("town")
	map.queue_free()
	await _frames(5)
	assert_eq(_view().loc_id, "test_ambush", "stopped on the road")
	assert_true(_view().in_combat, "wolves")
	assert_eq(st.total_minutes() - start, 120, "two hours on the first road")
	var cv := _view().combat_view
	for c in cv.e.combatants:
		if c.side == &"enemy":
			cv.e.deal_damage(null, c, [{"amount": 100, "type": "slashing"}], false, "test")
	cv.finished.emit("victory")
	await _frames(6)
	# Every random encounter pays (RoadSpoils): the road waits while the spoils are taken.
	assert_true(await _take_spoils(), "the wolves' spoils: coins and a find")
	await _frames(6)
	assert_eq(_view().loc_id, "test_town", "and on to town")
	assert_eq(st.total_minutes() - start, 120 + 1 + 180, "the fight's minute and the second road")
	assert_true(st.travel_resume.is_empty())
	assert_true(RoadFamiliarity.walked(st, "r1") and RoadFamiliarity.walked(st, "r2"), "both roads are walked now: familiar ground")


## A fight on the road, saved at its round start and loaded again (Continue after quitting mid-fight), comes back (QA
## FN-13: the fight was only in that visit's copy of the place, so the load found nothing and the party stood on the
## road with no fight and its journey stalled); won, the journey goes on.
func test_a_road_fight_comes_back_after_a_load() -> void:
	var st := GameState.story
	st.visited["test_ambush"] = true
	st.set_flag("heard_of_town", true)
	_view().walk_to(Vector2i(6, 2))
	for i in 200:
		if root.get("screen") is TravelScreen:
			break
		await get_tree().process_frame
	var map := root.get("screen") as TravelScreen
	map.travel_chosen.emit("town")
	map.queue_free()
	await _frames(5)
	assert_true(_view().in_combat, "wolves on the road")
	for i in 60:
		if not GameState.combat_snapshot.is_empty():
			break
		await get_tree().process_frame
	assert_eq(SaveSystem.save_round(), OK)
	root.queue_free()
	await _frames(2)
	GameState.reset()
	assert_eq(SaveSystem.load_slot(SaveSystem.ROUND_START), OK)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(8)
	assert_eq(_view().loc_id, "test_ambush")
	assert_true(_view().in_combat, "the road fight is back after the load")
	var cv := _view().combat_view
	for c in cv.e.combatants:
		if c.side == &"enemy":
			cv.e.deal_damage(null, c, [{"amount": 100, "type": "slashing"}], false, "test")
	cv.finished.emit("victory")
	await _frames(6)
	assert_true(await _take_spoils(), "the road fight's reward came back with it")
	await _frames(6)
	assert_eq(_view().loc_id, "test_town", "won, and on to town")
	assert_true((GameState.story.loc_state("test_ambush").get("custom_fights", {}) as Dictionary).is_empty(), "nothing left waiting")
	SaveSystem.delete_slot(SaveSystem.ROUND_START)


## A road's fights take turns on its battle grounds (RoadGrounds, Ashwin 2026-10-12): two fights on the same road
## play out on two different maps, and on a ground that isn't the table's own map the foes start on its foe spots.
func test_road_fights_take_turns_on_the_road_s_battle_grounds() -> void:
	var c := Compendium.shared()
	var spots: Array[Vector2i] = [Vector2i(7, 1), Vector2i(7, 3), Vector2i(8, 2)]
	c.tables["locations"]["test_glade"] = {"id": "test_glade", "name": "A Glade", "region": "test", "summary": "",
		"map": {"rows": ["##########", "#........#", "#........#", "#........#", "##########"], "outdoors": true},
		"spawns": {"default": [2, 2]}, "foe_spots": [[7, 1], [7, 3], [8, 2]]}
	(c.tables["random_encounters"]["test_road"] as Dictionary)["grounds"] = ["test_ambush", "test_glade"]
	var grounds: Array[String] = []
	for leg: Array in [["hall", "mid"], ["mid", "hall"]]:
		root.call("travel", str(leg[0]), str(leg[1]))
		await _frames(5)
		assert_true(_view().in_combat, "wolves on the road from %s" % leg[0])
		grounds.append(_view().loc_id)
		var cv := _view().combat_view
		for cb in cv.e.combatants:
			if cb.side == &"enemy":
				if _view().loc_id == "test_glade":
					assert_true(cb.cell in spots, "the wolf starts on a foe spot of the glade (%s)" % cb.cell)
				else:
					assert_eq(cb.cell, Vector2i(7, 2), "on the table's own map the wolf stands where written")
				cv.e.deal_damage(null, cb, [{"amount": 100, "type": "slashing"}], false, "test")
		cv.finished.emit("victory")
		await _frames(6)
		var lw := root.get("loot") as LootWindow
		if lw != null:
			lw.call("_take_all")
			if root.get("loot") != null:
				lw.call("_close")
		await _frames(8)
	assert_true(grounds.has("test_ambush") and grounds.has("test_glade"), "one fight on each ground, not the same twice: %s" % [grounds])


## A meeting on the road pays too (RoadSpoils): its reward opens when the conversation ends, and the journey waits.
func test_a_meeting_on_the_road_leaves_a_reward_then_the_journey_goes_on() -> void:
	DialogueFile.register(DialogueFile.parse("~ meet\nNarrator: A pedlar tips his hat and goes by.\n-> END\n", "test/road"))
	Compendium.shared().tables["random_encounters"]["test_road"]["entries"] = [{"id": "pedlar", "weight": 1, "dialogue": "test/road:meet"}]
	var st := GameState.story
	st.set_flag("heard_of_town", true)
	var gold_before := st.gold
	_view().walk_to(Vector2i(6, 2))
	for i in 200:
		if root.get("screen") is TravelScreen:
			break
		await get_tree().process_frame
	var map := root.get("screen") as TravelScreen
	map.select("town")
	map.travel_chosen.emit("town")
	map.queue_free()
	await _frames(5)
	var d := root.get("dialogue") as DialogueUI
	assert_true(d != null, "the pedlar on the road")
	for i in 20:
		if root.get("dialogue") == null:
			break
		d.call("_advance")
		await _frames(1)
	await _frames(4)
	assert_true(await _take_spoils(), "the meeting leaves coins and a find")
	await _frames(6)
	assert_true(st.gold > gold_before, "the coins are in the purse")
	assert_eq(_view().loc_id, "test_town", "and on to town")


## A journey is armed (StoryState.travel_resume) the moment a road's fight or meeting is rolled, but the party only
## stands on that road once the change of place behind its cover has run. The hours of the leg trigger an autosave in
## between, which wrote the party still at the start with the journey armed: "Last Autosave" after a lost road fight
## loaded it, and the next fight the party won anywhere (the fire elemental in Ghakis's lair, Ashwin 2026-10-18) sent it
## on to the journey's end, straight after Take All. No autosave holds a journey away from its road.
func test_no_autosave_holds_a_journey_away_from_its_road() -> void:
	UiMotion._checked = true
	UiMotion.reduced = false   # the change of place waits behind its cover, as in the game: that is when the save fell
	for n in range(1, SaveSystem.AUTOSAVES + 1):
		SaveSystem.delete_slot(SaveSystem.autosave_slot(n))
	root.set("autosaves", true)
	root.call("travel", "hall", "mid")
	for i in 600:
		await get_tree().process_frame
		if not bool(root.get("moving")) and _view().loc_id == "test_ambush":
			break
	await _frames(3)
	assert_eq(_view().loc_id, "test_ambush", "stopped on the road")
	assert_false(GameState.story.travel_resume.is_empty(), "with the journey waiting")
	for n in range(1, SaveSystem.AUTOSAVES + 1):
		var slot := SaveSystem.autosave_slot(n)
		if not SaveSystem.has_slot(slot):
			continue
		var d := JSON.parse_string(FileAccess.get_file_as_string(SaveSystem.slot_path(slot))) as Dictionary
		var story := d["story"] as Dictionary
		var resume := story.get("travel_resume", {}) as Dictionary
		assert_true(resume.is_empty() or Travel.is_road_scene(str(story["location"])),
			"%s: at %s with the journey %s" % [slot, story["location"], resume])
	root.set("autosaves", false)
	for n in range(1, SaveSystem.AUTOSAVES + 1):
		SaveSystem.delete_slot(SaveSystem.autosave_slot(n))
	UiMotion.reduced = true


## A journey left over in a save made before that was fixed (or by any path that leaves the road) must not follow the
## party into a fight that has nothing to do with it: the record is dropped, the spoils are taken and the party stays.
func test_a_stale_journey_does_not_follow_a_fight_away_from_the_road() -> void:
	var st := GameState.story
	st.travel_resume = {"to": "town", "at": "town"}
	var foes: Array = [{"monster": "wolf", "cell": [4, 2]}]
	_view().start_custom_encounter({"id": "stale_wolves", "monsters": foes, "loot": RoadSpoils.for_fight(st, foes, "stale")})
	await _frames(5)
	var cv := _view().combat_view
	assert_true(_view().in_combat, "wolves in the hall")
	for c in cv.e.combatants:
		if c.side == &"enemy":
			cv.e.deal_damage(null, c, [{"amount": 100, "type": "slashing"}], false, "test")
	cv.finished.emit("victory")
	await _frames(6)
	var lw := root.get("loot") as LootWindow
	assert_true(lw != null, "the wolves' spoils")
	if lw != null:
		lw.call("_take_all")
		if root.get("loot") != null:
			lw.call("_close")
	await _frames(10)
	assert_eq(_view().loc_id, "test_hall", "Take All leaves the party where it fought")
	assert_true(st.travel_resume.is_empty(), "and the stale journey is gone")


## A journey ends where the party leaves its road for a place of its own (a conversation's `move`, a stale record
## loaded with a save); on the road's own map it waits.
func test_a_journey_waits_on_its_road_and_ends_anywhere_else() -> void:
	var st := GameState.story
	st.travel_resume = {"to": "town", "at": "town"}
	root.call("enter_location", "test_ambush", "default")
	await _frames(2)
	assert_false(st.travel_resume.is_empty(), "on the road's own map the journey waits")
	root.call("enter_location", "test_town", "default")
	await _frames(2)
	assert_true(st.travel_resume.is_empty(), "anywhere else it is over")


func test_which_maps_are_road_scenes() -> void:
	var c := Compendium.shared()
	assert_true(Travel.is_road_scene("test_ambush"), "a table's own map")
	assert_false(Travel.is_road_scene("test_hall"), "a town")
	assert_false(Travel.is_road_scene(""), "nowhere")
	(c.tables["random_encounters"]["test_road"] as Dictionary)["grounds"] = ["test_ambush", "test_glade"]
	assert_true(Travel.is_road_scene("test_glade"), "one of its battle grounds")
	(c.tables["travel"]["barovia"]["roads"][0] as Dictionary)["grounds"] = ["test_hall"]
	assert_true(Travel.is_road_scene("test_hall"), "a road's own battle ground")


## The loot window that's open now: checks it holds coins and a find, that the party is still on the road while it's
## open, then takes everything. False if there was none.
func _take_spoils() -> bool:
	var lw := root.get("loot") as LootWindow
	if lw == null:
		return false
	var ok := lw.gold > 0.0 and not lw.items.is_empty()
	await _frames(4)
	assert_eq(_view().loc_id, "test_ambush", "still on the road while the spoils are open")
	lw.call("_take_all")
	if root.get("loot") != null:
		lw.call("_close")
	return ok


func test_day_and_night_outdoors() -> void:
	var st := GameState.story
	st.minute_of_day = 12 * 60
	_view().update_daylight()
	assert_eq(_view().time_phase(), "day")
	assert_false(_view().lantern.visible, "no lantern by day")
	st.minute_of_day = 23 * 60
	_view().update_daylight()
	assert_eq(_view().time_phase(), "night")
	assert_true(_view().lantern.visible)
	assert_true(StoryConditions.check("night and hour >= 23", st))
	assert_false(StoryConditions.check("day", st))
