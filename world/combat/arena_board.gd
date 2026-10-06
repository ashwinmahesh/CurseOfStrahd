class_name ArenaBoard
extends Node3D
## The 3D dressing of a combat map (ADR 0007): built from the same CombatGrid the rules use, so what you see is
## what the rules see. Cell (x, z) covers world x..x+1, z..z+1; a floor raised 5 ft sits one unit higher.
##   '.' flagstones and grass   '~' brambles and mud (Difficult Terrain)   '=' gravestones / a low wall (Half Cover)
##   '#' standing stones, shrine pillars and the yard's outer wall (block movement and sight)   '1'-'4' the dais
## Placeholder geometry in the palette (plan §4.1 cel look) until Phase 3 builds real sets.

const WALL_H := 1.8
const OUTER_H := 1.4
const LOW_H := 0.75

var grid: CombatGrid
var _rng := RandomNumberGenerator.new()


static func build(grid_: CombatGrid) -> ArenaBoard:
	var b := ArenaBoard.new()
	b.name = "ArenaBoard"
	b.grid = grid_
	b._rng.seed = 7   # cosmetic only (dressing placement), never rules
	b._build()
	return b


func floor_y(cell: Vector2i) -> float:
	return grid.height(cell) / float(CombatGrid.FEET)


func cell_center(cell: Vector2i, size_cells: int = 1) -> Vector3:
	return grid.world_center(cell, size_cells)


func _build() -> void:
	var grass := Look.cel_checker("bog", "bog_deep", "ink")
	var stone := Look.cel_checker("stone", "stone_deep", "ink")
	var mud := Look.cel_checker("umber", "peat", "ink")
	var dais := Look.cel_checker("slate", "stone", "ink")
	for z in grid.depth:
		for x in grid.width:
			var c := Vector2i(x, z)
			var f := grid.flags(c)
			if (f & CombatGrid.VOID) != 0:
				continue
			var h := floor_y(c)
			if (f & CombatGrid.WALL) != 0:
				_wall(c)
				continue
			var mat: Material = grass
			if (f & CombatGrid.DIFFICULT) != 0:
				mat = mud
			elif h > 0.0:
				mat = dais
			elif (x + z * 3) % 7 < 3:
				mat = stone
			_box("Floor", Vector3(1, 0.2 + h, 1), Vector3(x + 0.5, (h - 0.2) / 2.0, z + 0.5), mat)
			if (f & CombatGrid.DIFFICULT) != 0:
				_brambles(c)
			if (f & CombatGrid.LOW) != 0:
				_low_cover(c)
	_lanterns()


func _wall(c: Vector2i) -> void:
	var border := c.x == 0 or c.y == 0 or c.x == grid.width - 1 or c.y == grid.depth - 1
	if border:
		# The churchyard's outer wall: low, mossy, uneven.
		var h := OUTER_H + _rng.randf_range(-0.25, 0.15)
		_box("OuterWall", Vector3(1, h, 1), Vector3(c.x + 0.5, h / 2.0, c.y + 0.5), Look.cel("slate"))
		if _rng.randf() < 0.3:
			_box("Moss", Vector3(1.02, 0.12, 1.02), Vector3(c.x + 0.5, h - 0.05, c.y + 0.5), Look.cel("moss"))
	else:
		# Shrine pillars and standing stones.
		_box("Pillar", Vector3(0.9, WALL_H, 0.9), Vector3(c.x + 0.5, WALL_H / 2.0, c.y + 0.5), Look.cel("pewter"))
		_box("PillarCap", Vector3(1.0, 0.18, 1.0), Vector3(c.x + 0.5, WALL_H + 0.09, c.y + 0.5), Look.cel("slate"))


func _low_cover(c: Vector2i) -> void:
	var left := grid.has_flag(c + Vector2i(-1, 0), CombatGrid.LOW)
	var right := grid.has_flag(c + Vector2i(1, 0), CombatGrid.LOW)
	var up := grid.has_flag(c + Vector2i(0, -1), CombatGrid.LOW)
	var down := grid.has_flag(c + Vector2i(0, 1), CombatGrid.LOW)
	var base := floor_y(c)
	if left or right:
		# A run of low wall along x.
		_box("LowWall", Vector3(1.0, LOW_H, 0.45), Vector3(c.x + 0.5, base + LOW_H / 2.0, c.y + 0.5), Look.cel("bone_dark"))
	elif up or down:
		_box("LowWall", Vector3(0.45, LOW_H, 1.0), Vector3(c.x + 0.5, base + LOW_H / 2.0, c.y + 0.5), Look.cel("bone_dark"))
	else:
		# A leaning gravestone with a plinth.
		_box("Plinth", Vector3(0.8, 0.18, 0.5), Vector3(c.x + 0.5, base + 0.09, c.y + 0.5), Look.cel("stone"))
		var stone := _box("Gravestone", Vector3(0.6, 0.85, 0.18), Vector3(c.x + 0.5, base + 0.6, c.y + 0.5), Look.cel("pewter"))
		stone.rotation.z = _rng.randf_range(-0.12, 0.12)


func _brambles(c: Vector2i) -> void:
	for i in 3:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.07
		cm.height = _rng.randf_range(0.25, 0.45)
		mi.mesh = cm
		mi.position = Vector3(c.x + _rng.randf_range(0.2, 0.8), floor_y(c) + cm.height / 2.0, c.y + _rng.randf_range(0.2, 0.8))
		mi.rotation = Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4))
		mi.material_override = Look.cel("moss" if i % 2 == 0 else "bog")
		add_child(mi)


## Lanterns on a few pillars so the yard reads at dusk.
func _lanterns() -> void:
	var placed := 0
	for z in grid.depth:
		for x in grid.width:
			var c := Vector2i(x, z)
			var border := x == 0 or z == 0 or x == grid.width - 1 or z == grid.depth - 1
			if grid.has_flag(c, CombatGrid.WALL) and not border and placed < 4 and (x + z) % 2 == 0:
				var light := CandleFlicker.new()
				light.light_color = Look.color("candle")
				light.omni_range = 7.0
				light.base_energy = 2.2
				light.position = Vector3(x + 0.5, WALL_H + 0.5, z + 0.5)
				add_child(light)
				var flame := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.09
				sm.height = 0.18
				flame.mesh = sm
				flame.position = Vector3(x + 0.5, WALL_H + 0.3, z + 0.5)
				var fm := Look.cel("wick")
				fm.set_shader_parameter("emission", Look.color("flame") * 2.0)
				flame.material_override = fm
				add_child(flame)
				placed += 1


func _box(n: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi
