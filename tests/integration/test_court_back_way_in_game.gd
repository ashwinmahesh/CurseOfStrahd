extends TestCase
## The back way behind the study hearth in the running game (Dungeon Expansion Plan C3, docs/regions/castle_ravenloft_court.md
## §15): the party crawls into the hearth and arrives in the belfry map, the gas leaves it in the guest room four hours
## on, the panel won't budge until the torch is in the sconce, the belfry's fight starts from its rope, and Strahd's
## tower stands in the treasury over wall squares. The data and conversations are test_court_back_way.

const WAY := "castle_ravenloft_court_belfry"
const COURT := "castle_ravenloft_court"
const TREASURY := "castle_ravenloft_court_treasury"
const WEEPING := "castle_ravenloft_court_weeping"

var root: Node


func _boot(location: String, flags: Array[String] = []) -> void:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 10)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	for f in flags:
		GameState.story.set_flag(f)
	GameState.story.location = location
	GameState.story.minute_of_day = 12 * 60
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await _frames(1)
	UiMotion._checked = true
	UiMotion.reduced = true


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


## Reads the conversation to its end and lets the move or fight that follows it come up.
func _finish() -> void:
	for i in 12:
		var d := root.get("dialogue") as DialogueUI
		if d == null:
			break
		d.call("_advance")
		await _frames(2)
	for i in 120:
		if not bool(root.get("moving")):
			break
		await _frames(1)
	await _frames(3)


func test_the_party_crawls_through_the_cold_hearth_into_the_back_way() -> void:
	await _boot(COURT, ["court_hearth_found", "court_hearth_out"])
	root.call("start_dialogue", "castle_ravenloft/court_way:crawl", "")
	await _frames(2)
	await _finish()
	var v := _view()
	assert_eq(v.loc_id, WAY, "the party is in the back way")
	assert_eq(GameState.story.location, WAY)
	assert_eq(v.leader().cell, Vector2i(2, 15), "at the foot of the flue")
	for m in v.members:
		assert_true(v.grid.in_bounds(m.cell) and not v.grid.is_solid(m.cell), "%s stands on open floor" % m.cell)
	assert_true(v.prop_nodes.has("court_way_skeleton") and v.prop_nodes.has("court_way_rope"), "its things are on the board")
	assert_eq(ModeController.mode, ModeController.Mode.EXPLORATION)


func test_the_gas_leaves_the_party_in_the_guest_room_four_hours_on() -> void:
	await _boot(WAY)
	var before := GameState.story.total_minutes()
	root.call("start_dialogue", "castle_ravenloft/court_way:gassed", "")
	await _frames(2)
	await _finish()
	var v := _view()
	assert_eq(v.loc_id, WEEPING)
	assert_eq(GameState.story.total_minutes() - before, 240)
	var area_cells := [Vector2i(16, 13), Vector2i(23, 21)]
	for m in v.members:
		assert_true(m.cell.x >= area_cells[0].x and m.cell.x <= area_cells[1].x and m.cell.y >= area_cells[0].y and m.cell.y <= area_cells[1].y,
			"%s wakes in the guest room" % m.cell)


func test_the_panel_will_not_budge_until_the_torch_is_in_the_sconce() -> void:
	await _boot(WAY)
	var v := _view()
	var panel: Dictionary = {}
	for d: Variant in v.loc["doors"]:
		if str((d as Dictionary)["id"]) == "court_way_panel":
			panel = d as Dictionary
	assert_true(v.door_nodes.has("court_way_panel"), "the panel is drawn as a door")
	var cell := LocationView._cell(panel["cell"])
	assert_true(v.grid.has_flag(cell, CombatGrid.WALL), "shut")
	LocationLocks._use_door(v, panel)
	assert_true(v.grid.has_flag(cell, CombatGrid.WALL), "still shut: it won't budge")
	GameState.story.set_flag("court_way_sconce_set")
	LocationLocks._use_door(v, panel)
	assert_false(v.grid.has_flag(cell, CombatGrid.WALL), "and open once the torch is set")


func test_the_hall_of_webs_slows_the_party_off_the_path() -> void:
	await _boot(WAY)
	var v := _view()
	assert_true(v.grid.has_flag(Vector2i(28, 13), CombatGrid.DIFFICULT), "webs are difficult ground")
	assert_false(v.grid.has_flag(Vector2i(28, 14), CombatGrid.DIFFICULT), "the cut path is clear")
	assert_false(v.grid.has_flag(Vector2i(28, 14), CombatGrid.WALL))


func test_pulling_the_rope_starts_the_spiders_fight_in_the_belfry() -> void:
	await _boot(WAY, ["court_way_bell_rung"])
	var v := _view()
	for i in 4:
		v.members[i].cell = [Vector2i(42, 14), Vector2i(41, 14), Vector2i(43, 14), Vector2i(42, 15)][i]
	root.call("start_dialogue", "castle_ravenloft/court_way:pull", "")
	await _frames(2)
	await _finish()
	await _frames(6)
	assert_true(_view().in_combat, "the spiders came")


func test_strahds_tower_stands_over_wall_squares_in_the_treasury() -> void:
	await _boot(TREASURY)
	var v := _view()
	assert_true(v.exit_nodes.has(FortressSite.ENTRY), "the tower is built, and clickable through its door")
	var tower := v.exit_nodes[FortressSite.ENTRY] as Node3D
	assert_eq(str(tower.name), "Fortress")
	for c in FortressSite.footprint(Vector2i(12, 0)):
		assert_true(v.grid.has_flag(c, CombatGrid.WALL), "%s is wall to walking and sight" % c)
	assert_false(v.grid.has_flag(Vector2i(13, 4), CombatGrid.WALL), "the square before the door is open")
	assert_false(v.grid.has_flag(Vector2i(7, 8), CombatGrid.WALL), "the hoard's square is open as it was")
	assert_true(v.container_nodes.has("court_treasury_hoard"), "the Tarokka hoard is there to open")
	assert_eq(v.leader().cell, Vector2i(8, 2), "the party arrives at the foot of the old stair")
