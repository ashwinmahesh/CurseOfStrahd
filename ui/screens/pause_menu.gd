class_name PauseMenu
extends CanvasLayer
## Esc menu (plan §10 Phase 3 "save and load anywhere outside combat"), drawn to the owner's Crimson settings concept
## number for number: the concept's 280-unit-wide arch scaled by K, every position, colour and stroke from its SVG.
## An arched frame (wine to black, a gilt line and a fainter inset one), the crest at the apex, scrolls at the
## shoulders, the title over a lozenge rule, Music, Effects and Voices sliders with their icons, the choices as long
## hexagons (the selected one wine with lozenges outside its points), and a footer wave between corner brackets. The
## concept had two sliders and three buttons; this menu has three, five and a respec option, so the arch is taller,
## with the concept's spacing kept. The saves open in the same arch. As the game-over screen it offers only loading.
## Quicksave (and F5, here and exploring) saves over the game's current slot (SaveSystem.current_slot).

## Concept units to pixels.
const K := 1.5
## The concept's arch is 280 x 400 units; this one is taller to hold five buttons.
const W_U := 280.0
const H_U := 557.0
const SLIDER_Y: Array[float] = [155.0, 192.0, 229.0]
const RESPEC_Y := 263.0
const FIRST_BUTTON_Y := 301.0
const BUTTON_PITCH := 46.0

const TITLE_SCENE := "res://scenes/main_menu.tscn"
const GAME_SCENE := "res://scenes/game.tscn"

var game_over := false
## Tests swap in their own scene change (the test runner is the current scene).
var scene_changer: Callable
var root: Node
var st: StoryState
var _frame: Control
var _items: Array[Control] = []    ## everything placed on the frame for the current page
var _buttons: Array[Button] = []
var _list_box: VBoxContainer       ## the saves, when they're showing
var _note: Label                   ## "Saved." under the buttons
static var _serif: Font


func _init() -> void:
	name = "PauseMenu"
	layer = 30


## The concept's type: Georgia (a book serif every Mac has), lining up with the mockup.
static func serif() -> Font:
	if _serif == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Georgia", "Times New Roman", "Palatino"])
		f.fallbacks = [ThemeDB.fallback_font]
		_serif = f
	return _serif


static func _u(x: float, y: float) -> Vector2:
	return Vector2(x, y) * K


static func _c(name: String) -> Color:
	return Look.color(name)


func open(root_: Node, state: StoryState, _index: int) -> void:
	root = root_
	st = state
	var dim := ColorRect.new()
	dim.color = Color(_c("arch_back"), 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_frame = Control.new()
	var size := _u(W_U, H_U)
	_frame.anchor_left = 0.5
	_frame.anchor_right = 0.5
	_frame.anchor_top = 0.5
	_frame.anchor_bottom = 0.5
	_frame.offset_left = -size.x / 2.0
	_frame.offset_right = size.x / 2.0
	_frame.offset_top = -size.y / 2.0 - 8.0
	_frame.offset_bottom = size.y / 2.0 - 8.0
	add_child(_frame)
	var art := UiParts.drawn(size, _paint_frame)
	art.size = size
	_frame.add_child(art)
	var esc := _text("Esc: close", 8.5, Color(_c("arch_text"), 0.55))
	esc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	esc.position = Vector2(0, size.y + 6.0)
	esc.size = Vector2(size.x, 18)
	esc.visible = not game_over
	_frame.add_child(esc)
	if game_over:
		_show_saves()
	else:
		_show_menu()


# --- The frame ------------------------------------------------------------------------------------

## The arch path: M0,H L0,120 C0,60 80,20 140,0 C200,20 280,60 280,120 L280,H Z (and its inset at 9).
static func _arch(inset: float) -> PackedVector2Array:
	var i := inset
	var pts := PackedVector2Array([_u(i, H_U - i), _u(i, 120.0 + i * 0.22)])
	pts.append_array(_bez(_u(i, 120.0 + i * 0.22), _u(i, 60.0 + i * 0.89), _u(80.0 + i * 0.44, 20.0 + i), _u(140, i * 1.11)))
	pts.append_array(_bez(_u(140, i * 1.11), _u(200.0 - i * 0.44, 20.0 + i), _u(280.0 - i, 60.0 + i * 0.89), _u(280.0 - i, 120.0 + i * 0.22)))
	pts.append(_u(280.0 - i, H_U - i))
	return pts


static func _bez(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, steps: int = 24) -> PackedVector2Array:
	var out := PackedVector2Array()
	for s in range(1, steps + 1):
		var t := float(s) / steps
		var u := 1.0 - t
		out.append(p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t)
	return out


func _paint_frame(c: Control) -> void:
	var gold := _c("arch_gold")
	var outer := _arch(0.0)
	UiParts.gradient_fill(c, outer, _c("arch_top"), _c("arch_bottom"))
	UiParts.closed_line(c, outer, gold, 2.0 * K)
	UiParts.closed_line(c, _arch(9.0), Color(gold, 0.6), 1.0 * K)
	# Crest: a ring at (140,40) r13 and a lozenge (140,29)-(148,40)-(140,51)-(132,40).
	c.draw_arc(_u(140, 40), 13.0 * K, 0.0, TAU, 48, gold, 1.2 * K, true)
	c.draw_colored_polygon(PackedVector2Array([_u(140, 29), _u(148, 40), _u(140, 51), _u(132, 40)]), _c("arch_gold_light"))
	# Shoulder scrolls: M22,130 C22,110 40,102 52,112 C60,119 52,130 44,124, and mirrored.
	for flip: float in [1.0, -1.0]:
		var m := func(x: float, y: float) -> Vector2: return _u(140.0 + (x - 140.0) * flip, y)
		var pts := PackedVector2Array([m.call(22.0, 130.0)])
		pts.append_array(_bez(m.call(22.0, 130.0), m.call(22.0, 110.0), m.call(40.0, 102.0), m.call(52.0, 112.0)))
		pts.append_array(_bez(m.call(52.0, 112.0), m.call(60.0, 119.0), m.call(52.0, 130.0), m.call(44.0, 124.0)))
		c.draw_polyline(pts, gold, 1.5 * K, true)
	# Footer: the wave M60,F C90,F-10 115,F+10 140,F C165,F-10 190,F+10 220,F with a lozenge at 140, and brackets.
	var fy := H_U - 28.0
	var wave := PackedVector2Array([_u(60, fy)])
	wave.append_array(_bez(_u(60, fy), _u(90, fy - 10.0), _u(115, fy + 10.0), _u(140, fy)))
	wave.append_array(_bez(_u(140, fy), _u(165, fy - 10.0), _u(190, fy + 10.0), _u(220, fy)))
	c.draw_polyline(wave, gold, 1.2 * K, true)
	_lozenge(c, _u(140, fy), 5.0, gold)
	var by := H_U - 17.0
	for b: Array in [[17.0, 1.0], [263.0, -1.0]]:
		var x := float(b[0])
		var d := float(b[1])
		c.draw_polyline(PackedVector2Array([_u(x, by - 18.0), _u(x, by), _u(x + 18.0 * d, by)]), gold, 2.0 * K, true)


## A lozenge `r` units from centre to point.
static func _lozenge(c: CanvasItem, at: Vector2, r: float, fill: Color, stroke: Color = Color(0, 0, 0, 0)) -> void:
	var k := r * K
	var pts := PackedVector2Array([at + Vector2(0, -k), at + Vector2(k, 0), at + Vector2(0, k), at + Vector2(-k, 0)])
	c.draw_colored_polygon(pts, fill)
	if stroke.a > 0.0:
		UiParts.closed_line(c, pts, stroke, 1.0 * K)


# --- Pages ----------------------------------------------------------------------------------------

func _clear() -> void:
	for n in _items:
		n.queue_free()
	_items.clear()
	_buttons.clear()
	_list_box = null
	_note = null


func _place(c: Control) -> Control:
	_frame.add_child(c)
	_items.append(c)
	return c


func _text(text: String, size_u: float, colour: Color, spacing: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	var f := serif()
	if spacing != 0:
		var v := FontVariation.new()
		v.base_font = serif()
		v.spacing_glyph = spacing
		f = v
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", roundi(size_u * K) if size_u > 0.0 else 13)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## The title, centred on y 90, and its rule at y 104: lines 72-126 and 154-208 with a lozenge at 140.
func _title(text: String) -> void:
	var t := _text(text, 25.0 if text.length() < 14 else 19.0, _c("arch_text"), 2)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	t.position = _u(0, 60)
	t.size = _u(W_U, 34)
	_place(t)
	_place(UiParts.drawn(_u(W_U, 10), func(c: Control) -> void:
		var gold := _c("arch_gold")
		c.draw_line(_u(72, 5), _u(126, 5), gold, 1.0 * K, true)
		c.draw_line(_u(154, 5), _u(208, 5), gold, 1.0 * K, true)
		_lozenge(c, _u(140, 5), 5.0, gold))).position = _u(0, 99)


func _show_menu() -> void:
	_clear()
	_title("Paused")
	_slider_row(SLIDER_Y[0], "Music", Audio.music_volume, func(v: float) -> void: Audio.set_volumes(v, Audio.sfx_volume))
	_slider_row(SLIDER_Y[1], "Effects", Audio.sfx_volume, func(v: float) -> void:
		Audio.set_volumes(Audio.music_volume, v)
		Audio.sfx("click"))
	_slider_row(SLIDER_Y[2], "Voices", VoiceOver.volume(), VoiceOver.set_volume)
	var respec := CheckBox.new()
	respec.text = "Allow rebuilding a character at Madam Eva"
	respec.add_theme_font_override("font", serif())
	respec.add_theme_font_size_override("font_size", roundi(10.5 * K))
	for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		respec.add_theme_color_override(k, Color(_c("arch_text"), 0.8))
	respec.button_pressed = bool(st.options.get("respec", true))
	respec.tooltip_text = "Madam Eva can rebuild one of the party from scratch (a respec)."
	respec.toggled.connect(func(on: bool) -> void: st.options["respec"] = on)
	respec.focus_mode = Control.FOCUS_NONE
	_place(respec)
	respec.reset_size()
	respec.position = Vector2((_u(W_U, 0).x - respec.size.x) / 2.0, _u(0, RESPEC_Y).y - respec.size.y / 2.0)
	var can := SaveSystem.can_save()
	var why := "In a fight the game saves itself at the start of each round; load that save to retry the round."
	_button(0, "Resume", func() -> void: root.call("close_screen"))
	var quick := _button(1, "Quicksave  (F5)", _quick_save)
	quick.disabled = not can
	quick.tooltip_text = why if not can else ("Saves over this game's slot; F9 loads it." if SaveSystem.current_slot != "" else "Saves this game in a new slot; F5 and F9 use it from then on.")
	var save := _button(2, "Save Game", _save_new)
	save.disabled = not can
	save.tooltip_text = why if not can else "Saves in a new slot."
	var load := _button(3, "Load a Save", _show_saves)
	load.disabled = SaveSystem.list_slots().is_empty()
	_button(4, "Quit to Title", func() -> void: leave_to(TITLE_SCENE))
	_note = _text("", 10.0, _c("arch_gold_light"))
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.position = _u(0, FIRST_BUTTON_Y + BUTTON_PITCH * 4.0 + 22.0)
	_note.size = _u(W_U, 14)
	_place(_note)
	_buttons[0].grab_focus.call_deferred()


func _show_saves() -> void:
	_clear()
	_title("The party has fallen" if game_over else "Load a Save")
	var top := 124.0
	if game_over:
		var lost := _text("Barovia keeps what it takes. Load a save to try again.", 10.0, _c("arch_text"))
		lost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lost.position = _u(24, 118)
		lost.size = _u(W_U - 48.0, 28)
		_place(lost)
		top = 150.0
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 5)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_box)
	scroll.position = _u(26, top)
	var last := FIRST_BUTTON_Y + BUTTON_PITCH * 3.0 - 30.0
	scroll.size = _u(W_U - 52.0, last - top)
	_place(scroll)
	_list()
	if not game_over:
		_button(3, "Back", _show_menu)
	_button(4, "Quit to Title", func() -> void: leave_to(TITLE_SCENE))
	_buttons[0].grab_focus.call_deferred()


# --- Sliders --------------------------------------------------------------------------------------

## A row at concept y: the icon at x 30-51, the label at x 64 (Georgia 14), the track x 145-250.
func _slider_row(y: float, text: String, value: float, on_change: Callable) -> void:
	var music := text == "Music"
	var icon := UiParts.drawn(_u(26, 26), func(c: Control) -> void:
		var gold := _c("arch_gold")
		# Concept coordinates to this icon's own (it sits at concept x 26, y - 13).
		var at := func(x: float, yy: float) -> Vector2: return _u(x, yy) - _u(26, y - 13.0)
		if music:
			# M30,150 h5 l7,-6 v22 l-7,-6 h-5 z, and the waves q4,5 0,10 / q8,9 0,18 (shifted to this row).
			var dy := y - 155.0
			c.draw_colored_polygon(PackedVector2Array([at.call(30.0, 150.0 + dy), at.call(35.0, 150.0 + dy), at.call(42.0, 144.0 + dy),
				at.call(42.0, 166.0 + dy), at.call(35.0, 160.0 + dy), at.call(30.0, 160.0 + dy)]), gold)
			for w: Array in [[47.0, 150.0, 4.0, 5.0], [51.0, 146.0, 8.0, 9.0]]:
				var p0 := at.call(float(w[0]), float(w[1]) + dy) as Vector2
				var p1 := at.call(float(w[0]) + float(w[2]), float(w[1]) + float(w[3]) + dy) as Vector2
				var p2 := at.call(float(w[0]), float(w[1]) + float(w[3]) * 2.0 + dy) as Vector2
				var arc := PackedVector2Array([p0])
				for s in range(1, 13):
					var t := s / 12.0
					arc.append(p0 * (1.0 - t) * (1.0 - t) + p1 * 2.0 * (1.0 - t) * t + p2 * t * t)
				c.draw_polyline(arc, gold, 1.4 * K, true)
		elif text == "Voices":
			# A speech scroll in the same gold, with three lit dots.
			var dy3 := y - 229.0
			var bubble := PackedVector2Array()
			for i in 20:
				var a := TAU * i / 20.0
				bubble.append(at.call(38.0 + cos(a) * 9.0, 225.0 + dy3 + sin(a) * 6.5) as Vector2)
			c.draw_colored_polygon(bubble, gold)
			c.draw_colored_polygon(PackedVector2Array([at.call(33.0, 229.0 + dy3), at.call(39.0, 230.0 + dy3), at.call(31.0, 236.0 + dy3)]), gold)
			for dx: float in [-4.0, 0.0, 4.0]:
				c.draw_circle(at.call(38.0 + dx, 225.0 + dy3) as Vector2, 1.1 * K, _c("arch_gold_light"))
		else:
			# A bell in the concept's candle colours: a gold body and rim, the clapper lit.
			var dy2 := y - 192.0
			var body := PackedVector2Array([at.call(38.0, 178.0 + dy2), at.call(42.0, 181.0 + dy2), at.call(43.0, 190.0 + dy2),
				at.call(46.0, 194.0 + dy2), at.call(30.0, 194.0 + dy2), at.call(33.0, 190.0 + dy2), at.call(34.0, 181.0 + dy2)])
			c.draw_colored_polygon(body, gold)
			c.draw_circle(at.call(38.0, 198.0 + dy2) as Vector2, 2.4 * K, _c("arch_gold_light")))
	icon.position = _u(26, y - 13.0)
	_place(icon)
	var l := _text(text, 14.0, _c("arch_text"))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = _u(64, y - 10.0)
	l.size = _u(76, 20)
	_place(l)
	var s := ConceptSlider.new()
	s.name = text
	s.value = value
	s.changed.connect(on_change)
	s.position = _u(138, y - 9.0)
	s.size = _u(119, 18)
	_place(s)


## The concept's slider: a 4-unit track with round caps (#160407 empty, gold filled) and a 7-unit lozenge thumb.
## Click or drag; the new value is sent when the mouse lets go.
class ConceptSlider extends Control:
	signal changed(value: float)
	var value := 0.5
	var _drag := false

	func _ready() -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		focus_mode = Control.FOCUS_NONE

	func _span() -> Vector2:
		var pad := 7.0 * PauseMenu.K
		return Vector2(pad, size.x - pad)

	func _draw() -> void:
		var sp := _span()
		var y := size.y / 2.0
		var w := 4.0 * PauseMenu.K
		var x := lerpf(sp.x, sp.y, clampf(value, 0.0, 1.0))
		draw_line(Vector2(sp.x, y), Vector2(sp.y, y), Look.color("arch_track"), w, true)
		draw_circle(Vector2(sp.x, y), w / 2.0, Look.color("arch_track"))
		draw_circle(Vector2(sp.y, y), w / 2.0, Look.color("arch_track"))
		draw_line(Vector2(sp.x, y), Vector2(x, y), Look.color("arch_gold"), w, true)
		draw_circle(Vector2(sp.x, y), w / 2.0, Look.color("arch_gold"))
		draw_circle(Vector2(x, y), w / 2.0, Look.color("arch_gold"))
		PauseMenu._lozenge(self, Vector2(x, y), 7.0, Look.color("arch_gold_light"), Look.color("arch_gold"))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_drag = (event as InputEventMouseButton).pressed
			_set_from((event as InputEventMouseButton).position.x)
			if not _drag:
				changed.emit(value)
			accept_event()
		elif event is InputEventMouseMotion and _drag:
			_set_from((event as InputEventMouseMotion).position.x)
			accept_event()

	func _set_from(x: float) -> void:
		var sp := _span()
		value = snappedf(clampf((x - sp.x) / maxf(sp.y - sp.x, 1.0), 0.0, 1.0), 0.05)
		queue_redraw()


# --- Buttons --------------------------------------------------------------------------------------

## The n-th button of the column, centred at y FIRST_BUTTON_Y + n x 46: the hexagon x 34-246, 34 tall, 14-unit
## points. Normal: #33090f with a 1-unit gold line. Selected (hovered or focused): #6e1a26 with a 1.5 #e3c47c line
## and 5-unit lozenges outside its points at x 23 and 257. Georgia 15, centred.
func _button(n: int, text: String, on_press: Callable) -> Button:
	var cy := FIRST_BUTTON_Y + BUTTON_PITCH * n
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", serif())
	b.add_theme_font_size_override("font_size", roundi(15.0 * K))
	for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, _c("arch_text"))
	b.add_theme_color_override("font_disabled_color", Color(_c("arch_text"), 0.35))
	for state: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.position = _u(18, cy - 17.0)
	b.size = _u(244, 34)
	b.pressed.connect(func() -> void: Audio.sfx("click"))
	b.pressed.connect(on_press)
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	# The hexagon is a child drawn behind the button, so the label stays on top of it.
	var face := UiParts.drawn(b.size, func(c: Control) -> void: _paint_button(b, c))
	face.show_behind_parent = true
	b.add_child(face)
	b.focus_entered.connect(face.queue_redraw)
	b.focus_exited.connect(face.queue_redraw)
	b.mouse_entered.connect(face.queue_redraw)
	b.mouse_exited.connect(face.queue_redraw)
	_place(b)
	_buttons.append(b)
	return b


func _paint_button(b: Button, c: Control) -> void:
	var lit := not b.disabled and (b.has_focus() or b.is_hovered())
	# Local units: the button spans concept x 18-262, so the hexagon's x 34-246 is 16-228 here.
	var hex := PackedVector2Array([_u(16, 17), _u(30, 0), _u(214, 0), _u(228, 17), _u(214, 34), _u(30, 34)])
	c.draw_colored_polygon(hex, _c("arch_button_lit") if lit else Color(_c("arch_button"), 0.55 if b.disabled else 1.0))
	if lit:
		UiParts.closed_line(c, hex, _c("arch_gold_light"), 1.5 * K)
		_lozenge(c, _u(5, 17), 5.0, _c("arch_gold_light"))
		_lozenge(c, _u(239, 17), 5.0, _c("arch_gold_light"))
	else:
		UiParts.closed_line(c, hex, Color(_c("arch_gold"), 0.45 if b.disabled else 1.0), 1.0 * K)


# --- Saves ----------------------------------------------------------------------------------------

## A labelled volume slider for other screens (0-100%), saved with the player's settings as it moves.
static func volume_row(text: String, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := UiKit.label(text, 16, "vellum")
	l.custom_minimum_size = Vector2(90, 0)
	row.add_child(l)
	var slider := HSlider.new()
	slider.name = text
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(220, 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.drag_ended.connect(func(_changed: bool) -> void: on_change.call(slider.value))
	row.add_child(slider)
	return row


func _list() -> void:
	if _list_box == null:
		return
	for c in _list_box.get_children():
		c.queue_free()
	var slots := SaveSystem.list_slots()
	if slots.is_empty():
		_list_box.add_child(_text("No saves yet.", 10.0, Color(_c("arch_text"), 0.6)))
	for s in slots:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var where := "This game · %s" % s["location"] if str(s["slot"]) == SaveSystem.current_slot else str(s["location"])
		info.add_child(_text("%s · Day %d" % [where, int(s["day"])], 10.0, _c("arch_text")))
		info.add_child(_text(str(s["saved_at"]).replace("T", " "), 8.0, Color(_c("arch_text"), 0.55)))
		row.add_child(info)
		var slot := str(s["slot"])
		row.add_child(UiParts.small_button("Load", func() -> void: _load(slot)))
		if not game_over:
			row.add_child(UiParts.small_button("Overwrite", func() -> void: _save(slot)))
		var party_text := "%s\n%s" % [slot, s["party"]]
		_list_box.add_child(UiParts.row(row, func() -> Control: return UiParts.rules_tip("Party", "", party_text)))


## F5 and the Quicksave button: over the game's current slot (a new one the first time), as the exploring F5 does.
func _quick_save() -> void:
	var err := SaveSystem.quick_save()
	if err == OK:
		Audio.sfx("page")
	if _note != null:
		_note.text = "Saved." if err == OK else "Can't save now."


func _save_new() -> void:
	_save("save_%s" % Time.get_datetime_string_from_system().replace(":", "-"))


func _save(slot: String) -> void:
	var err := SaveSystem.save(slot)
	if err == OK:
		Audio.sfx("page")
		if _list_box != null:
			_list()
		elif _note != null:
			_note.text = "Saved."
	elif _note != null:
		_note.text = "Can't save now (in combat)."


func _load(slot: String) -> void:
	if SaveSystem.load_slot(slot) == OK:
		leave_to(GAME_SCENE)


## Leaves for another scene. The menu pauses the tree when it opens in a fight, and a paused tree stays paused across
## a scene change, which left the title screen deaf to every click (owner bug, 2026-10-06): so unpause first.
func leave_to(path: String) -> void:
	get_tree().paused = false
	if scene_changer.is_valid():
		scene_changer.call(path)
	else:
		get_tree().change_scene_to_file(path)


func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo \
			and (event as InputEventKey).physical_keycode == KEY_F5:
		get_viewport().set_input_as_handled()
		if SaveSystem.can_save():
			_quick_save()
		return
	if event.is_action_pressed(&"combat_cancel") and root != null:
		get_viewport().set_input_as_handled()
		if _list_box != null:
			_show_menu()
		else:
			root.call("close_screen")
