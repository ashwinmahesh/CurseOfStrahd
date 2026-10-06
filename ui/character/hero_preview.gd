class_name HeroPreview
extends Control
## The custom hero's live sprite in the creator (docs/ui/character_creation.md, Appearance): the paper doll as the
## game puts it together (HeroLook), standing in a gothic arch and slowly turning through the 8 directions, or
## walking, or swinging its attack once. Taller picks stand taller in the arch.

signal turned(dir: String)

const ARCH := Vector2(270, 380)
const TURN_EVERY := 1.1
const WALK_CELL := 384.0

var appearance: Dictionary = {}
var species := "human"
var dir_index := 0
## "turn" (standing, turning), "walk" (the cycle, facing one way) or "attack" (once, then back to standing).
var mode := "turn"
var _frames: Array[Texture2D] = []
var _durations: Array[float] = []
var _frame := 0
var _clock := 0.0
var _turn_clock := 0.0
var _pic: TextureRect
var _note: Label


func _init() -> void:
	custom_minimum_size = ARCH + Vector2(0, 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic = TextureRect.new()
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pic)
	_note = UiKit.label("", 13, "parchment", ARCH.x - 40.0)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.position = Vector2(20, ARCH.y * 0.42)
	_note.size = Vector2(ARCH.x - 40.0, 80)
	add_child(_note)


func show_look(app: Dictionary, species_id: String) -> void:
	appearance = app.duplicate()
	species = species_id
	_reload()


func dir() -> String:
	return DirectionalSprite.DIRECTIONS[dir_index]


func turn(step: int) -> void:
	dir_index = posmod(dir_index + step, 8)
	_turn_clock = 0.0
	_reload()
	turned.emit(dir())


func set_mode(m: String) -> void:
	mode = m
	_reload()


func _reload() -> void:
	var kind := "walk" if mode == "walk" else ("attack" if mode == "attack" else "idle")
	_frames = HeroLook.preview_frames(appearance, kind, dir())
	_durations.clear()
	if kind == "attack" and not _frames.is_empty():
		_durations = HeroLook.attack_timing(appearance)
	_frame = 0
	_clock = 0.0
	_note.text = "" if not _frames.is_empty() else "This look's art is still being drawn."
	_layout()
	_show_frame()


## The figure fills the arch at the tallest height pick; shorter picks stand lower and smaller, feet on one line.
func _layout() -> void:
	var tallest := 0.0
	for o: Variant in HeroLook.options("heights"):
		tallest = maxf(tallest, float((o as Dictionary)["scale"]))
	var k := float(HeroLook.option("heights", str(appearance.get("height", "average"))).get("scale", 1.0)) / tallest
	var tex := _frames[0] if not _frames.is_empty() else null
	var cell := tex.get_size() if tex != null else Vector2(WALK_CELL, WALK_CELL)
	# render_walk.py frames a figure at 1.12x its height round 0.52 of it, so in a walk cell the feet are 0.964 of
	# the way down and the figure is 0.893 of the cell tall. Attack cells share the walk cell's centre and scale.
	var scale_px := (ARCH.y - 64.0) / (0.893 * WALK_CELL) * k
	var feet := cell.y / 2.0 + 0.464 * WALK_CELL
	_pic.size = cell * scale_px
	_pic.position = Vector2(ARCH.x / 2.0 - cell.x * scale_px / 2.0, ARCH.y - 14.0 - feet * scale_px)


func _show_frame() -> void:
	_pic.texture = _frames[_frame] if _frame < _frames.size() else null


func _process(delta: float) -> void:
	if _frames.is_empty():
		return
	match mode:
		"turn":
			_turn_clock += delta
			if _turn_clock >= TURN_EVERY:
				turn(1)
		"walk":
			_clock += delta
			if _clock >= 0.1:
				_clock = 0.0
				_frame = (_frame + 1) % _frames.size()
				_show_frame()
		"attack":
			_clock += delta
			var d := _durations[_frame] if _frame < _durations.size() else 0.08
			if _clock >= d:
				_clock = 0.0
				_frame += 1
				if _frame >= _frames.size():
					set_mode("turn")
					return
				_show_frame()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, ARCH)
	var pts := UiParts.arch_points(r, 70.0)
	UiParts.gradient_fill(self, pts, Look.color("ui_wine"), Look.color("ui_black"))
	# A pale pool of light where the figure stands.
	draw_set_transform(Vector2(ARCH.x / 2.0, ARCH.y - 12.0), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, ARCH.x * 0.32, Color(Look.color("parchment"), 0.09))
	draw_set_transform(Vector2.ZERO)
	UiParts.closed_line(self, pts, Look.color("gilt"), 2.0)
	var inner := UiParts.arch_points(Rect2(Vector2(7, 7), ARCH - Vector2(14, 12)), 64.0)
	UiParts.closed_line(self, inner, Color(Look.color("gilt"), 0.5), 1.0)
	UiParts.crest(self, Vector2(ARCH.x / 2.0, 0.0), 10.0)
	UiParts.brackets(self, Rect2(Vector2(4, 70), ARCH - Vector2(8, 74)), 14.0)
