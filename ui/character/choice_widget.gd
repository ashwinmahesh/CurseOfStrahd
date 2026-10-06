class_name ChoiceWidget
extends VBoxContainer
## One character-building choice (plan §5.6 "a new subclass or feat needs data, never new UI code"): a box titled
## with its count ("Skills · choose 2 of 9 · 2 of 2 ✓") and its options as toggles. Options that can't be picked stay
## visible, greyed, with the engine's reason; weak ones show ~ and the warning. Picking more than the count replaces
## the oldest pick. Works for every Choice.kind; ability increases allow the same ability twice.

signal picks_changed(key: String, picks: Array)

var choice: Choice
var _status: Label


static func create(c: Choice) -> ChoiceWidget:
	var w := ChoiceWidget.new()
	w.choice = c
	w._build()
	return w


func _build() -> void:
	add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	var t := UiKit.label(_title(), 17, "gilt")
	head.add_child(t)
	_status = UiKit.label(_status_text(), 15, "bile" if choice.is_complete() else "gilt")
	head.add_child(_status)
	add_child(head)
	if choice.kind == "ability_increase":
		_ability_rows()
		return
	var grid := GridContainer.new()
	grid.columns = 3 if choice.options.size() > 8 else 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	for o in choice.options:
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = o.id in choice.picks
		b.custom_minimum_size = Vector2(300 if grid.columns == 3 else 440, 34)
		b.clip_text = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var mark := "" if o.legal else "✕ "
		if o.legal and o.warning != "":
			mark = "~ "
		b.text = mark + o.label
		var tip := o.summary
		if not o.legal:
			tip += ("\n" if tip != "" else "") + "Can't pick: " + o.reason
		if o.warning != "":
			tip += ("\n" if tip != "" else "") + "~ " + o.warning
		b.tooltip_text = tip
		b.disabled = not o.legal and not o.id in choice.picks
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_stylebox_override("normal", UiKit.style("ui_oxblood", "gilt_dark", 1))
		b.add_theme_stylebox_override("pressed", UiKit.style("blood", "gilt_light", 2))
		b.add_theme_stylebox_override("hover", UiKit.style("ui_wine", "gilt_light", 1))
		b.add_theme_stylebox_override("disabled", UiKit.style("ui_black", "ui_oxblood", 1))
		b.add_theme_color_override("font_color", Look.color("vellum"))
		b.add_theme_color_override("font_pressed_color", Look.color("gilt_light"))
		b.add_theme_color_override("font_disabled_color", Look.color("gilt_dark"))
		var id := o.id
		b.toggled.connect(func(on: bool) -> void: _toggle(id, on))
		grid.add_child(b)
	add_child(grid)


func _title() -> String:
	var base := choice.label if choice.label != "" else choice.kind.replace("_", " ").capitalize()
	if choice.source != "" and not base.contains(choice.source):
		base = "%s · %s" % [choice.source, base]
	return "%s · choose %d" % [base, choice.count]


func _status_text() -> String:
	var n := choice.picks.size()
	return "  %d of %d %s" % [n, choice.count, "✓" if choice.is_complete() else "!"]


func _toggle(id: String, on: bool) -> void:
	var picks: Array = choice.picks.duplicate()
	if on and not id in picks:
		picks.append(id)
		while picks.size() > choice.count:
			picks.pop_front()
	elif not on:
		picks.erase(id)
	picks_changed.emit(choice.key, picks)


## Ability score increases: a button per ability adds +1 there (up to per_ability on one ability); when all are
## placed, the oldest moves. Clear starts over.
func _ability_rows() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for o in choice.options:
		var times := choice.picks.count(o.id)
		var b := Button.new()
		b.text = "%s +%d" % [o.label, times] if times > 0 else o.label
		b.tooltip_text = o.summary + ("" if o.legal else "\nCan't pick: " + o.reason)
		b.disabled = not o.legal and times == 0
		var id := o.id
		b.pressed.connect(func() -> void:
			var picks: Array = choice.picks.duplicate()
			if picks.count(id) >= choice.per_ability:
				return
			picks.append(id)
			while picks.size() > choice.count:
				picks.pop_front()
			picks_changed.emit(choice.key, picks))
		row.add_child(b)
	row.add_child(UiKit.button("Clear", func() -> void: picks_changed.emit(choice.key, []), 14))
	add_child(row)
