class_name ExploreHud
extends CanvasLayer
## The exploration screen (plan §5.2): party portraits with HP, conditions and the level-up badge (click to lead,
## right-click for the sheet), the location and time, the Narrator's box, the hover hint for what a click will do,
## toasts and the last roll, and buttons for the character, inventory, journal, rest, search, sneak and split.

signal leader_picked(index: int)
signal sheet_requested(index: int)
signal command(name: String)

var st: StoryState
var _party_box: VBoxContainer
var _where: Label
var _mode: Label
var _narr: RichTextLabel
var _narr_time := 0.0
var _hint: Label
var _toast: Label
var _toast_time := 0.0
var _roll: Label
var _roll_time := 0.0
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
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap = Minimap.new()
	minimap.size_flags_horizontal = Control.SIZE_SHRINK_END
	top.add_child(minimap)
	_where = _label("", 24, "gilt_light")
	_where.add_theme_font_override("font", UiKit.display_font())
	_where.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	narr_panel.offset_top = -190
	narr_panel.offset_bottom = -78
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
	_hint = _label("", 16, "gilt_light")
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	_toast = _label("", 20, "gilt_light")
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_left = -400
	_toast.offset_right = 400
	_toast.offset_top = 70
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_toast)
	_roll = _label("", 14, "parchment")
	_roll.anchor_top = 1.0
	_roll.anchor_bottom = 1.0
	_roll.offset_left = 14
	_roll.offset_top = -74
	_roll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_roll.custom_minimum_size = Vector2(560, 0)
	add_child(_roll)
	var bar := HBoxContainer.new()
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -470
	bar.offset_right = 470
	bar.offset_top = -62
	bar.offset_bottom = -14
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 6)
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
	add_child(bar)
	refresh()


func refresh(location_name: String = "", sneaking: bool = false, solo: bool = false) -> void:
	if st == null:
		return
	for c in _party_box.get_children():
		c.queue_free()
	for i in st.party.size():
		var ch := st.party[i]
		var card := PanelContainer.new()
		var s := StyleBoxFlat.new()
		s.bg_color = Color(Look.color("ui_black"), 0.9)
		s.border_color = Look.color("gilt_light") if i == 0 else Look.color("gilt_dark")
		s.set_border_width_all(3 if i == 0 else 2)
		s.set_corner_radius_all(4)
		s.set_content_margin_all(6)
		card.add_theme_stylebox_override("panel", s)
		var row := HBoxContainer.new()
		card.add_child(row)
		var tex := TextureRect.new()
		var path := "res://art/portraits/%s.png" % CombatToken.art_for(ch)
		tex.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
		tex.custom_minimum_size = Vector2(56, 56)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ch.hp <= 0:
			tex.modulate = Color(0.45, 0.45, 0.45)
		row.add_child(tex)
		var v := VBoxContainer.new()
		var name_text := "%s%s" % ["► " if i == 0 else "", ch.name]
		v.add_child(_label(name_text, 15, "vellum"))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(150, 8)
		bar.show_percentage = false
		bar.max_value = maxf(1.0, ch.max_hp())
		bar.value = ch.hp
		var fill := StyleBoxFlat.new()
		fill.bg_color = Look.color("sickly") if ch.hp * 2 > ch.max_hp() else (Look.color("gilt") if ch.hp * 4 > ch.max_hp() else Look.color("crimson"))
		var back := StyleBoxFlat.new()
		back.bg_color = Look.color("void")
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", back)
		v.add_child(bar)
		var info := "%d/%d · Lv %d" % [ch.hp, ch.max_hp(), ch.character_level()]
		var conds := ch.active_conditions()
		if not conds.is_empty():
			info += " · " + ", ".join(conds.map(func(c: StringName) -> String: return str(c).capitalize()))
		v.add_child(_label(info, 12, "parchment"))
		if st.can_level_up(ch):
			v.add_child(_label("▲ Level up!", 13, "bile"))
		row.add_child(v)
		var btn := Button.new()
		btn.flat = true
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.focus_mode = Control.FOCUS_NONE
		var idx := i
		btn.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
				if (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
					leader_picked.emit(idx)
				elif (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
					sheet_requested.emit(idx))
		card.add_child(btn)
		_party_box.add_child(card)
	# Guests (story allies the player commands, ADR 0010): a smaller frame, marked as a guest.
	for gi in st.guests.size():
		var g := st.guests[gi]
		var gcard := PanelContainer.new()
		var gs := StyleBoxFlat.new()
		gs.bg_color = Color(Look.color("ui_black"), 0.85)
		gs.border_color = Look.color("moonlight")
		gs.set_border_width_all(2)
		gs.set_corner_radius_all(4)
		gs.set_content_margin_all(5)
		gcard.add_theme_stylebox_override("panel", gs)
		var grow := HBoxContainer.new()
		gcard.add_child(grow)
		var npc := Compendium.shared().get_entry("npcs", st.guest_ids[gi])
		var gtex := TextureRect.new()
		var gpath := "res://art/portraits/%s.png" % str(npc.get("portrait", st.guest_ids[gi]))
		gtex.texture = load(gpath) as Texture2D if ResourceLoader.exists(gpath) else null
		gtex.custom_minimum_size = Vector2(40, 40)
		gtex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gtex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		grow.add_child(gtex)
		grow.add_child(_label("%s (guest)\n%d/%d" % [g.name, g.hp, g.max_hp()], 12, "moonlight"))
		_party_box.add_child(gcard)
	if location_name != "":
		_where.text = location_name
	var hours := st.minute_of_day / 60
	_mode.text = "Day %d · %02d:%02d%s%s · %d gp" % [st.day, hours, st.minute_of_day % 60, " · Sneaking" if sneaking else "",
		" · Split party" if solo else "", int(st.gold)]


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
	_hint.position = at + Vector2(18, 14)


func toast(text: String) -> void:
	_toast.text = text
	_toast_time = 2.5
	_toast.modulate.a = 1.0


func roll(text: String) -> void:
	_roll.text = text
	_roll_time = 8.0
	_roll.modulate.a = 1.0


func _process(delta: float) -> void:
	if _narr_time > 0.0:
		_narr_time -= delta
		if _narr_time <= 0.0:
			(get_node("NarratorBox") as PanelContainer).visible = false
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)
	if _roll_time > 0.0:
		_roll_time -= delta
		_roll.modulate.a = clampf(_roll_time, 0.0, 1.0)


func _label(text: String, size: int, colour: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Look.color(colour))
	l.add_theme_color_override("font_outline_color", Look.color("void"))
	l.add_theme_constant_override("outline_size", 5)
	return l
