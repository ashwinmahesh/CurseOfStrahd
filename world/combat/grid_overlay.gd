class_name GridOverlay
extends Node3D
## Squares painted on the combat floor: where the active creature can move, the path it would take, an area of
## effect template, valid targets, and the cursor. One flat quad per square per layer, drawn just above the floor.

const LAYERS := {
	"reach": {"colour": "moon_blue", "alpha": 0.35, "lift": 0.012, "size": 0.92},
	"dash": {"colour": "night", "alpha": 0.3, "lift": 0.011, "size": 0.92},
	"path": {"colour": "wick", "alpha": 0.75, "lift": 0.02, "size": 0.34},
	"area": {"colour": "candle", "alpha": 0.5, "lift": 0.016, "size": 0.96},
	"danger": {"colour": "crimson", "alpha": 0.45, "lift": 0.017, "size": 0.96},
	"target": {"colour": "vampire_red", "alpha": 0.55, "lift": 0.018, "size": 0.98},
	"friendly": {"colour": "flame", "alpha": 0.5, "lift": 0.018, "size": 0.98},
	"cursor": {"colour": "ivory", "alpha": 0.4, "lift": 0.022, "size": 1.0},
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
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var pm := PlaneMesh.new()
	pm.size = Vector2(float(spec["size"]), float(spec["size"]))
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
	var mmi := _layers[key] as MultiMeshInstance3D
	var mm := mmi.multimesh
	var lift := float((LAYERS[key] as Dictionary)["lift"])
	mm.instance_count = cells.size()
	for i in cells.size():
		var cell: Vector2i = cells[i]
		var y := board.floor_y(cell) + lift
		if board.grid.has_flag(cell, CombatGrid.LOW):
			y += ArenaBoard.LOW_H
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(cell.x + 0.5, y, cell.y + 0.5)))


func clear(key: String) -> void:
	show_cells(key, [])


func clear_all() -> void:
	for key: String in LAYERS:
		if key != "weapon":
			clear(key)
