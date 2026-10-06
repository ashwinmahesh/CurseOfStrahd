class_name EndingScreen
extends CanvasLayer
## The campaign's last screen (ADR 0014): the ending's title card, its narration (the ending's .dialogue node, line by
## line, a speaker's portrait above their words), the epilogue slides whose conditions hold (Endings.slides: one per
## place or ally, with a portrait), then The End, when the save is marked finished (SaveSystem.save_finished) and
## Return to the title goes back to the main menu. Continue, a click, Space or Enter goes on; Esc skips the rest of
## the narration or of the slides. The castle key art lies behind it all, lit by the ending's tone (dawn, night, blood).

## The last card is up and the save is marked finished.
signal finished_shown
## The player left for the title.
signal closed

enum Phase { TITLE, NARRATION, SLIDES, END }

## Tone -> [the glow rising from the bottom, the key art's tint, the title's colour].
const TONES := {
	"dawn": ["ember_deep", "candle", "gilt_light"],
	"night": ["night_deep", "moon_blue", "moonlight"],
	"blood": ["blood_deep", "vampire_red", "vampire_red"],
}
const BACKDROP := "res://art/ui/title_backdrop.png"

var st: StoryState
var ending: Dictionary = {}
var phase: Phase = Phase.TITLE
var slides: Array[Dictionary] = []
var slide_index := 0
## The narration beat on screen, and every narration line shown so far (tests read them).
var beat: Dictionary = {}
var lines_shown: Array[String] = []
var runner: DialogueRunner
## Captures and tests switch these off: no save is written, and Return to the title only closes the screen.
var save_on_finish := true
var to_title := true
var saved := false

var _tone: Array = []
var _card: VBoxContainer
var _footer: HBoxContainer
var _count: Label
var _go: Button
static var _serif: Font
static var _serif_italic: Font


func _init() -> void:
	name = "EndingScreen"
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS


## Starts the ending: the title card first.
func play(state: StoryState, ending_: Dictionary) -> void:
	st = state
	ending = ending_
	slides = Endings.slides(ending, st)
	_tone = TONES.get(str(ending.get("tone", "night")), TONES["night"]) as Array
	_build()
	Audio.play_music(str(ending.get("music", "ending")))
	runner = DialogueRunner.new(st, Dice.roller)
	_show_title()


## On to the next card: the title, each narration line, each slide, then The End (whose button leaves).
func advance() -> void:
	match phase:
		Phase.TITLE:
			phase = Phase.NARRATION
			if not runner.start(str(ending.get("narration", ""))):
				_to_slides()
				return
			# The new lord's ending speaks of the heir as {name}.
			var heir := Endings.heir(st)
			if heir != null:
				runner.speaker = heir
			_next_beat()
		Phase.NARRATION:
			_next_beat()
		Phase.SLIDES:
			slide_index += 1
			if slide_index >= slides.size():
				_to_end()
			else:
				_show_slide()
		Phase.END:
			leave()


## Esc: the rest of the narration, or of the slides, is skipped.
func skip() -> void:
	match phase:
		Phase.TITLE:
			advance()
		Phase.NARRATION:
			_to_slides()
		Phase.SLIDES:
			_to_end()


## Back to the title screen (or just closed, for captures and tests).
func leave() -> void:
	VoiceOver.stop()
	closed.emit()
	if to_title and is_inside_tree():
		ModeController.force(ModeController.Mode.EXPLORATION)
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		queue_free()


func _next_beat() -> void:
	var b := runner.next()
	for i in 100:
		match str(b.get("kind", "")):
			"line", "notice":
				_show_beat(b)
				return
			"options":
				b = runner.choose(0)   # a narration offers no choices; a stray menu takes its first option
			"check":
				b = runner.next()
			_:
				break   # the end of the narration (or something a narration shouldn't hold)
	_to_slides()


func _to_slides() -> void:
	VoiceOver.stop()
	beat = {}
	phase = Phase.SLIDES
	slide_index = 0
	if slides.is_empty():
		_to_end()
	else:
		_show_slide()


func _to_end() -> void:
	VoiceOver.stop()
	phase = Phase.END
	if save_on_finish and not saved:
		saved = SaveSystem.save_finished(str(ending.get("id", "")), str(ending.get("title", ""))) == OK
	_show_end()
	finished_shown.emit()


# --- Building -------------------------------------------------------------------------------------

func _build() -> void:
	var back := ColorRect.new()
	back.color = Look.color("void")
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.gui_input.connect(_clicked)
	add_child(back)
	# The castle under its moon, dim and tinted by the ending's light.
	if ResourceLoader.exists(BACKDROP):
		var art := TextureRect.new()
		art.texture = load(BACKDROP) as Texture2D
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.modulate = Color(Look.color(str(_tone[1])), 0.4)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)
	# Dark above, the tone's glow rising from below (a pale dawn, the valley's night, the castle's red).
	var grad := Gradient.new()
	grad.set_color(0, Color(Look.color("void"), 0.75))
	grad.set_color(1, Color(Look.color(str(_tone[0])), 0.7))
	grad.add_point(0.55, Color(Look.color("void"), 0.55))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var shade := TextureRect.new()
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_card = VBoxContainer.new()
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_theme_constant_override("separation", 14)
	_place(_card, Vector2(0.5, 0.5), Rect2(-620, -380, 1240, 680))
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	_footer = HBoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	_footer.add_theme_constant_override("separation", 18)
	_place(_footer, Vector2(0.5, 1.0), Rect2(-500, -104, 1000, 64))
	add_child(_footer)
	_count = UiKit.label("", 15, "parchment")
	_footer.add_child(_count)
	_go = UiParts.small_button("Continue", advance)
	_go.name = "Continue"
	_go.focus_mode = Control.FOCUS_NONE
	_footer.add_child(_go)
	var hint := UiKit.label("or click, Space or Enter · Esc skips", 13, "parchment")
	hint.name = "Hint"
	_footer.add_child(hint)


static func _place(c: Control, anchor: Vector2, r: Rect2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = r.position.x
	c.offset_top = r.position.y
	c.offset_right = r.end.x
	c.offset_bottom = r.end.y
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH


func _clear() -> void:
	for c in _card.get_children():
		_card.remove_child(c)
		c.queue_free()
	_card.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.6)


## The book serif (Georgia) for the narration, upright and italic.
static func serif(italic: bool) -> Font:
	if _serif == null:
		for i in 2:
			var f := SystemFont.new()
			f.font_names = PackedStringArray(["Georgia", "Times New Roman", "Palatino"])
			f.font_italic = i == 1
			f.fallbacks = [ThemeDB.fallback_font]
			if i == 0:
				_serif = f
			else:
				_serif_italic = f
	return _serif_italic if italic else _serif


static func _prose(bbcode: String, size: int, width: float) -> RichTextLabel:
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.scroll_active = false
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(width, 0)
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_theme_font_override("normal_font", serif(false))
	t.add_theme_font_override("italics_font", serif(true))
	for k: String in ["normal_font_size", "italics_font_size"]:
		t.add_theme_font_size_override(k, size)
	t.add_theme_color_override("default_color", Look.color("vellum"))
	t.add_theme_color_override("font_outline_color", Look.color("void"))
	t.add_theme_constant_override("outline_size", 6)
	t.text = bbcode
	return t


static func _esc(text: String) -> String:
	return text.replace("[", "[lb]")


static func _centred(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _display(text: String, size: int, colour: String) -> Label:
	var l := _centred(UiKit.label(text, size, colour))
	l.add_theme_font_override("font", UiKit.display_font())
	l.add_theme_constant_override("outline_size", 8)
	return l


func _footer_for(count: String, button: String) -> void:
	_count.text = count
	_count.visible = count != ""
	_go.text = button


# --- Cards ----------------------------------------------------------------------------------------

func _show_title() -> void:
	_clear()
	_card.add_child(_display("Curse of Strahd", 24, "parchment"))
	_card.add_child(_display(str(ending.get("title", "")), 68, str(_tone[2])))
	_card.add_child(UiKit.divider(400.0))
	_card.add_child(_prose("[center][i]%s[/i][/center]" % _esc(str(ending.get("summary", ""))), 24, 900.0))
	_footer_for("", "Continue")


func _show_beat(b: Dictionary) -> void:
	beat = b
	_clear()
	var text := str(b.get("text", ""))
	lines_shown.append(text)
	if str(b["kind"]) == "notice":
		VoiceOver.stop()
		_card.add_child(_prose("[center][color=#%s]◆ %s[/color][/center]" % [Look.color("bile").to_html(false), _esc(text)], 22, 900.0))
	elif bool(b.get("narrator", false)):
		VoiceOver.say(VoiceOver.beat_voice(b), text)
		_card.add_child(_prose("[center][i][color=#%s]%s[/color][/i][/center]" % [Look.color("parchment").to_html(false), _esc(text)], 30, 1000.0))
	else:
		VoiceOver.say(VoiceOver.beat_voice(b), text)
		var art := str(b.get("portrait", ""))
		if art != "" and ResourceLoader.exists("res://art/portraits/%s.png" % art):
			_card.add_child(UiParts.framed_portrait(art, 220.0))
		_card.add_child(_display(str(b.get("name", "")), 28, "gilt_light"))
		var colour := "moonlight" if bool(b.get("party", false)) else "vellum"
		_card.add_child(_prose("[center][color=#%s]“%s”[/color][/center]" % [Look.color(colour).to_html(false), _esc(text)], 28, 960.0))
	_footer_for("", "Continue")


func _show_slide() -> void:
	_clear()
	var s := slides[slide_index]
	_card.add_child(_display("Epilogue", 20, "parchment"))
	_card.add_child(_display(str(s.get("title", "")), 44, "gilt_light"))
	_card.add_child(UiKit.divider(320.0))
	var panel := PanelContainer.new()
	var style := UiKit.style("ui_black", "gilt_dark", 2, 0.8)
	style.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiKit.trim(panel, 84.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	var art := str(s.get("portrait", ""))
	var has_art := art != "" and ResourceLoader.exists("res://art/portraits/%s.png" % art)
	if has_art:
		var pic := UiParts.framed_portrait(art, 230.0)
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pic)
	var body := _esc(str(s.get("text", "")))
	var words := _prose(body if has_art else "[center]%s[/center]" % body, 26, 640.0 if has_art else 820.0)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(words)
	_card.add_child(panel)
	_footer_for("%d of %d" % [slide_index + 1, slides.size()], "Continue")


func _show_end() -> void:
	_clear()
	_card.add_child(_display("The End", 84, str(_tone[2])))
	_card.add_child(_display(str(ending.get("title", "")), 32, "gilt_light"))
	_card.add_child(UiKit.divider(380.0))
	var note := "Your story is saved, marked finished." if saved else "Your story is told."
	_card.add_child(_centred(UiKit.label(note, 18, "parchment")))
	var home := UiParts.primary_button("Return to the title", leave)
	home.name = "ReturnToTitle"
	_card.add_child(home)
	home.grab_focus.call_deferred()
	_footer.visible = false


# --- Input ----------------------------------------------------------------------------------------

func _clicked(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	get_viewport().set_input_as_handled()
	if phase != Phase.END:
		advance()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"combat_cancel"):
		get_viewport().set_input_as_handled()
		skip()
	elif event.is_action_pressed(&"combat_confirm") or event.is_action_pressed(&"combat_end_turn"):
		get_viewport().set_input_as_handled()
		if phase != Phase.END:
			advance()
	elif event is InputEventKey or event is InputEventJoypadButton:
		# Nothing reaches the world under the last screen.
		get_viewport().set_input_as_handled()


# --- Captures -------------------------------------------------------------------------------------

## A playthrough that touched most of the valley, so the slides have something to show (captures only).
const CAPTURE_FLAGS := {"vallaki_backed": "neither", "order_fate": "rest", "winery_wine_flows": true,
	"martikovs_reconciled": true, "abbot_fate": "repentant", "ilya_fate": "healed", "kasimir_at_peace": true,
	"van_richten_reunited": true, "mordenkainen_restored": true, "wolf_pack_leader": "emil", "lysaga_dead": true,
	"bonegrinder_fate": "destroyed", "death_house_children_at_rest": true, "dark_gifts_taken": 1}


## make capture SCENE=res://scenes/game.tscn NAME=ending ARGS="--ending=<id>": the title card, the first narration
## line, a speaker's line, the first slide, a slide with a portrait, and The End. No save is written.
static func capture(game: Node, tool: Node, out: String, id: String) -> void:
	var st := GameState.story
	for k: String in CAPTURE_FLAGS:
		st.set_flag(k, CAPTURE_FLAGS[k])
	if id in ["strahd_destroyed", "ireena_at_peace", "new_darklord"]:
		st.set_flag("strahd_destroyed", true)
	if id == "ireena_at_peace":
		st.set_flag("ireena_pool_choice", "promised")
	if id == "ireena_given_up":
		st.set_flag("strahd_parley", "ireena")
	if id == "new_darklord" and not st.party.is_empty():
		st.party[0].accept_dark_gift(Endings.HEIR_GIFT)
	st.add_guest("ireena")
	st.set_flag(Endings.FLAG, id)
	game.call("show_ending")
	var screen := game.get("ending") as EndingScreen
	if screen == null:
		return
	screen.save_on_finish = false
	screen.to_title = false
	await tool.call("wait_frames", 70)
	tool.call("_shot", out + "_1_title.png")
	screen.advance()
	await tool.call("wait_frames", 70)
	tool.call("_shot", out + "_2_narration.png")
	for i in 12:
		if screen.phase != Phase.NARRATION or not bool(screen.beat.get("narrator", true)):
			break
		screen.advance()
	if screen.phase == Phase.NARRATION:
		await tool.call("wait_frames", 70)
		tool.call("_shot", out + "_3_speaker.png")
	screen.skip()
	await tool.call("wait_frames", 70)
	tool.call("_shot", out + "_4_slide.png")
	for i in screen.slides.size():
		screen.advance()
		if screen.phase != Phase.SLIDES or str(screen.slides[screen.slide_index].get("portrait", "")) != "":
			break
	await tool.call("wait_frames", 70)
	tool.call("_shot", out + "_5_slide_portrait.png")
	screen.skip()
	await tool.call("wait_frames", 70)
	tool.call("_shot", out + "_6_end.png")
