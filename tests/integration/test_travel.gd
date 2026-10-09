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
	for id: String in ["test_hall", "test_town", "test_ambush"]:
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
	assert_eq(_view().loc_id, "test_town", "and on to town")
	assert_eq(st.total_minutes() - start, 120 + 1 + 180, "the fight's minute and the second road")
	assert_true(st.travel_resume.is_empty())


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
	assert_eq(_view().loc_id, "test_town", "won, and on to town")
	assert_true((GameState.story.loc_state("test_ambush").get("custom_fights", {}) as Dictionary).is_empty(), "nothing left waiting")
	SaveSystem.delete_slot(SaveSystem.ROUND_START)


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
