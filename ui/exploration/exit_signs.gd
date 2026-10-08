class_name ExitSigns
extends Control
## Ways out of a location shown over the world (part of the exploration HUD, under its panels): every road or path
## to another region gets a glowing square at the way out, chevrons on the ground leading to it, and a plaque naming
## where it goes, drawn in screen space over whatever stands there so it stays sharp and the palette pass never
## touches it. A way that's shut for now (its `when` doesn't hold) is drawn dim. Doors into buildings are left to the
## hover hint and the minimap.

var view: LocationView
var signs: Array[Dictionary] = []
var _time := 0.0
## The HUD's panels showing now (the Narrator's box, the last roll, the command bar): a plaque that would sit on one
## is lifted above it, since the panels are see-through and a plaque read through them muddles both (ExploreHud sets it).
var keep_clear: Array[Rect2] = []
## Where each plaque was drawn last, for tests.
var plaque_rects: Array[Rect2] = []


func _init() -> void:
	name = "ExitSigns"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_location(v: LocationView) -> void:
	view = v
	signs.assign(ways_out(v).filter(func(e: Dictionary) -> bool: return bool(e["region"])))
	queue_redraw()


## Every way out of a location: {id, cell, label, to, destination, region, open, dir}. `region` is a road to another
## outdoor place or onto the travel map (as opposed to a door into a building); `dir` points out of the map there, or
## is zero for a way out inside the map (a garden gate), which gets no arrows.
static func ways_out(v: LocationView) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var outdoors := bool((v.loc["map"] as Dictionary).get("outdoors", false))
	for ex: Variant in v.loc.get("exits", []):
		var e := ex as Dictionary
		var to := str(e["to"])
		var dest := {} if to == "travel" else Compendium.shared().get_entry("locations", to)
		var region := to == "travel" or (outdoors and bool((dest.get("map", {}) as Dictionary).get("outdoors", false)))
		var a := e["cell"] as Array
		var cell := Vector2i(int(a[0]), int(a[1]))
		out.append({"id": str(e["id"]), "cell": cell, "label": str(e.get("label", "Leave")), "to": to,
			"destination": "Opens the travel map" if to == "travel" else str(dest.get("name", "")), "region": region,
			"open": StoryConditions.check(str(e.get("when", "")), v.st), "dir": outward(v.grid, cell) if on_edge(v.grid, cell) else Vector2i.ZERO})
	return out


static func on_edge(grid: CombatGrid, cell: Vector2i) -> bool:
	return cell.x == 0 or cell.y == 0 or cell.x == grid.width - 1 or cell.y == grid.depth - 1


## The way out of the map at a square: straight off the nearest edge.
static func outward(grid: CombatGrid, cell: Vector2i) -> Vector2i:
	var gaps := [cell.x, grid.width - 1 - cell.x, cell.y, grid.depth - 1 - cell.y]
	var dirs: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	var best := 0
	for i in 4:
		if int(gaps[i]) < int(gaps[best]):
			best = i
	return dirs[best]


func _process(delta: float) -> void:
	_time += delta
	if not signs.is_empty() and is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	plaque_rects.clear()
	if view == null or not is_instance_valid(view) or view.rig == null or view.in_combat:
		return
	var cam := view.rig.camera
	# Marks on the ground are drawn over everything, so they stay off squares where the party stands.
	var stood := {}
	for m in view.members:
		stood[m.cell] = true
	for e in signs:
		var cell := e["cell"] as Vector2i
		if HiddenAreas.hides(view, cell):
			continue   # a way out of a room nobody has found yet
		var dir := e["dir"] as Vector2i
		var open := bool(e["open"])
		var y := view.board.floor_y(cell) + 0.04
		var glow := Look.color("gilt_light") if open else Look.color("pewter")
		var pulse := 0.5 + 0.5 * sin(_time * 2.6)
		# The square itself.
		var sq := _ground_poly(cam, [Vector2(cell.x, cell.y), Vector2(cell.x + 1, cell.y), Vector2(cell.x + 1, cell.y + 1),
			Vector2(cell.x, cell.y + 1)], y)
		if sq.size() == 4:
			if not stood.has(cell):
				draw_colored_polygon(sq, Color(glow, (0.2 + 0.18 * pulse) if open else 0.16))
			var ring := sq.duplicate()
			ring.append(sq[0])
			draw_polyline(ring, Color(glow, 0.95), 2.5, true)
		# Chevrons on the open ground leading to it, marching outward.
		if open and dir != Vector2i.ZERO:
			for k in range(3, 0, -1):
				var c := cell - dir * k
				if not view.grid.in_bounds(c) or view.grid.has_flag(c, CombatGrid.WALL | CombatGrid.VOID) or stood.has(c):
					continue
				var a := fposmod(_time * 1.4 - k * 0.33, 1.0)
				_chevron(cam, Vector2(c) + Vector2(0.5, 0.5), Vector2(dir), view.board.floor_y(c) + 0.04, Color(glow, 0.3 + 0.6 * a))
		_plaque(cam, e, Vector3(cell.x + 0.5, y + 1.7, cell.y + 0.5), Vector3(dir.x, 0, dir.y), glow)


## Ground points (world x, z) on the screen, lying on the ground (lay_on_ground); empty if any is behind the camera,
## or the shape is seen edge-on and has nothing to draw.
func _ground_poly(cam: Camera3D, pts: Array, y: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for w: Vector3 in lay_on_ground(view.board, pts, y):
		if cam.is_position_behind(w):
			return PackedVector2Array()
		out.append(cam.unproject_position(w))
	if absf(area(out)) < 1.0:
		return PackedVector2Array()
	return out


## A flat shape's points (world x, z) laid on the ground, 0.04 above it: on natural ground on the plane of its slope at
## the shape's middle (ArenaBoard.ground_normal), so the shape stays flat and can't fold over itself on screen the way
## one with each point at its own height can on a steep slope; elsewhere at height `y`.
static func lay_on_ground(board: ArenaBoard, pts: Array, y: float) -> Array[Vector3]:
	var mid := Vector2.ZERO
	for p: Vector2 in pts:
		mid += p
	mid /= float(maxi(pts.size(), 1))
	var up := Vector3.UP
	var y0 := y
	if board.has_terrain():
		up = board.ground_normal(Vector2i(floori(mid.x), floori(mid.y)))
		y0 = board.ground_y(mid) + 0.04
	var out: Array[Vector3] = []
	for p: Vector2 in pts:
		var d := p - mid
		out.append(Vector3(p.x, y0 - (up.x * d.x + up.z * d.y) / up.y, p.y))
	return out


## The signed area of a polygon on the screen (0 when it's seen edge-on).
static func area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var q := poly[(i + 1) % poly.size()]
		a += poly[i].x * q.y - q.x * poly[i].y
	return a / 2.0


func _chevron(cam: Camera3D, centre: Vector2, dir: Vector2, y: float, colour: Color) -> void:
	var pts := _ground_poly(cam, chevron_points(centre, dir), y)
	if pts.size() == 6:
		draw_colored_polygon(pts, colour)


## The chevron's outline on the ground (world x, z) round a square's middle, pointing along `dir`.
static func chevron_points(centre: Vector2, dir: Vector2) -> Array:
	var side := dir.orthogonal() * 0.27
	var tip := centre + dir * 0.3
	var back := centre - dir * 0.2
	var thick := dir * 0.14
	return [back + side, tip, back - side, back - side - thick, tip - thick, back + side - thick]


## A crimson-black plaque above the way out: where it goes, with an arrow pointing out of the map. When the way out
## is off the screen (and open), the plaque waits at the edge of the play area instead, its arrow pointing toward it.
func _plaque(cam: Camera3D, e: Dictionary, at: Vector3, out_dir: Vector3, glow: Color) -> void:
	var screen := get_viewport_rect()
	var behind := cam.is_position_behind(at)
	var p := cam.unproject_position(at) if not behind else Vector2(-1e6, -1e6)
	var on_screen := not behind and screen.grow(-20.0).has_point(p)
	if not on_screen and not bool(e["open"]):
		return
	var font := UiKit.display_font()
	var title := str(e["label"])
	var sub := str(e["destination"])
	if sub != "" and title.to_lower().contains(sub.to_lower()):
		sub = ""
	if not bool(e["open"]):
		sub = "Not yet" if sub == "" else "%s · not yet" % sub
	# Off the screen the plaque is a size smaller.
	var big := 18 if on_screen else 16
	var small := 13 if on_screen else 12
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, big)
	var sw := ThemeDB.fallback_font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, small) if sub != "" else Vector2.ZERO
	var box := Vector2(maxf(tw.x, sw.x) + 44.0, tw.y + (sw.y + 2.0 if sub != "" else 0.0) + 10.0)
	var d := Vector2.RIGHT
	var r := Rect2()
	if on_screen:
		var shown := p.clamp(screen.position + Vector2(box.x / 2.0 + 12.0, box.y + 12.0), screen.end - Vector2(box.x / 2.0 + 12.0, 12.0))
		r = _clear_of_panels(Rect2(shown - Vector2(box.x / 2.0, box.y), box))
		# The arrow points the way out as the camera sees it (down at the square for a way out inside the map).
		var ahead := cam.unproject_position(at + out_dir) - p
		d = ahead.normalized() if out_dir != Vector3.ZERO and ahead.length() > 0.01 else Vector2.DOWN
		# A thin stem down to the square.
		draw_line(Vector2(shown.x, r.end.y), cam.unproject_position(at - Vector3(0, 1.6, 0)), Color(glow, 0.6), 1.5, true)
	else:
		d = (p - screen.get_center()).normalized() if not behind else _toward(Vector2(at.x, at.z))
		r = _clear_of_panels(Rect2(_edge_spot(d, box) - box / 2.0, box))
	plaque_rects.append(r)
	draw_rect(r.grow(2.0), Color(Look.color("void"), 0.45), true)
	draw_rect(r, Color(Look.color("ui_black"), 0.9 if on_screen else 0.8), true)
	draw_rect(r, glow, false, 1.5)
	draw_string(font, r.position + Vector2(30, 5 + font.get_ascent(big)), title, HORIZONTAL_ALIGNMENT_LEFT, -1, big,
		Look.color("gilt_light") if bool(e["open"]) else Look.color("silver"))
	if sub != "":
		draw_string(ThemeDB.fallback_font, r.position + Vector2(30, 7 + tw.y + ThemeDB.fallback_font.get_ascent(small)), sub,
			HORIZONTAL_ALIGNMENT_LEFT, -1, small, Look.color("vellum"))
	var c := r.position + Vector2(16, box.y / 2.0)
	draw_colored_polygon(PackedVector2Array([c + d * 8.0, c - d * 6.0 + d.orthogonal() * 6.0, c - d * 3.0,
		c - d * 6.0 - d.orthogonal() * 6.0]), glow)


## A plaque's box lifted above any HUD panel it would sit on (keep_clear), never off the top of the screen.
func _clear_of_panels(r: Rect2) -> Rect2:
	for _pass in 2:   # lifted off one panel onto another (the roll above the Narrator's box) moves again
		for panel in keep_clear:
			if r.intersects(panel.grow(4.0)):
				r.position.y = maxf(12.0, panel.position.y - 8.0 - r.size.y)
	return r


## The screen direction of a ground point from where the camera looks (works behind the camera too).
func _toward(ground: Vector2) -> Vector2:
	var basis := view.rig.ground_basis()
	var off := Vector3(ground.x, 0, ground.y) - view.rig.global_position
	off.y = 0.0
	var d := Vector2(off.dot(basis[1]), -off.dot(basis[0]))
	return d.normalized() if d.length() > 0.01 else Vector2.RIGHT


## Where a plaque goes on the edge of the play area (clear of the party cards, the minimap, the Narrator and the
## buttons) in screen direction `d` from its middle.
func _edge_spot(d: Vector2, box: Vector2) -> Vector2:
	var screen := get_viewport_rect()
	var safe := Rect2(screen.position + Vector2(250, 96), screen.size - Vector2(500, 300))
	safe = safe.grow_individual(-box.x / 2.0, -box.y / 2.0, -box.x / 2.0, -box.y / 2.0)
	var mid := safe.get_center()
	var t := INF
	if absf(d.x) > 0.001:
		t = minf(t, ((safe.end.x if d.x > 0.0 else safe.position.x) - mid.x) / d.x)
	if absf(d.y) > 0.001:
		t = minf(t, ((safe.end.y if d.y > 0.0 else safe.position.y) - mid.y) / d.y)
	return mid + d * t
