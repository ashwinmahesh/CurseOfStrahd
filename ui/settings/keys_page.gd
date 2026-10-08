class_name KeysPage
extends Control
## Settings' Keys page (Improvement Ideas U5), inside the pause menu's arch: every command's key and alternate under
## its list's heading. Click a key, then press the new one; Escape leaves it as it was and Backspace takes it off. A key
## that another command of the same list had moves over in exchange (InputActions.bind), and the note says so.
## Escape and F1 keep their jobs, so there's always a way back.

signal noted(text: String)

## Width of each key cap, in pixels.
const CAP_W := 76.0
const K := PauseMenu.K

var _rows: VBoxContainer
## action -> [key cap, alternate cap]
var _caps: Dictionary = {}
## While waiting for a key: [action, slot].
var _waiting: Array = []


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Keys"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.clip_contents = true
	add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 3)
	scroll.add_child(_rows)
	var fixed := _label("Esc: the menu and back  ·  F1: the controls", 8.5, Color(Look.color("arch_text"), 0.6))
	fixed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rows.add_child(fixed)
	for list: String in InputActions.LISTS:
		var head := _label(str(InputActions.LISTS[list]), 10.5, Look.color("arch_gold"))
		_rows.add_child(head)
		for c: Array in InputActions.COMMANDS:
			if str(c[2]) == list:
				_rows.add_child(_row(c[0] as StringName, str(c[1])))
	_refresh()


func _row(action: StringName, what: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = str(action)
	row.add_theme_constant_override("separation", 4)
	var l := _label(what, 9.5, Look.color("arch_text"))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(1, 0)
	row.add_child(l)
	var caps: Array[Button] = []
	for slot in 2:
		var b := Button.new()
		b.name = "Key" if slot == 0 else "Alternate"
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(CAP_W, 0)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.add_theme_font_override("font", PauseMenu.serif())
		b.add_theme_font_size_override("font_size", roundi(8.5 * K))
		b.tooltip_text = "%s: click, then press the new key. Esc keeps it, Backspace clears it." % \
			("The key" if slot == 0 else "A second key")
		b.pressed.connect(func() -> void: _wait(action, slot))
		row.add_child(b)
		caps.append(b)
	_caps[action] = caps
	return row


func _label(text: String, size_u: float, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", PauseMenu.serif())
	l.add_theme_font_size_override("font_size", roundi(size_u * K))
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Every cap's key as it is now; the one waiting for a key lit.
func _refresh() -> void:
	for action: StringName in _caps:
		var keys := InputActions.keys(action)
		var caps := _caps[action] as Array[Button]
		for slot in 2:
			var waiting: bool = not _waiting.is_empty() and _waiting[0] == action and int(_waiting[1]) == slot
			var b := caps[slot]
			b.text = "press a key" if waiting else (InputActions.key_name(keys[slot]) if keys[slot] != KEY_NONE else "—")
			_cap_look(b, waiting, keys[slot] != KEY_NONE)


## The cap's face: a wine plate with a gilt edge, lit while it waits for a key; an empty one fainter.
func _cap_look(b: Button, lit: bool, has_key: bool) -> void:
	for state: String in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		var s := StyleBoxFlat.new()
		var hot := lit or state in ["hover", "hover_pressed", "pressed"]
		s.bg_color = Look.color("arch_button_lit") if hot else Color(Look.color("arch_button"), 1.0 if has_key else 0.5)
		s.border_color = Look.color("arch_gold_light") if hot else Color(Look.color("arch_gold"), 0.8 if has_key else 0.4)
		s.set_border_width_all(1)
		s.set_corner_radius_all(3)
		s.content_margin_left = 4
		s.content_margin_right = 4
		s.content_margin_top = 1
		s.content_margin_bottom = 1
		b.add_theme_stylebox_override(state, s)
	var text_colour := Look.color("arch_gold_light") if lit or has_key else Color(Look.color("arch_text"), 0.45)
	for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, text_colour)


func _wait(action: StringName, slot: int) -> void:
	Audio.sfx("click")
	_waiting = [action, slot]
	_refresh()
	noted.emit("Press the new key for %s. Esc keeps the old one; Backspace clears it." % InputActions.name_of(action))


## While a cap waits, the next key pressed is the new key (before anything else hears it, Escape included).
func _input(event: InputEvent) -> void:
	if _waiting.is_empty():
		return
	var ev := event as InputEventKey
	if ev == null or not ev.pressed or ev.echo:
		return
	get_viewport().set_input_as_handled()
	var key := int(ev.physical_keycode) if ev.physical_keycode != KEY_NONE else int(ev.keycode)
	press(key)


## The key the player pressed while a cap waits (tests call it directly).
func press(key: int) -> void:
	if _waiting.is_empty():
		return
	var action := _waiting[0] as StringName
	var slot := int(_waiting[1])
	_waiting = []
	var note := ""
	if key == KEY_ESCAPE:
		note = ""
	elif key in [KEY_BACKSPACE, KEY_DELETE]:
		InputActions.clear(action, slot)
		note = "%s has no key now." % InputActions.name_of(action) if InputActions.keys(action)[0] == KEY_NONE else ""
	else:
		note = InputActions.bind(action, slot, key)
		Audio.sfx("click")
	_refresh()
	noted.emit(note)


func waiting() -> bool:
	return not _waiting.is_empty()
