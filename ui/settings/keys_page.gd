class_name KeysPage
extends Control
## Settings' Keys page (Improvement Ideas U5), inside the pause menu's arch: every command's key and alternate under
## its list's heading. Click a key, then press the new one; Escape leaves it as it was and Backspace takes it off. A key
## that another command of the same list had moves over in exchange (InputActions.bind), and the note says so.
## Escape and F1 keep their jobs, so there's always a way back.
## The Controller view (U6, docs/ui/controller.md) does the same for the pad: each command's button (a trigger too),
## press its cap and then the new button; a button another command of the list had moves over in exchange
## (InputActions.pad_bind). B and Start keep their jobs, and so do the sticks and the D-pad's moving, so there's always
## a way round and back. It opens on the controller while a pad is in use.

signal noted(text: String)

## Width of each key cap, in pixels.
const CAP_W := 76.0
const K := PauseMenu.K

## The controller's buttons instead of the keys.
var pad_view := false
var _rows: VBoxContainer
## action -> [key cap, alternate cap]
var _caps: Dictionary = {}
## action -> the controller view's cap
var _pad_caps: Dictionary = {}
## While waiting for a key: [action, slot].
var _waiting: Array = []
## While waiting for a button: the action.
var _waiting_pad := &""


func _ready() -> void:
	pad_view = PadNav.active()
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
	_build()


## The page's lists: the keyboard's or the controller's.
func _build() -> void:
	for c: Node in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	_caps.clear()
	_pad_caps.clear()
	_rows.add_child(_view_switch())
	if pad_view:
		var fixed := _label("B: back  ·  Start: the menu  ·  the sticks and the D-pad's moving stay put", 8.5,
			Color(Look.color("arch_text"), 0.6))
		fixed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rows.add_child(fixed)
		for list: String in InputActions.PAD_LISTS:
			_rows.add_child(_label(str(InputActions.PAD_LISTS[list]), 10.5, Look.color("arch_gold")))
			for c: Array in InputActions.PAD_COMMANDS:
				if str(c[2]) == list:
					_rows.add_child(_pad_row(c[0] as StringName, str(c[1])))
		_refresh_pad()
		return
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


## "Keyboard · Controller" at the top: which list the page shows.
func _view_switch() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "View"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	for v: Array in [["Keyboard", false], ["Controller", true]]:
		var b := Button.new()
		b.name = str(v[0])
		b.text = str(v[0])
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", PauseMenu.serif())
		b.add_theme_font_size_override("font_size", roundi(10.0 * K))
		var on := bool(v[1]) == pad_view
		for k: String in ["font_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, Look.color("arch_gold_light") if on else Color(Look.color("arch_gold"), 0.7))
		b.pressed.connect(func() -> void: show_pad(bool(v[1])))
		row.add_child(b)
	return row


## Shows the controller's buttons (or the keys).
func show_pad(on: bool) -> void:
	if on == pad_view:
		return
	Audio.sfx("click")
	pad_view = on
	_waiting = []
	_waiting_pad = &""
	_build.call_deferred()   # not while the switch that asked is still being pressed


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
		var b := _cap("Key" if slot == 0 else "Alternate")
		b.tooltip_text = "%s: click, then press the new key. Esc keeps it, Backspace clears it." % \
			("The key" if slot == 0 else "A second key")
		b.pressed.connect(func() -> void: _wait(action, slot))
		row.add_child(b)
		caps.append(b)
	_caps[action] = caps
	return row


func _pad_row(action: StringName, what: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = str(action)
	row.add_theme_constant_override("separation", 4)
	var l := _label(what, 9.5, Look.color("arch_text"))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(1, 0)
	row.add_child(l)
	var b := _cap("Button")
	b.custom_minimum_size = Vector2(CAP_W * 1.4, 0)
	b.tooltip_text = "Press it, then the new button (a trigger too)."
	b.pressed.connect(func() -> void: _wait_pad(action))
	row.add_child(b)
	_pad_caps[action] = b
	return row


func _cap(name_: String) -> Button:
	var b := Button.new()
	b.name = name_
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(CAP_W, 0)
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.add_theme_font_override("font", PauseMenu.serif())
	b.add_theme_font_size_override("font_size", roundi(8.5 * K))
	return b


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


## Every controller cap's button as it is now (its name in the pad's family); the one waiting lit.
func _refresh_pad() -> void:
	for action: StringName in _pad_caps:
		var b := _pad_caps[action] as Button
		var waiting := _waiting_pad == action
		var place := InputActions.pad_place(InputActions.pad_code(action))
		b.text = "press a button" if waiting else (PadGlyphs.name_of(place) if place != "" else "—")
		_cap_look(b, waiting, place != "")


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


func _wait_pad(action: StringName) -> void:
	Audio.sfx("click")
	_waiting_pad = action
	_refresh_pad()
	noted.emit("Press the new button. B keeps the old one.")


## While a cap waits, the next key (or pad button) pressed is the new one, before anything else hears it.
func _input(event: InputEvent) -> void:
	if _waiting_pad != &"":
		var jb := event as InputEventJoypadButton
		var jm := event as InputEventJoypadMotion
		if jb != null and jb.pressed:
			get_viewport().set_input_as_handled()
			press_pad(int(jb.button_index))
		elif jm != null and jm.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT] and jm.axis_value > 0.6:
			get_viewport().set_input_as_handled()
			press_pad(InputActions.PAD_TRIGGER + int(jm.axis))
		elif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			press_pad(JOY_BUTTON_B)
		elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
			get_viewport().set_input_as_handled()   # a button let go, a stick: nothing else hears them while it waits
		return
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


## The button (or InputActions.PAD_TRIGGER + a trigger's axis) pressed while a controller cap waits; B keeps the old
## one (tests call it directly).
func press_pad(code: int) -> void:
	if _waiting_pad == &"":
		return
	var action := _waiting_pad
	_waiting_pad = &""
	var note := ""
	if code != JOY_BUTTON_B:
		note = InputActions.pad_bind(action, code)
		Audio.sfx("click")
	_refresh_pad()
	PadGlyphs.refresh_hints()
	noted.emit(note)


## The shown list's keys (or buttons) all back where they started; returns the note saying so.
func reset_view() -> String:
	_waiting = []
	_waiting_pad = &""
	if pad_view:
		InputActions.pad_reset()
		_refresh_pad()
		PadGlyphs.refresh_hints()
		return "Every button is back where it started."
	InputActions.reset()
	_refresh()
	return "Every key is back where it started."


func waiting() -> bool:
	return not _waiting.is_empty() or _waiting_pad != &""
