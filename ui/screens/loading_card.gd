class_name LoadingCard
extends CanvasLayer
## G5, the loading card (docs/ui/loading_cards.md): arriving in a new region, the screen shows that region's
## establishing picture from the cutscenes (data/loading/cards.json), the place's name over it and a tip, while the
## place settles in behind; it fades after a moment, or at a click or any key. Never in headless runs or still captures
## (UiMotion), so tests and screenshots see the place itself.
## The loading lane: a change of place that takes a while puts the card up before the place is built (`cover`), so the
## wait shows the card instead of the last place frozen; it stays until the game says the place is ready (`lift`).

signal closed

const DATA := "res://data/loading/cards.json"
const HOLD_SECONDS := 2.4
const FADE_SECONDS := 0.6
## Seconds the card takes to come up.
const FADE_IN := 0.25
## A covering card goes after this many seconds whatever happens, so it can never stay up.
const MAX_COVER := 20.0

static var _data: Dictionary = {}
static var _rng := RandomNumberGenerator.new()   # cosmetic: which tip

var location: Dictionary = {}
var tip := ""
## Up while a place is built (`cover`): it waits for `lift` instead of fading on its own.
var covering := false
## Seconds the card stays up at least, counted from when it starts to come up.
var hold := HOLD_SECONDS
var _closing := false
var _lifted := false
var _root: Control
var _since := 0


func _init() -> void:
	name = "LoadingCard"
	layer = 40   # over the place's fade from black, under the menus
	process_mode = Node.PROCESS_MODE_ALWAYS


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_data = parsed as Dictionary if parsed is Dictionary else {}
	return _data


## The picture for `region` (a res:// path): its own, else the default.
static func picture_for(region: String) -> String:
	var d := data()
	var id := str((d.get("regions", {}) as Dictionary).get(region, d.get("default", "")))
	return Cutscenes.ART % id if id != "" else ""


static func tips() -> Array:
	return data().get("tips", []) as Array


## Shows the card for `loc` on `parent`, unless motion is off (tests, captures). Returns it, or null.
static func show_for(parent: Node, loc: Dictionary) -> LoadingCard:
	return _make(parent, loc, false, HOLD_SECONDS)


## Puts the card up over a change of place before the place is built (the loading lane); it stays until `lift`, then
## for what's left of `hold_s`. Null with motion off.
static func cover(parent: Node, loc: Dictionary, hold_s: float) -> LoadingCard:
	return _make(parent, loc, true, hold_s)


static func _make(parent: Node, loc: Dictionary, covering_: bool, hold_s: float) -> LoadingCard:
	if not UiMotion.on() or parent == null or not parent.is_inside_tree():
		return null
	var card := LoadingCard.new()
	card.location = loc
	card.covering = covering_
	card.hold = hold_s
	var all := tips()
	card.tip = str(all[_rng.randi_range(0, all.size() - 1)]) if not all.is_empty() else ""
	parent.add_child(card)
	return card


## The place behind a covering card is ready: the card goes once it has been up for `hold` seconds.
func lift() -> void:
	if _lifted or _closing:
		return
	_lifted = true
	var left := hold - (Time.get_ticks_msec() - _since) / 1000.0
	if left <= 0.0:
		close()
		return
	var tw := UiMotion.tween_for(_root)
	tw.tween_interval(left)
	tw.tween_callback(close)


## Whether a click or key may send the card away now: not while it covers a place still being built.
func _can_close() -> bool:
	return not _closing and (not covering or _lifted)


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and _can_close():
			close())
	add_child(_root)
	var black := ColorRect.new()
	black.color = Look.color("void")
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(black)
	var path := picture_for(str(location.get("region", "")))
	if ResourceLoader.exists(path):
		var art := TextureRect.new()
		art.texture = load(path) as Texture2D
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(art)
	_root.add_child(CutsceneView._shade(false, 300.0, 0.9))
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CutsceneView._place(col, Vector2(0.5, 1.0), Rect2(-560, -230, 1120, 190))
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(col)
	var title := UiKit.label(str(location.get("name", "")), 40, "gilt_light")
	title.name = "Title"
	title.add_theme_font_override("font", UiKit.display_font())
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	col.add_child(UiKit.divider(360.0))
	var hint := UiKit.label(tip, 18, "vellum")
	hint.name = "Tip"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)
	_root.modulate.a = 0.0
	_since = Time.get_ticks_msec()
	var tw := UiMotion.tween_for(_root)
	tw.tween_property(_root, "modulate:a", 1.0, FADE_IN)
	if covering:
		get_tree().create_timer(MAX_COVER, true).timeout.connect(close)
		return
	tw.tween_interval(hold)
	tw.tween_callback(close)


func close() -> void:
	if _closing:
		return
	_closing = true
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	closed.emit()
	if not UiMotion.on():
		queue_free()
		return
	var tw := UiMotion.tween_for(_root)
	tw.tween_property(_root, "modulate:a", 0.0, FADE_SECONDS)
	tw.tween_callback(queue_free)


## Keys come here before the HUD's shortcuts and the game's own keys, so while the card is up nothing under it answers
## one (Escape included): it only sends the card away, once it may go.
func _input(event: InputEvent) -> void:
	if _closing or not event is InputEventKey or not (event as InputEventKey).pressed:
		return
	get_viewport().set_input_as_handled()
	if _can_close():
		close()
