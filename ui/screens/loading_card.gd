class_name LoadingCard
extends CanvasLayer
## G5, the loading card (docs/ui/loading_cards.md): arriving in a new region, the screen shows that region's
## establishing picture from the cutscenes (data/loading/cards.json), the place's name over it and a tip, while the
## place settles in behind; it fades after a moment, or at a click or any key. Never in headless runs or still captures
## (UiMotion), so tests and screenshots see the place itself.

signal closed

const DATA := "res://data/loading/cards.json"
const HOLD_SECONDS := 2.4
const FADE_SECONDS := 0.6

static var _data: Dictionary = {}
static var _rng := RandomNumberGenerator.new()   # cosmetic: which tip

var location: Dictionary = {}
var tip := ""
var _closing := false
var _root: Control


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
	if not UiMotion.on() or parent == null or not parent.is_inside_tree():
		return null
	var card := LoadingCard.new()
	card.location = loc
	var all := tips()
	card.tip = str(all[_rng.randi_range(0, all.size() - 1)]) if not all.is_empty() else ""
	parent.add_child(card)
	return card


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed:
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
	var tw := UiMotion.tween_for(_root)
	tw.tween_property(_root, "modulate:a", 1.0, 0.25)
	tw.tween_interval(HOLD_SECONDS)
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


func _unhandled_input(event: InputEvent) -> void:
	if not _closing and event is InputEventKey and (event as InputEventKey).pressed:
		get_viewport().set_input_as_handled()
		close()
