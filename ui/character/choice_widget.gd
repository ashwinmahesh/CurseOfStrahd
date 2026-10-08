class_name ChoiceWidget
extends VBoxContainer
## One character-building choice (plan §5.6 "a new subclass or feat needs data, never new UI code"): a box titled
## with its count ("Skills · choose 2 of 9 · 2 of 2 ✓") and its options as toggles. Options that can't be picked stay
## visible, greyed, with the engine's reason; weak ones show ~ and the warning. Picking more than the count replaces
## the oldest pick. Works for every Choice.kind; ability increases allow the same ability twice. Inside a swap chance
## (a Long Rest, a level up) a line says what may change, and picks that have to stay say why on hover.

signal picks_changed(key: String, picks: Array)

var choice: Choice
## Feat lists (level 4's Ability Score Improvement, an origin feat, a Fighting Style) show the highlighted feat's full
## text in a panel on the right (owner, 2026-10-07: long feats didn't fit a tooltip): the option under the mouse, else
## the one picked, else the first that can be taken.
const SPLIT_KINDS: Array[String] = ["feat", "fighting_style"]
const SPELL_KINDS: Array[String] = ["cantrip", "spell", "spellbook"]
## The list and the panel scroll on their own past this height, so the panel stays beside the list.
const SPLIT_HEIGHT := 470.0
var _detail: VBoxContainer
var _detail_scroll: ScrollContainer
var _shown := ""


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
	var note := ChoiceOptions.swap_note(choice)
	if note != "":
		# It wraps at whatever width the screen gives the choice: a fixed 1100 was wider than Level Up's list, and pushed
		# the whole frame off the right of the screen (UI QA UI-03).
		add_child(UiKit.label(note, 14, "moonlight", 600))
	if choice.kind == "ability_increase":
		_ability_rows()
		return
	var split := choice.kind in SPLIT_KINDS and choice.options.size() > 1
	var grid := GridContainer.new()
	grid.columns = 2 if split else (3 if choice.options.size() > 8 else 2)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 5)
	# Spells go under a heading per spell level, alphabetical within it (SpellGroups).
	var spells := choice.kind in SPELL_KINDS
	var options: Array = SpellGroups.sorted(choice.options, func(o: ChoiceOption) -> String: return o.id) if spells else choice.options
	var level_now := -1
	var grids: Array[GridContainer] = [grid]
	for ov: Variant in options:
		var o := ov as ChoiceOption
		if spells and SpellGroups.level_of(o.id) != level_now:
			level_now = SpellGroups.level_of(o.id)
			if grid.get_child_count() > 0:
				grid = GridContainer.new()
				grid.columns = grids[0].columns
				grid.add_theme_constant_override("h_separation", 6)
				grid.add_theme_constant_override("v_separation", 5)
				grids.append(grid)
			grid.set_meta(&"heading", SpellGroups.heading(level_now))
		var picked := o.id in choice.picks
		var mark := "◆ " if picked else ("✕ " if not o.legal else ("~ " if o.warning != "" else "◇ "))
		var tip := o.summary
		var foot := ""
		if not o.legal:
			foot = "Can't pick: " + o.reason
		elif o.locked:
			foot = "Stays: " + o.reason
		elif o.warning != "":
			foot = "~ " + o.warning
		var label := o.label
		var b := UiParts.tip_button(mark + o.label, func() -> void: pass, func() -> Control:
			return UiParts.rules_tip(label, "", tip, [], foot), picked, 14)
		if split:
			# The panel on the right is the description; no tooltip over it.
			b.tooltip_text = ""
			b.tip = Callable()
			var oid := o.id
			b.mouse_entered.connect(func() -> void: show_detail(oid))
			b.focus_entered.connect(func() -> void: show_detail(oid))
		b.toggle_mode = true
		b.button_pressed = picked
		if choice.kind in ["cantrip", "spell", "spellbook"]:
			UiParts.icon_on_button(b, "spell", o.id, 26)
		b.custom_minimum_size = Vector2(268 if grid.columns == 3 or split else 400, 32)
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
	if split:
		_build_split(grid)
	elif spells:
		for g in grids:
			if g.get_child_count() == 0:
				continue
			# A heading only when the list spans more than one level.
			if grids.size() > 1 or choice.kind == "spellbook":
				var cap := UiParts.caption(str(g.get_meta(&"heading", "")).to_upper(), 12, "gilt")
				add_child(cap)
			add_child(g)
	else:
		add_child(grid)


## The list on the left (its own scroll past SPLIT_HEIGHT) and the description panel on the right.
func _build_split(grid: GridContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var list := ScrollContainer.new()
	list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.custom_minimum_size = Vector2(grid.get_combined_minimum_size().x + 14, minf(grid.get_combined_minimum_size().y, SPLIT_HEIGHT))
	list.follow_focus = true
	list.add_child(grid)
	# Off the list, the panel goes back to the feat that's picked.
	list.mouse_exited.connect(func() -> void:
		if not list.get_global_rect().has_point(list.get_global_mouse_position()):
			show_detail(_default_detail()))
	row.add_child(list)
	var panel := PanelContainer.new()
	var ps := UiKit.style("ui_black", "gilt_dark", 2, 0.92)
	ps.set_corner_radius_all(10)
	ps.corner_detail = 1
	ps.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", ps)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(380, list.custom_minimum_size.y)
	UiKit.trim(panel, 48.0)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 8)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.add_child(_detail)
	panel.add_child(_detail_scroll)
	row.add_child(panel)
	add_child(row)
	show_detail(_default_detail())


func _default_detail() -> String:
	if not choice.picks.is_empty():
		return choice.picks[0]
	for o in choice.options:
		if o.legal:
			return o.id
	return choice.options[0].id if not choice.options.is_empty() else ""


## Fills the panel with option `id`'s full text: its name, kind and prerequisite, the summary, each benefit (and a
## Dark Gift's drawback) with how it's used, any ability increase, and why it can't be taken if it can't.
func show_detail(id: String) -> void:
	if _detail == null or id == _shown or id == "":
		return
	_shown = id
	for c in _detail.get_children():
		c.queue_free()
	var o := choice.option(id)
	if o == null:
		return
	var width := maxf(300.0, _detail_scroll.size.x - 16.0) if _detail_scroll.size.x > 0.0 else 420.0
	var f := Compendium.shared().get_entry("feats", id)
	var name_ := UiKit.label(str(f.get("name", o.label)), 22, "gilt_light")
	name_.add_theme_font_override("font", UiKit.display_font())
	_detail.add_child(name_)
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 6)
	var cat := str(f.get("category", ""))
	if cat != "":
		tags.add_child(UiParts.pill({"dark_gift": "Dark Gift", "fighting_style": "Fighting Style", "origin": "Origin feat",
			"general": "General feat", "epic_boon": "Epic Boon"}.get(cat, cat.capitalize()) as String, "rose" if cat == "dark_gift" else "gilt", 12))
	if bool(f.get("repeatable", false)):
		tags.add_child(UiParts.pill("Repeatable", "moonlight", 12))
	var pre := str((f.get("prerequisites", {}) as Dictionary).get("text", ""))
	if pre != "":
		tags.add_child(UiParts.pill("Needs: " + pre, "parchment", 12))
	if tags.get_child_count() > 0:
		_detail.add_child(tags)
	var summary := str(f.get("summary", o.summary))
	if summary != "":
		var sl := UiKit.label(summary, 15, "parchment", width)
		_detail.add_child(sl)
	var inc := f.get("ability_increase", {}) as Dictionary
	if not inc.is_empty():
		var names: Array[String] = []
		for a: Variant in inc.get("from", []):
			names.append(str(Creature.ABILITY_NAMES.get(StringName(str(a)), str(a))))
		var pts := int(inc.get("points", 1))
		var line := ("+%d to %s" % [pts, names[0]]) if names.size() == 1 else ("%d points among %s" % [pts, ", ".join(names)])
		_detail.add_child(UiKit.label("Ability increase: %s (to a maximum of %d)" % [line, int(inc.get("max", 20))], 14, "bile", width))
	for bv: Variant in f.get("benefits", []):
		_benefit(bv as Dictionary, width, "gilt")
	if f.has("drawback"):
		_benefit(f["drawback"] as Dictionary, width, "vampire_red", "Drawback · ")
	if not o.legal:
		_detail.add_child(UiKit.label("Can't pick: " + o.reason, 14, "vampire_red", width))
	elif o.warning != "":
		_detail.add_child(UiKit.label("~ " + o.warning, 14, "gilt", width))
	_detail_scroll.scroll_vertical = 0


func _benefit(b: Dictionary, width: float, colour: String, prefix: String = "") -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var n := UiKit.label(prefix + str(b.get("name", "")), 16, colour)
	n.add_theme_font_override("font", UiKit.display_font())
	head.add_child(n)
	var tag := UiParts.ACTION_TAGS.get(str(b.get("action", "passive")), []) as Array
	if not tag.is_empty():
		head.add_child(UiParts.pill(str(tag[0]), str(tag[1]), 11))
	_detail.add_child(head)
	var text := str(b.get("text", b.get("summary", "")))
	if text != "":
		_detail.add_child(UiKit.label(text, 14, "vellum", width))


func _title() -> String:
	var base := choice.label if choice.label != "" else choice.kind.replace("_", " ").capitalize()
	if choice.source != "" and not base.contains(choice.source):
		base = "%s · %s" % [choice.source, base]
	return "%s · choose %d" % [base, choice.count]


func _status_text() -> String:
	var n := choice.picks.size()
	return "  %d of %d %s" % [n, choice.count, "✓" if choice.is_complete() else "!"]


func _toggle(id: String, on: bool) -> void:
	picks_changed.emit(choice.key, ChoiceOptions.toggled(choice, id, on))


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
