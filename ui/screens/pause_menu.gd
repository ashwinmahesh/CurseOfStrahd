class_name PauseMenu
extends CanvasLayer
## Esc menu (plan §10 Phase 3 "save and load anywhere outside combat"), drawn to the owner's Crimson settings concept
## number for number: the concept's 280-unit-wide arch scaled by K, every position, colour and stroke from its SVG.
## An arched frame (wine to black, a gilt line and a fainter inset one), the crest at the apex, scrolls at the
## shoulders, the title over a lozenge rule, Music, Effects and Voices sliders with their icons, the choices as long
## hexagons (the selected one wine with lozenges outside its points), and a footer wave between corner brackets. The
## concept had two sliders and three buttons; this menu has three, five and a way to Settings (docs/plans/ui_polish.md),
## so the arch is taller, with the concept's spacing kept. Settings' three pages (Game, Display, Keys) open in the same
## arch; the saves are a page of their own (ui/screens/saves_screen.gd). As the game-over screen it offers only loading.
## Quicksave (and its key, F5 unless the player moved it, here and exploring) saves over the game's current slot.

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
var _note: Label                   ## "Saved." under the buttons
var _on_settings := false
var _settings_page := "Game"
var _confirm: Button                ## "Leave Honour for ...", while that switch waits for its second click
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
	UiScale.full_screen(self)   # the arch fills the screen at its design size, whatever the interface size
	# The world as the menu opens over it: the picture for a save made from its pages (lane 16, Q9).
	SaveSystem.hold_view(self)
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
	# The arch is this screen's frame: closing, it sinks away like a framed screen's panel (UiMotion.dismiss).
	set_meta(&"frame_panel", _frame)
	var art := UiParts.drawn(size, _paint_frame)
	art.size = size
	_frame.add_child(art)
	var esc := _text("Esc: close", 8.5, Color(_c("arch_text"), 0.55))
	PadGlyphs.hint(esc, "Esc: close", "{b}: close")
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
	_on_settings = false
	for n in _items:
		# Out of the frame at once, so the next page's rows and tabs keep their names.
		if n.get_parent() == _frame:
			_frame.remove_child(n)
		n.queue_free()
	_items.clear()
	_buttons.clear()
	_note = null
	_confirm = null


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
	# The rest of the player's settings (the look, the window, fight speed, the respec) are a page of their own, and the
	# cheat codes (CheatCodesPage) another beside it while there's a party to give items to.
	var links: Array[Button] = [_link("◆  Settings  ◆", _show_settings)]
	if CheatCodesPage.can_open(st):
		links.append(_link("◆  Cheat codes  ◆", _open_cheats))
		links[1].name = "CheatCodes"
	var gap := 16.0 * K
	var x := _u(W_U, 0).x + gap
	for b in links:
		x -= b.size.x + gap
	x /= 2.0
	for b in links:
		b.position = Vector2(x, _u(0, RESPEC_Y).y - b.size.y / 2.0)
		x += b.size.x + gap
	var can := SaveSystem.can_save()
	var why := "In a fight the game saves itself at the start of each round; load that save to retry the round."
	_button(0, "Resume", func() -> void: root.call("close_screen"))
	var qs := InputActions.key_text(&"quick_save")
	var quick := _button(1, "Quicksave  (%s)" % qs if qs != "" else "Quicksave", _quick_save)
	quick.disabled = not can
	quick.tooltip_text = why if not can else InputActions.fill("Saves over this game's slot; {quick_load} loads it." \
		if SaveSystem.current_slot != "" else "Saves this game in a new slot; {quick_save} and {quick_load} use it from then on.")
	var save := _button(2, "Save Game", func() -> void: _open_saves(SavesScreen.Mode.SAVE))
	save.disabled = not can
	save.tooltip_text = why if not can else "Save in a new slot, or over one of your saves."
	var load := _button(3, "Load a Save", _show_saves)
	load.disabled = SaveSystem.list_slots().is_empty()
	_button(4, "Quit to Title", func() -> void: leave_to(TITLE_SCENE))
	_note = _text("", 10.0, _c("arch_gold_light"))
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.position = _u(0, FIRST_BUTTON_Y + BUTTON_PITCH * 4.0 + 22.0)
	_note.size = _u(W_U, 14)
	_place(_note)
	_buttons[0].grab_focus.call_deferred()


## Settings (docs/plans/ui_polish.md), three pages under the title: Game (the difficulty, how fights and the Narrator
## play, turn-based exploring, the respec option), Display (the look, graphics, the window, depth blur, the interface and text sizes) and Keys (KeysPage).
## Each row is a choice the player steps through with a click; kept in user://settings.cfg.
const SETTINGS_PAGES: Array[String] = ["Game", "Display", "Keys"]
## Concept y of the first row and the pitch between rows.
const ROW_Y := 158.0
const ROW_PITCH := 34.0


func _show_settings(page: String = "Game") -> void:
	_clear()
	_on_settings = true
	_settings_page = page
	_title("Settings")
	_page_tabs(page)
	_note = _text("", 9.5, _c("arch_gold_light"))
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.position = _u(24, 380)
	_note.size = _u(W_U - 48.0, 30)
	match page:
		"Display":
			_display_rows()
		"Keys":
			var keys := KeysPage.new()
			keys.noted.connect(func(t: String) -> void: _note.text = t)
			keys.position = _u(26, 138)
			keys.size = _u(W_U - 52.0, 240)
			_place(keys)
			_note.position = _u(24, 381)
			_note.size = _u(W_U - 48.0, 22)
			var reset := _link("Every key back to the start", func() -> void:
				InputActions.reset()
				_show_settings("Keys")
				_note.text = "Every key is back where it started.")
			reset.position = Vector2((_u(W_U, 0).x - reset.size.x) / 2.0, _u(0, 409).y - reset.size.y / 2.0)
		_:
			_game_rows()
	_place(_note)
	_button(3, "Back", _show_menu)
	_button(4, "Resume", func() -> void: root.call("close_screen"))
	_buttons[0].grab_focus.call_deferred()


## The three page names under the title, the open one lit over a gilt rule with a lozenge.
func _page_tabs(page: String) -> void:
	var xs: Array[float] = [86.0, 140.0, 194.0]   # clear of the shoulder scrolls
	for i in SETTINGS_PAGES.size():
		var name_ := SETTINGS_PAGES[i]
		var on := name_ == page
		var tab := _link(name_, func() -> void: _show_settings(name_))
		tab.name = "Page" + name_
		tab.add_theme_font_size_override("font_size", roundi(12.5 * K))
		for k: String in ["font_color", "font_pressed_color", "font_focus_color"]:
			tab.add_theme_color_override(k, _c("arch_gold_light") if on else Color(_c("arch_gold"), 0.75))
		tab.reset_size()
		tab.position = Vector2(_u(xs[i], 0).x - tab.size.x / 2.0, _u(0, 124).y - tab.size.y / 2.0)
		if on:
			var mark := UiParts.drawn(Vector2(tab.size.x, 6.0 * K), func(c: Control) -> void:
				var y := c.size.y / 2.0
				c.draw_line(Vector2(0, y), Vector2(c.size.x, y), Color(_c("arch_gold"), 0.8), 1.0, true)
				_lozenge(c, Vector2(c.size.x / 2.0, y), 2.5, _c("arch_gold_light")))
			mark.position = Vector2(tab.position.x, tab.position.y + tab.size.y - 2.0 * K)
			_place(mark)


## Game: the playthrough's difficulty, how fights and the Narrator play, turn-based exploring, and the respec option.
func _game_rows() -> void:
	var y := ROW_Y
	if st != null:
		_difficulty_row(y)
		y += ROW_PITCH
	_choice_row(y, "Fights", ["Normal", "Fast"], 1 if GameSettings.fast_combat() else 0, func(i: int) -> void:
		GameSettings.set_fast_combat(i == 1), "Fast plays moves and the pauses between turns at twice the speed.")
	y += ROW_PITCH
	_choice_row(y, "Narration", ["Fades", "Stays"], 1 if GameSettings.narration_stays() else 0, func(i: int) -> void:
		GameSettings.set_narration_stays(i == 1), "Whether the Narrator's box fades on its own or stays until you close it.")
	y += ROW_PITCH
	# Turn-based exploring (F7): the same switch as its key and the hotbar's Turn-based button.
	_choice_row(y, "Exploring", ["Real time", "Turn-based"], 1 if GameSettings.turn_based() else 0, func(i: int) -> void:
		_set_turn_based(i == 1),
		InputActions.fill("Turn-based: outside fights the party moves in rounds, one of you at a time, to set up an ambush. {plan_mode} switches it too."))
	y += ROW_PITCH
	# The controller's button pictures (U6, PadGlyphs): the pad in use, or a family picked here.
	var icons: Array[String] = ["auto"]
	icons.append_array(PadGlyphs.FAMILIES)
	var icon_names: Array[String] = ["Automatic", "Xbox", "PlayStation", "Nintendo"]
	_choice_row(y, "Button icons", icon_names, maxi(0, icons.find(str(GameSettings.value("pad_icons", "auto")))),
		func(i: int) -> void:
			GameSettings.set_value("pad_icons", icons[i])
			PadGlyphs.refresh_hints(),
		"The controller's buttons as they're shown: Automatic follows the pad you play with.")
	y += ROW_PITCH
	var respec := CheckBox.new()
	respec.text = "Allow rebuilding a character at Madam Eva"
	respec.add_theme_font_override("font", serif())
	respec.add_theme_font_size_override("font_size", roundi(10.5 * K))
	for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		respec.add_theme_color_override(k, Color(_c("arch_text"), 0.8))
	respec.button_pressed = bool(st.options.get("respec", true)) if st != null else true
	respec.tooltip_text = "Madam Eva can rebuild one of the party from scratch (a respec)."
	respec.toggled.connect(func(on: bool) -> void:
		if st != null:
			st.options["respec"] = on)
	respec.focus_mode = Control.FOCUS_NONE
	_place(respec)
	respec.reset_size()
	respec.position = Vector2((_u(W_U, 0).x - respec.size.x) / 2.0, _u(0, y).y - respec.size.y / 2.0)


## The playthrough's difficulty (F1, combat/difficulty.gd, kept in its options): Story, Balanced and Tactician switch
## any time; Honour is only chosen for a new game, so it's listed only while it's the mode, and leaving it, which is for
## good, waits for a second click on the link that appears.
func _difficulty_row(y: float) -> void:
	var now := Difficulty.of_options(st.options).id
	var ids: Array[String] = []
	var names: Array[String] = []
	var tip: Array[String] = []
	for id in Difficulty.IDS:
		var d := Difficulty.named(id)
		if id == now or Difficulty.can_switch(now, id):
			ids.append(id)
			names.append(d.name)
		if d.switchable:
			tip.append("%s: %s" % [d.name, d.summary])
	tip.append("Honour (one life, one save) is chosen when a new game begins.")
	_choice_row(y, "Difficulty", names, ids.find(now), func(i: int) -> void: _pick_difficulty(ids[i]), "\n".join(tip))


## A difficulty picked on the row: at once, unless it leaves Honour, which asks first.
func _pick_difficulty(to: String) -> void:
	var from := Difficulty.of_options(st.options).id
	if _confirm != null and is_instance_valid(_confirm):
		_items.erase(_confirm)
		_frame.remove_child(_confirm)
		_confirm.queue_free()
	_confirm = null
	if to == from:
		_note.text = ""
		return
	var warning := Difficulty.switch_warning(from, to)
	if warning == "":
		_set_difficulty(to)
		return
	_note.text = warning
	_confirm = _link("Leave Honour for %s" % Difficulty.named(to).name, func() -> void:
		_set_difficulty(to)
		_show_settings("Game")   # Honour is no longer offered
		_note.text = "Now %s. Enemies change from the next fight." % Difficulty.named(to).name)
	_confirm.name = "LeaveHonour"
	_confirm.position = Vector2((_u(W_U, 0).x - _confirm.size.x) / 2.0, _u(0, 336).y - _confirm.size.y / 2.0)


## The playthrough's mode: kept in its options, and the party's bonus (Story's +2) put on or taken off at once.
func _set_difficulty(to: String) -> void:
	st.options["difficulty"] = to
	var d := Difficulty.named(to)
	for ch in st.roster():
		d.fit_party(ch)
	_note.text = "%s: %s. Enemies change from the next fight." % [d.name, d.tagline.to_lower()]


## Display: the world's look and how hard the renderer works, the window, depth blur, and the interface and text sizes.
func _display_rows() -> void:
	var y := ROW_Y
	_choice_row(y, "Look", ["Modern", "Classic"], 0 if Look.modern() else 1, func(i: int) -> void:
		_set_look("modern" if i == 0 else "classic"),
		"Modern: smooth light, relief and glow. Classic: the 1990s cartoon, every colour from the palette.")
	y += ROW_PITCH
	var presets := Graphics.PRESETS
	_choice_row(y, "Graphics", ["Low", "Medium", "High"], presets.find(Graphics.preset()), func(i: int) -> void:
		Graphics.set_preset(presets[i])
		_note.text = "Edges change now, shadows and lamps from the next place you go." if Look.modern() \
			else "The Classic look always draws the same; this is for Modern.",
		"How hard the Modern look works: smooth edges, shadow detail, how many lamps cast shadows, and reflections. Lower it if the game stutters.")
	y += ROW_PITCH
	_choice_row(y, "Window", ["Windowed", "Fullscreen"], 1 if GameSettings.fullscreen() else 0, func(i: int) -> void:
		GameSettings.set_fullscreen(i == 1), "Play in a window or fill the screen.")
	y += ROW_PITCH
	var reaches := Atmosphere.EDGE_BLURS.keys()
	var blurs: Array[String] = ["Off"]
	for id: String in reaches:
		blurs.append(str(Atmosphere.EDGE_BLURS[id]["name"]))
	var blur := reaches.find(Atmosphere.edge_blur()) + 1 if GameSettings.depth_blur() else 0
	_choice_row(y, "Depth blur", blurs, blur, func(i: int) -> void:
		GameSettings.set_depth_blur(i > 0)
		if i > 0:
			GameSettings.set_blur_reach(str(reaches[i - 1]))
		_note.text = "" if Look.modern() else "The Classic look never blurs; this is for Modern.",
		"Modern look: the world softens toward the screen's edges, most in the corners, and the middle stays sharp. Corners blurs the least, Wide the most. The interface, names and markers never blur.")
	y += ROW_PITCH
	var sizes := GameSettings.UI_SCALES
	var percents: Array[String] = []
	for v in sizes:
		percents.append("%d%%" % roundi(v * 100.0))
	_choice_row(y, "Interface", percents, sizes.find(GameSettings.ui_scale()), func(i: int) -> void:
		GameSettings.set_ui_scale(sizes[i])
		UiScale.apply()
		_note.text = "The game's interface takes this size when you close the menu.",
		"How big the interface is while you play: the party, the bar, fights, conversations and rules cards. Menus like this one keep their size.")
	y += ROW_PITCH
	var texts := GameSettings.TEXT_SCALES
	_choice_row(y, "Text", ["Normal", "Large", "Larger"], texts.find(GameSettings.text_scale()), func(i: int) -> void:
		GameSettings.set_text_scale(texts[i])
		_note.text = "Conversations, the Narrator and the journal read larger." if i > 0 else "",
		"The size of what you read: conversations, the Narrator's box and the journal.")


## Turn-based exploring on or off: the place the party is in switches at once (in a fight, once it's over).
func _set_turn_based(on: bool) -> void:
	var view := root.get("view") as LocationView if root != null and "view" in root else null
	if view != null and not view.in_combat and view.planning != on:
		view.toggle_plan()
	else:
		GameSettings.set_turn_based(on)


## A new look applies to the place at once when the party is simply exploring; in a fight, from the next place.
func _set_look(style: String) -> void:
	if style == Look.style():
		return
	Look.set_style(style)
	var view := root.get("view") as LocationView if root != null and "view" in root else null
	if view != null and not view.in_combat and root.has_method("rebuild"):
		root.call("rebuild")
		_note.text = ""
	elif _note != null:
		_note.text = "The new look starts at the next place you go."


## A row of the settings page at concept y: the label at x 30 (Georgia 14) and, where the sliders' tracks are, the
## current choice between gilt arrows; a click moves to the next choice, or back one on the left arrow.
func _choice_row(y: float, text: String, options: Array[String], current: int, on_change: Callable, tip: String) -> void:
	var l := _text(text, 14.0, _c("arch_text"))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = _u(30, y - 10.0)
	l.size = _u(100, 20)
	_place(l)
	var b := Button.new()
	b.name = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", serif())
	b.add_theme_font_size_override("font_size", roundi(13.0 * K))
	for k: String in ["font_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, _c("arch_gold_light"))
	b.add_theme_color_override("font_hover_color", _c("arch_text"))
	for state: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var at := [current, false]   # the choice showing, and whether the click came on the left arrow
	b.text = "‹  %s  ›" % options[current]
	b.gui_input.connect(func(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			at[1] = mb.position.x < b.size.x * 0.3)
	var turn := func(step: int) -> void:
		Audio.sfx("click")
		at[0] = posmod(int(at[0]) + step, options.size())
		b.text = "‹  %s  ›" % options[int(at[0])]
		on_change.call(int(at[0]))
	b.pressed.connect(func() -> void:
		turn.call(-1 if bool(at[1]) else 1)
		at[1] = false)
	b.set_meta(&"pad_adjust", turn)   # the pad's left and right turn it (PadNav)
	b.position = _u(130, y - 11.0)
	b.size = _u(127, 22)
	# A fine gold rule under the choice, like the sliders' tracks.
	var rule := UiParts.drawn(_u(127, 4), func(c: Control) -> void:
		c.draw_line(Vector2(0, c.size.y / 2.0), Vector2(c.size.x, c.size.y / 2.0), Color(_c("arch_gold"), 0.45), 1.0, true)
		_lozenge(c, Vector2(c.size.x / 2.0, c.size.y / 2.0), 3.0, _c("arch_gold")))
	rule.position = _u(130, y + 10.0)
	_place(rule)
	_place(b)


## A small centred text button in the arch's gold (the menu's way to Settings).
func _link(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", serif())
	b.add_theme_font_size_override("font_size", roundi(11.5 * K))
	for k: String in ["font_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, _c("arch_gold"))
	b.add_theme_color_override("font_hover_color", _c("arch_gold_light"))
	for state: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.pressed.connect(func() -> void: Audio.sfx("click"))
	b.pressed.connect(on_press)
	_place(b)
	b.reset_size()
	return b


## Load a Save opens the saves' own page. As the game-over screen, the arch says the party has fallen and offers the
## way back: that page, the last autosave, or the title.
func _show_saves() -> void:
	if not game_over:
		_open_saves(SavesScreen.Mode.LOAD)
		return
	_clear()
	_title("The party has fallen")
	var lost := _text("Barovia keeps what it takes. Load a save to try again.", 10.0, _c("arch_text"))
	lost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lost.position = _u(24, 126)
	lost.size = _u(W_U - 48.0, 20)
	_place(lost)
	# The last autosave, said where it was made; the buttons sit at the foot of the arch. An Honour run ends here: its
	# one save carries on in Tactician (SaveSystem.end_honour), and that is the way back.
	var honour := SaveSystem.honour()
	if honour:
		SaveSystem.end_honour()
	var back_to := SaveSystem.current_slot if honour else SaveSystem.AUTOSAVE
	var s := SaveSystem.describe(back_to) if back_to != "" else {}
	var auto := not s.is_empty()
	if auto:
		var head := "The Honour run ends here.\nIts save carries on in Tactician:" if honour else "The last autosave"
		var at := _text("%s\n%s\nDay %d · %s" % [head, s["location"], int(s["day"]), SavesScreen.when(s)], 11.0, _c("arch_gold_light"))
		at.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		at.clip_text = true
		at.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		at.position = _u(30, 200)
		at.size = _u(W_U - 60.0, 70)
		_place(at)
	_button(2 if auto else 3, "Load a Save", func() -> void: _open_saves(SavesScreen.Mode.LOAD))
	if auto and honour:
		_button(3, "Carry On", func() -> void: _load(back_to)).tooltip_text = \
			"Back to the run's save, now in Tactician: the game saves as ever, and Honour is over for good."
	elif auto:
		_button(3, "Last Autosave", func() -> void: _load(SaveSystem.AUTOSAVE)).tooltip_text = \
			"Back to where the game last saved itself: arriving somewhere, a rest or a won fight."
	_button(4, "Quit to Title", func() -> void: leave_to(TITLE_SCENE))
	_buttons[0].grab_focus.call_deferred()


## The cheat codes' page over the arch, which hides the arch until it closes.
func _open_cheats() -> void:
	CheatCodesPage.open_on(self, st, _frame).closed.connect(func() -> void:
		if not _buttons.is_empty():
			_buttons[0].grab_focus.call_deferred())


## The saves' page over the arch (lane 16's), which hides the arch until it closes. A save comes back to "Saved.".
func _open_saves(mode: SavesScreen.Mode) -> void:
	var page := SavesScreen.open_on(self, mode, func() -> void: leave_to(GAME_SCENE), _frame)
	page.saved.connect(func(_slot: String) -> void:
		_show_menu()
		_note.text = "Saved.")
	page.closed.connect(func() -> void:
		if not _buttons.is_empty():
			_buttons[0].grab_focus.call_deferred())


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

	## The pad's left and right (PadNav): a step down or up.
	func pad_adjust(step: int) -> void:
		value = snappedf(clampf(value + 0.05 * step, 0.0, 1.0), 0.05)
		queue_redraw()
		changed.emit(value)


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


## F5 and the Quicksave button: over the game's current slot (a new one the first time), as the exploring F5 does.
func _quick_save() -> void:
	var err := SaveSystem.quick_save()
	if err == OK:
		Audio.sfx("page")
	if _note != null:
		_note.text = "Saved." if err == OK else "Can't save now."


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
	if event.is_action_pressed(&"quick_save") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if SaveSystem.can_save():
			_quick_save()
		return
	if event.is_action_pressed(&"combat_cancel") and root != null:
		get_viewport().set_input_as_handled()
		if _on_settings:
			_show_menu()
		else:
			root.call("close_screen")
