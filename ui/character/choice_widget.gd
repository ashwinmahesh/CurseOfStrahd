class_name ChoiceWidget
extends VBoxContainer
## One character-building choice (plan §5.6 "a new subclass or feat needs data, never new UI code"): a box titled
## with its count ("Skills · choose 2 of 9 · 2 of 2 ✓") and its options as toggles. Options that can't be picked stay
## visible, greyed, with the engine's reason; weak ones show ~ and the warning. Picking more than the count replaces
## the oldest pick. Works for every Choice.kind; ability increases allow the same ability twice.

signal picks_changed(key: String, picks: Array)

var choice: Choice


static func create(c: Choice) -> ChoiceWidget:
	var w := ChoiceWidget.new()
	w.choice = c
	w._build()
	return w


func _build() -> void:
	add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var t := UiKit.header(_title())
	t.add_theme_font_size_override("font_size", 18)
	head.add_child(t)
	var status := UiParts.pill(_status_text().strip_edges(), "bile" if choice.is_complete() else "gilt", 13)
	head.add_child(status)
	add_child(head)
	if choice.kind == "ability_increase":
		_ability_rows()
		return
	var grid := GridContainer.new()
	grid.columns = 3 if choice.options.size() > 8 else 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 5)
	for o in choice.options:
		var picked := o.id in choice.picks
		var mark := "◆ " if picked else ("✕ " if not o.legal else ("~ " if o.warning != "" else "◇ "))
		var tip := o.summary
		var foot := ""
		if not o.legal:
			foot = "Can't pick: " + o.reason
		elif o.warning != "":
			foot = "~ " + o.warning
		var label := o.label
		var b := UiParts.tip_button(mark + o.label, func() -> void: pass, func() -> Control:
			return UiParts.rules_tip(label, "", tip, [], foot), picked, 14)
		b.toggle_mode = true
		b.button_pressed = picked
		if choice.kind in ["cantrip", "spell", "spellbook"]:
			UiParts.icon_on_button(b, "spell", o.id, 26)
		b.custom_minimum_size = Vector2(268 if grid.columns == 3 else 400, 32)
		# Long option lists read better in the book face's plainer companion.
		b.add_theme_font_override("font", ThemeDB.fallback_font)
		b.clip_text = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not o.legal and not picked
		var pressed := UiKit.button_style("hover")
		pressed.border_color = Look.color("gilt_light")
		pressed.set_border_width_all(2)
		b.add_theme_stylebox_override("pressed", pressed)
		b.add_theme_stylebox_override("hover_pressed", pressed)
		b.add_theme_color_override("font_pressed_color", Look.color("gilt_light"))
		b.add_theme_color_override("font_hover_pressed_color", Look.color("gilt_light"))
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
		var summary := o.summary
		var reason := "" if o.legal else "Can't pick: " + o.reason
		var label := o.label
		var b := UiParts.tip_button("%s +%d" % [o.label, times] if times > 0 else o.label, func() -> void: pass, func() -> Control:
			return UiParts.rules_tip(label, "", summary, [], reason), times > 0, 14)
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
