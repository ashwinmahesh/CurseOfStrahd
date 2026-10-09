class_name PlaceDissolve
extends CanvasLayer
## A new place resolving out of a soft blur as the black lifts (Visual Polish Plan 10, shaders/post/place_dissolve
## .gdshader): GameRoot._fade_in_place starts it with the place's fade from black, and the world sharpens a little
## after the black has gone, so a change of place reads as a haze clearing rather than a cut through black. One layer
## per game, over the world and under the HUD (which stays crisp), shown only while a place comes in. Like the rest of
## the interface's motion it's off in headless runs and still captures (UiMotion).

const SHADER := preload("res://shaders/post/place_dissolve.gdshader")
## Over the world, under the HUD (10) and everything over it.
const LAYER := 5
## Seconds the world takes to sharpen once the black starts lifting (the black takes 0.6).
const SECONDS := 1.0

## Tests ask for it in headless runs.
static var headless_too := false

var _mat: ShaderMaterial
var _tw: Tween = null


static func on() -> bool:
	return UiMotion.on() or headless_too


## The place coming in over `game` sharpens out of a blur, starting `delay` seconds from now. The layer, or null when
## motion is off.
static func play(game: Node, delay: float) -> PlaceDissolve:
	if not on() or game == null or not game.is_inside_tree():
		return null
	var d := game.get_node_or_null("PlaceDissolve") as PlaceDissolve
	if d == null:
		d = PlaceDissolve.new()
		d.name = "PlaceDissolve"
		game.add_child(d)
	d._play(delay)
	return d


func _init() -> void:
	layer = LAYER
	visible = false
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	var r := ColorRect.new()
	r.name = "Blur"
	r.material = _mat
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(r)


func _play(delay: float) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_mat.set_shader_parameter("lines", get_viewport().get_visible_rect().size.y)
	set_amount(1.0)
	visible = true
	# Paused game or not, like the fade from black it goes with (an arrival picture pauses the game as it opens).
	_tw = UiMotion.tween_for(self)
	_tw.tween_interval(delay)
	_tw.tween_method(set_amount, 1.0, 0.0, SECONDS).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_tw.tween_callback(func() -> void: visible = false)


func set_amount(k: float) -> void:
	_mat.set_shader_parameter("amount", k)


## How soft the world is now (0 when sharp).
func amount() -> float:
	return float(_mat.get_shader_parameter("amount")) if visible else 0.0
