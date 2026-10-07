class_name AchievementsPanel
extends CanvasLayer
## The achievements (N8) in a framed list: each one's name, how it's earned, and when it was, earned ones lit and the
## rest dim. Opened from the title, and its list sits in the ending's tally too (Achievements keeps them).

signal closed


func _init() -> void:
	name = "AchievementsPanel"
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS


## A panel over `parent`, closed with its button or Esc.
static func open(parent: Node) -> AchievementsPanel:
	var p := AchievementsPanel.new()
	parent.add_child(p)
	var frame := UiKit.screen_frame(p, "Achievements", Vector2(1000, 760))
	var under_crest := Control.new()
	under_crest.custom_minimum_size = Vector2(0, 14)
	frame.add_child(under_crest)
	var all := Achievements.all()
	var got := all.filter(func(a: Dictionary) -> bool: return str(a["earned"]) != "").size()
	var head := UiKit.label("%d of %d earned, over every playthrough and Skirmish." % [got, all.size()], 16, "parchment")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.add_child(head)
	var pane := UiParts.pane(12)
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pane.add_child(UiParts.fill_scroll(list(900.0)))
	frame.add_child(pane)
	var close := UiParts.primary_button("Close", p.close)
	close.name = "Close"
	frame.add_child(close)
	return p


## Every achievement as a row: lit with the date it was earned, or dim with how to earn it.
static func list(width: float, only: Array = []) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	for a in Achievements.all():
		if not only.is_empty() and not str(a["id"]) in only:
			continue
		var got := str(a["earned"]) != ""
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(UiParts.drawn(Vector2(22, 22), func(c: Control) -> void:
			UiParts.diamond(c, c.size / 2.0, 10.0, Look.color("void"), true)
			UiParts.diamond(c, c.size / 2.0, 8.0, Look.color("gilt_light" if got else "ui_oxblood"), true)))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		var n := UiKit.label(str(a["name"]), 17, "gilt_light" if got else "bone")
		n.add_theme_font_override("font", UiKit.display_font())
		col.add_child(n)
		col.add_child(UiKit.label(str(a["text"]), 13, "vellum" if got else "parchment", width - 220.0))
		row.add_child(col)
		row.add_child(UiParts.gap())
		if got:
			row.add_child(UiKit.label(str(a["earned"]).replace("T", " ").left(10), 13, "gilt"))
		var r := UiParts.row(row, Callable(), got)
		if not got:
			r.modulate = Color(1, 1, 1, 0.75)
		box.add_child(r)
	return box


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"combat_cancel"):
		get_viewport().set_input_as_handled()
		close()
