extends TestCase
## Caves as caves (the vault's Natural Maps Plan, I2; owner 2026-10-19: "Ex cave rooms should have natural shapes instead
## of it all being square rooms"): a place whose look says `cave` draws its rock as one surface over a smooth contour
## (Caves) instead of a block a square, in the Modern look; Classic keeps the blocks. The werewolf den's caves, Ghakis's
## lair (its keepers' post stays built), the Amber Temple's deep and the drowned library (the lighter `hewn` amount)
## have it.

const DEN := "werewolf_den_caves"
const LAIR := "ghakis_lair"
const LIBRARY := "drowned_library"
const DEEP := "amber_deep"   # (the Amber Temple's deep: the owner said yes, 2026-10-19)

var view: LocationView
var _was := ""


func before_each() -> void:
	_was = Look.style()
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	# No fight on arrival in the den, so nothing else is drawn.
	GameState.story.set_flag("den_guards_cleared", true)


func after_each() -> void:
	if view != null:
		view.queue_free()
		view = null
	Look.set_style(_was, false)
	GameState.reset()


func _view(loc: String) -> LocationView:
	view = LocationView.create(loc, GameState.story, null, Dice.roller, "default")
	add_child(view)
	await get_tree().process_frame
	return view


## Every cave place draws its rock as a cave, and no square of it is a block any more (a wall square drew an
## "InteriorWall" or a "WallBlock" before).
func test_the_rock_is_a_cave_not_blocks() -> void:
	Look.set_style("modern", false)
	for loc: String in [DEN, LAIR, LIBRARY, DEEP]:
		var v := await _view(loc)
		var cave := Caves.of(v.board)
		assert_true(cave != null, "%s is a cave" % loc)
		if cave == null:
			continue
		assert_true(cave.rock_squares().size() > 100, "%s's rock squares are drawn by the cave" % loc)
		# No wall the kit built stands on a square the cave draws.
		var st := v.board.get_meta("interior_walls", {}) as Dictionary
		for w: Dictionary in st.get("walls", []):
			assert_false(cave.claims(w["cell"] as Vector2i), "%s: no built wall on %s" % [loc, w["cell"]])
		var pieces := 0
		for n in v.board.get_children():
			if n.has_meta("cave"):
				pieces += 1
		assert_true(pieces > 20, "%s has pieces of rock (%d)" % [loc, pieces])
		v.queue_free()
		view = null
		await get_tree().process_frame


## The rock stays out of the floor: nothing of it above the rubble at its foot (half a unit up and more) stands over a
## floor square by more than a quarter of a square (rule 2) plus what its face leans over and the grid's resampling
## moves it, half a square in all, so a token in a square's middle and its ring are always clear of it.
func test_the_rock_never_comes_far_over_the_floor() -> void:
	Look.set_style("modern", false)
	for loc: String in [DEN, LAIR, LIBRARY, DEEP]:
		var v := await _view(loc)
		var cave := Caves.of(v.board)
		var bad := 0
		var worst := 0.0
		var where := ""
		for n in v.board.get_children():
			var mi := n as MeshInstance3D
			if mi == null or not mi.has_meta("cave") or mi.mesh == null:
				continue
			for i in mi.mesh.get_surface_count():
				for p: Vector3 in mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
					var at := mi.position + p
					if at.y - cave.floor_at(at.x, at.z) < 0.5:
						continue
					var depth := cave.outline_at(at.x, at.z)
					worst = maxf(worst, depth)
					if depth > 0.5:
						bad += 1
						if where.length() < 200:
							where += " (%.2f, %.2f, %.2f) piece %s depth %.2f;" % [at.x, at.y, at.z, mi.get_meta("cave"), depth]
		assert_eq(bad, 0, "%s: no rock above the rubble comes more than half a square over the floor (worst %.2f)%s" % [loc, worst, where])
		v.queue_free()
		view = null
		await get_tree().process_frame


## The walls aren't ruler straight: along the south wall of the great cave, where nothing hangs on it, the contour
## wanders by at least a fifth of a square.
func test_a_wall_wanders() -> void:
	Look.set_style("modern", false)
	var v := await _view(DEN)
	var cave := Caves.of(v.board)
	var lo := INF
	var hi := -INF
	var x := 10.0
	while x <= 16.0:
		var f := cave.field_at(x, 19.0)   # the wall's foot, on the grid line
		lo = minf(lo, f)
		hi = maxf(hi, f)
		x += 0.2
	assert_true(hi - lo > 0.2, "the foot of the great cave's south wall moves (%.2f to %.2f)" % [lo, hi])
	assert_true(cave.wobble() > 0.05, "the walls stand off the grid by %.2f on average" % cave.wobble())


## A wall with something hung on it stays straight there: Mother Night's tally marks on the shrine's west wall, a wall
## prop, and the wall at the den's mouth (an exit hung on it). The foot of the wall is within a few hundredths of the
## grid line along its length.
func test_a_wall_with_a_prop_stays_straight() -> void:
	Look.set_style("modern", false)
	var v := await _view(DEN)
	var cave := Caves.of(v.board)
	# den_silver_chains hangs on (1, 13): the alcove's west wall, whose face is the line x = 2.
	for z: float in [13.2, 13.5, 13.8]:
		assert_between(cave.field_at(2.0, z), -0.06, 0.06, "the wall behind the chains is on its grid line at z %.1f" % z)


## Corners round by what the walls beside them allow: a big room's corner is cut (a plain 12 x 12 room in rock, drawn
## with the walls' wandering off), a one square niche's hardly.
func test_corners_round() -> void:
	Look.set_style("modern", false)
	var rows: Array[String] = []
	for z in 20:
		var row := ""
		for x in 20:
			row += "." if (x >= 4 and x < 16 and z >= 4 and z < 16) else "#"
		rows.append(row)
	var b := ArenaBoard.build(CombatGrid.from_rows(rows), "dungeon", "")
	var cave := Caves.new()
	cave.board = b
	cave.look = {"cave": true}
	cave.amt = (Caves.AMOUNTS["full"] as Dictionary).duplicate()
	cave.amt["wander"] = 0.0
	cave.amt["bays"] = 0.0
	cave._plan()
	var wall := cave.field_at(4.3, 10.0)
	var corner := cave.field_at(4.3, 4.3)
	assert_between(wall, 0.2, 0.4, "a plain wall holds its line (%.2f)" % wall)
	assert_true(corner < wall - 0.08, "the room's corner is cut (%.2f against %.2f)" % [corner, wall])
	assert_true(cave.deepest_intrusion() <= 0.35, "and never by more than a quarter of a square (%.2f)" % cave.deepest_intrusion())
	b.free()


## The keepers' post of Ghakis's lair is still built, with its walls drawn as before, while the rock round it is the
## cave's; the drowned library's shelves are still shelves.
func test_what_is_built_stays_built() -> void:
	Look.set_style("modern", false)
	var v := await _view(LAIR)
	assert_false(Caves.owns(v.board, Vector2i(16, 23)), "a wall of the keepers' post isn't the cave's")
	assert_false(Caves.owns(v.board, Vector2i(10, 22)), "nor the north wall of the post")
	assert_true(Caves.owns(v.board, Vector2i(18, 24)), "the rock between the post and the tunnel is")
	var built := ((v.board.get_meta("interior_walls", {}) as Dictionary).get("walls", []) as Array).size()
	assert_true(built > 10, "the post's walls are InteriorWalls (%d)" % built)
	v.queue_free()
	view = null
	await get_tree().process_frame
	var lib := await _view(LIBRARY)
	assert_false(Caves.owns(lib.board, Vector2i(6, 5)), "a stack of shelves isn't rock")
	assert_true(Caves.owns(lib.board, Vector2i(3, 8)), "the library's outer wall is")
	assert_true(Caves.owns(lib.board, Vector2i(0, 8)), "and so is the ring of rock round the map")
	for key: String in ["round", "wander", "bays", "lean", "talus", "decor"]:
		assert_true(float((Caves.AMOUNTS["hewn"] as Dictionary)[key]) <= float((Caves.AMOUNTS["full"] as Dictionary)[key]), "hewn is the lighter amount of %s" % key)


## Rock opens round the party where it hides it, like every wall (SeeThrough), and the floor gets its loose stones,
## puddles in the den only.
func test_rock_opens_and_the_floor_has_things() -> void:
	Look.set_style("modern", false)
	var v := await _view(DEN)
	var unmarked := 0
	var far := false
	for n in v.board.get_children():
		if n is MeshInstance3D and n.has_meta("cave") and not SeeThrough.marked(n as MeshInstance3D):
			unmarked += 1
		if n.name == "CaveRockFar":
			far = true
	assert_eq(unmarked, 0, "every piece of rock opens round the party")
	assert_true(far, "the rock far from any cave is one top")
	var decor := v.board.get_node_or_null("CaveDecor")
	assert_true(decor != null and decor.has_node("Stones") and decor.has_node("Puddles"), "stones and puddles on the den's floor")
	assert_true(decor != null and bool(decor.get_meta("stays", false)), "kept when a prop takes a square")
	v.queue_free()
	view = null
	await get_tree().process_frame
	var lair := await _view(LAIR)
	var lair_decor := lair.board.get_node_or_null("CaveDecor")
	assert_true(lair_decor != null and lair_decor.has_node("Stones") and not lair_decor.has_node("Puddles"), "stones, but no puddles, on the lair's")


## A door in a gap in a cave's rock brings its own frame (InteriorWalls frames only the walls it builds), and Classic
## keeps its blocks.
func test_the_door_has_a_frame_and_classic_keeps_blocks() -> void:
	Look.set_style("modern", false)
	var v := await _view(DEN)
	assert_false(InteriorWalls.frames(v.board, Vector2i(5, 7)), "the pen's gate is hung without the kit's doorway")
	v.queue_free()
	view = null
	await get_tree().process_frame
	Look.set_style("classic", false)
	var classic := await _view(DEN)
	assert_true(Caves.of(classic.board) == null, "Classic keeps the old blocks")
