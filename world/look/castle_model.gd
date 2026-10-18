class_name CastleModel
extends RefCounted
## The model of Castle Ravenloft on the table in the warden Exethanter's study (Amber Temple Look Plan step 12): the
## wardens' architect built it from what he saw from the mountain, so it is made here from the castle's own kit pieces
## (the curtain walls' tops, round towers with their spires, the gate, the keep's lit windows) at a fiftieth of their size,
## one mesh on a plain table. Only a look: the square it stands on is the table's, as ever; the Modern finish only (Classic
## keeps the round table's picture).

## How small the model is made: the castle is thirty-eight squares across, the model most of one.
const SCALE := 0.022
## The curtain walls' rectangle in the castle's own squares (x, z, half-width, half-depth), their height, and the keep's.
const WALLS := Rect2(-17.0, -11.0, 34.0, 22.0)
const WALL_H := 6.0
const KEEP := Rect2(-9.0, -7.0, 18.0, 11.0)
const KEEP_H := 10.5
const CORE := "castle/ashlar"
const TABLE_TOP := Vector3(1.0, 0.07, 0.72)
const TABLE_HEIGHT := 0.58
const WOOD := "walnut"


## Builds the table and the castle on it, at `cell`, under `root` (SetDressing.place's node for the prop); returns `root`.
static func place(board: ArenaBoard, root: Node3D, cell: Vector2i) -> Node3D:
	SetDressing.take_square(board, root, cell)   # it stands where the board's own furniture was
	var base := board.cell_center(cell)
	var table := Node3D.new()
	table.name = "ModelTable"
	table.position = base
	root.add_child(table)
	var top := MeshInstance3D.new()
	top.name = "TableTop"
	var tb := BoxMesh.new()
	tb.size = TABLE_TOP
	top.mesh = tb
	top.position = Vector3(0, TABLE_HEIGHT, 0)
	top.material_override = Look.cel(WOOD)
	table.add_child(top)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var leg := MeshInstance3D.new()
			leg.name = "TableLeg"
			var lb := BoxMesh.new()
			lb.size = Vector3(0.07, TABLE_HEIGHT, 0.07)
			leg.mesh = lb
			leg.position = Vector3(sx * (TABLE_TOP.x / 2.0 - 0.08), TABLE_HEIGHT / 2.0, sz * (TABLE_TOP.z / 2.0 - 0.08))
			leg.material_override = Look.cel(WOOD)
			table.add_child(leg)
	var castle := _castle()
	if castle != null:
		castle.name = "CastleRavenloft"
		castle.position = Vector3(0, TABLE_HEIGHT + TABLE_TOP.y / 2.0, 0)
		castle.scale = Vector3.ONE * SCALE
		castle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		table.add_child(castle)
	return root


## The castle as one mesh, in its own squares (the origin the middle of its ground, y up), from the kit; null where the
## kit isn't there.
static func _castle() -> MeshInstance3D:
	if not BuildingKit.has("kit_castle_wall_top_a"):
		return null
	var parts: Array = []
	# The rock it stands on.
	parts.append([_box(Vector3(WALLS.size.x + 3.0, 1.4, WALLS.size.y + 3.0)), Transform3D(Basis(), Vector3(0, -0.7, 0)), "pal_pewter"])
	# The curtain walls: a body and the kit's crenellated top the length of each side.
	var x0 := WALLS.position.x
	var z0 := WALLS.position.y
	var x1 := WALLS.end.x
	var z1 := WALLS.end.y
	for side: Array in [[Vector2(x0, z0), Vector2(x1, z0)], [Vector2(x0, z1), Vector2(x1, z1)],
			[Vector2(x0, z0), Vector2(x0, z1)], [Vector2(x1, z0), Vector2(x1, z1)]]:
		var a := side[0] as Vector2
		var b := side[1] as Vector2
		var mid := (a + b) / 2.0
		var along := (b - a).length()
		var horizontal := absf(b.y - a.y) < 0.01
		parts.append([_box(Vector3(along if horizontal else 0.8, WALL_H, 0.8 if horizontal else along)),
			Transform3D(Basis(), Vector3(mid.x, WALL_H / 2.0, mid.y)), CORE])
		# (the kit's top outward: facing away from the middle)
		var out := Vector3(0, 0, -1.0 if mid.y < 0.0 else 1.0) if horizontal else Vector3(-1.0 if mid.x < 0.0 else 1.0, 0, 0)
		var steps := int(along)
		for i in steps:
			var t := (float(i) + 0.5) / float(steps)
			var p := a.lerp(b, t)
			if horizontal and absf(p.x) < 1.6 and mid.y > 0.0:
				continue   # the gate's gap on the south side
			parts.append(["kit_castle_wall_top_a", BuildingKit.face_xf(Vector3(p.x, WALL_H, p.y) + out * 0.4, atan2(out.x, out.z))])
	# The gate in the south wall.
	if BuildingKit.has("kit_castle_gate_w2_d2"):
		parts.append(["kit_castle_gate_w2_d2", Transform3D(Basis(), Vector3(0, 0, z1))])
	# The keep: a tall block with its lit windows along its south face, and its tall round towers.
	parts.append([_box(Vector3(KEEP.size.x, KEEP_H, KEEP.size.y)),
		Transform3D(Basis(), Vector3(KEEP.position.x + KEEP.size.x / 2.0, KEEP_H / 2.0, KEEP.position.y + KEEP.size.y / 2.0)), CORE])
	var face_z := KEEP.end.y
	for i in 6:
		var wx := KEEP.position.x + 2.0 + float(i) * 2.9
		parts.append(["kit_castle_window_lit" if i % 2 == 0 else "kit_castle_window", BuildingKit.face_xf(Vector3(wx, 3.0, face_z + 0.03), 0.0)])
	# Round towers, corner and keep, each with its spire.
	for t: Array in [[-17.0, -11.0, 1.1, 8.5], [17.0, -11.0, 1.1, 8.5], [-17.0, 11.0, 1.1, 8.0], [17.0, 11.0, 1.1, 8.0],
			[-9.0, -7.0, 1.6, 14.0], [9.0, -7.0, 1.4, 13.0], [0.0, -7.0, 1.0, 15.5], [-9.0, 4.0, 1.2, 12.0], [9.0, 4.0, 1.2, 12.0]]:
		_tower(parts, float(t[0]), float(t[1]), float(t[2]), float(t[3]))
	return BuildingKit.merge(parts)


## A round tower at (`x`, `z`) of radius `r` and height `h`: its battered foot, its shaft, its top and its spire.
static func _tower(parts: Array, x: float, z: float, r: float, h: float) -> void:
	var sc := Basis.from_scale(Vector3(r, 1.0, r))
	var foot := 1.23
	if BuildingKit.has("kit_castle_tower_foot"):
		parts.append(["kit_castle_tower_foot", Transform3D(sc, Vector3(x, 0, z))])
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = h - foot
	cyl.radial_segments = 16
	cyl.rings = 1
	parts.append([cyl, Transform3D(Basis(), Vector3(x, (h + foot) / 2.0, z)), CORE])
	if BuildingKit.has("kit_castle_tower_top"):
		parts.append(["kit_castle_tower_top", Transform3D(sc, Vector3(x, h, z))])
	if BuildingKit.has("kit_castle_spire"):
		parts.append(["kit_castle_spire", Transform3D(Basis.from_scale(Vector3(r, r, r)), Vector3(x, h + 0.55, z))])


static func _box(size: Vector3) -> BoxMesh:
	var bm := BoxMesh.new()
	bm.size = size
	return bm
