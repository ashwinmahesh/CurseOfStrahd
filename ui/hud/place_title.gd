class_name PlaceTitle
extends CanvasLayer
## The place's name on arriving (Visual Polish Plan 6, after Octopath Traveler 2's area names): set in the display
## face over a gilt rule near the top of the screen, it rises into view as the place fades in from black, holds, and
## fades away. GameRoot.enter_location shows it whenever no loading card is up (a card names the place itself, so a
## new region or a slow change of place never shows both); a journey's arrival adds the hour beneath it. It never takes
## a click, makes way at once for a conversation or an arrival picture, and like the loading card never shows in
## headless runs or still captures (UiMotion).

## Over the HUD (10), under the menus (25), the place's fade from black (39) and the loading card (40).
const LAYER := 20
## Seconds: waiting for the black to start lifting, coming up, holding, going.
const DELAY := 0.35
const FADE_IN := 0.7
const HOLD := 2.4
const FADE_OUT := 0.9
## How far it rises as it comes up (pixels), and where its middle sits (a share of the screen's height from the top).
const RISE := 10.0
const TOP := 0.13

## Tests ask for it in headless runs.
static var headless_too := false

var place_name := ""
var _root: VBoxContainer
var _name: Label
var _sub: Label
var _game: Node = null
var _going := false


## Shows `loc`'s name over `game` (GameRoot, whose conversation and screens it makes way for). Null when a loading
## card is up over `game` (it names the place itself), when motion is off or when the place has no name.
static func show_for(game: Node, loc: Dictionary) -> PlaceTitle:
	var name_ := str(loc.get("name", ""))
	if name_ == "" or game == null or not game.is_inside_tree() or not (UiMotion.on() or headless_too):
		return null
	if game.get_children().any(func(c: Node) -> bool: return c is LoadingCard):
		return null
	for c in game.get_children():
		if c is PlaceTitle:
			(c as PlaceTitle).queue_free()   # a quick change of place: the last name goes at once
	var t := PlaceTitle.new()
	t.name = "PlaceTitle"
	t.place_name = name_
	t._game = game
	game.add_child(t)
	return t


## A line beneath the name (a journey's arrival: the hour).
func set_subtitle(text: String) -> void:
	_sub.text = text
	_sub.visible = text != ""


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = VBoxContainer.new()
	_root.name = "Title"
	_root.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_theme_constant_override("separation", 4)
	_name = UiKit.label("", 34, "gilt_light")
	_name.name = "Name"
	_name.add_theme_font_override("font", UiKit.display_font())
	_name.add_theme_constant_override("outline_size", 8)
	_name.add_theme_color_override("font_outline_color", Look.color("void"))
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_name)
	_root.add_child(UiKit.divider(300.0))
	_sub = UiKit.label("", 17, "vellum")
	_sub.name = "Subtitle"
	_sub.add_theme_constant_override("outline_size", 6)
	_sub.add_theme_color_override("font_outline_color", Look.color("void"))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub.visible = false
	_root.add_child(_sub)
	add_child(_root)


func _ready() -> void:
	_name.text = place_name
	_root.anchor_left = 0.5
	_root.anchor_right = 0.5
	_root.anchor_top = TOP
	_root.anchor_bottom = TOP
	_root.custom_minimum_size = Vector2(minf(900.0, get_viewport().get_visible_rect().size.x - 80.0), 0.0)
	_root.offset_left = -_root.custom_minimum_size.x / 2.0
	_root.offset_right = _root.custom_minimum_size.x / 2.0
	_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.modulate.a = 0.0
	if headless_too and not UiMotion.on():
		_root.modulate.a = 1.0   # a test reads it as it stands
		return
	_rise(RISE)
	var tw := UiMotion.tween_for(_root)
	tw.tween_interval(DELAY)
	tw.tween_property(_root, "modulate:a", 1.0, FADE_IN).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_method(_rise, RISE, 0.0, FADE_IN).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_interval(HOLD)
	tw.tween_callback(go.bind(FADE_OUT))


## Sits `r` pixels below its place.
func _rise(r: float) -> void:
	_root.offset_top = r
	_root.offset_bottom = r


## Fades away over `seconds` and goes.
func go(seconds: float = FADE_OUT) -> void:
	if _going:
		return
	_going = true
	var tw := UiMotion.tween_for(_root) if is_inside_tree() else null
	if tw == null or seconds <= 0.0:
		queue_free()
		return
	tw.tween_property(_root, "modulate:a", 0.0, seconds)
	tw.tween_callback(queue_free)


func _process(_delta: float) -> void:
	# A conversation or a screen (an arrival picture, a menu) opened: the name makes way at once.
	if not _going and is_instance_valid(_game) and (_game.get("dialogue") != null or _game.get("screen") != null):
		go(0.2)
