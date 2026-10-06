class_name ExplorationHud
extends CanvasLayer
## Phase 0 placeholder HUD: party list with the leader marked, controls, and save/load toasts.
## Drawn on a CanvasLayer so the palette post-process never touches UI (plan §5.6).

var _rows: Array[Label] = []
var _toast: Label
var _toast_time := 0.0


func _init() -> void:
	name = "ExplorationHud"
	layer = 10


func build(names: Array[String]) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.add_theme_stylebox_override("panel", _frame())
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var title := _label("THE PARTY", 15, Look.color("parchment"))
	box.add_child(title)
	for i in names.size():
		var row := _label("%d  %s" % [i + 1, names[i]], 20, Look.color("vellum"))
		box.add_child(row)
		_rows.append(row)

	var help := _label("WASD / click: move leader    Tab or 1-4: change leader    Q/E: rotate    Wheel: zoom\nF5: quick save    F9: quick load    P: palette pass on/off", 15, Look.color("parchment"))
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = 16
	help.offset_top = -64
	add_child(help)

	_toast = _label("", 22, Look.color("gilt_light"))
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_left = -300
	_toast.offset_right = 300
	_toast.offset_top = 24
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_toast)


func set_leader(index: int) -> void:
	for i in _rows.size():
		var lead := i == index
		_rows[i].add_theme_color_override("font_color", Look.color("gilt_light") if lead else Look.color("vellum"))
		_rows[i].text = ("> " if lead else "   ") + _rows[i].text.substr(_rows[i].text.find(str(i + 1)))


func toast(text: String) -> void:
	_toast.text = text
	_toast_time = 2.0


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)


func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", Look.color("void"))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _frame() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(Look.color("ui_black"), 0.88)
	s.border_color = Look.color("gilt_dark")
	s.set_border_width_all(2)
	s.set_corner_radius_all(2)
	s.set_content_margin_all(12)
	return s
