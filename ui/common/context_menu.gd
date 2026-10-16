class_name ContextMenu
extends PopupMenu
## The right-click menu used everywhere (plan §5.6): hotbar slots in combat (Info, Use, Cast at level N) and things in
## the world (Talk, Open, Pick the lock, Disarm, Read ...). A title line, then actions; a greyed-out action says why in
## its tooltip. It only shows choices: whoever opened it decides what each id does.

signal picked(id: String)

var mobile_sheet: CanvasLayer

var _ids: Array[String] = []

## Which icon (art/ui/icons) goes with an action, by the part of its id before any ":".
const ICONS := {"talk": "talk", "look": "search", "search_here": "search", "open": "door", "force": "door", "go": "door",
	"pick": "key", "key": "key", "disarm": "key", "trade": "trade", "use": "inventory", "walk": "map", "avoid": "sneak",
	"lead": "party", "sheet": "character", "inventory": "inventory", "spells": "spells", "info": "journal",
	"cast": "spells", "meta": "spells", "ready": "attack", "choice": "attack", "knock": "spells", "chime": "inventory",
	"mystery_key": "key", "strike": "attack", "pickpocket": "sneak", "check": "search", "check_aid": "character"}


func _init() -> void:
	add_theme_font_size_override("font_size", 16)
	add_theme_font_size_override("font_separator_size", 14)
	add_theme_color_override("font_color", Look.color("vellum"))
	add_theme_color_override("font_hover_color", Look.color("gilt_light"))
	add_theme_color_override("font_disabled_color", Look.color("bone"))
	add_theme_color_override("font_separator_color", Look.color("gilt"))
	add_theme_stylebox_override("panel", UiKit.style("ui_black", "gilt_dark", 2, 0.97))
	var hover := UiKit.style("ui_oxblood", "gilt_dark", 0, 1.0)
	hover.set_content_margin_all(4)
	add_theme_stylebox_override("hover", hover)
	add_theme_constant_override("icon_max_width", 18)
	add_theme_font_override("font_separator", UiKit.display_font())
	id_pressed.connect(func(i: int) -> void:
		Audio.sfx("click")
		if i >= 0 and i < _ids.size():
			picked.emit(_ids[i]))


## `actions`: [{id, label, enabled = true, why = ""}] or {separator: "Heading"}.
func show_actions(title: String, actions: Array[Dictionary], at: Vector2) -> void:
	if MobileDevice.enabled():
		_show_mobile(title, actions)
		return
	clear()
	_ids.clear()
	if title != "":
		add_separator(title)
	for a in actions:
		if a.has("separator"):
			add_separator(str(a["separator"]))
			continue
		var i := _ids.size()
		var tex := UiKit.icon(str(ICONS.get(str(a["id"]).get_slice(":", 0), "")))
		if tex != null:
			add_icon_item(tex, str(a["label"]), i)
		else:
			add_item(str(a["label"]), i)
		_ids.append(str(a["id"]))
		var idx := get_item_index(i)
		if tex != null:
			set_item_icon_modulate(idx, Look.color("gilt") if bool(a.get("enabled", true)) else Look.color("gilt_dark"))
		if not bool(a.get("enabled", true)):
			set_item_disabled(idx, true)
		if str(a.get("why", "")) != "":
			set_item_tooltip(idx, str(a["why"]))
	reset_size()
	position = Vector2i(at)
	popup()


func is_open() -> bool:
	return mobile_sheet != null or visible


func close() -> void:
	hide()
	if mobile_sheet != null:
		mobile_sheet.hide()
		mobile_sheet.queue_free()
		mobile_sheet = null
	if MobileDevice.enabled() and UiFeel.touch != null:
		UiFeel.touch.cancel()


func _exit_tree() -> void:
	if is_instance_valid(mobile_sheet):
		mobile_sheet.queue_free()


func _show_mobile(title: String, actions: Array[Dictionary]) -> void:
	close()
	mobile_sheet = CanvasLayer.new()
	mobile_sheet.layer = 50
	mobile_sheet.set_meta(&"pad_scope", true)
	# This PopupMenu is a separate viewport: the sheet belongs to the game's viewport instead.
	get_parent().add_child(mobile_sheet)
	var body := MobilePage.build(mobile_sheet, title, close)
	(body.get_parent() as ScrollContainer).horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	for action in actions:
		if action.has("separator"):
			body.add_child(MobileUi.text(str(action["separator"]), "gilt_light"))
			continue
		var id := str(action["id"])
		var button := MobileUi.button(str(action["label"]), func() -> void:
			close()
			Audio.sfx("click")
			picked.emit(id))
		button.disabled = not bool(action.get("enabled", true))
		body.add_child(button)
		if str(action.get("why", "")) != "":
			body.add_child(MobileUi.text(str(action["why"]), "parchment"))
