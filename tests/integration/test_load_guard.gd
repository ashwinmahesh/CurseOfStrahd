extends TestCase
## The load guard (Dungeon Expansion Plan E1, LocationParty._place_party): a save made before a map was edited can name a
## square that is a wall now. The party goes to the nearest open square (or round the default spawn when none is in
## reach) instead of standing in the stone, and a round-start save whose fight no longer fits the map begins again from the
## fight's own squares instead of resuming on the old layout.

const OPEN_ROWS := [
	"###########",
	"#.........#",
	"#.........#",
	"#.........#",
	"###########"]

## The same hall after an edit: the square the party saved on, (7, 2), is now a pillar.
const EDITED_ROWS := [
	"###########",
	"#.........#",
	"#......#..#",
	"#.........#",
	"###########"]

## A long hall whose far end is solid for ten squares round the saved square.
const LONG_ROWS := [
	"####################",
	"#........###########",
	"#........###########",
	"#........###########",
	"####################"]

var root: Node
var _fights: Array = []


func _loc(rows: Array, with_fight: bool = false) -> Dictionary:
	var d := {
		"id": "test_guard_hall", "name": "Test Guard Hall", "region": "test", "summary": "A fixture.",
		"map": {"rows": rows, "light": "dim"},
		"spawns": {"default": [1, 1]},
	}
	if with_fight:
		d["encounters"] = [{"id": "guard_wolves", "trigger": "flag:never", "monsters": [{"monster": "wolf", "cell": [9, 1]}]}]
	return d


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	Dice.reseed(4)


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await _frames(1)
	(Compendium.shared().tables["locations"] as Dictionary).erase("test_guard_hall")
	SaveSystem.delete_slot("round_start")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The game loaded into the hall with the party's squares already saved, as a load leaves them.
func _load_into(rows: Array, saved: Array[Vector2i], with_fight: bool = false) -> void:
	Compendium.shared().tables["locations"]["test_guard_hall"] = _loc(rows, with_fight)
	GameState.story.location = "test_guard_hall"
	GameState.story.positions = saved.duplicate()
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(4)


func _view() -> LocationView:
	return root.get("view") as LocationView


func _open(v: LocationView, c: Vector2i) -> bool:
	return v.grid.in_bounds(c) and not v.grid.is_solid(c)


func test_open_squares_stay_where_they_were_saved() -> void:
	await _load_into(OPEN_ROWS, [Vector2i(7, 2), Vector2i(6, 2)])
	var v := _view()
	assert_eq(v.members[0].cell, Vector2i(7, 2), "the leader stands where they saved")
	assert_eq(v.members[1].cell, Vector2i(6, 2))


func test_a_saved_square_that_is_a_wall_now_puts_them_on_the_nearest_open_one() -> void:
	await _load_into(EDITED_ROWS, [Vector2i(7, 2), Vector2i(6, 2)])
	var v := _view()
	var leader := v.members[0].cell
	assert_ne(leader, Vector2i(7, 2), "not in the pillar")
	assert_true(_open(v, leader), "on open floor")
	assert_eq(maxi(absi(leader.x - 7), absi(leader.y - 2)), 1, "the square beside it")
	assert_eq(v.members[1].cell, Vector2i(6, 2), "the one whose square is still open stays")
	assert_ne(leader, v.members[1].cell, "and the leader doesn't land on them")
	for i in v.members.size():
		assert_eq(GameState.story.positions[i], v.members[i].cell, "what's saved next is where they stand")


func test_two_in_the_wall_do_not_share_a_square() -> void:
	await _load_into(EDITED_ROWS, [Vector2i(7, 2), Vector2i(7, 2)])
	var v := _view()
	assert_true(_open(v, v.members[0].cell) and _open(v, v.members[1].cell))
	assert_ne(v.members[0].cell, v.members[1].cell, "each found their own square")


func test_with_no_open_square_in_reach_they_stand_at_the_default_spawn() -> void:
	# Saved at the far end, (18, 2), which is stone for ten squares round now.
	await _load_into(LONG_ROWS, [Vector2i(18, 2), Vector2i(17, 2)])
	var v := _view()
	assert_eq(v.members[0].cell, Vector2i(1, 1), "the default spawn")
	assert_true(_open(v, v.members[1].cell), "and the other one beside them")
	assert_ne(v.members[1].cell, v.members[0].cell)


func test_a_square_outside_a_smaller_map_counts_as_closed() -> void:
	await _load_into(OPEN_ROWS, [Vector2i(40, 40), Vector2i(41, 40)])
	var v := _view()
	assert_eq(v.members[0].cell, Vector2i(1, 1), "back at the default spawn")
	assert_true(_open(v, v.members[1].cell))


## Only a load goes by the saved squares: arriving through a spawn, in this map too, stands the party at the spawn.
func test_arriving_by_a_spawn_ignores_saved_squares() -> void:
	await _load_into(OPEN_ROWS, [])
	GameState.story.positions = [Vector2i(7, 2), Vector2i(6, 2)]
	root.call("enter_location", "test_guard_hall", "default")
	await _frames(3)
	assert_eq(_view().members[0].cell, Vector2i(1, 1), "the spawn, as always")


# --- A round-start save in a map that has changed ---------------------------------------------------------------------

## A fight begun in the hall, saved as its first round began; the snapshot's round is made 3 so a resume shows itself.
func _saved_fight() -> Dictionary:
	await _load_into(OPEN_ROWS, [Vector2i(7, 2), Vector2i(6, 2)], true)
	_view().start_encounter("guard_wolves")
	for i in 30:
		await get_tree().process_frame
		if not GameState.combat_snapshot.is_empty():
			break
	var snap := GameState.combat_snapshot.duplicate(true)
	(snap["data"] as Dictionary)["round"] = 3
	root.queue_free()
	await _frames(2)
	return snap


func _party_cell(snap: Dictionary) -> Vector2i:
	for cd: Variant in (snap["data"] as Dictionary)["combatants"]:
		if str((cd as Dictionary)["side"]) == "party":
			var a := (cd as Dictionary)["cell"] as Array
			return Vector2i(int(a[0]), int(a[1]))
	return Vector2i(-1, -1)


func test_a_round_start_save_resumes_its_fight_in_a_map_that_has_not_changed() -> void:
	var snap := await _saved_fight()
	assert_false(snap.is_empty(), "the fight saved itself as its round began")
	GameState.combat_snapshot = snap
	Compendium.shared().tables["locations"]["test_guard_hall"] = _loc(OPEN_ROWS, true)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(6)
	var v := _view()
	assert_true(v.in_combat, "the fight is back")
	assert_true(v.combat_view.e.round_no >= 3, "at the round it was saved in (%d)" % v.combat_view.e.round_no)


func test_a_round_start_save_begins_again_where_the_map_has_changed() -> void:
	var snap := await _saved_fight()
	var stood := _party_cell(snap)
	assert_ne(stood, Vector2i(-1, -1))
	# Wall in the square somebody stood on in the saved fight.
	var rows: Array = OPEN_ROWS.duplicate()
	var row := str(rows[stood.y])
	rows[stood.y] = row.substr(0, stood.x) + "#" + row.substr(stood.x + 1)
	GameState.combat_snapshot = snap
	Compendium.shared().tables["locations"]["test_guard_hall"] = _loc(rows, true)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(6)
	var v := _view()
	assert_true(v.in_combat, "the fight is on")
	assert_eq(v.combat_view.e.round_no, 1, "from its own start, not resumed on the old layout")
	for c in v.combat_view.e.combatants:
		if c.side == &"party":
			assert_true(_open(v, c.cell), "%s stands on open floor" % c.cell)
