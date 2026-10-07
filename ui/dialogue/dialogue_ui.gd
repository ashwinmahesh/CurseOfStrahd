class_name DialogueUI
extends CanvasLayer
## The conversation screen (plan §5.4, §5.7): the speaker's portrait and name, the line, numbered options with
## their skill checks (who rolls, the bonus and the chance), the roll shown in the open, notices (journal, items,
## money, milestones), and the Narrator in italics with their own portrait. It plays a DialogueRunner and never
## decides anything itself. Keys 1-9 pick options; Continue, a click anywhere, Space, Enter or Escape continues (the
## last line ends it); controller: d-pad and A.

signal ended(combat: String)
## A `shop` line: the game opens the shop for `npc` and calls resume() when it closes.
signal shop_requested(npc: String)
## Someone steps into or out of the scene on the map (`appear`, `vanish`).
signal stage_requested(what: String, npc: String, at: String)
## A `respec` pick: the game rebuilds party member `index` and calls resume() when it's done.
signal respec_requested(index: int)

var runner: DialogueRunner
var _panel: PanelContainer
var _portrait: TextureRect
var _name: Label
var _text: RichTextLabel
var _options: VBoxContainer
var _hint: Label
var _continue_row: HBoxContainer
var _waiting_continue := false
var _option_buttons: Array[Button] = []
var _focus := 0
## What's been said in this conversation, for the scroll-back (H or the History button).
var _history: Array[String] = []
var _history_panel: PanelContainer
var _history_text: RichTextLabel
## The keys of the options shown now ("file|text"), to mark the one chosen as already asked.
var _option_keys: Array[String] = []
## The options on screen now (the runner's option dictionaries), for the controller focus and for tests.
var options_shown: Array = []
var _spread: HBoxContainer
var _frame_art: Control
var _options_scroll: ScrollContainer
## The options never take more than this share of the screen's height; past it they scroll.
const OPTIONS_SHARE := 0.45


func _init() -> void:
	name = "DialogueUI"
	layer = 20


func _ready() -> void:
	# A click anywhere continues (or closes a description after its last line): the dim behind the box and the box
	# itself take it, and everything inside lets it through except the buttons.
	var dim := ColorRect.new()
	dim.color = Color(Look.color("void"), 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_clicked)
	add_child(dim)
	_panel = PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(Look.color("ui_black"), 0.95)
	s.border_color = Look.color("gilt_dark")
	s.set_border_width_all(2)
	# Bevelled corners like every other panel (owner, 2026-10-06: not plain squares).
	s.set_corner_radius_all(10)
	s.corner_detail = 1
	s.set_content_margin_all(24)
	s.shadow_color = Color(Look.color("void"), 0.6)
	s.shadow_size = 10
	_panel.add_theme_stylebox_override("panel", s)
	UiKit.trim(_panel, 84.0)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -640
	_panel.offset_right = 640
	_panel.offset_top = -330
	_panel.offset_bottom = -24
	# A long list of options grows the box upward, never off the bottom of the screen.
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_clicked)
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_panel.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	# The speaker in the sheet's gilt frame, with their name on a plaque beneath.
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(212, 212)
	var back := ColorRect.new()
	back.color = Look.color("ui_black")
	back.position = Vector2(6, 6)
	back.size = Vector2(200, 200)
	holder.add_child(back)
	_portrait = TextureRect.new()
	_portrait.position = Vector2(6, 6)
	_portrait.size = Vector2(200, 200)
	_portrait.custom_minimum_size = Vector2(200, 200)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_portrait)
	holder.add_child(UiParts.drawn(Vector2(212, 212), func(c: Control) -> void:
		if _portrait.texture == null:
			return
		var r := Rect2(Vector2.ZERO, c.size)
		c.draw_rect(r.grow(-1), Look.color("gilt"), false, 2.0)
		c.draw_rect(r.grow(-5), Color(Look.color("gilt_dark"), 0.9), false, 1.0)
		for p: Vector2 in [Vector2(1, 1), Vector2(c.size.x - 1, 1), Vector2(1, c.size.y - 1), c.size - Vector2(1, 1)]:
			UiParts.diamond(c, p, 7.0, Look.color("void"), true)
			UiParts.diamond(c, p, 5.0, Look.color("gilt_light"), true)))
	_frame_art = holder.get_child(2) as Control
	left.add_child(holder)
	_name = _label("", 22, "gilt_light")
	_name.add_theme_font_override("font", UiKit.display_font())
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.custom_minimum_size = Vector2(212, 0)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_text)
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 4)
	# Past a share of the screen the options scroll (the focused one is kept in view), so every option stays on
	# screen and clickable however many there are.
	_options_scroll = ScrollContainer.new()
	_options_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_options_scroll.follow_focus = true
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options_scroll.add_child(_options)
	_options.minimum_size_changed.connect(_fit_options)
	right.add_child(_options_scroll)
	_continue_row = HBoxContainer.new()
	_continue_row.add_theme_constant_override("separation", 12)
	var go := UiParts.small_button("Continue", _advance)
	go.name = "Continue"
	go.focus_mode = Control.FOCUS_NONE
	_continue_row.add_child(go)
	_hint = _label("or click, Space, Enter or Esc", 13, "parchment")
	_continue_row.add_child(_hint)
	right.add_child(_continue_row)
	# The scroll-back of what's been said: a button under the speaker's name, and H.
	var hist := UiParts.small_button("History (H)", toggle_history)
	hist.name = "History"
	hist.focus_mode = Control.FOCUS_NONE
	hist.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hist.modulate = Color(1, 1, 1, 0.8)
	left.add_child(hist)
	_build_history()
	# The Tarokka spread: each card Madam Eva turns stays face up above the conversation.
	_spread = HBoxContainer.new()
	_spread.add_theme_constant_override("separation", 14)
	_spread.anchor_left = 0.5
	_spread.anchor_right = 0.5
	_spread.offset_left = -560
	_spread.offset_right = 560
	_spread.offset_top = 60
	_spread.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_spread)


## The scroll-back panel over the scene, above the box: every line of this conversation so far, newest at the bottom.
func _build_history() -> void:
	_history_panel = PanelContainer.new()
	var s := UiKit.style("ui_black", "gilt_dark", 2, 0.97)
	s.set_corner_radius_all(10)
	s.corner_detail = 1
	s.set_content_margin_all(20)
	_history_panel.add_theme_stylebox_override("panel", s)
	UiKit.trim(_history_panel, 56.0)
	_history_panel.anchor_left = 0.5
	_history_panel.anchor_right = 0.5
	_history_panel.offset_left = -560
	_history_panel.offset_right = 560
	_history_panel.offset_top = 40
	_history_panel.offset_bottom = 520
	_history_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_history_panel.visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_history_panel.add_child(col)
	var head := HBoxContainer.new()
	var title := UiKit.header("So far")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiParts.small_button("Close (H)", toggle_history))
	col.add_child(head)
	_history_text = RichTextLabel.new()
	_history_text.bbcode_enabled = true
	_history_text.scroll_following = true
	_history_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_history_text.add_theme_font_size_override("normal_font_size", 16)
	_history_text.add_theme_font_size_override("italics_font_size", 16)
	_history_text.add_theme_color_override("default_color", Look.color("vellum"))
	col.add_child(_history_text)
	add_child(_history_panel)


func toggle_history() -> void:
	_history_panel.visible = not _history_panel.visible
	if _history_panel.visible:
		_history_text.text = "\n\n".join(_history) if not _history.is_empty() else "[i]Nothing said yet.[/i]"


func history_open() -> bool:
	return _history_panel != null and _history_panel.visible


func _remember(line: String) -> void:
	_history.append(line)
	if _history.size() > 200:
		_history.pop_front()


## A face-up Tarokka card: its art if there is any, else its name, suit and number on a card face.
func _tarokka_card(card_id: String, slot: String) -> Control:
	var card := Tarokka.card(card_id)
	var face := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Look.color("vellum")
	st.border_color = Look.color("blood_deep") if str(card.get("deck", "")) == "high" else Look.color("ui_black")
	st.set_border_width_all(4)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(8)
	face.add_theme_stylebox_override("panel", st)
	face.custom_minimum_size = Vector2(170, 250)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	face.add_child(v)
	var art := "res://art/tarokka/%s.png" % str(card.get("art", card_id))
	if ResourceLoader.exists(art):
		var tex := TextureRect.new()
		tex.texture = load(art) as Texture2D
		tex.custom_minimum_size = Vector2(150, 170)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		v.add_child(tex)
	else:
		var glyph := {"swords": "⚔", "stars": "✶", "coins": "◉", "glyphs": "✠"}.get(str(card.get("suit", "")), "☾") as String
		var big := _label(glyph, 64, "blood_deep" if str(card.get("deck", "")) == "high" else "ui_black")
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(big)
		if card.has("value"):
			var num := _label("Master" if int(card["value"]) == 10 else str(int(card["value"])), 18, "ui_black")
			num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(num)
	var nm := _label(str(card.get("name", card_id)), 17, "ui_black")
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nm)
	var sl := _label(str(Tarokka.SLOT_NAMES.get(slot, "")), 12, "peat")
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sl)
	for l in v.find_children("*", "Label", false, false):
		(l as Label).add_theme_constant_override("outline_size", 0)
	return face


## Starts a conversation at "file:node". Returns false if it doesn't exist.
func play(r: DialogueRunner, ref: String) -> bool:
	runner = r
	if not runner.start(ref):
		return false
	_advance()
	return true


## Back from the shop: the conversation carries on.
func resume() -> void:
	visible = true
	_advance()


func _advance() -> void:
	_clear_options()
	var beat := runner.next()
	_show(beat)


func _show(beat: Dictionary) -> void:
	_waiting_continue = false
	# A line speaks its recorded clip, if it has one (ADR 0013); anything else ends the last line's voice.
	if str(beat["kind"]) == "line":
		VoiceOver.say(VoiceOver.beat_voice(beat), str(beat["text"]))
	else:
		VoiceOver.stop()
	match str(beat["kind"]):
		"end":
			ended.emit(str(beat.get("combat", "")))
			queue_free()
		"line":
			_line(beat)
			_waiting_continue = true
		"notice":
			_text.text = "[color=#%s]◆ %s[/color]" % [Look.color("bile").to_html(false), _esc(str(beat["text"]))]
			_remember(_text.text)
			_waiting_continue = true
			if beat.has("card"):
				Audio.sfx("card")
				var card := _tarokka_card(str(beat["card"]), str(beat.get("slot", "")))
				_spread.add_child(card)
				UiMotion.flip_in(card)
		"check":
			var colour := "bile" if bool(beat["success"]) else "vampire_red"
			var said := str(beat.get("said", ""))
			_show_portrait(str(beat.get("portrait", "")))
			_name.text = str(beat["who"])
			_text.text = "%s[color=#%s]%s rolls %s: %d vs DC %d, %s[/color]\n[font_size=14][color=#%s]%s[/color][/font_size]" % [
				("[i]\"%s\"[/i]\n" % _esc(said)) if said != "" else "", Look.color(colour).to_html(false), beat["who"], beat["skill"],
				int(beat["total"]), int(beat["dc"]), "success" if bool(beat["success"]) else "failure",
				Look.color("parchment").to_html(false), _esc(str(beat["detail"]))]
			_remember(_text.text)
			_waiting_continue = true
			# A failed check: what the roller could still spend (Heroic Inspiration, Tactical Mind).
			for aid: Variant in beat.get("aids", []):
				var a := aid as Dictionary
				var b := Button.new()
				b.text = str(a["label"])
				b.add_theme_font_size_override("font_size", 16)
				UiKit.button_look(b)
				b.add_theme_color_override("font_color", Look.color("bile"))
				var id := str(a["id"])
				b.pressed.connect(func() -> void:
					_clear_options()
					_show(runner.use_aid(id)))
				_options.add_child(b)
		"options":
			_show_options(beat["options"] as Array)
		"stage":
			stage_requested.emit(str(beat["what"]), str(beat["npc"]), str(beat["at"]))
			_show(runner.next())
			return
		"shop":
			visible = false
			shop_requested.emit(str(beat["npc"]))
			return
		"respec":
			visible = false
			respec_requested.emit(int(beat["index"]))
			return
		"pick_member":
			_show_portrait(DialogueRunner.NARRATOR_PORTRAIT)
			_name.text = "Narrator"
			_text.text = "[i][color=#%s]%s[/color][/i]" % [Look.color("vampire_red").to_html(false), _esc(str(beat["text"]))]
			var picks: Array = []
			for n: Variant in beat["members"]:
				picks.append({"text": str(n), "label": "", "check": {}, "enabled": true, "member": true})
			_show_options(picks)
	_continue_row.visible = _waiting_continue


func _line(beat: Dictionary) -> void:
	if bool(beat["narrator"]):
		_show_portrait(str(beat["portrait"]))
		_name.text = "Narrator"
		_text.text = "[i][color=#%s]%s[/color][/i]" % [Look.color("parchment").to_html(false), _esc(str(beat["text"]))]
		_remember(_text.text)
		return
	_name.text = str(beat["name"])
	_show_portrait(str(beat["portrait"]))
	var colour := "moonlight" if bool(beat["party"]) else "vellum"
	_text.text = "[color=#%s]%s[/color]" % [Look.color(colour).to_html(false), _esc(str(beat["text"]))]
	_remember("[color=#%s]%s:[/color] %s" % [Look.color("gilt_light").to_html(false), _esc(str(beat["name"])), _text.text])


## The speaker's portrait (art/portraits/<id>.png) in the gilt frame; none if there's no such art.
func _show_portrait(art_id: String) -> void:
	var path := "res://art/portraits/%s.png" % art_id
	_portrait.texture = load(path) as Texture2D if art_id != "" and ResourceLoader.exists(path) else null
	_frame_art.queue_redraw()


func _show_options(options: Array) -> void:
	_option_buttons.clear()
	_option_keys.clear()
	options_shown = options
	var asked := _asked()
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
		_option_look(b)
		var key := _option_key(str(opt["text"]))
		_option_keys.append(key)
		# Already asked in an earlier visit: dimmer, still there to ask again (BG3's way).
		var seen := not bool(opt.get("member", false)) and asked.has(key)
		b.add_theme_color_override("font_color", Look.color("gilt_light") if label != "" else Look.color("parchment" if seen else "vellum"))
		if seen:
			b.add_theme_color_override("font_focus_color", Look.color("parchment"))
			b.add_theme_color_override("font_hover_color", Look.color("vellum"))
			b.text = "%s  ✓" % b.text
			b.tooltip_text = "Already asked"
		b.add_theme_color_override("font_hover_color", Look.color("gilt_light"))
		var idx := i
		if not bool(opt.get("enabled", true)):
			b.disabled = true
			b.tooltip_text = str(opt.get("reason", ""))
			b.add_theme_color_override("font_disabled_color", Look.color("bone"))
		b.pressed.connect(func() -> void: _choose(idx))
		_options.add_child(b)
		_option_buttons.append(b)
		i += 1
	# The keyboard starts on the first thing not asked yet.
	_focus = 0
	for k in _option_buttons.size():
		if not _option_buttons[k].disabled and not asked.has(_option_keys[k]):
			_focus = k
			break
	if not _option_buttons.is_empty():
		_option_buttons[_focus].grab_focus()


## The options' area is as tall as its options, up to OPTIONS_SHARE of the screen; past that it scrolls.
func _fit_options() -> void:
	var cap := get_viewport().get_visible_rect().size.y * OPTIONS_SHARE if is_inside_tree() else 400.0
	_options_scroll.custom_minimum_size = Vector2(0, minf(_options.get_combined_minimum_size().y, cap))


## Options read as lines of text; the one under the mouse or keyboard gets a crimson band with pointed ends and a
## fine gilt edge, like the menu's buttons.
func _option_look(b: Button) -> void:
	var plain := StyleBoxEmpty.new()
	plain.content_margin_left = 20
	plain.content_margin_top = 4
	plain.content_margin_bottom = 4
	var lit := UiKit.style("ui_oxblood", "gilt_dark", 1, 0.95)
	lit.set_corner_radius_all(14)
	lit.corner_detail = 1
	lit.content_margin_left = 20
	lit.content_margin_top = 4
	lit.content_margin_bottom = 4
	for state: String in ["normal", "disabled"]:
		b.add_theme_stylebox_override(state, plain)
	for state: String in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(state, lit)


func _choose(i: int) -> void:
	Audio.sfx("click")
	var member := i < options_shown.size() and bool((options_shown[i] as Dictionary).get("member", false))
	if not member and i < _option_keys.size():
		_asked()[_option_keys[i]] = true
		_remember("[color=#%s]▸ %s[/color]" % [Look.color("moonlight").to_html(false), _esc(str((options_shown[i] as Dictionary)["text"]))])
	_clear_options()
	_show(runner.pick_member(i) if member else runner.choose(i))


## The options chosen before, kept with the story (it's saved and loaded with it): "file|text" -> true.
func _asked() -> Dictionary:
	if runner == null or runner.st == null:
		return {}
	if not runner.st.options.get("asked") is Dictionary:
		runner.st.options["asked"] = {}
	return runner.st.options["asked"] as Dictionary


## An option is known by its words within its conversation's file (the same question can come back from more than
## one node of it).
func _option_key(text: String) -> String:
	return "%s|%s" % [runner.file.key if runner != null and runner.file != null else "", text]


func _clear_options() -> void:
	options_shown = []
	for c in _options.get_children():
		c.queue_free()
	_option_buttons.clear()


## A left click on the box or anywhere around it.
func _clicked(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	get_viewport().set_input_as_handled()
	if history_open():
		toggle_history()
		return
	if runner != null and _waiting_continue:
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if runner == null:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo \
			and (event as InputEventKey).physical_keycode == KEY_H:
		get_viewport().set_input_as_handled()
		toggle_history()
		return
	if history_open():
		# The scroll-back is being read: Escape closes it and nothing else moves the conversation on.
		if event.is_action_pressed(&"combat_cancel"):
			toggle_history()
		if event is InputEventKey or event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
		return
	if _waiting_continue:
		# A click that no part of the screen took (the Tarokka cards) continues too.
		var go := event.is_action_pressed(&"combat_confirm") or event.is_action_pressed(&"combat_end_turn") \
			or event.is_action_pressed(&"combat_cancel") \
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
