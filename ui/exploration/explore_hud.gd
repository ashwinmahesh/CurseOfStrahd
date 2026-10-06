class_name ExploreHud
extends CanvasLayer
## The exploration screen (plan §5.2): party cards with framed portraits, Hit Points bars, conditions and the
## level-up badge (click to lead, right-click for the sheet), the location and time, the Narrator's box, the hover hint
## for what a click will do, toasts and the last roll on dark plates, and the command bar for the character,
## inventory, journal, rest, search, sneak and split.

signal leader_picked(index: int)
signal sheet_requested(index: int)
signal command(name: String)

var st: StoryState
var _party_box: VBoxContainer
var _where: Label
## The width of the top-right block the location's name has to fit.
const WHERE_WIDTH := 346.0
var _mode: Label
var _narr: RichTextLabel
var _narr_time := 0.0
var _hint: Label
var _toast: Label
var _toast_time := 0.0
var _roll: Label
var _roll_time := 0.0
var _hint_panel: PanelContainer
var _toast_panel: PanelContainer
var _roll_panel: PanelContainer
## The current location at the top right, north up, following the party (ui/exploration/minimap.gd).
var minimap: Minimap
## Ways out to other regions marked over the world (ui/exploration/exit_signs.gd).
var exit_signs: ExitSigns

## [label, key, command, icon (art/ui/icons)]
const BUTTONS := [["Character", "C", "sheet", "character"], ["Inventory", "I", "inventory", "inventory"],
	["Journal", "J", "journal", "journal"], ["Party", "P", "party", "party"], ["Map", "M", "map", "map"],
	["Rest", "R", "rest", "rest"], ["Search", "F", "search", "search"], ["Sneak", "V", "sneak", "sneak"],
	["Split", "G", "split", "split"], ["Menu", "Esc", "menu", "menu"]]


func _init() -> void:
	name = "ExploreHud"
	layer = 10


func build(state: StoryState) -> void:
	st = state
	exit_signs = ExitSigns.new()
	add_child(exit_signs)
	_party_box = VBoxContainer.new()
	_party_box.position = Vector2(12, 12)
	_party_box.add_theme_constant_override("separation", 6)
	add_child(_party_box)
	var top := VBoxContainer.new()
	top.anchor_left = 1.0
	top.anchor_right = 1.0
	top.offset_left = -360
	top.offset_right = -14
	top.offset_top = 12
	# Anything wider than the block grows it leftward, never off the right edge of the screen.
	top.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap = Minimap.new()
	minimap.size_flags_horizontal = Control.SIZE_SHRINK_END
	top.add_child(minimap)
	_where = _label("", 24, "gilt_light")
	_where.add_theme_font_override("font", UiKit.display_font())
	_where.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_where.custom_minimum_size = Vector2(WHERE_WIDTH, 0)
	top.add_child(_where)
	_mode = _label("", 15, "parchment")
	_mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_mode)
	add_child(top)
	var narr_panel := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(Look.color("ui_black"), 0.85)
	s.border_color = Look.color("gilt_dark")
	s.set_border_width_all(2)
	s.set_corner_radius_all(2)
	s.set_content_margin_all(18)
	narr_panel.add_theme_stylebox_override("panel", s)
	narr_panel.anchor_left = 0.5
	narr_panel.anchor_right = 0.5
	narr_panel.anchor_top = 1.0
	narr_panel.anchor_bottom = 1.0
	narr_panel.offset_left = -420
	narr_panel.offset_right = 420
	narr_panel.offset_top = -196
	narr_panel.offset_bottom = -84
	narr_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_narr = RichTextLabel.new()
	_narr.bbcode_enabled = true
	_narr.fit_content = true
	_narr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_narr.add_theme_font_size_override("italics_font_size", 19)
	_narr.add_theme_font_size_override("normal_font_size", 19)
	narr_panel.add_child(_narr)
	narr_panel.name = "NarratorBox"
	UiKit.trim(narr_panel, 56.0)
	narr_panel.visible = false
	add_child(narr_panel)
	_hint = _label("", 15, "gilt_light")
	_hint_panel = _plate(_hint, 8)
	_hint_panel.visible = false
	add_child(_hint_panel)
	_toast = _label("", 19, "gilt_light")
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_panel = _plate(_toast, 12)
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_panel.offset_top = 70
	_toast_panel.visible = false
	add_child(_toast_panel)
	_roll = _label("", 14, "parchment")
	_roll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_roll.custom_minimum_size = Vector2(520, 0)
	_roll_panel = _plate(_roll, 8)
	_roll_panel.anchor_top = 1.0
	_roll_panel.anchor_bottom = 1.0
	_roll_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_roll_panel.offset_left = 14
	_roll_panel.offset_bottom = -78
	_roll_panel.visible = false
	add_child(_roll_panel)
	# The command bar sits on a dark plate with gilt corners, like the frames of the menus it opens.
	var plate := PanelContainer.new()
	var ps := UiKit.style("ui_black", "gilt_dark", 2, 0.88)
	ps.content_margin_left = 16
	ps.content_margin_right = 16
	ps.content_margin_top = 7
	ps.content_margin_bottom = 7
	plate.add_theme_stylebox_override("panel", ps)
	plate.anchor_left = 0.5
	plate.anchor_right = 0.5
	plate.anchor_top = 1.0
	plate.anchor_bottom = 1.0
	plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	plate.offset_bottom = -10
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.trim(plate, 30.0)
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 6)
	plate.add_child(bar)
	for b: Array in BUTTONS:
		var cmd := str(b[2])
		var btn := UiKit.button("", func() -> void: command.emit(cmd), 14, str(b[3]))
		btn.tooltip_text = "%s (%s)" % [b[0], b[1]]
		btn.name = str(b[0])
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_constant_override("icon_max_width", 30)
		btn.custom_minimum_size = Vector2(52, 48)
		btn.expand_icon = false
		bar.add_child(btn)
	add_child(plate)
	refresh()


func refresh(location_name: String = "", sneaking: bool = false, solo: bool = false) -> void:
	if st == null:
		return
	for c in _party_box.get_children():
		c.queue_free()
	for i in st.party.size():
		var ch := st.party[i]
		var lead := i == 0
		var card := PanelContainer.new()
		var s := UiKit.style("ui_black", "gilt_light" if lead else "gilt_dark", 2, 0.9)
		s.set_content_margin_all(6)
		s.content_margin_right = 10
		card.add_theme_stylebox_override("panel", s)
		card.custom_minimum_size = Vector2(236, 0)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)
		row.add_child(UiParts.framed_portrait(CombatToken.art_for(ch), 58.0, ch.hp <= 0, ch.dead))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 3)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 4)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var n := _label(("★ " if lead else "") + ch.name.get_slice(" ", 0), 16, "gilt_light" if lead else "vellum")
		n.add_theme_font_override("font", UiKit.display_font())
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(n)
		head.add_child(_label("Lv %d" % ch.character_level(), 12, "parchment"))
		v.add_child(head)
		var bar := UiParts.hp_bar(ch, 150.0, 10.0, false)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(bar)
		var info := HBoxContainer.new()
		info.add_theme_constant_override("separation", 6)
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(_label("%d / %d" % [ch.hp, ch.max_hp()], 12, "vellum"))
		var conds := ch.active_conditions()
		var state := ""
		if ch.dead:
			state = "Dead"
		elif ch.hp <= 0:
			state = "Down"
		elif ch.is_bloodied():
			state = "Bloodied"
		if state != "":
			info.add_child(_label(state, 12, "vampire_red"))
		if not conds.is_empty():
			info.add_child(_label(", ".join(conds.map(func(c: StringName) -> String: return str(c).capitalize())), 12, "rose"))
		v.add_child(info)
		if st.can_level_up(ch):
			v.add_child(_label("▲ Level up!", 13, "bile"))
		row.add_child(v)
		var btn := Button.new()
		btn.flat = true
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.focus_mode = Control.FOCUS_NONE
		for st_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			btn.add_theme_stylebox_override(st_name, StyleBoxEmpty.new())
		btn.tooltip_text = "%s · %s\nClick: lead · Right-click: sheet" % [ch.name, ch.class_summary()]
		var idx := i
		btn.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
				if (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
					leader_picked.emit(idx)
				elif (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
					sheet_requested.emit(idx))
		card.add_child(btn)
		_party_box.add_child(card)
	# Guests (story allies the player commands, ADR 0010): a smaller frame in moonlight, marked as a guest.
	for gi in st.guests.size():
		var g := st.guests[gi]
		var gcard := PanelContainer.new()
		var gs := UiKit.style("ui_black", "moonlight", 2, 0.85)
		gs.set_content_margin_all(5)
		gcard.add_theme_stylebox_override("panel", gs)
		gcard.custom_minimum_size = Vector2(236, 0)
		var grow := HBoxContainer.new()
		grow.add_theme_constant_override("separation", 8)
		gcard.add_child(grow)
		var npc := Compendium.shared().get_entry("npcs", st.guest_ids[gi])
		grow.add_child(UiParts.framed_portrait(str(npc.get("portrait", st.guest_ids[gi])), 42.0, g.hp <= 0))
		var gv := VBoxContainer.new()
		gv.add_theme_constant_override("separation", 3)
		var ghead := HBoxContainer.new()
		ghead.add_theme_constant_override("separation", 6)
		ghead.add_child(_label(g.name, 14, "moonlight"))
		ghead.add_child(UiParts.pill("Guest", "moonlight", 11))
		gv.add_child(ghead)
		gv.add_child(UiParts.hp_bar(g, 150.0, 8.0, false))
		grow.add_child(gv)
		_party_box.add_child(gcard)
	if location_name != "":
		_fit_where(location_name)
	var hours := st.minute_of_day / 60
	_mode.text = "Day %d · %02d:%02d%s%s · %d gp" % [st.day, hours, st.minute_of_day % 60, " · Sneaking" if sneaking else "",
		" · Split party" if solo else "", int(st.gold)]


## The location's name at the top right: the book hand at 24 px, smaller for a long name ("The Amber Temple: Hall of
## the Faceless God"), broken after a colon onto a second line, and wrapped if it still doesn't fit.
func _fit_where(text: String) -> void:
	var font := UiKit.display_font()
	var size := 24
	while size > 18 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > WHERE_WIDTH:
		size -= 1
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > WHERE_WIDTH and text.contains(": "):
		text = text.replace(": ", ":\n")
	_where.add_theme_font_size_override("font_size", size)
	_where.text = text


## A new location: the minimap and the signs at its ways out.
func show_location(view: LocationView) -> void:
	minimap.show_location(view)
	exit_signs.show_location(view)


func narrate(text: String) -> void:
	var box := get_node("NarratorBox") as PanelContainer
	box.visible = true
	_narr.text = "[i][color=#%s]%s[/color][/i]" % [Look.color("parchment").to_html(false), text.replace("[", "[lb]")]
	_narr_time = clampf(3.0 + text.length() * 0.05, 4.0, 10.0)


func hint(text: String, at: Vector2) -> void:
	_hint.text = (text + "\nRight-click: more") if text != "" else ""
	_hint_panel.visible = text != ""
	_hint_panel.reset_size()
	_hint_panel.position = at + Vector2(18, 14)


func toast(text: String) -> void:
	_toast.text = text
	_toast_time = 2.5
	_toast_panel.visible = text != ""
	_toast_panel.modulate.a = 1.0
	_toast_panel.reset_size()
	_toast_panel.offset_left = -_toast_panel.size.x / 2.0
	_toast_panel.offset_right = _toast_panel.size.x / 2.0


func roll(text: String) -> void:
	_roll.text = text
	_roll_time = 8.0
	_roll_panel.visible = text != ""
	_roll_panel.modulate.a = 1.0


## A dark plate with a fine gilt edge behind a floating line of text (hints, toasts, the last roll).
func _plate(content: Control, margin: int) -> PanelContainer:
	var p := PanelContainer.new()
	var s := UiKit.style("ui_black", "gilt_dark", 1, 0.9)
	s.set_content_margin_all(margin)
	s.content_margin_top = margin * 0.6
	s.content_margin_bottom = margin * 0.6
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(content)
	return p


func _process(delta: float) -> void:
	if _narr_time > 0.0:
		_narr_time -= delta
		if _narr_time <= 0.0:
			(get_node("NarratorBox") as PanelContainer).visible = false
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast_panel.modulate.a = clampf(_toast_time, 0.0, 1.0)
		_toast_panel.visible = _toast_time > 0.0
	if _roll_time > 0.0:
		_roll_time -= delta
		_roll_panel.modulate.a = clampf(_roll_time, 0.0, 1.0)
		_roll_panel.visible = _roll_time > 0.0


func _label(text: String, size: int, colour: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Look.color(colour))
	l.add_theme_color_override("font_outline_color", Look.color("void"))
	l.add_theme_constant_override("outline_size", 5)
	return l
