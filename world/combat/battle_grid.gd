class_name BattleGrid
extends MeshInstance3D
## The battle grid (Ashwin 2026-10-19: "we don't need to draw our real world maps as a battle grid. It can look like a
## real natural map that we just overlay a grid on top afterwards", Natural Maps plan N1): the Modern look draws no grid
## in its ground; this lays thin lines over it where a creature can stand, only while they help. By default the player
## holds the Show the grid key (show_grid, B): the lines fade in round the creature whose turn it is (round the party's
## leader when exploring), fading out past its reach, and over the whole map in the tactical view (Ashwin 2026-10-19:
## "we don't need to show the grid in combat it is unnecessary ... maybe it could be a button the player holds"). The
## Battle grid setting (GameSettings) can show them on their own in fights, or in fights and when exploring, or never.
## The Classic look keeps its painted grid and has none of this.
##
## One mesh per board, made the first time it is wanted and kept with the board: every square a creature can stand in
## (not a wall, a tree, water or the void, nor a hidden room's) is a patch lying on the ground as it is drawn, the four
## triangles round its middle on natural ground (ArenaBoard.corner_height, so it follows slopes, cliffs and steps
## exactly) or a flat one, and the shader draws a line along the patch's border. Neighbouring patches each draw half of
## the line between them, so a crossing is one line deep, never two.

## How far above the ground the patches lie, so a creature's feet never swallow a line, and on natural ground, whose
## drawn skin bends between the squares' corners, as far as the marks (GridOverlay.SLOPE_LIFT); a line goes under them.
const LIFT := 0.012
const SLOPE_LIFT := 0.03
## How many squares from the creature the lines stay whole to, and how far past that they fade out. The reach is
## the creature's movement (a speed of 30 ft is 6 squares) plus two, at least 8 (Natural Maps plan: "about 8 squares").
const REACH_LEAST := 8.0
const REACH_MOST := 14.0
const REACH_FADE := 2.5
## How many squares the lines reach with the whole map showing (the tactical view).
const REACH_WHOLE := 400.0
## How fast the lines fade in and out, and how far they have come (0 hidden, 1 shown).
const FADE_TIME := 0.3
const SHADER := preload("res://shaders/fx/battle_grid.gdshader")
## Where a board keeps its patches: {"mesh": ArrayMesh, "cells": Dictionary, "hidden": int}.
const META := "battle_grid_patches"
const _CORNERS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]

var board: ArenaBoard
## The creature the lines gather round (a token, as the camera follows it), or null for the whole map.
var follow: Node3D = null
## The camera, which eases the lines out to the whole map as it goes into the tactical view.
var rig: CameraRig = null
## How far from `follow` the lines reach (squares), set from the creature's movement.
var reach := REACH_LEAST
## Whether this grid's host wants it shown on its own (a fight, with the setting at In fights or Always), and whether the
## host is live at all (a fight that is over, or exploring while a fight is on, shows nothing, even held).
var auto := false
var active := true
## The controller's way: the radial wheel's Grid wedge latches it on until it is picked again (CombatView).
var latched := false
## The controller action held to show it where the host has one (exploring: the names trigger, `explore_grid`).
var pad_action := &""
var _want := false
var _shown := 0.0
var _mat: ShaderMaterial
var _focus := Vector2.ZERO
var _recheck := 0.0


static func create(board_: ArenaBoard) -> BattleGrid:
	var g := BattleGrid.new()
	g.name = "BattleGrid"
	g.board = board_
	g.visible = false
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return g


## Whether a fight shows the grid without being asked: the Modern look, when the setting is In fights or Always.
static func auto_in_fights() -> bool:
	return Look.modern() and GameSettings.battle_grid() in ["fights", "always"]


## Whether exploring shows the grid without being asked: the Modern look, when the setting is Always.
static func auto_exploring() -> bool:
	return Look.modern() and GameSettings.battle_grid() == "always"


## Whether the player is holding the Show the grid key, with the setting letting them (never says no).
static func held() -> bool:
	return Look.modern() and GameSettings.battle_grid() != "never" and InputMap.has_action(&"show_grid") \
			and Input.is_action_pressed(&"show_grid")


## The squares a line is drawn in: where a creature can stand beside it, not a wall or a tree, water or the void, and
## not a square of a hidden room. `hidden` is HiddenAreas.hidden (cell -> true).
static func cells(board_: ArenaBoard, hidden: Dictionary = {}) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var g := board_.grid
	for z in g.depth:
		for x in g.width:
			var c := Vector2i(x, z)
			if (g.flags(c) & (CombatGrid.WALL | CombatGrid.VOID | CombatGrid.WATER)) == 0 and not hidden.has(c):
				out.append(c)
	return out


## The height of corner `k` (0 or 1 each way) of square `c`, where a line there lies: its natural ground's sloped
## corner, else the floor a creature stands on.
static func corner_y(board_: ArenaBoard, c: Vector2i, k: Vector2i) -> float:
	return board_.corner_height(c, k) if board_.has_terrain() and board_.grid.has_flag(c, CombatGrid.NATURAL) \
			else board_.grid.height(c) / float(CombatGrid.FEET)


## One patch per square of `list` as a mesh: UV runs 0..1 across each square (the shader reads its border from it), at
## the heights of corner_y plus LIFT; a natural square's top is four triangles round its middle, as the ground is
## drawn, a flat one two.
static func patches(board_: ArenaBoard, list: Array[Vector2i]) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var index := PackedInt32Array()
	var terrain := board_.has_terrain()
	for c in list:
		var natural := terrain and board_.grid.has_flag(c, CombatGrid.NATURAL)
		var first := verts.size()
		var total := 0.0
		var lift := SLOPE_LIFT if natural else LIFT
		for k in 4:
			var y := corner_y(board_, c, _CORNERS[k]) + lift
			total += y
			verts.append(Vector3(c.x + _CORNERS[k].x, y, c.y + _CORNERS[k].y))
			uvs.append(Vector2(_CORNERS[k]))
		if natural:
			verts.append(Vector3(c.x + 0.5, total / 4.0, c.y + 0.5))
			uvs.append(Vector2(0.5, 0.5))
			for k in 4:
				index.append_array([first + 4, first + k, first + (k + 1) % 4])
		else:
			index.append_array([first, first + 1, first + 2, first, first + 2, first + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	if not index.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The squares the lines were made over, once they are (for a test).
func drawn_cells() -> Array[Vector2i]:
	var kept := board.get_meta(META, {}) as Dictionary
	var out: Array[Vector2i] = []
	out.assign(kept.get("cells", []) as Array)
	return out


## The host shows the grid on its own (or stops): a fight with the setting at In fights, exploring at Always.
func set_auto(on: bool) -> void:
	auto = on


## The host is live (or not): a fight that is over, or exploring while a fight is on, shows no grid, held or not.
func set_active(on: bool) -> void:
	active = on


## Whether the grid is wanted now: its host is live and either asks for it or the key is held.
func is_wanted() -> bool:
	return _want


## How much of the grid shows (0 hidden, 1 whole strength).
func shown() -> float:
	return _shown


## The lines gather round `who` and reach as far as a creature with `speed_ft` of movement.
func gather(who: Node3D, speed_ft: int = 0) -> void:
	follow = who
	reach = clampf(float(speed_ft) / float(CombatGrid.FEET) + 2.0, REACH_LEAST, REACH_MOST)
	_aim()


func _ensure() -> void:
	var hid := _hidden()
	var kept := board.get_meta(META, {}) as Dictionary
	if not kept.has("mesh") or int(kept["hidden"]) != hid.size():
		var list := cells(board, hid)
		kept = {"mesh": patches(board, list), "cells": list, "hidden": hid.size()}
		board.set_meta(META, kept)
	if mesh != kept["mesh"]:
		mesh = kept["mesh"] as ArrayMesh
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
		_mat.render_priority = 4   # (under the marks, which are 5)
		material_override = _mat


## The squares of the place's hidden rooms (secret doors nobody has found), which show no line.
func _hidden() -> Dictionary:
	var view := board.get_parent() as LocationView
	var h := HiddenAreas.of(view) if view != null else null
	return h.hidden if h != null else {}


func _process(delta: float) -> void:
	var asked := auto or held() or latched or (pad_action != &"" and InputMap.has_action(pad_action) and Input.is_action_pressed(pad_action))
	var want := active and Look.modern() and GameSettings.battle_grid() != "never" and asked
	if want and not _want:
		_ensure()   # (made over the board's squares the first time it is wanted, and kept with the board)
		visible = true
	_want = want
	_shown = move_toward(_shown, 1.0 if _want else 0.0, delta / FADE_TIME)
	if _shown <= 0.0 and not _want:
		visible = false
		return
	_recheck -= delta
	if _recheck <= 0.0:
		_recheck = 0.5
		if _want:
			_ensure()   # (a secret door found since: its room's squares get lines)
	_aim()
	if _mat != null:
		_mat.set_shader_parameter("shown", _shown)


## Points the lines' fade at what they gather round: the creature (the whole map in the tactical view, as the
## camera eases into it), or the whole map when there is none.
func _aim() -> void:
	if _mat == null:
		return
	if follow != null and is_instance_valid(follow):
		_focus = Vector2(follow.global_position.x, follow.global_position.z)
	var whole := follow == null or not is_instance_valid(follow)
	var k := 1.0 if whole else (smoothstep(0.0, 1.0, rig.tactical_shown) if rig != null else 0.0)
	var far := lerpf(reach, REACH_WHOLE, k)
	_mat.set_shader_parameter("focus", _focus)
	_mat.set_shader_parameter("reach_in", maxf(far - REACH_FADE, 0.0))
	_mat.set_shader_parameter("reach_out", far)
