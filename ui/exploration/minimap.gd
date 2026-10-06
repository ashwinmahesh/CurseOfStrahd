class_name Minimap
extends Control
## The minimap at the top right of the exploration HUD: the current location drawn from its grid map, north up,
## centred on the party's leader and moving with them. Ways out are marked: a gilt arrow for a road to another region
## (on the rim, pointing toward it, while it's beyond the edge) and a small lamp for a door into a building. Doors,
## the people here and the party show as marks, and a pale wedge shows which way the camera looks. The wheel zooms;
## a click walks the party to that square. It reads the LocationView and never changes it except through `click`.

const RADIUS := 100.0
const RIM := 7.0
const PX := 16                     ## texture pixels per square (drawn smaller than this, so it stays sharp)
const ZOOM_MIN := 6.0              ## screen pixels per square
const ZOOM_MAX := 16.0

var view: LocationView
var cell_px := 9.0
var ways_out: Array[Dictionary] = []
var _grid: CombatGrid              ## the map as authored (doors drawn on top as they stand now)
var _tex: ImageTexture
var _colours: Dictionary = {}
var _centre := Vector2.ZERO        ## the ground point (world x, z) under the middle
var _content: Control
var _rim: Control
## Squares behind undiscovered secret doors (HiddenAreas), left dark until found.
var _hidden: Dictionary = {}
var _hidden_sig := ""
var _check := 0.0


func _init() -> void:
	name = "Minimap"
	custom_minimum_size = Vector2.ONE * (RADIUS + RIM) * 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var mask := Control.new()
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.draw.connect(func() -> void: mask.draw_circle(_mid(), RADIUS, Color.WHITE, true, -1.0, true))
	add_child(mask)
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.draw.connect(_draw_content)
	mask.add_child(_content)
	_rim = Control.new()
	_rim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rim.draw.connect(_draw_rim)
	add_child(_rim)


func show_location(v: LocationView) -> void:
	view = v
	_grid = CombatGrid.from_rows(v.loc["map"]["rows"] as Array)
	_colours = colours_for(ArenaBoard.theme_for(v.loc["map"] as Dictionary))
	_redo_hidden()
	_centre = _leader_ground()
	tooltip_text = "%s\nWheel: zoom · Click: walk there" % str(v.loc.get("name", ""))
	_content.queue_redraw()
	_rim.queue_redraw()


## Leaves the squares behind undiscovered secret doors (and the ways out there) off the map.
func _redo_hidden() -> void:
	_hidden_sig = HiddenAreas.signature(view)
	_hidden = HiddenAreas.hidden_cells(view)
	ways_out.assign(ExitSigns.ways_out(view).filter(func(e: Dictionary) -> bool: return not _hidden.has(e["cell"])))
	_tex = ImageTexture.create_from_image(_render())


## Map colours by the kind of place, in the game's gothic tones: grey ground outdoors with dark pines in the wilds and
## blood-dark roofs in a town; dark planks and black walls with a gilt edge indoors.
static func colours_for(theme: String) -> Dictionary:
	var c := {"floor": "walnut", "raised": "leather", "wall": "void", "edge": "gilt_dark", "low": "umber", "rough": "peat",
		"water": "moon_blue", "water_edge": "night_deep"}
	if theme in ArenaBoard.WILD:
		c.merge({"floor": "slate", "raised": "pewter", "wall": "bog", "edge": "bog_deep", "low": "umber", "rough": "stone"}, true)
	elif theme in ArenaBoard.TOWNS or theme == "shrine_yard":
		c.merge({"floor": "slate", "raised": "pewter", "wall": "blood_deep", "edge": "void", "low": "umber", "rough": "stone"}, true)
	elif theme == "dungeon":
		c.merge({"floor": "stone", "raised": "slate", "rough": "stone_deep"}, true)
	var out := {}
	for k: String in c:
		out[k] = Look.color(str(c[k]))
	return out


## The location as an image, PX pixels a square: ground, walls or trees with an inked edge where they meet open
## ground, low cover, rough ground and water. Mipmapped, so it shrinks cleanly.
func _render() -> Image:
	var w := _grid.width
	var d := _grid.depth
	var img := Image.create(w * PX, d * PX, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for z in d:
		for x in w:
			var c := Vector2i(x, z)
			if _hidden.has(c):
				continue
			var f := _grid.flags(c)
			var col := Color(0, 0, 0, 0)
			if (f & CombatGrid.WATER) != 0:
				col = _colours["water"]
			elif (f & CombatGrid.VOID) != 0:
				continue
			elif (f & CombatGrid.WALL) != 0:
				col = _colours["wall"]
			elif (f & CombatGrid.LOW) != 0:
				col = _colours["low"]
			elif (f & CombatGrid.DIFFICULT) != 0:
				col = _colours["rough"]
			elif _grid.height(c) > 0:
				col = _colours["raised"]
			else:
				col = _colours["floor"]
			img.fill_rect(Rect2i(x * PX, z * PX, PX, PX), col)
	var line := 3
	for z in d:
		for x in w:
			var c := Vector2i(x, z)
			if _hidden.has(c):
				continue
			var solid := _grid.has_flag(c, CombatGrid.WALL)
			var wet := _grid.has_flag(c, CombatGrid.WATER)
			if not solid and not wet:
				continue
			var edge: Color = _colours["edge"] if solid else _colours["water_edge"]
			for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := c + dir
				if not _grid.in_bounds(n) or _grid.has_flag(n, CombatGrid.WALL | CombatGrid.VOID) or _hidden.has(n):
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
	img.generate_mipmaps()
	return img


func _mid() -> Vector2:
	return size / 2.0


func _leader_ground() -> Vector2:
	if view == null or not is_instance_valid(view) or view.members.is_empty():
		return _centre
	var tok := view.tokens.get(view.members[0].id) as Node3D
	return Vector2(tok.global_position.x, tok.global_position.z) if tok != null else _centre


## A ground point (world x, z) on the minimap.
func to_map(ground: Vector2) -> Vector2:
	return _mid() + (ground - _centre) * cell_px


func _process(delta: float) -> void:
	if view == null or not is_instance_valid(view) or not is_visible_in_tree():
		return
	_centre = _leader_ground()   # the token glides from square to square, and the map with it
	_check -= delta
	if _check <= 0.0:
		_check = HiddenAreas.CHECK_EVERY
		if HiddenAreas.signature(view) != _hidden_sig:
			_redo_hidden()   # a secret door was found: the room behind it comes onto the map
	_content.queue_redraw()
	_rim.queue_redraw()


func _draw_content() -> void:
	var mid := _mid()
	_content.draw_circle(mid, RADIUS, Look.color("ink"), true, -1.0, true)
	if view == null or not is_instance_valid(view) or _tex == null:
		return
	_content.draw_texture_rect(_tex, Rect2(to_map(Vector2.ZERO), Vector2(_grid.width, _grid.depth) * cell_px), false)
	_draw_doors()
	_draw_camera_wedge()
	for e in ways_out:
		_draw_way_out(e)
	for npc: Variant in view.npc_tokens.values():
		var n := npc as Node3D
		if is_instance_valid(n) and n.visible and not _hidden.has(Vector2i(floori(n.global_position.x), floori(n.global_position.z))):
			var at := to_map(Vector2(n.global_position.x, n.global_position.z))
			_content.draw_circle(at, 4.0, Look.color("ink"), true, -1.0, true)
			_content.draw_circle(at, 2.8, Look.color("moonlight"), true, -1.0, true)
	for g in view.guest_members:
		_dot(view.tokens.get(g.id) as Node3D, 3.6, Look.color("mist_blue"))
	for i in range(view.members.size() - 1, -1, -1):
		_dot(view.tokens.get(view.members[i].id) as Node3D, 5.5 if i == 0 else 3.8,
			Look.color("gilt_light") if i == 0 else Look.color("vellum"))
	# A soft shadow inside the rim.
	for i in 6:
		_content.draw_arc(mid, RADIUS - i * 2.0, 0.0, TAU, 96, Color(Look.color("void"), 0.42 - i * 0.07), 2.5, true)


func _dot(tok: Node3D, r: float, colour: Color) -> void:
	if tok == null or not is_instance_valid(tok):
		return
	var at := to_map(Vector2(tok.global_position.x, tok.global_position.z))
	_content.draw_circle(at, r + 1.5, Look.color("ink"), true, -1.0, true)
	_content.draw_circle(at, r, colour, true, -1.0, true)


## Closed doors as wooden bars; a secret door nobody has found yet as plain wall.
func _draw_doors() -> void:
	var found := view.st.loc_state(view.loc_id)["found"] as Dictionary
	for d: Variant in view.loc.get("doors", []):
		var door := d as Dictionary
		var a := door["cell"] as Array
		if _hidden.has(Vector2i(int(a[0]), int(a[1]))):
			continue
		var r := Rect2(to_map(Vector2(float(a[0]), float(a[1]))), Vector2.ONE * cell_px)
		var id := str(door["id"])
		if int(door.get("secret_dc", 0)) > 0 and not bool(found.get(id, false)):
			_content.draw_rect(r, _colours["wall"], true)
			continue
		var node := view.door_nodes.get(id) as Node3D
		if node != null and is_instance_valid(node) and node.visible:
			_content.draw_rect(r.grow(-cell_px * 0.12), Look.color("leather"), true)
			_content.draw_rect(r.grow(-cell_px * 0.12), Look.color("peat"), false, 1.5)


func _draw_camera_wedge() -> void:
	if view.rig == null or view.members.is_empty():
		return
	var fwd := view.rig.ground_basis()[0]
	var at := to_map(_leader_ground())
	var ang := Vector2(fwd.x, fwd.z).angle()
	var pts := PackedVector2Array([at])
	for i in 9:
		pts.append(at + Vector2.from_angle(ang - 0.55 + i * 0.1375) * 54.0)
	_content.draw_colored_polygon(pts, Color(Look.color("ivory"), 0.16))


## A way out: a gilt arrow at a road to another region (pinned to the rim, pointing at it, while it's beyond the
## edge), a lamp at a door. Ways that are shut for now are drawn in pewter.
func _draw_way_out(e: Dictionary) -> void:
	var cell := e["cell"] as Vector2i
	var at := to_map(Vector2(cell) + Vector2(0.5, 0.5))
	var open := bool(e["open"])
	if not bool(e["region"]):
		if at.distance_to(_mid()) < RADIUS - 6.0:
			_content.draw_circle(at, 4.0, Look.color("ink"), true, -1.0, true)
			_content.draw_circle(at, 2.8, Look.color("flame") if open else Look.color("pewter"), true, -1.0, true)
		return
	var colour := Look.color("gilt_light") if open else Look.color("pewter")
	var dir := Vector2(e["dir"] as Vector2i)
	var off := at - _mid()
	if off.length() > RADIUS - 14.0:
		# Beyond the edge: an arrow on the rim, pointing the way.
		var toward := off.normalized()
		var tip := _mid() + toward * (RADIUS - 5.0)
		_arrow(tip, toward, 18.0, colour)
		return
	_content.draw_circle(at, 9.0, Color(colour, 0.25), true, -1.0, true)
	if dir == Vector2.ZERO:
		_content.draw_circle(at, 5.0, Look.color("ink"), true, -1.0, true)
		_content.draw_circle(at, 3.5, colour, true, -1.0, true)
	else:
		_arrow(at + dir * 7.0, dir, 13.0, colour)


func _arrow(tip: Vector2, dir: Vector2, length: float, colour: Color) -> void:
	var side := dir.orthogonal() * length * 0.55
	var back := tip - dir * length
	var pts := PackedVector2Array([tip, back + side, back + dir * length * 0.3, back - side])
	_content.draw_colored_polygon(pts, colour)
	pts.append(tip)
	_content.draw_polyline(pts, Look.color("ink"), 1.5, true)


func _draw_rim() -> void:
	var mid := _mid()
	_rim.draw_arc(mid, RADIUS + RIM * 0.5, 0.0, TAU, 128, Look.color("ui_black"), RIM, true)
	_rim.draw_arc(mid, RADIUS + 1.0, 0.0, TAU, 128, Look.color("gilt"), 2.0, true)
	_rim.draw_arc(mid, RADIUS + RIM - 1.0, 0.0, TAU, 128, Look.color("gilt_dark"), 2.0, true)
	for i in 8:
		_rim.draw_circle(mid + Vector2.from_angle(PI / 8.0 + i * PI / 4.0) * (RADIUS + RIM * 0.5), 1.8, Look.color("gilt"), true, -1.0, true)
	# North on a crimson stud at the top.
	var n_at := mid + Vector2(0, -RADIUS - RIM * 0.5)
	_rim.draw_circle(n_at, 12.0, Look.color("ui_oxblood"), true, -1.0, true)
	_rim.draw_circle(n_at, 12.0, Look.color("gilt"), false, 1.5, true)
	var font := ThemeDB.fallback_font
	var w := font.get_string_size("N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	_rim.draw_string(font, n_at + Vector2(-w / 2.0, 5.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Look.color("gilt_light"))


func _has_point(point: Vector2) -> bool:
	return point.distance_to(_mid()) <= RADIUS + RIM


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		cell_px = clampf(cell_px * 1.15, ZOOM_MIN, ZOOM_MAX)
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		cell_px = clampf(cell_px / 1.15, ZOOM_MIN, ZOOM_MAX)
	elif mb.button_index == MOUSE_BUTTON_LEFT and view != null and is_instance_valid(view):
		view.click(cell_at(mb.position))
	accept_event()


## The square under a point on the minimap.
func cell_at(point: Vector2) -> Vector2i:
	var g := _centre + (point - _mid()) / cell_px
	return Vector2i(floori(g.x), floori(g.y))
