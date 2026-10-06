class_name DialogueUI
extends CanvasLayer
## The conversation screen (plan §5.4, §5.7): the speaker's portrait and name, the line, numbered options with
## their skill checks (who rolls, the bonus and the chance), the roll shown in the open, notices (journal, items,
## money, milestones), and the Narrator in italics in a candle-lit frame. It plays a DialogueRunner and never
## decides anything itself. Keys 1-9 pick options; Space, Enter or a click continues; controller: d-pad and A.

signal ended(combat: String)

var runner: DialogueRunner
var _panel: PanelContainer
var _portrait: TextureRect
var _name: Label
var _text: RichTextLabel
var _options: VBoxContainer
var _hint: Label
var _waiting_continue := false
var _option_buttons: Array[Button] = []
var _focus := 0
var _history: Array[String] = []


func _init() -> void:
	name = "DialogueUI"
	layer = 20


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(Look.color("void"), 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_panel = PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(Look.color("ink"), 0.95)
	s.border_color = Look.color("bone_dark")
	s.set_border_width_all(3)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", s)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -640
	_panel.offset_right = 640
	_panel.offset_top = -330
	_panel.offset_bottom = -24
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_panel.add_child(row)
	var left := VBoxContainer.new()
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(200, 200)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left.add_child(_portrait)
	_name = _label("", 22, "flame")
	left.add_child(_name)
	row.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	row.add_child(right)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.custom_minimum_size = Vector2(980, 60)
	_text.add_theme_font_size_override("normal_font_size", 20)
	_text.add_theme_font_size_override("italics_font_size", 20)
	_text.add_theme_color_override("default_color", Look.color("vellum"))
	right.add_child(_text)
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 4)
	right.add_child(_options)
	_hint = _label("Space / click: continue", 13, "parchment")
	right.add_child(_hint)


## Starts a conversation at "file:node". Returns false if it doesn't exist.
func play(r: DialogueRunner, ref: String) -> bool:
	runner = r
	if not runner.start(ref):
		return false
	_advance()
	return true


func _advance() -> void:
	_clear_options()
	var beat := runner.next()
	_show(beat)


func _show(beat: Dictionary) -> void:
	_waiting_continue = false
	match str(beat["kind"]):
		"end":
			ended.emit(str(beat.get("combat", "")))
			queue_free()
		"line":
			_line(beat)
			_waiting_continue = true
		"notice":
			_text.text = "[color=#%s]◆ %s[/color]" % [Look.color("bile").to_html(false), _esc(str(beat["text"]))]
			_waiting_continue = true
		"check":
			var colour := "bile" if bool(beat["success"]) else "vampire_red"
			var said := str(beat.get("said", ""))
			_portrait.texture = null
			_name.text = str(beat["who"])
			_text.text = "%s[color=#%s]%s rolls %s: %d vs DC %d, %s[/color]\n[font_size=14][color=#%s]%s[/color][/font_size]" % [
				("[i]\"%s\"[/i]\n" % _esc(said)) if said != "" else "", Look.color(colour).to_html(false), beat["who"], beat["skill"],
				int(beat["total"]), int(beat["dc"]), "success" if bool(beat["success"]) else "failure",
				Look.color("parchment").to_html(false), _esc(str(beat["detail"]))]
			_waiting_continue = true
		"options":
			_show_options(beat["options"] as Array)
	_hint.visible = _waiting_continue


func _line(beat: Dictionary) -> void:
	if bool(beat["narrator"]):
		_portrait.texture = null
		_name.text = ""
		_text.text = "[i][color=#%s]%s[/color][/i]" % [Look.color("parchment").to_html(false), _esc(str(beat["text"]))]
		return
	_name.text = str(beat["name"])
	var path := "res://art/portraits/%s.png" % beat["portrait"]
	_portrait.texture = load(path) as Texture2D if str(beat["portrait"]) != "" and ResourceLoader.exists(path) else null
	var colour := "moonlight" if bool(beat["party"]) else "vellum"
	_text.text = "[color=#%s]%s[/color]" % [Look.color(colour).to_html(false), _esc(str(beat["text"]))]


func _show_options(options: Array) -> void:
	_option_buttons.clear()
	var i := 0
	for o: Variant in options:
		var opt := o as Dictionary
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 17)
		var label := str(opt["label"])
		var check := opt["check"] as Dictionary
		var extra := ""
		if not check.is_empty():
			extra = "  (%s %+d, %d%%)" % [str(check["who"]).get_slice(" ", 0), int(check["bonus"]), roundi(float(check["chance"]) * 100.0)]
		b.text = "%d. %s%s%s" % [i + 1, (label + " ") if label != "" else "", opt["text"], extra]
		b.flat = true
		b.add_theme_color_override("font_color", Look.color("flame") if label != "" else Look.color("vellum"))
		b.add_theme_color_override("font_hover_color", Look.color("wick"))
		var idx := i
		if not bool(opt.get("enabled", true)):
			b.disabled = true
			b.tooltip_text = str(opt.get("reason", ""))
			b.add_theme_color_override("font_disabled_color", Look.color("ash_violet"))
		b.pressed.connect(func() -> void: _choose(idx))
		_options.add_child(b)
		_option_buttons.append(b)
		i += 1
	_focus = 0
	if not _option_buttons.is_empty():
		_option_buttons[0].grab_focus()


func _choose(i: int) -> void:
	_clear_options()
	_show(runner.choose(i))


func _clear_options() -> void:
	for c in _options.get_children():
		c.queue_free()
	_option_buttons.clear()


func _unhandled_input(event: InputEvent) -> void:
	if runner == null:
		return
	if _waiting_continue:
		var go := event.is_action_pressed(&"combat_confirm") or event.is_action_pressed(&"combat_end_turn") \
			or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
		if go:
			get_viewport().set_input_as_handled()
			_advance()
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		var k := (event as InputEventKey).physical_keycode
		if k >= KEY_1 and k <= KEY_9:
			var idx := int(k - KEY_1)
			if idx < _option_buttons.size():
				get_viewport().set_input_as_handled()
				_choose(idx)


func _label(text: String, size: int, colour: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Look.color(colour))
	l.add_theme_color_override("font_outline_color", Look.color("void"))
	l.add_theme_constant_override("outline_size", 5)
	return l


static func _esc(t: String) -> String:
	return t.replace("[", "[lb]")
