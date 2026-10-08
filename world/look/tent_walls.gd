class_name TentWalls
extends RefCounted
## Tents (interior style "tent", docs/art/interiors.md): a tent's walls are canvas, not a house's. Each wall square
## holds a sheet of the patched canvas (tent/canvas) on every side that faces the room, hanging in folds and leaning in
## toward the top, with the foot of the roof's slope above it, a dark hem at the ground, poles at the corners and every
## few squares, and a rope along the top that charms hang from. The painted eyes among the charms turn, very slowly, to
## face the camera ("each one is turning, very slowly, to face you"). Behind the canvas lies the camp's ground.
##
## In the Modern look the sheets stand a full tent wall high and drop to the cut-away height toward the camera as a
## room's walls do (InteriorWalls hands every tent wall square here, with its state); in Classic they stand at the
## cut-away height, without charms or roof. Nothing here changes the rules grid.

## How far the canvas leans in over a full wall, and how far the roof's foot reaches in and climbs above it.
const LEAN := 0.16
const ROOF_IN := 0.34
const ROOF_UP := 0.3
## Folds per square, and how deep they are at the top (half that at the hem).
const FOLDS := 2.5
const FOLD_DEPTH := 0.035
## The canvas's foot stands this far inside the wall square, so the folds never reach the room's floor.
const INSET := 0.045
## A pole at every corner and at every third seam along a wall.
const POLE_EVERY := 3
const POLE_R := 0.04
const CANVAS := "tent/canvas"
const ACROSS := 12      ## sheet columns per square
const UP := 6           ## sheet rows

## Charms are drawn half as big again as life, so they read from the camera.
const CHARM_SCALE := 1.5
## The charms on the ropes: [kind, palette colour]. Bones, bells, little mirrors, a dried bird's foot, beads, a tooth,
## and painted eyes (the narration's charms; the eyes are the tent's own painted eyes).
const CHARMS := [["eye", "ivory"], ["bell", "tan"], ["bone", "bone"], ["mirror", "silver"], ["eye", "ivory"],
	["foot", "umber"], ["beads", "crimson"], ["tooth", "vellum"], ["bell", "pewter"], ["beads", "moon_blue"]]


static func is_tent(board: ArenaBoard) -> bool:
	return BuildingKit.interior_style(board) == "tent"


## Builds tent wall square `c`: canvas on each side facing the room (full and cut versions, registered with the room
## walls' cut-away in `st`, InteriorWalls' state; empty in Classic), always on the camp's ground. Always true: a tent
## never falls back to a wall block.
static func build(board: ArenaBoard, c: Vector2i, wall_mat: Material, st: Dictionary) -> bool:
	# Pieces hung on the canvas or backed onto it stand off it: past the inset and the lean at about chest height.
	board.wall_inset = INSET + FOLD_DEPTH + LEAN * (float(st["height"]) if not st.is_empty() else InteriorWalls.CUT) / 2.5 * 0.6
	_ground(board, c, st)
	var faces := _faces(board, c)
	var canvas: Material = Look.cel_textured(CANVAS)
	if canvas == null:
		canvas = wall_mat
	if faces.is_empty():
		return true   # a corner of the wall: the sheets of the two sides meet in front of it, at a pole
	var node := Node3D.new()
	node.name = "TentWall"
	node.position = board.cell_center(c)
	board.add_child(node)
	if st.is_empty():
		_canvas(node, board, c, faces, InteriorWalls.CUT, canvas, false)
		return true
	var h := float(st["height"])
	var full := Node3D.new()
	full.name = "Full"
	node.add_child(full)
	var low := Node3D.new()
	low.name = "Cut"
	low.visible = false
	node.add_child(low)
	_canvas(full, board, c, faces, h, canvas, true)
	_canvas(low, board, c, faces, InteriorWalls.CUT, canvas, false)
	(st["walls"] as Array).append({"node": node, "full": full, "low": low, "cell": c, "cut": false, "h": h})
	return true


## The camp's ground under a wall square (the canvas stands on it, and it shows past the cut-away canvas).
static func _ground(board: ArenaBoard, c: Vector2i, st: Dictionary) -> void:
	var surface := str(st.get("ground", "")) if not st.is_empty() else ""
	var mat: Material = Look.cel_textured(surface if surface != "" else "village/grass", 0.0)
	board.add_box("Ground", Vector3(1, 0.2, 1), Vector3(c.x + 0.5, -0.1, c.y + 0.5), mat if mat != null else Look.cel("bog_deep"))


## The sides of `c` with an open square beside it.
static func _faces(board: ArenaBoard, c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in SetDressing.FACES:
		if _open(board, c + d):
			out.append(d)
	return out


static func _open(board: ArenaBoard, c: Vector2i) -> bool:
	return board.grid.in_bounds(c) and not board.grid.has_flag(c, CombatGrid.WALL) and not board.grid.has_flag(c, CombatGrid.VOID)


## The canvas on the faces of `c` (Vector2i directions toward the room) under `parent`, which stands at the square's
## centre, `h` high; `dressed` adds the roof's foot, the poles, the rope and its charms.
static func _canvas(parent: Node3D, board: ArenaBoard, c: Vector2i, faces: Array[Vector2i], h: float, canvas: Material,
		dressed: bool) -> void:
	var lean := LEAN * h / 2.5
	for d in faces:
		var t := Vector2i(-d.y, d.x)
		# A room corner at an end of this side (the room stops there: the next square along is wall): the sheet's top
		# is pulled in at that end to meet the next side's sheet, which leans in too.
		var corner_hi := not _open(board, c + d + t)
		var corner_lo := not _open(board, c + d - t)
		var sheet := _sheet(c, d, h, lean, corner_lo, corner_hi, 0.0, 0.0)
		_mesh(parent, sheet, canvas, "Canvas")
		var dv := Vector3(d.x, 0, d.y)
		var tv := Vector3(t.x, 0, t.y)
		_box(parent, Vector3(1.0, 0.08, 0.05) if d.y != 0 else Vector3(0.05, 0.08, 1.0), dv * (0.5 - INSET + 0.02) + Vector3(0, 0.04, 0),
			Look.cel("bruise_deep"))
		if not dressed:
			continue
		# The roof's foot: canvas climbing in from the wall's top (the rest of the roof is above the camera's view).
		var roof := _sheet(c, d, h, lean, corner_lo, corner_hi, ROOF_IN, ROOF_UP)
		_mesh(parent, roof, canvas, "Roof")
		_rope_and_charms(parent, board, c, d, t, h, lean, corner_lo, corner_hi)
		# Poles: at the room's corners (drawn by the side running east-west, so each corner gets one) and at every third
		# seam along a wall.
		for s: int in [-1, 1]:
			var at_corner := corner_hi if s == 1 else corner_lo
			var seam := (c.x if d.y != 0 else c.y) + (1 if s == 1 else 0)
			if (at_corner and d.y != 0) or (not at_corner and posmod(seam, POLE_EVERY) == 0 and _open(board, c + d + t * s)
					and not _open(board, c + t * s)):
				var foot := dv * (0.5 - INSET + 0.03) + tv * (0.5 * s)
				var top := foot + dv * lean + Vector3(0, h + 0.18, 0)
				if at_corner:
					foot += -tv * (0.03 * s)
					top += -tv * (lean * s)
				_pole(parent, foot, top)


## A sheet of canvas along side `d` of square `c` (local to the square's centre): from the hem up `h` with the folds and
## the lean, or with `reach` > 0 the roof's foot, from the wall's top `reach` further in and `rise` higher. Ends at a
## room corner are pulled in so the sheets of two sides meet. Returns [points (rows of columns), the normal side].
static func _sheet(c: Vector2i, d: Vector2i, h: float, lean: float, corner_lo: bool, corner_hi: bool, reach: float,
		rise: float) -> Dictionary:
	var t := Vector2i(-d.y, d.x)
	var dv := Vector3(d.x, 0, d.y)
	var tv := Vector3(t.x, 0, t.y)
	var along0 := float(c.x if t.x != 0 else c.y) * float(t.x + t.y)   # world position along the side, for the folds
	var rows: Array = []
	for j in UP + 1:
		var v := float(j) / UP
		var row: Array[Vector3] = []
		for i in ACROSS + 1:
			var u := float(i) / ACROSS - 0.5
			var p := Vector3.ZERO
			if reach <= 0.0:
				var pull := lean * v
				var uu := u
				if corner_hi:
					uu -= pull * (u + 0.5)
				if corner_lo:
					uu += pull * (0.5 - u)
				var taper := minf(1.0, (0.5 - absf(u)) * 6.0) if (corner_hi and u > 0.0) or (corner_lo and u < 0.0) else 1.0
				var fold := FOLD_DEPTH * sin((along0 + u * float(t.x + t.y)) * FOLDS * TAU) * (0.5 + 0.5 * v) * taper
				p = dv * (0.5 - INSET + pull + fold) + tv * uu + Vector3(0, v * h, 0)
			else:
				# The roof's foot: from the canvas's top edge (its lean) in by `reach` and up by `rise`.
				var inward := lean + reach * v
				var uu := u
				if corner_hi:
					uu -= inward * (u + 0.5)
				if corner_lo:
					uu += inward * (0.5 - u)
				p = dv * (0.5 - INSET + inward) + tv * uu + Vector3(0, h + rise * v, 0)
			row.append(p)
		rows.append(row)
	return {"rows": rows, "out": dv}


## A two-sided mesh of a sheet's grid (`sheet` from _sheet), normals toward the room in front and away behind.
static func _mesh(parent: Node3D, sheet: Dictionary, mat: Material, name: String) -> MeshInstance3D:
	var rows := sheet["rows"] as Array
	var inward := sheet["out"] as Vector3
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var idx := PackedInt32Array()
	var nr := rows.size()
	var nc := (rows[0] as Array).size()
	for side: int in [1, -1]:
		var base := verts.size()
		for j in nr:
			for i in nc:
				var p := (rows[j] as Array)[i] as Vector3
				var du := ((rows[j] as Array)[mini(i + 1, nc - 1)] as Vector3) - ((rows[j] as Array)[maxi(i - 1, 0)] as Vector3)
				var dw := ((rows[mini(j + 1, nr - 1)] as Array)[i] as Vector3) - ((rows[maxi(j - 1, 0)] as Array)[i] as Vector3)
				var n := du.cross(dw).normalized()
				if n.dot(inward) < 0.0:
					n = -n
				verts.append(p)
				normals.append(n * side)
		for j in nr - 1:
			for i in nc - 1:
				var a := base + j * nc + i
				for tri: Array in [[a, a + 1, a + nc + 1], [a, a + nc + 1, a + nc]]:
					_tri(idx, verts, tri, inward * side)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = am
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## A triangle wound so its front faces `toward` (Godot's front faces are clockwise as seen).
static func _tri(idx: PackedInt32Array, verts: PackedVector3Array, tri: Array, toward: Vector3) -> void:
	var a := verts[int(tri[0])]
	var b := verts[int(tri[1])]
	var c := verts[int(tri[2])]
	if (b - a).cross(c - a).dot(toward) > 0.0:
		idx.append_array([int(tri[0]), int(tri[2]), int(tri[1])])
	else:
		idx.append_array([int(tri[0]), int(tri[1]), int(tri[2])])


## A tent pole from `foot` to `top` (local), with a rope lashed round it under the top.
static func _pole(parent: Node3D, foot: Vector3, top: Vector3) -> void:
	var wood: Material = Look.cel_textured("kit/oak_v")
	if wood == null:
		wood = Look.cel("walnut")
	var along := top - foot
	var mi := MeshInstance3D.new()
	mi.name = "Pole"
	var cm := CylinderMesh.new()
	cm.top_radius = POLE_R * 0.85
	cm.bottom_radius = POLE_R
	cm.height = along.length()
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = wood
	mi.transform = Transform3D(_basis_along(along), foot + along / 2.0)
	parent.add_child(mi)
	var lash := MeshInstance3D.new()
	lash.name = "Lashing"
	var lm := CylinderMesh.new()
	lm.top_radius = POLE_R * 1.3
	lm.bottom_radius = POLE_R * 1.3
	lm.height = 0.07
	lm.radial_segments = 8
	lash.mesh = lm
	lash.material_override = Look.cel("tan")
	lash.transform = Transform3D(_basis_along(along), foot + along * 0.9)
	parent.add_child(lash)


## A basis whose y axis runs along `dir`.
static func _basis_along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


## The rope along the top of side `d` and the charms hanging from it (two to four per square, picked by the square).
static func _rope_and_charms(parent: Node3D, board: ArenaBoard, c: Vector2i, d: Vector2i, t: Vector2i, h: float,
		lean: float, corner_lo: bool, corner_hi: bool) -> void:
	var dv := Vector3(d.x, 0, d.y)
	var tv := Vector3(t.x, 0, t.y)
	var y := h - 0.06
	var out := dv * (0.5 - INSET + lean * (y / h) + FOLD_DEPTH + 0.03)
	var lo := -0.5 + (lean if corner_lo else 0.0)
	var hi := 0.5 - (lean if corner_hi else 0.0)
	var rope := MeshInstance3D.new()
	rope.name = "Rope"
	var rm := CylinderMesh.new()
	rm.top_radius = 0.012
	rm.bottom_radius = 0.012
	rm.height = hi - lo
	rm.radial_segments = 6
	rope.mesh = rm
	rope.material_override = Look.cel("tan")
	rope.transform = Transform3D(_basis_along(tv), out + tv * ((lo + hi) / 2.0) + Vector3(0, y, 0))
	parent.add_child(rope)
	var seed := ModelPiece.hash_cell(c) + d.x * 7 + d.y * 13
	var count := 2 + posmod(seed, 3)
	for k in count:
		var u := lerpf(lo + 0.12, hi - 0.12, (k + 0.5) / count) + float(posmod(seed * (k + 3), 7) - 3) * 0.02
		var kind := CHARMS[posmod(seed + k * 5, CHARMS.size())] as Array
		var drop := 0.14 + float(posmod(seed * (k + 1), 5)) * 0.06
		var charm := Charm.make(str(kind[0]), str(kind[1]), drop)
		charm.position = out + tv * u + Vector3(0, y, 0)
		charm.scale = Vector3.ONE * CHARM_SCALE
		charm.rotation.y = float(posmod(seed * 31 + k * 97, 360)) * PI / 180.0
		parent.add_child(charm)


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Hem"
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi
