extends TestCase
## People walking routes (NpcRoutes, owner 2026-10-07: "NPCs should move around the map"): a `path` entry walks from
## its cell through its waypoints and back, its square (hover, clicks, the low block) going with it; it holds while a
## conversation runs, while the leader stands beside it and under turn-based exploring until a round ends; a sleeper
## and a person with no path stay where they are.

const LOC := {
	"id": "test_lane", "name": "Test Lane", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"##############",
		"#............#",
		"#............#",
		"#............#",
		"#............#",
		"##############"], "light": "dim"},
	"spawns": {"default": [1, 4]},
	"npcs": [
		{"npc": "ismark", "cell": [3, 1], "dialogue": "test/lane:start", "path": [[10, 1]], "pause": 0.2},
		{"npc": "ireena", "cell": [6, 3], "dialogue": "test/lane:start", "facing": "west"},
		{"npc": "donavich", "cell": [3, 3], "dialogue": "test/lane:start", "path": [[8, 3]], "asleep": true}]
}

const DIALOGUE := """
~ start
Ismark: Walk with me a moment.
-> END
"""

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_lane"] = LOC.duplicate(true)
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/lane"))
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_lane"
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	var hud := root.get("hud") as ExploreHud
	hud.close_narration()


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	Compendium.shared().tables["locations"].erase("test_lane")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func _cell_of(npc_id: String) -> Vector2i:
	for shown in _view()._npc_shown:
		if str((shown["spec"] as Dictionary)["npc"]) == npc_id:
			return shown["cell"] as Vector2i
	return Vector2i(-1, -1)


## Runs the routes for `seconds` of game time, a frame at a time.
func _run(seconds: float) -> void:
	var routes := NpcRoutes.of(_view())
	var t := 0.0
	while t < seconds:
		routes._process(0.1)
		t += 0.1
	await _frames(1)


func test_a_walker_follows_its_route_and_its_square_goes_with_it() -> void:
	var v := _view()
	var at := _cell_of("ismark")
	assert_true(at.y == 1 and at.x <= 4, "he starts at his cell (at %s)" % at)
	await _run(1.0)
	var moved := _cell_of("ismark")
	assert_true(moved.x > at.x, "he set off along his path (from %s to %s)" % [at, moved])
	assert_eq(str(v.thing_at(moved).get("id", "")), "ismark", "hover and clicks find him where he is now")
	assert_true(v.thing_at(at).is_empty(), "nobody is left behind where he was")
	assert_true(v.grid.has_flag(moved, CombatGrid.LOW), "his square is taken")
	assert_false(v.grid.has_flag(at, CombatGrid.LOW), "the square he left is free again")
	var seen := {}
	var back := false
	for i in 60:
		await _run(0.35)
		seen[_cell_of("ismark")] = true
		back = back or (seen.has(Vector2i(10, 1)) and _cell_of("ismark") == Vector2i(3, 1))
	assert_true(seen.has(Vector2i(10, 1)), "he walks to his waypoint (saw %s)" % [seen.keys()])
	assert_true(back, "and back to where he started")
	assert_eq(_cell_of("ireena"), Vector2i(6, 3), "someone with no path stays put")
	assert_eq(_cell_of("donavich"), Vector2i(3, 3), "a sleeper never walks")


func test_talking_holds_everyone_still() -> void:
	root.call("start_dialogue", "test/lane:start", "ismark")
	await _frames(2)
	var at := _cell_of("ismark")
	await _run(3.0)
	assert_eq(_cell_of("ismark"), at, "nobody walks off mid-conversation")


func test_he_stops_beside_the_leader() -> void:
	var v := _view()
	var at := _cell_of("ismark")
	v.leader().cell = at + Vector2i(0, 1)
	await _run(3.0)
	assert_eq(_cell_of("ismark"), at, "someone comes up to him, so he waits")


func test_turn_based_exploring_moves_him_only_as_a_round_ends() -> void:
	var v := _view()
	LocationPlan.start(v)   # not toggle(): that keeps the choice in the player's settings
	var at := _cell_of("ismark")
	await _run(6.0)
	var first := _cell_of("ismark")
	assert_eq(first.x - at.x, NpcRoutes.ROUND_SQUARES, "his Speed's worth of squares in the round (from %s to %s)" % [at, first])
	await _run(4.0)
	assert_eq(_cell_of("ismark"), first, "then he waits for the round to end")
	v.next_round()
	await _run(2.0)
	assert_ne(_cell_of("ismark"), first, "a new round, a few more steps")
	LocationPlan.stop(v)


## The loading lane: a route's legs are searched with a budget that grows until it reaches the leg's end, not over the
## whole map; in the two busiest towns every leg comes out square for square the path the whole-map search gives.
func test_budgeted_legs_match_the_whole_map_search() -> void:
	var no := func(_c: Vector2i) -> bool: return false
	var legs := 0
	for id: String in ["vallaki", "village_of_barovia"]:
		root.queue_free()
		await _frames(1)
		GameState.story.location = id
		root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
		add_child(root)
		await _frames(2)
		var v := _view()
		for n: Variant in v.loc.get("npcs", []):
			var spec := n as Dictionary
			if not spec.has("path"):
				continue
			var from := LocationView._cell(spec["cell"])
			var stops: Array = (spec["path"] as Array) + [[from.x, from.y]]
			for s: Variant in stops:
				var to := NpcRoutes._stop(s, spec)["cell"] as Vector2i
				var whole := CombatGrid.path_to(v.grid.reachable(from, 1, NpcRoutes.LEG_FEET, no, no, no), to)
				assert_eq(NpcRoutes.leg_path(v.grid, from, to), whole, "%s in %s, %s to %s" % [spec["npc"], id, from, to])
				legs += 1
				from = to
	assert_true(legs >= 10, "enough legs compared (%d)" % legs)


func test_every_authored_route_can_be_walked() -> void:
	var with_paths: Array[String] = []
	for id: String in Compendium.shared().table("locations"):
		for n: Variant in Compendium.shared().get_entry("locations", id).get("npcs", []):
			if (n as Dictionary).has("path") and not id in with_paths:
				with_paths.append(id)
	assert_true(with_paths.size() >= 5, "the towns have people walking (%s)" % [with_paths])
	for id in with_paths:
		root.queue_free()
		await _frames(1)
		GameState.story.location = id
		root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
		add_child(root)
		await _frames(2)
		var v := _view()
		for n: Variant in v.loc.get("npcs", []):
			var spec := n as Dictionary
			if not spec.has("path") or bool(spec.get("asleep", false)):
				continue
			var own := LocationView._cell(spec["cell"])
			var low := v.grid.has_flag(own, CombatGrid.LOW)
			v.grid.set_flag(own, CombatGrid.LOW, false)
			var route := NpcRoutes.route_for(v, spec)
			v.grid.set_flag(own, CombatGrid.LOW, low)
			assert_false(route.is_empty(), "%s in %s can walk every leg of its path" % [spec["npc"], id])


## Lane 25's sight cones read each figure's facing: a person stands facing their entry's `facing`, and a walker turns
## to the way it walks.
func test_people_face_their_way_and_walkers_turn_as_they_go() -> void:
	var v := _view()
	var ireena := v.npc_tokens["ireena"] as CombatToken
	assert_true(ireena.sprite.facing.distance_to(Vector3(-1, 0, 0)) < 0.01, "she faces west (%s)" % ireena.sprite.facing)
	var ismark := v.npc_tokens["ismark"] as CombatToken
	await _run(2.0)
	assert_true(ismark.sprite.facing.x > 0.7, "walking east, he faces east (%s)" % ismark.sprite.facing)
