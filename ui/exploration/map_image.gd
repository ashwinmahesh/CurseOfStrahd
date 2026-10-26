class_name MapImage
extends RefCounted
## A location drawn from its grid as one image, the picture both the minimap (ui/exploration/minimap.gd) and the area map
## (ui/screens/area_map.gd, the map screen's "This area") are made of. Pure drawing: it reads the grid, the colours and
## the squares to leave out, and changes nothing.

## Texture pixels per square (drawn smaller than this, so it stays sharp).
const PX := 16


## The colours a location's map is drawn in: by the kind of place (Minimap.colours_for), and a place's own water (its
## mood's water `map` and `map_edge`: Tser Pool is black, not lake blue, owner report 2026-10-08).
static func colours(v: LocationView) -> Dictionary:
	var c := Minimap.colours_for(ArenaBoard.theme_for(v.loc["map"] as Dictionary))
	var water := (v.atmosphere.mood.get("water", {}) as Dictionary) if v.atmosphere != null else {}
	if water.has("map"):
		c["water"] = Look.color(str(water["map"]))
	if water.has("map_edge"):
		c["water_edge"] = Look.color(str(water["map_edge"]))
	return c


## The location as an image, PX pixels a square: ground, walls or trees with an inked edge where they meet open
## ground, low cover, rough ground and water. Mipmapped, so it shrinks cleanly.
static func render(grid: CombatGrid, colours: Dictionary, hidden: Dictionary, view: LocationView = null) -> Image:
	var w := grid.width
	var d := grid.depth
	var img := Image.create(w * PX, d * PX, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for z in d:
		for x in w:
			var c := Vector2i(x, z)
			if hidden.has(c):
				continue
			var f := grid.flags(c)
			var col := Color(0, 0, 0, 0)
			if (f & CombatGrid.WATER) != 0:
				col = colours["water"]
			elif (f & CombatGrid.VOID) != 0:
				continue
			elif (f & CombatGrid.WALL) != 0:
				col = colours["wall"]
			elif (f & CombatGrid.LOW) != 0:
				col = colours["low"]
			elif (f & CombatGrid.DIFFICULT) != 0:
				col = colours["rough"]
			elif grid.height(c) > 0:
				col = colours["raised"]
			else:
				col = colours["floor"]
			img.fill_rect(Rect2i(x * PX, z * PX, PX, PX), col)
	var line := 3
	for z in d:
		for x in w:
			var c := Vector2i(x, z)
			if hidden.has(c):
				continue
			var solid := grid.has_flag(c, CombatGrid.WALL)
			var wet := grid.has_flag(c, CombatGrid.WATER)
			if not solid and not wet:
				continue
			var edge: Color = colours["edge"] if solid else colours["water_edge"]
			for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := c + dir
				if not grid.in_bounds(n) or grid.has_flag(n, CombatGrid.WALL | CombatGrid.VOID) or hidden.has(n):
					continue
				var r := Rect2i(x * PX, z * PX, PX, PX)
				if dir.x > 0:
					r = Rect2i(x * PX + PX - line, z * PX, line, PX)
				elif dir.x < 0:
					r = Rect2i(x * PX, z * PX, line, PX)
				elif dir.y > 0:
					r = Rect2i(x * PX, z * PX + PX - line, PX, line)
				else:
					r = Rect2i(x * PX, z * PX, PX, line)
				img.fill_rect(r, edge)
	_paint_landmarks(img, hidden, view)
	img.generate_mipmaps()
	return img


## Big pieces drawn on the map in their own colours over the squares they stand on (catalog "map_marks", lane 28,
## owner report 2026-10-08: Madam Eva's tent was a tiny thing on the map): the great tent a patched round of crimson
## and gold, wagons and tents their painted colours. Each from its footprint as the board stood it (ModelPiece).
static func _paint_landmarks(img: Image, hidden: Dictionary, view: LocationView) -> void:
	if view == null or not is_instance_valid(view) or view.board == null:
		return
	var marks := SetDressing.catalog().get("map_marks", {}) as Dictionary
	for f: Variant in view.board.get_meta("big_feet", []):
		var foot := f as Array
		var mark := marks.get(str(foot[2]) if foot.size() > 2 else "", {}) as Dictionary
		if mark.is_empty() or hidden.has(foot[0] as Vector2i):
			continue
		var r := foot[1] as Rect2
		var trim := r.size * (1.0 - float(mark.get("scale", 1.0))) / 2.0   # the footprint less its guy ropes and stakes
		r = r.grow_individual(-trim.x, -trim.y, -trim.x, -trim.y)
		var fill := Look.color(str(mark.get("fill", "umber")))
		var rim := Look.color(str(mark.get("rim", "ink")))
		var round_ := str(mark.get("shape", "")) == "round"
		var stripes: Array[Color] = []
		for name: Variant in mark.get("stripes", []):
			stripes.append(Look.color(str(name)))
		var x0 := maxi(0, floori(r.position.x * PX))
		var y0 := maxi(0, floori(r.position.y * PX))
		var x1 := mini(img.get_width() - 1, ceili(r.end.x * PX))
		var y1 := mini(img.get_height() - 1, ceili(r.end.y * PX))
		var c := r.get_center() * PX
		var half := r.size * PX / 2.0
		var edge := 1.0 - 2.5 / minf(half.x, half.y)   # a rim about two and a half pixels wide
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var u := (float(x) + 0.5 - c.x) / half.x
				var v := (float(y) + 0.5 - c.y) / half.y
				var d := Vector2(u, v).length() if round_ else maxf(absf(u), absf(v))
				if d > 1.0:
					continue
				var col := fill
				if not stripes.is_empty():
					# A tent's panels: alternating colours round its middle, like the canvas seen from above.
					col = stripes[int((atan2(v, u) + PI) / TAU * 12.0) % stripes.size()]
				img.set_pixel(x, y, rim if d > edge else col)
