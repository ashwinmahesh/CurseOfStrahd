class_name Stairs
extends RefCounted
## Stairs built as steps (owner report 2026-10-06: the stair pictures were too small and the stairwell down looked
## like an odd icon). Real steps read right from every camera heading and stand at a believable size beside a 6 ft
## person: a flight up climbs 7.5 ft over its square, a stairwell down drops 7 ft into a stone shaft. The steps start
## at the square's open side, where the party walks in, and climb or descend away from it.

const STEPS := 7
const RISE := 1.5      ## a flight up: 7.5 ft
const DROP := 1.4      ## a stairwell down: 7 ft
const WIDTH := 0.9
const WOODEN := ["manor", "townhouse", "house", "attic", "tavern", "inn", "shop", "tent"]
## A short flight up a 5 ft rise between two floors (owner, 2026-10-15: "we shouldn't just be stepping straight up
## onto 5ft bricks. There should be small steps leading to it"; Castle Ravenloft first, every place since 2026-10-17):
## FLIGHT_STEPS steps in the lower square's half against the higher square's face, the higher floor the last step.
## Where: every location's built floors (ArenaBoard), and CastleBuilder for the gates' wall walk. The rules grid is
## unchanged: a 5 ft step up is still one.
const FLIGHT_STEPS := 5
const FLIGHT_DEPTH := 0.5


## Whether two floors `rise` apart (world units) are one 5 ft step, which a flight dresses.
static func flight_rise(rise: float) -> bool:
	return rise > 0.6 and rise < 1.4


## The boxes of a flight ([{size, at}], world units): `edge` is the middle of the edge the two squares share at the
## lower floor's height, `d` points from the lower square to the higher, `rise` is how far up the higher floor is. Each
## step is solid down to the floor, and a little below it, so it sits on uneven ground too.
static func flight(edge: Vector3, d: Vector2i, rise: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var tread := FLIGHT_DEPTH / FLIGHT_STEPS
	var back := Vector3(-d.x, 0, -d.y)
	for i in FLIGHT_STEPS:
		var h := rise * (FLIGHT_STEPS - i) / float(FLIGHT_STEPS + 1)   # the tallest against the face
		var size := Vector3(1.0 if d.x == 0 else tread, h + 0.2, tread if d.x == 0 else 1.0)
		out.append({"size": size, "at": edge + back * (tread * (i + 0.5)) + Vector3(0, (h - 0.2) / 2.0, 0)})
	return out


## The side of `cell` the party comes in from: an open neighbour, the ones the opening camera faces first.
static func entry_side(board: ArenaBoard, cell: Vector2i) -> Vector2i:
	for d in SetDressing.FACES:
		var n := cell + d
		if board.grid.in_bounds(n) and not board.grid.has_flag(n, CombatGrid.WALL) and not board.grid.has_flag(n, CombatGrid.VOID):
			return d
	return Vector2i(0, 1)


## A flight of steps up on `cell`, under `parent`. Returns its root.
static func up(board: ArenaBoard, parent: Node3D, cell: Vector2i) -> Node3D:
	var root := _root(board, parent, cell, "StairsUp")
	var tread := _tread(board)
	var step := 1.0 / STEPS
	for i in STEPS:
		var h := RISE * (i + 1) / STEPS
		# Each step is solid down to the floor, so the flight reads as one block of stairs from the side.
		_box(root, Vector3(WIDTH, h, step), Vector3(0, h / 2.0, 0.5 - step * (i + 0.5)), tread)
	# A banister on one side, following the slope.
	var rail := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var run := sqrt(1.0 + RISE * RISE)
	bm.size = Vector3(0.06, 0.06, run)
	rail.mesh = bm
	rail.position = Vector3(WIDTH / 2.0, RISE / 2.0 + 0.45, 0)
	rail.rotation.x = atan2(RISE, 1.0)
	rail.material_override = Look.cel("walnut")
	root.add_child(rail)
	for z: float in [0.45, -0.45]:
		var post_h := RISE * (0.5 - z) + 0.45
		_box(root, Vector3(0.07, post_h, 0.07), Vector3(WIDTH / 2.0, post_h / 2.0, z), Look.cel("walnut"))
	return root


## A stairwell down on `cell`: the square's floor gives way to a stone shaft with steps descending into the dark.
static func down(board: ArenaBoard, parent: Node3D, cell: Vector2i) -> Node3D:
	var root := _root(board, parent, cell, "StairsDown")
	if board.grid.has_flag(cell, CombatGrid.WALL):
		SetDressing.take_square(board, root, cell)
	board.hide_floor(cell)
	root.tree_exiting.connect(func() -> void:
		if is_instance_valid(board):
			board.show_floor(cell))
	var tread := _tread(board)
	var shaft: Material = Look.cel_textured("dungeon/stone_wall")
	if shaft == null:
		shaft = Look.cel("stone_deep")
	var step := 1.0 / STEPS
	for i in STEPS:
		var top := -DROP * (i + 1) / STEPS
		_box(root, Vector3(WIDTH, DROP + top + 0.02, step), Vector3(0, (top - DROP) / 2.0, 0.5 - step * (i + 0.5)), tread)
	# The shaft: three stone sides and a dark floor at the bottom, so the hole doesn't show under the floor around it.
	_box(root, Vector3(1.0, 0.05, 1.0), Vector3(0, -DROP - 0.02, 0), Look.cel("void"))
	_box(root, Vector3(1.0, DROP, 0.05), Vector3(0, -DROP / 2.0, -0.475), shaft)
	for x: float in [-0.475, 0.475]:
		_box(root, Vector3(0.05, DROP, 1.0), Vector3(x, -DROP / 2.0, 0), shaft)
	return root


static func _root(board: ArenaBoard, parent: Node3D, cell: Vector2i, name_: String) -> Node3D:
	var root := Node3D.new()
	root.name = name_
	parent.add_child(root)
	var e := entry_side(board, cell)
	root.position = board.cell_center(cell) - parent.position   # its parent is a holder at the board's origin
	# Local +z points to the entry side: the steps start there.
	var n := Vector3(e.x, 0, e.y)
	root.rotation.y = atan2(n.x, n.z)
	return root


static func _tread(board: ArenaBoard) -> Material:
	var surface := "interior/wood_planks" if board.theme in WOODEN else "dungeon/stone_floor"
	var m := Look.cel_textured(surface)
	return m if m != null else Look.cel("walnut" if board.theme in WOODEN else "stone")


static func _box(root: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	root.add_child(mi)
