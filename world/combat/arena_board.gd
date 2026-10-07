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
## The top of a cut-away interior wall (and a door's lintel indoors).
const CUT_FACE := "grave"

var grid: CombatGrid
var place := ""
## shrine_yard (the arena), svalich_road / forest (trees), village (houses), manor, tavern, shop, townhouse, church,
## attic (cut-away interiors), dungeon.
var theme := "shrine_yard"
var _rng := RandomNumberGenerator.new()


## `place_` is the location's id: art/sprites/props/catalog.json can dress one place's squares its own way
## (the Wizard of Wines' '=' rows are vines).
static func build(grid_: CombatGrid, theme_: String = "shrine_yard", place_: String = "") -> ArenaBoard:
	var b := ArenaBoard.new()
	b.name = "ArenaBoard"
	b.grid = grid_
	b.theme = theme_
	b.place = place_
	b._look = (SetDressing.catalog().get("place_looks", {}) as Dictionary).get(place_, {}) as Dictionary
	b._rng.seed = 7   # cosmetic only (dressing placement), never rules
	b._build()
	return b


func floor_y(cell: Vector2i) -> float:
	return grid.height(cell) / float(CombatGrid.FEET)


func cell_center(cell: Vector2i, size_cells: int = 1) -> Vector3:
	return grid.world_center(cell, size_cells)


const INTERIORS := ["manor", "tavern", "shop", "townhouse", "church", "attic", "inn", "house", "tent"]
const WILD := ["svalich_road", "forest", "road", "camp", "tser_pool", "riverside", "wilderness"]   ## (camp: wagons too)
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
	# A place can have its own ground (catalog "floors"): grass on Bonegrinder's hill, though it's built like a town.
	var own := str((SetDressing.catalog().get("floors", {}) as Dictionary).get(place, ""))
	if own != "":
		floor_s = own
	floor_s = str(_look.get("floor", floor_s))
	if floor_s != "":
		_floor_tex = Look.cel_textured(floor_s, 0.22)
	var mud := str(_look.get("difficult", Look.theme_surface(t, "difficult")))
	if mud != "":
		_mud_tex = Look.cel_textured(mud, 0.22)
	var wall := str(_look.get("wall", Look.theme_surface(t, "wall")))
	if wall != "":
		_wall_tex = Look.cel_textured(wall)
	if str(_look.get("rock_walls", "")) != "":
		_rock_tex = Look.cel_textured(str(_look["rock_walls"]))
	var roof := Look.theme_surface(t, "roof")
	if roof != "":
		_roof_tex = Look.cel_textured(roof)
	var roof_alt := Look.theme_surface(t, "roof_alt")
	if roof_alt != "":
		_roof_alt = Look.cel_textured(roof_alt)
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
	if theme == "camp":
		_find_wagons()
	if theme != "shrine_yard":
		_load_textures()
		# Raised ground: grassy banks outdoors (hills, ledges, a gallows mound), stone in churches and dungeons,
		# boards in towns and rooms.
		var raised := "village/grass" if theme in WILD else ("church/stone_flags" if theme == "church" else ("dungeon/stone_floor" if theme == "dungeon" else "interior/wood_planks"))
		var raised_mat := Look.cel_textured(raised, 0.22)
		if raised_mat != null:
			dais = raised_mat
		if _floor_tex != null:
			grass = _floor_tex
			stone = _floor_tex
		if _mud_tex != null:
			mud = _mud_tex
	else:
		# The shrine yard (the arena, and open-air yards such as the Abbey's garden): grass and flagstones, a mud
		# patch, stone walls and pillars.
		var yard_grass := Look.cel_textured("village/grass", 0.22)
		var yard_flags := Look.cel_textured("church/stone_flags", 0.22)
		var yard_mud := Look.cel_textured("village/mud_road", 0.22)
		if yard_grass != null and yard_flags != null:
			grass = yard_grass
			stone = yard_grass
			dais = yard_flags
			_floor_tex = yard_grass
		if yard_mud != null:
			mud = yard_mud
		_wall_tex = Look.cel_textured("church/stone_wall")
		_roof_tex = Look.cel_textured("village/roof_slate")
		if _look.has("floor") and Look.cel_textured(str(_look["floor"]), 0.22) != null:
			grass = Look.cel_textured(str(_look["floor"]), 0.22)
			stone = grass
			_floor_tex = grass
		if str(_look.get("rock_walls", "")) != "":
			_rock_tex = Look.cel_textured(str(_look["rock_walls"]))
	_floor_mat = grass
	if place != "" and Compendium.shared().has("locations", place):
		SetDressing.reserve(self, Compendium.shared().get_entry("locations", place))
		_plan_rooms(Compendium.shared().get_entry("locations", place))
	if theme in TOWNS:
		_yard = TownBuilder.plan(self)
	elif theme == "shrine_yard" and place != "":
		TownBuilder.plan(self)   # a yard's sheds and shrines are buildings; lone stones stay pillars
	for z in grid.depth:
		for x in grid.width:
			var c := Vector2i(x, z)
			var f := grid.flags(c)
			if (f & CombatGrid.WATER) != 0:
				_water(c)
				continue
			if (f & CombatGrid.VOID) != 0:
				continue
			var h := floor_y(c)
			if (f & CombatGrid.WALL) != 0:
				var first := get_child_count()
				_wall(c)
				if not _has_ground.has(c):
					_dress(c, first)
				continue
			var mat: Material = grass
			if (f & CombatGrid.DIFFICULT) != 0:
				mat = mud
			elif h > 0.0:
				mat = dais
			elif (x + z * 3) % 7 < 3:
				mat = stone
			var room := _room_at(c)
			if room.has("floor") and (f & CombatGrid.DIFFICULT) == 0 and h <= 0.0:
				mat = room["floor"] as Material
			_floors[c] = _box("Floor", Vector3(1, 0.2 + h, 1), Vector3(x + 0.5, (h - 0.2) / 2.0, z + 0.5), mat)
			var dressed := get_child_count()
			if (f & CombatGrid.DIFFICULT) != 0:
				_brambles(c)
			if (f & CombatGrid.LOW) != 0:
				_low_cover(c)
			_dress(c, dressed)
	if theme == "shrine_yard" and place == "":
		_lanterns()   # the arena's lit pillars


## Tall billboards (trees) that fade when they stand between the camera and the party.
var occluders: Array[Sprite3D] = []
## 3D trees (ModelPiece) that fade the same way.
var mesh_occluders: Array[Node3D] = []
var _faded_for: Array = []           ## fade_occluders' camera, focus and counts once every tree had settled
## The scenery the board put on each square (a tree, a wall block, furniture on a '=' square, brambles), so a
## location's own prop can take the square's place (SetDressing): cell -> Array of nodes. Ground boxes aren't in it.
var dressing: Dictionary = {}
## Squares holding a door (SetDressing.door): not wall for hanging pictures or picking a wall's direction.
var door_cells: Dictionary = {}
## Squares a location's things stand on (SetDressing.reserve), and wall faces with a piece hung on them.
var occupied: Dictionary = {}
var used_faces: Dictionary = {}
var _floor_mat: Material = null
## This place's own look (catalog "place_looks": the Amber Temple's black stone, Mount Baratok's snow and cliffs) and
## its rooms' surfaces (catalog "rooms", matched on the location's area names: a bathroom's tiles, a kitchen's flags).
var _look: Dictionary = {}
var _rooms: Array[Dictionary] = []     ## [{rect: Rect2i, floor: Material, wall: Material}]
var _rock_tex: Material = null
## The location's areas as rectangles (a wall piece hangs on the side facing its own area).
var areas: Array[Rect2i] = []
## Towns (TownBuilder): the houses ({root, walls, upper, aabb ...}), which house each square belongs to, the window
## pieces by "x,y,dx,dy" (a door hung there hides its window), and the squares of low yard wall.
var buildings: Array[Dictionary] = []
var house_cells: Dictionary = {}
var windows: Dictionary = {}
var _yard: Dictionary = {}
var _roof_alt: Material = null
var _has_ground: Dictionary = {}     ## wall squares with a ground box of their own (trees)
var _cleared: Dictionary = {}        ## cell -> the floor box put under a wall square a prop took
var _floors: Dictionary = {}         ## cell -> its floor box (a stairwell down opens it)
var _wagon_cells := {}      ## camp: '#' blocks inside the map are wagons, cell -> the block's center
var _wagon_drawn := {}


## In a camp, small blocks of '#' away from the map's edge are the Vistani's wagons.
func _find_wagons() -> void:
	var seen := {}
	for z in grid.depth:
		for x in grid.width:
			var start := Vector2i(x, z)
			if seen.has(start) or not grid.has_flag(start, CombatGrid.WALL) or _on_border(start):
				continue
			var block: Array[Vector2i] = []
			var open: Array[Vector2i] = [start]
			seen[start] = true
			while not open.is_empty():
				var c: Vector2i = open.pop_back()
				block.append(c)
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n := c + d
					if not seen.has(n) and grid.in_bounds(n) and grid.has_flag(n, CombatGrid.WALL) and not _on_border(n):
						seen[n] = true
						open.append(n)
			if block.size() > 24:
				continue
			var sum := Vector2.ZERO
			for c in block:
				sum += Vector2(c)
			var center := sum / float(block.size())
			for c in block:
				_wagon_cells[c] = center


func _on_border(c: Vector2i) -> bool:
	return c.x == 0 or c.y == 0 or c.x == grid.width - 1 or c.y == grid.depth - 1


## Matches each of the location's areas to a room style (catalog "rooms": words in its name -> floor and wall).
func _plan_rooms(loc: Dictionary) -> void:
	var rules: Array = []
	for a: Variant in loc.get("areas", []):
		var area := a as Dictionary
		var name_ := ("%s %s" % [str(area.get("name", "")), str(area.get("id", "")).replace("_", " ")]).to_lower()
		var cells0 := area.get("cells", []) as Array
		var q0 := Vector2i(int(cells0[0][0]), int(cells0[0][1]))
		var q1 := Vector2i(int(cells0[1][0]), int(cells0[1][1]))
		areas.append(Rect2i(Vector2i(mini(q0.x, q1.x), mini(q0.y, q1.y)), (q1 - q0).abs() + Vector2i.ONE))
		# Room rules are for rooms; an outdoor map has its own few (a jetty is planks), so a fishing "landing" isn't
		# floored like a manor's.
		var key := "rooms" if theme in INTERIORS or theme == "dungeon" else "outdoor_rooms"
		if area.has("floor") or area.has("walls"):
			# The data names this room's own surfaces (an area's `floor` and `walls`).
			rules = [[[name_], {"floor": area.get("floor", ""), "wall": area.get("walls", "")}]] + (SetDressing.catalog().get(key, []) as Array)
		else:
			rules = SetDressing.catalog().get(key, []) as Array
		for rule: Variant in rules:
			var hit := false
			for w: String in (rule as Array)[0]:
				hit = hit or name_.contains(w)
			if not hit:
				continue
			var style := (rule as Array)[1] as Dictionary
			var cells := area.get("cells", []) as Array
			var p0 := Vector2i(int(cells[0][0]), int(cells[0][1]))
			var p1 := Vector2i(int(cells[1][0]), int(cells[1][1]))
			var r := Rect2i(Vector2i(mini(p0.x, p1.x), mini(p0.y, p1.y)), (p1 - p0).abs() + Vector2i.ONE)
			var room := {"rect": r}
			if str(style.get("floor", "")) != "" and Look.cel_textured(str(style["floor"]), 0.22) != null:
				room["floor"] = Look.cel_textured(str(style["floor"]), 0.22)
			if str(style.get("wall", "")) != "" and Look.cel_textured(str(style["wall"])) != null:
				room["wall"] = Look.cel_textured(str(style["wall"]))
			_rooms.append(room)
			break


## The styled room a square is in ({} if none). Smaller rooms win where areas overlap.
func _room_at(c: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	for r: Dictionary in _rooms:
		var rect := r["rect"] as Rect2i
		if rect.has_point(c) and (best.is_empty() or rect.get_area() < (best["rect"] as Rect2i).get_area()):
			best = r
	return best


## The room a wall square belongs to, from the open squares beside it (the faces the camera sees first).
func _wall_room(c: Vector2i) -> Dictionary:
	for d in SetDressing.FACES:
		var n := c + d
		if grid.in_bounds(n) and not grid.has_flag(n, CombatGrid.WALL) and not grid.has_flag(n, CombatGrid.VOID):
			var r := _room_at(n)
			if r.has("wall"):
				return r
	return {}


## Rock instead of trees (catalog place_looks "rock_walls"): a craggy column of cliff on each wall square, taller at
## the map's edge, so mountains and caves are walled by rock.
func _rock(c: Vector2i) -> void:
	_box("Ground", Vector3(1, 0.2, 1), Vector3(c.x + 0.5, -0.1, c.y + 0.5), _floor_mat)
	_has_ground[c] = true
	var first := get_child_count()
	var h := (3.2 if _on_border(c) else 2.2) + _rng.randf_range(-0.6, 0.6)
	var w := _rng.randf_range(0.95, 1.08)
	var rock := _box("Rock", Vector3(w, h, w), Vector3(c.x + 0.5, h / 2.0, c.y + 0.5), _rock_tex)
	rock.rotation.y = _rng.randf_range(-0.12, 0.12)
	_dress(c, first)


## A town house's walls.
func house_wall_material() -> Material:
	return _wall_tex if _wall_tex != null else Look.cel("bone_dark")


## A town roof: slate for the grander houses where the town has both, else its usual roof.
func roof_material(grand: bool) -> Material:
	if grand and _roof_alt != null:
		return _roof_alt
	return _roof_tex if _roof_tex != null else Look.cel("blood_deep")


## A piece hung on a house's wall goes with the house when it's cut away (TownBuilder.cut_away).
func attach_to_building(c: Vector2i, node: Node3D) -> void:
	if house_cells.has(c):
		((buildings[int(house_cells[c])] as Dictionary)["extras"] as Array).append(node)


## Hides the house on `c` (a piece standing in for the whole building takes its place); returns its ground centre.
## Every house built from the same block of wall squares (an L-shaped block is several houses).
func hide_building(c: Vector2i) -> Vector3:
	var group := int((buildings[int(house_cells[c])] as Dictionary)["group"])
	var area := Rect2i()
	for b: Dictionary in buildings:
		if int(b["group"]) != group:
			continue
		_show_house(b, false)
		area = b["rect"] as Rect2i if area.size == Vector2i.ZERO else area.merge(b["rect"] as Rect2i)
	return Vector3(area.position.x + area.size.x / 2.0, 0.0, area.position.y + area.size.y / 2.0)


func show_building(c: Vector2i) -> void:
	if not house_cells.has(c):
		return
	var group := int((buildings[int(house_cells[c])] as Dictionary)["group"])
	for b: Dictionary in buildings:
		if int(b["group"]) == group:
			_show_house(b, true)


func _show_house(b: Dictionary, shown: bool) -> void:
	b["hidden"] = not shown
	(b["root"] as Node3D).visible = shown
	# Ground where the house stood while something else stands there.
	var r := b["rect"] as Rect2i
	for i in r.size.x:
		for j in r.size.y:
			var c := r.position + Vector2i(i, j)
			if not shown and not _cleared.has(c):
				_cleared[c] = _box("Floor", Vector3(1, 0.2, 1), Vector3(c.x + 0.5, -0.1, c.y + 0.5), _floor_mat)
			elif shown and _cleared.has(c):
				(_cleared[c] as Node).queue_free()
				_cleared.erase(c)
	for e: Variant in b["extras"]:
		if is_instance_valid(e):
			(e as Node3D).visible = shown


## Cuts away the houses hiding the party (towns only).
func cut_buildings(camera_pos: Vector3, focus: Vector3, delta: float) -> void:
	if not buildings.is_empty():
		TownBuilder.cut_away(self, camera_pos, focus, delta)


func add_box(n: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	return _box(n, size, pos, mat)


## Records the nodes added since child index `from` as square `c`'s scenery.
func _dress(c: Vector2i, from: int) -> void:
	if from >= get_child_count():
		return
	var nodes: Array = dressing.get(c, [])
	for i in range(from, get_child_count()):
		nodes.append(get_child(i))
	dressing[c] = nodes


## Hides the board's scenery on a square while a location's prop stands there; a wall square gets floor under it.
func clear_cell(c: Vector2i) -> void:
	for n: Node3D in dressing.get(c, []):
		n.visible = false
	if grid.has_flag(c, CombatGrid.WALL) and not _has_ground.has(c) and not _cleared.has(c):
		var h := floor_y(c)
		_cleared[c] = _box("Floor", Vector3(1, 0.2 + h, 1), Vector3(c.x + 0.5, (h - 0.2) / 2.0, c.y + 0.5), _floor_mat)


## A stairwell down opens the floor of its square (and shows it again when it goes).
func hide_floor(c: Vector2i) -> void:
	for d: Dictionary in [_floors, _cleared]:
		if d.has(c) and is_instance_valid(d[c]):
			(d[c] as Node3D).visible = false


func show_floor(c: Vector2i) -> void:
	for d: Dictionary in [_floors, _cleared]:
		if d.has(c) and is_instance_valid(d[c]):
			(d[c] as Node3D).visible = true


## A wall square drawn as a tree or a rock column (it has ground of its own under it).
func is_tree(c: Vector2i) -> bool:
	return grid.in_bounds(c) and _has_ground.has(c) and dressing.has(c) and not _wagon_cells.has(c)


## Puts a square's scenery back (its prop is gone).
func restore_cell(c: Vector2i) -> void:
	for n: Node3D in dressing.get(c, []):
		n.visible = true
	if _cleared.has(c):
		(_cleared[c] as Node).queue_free()
		_cleared.erase(c)


## What the walls of this board are made of (door frames and secret doors match it); a town's yard walls are stone.
func wall_material() -> Material:
	if theme in TOWNS:
		var stone := Look.cel_textured(TownBuilder.STONE)
		return stone if stone != null else Look.cel("stone")
	if _wall_tex != null and theme not in WILD:
		return _wall_tex
	var colour := {"manor": "umber", "tavern": "walnut", "shop": "walnut", "townhouse": "umber", "church": "slate",
		"attic": "peat", "dungeon": "stone_deep"}.get(theme, "walnut") as String
	return Look.cel(colour)


## A Vistani wagon: a low painted body on each of its squares, and the wagon's picture once, at its middle.
func _wagon(c: Vector2i) -> void:
	var center := _wagon_cells[c] as Vector2
	var key := "%.1f,%.1f" % [center.x, center.y]
	if not SetDressing.has_art("vardo"):
		_box("WagonBed", Vector3(1, 0.9, 1), Vector3(c.x + 0.5, 0.45, c.y + 0.5), Look.cel("walnut"))
		if not _wagon_drawn.has(key):
			_wagon_drawn[key] = true
			prop_sprite("wagon", Vector3(center.x + 0.5, 0.9, center.y + 0.5), 1.3)
		return
	# A painted vardo standing on the ground over its block of squares (sized to the block).
	_box("Ground", Vector3(1, 0.2, 1), Vector3(c.x + 0.5, -0.1, c.y + 0.5), _floor_mat)
	_has_ground[c] = true
	if not _wagon_drawn.has(key):
		_wagon_drawn[key] = true
		var cells := 0
		for k: Vector2i in _wagon_cells:
			if (_wagon_cells[k] as Vector2).is_equal_approx(center):
				cells += 1
		var first := get_child_count()
		SetDressing.stand_piece(self, self, "vardo", c, clampf(sqrt(cells / 6.0), 0.75, 1.3), Vector3(center.x + 0.5, 0.0, center.y + 0.5))
		_dress(c, first)


## Deep water: a dark surface a little below the floor.
func _water(c: Vector2i) -> void:
	var m: Material = Look.cel_textured("wild/water")
	if m == null:
		m = Look.cel_checker("night", "night_deep", "night_deep")
	_box("Water", Vector3(1, 0.1, 1), Vector3(c.x + 0.5, -0.18, c.y + 0.5), m)


func _wall(c: Vector2i) -> void:
	if theme == "camp" and _wagon_cells.has(c):
		_wagon(c)
		return
	if _rock_tex != null and not house_cells.has(c) and (theme in WILD or theme == "shrine_yard" or theme in TOWNS and _on_border(c)):
		_rock(c)
		return
	if theme in WILD:
		_tree(c)
		return
	if theme in INTERIORS or theme == "dungeon":
		# A lone wall square in a room is a pillar in the place's style (BuildingKit, docs/art/building_kit.md).
		var room := _room_at(c)
		if BuildingKit.pillar(self, c, room["floor"] as Material if room.has("floor") else _floor_mat):
			return
		# Cut-away walls (low enough to see over from the camera), capped with a darker band.
		var colour := {"manor": "umber", "tavern": "walnut", "shop": "walnut", "townhouse": "umber", "church": "slate",
			"attic": "peat"}.get(theme, "stone_deep") as String
		var h := 1.15
		var room_wall := _wall_room(c)
		var wall_mat: Material = room_wall["wall"] as Material if room_wall.has("wall") else (_wall_tex if _wall_tex != null else Look.cel(colour))
		_box("Wall", Vector3(1, h, 1), Vector3(c.x + 0.5, h / 2.0, c.y + 0.5), wall_mat)
		# The cut face reads as the dark inside of the wall, so rooms stand out of the dark rather than out of a slab.
		_box("WallCap", Vector3(1.02, 0.1, 1.02), Vector3(c.x + 0.5, h + 0.05, c.y + 0.5), Look.cel(CUT_FACE))
		ModelPiece.dress_wall(self, c, wall_mat)   # 3D panelling where this place uses the models (docs/art/models.md)
		return
	if theme in TOWNS:
		var border := c.x == 0 or c.y == 0 or c.x == grid.width - 1 or c.y == grid.depth - 1
		if border and theme == "village":
			_tree(c)   # the village thins into forest at the map's edge
			return
		if border and _outer_tex != null:
			# A town's palisade: the building kit's logs (docs/art/building_kit.md), else a textured box.
			if TownBuilder.palisade(self, c, _floor_mat):
				return
			var ph := 2.2
			_box("Palisade", Vector3(1, ph, 1), Vector3(c.x + 0.5, ph / 2.0, c.y + 0.5), _outer_tex)
			return
		if house_cells.has(c):
			return   # part of a house TownBuilder built whole
		if _yard.has(c):
			TownBuilder.yard_wall(self, c, wall_material())
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
	if house_cells.has(c):
		return   # a yard's shed or shrine, built whole by TownBuilder
	var border := c.x == 0 or c.y == 0 or c.x == grid.width - 1 or c.y == grid.depth - 1
	if border:
		# The churchyard's outer wall: low, mossy, uneven.
		var h := OUTER_H + _rng.randf_range(-0.25, 0.15)
		_box("OuterWall", Vector3(1, h, 1), Vector3(c.x + 0.5, h / 2.0, c.y + 0.5), _wall_tex if _wall_tex != null else Look.cel("slate"))
		if _rng.randf() < 0.3:
			_box("Moss", Vector3(1.02, 0.12, 1.02), Vector3(c.x + 0.5, h - 0.05, c.y + 0.5), Look.cel("moss"))
	else:
		# Shrine pillars and standing stones.
		_box("Pillar", Vector3(0.9, WALL_H, 0.9), Vector3(c.x + 0.5, WALL_H / 2.0, c.y + 0.5), _wall_tex if _wall_tex != null else Look.cel("pewter"))
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
	var at := Vector3(c.x + 0.5 + _rng.randf_range(-0.12, 0.12), 0.0, c.y + 0.5 + _rng.randf_range(-0.12, 0.12))
	var size := _rng.randf_range(0.5, 0.7)
	_box("Ground", Vector3(1, 0.2, 1), Vector3(c.x + 0.5, -0.1, c.y + 0.5), _floor_tex if _floor_tex != null else Look.cel("bog_deep"))
	_has_ground[c] = true
	var first := get_child_count()
	var pick := ModelPiece.hash_cell(c)
	var tree3d := ModelPiece.tree(self, kind, at, size, pick, float(pick % 360) * PI / 180.0)
	if tree3d != null:
		add_child(tree3d)   # a 3D tree (docs/art/models.md) where the 2D one would stand, as tall
		mesh_occluders.append(tree3d)
		_dress(c, first)
		return
	var tree := prop_sprite(kind, at, size)
	if tree != null:
		occluders.append(tree)
		_dress(c, first)
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
	_dress(c, first)


## Which set in art/sprites/props/catalog.json dresses this board's '=' and '~' squares.
func _dressing_key() -> String:
	if theme in WILD:
		return "wild"
	if theme in TOWNS:
		return "town"
	return theme


## The run of '=' squares through `c` (4-connected): {size, by_wall}. A long run indoors is one long piece of
## furniture (a bar, a row of pews, a dining table), so all of it takes the same art.
var _runs: Dictionary = {}


func _low_run(c: Vector2i) -> Dictionary:
	if _runs.has(c):
		return _runs[c] as Dictionary
	var seen := {c: true}
	var open: Array[Vector2i] = [c]
	var by_wall := false
	while not open.is_empty():
		var at: Vector2i = open.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := at + d
			if not grid.in_bounds(n):
				continue
			if grid.has_flag(n, CombatGrid.WALL):
				by_wall = true
			elif grid.has_flag(n, CombatGrid.LOW) and not seen.has(n):
				seen[n] = true
				open.append(n)
	var run := {"size": seen.size(), "by_wall": by_wall}
	for k: Vector2i in seen:
		_runs[k] = run
	return run


func _low_cover(c: Vector2i) -> void:
	var sets := SetDressing.catalog().get("low_cover", {}) as Dictionary
	var key := place if place != "" and sets.has(place) else _dressing_key()
	var choices := sets.get(key, []) as Array
	if theme in INTERIORS or theme == "dungeon" or key == place:
		var run := _low_run(c)
		if int(run["size"]) >= 3:
			choices = sets.get(key + ("_wall_run" if bool(run["by_wall"]) and sets.has(key + "_wall_run") else "_run"), choices) as Array
	if not choices.is_empty():
		# Crates and carts in town, stumps and boulders in the woods, a room's furniture indoors.
		# The first choice (from the square's position) that fits the room around it: a wagon only where there's
		# space for a wagon.
		var room := SetDressing.room_at(self, c)
		var start := (c.x * 7 + c.y * 3) % choices.size()
		var pick := str(choices[start])
		for k in choices.size():
			var cand := str(choices[(start + k) % choices.size()])
			if SetDressing.has_art(cand) and SetDressing.footprint(cand) <= room * 1.05:
				pick = cand
				break
		if SetDressing.has_art(pick):
			# Fixed in place and turned like the location's own props (against a wall, or facing south).
			SetDressing.stand_piece(self, self, pick, c)
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
	var low_mat: Material = _wall_tex if _wall_tex != null else Look.cel("bone_dark")
	if left or right:
		# A run of low wall along x.
		_box("LowWall", Vector3(1.0, LOW_H, 0.45), Vector3(c.x + 0.5, base + LOW_H / 2.0, c.y + 0.5), low_mat)
	elif up or down:
		_box("LowWall", Vector3(0.45, LOW_H, 1.0), Vector3(c.x + 0.5, base + LOW_H / 2.0, c.y + 0.5), low_mat)
	elif ModelPiece.for_art(self, "gravestone") != "":
		ModelPiece.stand(self, self, ModelPiece.for_art(self, "gravestone"), "gravestone", c, null, _rng.randf_range(0.9, 1.1))
	elif prop_sprite("gravestone", Vector3(c.x + 0.5, base, c.y + 0.5), _rng.randf_range(0.9, 1.1)) != null:
		pass
	else:
		# A leaning gravestone with a plinth.
		_box("Plinth", Vector3(0.8, 0.18, 0.5), Vector3(c.x + 0.5, base + 0.09, c.y + 0.5), Look.cel("stone"))
		var stone := _box("Gravestone", Vector3(0.6, 0.85, 0.18), Vector3(c.x + 0.5, base + 0.6, c.y + 0.5), Look.cel("pewter"))
		stone.rotation.z = _rng.randf_range(-0.12, 0.12)


## Difficult terrain: brambles in the woods, rubble underground and indoors (catalog "difficult"); a town's mud
## is its texture alone. Elsewhere (the arena) a few thorny cones.
func _brambles(c: Vector2i) -> void:
	var sets := SetDressing.catalog().get("difficult", {}) as Dictionary
	var key := place if sets.has(place) else (_dressing_key() if theme in WILD or theme == "dungeon" else ("interior" if theme in INTERIORS else theme))
	var choices := sets.get(key, []) as Array
	if not choices.is_empty():
		var pick := str(choices[(c.x * 5 + c.y * 11) % choices.size()])
		if SetDressing.has_art(pick):
			var at := Vector3(c.x + 0.5 + _rng.randf_range(-0.15, 0.15), floor_y(c), c.y + 0.5 + _rng.randf_range(-0.15, 0.15))
			var model := ModelPiece.for_art(self, pick, ModelPiece.hash_cell(c))
			if model != "":
				ModelPiece.stand(self, self, model, pick, c, at, _rng.randf_range(0.85, 1.15)).set_meta("ground_cover", true)
				return
			if str((SetDressing.manifest()[pick] as Dictionary).get("mount", "stand")) == "floor":
				var flat := SetDressing.flat_sprite(pick)
				flat.position = at + Vector3(0, SetDressing.WALL_GAP, 0)
				flat.rotation.y = _rng.randf_range(0.0, TAU)
				add_child(flat)
			else:
				var bush := prop_sprite(pick, at, _rng.randf_range(0.85, 1.15))
				if bush != null:
					bush.set_meta("ground_cover", true)   # brambles may grow into each other
			return
	if theme in TOWNS:
		return
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


## Fades the trees standing between the camera and `focus` (the party's leader), and brings back the rest.
func fade_occluders(camera_pos: Vector3, focus: Vector3, delta: float) -> void:
	# Once every tree has reached its fade, nothing changes until the camera or the party moves (or trees come and
	# go): the walk over every tree each frame is skipped while the view stands still.
	var key := [camera_pos, focus, occluders.size(), mesh_occluders.size()]
	if key == _faded_for:
		return
	var changing := false
	var to_cam := Vector2(camera_pos.x - focus.x, camera_pos.z - focus.z).normalized()
	for t in occluders:
		var rel := Vector2(t.position.x - focus.x, t.position.z - focus.z)
		var between := rel.length() < 4.0 and rel.normalized().dot(to_cam) > 0.35
		var target := 0.28 if between else 1.0
		var a := move_toward(t.modulate.a, target, delta * 4.0)
		changing = changing or not is_equal_approx(a, target)
		if not is_equal_approx(a, t.modulate.a):
			t.modulate.a = a
			# The texture's own alpha always counts (switching `transparent` off drew the whole quad: the black box
			# behind trees). A fading tree is blended, and drawn after the screen pass like the characters; at the
			# screen pass's own priority it sorted before it now and then and was painted over (trees flickering).
			var fading := a < 0.999
			t.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED if fading else SpriteBase3D.ALPHA_CUT_DISCARD
			t.render_priority = DirectionalSprite.RENDER_PRIORITY if fading else 0
	for t in mesh_occluders:
		if not is_instance_valid(t):
			continue
		var rel := Vector2(t.global_position.x - focus.x, t.global_position.z - focus.z)
		var between := rel.length() < 4.0 and rel.normalized().dot(to_cam) > 0.35
		var was := float(t.get_meta("fade", 0.0))
		var goal := 0.72 if between else 0.0
		var f := move_toward(was, goal, delta * 4.0)
		changing = changing or not is_equal_approx(f, goal)
		if not is_equal_approx(f, was):
			t.set_meta("fade", f)
			ModelPiece.set_fade(t, f)
	_faded_for = [] if changing else key
