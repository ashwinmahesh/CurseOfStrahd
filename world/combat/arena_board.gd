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
## shrine_yard (the arena), svalich_road / forest (trees), village (houses), manor, tavern, shop, townhouse, church,
## attic (cut-away interiors), dungeon.
var theme := "shrine_yard"
var _rng := RandomNumberGenerator.new()


static func build(grid_: CombatGrid, theme_: String = "shrine_yard") -> ArenaBoard:
	var b := ArenaBoard.new()
	b.name = "ArenaBoard"
	b.grid = grid_
	b.theme = theme_
	b._rng.seed = 7   # cosmetic only (dressing placement), never rules
	b._build()
	return b


func floor_y(cell: Vector2i) -> float:
	return grid.height(cell) / float(CombatGrid.FEET)


func cell_center(cell: Vector2i, size_cells: int = 1) -> Vector3:
	return grid.world_center(cell, size_cells)


const INTERIORS := ["manor", "tavern", "shop", "townhouse", "church", "attic", "inn", "house", "tent"]
const WILD := ["svalich_road", "forest", "road", "camp", "tser_pool", "riverside", "wilderness"]
const TOWNS := ["village", "vallaki", "town"]
const PROPS_JSON := "res://art/sprites/props/manifest.json"
static var _props: Dictionary = {}

## Textured surfaces for this theme (art/textures, docs/art/textures.md); null where the theme has none.
var _floor_tex: Material = null
var _mud_tex: Material = null
var _wall_tex: Material = null
var _roof_tex: Material = null
var _outer_tex: Material = null


## A board theme for a location: its map theme, or by whether it's outdoors for themes the board doesn't know.
static func theme_for(map: Dictionary) -> String:
	var t := str(map.get("theme", ""))
	if t in INTERIORS or t in WILD or t in TOWNS or t in ["dungeon", "shrine_yard"]:
		return t
	return "svalich_road" if bool(map.get("outdoors", false)) else "manor"


func _surface_theme() -> String:
	if theme in WILD:
		return "village"
	if theme in ["inn"]:
		return "tavern"
	if theme in ["house", "tent"]:
		return "townhouse"
	if theme == "town":
		return "vallaki"
	return theme


func _load_textures() -> void:
	var t := _surface_theme()
	var floor_s := Look.theme_surface(t, "floor")
	if theme in TOWNS and Look.theme_surface(t, "floor_alt") != "" and theme != "vallaki":
		floor_s = Look.theme_surface(t, "floor_alt")   # the village's streets are cobbled
	if theme in WILD:
		floor_s = "village/grass"
	if floor_s != "":
		_floor_tex = Look.cel_textured(floor_s, 0.22)
	var mud := Look.theme_surface(t, "difficult")
	if mud != "":
		_mud_tex = Look.cel_textured(mud, 0.22)
	var wall := Look.theme_surface(t, "wall")
	if wall != "":
		_wall_tex = Look.cel_textured(wall)
	var roof := Look.theme_surface(t, "roof")
	if roof != "":
		_roof_tex = Look.cel_textured(roof)
	var outer := Look.theme_surface(t, "outer")
	if outer != "":
		_outer_tex = Look.cel_textured(outer)


func _build() -> void:
	var grass := Look.cel_checker("bog", "bog_deep", "ink")
	var stone := Look.cel_checker("stone", "stone_deep", "ink")
	var mud := Look.cel_checker("umber", "peat", "ink")
	var dais := Look.cel_checker("slate", "stone", "ink")
	if theme in INTERIORS:
		grass = Look.cel_checker("walnut", "umber", "peat") if theme != "church" else Look.cel_checker("stone", "slate", "stone_deep")
		stone = grass
		if theme == "attic":
			grass = Look.cel_checker("umber", "peat", "ink")
			stone = grass
		mud = Look.cel_checker("bone_dark", "umber", "peat")
	elif theme == "dungeon":
		grass = Look.cel_checker("stone_deep", "grave", "ink")
		stone = Look.cel_checker("stone", "stone_deep", "ink")
		mud = Look.cel_checker("bog_deep", "peat", "ink")
	elif theme in TOWNS:
		stone = Look.cel_checker("stone", "slate", "stone_deep")
	if theme != "shrine_yard":
		_load_textures()
		if _floor_tex != null:
			grass = _floor_tex
			stone = _floor_tex
		if _mud_tex != null:
			mud = _mud_tex
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
	if theme == "shrine_yard":
		_lanterns()


func _wall(c: Vector2i) -> void:
	if theme in WILD:
		_tree(c)
		return
	if theme in INTERIORS or theme == "dungeon":
		# Cut-away walls (low enough to see over from the camera), capped with a darker band.
		var colour := {"manor": "umber", "tavern": "walnut", "shop": "walnut", "townhouse": "umber", "church": "slate",
			"attic": "peat"}.get(theme, "stone_deep") as String
		var h := 1.15
		_box("Wall", Vector3(1, h, 1), Vector3(c.x + 0.5, h / 2.0, c.y + 0.5), _wall_tex if _wall_tex != null else Look.cel(colour))
		_box("WallCap", Vector3(1.02, 0.1, 1.02), Vector3(c.x + 0.5, h + 0.05, c.y + 0.5), Look.cel("bone_dark"))
		return
	if theme in TOWNS:
		var border := c.x == 0 or c.y == 0 or c.x == grid.width - 1 or c.y == grid.depth - 1
		if border and _outer_tex != null:
			# A town's palisade.
			var ph := 2.2
			_box("Palisade", Vector3(1, ph, 1), Vector3(c.x + 0.5, ph / 2.0, c.y + 0.5), _outer_tex)
			return
		# Houses: plaster-and-timber walls under slate or thatch.
		var hh := 2.0
		if _wall_tex != null:
			_box("House", Vector3(1, hh, 1), Vector3(c.x + 0.5, hh / 2.0, c.y + 0.5), _wall_tex)
		else:
			_box("House", Vector3(1, hh, 1), Vector3(c.x + 0.5, hh / 2.0, c.y + 0.5), Look.cel("bone_dark"))
			_box("Timber", Vector3(1.02, 0.16, 1.02), Vector3(c.x + 0.5, hh * 0.55, c.y + 0.5), Look.cel("peat"))
		_box("Roof", Vector3(1.08, 0.24, 1.08), Vector3(c.x + 0.5, hh + 0.12, c.y + 0.5), _roof_tex if _roof_tex != null else Look.cel("blood_deep"))
		return
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


## A billboard prop from art/sprites/props (manifest: pixel_size, height): standing on `at`, facing the camera.
func prop_sprite(id: String, at: Vector3, scale_: float = 1.0) -> Sprite3D:
	if _props.is_empty() and FileAccess.file_exists(PROPS_JSON):
		_props = (JSON.parse_string(FileAccess.get_file_as_string(PROPS_JSON)) as Dictionary).get("props", {}) as Dictionary
	var info := _props.get(id, {}) as Dictionary
	var path := "res://" + str(info.get("file", ""))
	if info.is_empty() or not ResourceLoader.exists(path):
		return null
	var sp := Sprite3D.new()
	sp.texture = load(path) as Texture2D
	sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sp.shaded = true
	sp.pixel_size = float(info.get("pixel_size", 0.01)) * scale_
	sp.offset = Vector2(0, float(info.get("height_px", 256)) / 2.0)
	sp.position = at
	add_child(sp)
	return sp


## A Barovian pine (or a dead tree): a billboard where the art exists, else a dark trunk and a cone of needles.
func _tree(c: Vector2i) -> void:
	var kind := "dead_tree" if _rng.randf() < 0.22 else "pine"
	if prop_sprite(kind, Vector3(c.x + 0.5 + _rng.randf_range(-0.12, 0.12), 0.0, c.y + 0.5 + _rng.randf_range(-0.12, 0.12)),
			_rng.randf_range(0.5, 0.7)) != null:
		_box("Ground", Vector3(1, 0.2, 1), Vector3(c.x + 0.5, -0.1, c.y + 0.5), _floor_tex if _floor_tex != null else Look.cel("bog_deep"))
		return
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.1
	tm.bottom_radius = 0.16
	tm.height = 0.8
	trunk.mesh = tm
	trunk.position = Vector3(c.x + 0.5, 0.4, c.y + 0.5)
	trunk.material_override = Look.cel("peat")
	add_child(trunk)
	var crown := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = _rng.randf_range(0.5, 0.65)
	cm.height = _rng.randf_range(1.8, 2.6)
	crown.mesh = cm
	crown.position = Vector3(c.x + 0.5 + _rng.randf_range(-0.1, 0.1), 0.7 + cm.height / 2.0, c.y + 0.5 + _rng.randf_range(-0.1, 0.1))
	crown.material_override = Look.cel("bog_deep" if _rng.randf() < 0.6 else "bog")
	add_child(crown)
	_box("Ground", Vector3(1, 0.2, 1), Vector3(c.x + 0.5, -0.1, c.y + 0.5), Look.cel("bog_deep"))


func _low_cover(c: Vector2i) -> void:
	var base0 := floor_y(c)
	var at := Vector3(c.x + 0.5, base0, c.y + 0.5)
	if theme in TOWNS or theme in WILD:
		# Crates, barrels, carts and stalls (billboards where the art exists).
		var pick := ["crate", "barrel", "barrel", "wagon", "market_stall"][(c.x * 7 + c.y * 3) % 5] as String if theme in TOWNS \
			else ["crate", "barrel", "dead_tree"][(c.x * 7 + c.y * 3) % 3] as String
		if prop_sprite(pick, at, 0.8 if pick in ["wagon", "market_stall"] else 1.0) != null:
			return
	if theme in INTERIORS and theme != "church":
		var sets := {"tavern": ["table", "table", "table", "barrel"], "inn": ["table", "table", "bed", "barrel"],
			"shop": ["crate", "barrel", "bookshelf", "table"], "attic": ["crate", "bed", "barrel", "crate"],
			"townhouse": ["table", "bed", "bookshelf", "table"], "house": ["table", "bed", "barrel", "table"],
			"tent": ["crate", "barrel", "table", "crate"]}
		var choices := sets.get(theme, ["table", "table", "bed", "bookshelf"]) as Array
		var furn := str(choices[(c.x * 5 + c.y * 3) % choices.size()])
		if prop_sprite(furn, at) != null:
			return
	if theme in INTERIORS:
		# Furniture: a table, a bed, a pew.
		var base := floor_y(c)
		_box("Furniture", Vector3(0.92, 0.6, 0.92), Vector3(c.x + 0.5, base + 0.3, c.y + 0.5), Look.cel("leather" if theme != "church" else "walnut"))
		return
	if theme == "dungeon":
		_box("Rubble", Vector3(0.85, 0.55, 0.85), Vector3(c.x + 0.5, floor_y(c) + 0.27, c.y + 0.5), Look.cel("stone"))
		return
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
