class_name MapSketch
extends Control
## A Skirmish map from above (N1, N9): walls, low cover, Difficult Terrain, water and raised floors in the palette,
## the place's furniture as small marks, and everyone's square: heroes as gilt rings with their initial, foes as
## crimson discs as wide as their footprint, numbered. The encounter editor (N9) clicks squares on it; the Skirmish
## screen shows it as the field's preview.

## A square was clicked: `button` is MOUSE_BUTTON_LEFT or MOUSE_BUTTON_RIGHT.
signal cell_clicked(cell: Vector2i, button: int)
## The square under the mouse changed ((-1, -1) when it left the map).
signal cell_hovered(cell: Vector2i)

var grid: CombatGrid = null
## {cell: true}: the location's furniture, chests, doorways and ways out.
var furniture: Dictionary = {}
## [{cell: Vector2i, size: int, side: "party" | "enemy", label: String, lit: bool, pinned: bool}]
var marks: Array[Dictionary] = []
## Squares tinted to show where the chosen piece may go (the editor's brush).
var shade: Dictionary = {}
var hover := Vector2i(-1, -1)
## Clicks and hover only when editing.
var editable := false

var _cell := 10.0
var _origin := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func show_map(g: CombatGrid, furniture_: Dictionary, marks_: Array[Dictionary]) -> void:
	grid = g
	furniture = furniture_
	marks = marks_
	queue_redraw()


func _fit() -> void:
	if grid == null or grid.width == 0 or grid.depth == 0:
		return
	_cell = floorf(minf(size.x / grid.width, size.y / grid.depth))
	_cell = maxf(_cell, 3.0)
	_origin = ((size - Vector2(grid.width, grid.depth) * _cell) / 2.0).floor()


## The square at a point in this control, or (-1, -1).
func cell_at(p: Vector2) -> Vector2i:
	_fit()
	if grid == null:
		return Vector2i(-1, -1)
	var c := Vector2i(floori((p.x - _origin.x) / _cell), floori((p.y - _origin.y) / _cell))
	return c if grid.in_bounds(c) else Vector2i(-1, -1)


func cell_rect(c: Vector2i, cells: int = 1) -> Rect2:
	return Rect2(_origin + Vector2(c) * _cell, Vector2.ONE * _cell * cells)


func _gui_input(event: InputEvent) -> void:
	if not editable or grid == null:
		return
	if event is InputEventMouseMotion:
		var c := cell_at((event as InputEventMouseMotion).position)
		if c != hover:
			hover = c
			cell_hovered.emit(c)
			queue_redraw()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			var c := cell_at(mb.position)
			if c.x >= 0:
				accept_event()
				cell_clicked.emit(c, mb.button_index)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and hover.x >= 0:
		hover = Vector2i(-1, -1)
		cell_hovered.emit(hover)
		queue_redraw()
	elif what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	_fit()
	if grid == null:
		return
	var floor_a := Look.color("umber").darkened(0.35)
	var floor_b := Look.color("umber").darkened(0.42)
	for z in grid.depth:
		for x in grid.width:
			var c := Vector2i(x, z)
			var r := cell_rect(c)
			var f := grid.flags(c)
			if f & CombatGrid.WATER:
				draw_rect(r, Look.color("moon_blue").darkened(0.35))
			elif f & CombatGrid.VOID:
				continue
			elif f & CombatGrid.WALL:
				draw_rect(r, Look.color("ink"))
				draw_rect(r.grow(-maxf(1.0, _cell * 0.18)), Look.color("stone_deep"))
			else:
				var base := floor_a if (x + z) % 2 == 0 else floor_b
				var h := grid.height(c)
				if h > 0:
					base = base.lerp(Look.color("slate"), clampf(0.25 + h / 40.0, 0.0, 0.7))
				draw_rect(r, base)
				if f & CombatGrid.DIFFICULT:
					draw_rect(r.grow(-_cell * 0.22), Color(Look.color("bog"), 0.75))
				if f & CombatGrid.LOW:
					draw_rect(r.grow(-_cell * 0.12), Look.color("stone"))
					draw_rect(r.grow(-_cell * 0.12), Look.color("ink"), false, 1.0)
			if shade.has(c):
				draw_rect(r, Color(Look.color("gilt"), 0.18))
	for c: Vector2i in furniture:
		if grid.in_bounds(c):
			UiParts.diamond(self, cell_rect(c).get_center(), maxf(2.0, _cell * 0.22), Color(Look.color("bone"), 0.6), true)
	var font := UiKit.display_font()
	for m in marks:
		var cell := m["cell"] as Vector2i
		if cell.x < 0:
			continue
		var r := cell_rect(cell, int(m.get("size", 1)))
		var centre := r.get_center()
		var rad := r.size.x * 0.42
		var party := str(m.get("side", "")) == "party"
		var lit := bool(m.get("lit", false))
		# Squares filled in rather than placed in the editor show fainter.
		var a := 1.0 if bool(m.get("pinned", true)) or lit else 0.6
		if lit:
			draw_circle(centre, rad + maxf(2.0, _cell * 0.14), Color(Look.color("gilt_light"), 0.35))
		if party:
			draw_circle(centre, rad, Color(Look.color("ui_black"), a))
			draw_arc(centre, rad, 0, TAU, 24, Color(Look.color("gilt_light" if lit else "gilt"), a), maxf(1.5, _cell * 0.12), true)
		else:
			draw_circle(centre, rad, Color(Look.color("blood_deep" if not lit else "crimson"), a))
			draw_arc(centre, rad, 0, TAU, 24, Color(Look.color("vampire_red" if not lit else "gilt_light"), a), maxf(1.0, _cell * 0.08), true)
		var label := str(m.get("label", ""))
		if label != "" and _cell >= 9.0:
			var fs := int(clampf(r.size.x * 0.48, 8.0, 22.0))
			UiParts.centred_text(self, font, label, centre, fs, Color(Look.color("ivory" if party else "vellum"), a))
	if editable and hover.x >= 0:
		draw_rect(cell_rect(hover), Look.color("gilt_light"), false, 2.0)
