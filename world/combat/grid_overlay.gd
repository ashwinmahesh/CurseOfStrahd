class_name GridOverlay
extends Node3D
## Marks painted on the combat floor, only while they answer something the player is pointing at (owner 2026-10-06:
## the always-lit blue squares of where a creature could move were noise). Hovering the floor shows a dotted trail to
## a ring where the creature would stop, red when the walk provokes; aiming shows an area's edge and who can be
## targeted; a controller's cursor is a pale ring. Drawn just above the floor, one instance per mark per layer.

const LAYERS := {
	"path": {"colour": "wick", "alpha": 0.85, "lift": 0.02, "size": 0.2, "shape": "dot"},
	"goal": {"colour": "wick", "alpha": 0.85, "lift": 0.022, "size": 0.78, "shape": "ring"},
	"danger": {"colour": "crimson", "alpha": 0.9, "lift": 0.023, "size": 0.78, "shape": "ring"},
	"cursor": {"colour": "ivory", "alpha": 0.55, "lift": 0.021, "size": 0.78, "shape": "ring"},
	"area": {"colour": "candle", "alpha": 0.5, "lift": 0.016, "size": 0.96},
	"target": {"colour": "vampire_red", "alpha": 0.55, "lift": 0.018, "size": 0.98},
	"friendly": {"colour": "flame", "alpha": 0.5, "lift": 0.018, "size": 0.98},
	"weapon": {"colour": "lilac", "alpha": 0.6, "lift": 0.019, "size": 0.6},
	# A jump's or a throw's flight (show_arc): beads along a curve through the air (Combat HUD plan, owner pick 5).
	"arc": {"colour": "gilt_light", "alpha": 0.95, "lift": 0.0, "size": 0.11, "shape": "ball"},
	"arc_bad": {"colour": "crimson", "alpha": 0.9, "lift": 0.0, "size": 0.11, "shape": "ball"},
}
## Beads in an arc, and how high it rises for each square it covers (up to ARC_RISE_MOST).
const ARC_BEADS := 16
const ARC_RISE := 0.22
const ARC_RISE_MOST := 2.2

## How much higher a mark sits on a slope (natural ground), so the ground's bends don't swallow its corners.
const SLOPE_LIFT := 0.03

## An area's edge on the floor while a spell is aimed (show_outline), in place of its squares painted orange (owner,
## 2026-10-12: "for AoE spells, don't make the floor orange. Instead show a circular border which shows the area that
## would be affected"): a pale gold line, smooth round a radius, just under the creatures' rings so those stay clear.
const OUTLINE := {"colour": "wick", "alpha": 0.95, "lift": 0.026, "width": 0.14}
## The most a stretch of the line runs straight (squares), so it bends with natural ground and stays round.
const OUTLINE_STEP := 0.1
## How far a sharp corner's mitre may reach, in line widths (a cone's tip).
const OUTLINE_MITRE := 2.5
const OUTLINE_SHADER := preload("res://shaders/fx/area_outline.gdshader")

var board: ArenaBoard
var _layers: Dictionary = {}
var _outline: MeshInstance3D
## What the outline shows now, so pointing again at the same aim doesn't rebuild it.
var _outline_shows: Variant = null


static func create(board_: ArenaBoard) -> GridOverlay:
	var o := GridOverlay.new()
	o.name = "GridOverlay"
	o.board = board_
	for key: String in LAYERS:
		o._make_layer(key)
	o._make_outline()
	return o


func _make_outline() -> void:
	_outline = MeshInstance3D.new()
	_outline.name = "AreaOutline"
	var mat := ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	mat.set_shader_parameter("line_col", Color(Look.color(str(OUTLINE["colour"])), float(OUTLINE["alpha"])))
	# Drawn after the palette pass, like the other marks.
	mat.render_priority = 5
	_outline.material_override = mat
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_outline.visible = false
	add_child(_outline)


func _make_layer(key: String) -> void:
	var spec := LAYERS[key] as Dictionary
	var size := float(spec["size"])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	match str(spec.get("shape", "square")):
		"dot":
			var dot := CylinderMesh.new()
			dot.top_radius = size / 2.0
			dot.bottom_radius = size / 2.0
			dot.height = 0.004
			dot.radial_segments = 16
			dot.rings = 1
			mm.mesh = dot
		"ball":
			var ball := SphereMesh.new()
			ball.radius = size / 2.0
			ball.height = size
			ball.radial_segments = 8
			ball.rings = 4
			mm.mesh = ball
		"ring":
			var ring := TorusMesh.new()
			ring.outer_radius = size / 2.0
			ring.inner_radius = size / 2.0 - 0.06
			ring.rings = 32
			ring.ring_segments = 4
			mm.mesh = ring
		_:
			var pm := PlaneMesh.new()
			pm.size = Vector2(size, size)
			mm.mesh = pm
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Layer_" + key
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(Look.color(str(spec["colour"])), float(spec["alpha"]))
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.no_depth_test = false
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Drawn after the palette pass (which copies the screen before transparent geometry), like UI.
	mat.render_priority = 5
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_layers[key] = mmi


## Paints `cells` on layer `key` (replacing what was there).
func show_cells(key: String, cells: Array) -> void:
	var spots: Array[Vector3] = []
	for cell: Vector2i in cells:
		spots.append(_spot(cell))
	_place(key, spots)


## A walk from the first of `cells` to the last as a dotted trail on layer `key`: a dot between each pair of squares
## and on each square between the ends (the walker stands on the first, a ring marks the last), so the line reads as
## one path and diagonals don't look broken.
func show_trail(key: String, cells: Array) -> void:
	var spots: Array[Vector3] = []
	for i in range(1, cells.size()):
		var here := _spot(cells[i] as Vector2i)
		var mid := (_spot(cells[i - 1] as Vector2i) + here) / 2.0
		mid.y = maxf(here.y, _spot(cells[i - 1] as Vector2i).y)   # on the edge of a step up, not in the air
		if board.has_terrain():
			# On natural ground: the slope between them (or the top of a cliff), from each side of the edge.
			var m := Vector2(mid.x, mid.z)
			var back := _spot(cells[i - 1] as Vector2i)
			mid.y = maxf(board.ground_y(m.lerp(Vector2(here.x, here.z), 0.02)), board.ground_y(m.lerp(Vector2(back.x, back.z), 0.02)))
		spots.append(mid)
		if i < cells.size() - 1:
			spots.append(here)
	_place(key, spots)


## A flight through the air from `from` to `to` (world points) as beads on layer `key`, rising in the middle by how far it
## goes: a leap's or a throw's path, so the player sees where it lands before choosing (Baldur's Gate 3's arcs).
func show_arc(key: String, from: Vector3, to: Vector3) -> void:
	var rise := minf(ARC_RISE_MOST, ARC_RISE * Vector2(to.x - from.x, to.z - from.z).length() + 0.3)
	var mm := (_layers[key] as MultiMeshInstance3D).multimesh
	mm.instance_count = ARC_BEADS
	for i in ARC_BEADS:
		var k := float(i + 1) / float(ARC_BEADS + 1)
		var p := from.lerp(to, k)
		p.y += rise * 4.0 * k * (1.0 - k)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))


func clear(key: String) -> void:
	_place(key, [])


func clear_all() -> void:
	for key: String in LAYERS:
		if key != "weapon":
			clear(key)
	clear_outline()


## Draws an area's edge on the floor: `outline` as CombatGrid.area_outline gives it (a circle, an emanation's rounded
## edge, a cone's or a box's corners), or when that's empty the outer edge of `cells` (a wall's squares).
func show_outline(outline: Dictionary, cells: Array = []) -> void:
	var shows: Variant = [outline, cells]
	if _outline.visible and shows == _outline_shows:
		return
	_outline_shows = shows
	var loops := outline_loops(outline, cells)
	if loops.is_empty():
		clear_outline()
		return
	_outline.mesh = _ribbon(loops)
	_outline.visible = true


func clear_outline() -> void:
	_outline.visible = false
	_outline.mesh = null
	_outline_shows = null


func is_showing_outline() -> bool:
	return _outline.visible


## The closed lines an outline is drawn along, on the floor's grid (x, z; a square is 1), each point at most
## OUTLINE_STEP from the next: the shape's edge, else the outer edges of `cells`.
static func outline_loops(outline: Dictionary, cells: Array = []) -> Array[PackedVector2Array]:
	var loops: Array[PackedVector2Array] = []
	if outline.has("circle"):
		var centre := outline["circle"] as Vector2
		var r := float(outline["radius"])
		if r > 0.0:
			var n := clampi(ceili(TAU * r / OUTLINE_STEP), 24, 720)
			var ring := PackedVector2Array()
			for i in n:
				ring.append(centre + Vector2.from_angle(TAU * i / n) * r)
			loops.append(ring)
	elif outline.has("rect"):
		# Everything within `radius` of a box of squares: its sides pushed out, joined by quarter circles round its corners.
		var box := outline["rect"] as Rect2
		var r := float(outline["radius"])
		var ring := PackedVector2Array()
		var corners := [box.end, Vector2(box.position.x, box.end.y), box.position, Vector2(box.end.x, box.position.y)]
		var arc := clampi(ceili(PI / 2.0 * r / OUTLINE_STEP), 1, 180)
		for k in 4:
			for i in arc + 1:
				ring.append((corners[k] as Vector2) + Vector2.from_angle(PI / 2.0 * (k + float(i) / arc)) * r)
		loops.append(_dense(ring))
	elif outline.has("points"):
		loops.append(_dense(outline["points"] as PackedVector2Array))
	elif not cells.is_empty():
		for loop in _cell_edges(cells):
			loops.append(_dense(loop))
	return loops


## A closed line with points added along its straight stretches, none longer than OUTLINE_STEP.
static func _dense(loop: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in loop.size():
		var a := loop[i]
		var b := loop[(i + 1) % loop.size()]
		if a.is_equal_approx(b):
			continue
		var steps := maxi(1, ceili(a.distance_to(b) / OUTLINE_STEP))
		for j in steps:
			out.append(a.lerp(b, float(j) / steps))
	return out


## The outer edges of a set of squares as closed lines round each patch (and round each hole in one).
static func _cell_edges(cells: Array) -> Array[PackedVector2Array]:
	var inside := {}
	for c: Vector2i in cells:
		inside[c] = true
	# Each edge with nothing on its far side, going round its square the same way: start corner -> end corners.
	var edges := {}
	var sides := [[Vector2i(0, -1), Vector2i(0, 0), Vector2i(1, 0)], [Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 1)],
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 1)], [Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, 0)]]
	for c: Vector2i in inside:
		for sd: Array in sides:
			if not inside.has(c + (sd[0] as Vector2i)):
				var from := c + (sd[1] as Vector2i)
				if not edges.has(from):
					edges[from] = []
				(edges[from] as Array).append(c + (sd[2] as Vector2i))
	var loops: Array[PackedVector2Array] = []
	while not edges.is_empty():
		var start: Vector2i = edges.keys()[0]
		var loop := PackedVector2Array()
		var at := start
		while edges.has(at):
			var outs := edges[at] as Array
			var to: Vector2i = outs.pop_back()
			if outs.is_empty():
				edges.erase(at)
			loop.append(Vector2(at))
			at = to
		if loop.size() >= 3:
			loops.append(loop)
	return loops


## A flat band OUTLINE["width"] wide along each closed line, lying on the floor (natural ground's slope, a low wall's
## top), with UV.y running across it for the shader's soft edges.
func _ribbon(loops: Array[PackedVector2Array]) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var index := PackedInt32Array()
	var half := float(OUTLINE["width"]) / 2.0
	var lift := float(OUTLINE["lift"]) + (SLOPE_LIFT if board.has_terrain() else 0.0)
	for loop in loops:
		var n := loop.size()
		var first := verts.size()
		for i in n:
			var p := loop[i]
			var to_prev := (p - loop[(i - 1 + n) % n]).normalized()
			var to_next := (loop[(i + 1) % n] - p).normalized()
			var n0 := Vector2(-to_prev.y, to_prev.x)
			var n1 := Vector2(-to_next.y, to_next.x)
			var mitre := (n0 + n1).normalized()
			if mitre == Vector2.ZERO:
				mitre = n1
			var reach := half / maxf(mitre.dot(n1), 1.0 / OUTLINE_MITRE)
			var y := _floor_at(p) + lift
			verts.append(Vector3(p.x - mitre.x * reach, y, p.y - mitre.y * reach))
			verts.append(Vector3(p.x + mitre.x * reach, y, p.y + mitre.y * reach))
			uvs.append(Vector2(float(i) / n, 0.0))
			uvs.append(Vector2(float(i) / n, 1.0))
			var a := first + i * 2
			var b := first + ((i + 1) % n) * 2
			index.append_array([a, a + 1, b + 1, a, b + 1, b])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The floor's height under a point of the grid (x, z), where a mark lies: the ground there, or a low wall's top.
func _floor_at(p: Vector2) -> float:
	var cell := Vector2i(floori(p.x), floori(p.y))
	var y := board.ground_y(p)
	if board.grid.in_bounds(cell) and board.grid.has_flag(cell, CombatGrid.LOW):
		y += ArenaBoard.LOW_H
	return y


## Where a mark sits on a square: its centre, on the floor or on top of a low wall.
func _spot(cell: Vector2i) -> Vector3:
	var y := board.cell_center(cell).y   # (on natural ground, its slope)
	if board.grid.has_flag(cell, CombatGrid.LOW):
		y += ArenaBoard.LOW_H
	return Vector3(cell.x + 0.5, y, cell.y + 0.5)


func _place(key: String, spots: Array[Vector3]) -> void:
	var mm := (_layers[key] as MultiMeshInstance3D).multimesh
	var lift := float((LAYERS[key] as Dictionary)["lift"])
	mm.instance_count = spots.size()
	var terrain := board.has_terrain()
	for i in spots.size():
		var basis := Basis.IDENTITY
		if terrain:
			# Lying along natural ground's slope, a little higher so its corners stay above the ground.
			basis = board.ground_basis(Vector2i(floori(spots[i].x), floori(spots[i].z)))
		var up := lift + (SLOPE_LIFT if basis != Basis.IDENTITY else 0.0)
		mm.set_instance_transform(i, Transform3D(basis, spots[i] + basis.y * up))
