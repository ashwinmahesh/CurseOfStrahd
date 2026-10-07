class_name ItemTile
extends Control
## One item as a tile (U11, plan §5.6 "Inventory"): a pointed gothic arch in crimson and gilt with the item's icon, its
## count on a small plaque and its marks (a gilt spark when new, dimmed with a cross when junk, a moonlight lozenge when
## equipped, a flame edge for a quest item, a lilac edge for magic). Empty, it names what its slot takes ("Ring") in faint
## engraved capitals. Drag it onto anything that takes it (another slot, a party chip, the stash, the pack); hover for
## its card, click to pick it, right-click for its menu, double-click for its first action. The screen gives it what a
## drag carries and what it takes; the tile only draws and passes events on.

signal picked
signal activated
signal menu_requested(at: Vector2)

## What a drag from this tile carries ({} for nothing: an empty slot): {from, ch, id, entry, slot, index}.
var payload: Dictionary = {}
## func(data: Dictionary) -> bool: whether a drag may drop here; func(data: Dictionary) -> void when it does.
var accepts: Callable
var dropped: Callable
## func() -> Control: the rich tooltip.
var tip: Callable
var icon: Texture2D
var qty := 0
## Shown when empty: what the slot takes.
var caption := ""
## Any of "new", "junk", "equipped", "quest", "magic", "quick", "set2", "inactive" (worn but not working: it needs
## attunement).
var marks: Array[String] = []
## The picked tile.
var lit := false
## Can't be used here (the stash away from a safe place).
var dim := false
var _hover := false
var _drop_ok := false


static func make(side: Vector2) -> ItemTile:
	var t := ItemTile.new()
	t.custom_minimum_size = side
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	t.focus_mode = Control.FOCUS_NONE
	return t


func _ready() -> void:
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		_drop_ok = false
		queue_redraw())
	if tip.is_valid():
		tooltip_text = "·"


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _drop_ok:
		_drop_ok = false
		queue_redraw()


func _make_custom_tooltip(_for_text: String) -> Object:
	return tip.call() as Control if tip.is_valid() else null


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.double_click:
			activated.emit()
		else:
			picked.emit()
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		menu_requested.emit(mb.global_position)
		accept_event()


## The drag: the icon follows the pointer.
func _get_drag_data(_at: Vector2) -> Variant:
	if payload.is_empty():
		return null
	var ghost := TextureRect.new()
	ghost.texture = icon
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.size = Vector2(48, 48)
	ghost.position = Vector2(-24, -24)
	ghost.modulate = Color(1, 1, 1, 0.85)
	var holder := Control.new()
	holder.add_child(ghost)
	set_drag_preview(holder)
	return payload


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	var ok := data is Dictionary and accepts.is_valid() and bool(accepts.call(data))
	if ok != _drop_ok:
		_drop_ok = ok
		queue_redraw()
	return ok


func _drop_data(_at: Vector2, data: Variant) -> void:
	_drop_ok = false
	queue_redraw()
	dropped.call(data)


func _draw() -> void:
	var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
	var rise := minf(size.y * 0.22, 16.0)
	var shape := UiParts.arch_points(r, rise, 12)
	var filled := not payload.is_empty() or icon != null
	UiParts.gradient_fill(self, shape, Color(Look.color("ui_wine"), 0.95 if filled else 0.55),
		Color(Look.color("ui_black"), 0.98))
	if _hover and not _drop_ok:
		UiParts.gradient_fill(self, shape, Color(Look.color("gilt_light"), 0.10), Color(Look.color("gilt_light"), 0.03))
	if _drop_ok:
		UiParts.gradient_fill(self, shape, Color(Look.color("bile"), 0.28), Color(Look.color("bile"), 0.08))
	var inner := UiParts.arch_points(r.grow(-4), maxf(rise - 3.0, 4.0), 12)
	var edge := "gilt_dark"
	if "magic" in marks:
		edge = "lilac"
	if "quest" in marks or "inactive" in marks:
		edge = "flame"
	UiParts.closed_line(self, inner, Color(Look.color(edge), 0.55 if edge == "gilt_dark" else 0.8), 1.0)
	var outline := "bile" if _drop_ok else ("gilt_light" if lit else ("gilt" if _hover else "gilt_dark"))
	UiParts.closed_line(self, shape, Look.color(outline), 2.5 if lit or _drop_ok else 1.5)
	# The apex lozenge, as on the screen's title arch.
	UiParts.diamond(self, Vector2(size.x / 2.0, r.position.y + 1.0), 3.0, Look.color("gilt_light" if lit else "gilt"), true)
	var pic := Rect2(Vector2(size.x * 0.16, rise + (size.y - rise) * 0.10), Vector2(size.x * 0.68, size.x * 0.68))
	pic.size.y = minf(pic.size.y, size.y - pic.position.y - 6.0)
	pic.size.x = pic.size.y
	pic.position.x = (size.x - pic.size.x) / 2.0
	if icon != null:
		var tint := Color(1, 1, 1, 1)
		if "junk" in marks or dim:
			tint = Color(0.55, 0.5, 0.5, 0.75)
		draw_texture_rect(icon, pic, false, tint)
	elif caption != "":
		var words := caption.to_upper().split(" ")
		for i in words.size():
			UiParts.centred_text(self, UiParts.caps_font(), words[i], Vector2(size.x / 2.0, size.y * 0.56 + (i - (words.size() - 1) / 2.0) * 11.0),
				9, Color(Look.color("parchment"), 0.6), 2)
	if "junk" in marks:
		var c := pic.get_center()
		var k := pic.size.x * 0.32
		draw_line(c + Vector2(-k, -k), c + Vector2(k, k), Color(Look.color("bone"), 0.85), 2.0, true)
		draw_line(c + Vector2(k, -k), c + Vector2(-k, k), Color(Look.color("bone"), 0.85), 2.0, true)
	if "new" in marks:
		var at := Vector2(9, rise + 4.0)
		UiParts.diamond(self, at, 5.5, Look.color("void"), true)
		UiParts.diamond(self, at, 4.0, Look.color("gilt_light"), true)
	if "equipped" in marks or "set2" in marks or "quick" in marks:
		var at2 := Vector2(9, size.y - 9.0)
		var col := Look.color("moonlight" if "equipped" in marks else ("lilac" if "set2" in marks else "bile"))
		UiParts.diamond(self, at2, 5.0, Look.color("void"), true)
		UiParts.diamond(self, at2, 3.5, col, true)
	if qty > 1:
		var txt := str(qty)
		var w := UiParts.figure_font().get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 8.0
		var plaque := Rect2(Vector2(size.x - w - 3.0, size.y - 18.0), Vector2(w, 15))
		draw_rect(plaque, Color(Look.color("void"), 0.9))
		draw_rect(plaque, Look.color("gilt_dark"), false, 1.0)
		UiParts.centred_text(self, UiParts.figure_font(), txt, plaque.get_center() + Vector2(0, 1), 13, Look.color("ivory"), 2)


## A drop target over a whole area (the pack, the stash): highlights while a drag that it takes hovers over it.
class Zone extends PanelContainer:
	var accepts: Callable
	var dropped: Callable
	var _ok := false

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		var ok := data is Dictionary and accepts.is_valid() and bool(accepts.call(data))
		if ok != _ok:
			_ok = ok
			modulate = Color(1.12, 1.12, 1.0) if ok else Color.WHITE
		return ok

	func _drop_data(_at: Vector2, data: Variant) -> void:
		_ok = false
		modulate = Color.WHITE
		dropped.call(data)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END and _ok:
			_ok = false
			modulate = Color.WHITE


## A party chip that takes a dropped item (give it to them).
class DropButton extends Button:
	var accepts: Callable
	var dropped: Callable

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and accepts.is_valid() and bool(accepts.call(data))

	func _drop_data(_at: Vector2, data: Variant) -> void:
		dropped.call(data)


## The same for a row of the inventory's list view: the screen lays out the row's content (icon, name, tags, weight) on a
## crimson row card that lights when picked, glows on hover and takes a bile edge while a drag it takes hovers over it.
## Drags, drops, the right-click menu and double-click work as on a tile.
class Row extends PanelContainer:
	signal picked
	signal activated
	signal menu_requested(at: Vector2)

	var payload: Dictionary = {}
	var accepts: Callable
	var dropped: Callable
	var tip: Callable
	## The drag preview's picture.
	var icon: Texture2D
	var lit := false:
		set(v):
			lit = v
			_restyle()
	var _hover := false
	var _drop_ok := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func() -> void:
			_hover = true
			_restyle())
		mouse_exited.connect(func() -> void:
			_hover = false
			_drop_ok = false
			_restyle())
		if tip.is_valid():
			tooltip_text = "·"
		_restyle()

	func _restyle() -> void:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(Look.color("ui_wine" if lit or _hover else "ui_oxblood"), 0.75 if lit else (0.65 if _hover else 0.55))
		var edge := "bile" if _drop_ok else ("gilt_light" if lit else ("gilt" if _hover else "gilt_dark"))
		s.border_color = Color(Look.color(edge), 0.95)
		s.set_border_width_all(2 if lit or _drop_ok else 1)
		s.set_corner_radius_all(7)
		s.corner_detail = 1
		s.set_content_margin_all(7)
		add_theme_stylebox_override("panel", s)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END and _drop_ok:
			_drop_ok = false
			_restyle()

	func _make_custom_tooltip(_for_text: String) -> Object:
		return tip.call() as Control if tip.is_valid() else null

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb == null or not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.double_click:
				activated.emit()
			else:
				picked.emit()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			menu_requested.emit(mb.global_position)
			accept_event()

	func _get_drag_data(_at: Vector2) -> Variant:
		if payload.is_empty():
			return null
		var ghost := TextureRect.new()
		ghost.texture = icon
		ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ghost.size = Vector2(44, 44)
		ghost.position = Vector2(-22, -22)
		ghost.modulate = Color(1, 1, 1, 0.85)
		var holder := Control.new()
		holder.add_child(ghost)
		set_drag_preview(holder)
		return payload

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		var ok := data is Dictionary and accepts.is_valid() and bool(accepts.call(data))
		if ok != _drop_ok:
			_drop_ok = ok
			_restyle()
		return ok

	func _drop_data(_at: Vector2, data: Variant) -> void:
		_drop_ok = false
		_restyle()
		dropped.call(data)
