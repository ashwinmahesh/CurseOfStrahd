class_name ContextMenu
extends PopupMenu
## The right-click menu used everywhere (plan §5.6): hotbar slots in combat (Info, Use, Cast at level N) and things in
## the world (Talk, Open, Pick the lock, Disarm, Read ...). A title line, then actions; a greyed-out action says why in
## its tooltip. It only shows choices: whoever opened it decides what each id does.

signal picked(id: String)

var _ids: Array[String] = []


func _init() -> void:
	add_theme_font_size_override("font_size", 16)
	add_theme_font_size_override("font_separator_size", 14)
	add_theme_color_override("font_color", Look.color("vellum"))
	add_theme_color_override("font_hover_color", Look.color("gilt_light"))
	add_theme_color_override("font_disabled_color", Look.color("ui_wine"))
	add_theme_color_override("font_separator_color", Look.color("gilt"))
	add_theme_stylebox_override("panel", UiKit.style("ui_black", "gilt_dark", 2, 0.97))
	var hover := UiKit.style("ui_oxblood", "gilt_dark", 0, 1.0)
	hover.set_content_margin_all(4)
	add_theme_stylebox_override("hover", hover)
	id_pressed.connect(func(i: int) -> void:
		if i >= 0 and i < _ids.size():
			picked.emit(_ids[i]))


## `actions`: [{id, label, enabled = true, why = ""}] or {separator: "Heading"}.
func show_actions(title: String, actions: Array[Dictionary], at: Vector2) -> void:
	clear()
	_ids.clear()
	if title != "":
		add_separator(title)
	for a in actions:
		if a.has("separator"):
			add_separator(str(a["separator"]))
			continue
		var i := _ids.size()
		add_item(str(a["label"]), i)
		_ids.append(str(a["id"]))
		var idx := get_item_index(i)
		if not bool(a.get("enabled", true)):
			set_item_disabled(idx, true)
		if str(a.get("why", "")) != "":
			set_item_tooltip(idx, str(a["why"]))
	reset_size()
	position = Vector2i(at)
	popup()
