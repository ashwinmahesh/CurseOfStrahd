class_name CutsceneView
extends Control
## A story cutscene's picture (story/cutscenes.gd; docs/ui/cutscenes.md) as large as the screen allows without cropping
## any of it, black bars filling the rest (owner, 2026-10-08: fullscreen cut off the top), with a caption under it: the
## narrator's words in the book's italic, or a speaker's name over their line. The picture fades up out of black and
## stays whole: no slow push-in, which would crop it again. A Skip button sits at the top right; Esc in the
## owner (CutscenePlayer, or DialogueUI during a conversation) pauses it with Resume and Skip. Clicks and keys are the
## owner's to handle: the view only reports a click on the picture.

## Skip, from the corner button or the pause card.
signal skip_requested
## A left click on the picture while it isn't paused.
signal clicked

const FADE_SECONDS := 0.8
## Headless runs read the still on the main thread, as PlacePreload reads nothing ahead there: the stand-in renderer's
## texture store isn't made for textures made on several threads at once. A still read on a worker while the main
## thread made the Narrator's portrait lost a texture in a full test run ('Parameter "t" is null' in
## texture_2d_initialize, test_npc_routes, 2026-10-09). Tests of the worker thread itself turn this on.
static var headless_too := false
## The caption's width at most, centred on the screen.
const CAPTION_WIDTH := 1240.0

var art: TextureRect
var image_path := ""
## A caption is up (a line to read, Skip on offer); off while the conversation shows its box over the picture.
var captioning := false
var paused := false
var _focus := Vector2(0.5, 0.5)
## A still being read on a worker thread (ResourceLoader.load_threaded_request), so opening a cutscene never waits on
## the disk (Functional QA FN-20, 2026-10-09: a cold read froze the first frame for up to 2.3 s). "" when none.
var _loading := ""
var _fade: Tween
var _caption: VBoxContainer
var _name: Label
var _text: RichTextLabel
var _hint: Label
var _skip: Button
var _pause: PanelContainer


func _init() -> void:
	name = "CutsceneView"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	var black := ColorRect.new()
	black.color = Look.color("void")
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	art = TextureRect.new()
	art.name = "Art"
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED   # the whole picture, letterboxed or pillarboxed in black
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.resized.connect(func() -> void: art.pivot_offset = art.size * _focus)
	add_child(art)
	# Shade at the top for the Skip button and a deeper one at the bottom for the caption, like a film's letterbox.
	add_child(_shade(true, 150.0, 0.55))
	add_child(_shade(false, 340.0, 0.9))
	_caption = VBoxContainer.new()
	_caption.name = "Caption"
	_caption.alignment = BoxContainer.ALIGNMENT_END
	_caption.add_theme_constant_override("separation", 4)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_caption, Vector2(0.5, 1.0), Rect2(-CAPTION_WIDTH / 2.0, -250, CAPTION_WIDTH, 196))
	_caption.grow_vertical = Control.GROW_DIRECTION_BEGIN   # a long line rises up the picture, never onto the hint
	add_child(_caption)
	_name = UiKit.label("", 22, "gilt_light")
	_name.add_theme_font_override("font", UiKit.display_font())
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_child(_name)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(CAPTION_WIDTH, 0)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_override("normal_font", EndingScreen.serif(false))
	_text.add_theme_font_override("italics_font", EndingScreen.serif(true))
	for k: String in ["normal_font_size", "italics_font_size"]:
		_text.add_theme_font_size_override(k, 25)
	_text.add_theme_color_override("default_color", Look.color("vellum"))
	_text.add_theme_color_override("font_outline_color", Look.color("void"))
	_text.add_theme_constant_override("outline_size", 7)
	_caption.add_child(_text)
	_hint = UiKit.label("Click, Space or Enter to go on · Esc pauses", 13, "parchment")
	PadGlyphs.hint(_hint, _hint.text, "{a} goes on · {b} pauses")
	_hint.name = "Hint"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_hint, Vector2(0.5, 1.0), Rect2(-400, -44, 800, 24))
	add_child(_hint)
	_skip = UiParts.small_button("Skip  ▸▸", func() -> void: skip_requested.emit())
	_skip.name = "Skip"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.set_meta(&"pad_skip", true)   # a pad's A goes on and B pauses; Skip is on the pause card (PadNav)
	_skip.modulate = Color(1, 1, 1, 0.85)
	_place(_skip, Vector2(1.0, 0.0), Rect2(-150, 28, 118, 32))
	add_child(_skip)
	_build_pause()
	show_caption(false)


## The pause card: the picture waits under it until Resume (or Esc again); Skip leaves the cutscene.
func _build_pause() -> void:
	_pause = UiKit.panel()
	_pause.name = "Paused"
	_place(_pause, Vector2(0.5, 0.5), Rect2(-190, -110, 380, 220))
	_pause.visible = false
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	_pause.add_child(col)
	var head := UiKit.header("Paused")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var resume := UiKit.button("Resume", func() -> void: set_paused(false))
	resume.name = "Resume"
	resume.set_meta(&"pad_first", true)
	col.add_child(resume)
	var skip := UiKit.button("Skip the scene", func() -> void:
		set_paused(false)
		skip_requested.emit())
	skip.name = "SkipScene"
	col.add_child(skip)
	add_child(_pause)


## Shows `path` (a res:// picture), fading up from black or from the picture before. `focus` (the picture's point of
## interest, data `focus`) is kept as the pivot. A still not in memory yet is read on a worker thread: the caption
## and the black (or the picture before) show meanwhile, and the still fades up the frame it arrives.
func show_image(path: String, focus: Vector2 = Vector2(0.5, 0.5)) -> void:
	if path == image_path:
		return
	image_path = path
	_focus = focus
	if path == "" or not ResourceLoader.exists(path):
		_loading = ""
		_put(null)
		return
	if ResourceLoader.has_cached(path) or DisplayServer.get_name() == "headless" and not headless_too:
		_loading = ""
		_put(load(path) as Texture2D)
		return
	_loading = path
	ResourceLoader.load_threaded_request(path, "Texture2D", false, ResourceLoader.CACHE_MODE_REUSE)
	set_process(true)


## Whether a still is still on its way from the disk.
func loading() -> bool:
	return _loading != ""


func _process(_delta: float) -> void:
	if _loading == "":
		set_process(false)
		return
	var status := ResourceLoader.load_threaded_get_status(_loading)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	var path := _loading
	_loading = ""
	set_process(false)
	var tex := ResourceLoader.load_threaded_get(path) as Texture2D if status == ResourceLoader.THREAD_LOAD_LOADED else null
	if path == image_path:   # not superseded by another still meanwhile
		_put(tex)


## The still on screen, fading up out of black.
func _put(tex: Texture2D) -> void:
	art.texture = tex
	art.pivot_offset = art.size * _focus
	art.scale = Vector2.ONE
	if _fade != null:
		_fade.kill()
		_fade = null
	if not UiMotion.on():
		art.modulate.a = 1.0
		return
	art.modulate.a = 0.0
	_fade = UiMotion.tween_for(art)
	_fade.tween_property(art, "modulate:a", 1.0, FADE_SECONDS).set_ease(Tween.EASE_OUT)


## The caption under the picture: `speaker` over `bbcode` ("" for the narrator, whose words are already italic).
func caption(speaker: String, bbcode: String) -> void:
	_name.text = speaker
	_name.visible = speaker != ""
	_text.text = "[center]%s[/center]" % bbcode


## A line is up to read (with Skip and the hint), or not (the conversation's box is showing over the picture).
func show_caption(on: bool) -> void:
	captioning = on
	_caption.visible = on
	_hint.visible = on
	_skip.visible = on
	if not on and paused:
		set_paused(false)


func set_paused(on: bool) -> void:
	paused = on
	_pause.visible = on
	VoiceOver.set_paused(on)   # the Narrator waits with the picture (UI QA SND-03)
	if _fade != null and _fade.is_valid():
		if on:
			_fade.pause()
		else:
			_fade.play()


## Where the picture is drawn on the screen: the whole of it, as large as fits (tests and captures).
func picture_rect() -> Rect2:
	if art.texture == null:
		return Rect2()
	var tex := art.texture.get_size()
	var k := minf(art.size.x / tex.x, art.size.y / tex.y)
	var shown := tex * k * art.scale
	return Rect2(art.global_position + (art.size - shown) / 2.0, shown)


## Fades the whole view out, then calls `done` (at once without motion).
func fade_out(done: Callable) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not UiMotion.on() or not is_inside_tree():
		done.call()
		return
	var tw := UiMotion.tween_for(self)
	tw.tween_property(self, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_callback(done)


## What the caption says now, as plain text (tests).
func caption_text() -> String:
	return _text.get_parsed_text().strip_edges() if captioning else ""


func _on_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if not paused:
		clicked.emit()


static func _shade(top: bool, height: float, alpha: float) -> TextureRect:
	var grad := Gradient.new()
	grad.set_color(0, Color(Look.color("void"), alpha if top else 0.0))
	grad.set_color(1, Color(Look.color("void"), 0.0 if top else alpha))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var t := TextureRect.new()
	t.texture = gt
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.anchor_right = 1.0
	if top:
		t.offset_bottom = height
	else:
		t.anchor_top = 1.0
		t.anchor_bottom = 1.0
		t.offset_top = -height
	return t


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
