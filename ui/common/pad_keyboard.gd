class_name PadKeyboard
extends CanvasLayer
## Typing with a pad (U6, docs/ui/controller.md): A on a text field opens this board over the screen (PadNav). The
## D-pad moves over the keys and A types the one with focus; X deletes a letter, Y puts a space, LB switches capitals,
## Start or Done puts the text in the field (as if Enter were pressed there), and B leaves the field as it was. A
## TextEdit (the sheet's notes) gets a key for a new line.

signal done(text: String)

const ROWS: Array[String] = ["1234567890", "qwertyuiop", "asdfghjkl'", "zxcvbnm,.-"]
const KEY := Vector2(58, 52)

var field: Control
var text := ""
var caps := true
var _shown: Label
var _keys: Array[Button] = []


## Opens a board for `field_` (a LineEdit or TextEdit) over everything but the rules cards.
static func open_for(field_: Control) -> PadKeyboard:
	var k := PadKeyboard.new()
	k.field = field_
	k.text = str(field_.get("text"))
	k.caps = k.text == "" or k.text.ends_with(" ")
	field_.get_tree().root.add_child(k)
	return k


func _init() -> void:
	name = "PadKeyboard"
	layer = 99
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(Look.color("void"), 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_meta(&"pad_skip", true)
	add_child(dim)
	var plate := PanelContainer.new()
	plate.name = "Board"
	var s := UiKit.style("ui_black", "gilt", 2, 0.97)
	s.set_content_margin_all(18)
	plate.add_theme_stylebox_override("panel", s)
	plate.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 40)
	plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(plate)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	plate.add_child(col)
	var placeholder := str(field.get("placeholder_text")) if "placeholder_text" in field else ""
	col.add_child(UiKit.label(placeholder if placeholder != "" else "Type", 14, "parchment"))
	_shown = UiKit.label("", 22, "vellum", KEY.x * 10.0 + 40.0)
	_shown.name = "Text"
	col.add_child(_shown)
	for row: String in ROWS:
		var line := HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_theme_constant_override("separation", 4)
		for ch in row:
			line.add_child(_key(ch, func() -> void: type(_cased(ch))))
		col.add_child(line)
	var last := HBoxContainer.new()
	last.alignment = BoxContainer.ALIGNMENT_CENTER
	last.add_theme_constant_override("separation", 4)
	last.add_child(_key("Caps", toggle_caps, 1.6))
	last.add_child(_key("Space", func() -> void: type(" "), 3.0))
	if field is TextEdit:
		last.add_child(_key("New line", func() -> void: type("\n"), 1.8))
	last.add_child(_key("Delete", erase, 1.6))
	var ok := _key("Done", finish, 1.6)
	ok.name = "Done"
	UiParts.light_up(ok)
	last.add_child(ok)
	col.add_child(last)
	var hint := UiKit.label("", 13, "parchment")
	PadGlyphs.hint(hint, "Click the keys", "{a} types  ·  {x} deletes  ·  {y} space  ·  {lb} capitals  ·  {start} done  ·  {b} leaves it as it was")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	_keys[ROWS[0].length()].set_meta(&"pad_first", true)   # the board opens on the letters (q)
	_refresh()


func _key(label: String, on_press: Callable, wide: float = 1.0) -> Button:
	var b := UiKit.button(label, on_press, 18)
	if label.length() == 1:
		# A letter key in the plain face the typed text uses: in the book hand h and b, d and dl looked alike (UI QA UI-21).
		b.remove_theme_font_override("font")
		b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size = Vector2(KEY.x * wide, KEY.y)
	b.focus_mode = Control.FOCUS_NONE
	b.set_meta(&"letter", label)
	_keys.append(b)
	return b


func _cased(ch: String) -> String:
	return ch.to_upper() if caps else ch


func type(s: String) -> void:
	text += s
	if caps and s.strip_edges() != "" and field is LineEdit:
		caps = false   # a capital starts a word
	_refresh()


func erase() -> void:
	text = text.left(maxi(0, text.length() - 1))
	_refresh()


func toggle_caps() -> void:
	caps = not caps
	_refresh()


func _refresh() -> void:
	_shown.text = text + "▏"
	for b in _keys:
		var l := str(b.get_meta(&"letter"))
		if l.length() == 1:
			b.text = _cased(l)


## Done: the field takes the text, as if it were typed there and Enter pressed.
func finish() -> void:
	var le := field as LineEdit
	if le != null and is_instance_valid(le):
		var limit := le.max_length
		le.text = text if limit <= 0 else text.left(limit)
		le.text_changed.emit(le.text)
		le.text_submitted.emit(le.text)
	var te := field as TextEdit
	if te != null and is_instance_valid(te):
		te.text = text
		te.text_changed.emit()
	done.emit(text)
	_close()


func _close() -> void:
	queue_free()
	if is_instance_valid(field) and field.is_visible_in_tree():
		field.grab_focus.call_deferred()


## B (or Escape) leaves the field as it was.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"combat_cancel"):
		get_viewport().set_input_as_handled()
		_close()


## The pad's buttons on the board (PadNav asks first): X deletes, Y a space, LB capitals, Start done.
func pad_button(button: JoyButton) -> bool:
	match button:
		JOY_BUTTON_X:
			erase()
		JOY_BUTTON_Y:
			type(" ")
		JOY_BUTTON_LEFT_SHOULDER:
			toggle_caps()
		JOY_BUTTON_START:
			finish()
		_:
			return false
	return true


func pad_prompts() -> Array:
	return [["x", "Delete"], ["y", "Space"], ["lb", "Capitals"], ["start", "Done"]]
