class_name AreaMap
extends Control
## "Local area" on the map screen (Ashwin, 2026-10-25: "when you open map there should be a toggle for local area map which
## shows the full area map with exits named (where they go)"): the whole location the party is in, drawn from its grid
## (MapImage, the picture the minimap is made of) and fitted to the panel, with each way out marked where it is and
## named by what it is and where it goes ("Church", "-> Village Church"; a road that opens the travel map says so). A way
## that is shut for now is pewter. The party is marked, a named part of the place (its `areas`) is written across it,
## and squares behind a secret door nobody has found stay dark, as on the minimap. The wheel zooms and dragging pans.
## It reads the LocationView and never changes it. TravelScreen holds it beside the map of Barovia.

signal exit_hovered(id: String)
signal exit_picked(id: String)

## Zoom is a multiple of the fit: 1 shows the whole area, and ZOOM_MAX goes in this far.
const ZOOM_MAX := 5.0
## Clear space round the fitted area, for names at its edges.
const MARGIN := Vector2(70, 46)
## Ways out closer together than this (squares) with the same name are one mark and one name (a gate two squares wide).
const NEAR := 3
const OPEN_COLOUR := "gilt_light"
const SHUT_COLOUR := "pewter"
const TITLE_SIZE := 17
const GOES_SIZE := 14

var view: LocationView
## The ways out, as ExitSigns.ways_out gives them, without those behind an undiscovered secret door, with the ones of
## one name together: {ids, id, label, to, goes, region, open, dir, cells: Array[Vector2i], cell (the middle one)}.
var exits: Array[Dictionary] = []
var zoom := 1.0
## Where the area's top-left corner sits in the panel.
var pan := Vector2.ZERO
var hover := ""
var selected := ""
## Where each name was drawn last (exit id -> rect), for hit tests and tests.
var label_rects: Dictionary = {}
var _grid: CombatGrid
var _tex: ImageTexture
var _hidden: Dictionary = {}
var _time := 0.0
var _drag_from := Vector2(-1, -1)
var _dragged := false


func _init() -> void:
	name = "AreaMap"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_exited.connect(func() -> void: set_hover(""))


func show_area(v: LocationView) -> void:
	view = v
	_grid = LocationView.grid_for(v.loc)
	_hidden = HiddenAreas.hidden_cells(v)
	_tex = ImageTexture.create_from_image(MapImage.render(_grid, MapImage.colours(v), _hidden, v))
	exits = group_exits(ExitSigns.ways_out(v).filter(func(e: Dictionary) -> bool: return not _hidden.has(e["cell"])))
	zoom = 1.0
	pan = Vector2.ZERO
	_clamp()
	queue_redraw()


## What a way out is called and where it goes, for the map and its list: `title` (what it is: "Church") and `goes` (where it
## leads: "Village Church"), "" when the name already says it ("Blood of the Vine" into the Blood of the Vine). A road that
## opens the travel map leads to the map of Barovia.
static func naming(e: Dictionary) -> Dictionary:
	var title := str(e["label"])
	var goes := "The map of Barovia" if str(e["to"]) == "travel" else str(e["destination"])
	if goes != "" and title.to_lower().contains(goes.to_lower()):
		goes = ""
	return {"title": title, "goes": goes}


## `list` (ExitSigns.ways_out) with neighbours of one name made one: {ids, id (the first), label, to, goes, region, open, dir,
## cells, cell}, in the order the first of each was found.
static func group_exits(list: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Variant in list:
		var ex := e as Dictionary
		var cell := ex["cell"] as Vector2i
		var group: Dictionary = {}
		for g in out:
			if str(g["label"]) == str(ex["label"]) and str(g["to"]) == str(ex["to"]) and bool(g["open"]) == bool(ex["open"]) \
					and (g["cells"] as Array[Vector2i]).any(func(c: Vector2i) -> bool: return maxi(absi(c.x - cell.x), absi(c.y - cell.y)) <= NEAR):
				group = g
				break
		if group.is_empty():
			var cells: Array[Vector2i] = [cell]
			var ids: Array[String] = [str(ex["id"])]
			out.append({"ids": ids, "id": str(ex["id"]), "label": str(ex["label"]), "to": str(ex["to"]),
				"goes": str(naming(ex)["goes"]), "region": bool(ex["region"]), "open": bool(ex["open"]), "dir": ex["dir"],
				"cells": cells, "cell": cell})
		else:
			(group["cells"] as Array[Vector2i]).append(cell)
			(group["ids"] as Array[String]).append(str(ex["id"]))
			var mid := (group["cells"] as Array[Vector2i])[(group["cells"] as Array[Vector2i]).size() / 2]
			group["cell"] = mid
	return out


# --- Where things are ------------------------------------------------------------------------------

func _panel() -> Vector2:
	return size if size.x > 1.0 and size.y > 1.0 else custom_minimum_size


## Panel pixels a square takes when the whole area fits (zoom 1).
func fit_cell() -> float:
	if _grid == null:
		return 1.0
	var room := _panel() - MARGIN * 2.0
	return maxf(1.0, minf(room.x / float(_grid.width), room.y / float(_grid.depth)))


func cell_px() -> float:
	return fit_cell() * zoom


## A point in squares (x right, z down; the middle of a square is +0.5) in panel pixels at the current zoom and pan.
func to_panel(at: Vector2) -> Vector2:
	return pan + at * cell_px()


## The square under a panel point.
func cell_at(point: Vector2) -> Vector2i:
	var g := (point - pan) / cell_px()
	return Vector2i(floori(g.x), floori(g.y))


func _clamp() -> void:
	if _grid == null:
		return
	var area := Vector2(_grid.width, _grid.depth) * cell_px()
	var panel := _panel()
	for axis in 2:
		if area[axis] + MARGIN[axis] * 2.0 <= panel[axis]:
			pan[axis] = (panel[axis] - area[axis]) / 2.0
		else:
			pan[axis] = clampf(pan[axis], panel[axis] - area[axis] - MARGIN[axis], MARGIN[axis])


## Zooms by `factor` keeping the point under `at` where it is.
func zoom_at(at: Vector2, factor: float) -> void:
	var before := (at - pan) / cell_px()
	zoom = clampf(zoom * factor, 1.0, ZOOM_MAX)
	pan = at - before * cell_px()
	_clamp()
	queue_redraw()


## The middle of an exit's mark in panel pixels.
func exit_at_panel(g: Dictionary) -> Vector2:
	return to_panel(Vector2(g["cell"] as Vector2i) + Vector2(0.5, 0.5))


## The exit (its id) under a panel point: on its mark or on its name; "" for none.
func exit_under(point: Vector2) -> String:
	var best := ""
	var best_d := INF
	for g in exits:
		var id := str(g["id"])
		var d := INF
		for c: Vector2i in g["cells"]:
			d = minf(d, to_panel(Vector2(c) + Vector2(0.5, 0.5)).distance_to(point))
		if label_rects.has(id) and (label_rects[id] as Rect2).grow(3.0).has_point(point):
			d = minf(d, 1.0)
		if d < 16.0 and d < best_d:
			best_d = d
			best = id
	return best


func exit_named(id: String) -> Dictionary:
	for g in exits:
		if str(g["id"]) == id:
			return g
	return {}


# --- Drawing ---------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if is_visible_in_tree():
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_clamp()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _panel()), Look.color("ink"), true)
	label_rects.clear()
	if view == null or not is_instance_valid(view) or _tex == null:
		return
	_clamp()
	var cell := cell_px()
	draw_texture_rect(_tex, Rect2(pan, Vector2(_grid.width, _grid.depth) * cell), false)
	var font := UiKit.display_font()
	# What the names keep clear of: every mark and the party. The ways out's names are placed first (they matter), the
	# parts of the place get what room is left.
	var taken: Array[Rect2] = []
	for g in exits:
		for c: Vector2i in g["cells"]:
			taken.append(Rect2(to_panel(Vector2(c) + Vector2(0.5, 0.5)) - Vector2.ONE * 22.0, Vector2.ONE * 44.0))
	for m in _party():
		taken.append(Rect2(to_panel(Vector2(m.cell) + Vector2(0.5, 0.5)) - Vector2.ONE * 12.0, Vector2.ONE * 24.0))
	for g in exits:
		_layout_name(font, g, taken)
	_draw_areas(font, taken)
	for g in exits:
		_draw_mark(g, cell)
	_draw_party(cell)
	for g in exits:
		_draw_name(font, g)


## The party members the map marks, leader first: the dead are no longer out walking.
func _party() -> Array[Combatant]:
	var out: Array[Combatant] = []
	for m in view.members:
		if not m.creature.dead:
			out.append(m)
	return out


## A named part of the place (a yard, a lane) written faintly across it, where it isn't hidden, moved a little off the
## marks and names where they are in its way and left out where there is no room.
func _draw_areas(font: Font, taken: Array[Rect2]) -> void:
	for a: Variant in view.loc.get("areas", []):
		var area := a as Dictionary
		var cells := area.get("cells", []) as Array
		if cells.size() < 2:
			continue
		var lo := cells[0] as Array
		var hi := cells[1] as Array
		var mid := Vector2((float(lo[0]) + float(hi[0]) + 1.0) / 2.0, (float(lo[1]) + float(hi[1]) + 1.0) / 2.0)
		if _hidden.has(Vector2i(int(mid.x), int(mid.y))):
			continue
		var text := str(area.get("name", ""))
		var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
		var panel := Rect2(Vector2.ZERO, _panel()).grow(-4.0)
		var placed := Rect2()
		for shift: Vector2 in [Vector2.ZERO, Vector2(0, -26), Vector2(0, 26), Vector2(-sz.x * 0.45, 0), Vector2(sz.x * 0.45, 0),
				Vector2(0, -52), Vector2(0, 52), Vector2(-sz.x * 0.45, -26), Vector2(sz.x * 0.45, 26)]:
			var rect := Rect2(to_panel(mid) - sz / 2.0 + shift, sz)
			if not panel.encloses(rect):
				continue
			if not taken.any(func(t: Rect2) -> bool: return t.intersects(rect.grow(3.0))):
				placed = rect
				break
		if placed.size == Vector2.ZERO:
			continue
		var base := placed.position + Vector2(0, font.get_ascent(17))
		draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, Color(Look.color("void"), 0.55))
		draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(Look.color("vellum"), 0.55))
		taken.append(placed.grow(4.0))


func _colour_of(g: Dictionary) -> Color:
	return Look.color(OPEN_COLOUR if bool(g["open"]) else SHUT_COLOUR)


func _lit(g: Dictionary) -> bool:
	return str(g["id"]) == hover or str(g["id"]) == selected


## One mark for each square of a way out: a gilt arrow pointing off the edge for a road out of the area, a diamond for a
## door or a gate inside it; pewter while it is shut.
func _draw_mark(g: Dictionary, cell: float) -> void:
	var colour := _colour_of(g)
	var lit := _lit(g)
	var r := clampf(cell * 0.55, 8.0, 18.0) + (3.0 if lit else 0.0)
	for c: Vector2i in g["cells"]:
		var at := to_panel(Vector2(c) + Vector2(0.5, 0.5))
		var ink := Look.color("void")
		draw_rect(Rect2(to_panel(Vector2(c)), Vector2.ONE * cell), Color(colour, 0.28 + (0.2 if lit else 0.0)), true)
		var dir := Vector2(g["dir"] as Vector2i)
		if bool(g["region"]) and dir != Vector2.ZERO:
			var side := dir.orthogonal() * r * 0.8
			var pts := PackedVector2Array([at + dir * r, at - dir * r * 0.6 + side, at - dir * r * 0.15, at - dir * r * 0.6 - side])
			draw_colored_polygon(pts, colour)
			pts.append(pts[0])
			draw_polyline(pts, ink, 1.8, true)
		else:
			var pts := PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])
			draw_colored_polygon(pts, colour)
			pts.append(pts[0])
			draw_polyline(pts, ink, 1.8, true)
			draw_circle(at, r * 0.3, ink, true, -1.0, true)
		if lit:
			draw_arc(at, r + 5.0, 0.0, TAU, 32, Color(colour, 0.9), 2.0, true)


## The party: the leader a gilt mark with a slow ring, the others pale, and any guests a mist blue.
func _draw_party(cell: float) -> void:
	var shown := _party()
	for g in view.guest_members:
		_dot(Vector2(g.cell), clampf(cell * 0.28, 3.5, 7.0), Look.color("mist_blue"))
	for i in range(shown.size() - 1, -1, -1):
		var lead := i == 0
		var r := clampf(cell * (0.42 if lead else 0.3), 4.0, 11.0 if lead else 8.0)
		var at := to_panel(Vector2(shown[i].cell) + Vector2(0.5, 0.5))
		if lead:
			var pulse := 0.5 + 0.5 * sin(_time * 3.0)
			draw_circle(at, r + 5.0 + 6.0 * pulse, Color(Look.color("gilt_light"), 0.5 * (1.0 - pulse)), false, 2.5, true)
		draw_circle(at, r + 1.5, Look.color("ink"), true, -1.0, true)
		draw_circle(at, r, Look.color("gilt_light") if lead else Look.color("vellum"), true, -1.0, true)


func _dot(cell_at_: Vector2, r: float, colour: Color) -> void:
	var at := to_panel(cell_at_ + Vector2(0.5, 0.5))
	draw_circle(at, r + 1.5, Look.color("ink"), true, -1.0, true)
	draw_circle(at, r, colour, true, -1.0, true)


## What a way out's plaque says: what it is, then (under it) where it goes. A shut way says so.
func _plaque_lines(g: Dictionary) -> Array[String]:
	var goes := str(g["goes"])
	if not bool(g["open"]):
		goes = ("%s · shut for now" % goes) if goes != "" else "Shut for now"
	elif goes != "":
		goes = "→ " + goes
	return [str(g["label"]), goes]


func _plaque_size(font: Font, lines: Array[String]) -> Vector2:
	var t := font.get_string_size(lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE)
	var g := font.get_string_size(lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, GOES_SIZE) if lines[1] != "" else Vector2.ZERO
	return Vector2(maxf(t.x, g.x), t.y + (g.y + 1.0 if lines[1] != "" else 0.0)) + Vector2(16, 8)


## Where a way out's plaque goes: beside its mark, right, left, below or above, wherever it is clear of the marks, the
## party and the plaques before it (else the least crowded place). Kept in label_rects and added to `taken`.
func _layout_name(font: Font, g: Dictionary, taken: Array[Rect2]) -> void:
	var box_size := _plaque_size(font, _plaque_lines(g))
	var at := exit_at_panel(g)
	var r := 22.0
	var inside := Rect2(Vector2(4, 4), _panel() - Vector2(8, 8))
	var box := Rect2()
	var least := INF
	for s: Vector2 in [Vector2(r, -box_size.y / 2.0), Vector2(-r - box_size.x, -box_size.y / 2.0), Vector2(-box_size.x / 2.0, r),
			Vector2(-box_size.x / 2.0, -r - box_size.y), Vector2(r, r), Vector2(-r - box_size.x, r), Vector2(r, -r - box_size.y),
			Vector2(-r - box_size.x, -r - box_size.y), Vector2(-box_size.x / 2.0, r + 30.0), Vector2(-box_size.x / 2.0, -r - 30.0 - box_size.y)]:
		var rect := Rect2((at + s).clamp(inside.position, inside.end - box_size), box_size)
		var crowd := 0.0
		for t in taken:
			crowd += t.intersection(rect.grow(2.0)).get_area()
		if crowd < least:
			least = crowd
			box = rect
		if crowd == 0.0:
			break
	taken.append(box.grow(3.0))
	label_rects[str(g["id"])] = box


## A way out's plaque, dark with an edge in its colour: what it is, and where it goes under it.
func _draw_name(font: Font, g: Dictionary) -> void:
	var box := label_rects.get(str(g["id"]), Rect2()) as Rect2
	if box.size == Vector2.ZERO:
		return
	var lit := _lit(g)
	var open := bool(g["open"])
	var lines := _plaque_lines(g)
	var colour := _colour_of(g)
	draw_rect(box, Color(Look.color("ui_black"), 0.9), true)
	draw_rect(box, Color(colour, 0.95 if lit else 0.6), false, 2.0 if lit else 1.0)
	draw_string(font, box.position + Vector2(8, 4 + font.get_ascent(TITLE_SIZE)), lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE,
		Look.color("rose") if lit else (Look.color("vellum") if open else Look.color("pewter")))
	if lines[1] != "":
		var t_h := font.get_string_size(lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).y
		draw_string(font, box.position + Vector2(8, 4 + t_h + 1.0 + font.get_ascent(GOES_SIZE)), lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1,
			GOES_SIZE, Look.color("gilt_light") if open else Look.color("pewter"))


# --- Input -----------------------------------------------------------------------------------------

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(mb.position, 1.15)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(mb.position, 1.0 / 1.15)
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if mb.pressed:
				_drag_from = mb.position
				_dragged = false
			else:
				if not _dragged and mb.button_index == MOUSE_BUTTON_LEFT:
					var id := exit_under(mb.position)
					if id != "":
						pick(id)
				_drag_from = Vector2(-1, -1)
		accept_event()
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if _drag_from.x >= 0.0 and mm.button_mask != 0:
			if _dragged or mm.position.distance_to(_drag_from) > 5.0:
				_dragged = true
				pan += mm.relative
				_clamp()
		set_hover(exit_under(mm.position))
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover != "" else (Control.CURSOR_DRAG if _dragged else Control.CURSOR_ARROW)
		queue_redraw()


func set_hover(id: String) -> void:
	if id == hover:
		return
	hover = id
	exit_hovered.emit(id)
	queue_redraw()


## Picks a way out (a click, or A on the pad): it stays lit, and the map brings it into view.
func pick(id: String) -> void:
	selected = id
	var g := exit_named(id)
	if not g.is_empty():
		var at := exit_at_panel(g)
		if not Rect2(Vector2(60, 60), _panel() - Vector2(120, 120)).has_point(at):
			pan += _panel() / 2.0 - at
			_clamp()
	exit_picked.emit(id)
	queue_redraw()


# --- The pad ---------------------------------------------------------------------------------------

## The D-pad goes from way out to way out: the nearest one that way (false with none that way, so it leaves the map).
func pad_step(dir: Vector2i) -> bool:
	var now := hover if hover != "" else selected
	var from := exit_at_panel(exit_named(now)) if now != "" else _panel() / 2.0
	var best := ""
	var best_s := INF
	for g in exits:
		var id := str(g["id"])
		if id == now:
			continue
		var v := exit_at_panel(g) - from
		var along := v.dot(Vector2(dir))
		var side := absf(v.dot(Vector2(dir.y, dir.x)))
		if along <= 4.0 or side > along * 2.0:
			continue
		if along + side * 1.5 < best_s:
			best_s = along + side * 1.5
			best = id
	if best == "":
		if now == "" and not exits.is_empty():
			best = str(exits[0]["id"])   # nothing lit yet: the first
		else:
			return false
	set_hover(best)
	var at := exit_at_panel(exit_named(best))
	if not Rect2(Vector2(60, 60), _panel() - Vector2(120, 120)).has_point(at):
		pan += _panel() / 2.0 - at
		_clamp()
	return true


func pad_pick() -> void:
	if hover != "":
		pick(hover)


func pad_zoom(step: int) -> void:
	var at := exit_at_panel(exit_named(hover)) if hover != "" else _panel() / 2.0
	zoom_at(at, 1.15 if step > 0 else 1.0 / 1.15)


func pad_scroll(by: Vector2) -> void:
	pan -= by
	_clamp()
	queue_redraw()
