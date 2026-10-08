class_name ExploreHud
extends CanvasLayer
## The exploration screen (plan §5.2): party cards with framed portraits, Hit Points bars, conditions and the
## level-up badge (click to lead, right-click for the sheet), the location and time, the Narrator's box, the hover hint
## for what a click will do, toasts and the last roll on dark plates, and the command bar for the character,
## inventory, journal, rest, search, sneak, split and turn-based exploring.

signal leader_picked(index: int)
signal sheet_requested(index: int)
signal command(name: String)

var st: StoryState
var _party_box: VBoxContainer
var _where: Label
## The width of the top-right block the location's name has to fit.
const WHERE_WIDTH := 346.0
var _mode: Label
## The current objective under the time (the newest open quest's), a click opens the journal.
var _goal: Label
## Toasts that came while another was up, shown one after another.
var _toast_queue: Array[String] = []
## The command bar's buttons by command, so Sneak and Split can light up while they're on.
var _bar_buttons: Dictionary = {}
var _narr: RichTextLabel
var _narr_time := 0.0
var _narr_face: Control
var _hint: Label
var _toast: Label
var _toast_time := 0.0
var _roll: Label
var _roll_time := 0.0
var _saved: Label
var _saved_time := 0.0
var _hint_panel: PanelContainer
var _toast_panel: PanelContainer
var _roll_panel: PanelContainer
## The current location at the top right, north up, following the party (ui/exploration/minimap.gd).
var minimap: Minimap
## Ways out to other regions marked over the world (ui/exploration/exit_signs.gd).
var exit_signs: ExitSigns
## Names over everything usable while Alt is held (ui/exploration/thing_labels.gd).
var thing_labels: ThingLabels

## The exploring controls card (F1), like the one in fights.
const CONTROLS: Array[String] = [
	"Mouse: click the floor to walk there; click a person, door, chest or thing to use it (the hint says what a click will do); right-click it for everything you can do; the mouse wheel zooms.",
	"Hold Alt to see the names of everything you can use nearby. Hold L to see what each foe in sight can see (always shown while sneaking).",
	"Keyboard: WASD or the arrows walk · Q / E turn the camera · 1-4 or Tab pick who leads · C character · I inventory · J journal · P party · M map · R rest · F search · V sneak · G split the party · T turn-based (Space ends the round) · F5 quicksave · F9 load it · Esc menu.",
	"In conversations: 1-9 pick an answer · Space, Enter or a click goes on · H shows what's been said.",
	"Controller: left stick walks · A uses what's beside you · Back opens its menu · X searches · Y journal · LB / RB character and inventory · Start menu.",
]
var _controls: PanelContainer

## [label, key, command, icon (art/ui/icons)]
const BUTTONS := [["Character", "C", "sheet", "character"], ["Inventory", "I", "inventory", "inventory"],
	["Journal", "J", "journal", "journal"], ["Party", "P", "party", "party"], ["Map", "M", "map", "map"],
	["Rest", "R", "rest", "rest"], ["Search", "F", "search", "search"], ["Sneak", "V", "sneak", "sneak"],
	["Split", "G", "split", "split"], ["Turn-based", "T", "plan", "plan"], ["Menu", "Esc", "menu", "menu"]]


func _init() -> void:
	name = "ExploreHud"
	layer = 10


func build(state: StoryState) -> void:
	st = state
	exit_signs = ExitSigns.new()
	add_child(exit_signs)
	thing_labels = ThingLabels.new()
	add_child(thing_labels)
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
	_goal = _label("", 14, "gilt_light")
	_goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal.custom_minimum_size = Vector2(WHERE_WIDTH, 0)
	_goal.mouse_filter = Control.MOUSE_FILTER_STOP
	_goal.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_goal.gui_input.connect(func(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			command.emit("journal"))
	top.add_child(_goal)
	add_child(top)
	var narr_panel := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(Look.color("ui_black"), 0.85)
	s.border_color = Look.color("gilt_dark")
	s.set_border_width_all(2)
	# Bevelled corners like every other panel (owner, 2026-10-06: not plain squares).
	s.set_corner_radius_all(10)
	s.corner_detail = 1
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
	# Long passages grow the box upward, clear of the command bar. A click on it (or Esc) puts it away.
	narr_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	narr_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	narr_panel.gui_input.connect(func(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			narr_panel.accept_event()
			close_narration())
	var narr_row := HBoxContainer.new()
	narr_row.add_theme_constant_override("separation", 14)
	narr_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	narr_panel.add_child(narr_row)
	# Who's speaking: the Narrator's portrait, or the one party member a banter line comes from.
	_narr_face = CenterContainer.new()
	_narr_face.custom_minimum_size = Vector2(76, 76)
	_narr_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	narr_row.add_child(_narr_face)
	var narr_col := VBoxContainer.new()
	narr_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	narr_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	narr_row.add_child(narr_col)
	_narr = RichTextLabel.new()
	_narr.bbcode_enabled = true
	_narr.fit_content = true
	_narr.custom_minimum_size = Vector2(680, 0)
	_narr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_narr.add_theme_font_size_override("italics_font_size", 19)
	_narr.add_theme_font_size_override("normal_font_size", 19)
	narr_col.add_child(_narr)
	var close_hint := _label("Click or Esc to close", 12, "parchment")
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	narr_col.add_child(close_hint)
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
	_controls = UiKit.panel("ui_black", "gilt_dark")
	var cs := _controls.get_theme_stylebox("panel") as StyleBoxFlat
	cs.set_corner_radius_all(10)
	cs.corner_detail = 1
	cs.set_content_margin_all(22)
	UiKit.trim(_controls, 56.0)
	_controls.anchor_left = 0.5
	_controls.anchor_right = 0.5
	_controls.offset_left = -440
	_controls.offset_right = 440
	_controls.offset_top = 140
	_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls.visible = false
	var cbox := VBoxContainer.new()
	cbox.add_theme_constant_override("separation", 8)
	cbox.add_child(_label("Controls (F1 to close)", 20, "gilt_light"))
	for line: String in CONTROLS:
		var l := _label(line, 15, "vellum")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(820, 0)
		cbox.add_child(l)
	_controls.add_child(cbox)
	add_child(_controls)
	var f1 := _label("F1: controls", 12, "gilt_dark")
	f1.anchor_top = 1.0
	f1.anchor_bottom = 1.0
	f1.offset_left = 16
	f1.offset_top = -30
	f1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(f1)
	# A quiet "Autosaved" at the bottom right when the game saves itself.
	_saved = _label("◆ Autosaved", 14, "gilt")
	_saved.anchor_left = 1.0
	_saved.anchor_right = 1.0
	_saved.anchor_top = 1.0
	_saved.anchor_bottom = 1.0
	_saved.offset_left = -170
	_saved.offset_right = -18
	_saved.offset_top = -44
	_saved.offset_bottom = -20
	_saved.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_saved.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_saved.visible = false
	add_child(_saved)
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
		# Its key in the lower corner, so the shortcuts are learned by looking.
		var key := _label(str(b[1]), 10 if str(b[1]).length() > 1 else 12, "gilt_light")
		key.add_theme_constant_override("outline_size", 4)
		key.anchor_left = 1.0
		key.anchor_right = 1.0
		key.anchor_top = 1.0
		key.anchor_bottom = 1.0
		key.offset_left = -26
		key.offset_right = -7
		key.offset_top = -17
		key.offset_bottom = -2
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(key)
		_bar_buttons[cmd] = btn
		bar.add_child(btn)
	add_child(plate)
	refresh()


func refresh(location_name: String = "", sneaking: bool = false, solo: bool = false, planning: bool = false) -> void:
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
	# Sneak, Split and Turn-based read as on while they are.
	for pair: Array in [["sneak", sneaking, "Sneak", "V"], ["split", solo, "Split", "G"], ["plan", planning, "Turn-based", "T"]]:
		var b := _bar_buttons.get(str(pair[0]), null) as Button
		if b != null:
			var on := bool(pair[1])
			b.modulate = Color(1.25, 1.12, 0.8) if on else Color.WHITE
			b.tooltip_text = ("%s (%s) · on" if on else "%s (%s)") % [pair[2], pair[3]]
	# Turn-based exploring's panel takes the top of the screen: toasts drop below it.
	_toast_panel.offset_top = 136 if planning else 70
	_goal.text = _objective()
	_goal.visible = _goal.text != ""
	var hours := st.minute_of_day / 60
	_mode.text = "Day %d · %02d:%02d%s%s%s · %d gp" % [st.day, hours, st.minute_of_day % 60, " · Sneaking" if sneaking else "",
		" · Split party" if solo else "", " · Turn-based" if planning else "", int(st.gold)]


## The newest open quest's first objective ("◆ Follow the hidden stair down"), or "".
func _objective() -> String:
	var newest := ""
	for q in QuestLog.journal(st):
		if str(q["status"]) == "active" and not (q["objectives"] as Array).is_empty():
			newest = str((q["objectives"] as Array)[0])
			_goal_tip = "%s · click for the journal (J)" % q["name"]
	if _goal != null:
		_goal.tooltip_text = _goal_tip
	return ("◆ " + newest) if newest != "" else ""


var _goal_tip := ""


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
	thing_labels.show_location(view, exit_signs.signs)


## Shows a passage in the Narrator's box, with `portrait` (art/portraits/<id>.png; the Narrator's by default, ""
## for none) beside it. It fades on its own after a while, or goes at a click on it or Esc.
func narrate(text: String, portrait: String = DialogueRunner.NARRATOR_PORTRAIT) -> void:
	var box := get_node("NarratorBox") as PanelContainer
	box.visible = true
	for c in _narr_face.get_children():
		c.queue_free()
	_narr_face.visible = portrait != ""
	if portrait != "":
		_narr_face.add_child(UiParts.framed_portrait(portrait, 76.0))
	_narr.text = "[i][color=#%s]%s[/color][/i]" % [Look.color("parchment").to_html(false), text.replace("[", "[lb]")]
	_narr_time = clampf(3.0 + text.length() * 0.05, 4.0, 10.0)
	if GameSettings.narration_stays():
		_narr_time = 1.0e9   # the player keeps it up until they close it (Settings)
	# The Narrator speaks it, if it's recorded (ADR 0013); the box stays up until the voice is done.
	_narr_time = maxf(_narr_time, VoiceOver.say(VoiceOver.NARRATOR, text) + 1.0)


## Keeps the Narrator's box up while a voice is still speaking (ADR 0013).
func hold_narration(seconds: float) -> void:
	_narr_time = maxf(_narr_time, seconds + 1.0)


func narration_showing() -> bool:
	return (get_node("NarratorBox") as PanelContainer).visible


func close_narration() -> void:
	VoiceOver.stop()
	_narr_time = 0.0
	(get_node("NarratorBox") as PanelContainer).visible = false


func hint(text: String, at: Vector2) -> void:
	_hint.text = (text + "\nRight-click: more") if text != "" else ""
	_hint_panel.visible = text != ""
	_hint_panel.reset_size()
	_hint_panel.position = at + Vector2(18, 14)


func toast(text: String) -> void:
	# Another message is still being read: this one waits its turn (unless it's the same again).
	if _toast_time > 1.0 and text != "" and text != _toast.text:
		if not text in _toast_queue:
			_toast_queue.append(text)
		return
	_toast.text = text
	_toast_time = 2.5
	_toast_panel.visible = text != ""
	_toast_panel.modulate.a = 1.0
	_toast_panel.reset_size()
	_toast_panel.offset_left = -_toast_panel.size.x / 2.0
	_toast_panel.offset_right = _toast_panel.size.x / 2.0


func toggle_controls() -> void:
	_controls.visible = not _controls.visible


func controls_showing() -> bool:
	return _controls.visible


## The game just saved itself: a note at the bottom right that fades.
func saved_note() -> void:
	_saved_time = 2.5
	_saved.visible = true
	_saved.modulate.a = 1.0


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
		if _toast_time <= 0.6 and not _toast_queue.is_empty():
			_toast_time = 0.0
			toast(_toast_queue.pop_front())
	if _saved_time > 0.0:
		_saved_time -= delta
		_saved.modulate.a = clampf(_saved_time, 0.0, 1.0)
		_saved.visible = _saved_time > 0.0
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
