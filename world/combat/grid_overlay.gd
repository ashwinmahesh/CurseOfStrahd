class_name GridOverlay
extends Node3D
## Marks painted on the combat floor, only while they answer something the player is pointing at (owner 2026-10-06:
## the always-lit blue squares of where a creature could move were noise). Hovering the floor shows a dotted trail to
## a ring where the creature would stop, red when the walk provokes; aiming shows an area template and who can be
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
}

var board: ArenaBoard
var _layers: Dictionary = {}


static func create(board_: ArenaBoard) -> GridOverlay:
	var o := GridOverlay.new()
	o.name = "GridOverlay"
	o.board = board_
	for key: String in LAYERS:
		o._make_layer(key)
	return o


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
		spots.append(mid)
		if i < cells.size() - 1:
			spots.append(here)
	_place(key, spots)


func clear(key: String) -> void:
	_place(key, [])


func clear_all() -> void:
	for key: String in LAYERS:
		if key != "weapon":
			clear(key)


## Where a mark sits on a square: its centre, on the floor or on top of a low wall.
func _spot(cell: Vector2i) -> Vector3:
	var y := board.floor_y(cell)
	if board.grid.has_flag(cell, CombatGrid.LOW):
		y += ArenaBoard.LOW_H
	return Vector3(cell.x + 0.5, y, cell.y + 0.5)


func _place(key: String, spots: Array[Vector3]) -> void:
	var mm := (_layers[key] as MultiMeshInstance3D).multimesh
	var lift := float((LAYERS[key] as Dictionary)["lift"])
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, spots[i] + Vector3(0, lift, 0)))
