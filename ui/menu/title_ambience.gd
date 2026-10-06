class_name TitleAmbience
extends Control
## Movement on the title screen (owner, 2026-10-06: "the bats are flying around, there's movement happening"): bats
## circling the castle, now and then one flying past close by, a flight bursting from the towers, the moon's glow
## breathing, crimson cloud and valley mist drifting (shaders/ui/title_mist.gdshader), the coach lamp flickering, and
## far-off lightning now and then. Everything is drawn here over the key art (art/ui/title_backdrop.png) with no new
## images and no grain; positions are in the art's own pixels, mapped through its cover scaling, so it holds at any
## window size. Cosmetic randomness only, from its own generator.

## Landmarks in the key art's pixels (1376 x 768).
const MOON := Vector2(918.0, 140.0)
const MOON_R := 152.0
const CASTLE := Vector2(925.0, 215.0)
const LAMP := Vector2(741.0, 650.0)
const TOWERS: Array[Vector2] = [Vector2(918.0, 40.0), Vector2(866.0, 160.0), Vector2(968.0, 170.0), Vector2(1077.0, 262.0),
	Vector2(757.0, 255.0)]
const CIRCLERS := 14
## A bat's right wing at rest, from the shoulder (0, 0) to the tip (1, 0), with a scalloped trailing edge. The left
## wing mirrors it; flapping rotates it about the shoulder.
const WING: Array[Vector2] = [Vector2(0.04, -0.06), Vector2(0.30, -0.16), Vector2(0.58, -0.20), Vector2(1.0, -0.06),
	Vector2(0.86, 0.06), Vector2(0.74, 0.0), Vector2(0.60, 0.14), Vector2(0.46, 0.06), Vector2(0.32, 0.18),
	Vector2(0.16, 0.10), Vector2(0.04, 0.10)]

## The key art this lies over; its texture's size and the control's size give the cover scaling.
var art: TextureRect
var time := 0.0
var _rng := RandomNumberGenerator.new()
var _bats: Array[Dictionary] = []
var _next_flyby := 3.0
var _next_burst := 9.0
var _next_flash := 14.0
var _flash := 10.0
var _bat_layer: Control
var _moon_glow: TextureRect
var _lamp_glow: TextureRect
var _sky_flash: TextureRect


func _init() -> void:
	name = "TitleAmbience"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	# Back to front: the crimson cloud veil, the moon's glow, the valley mist, the lamp, the bats, then the flash.
	add_child(_mist_layer(Look.color("blood"), 0.30, Vector2(0.006, 0.0), 2.2, Vector2(0.12, 0.44), 0.14, 0.50, 3.0))
	_moon_glow = _glow(Look.color("frost"))
	add_child(_moon_glow)
	add_child(_mist_layer(Look.color("silver"), 0.42, Vector2(0.010, 0.0), 2.6, Vector2(0.62, 1.0), 0.16, 0.46, 11.0))
	add_child(_mist_layer(Look.color("frost"), 0.22, Vector2(-0.007, 0.0), 4.0, Vector2(0.72, 1.0), 0.12, 0.52, 27.0))
	_lamp_glow = _glow(Look.color("flame"))
	add_child(_lamp_glow)
	_bat_layer = UiParts.drawn(Vector2.ZERO, _draw_bats)
	_bat_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bat_layer)
	_sky_flash = _glow(Look.color("frost"))
	_sky_flash.modulate.a = 0.0
	add_child(_sky_flash)
	for i in CIRCLERS:
		_bats.append(_circler(i))


# --- Mapping the art --------------------------------------------------------------------------------

## The art's pixels to this control's: the TextureRect covers the screen keeping its aspect, centred.
func _scale() -> float:
	var t := _art_size()
	return maxf(size.x / t.x, size.y / t.y)


func _art_size() -> Vector2:
	if art != null and art.texture != null:
		return Vector2(art.texture.get_size())
	return Vector2(1376, 768)


func to_screen(p: Vector2) -> Vector2:
	var s := _scale()
	return (size - _art_size() * s) / 2.0 + p * s


# --- Layers -----------------------------------------------------------------------------------------

func _mist_layer(colour: Color, strength: float, drift: Vector2, scale_: float, band: Vector2, soft: float,
		threshold: float, seed: float) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/ui/title_mist.gdshader")
	m.set_shader_parameter("tint", colour)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("drift", drift)
	m.set_shader_parameter("scale", scale_)
	m.set_shader_parameter("band_in", band)
	m.set_shader_parameter("soft", soft)
	m.set_shader_parameter("threshold", threshold)
	m.set_shader_parameter("seed", seed)
	r.material = m
	return r


## A soft round light, added onto what's under it.
func _glow(colour: Color) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(colour, 1.0))
	g.set_color(1, Color(colour, 0.0))
	g.add_point(0.35, Color(colour, 0.45))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	t.material = mat
	return t


func _place_glow(t: TextureRect, at: Vector2, radius: float) -> void:
	t.position = at - Vector2(radius, radius)
	t.size = Vector2(radius, radius) * 2.0


# --- Bats -------------------------------------------------------------------------------------------

## A bat circling the castle at its own distance: the far ones small and hazed toward the sky.
func _circler(i: int) -> Dictionary:
	var depth := _rng.randf_range(0.0, 1.0)
	return {"kind": "orbit", "rx": _rng.randf_range(110.0, 300.0), "ry": _rng.randf_range(40.0, 120.0),
		"cy": _rng.randf_range(-70.0, 40.0), "w": _rng.randf_range(0.18, 0.42) * (1.0 if i % 3 != 0 else -1.0),
		"a0": _rng.randf_range(0.0, TAU), "size": lerpf(17.0, 8.0, depth), "flap": _rng.randf_range(5.5, 7.5),
		"phase": _rng.randf_range(0.0, TAU), "depth": depth}


## One bat flying past close by, from one side of the screen to the other with a lazy bob.
func _flyby() -> Dictionary:
	var t := _art_size()
	var left := _rng.randf() < 0.5
	var y0 := _rng.randf_range(t.y * 0.08, t.y * 0.5)
	return {"kind": "fly", "from": Vector2(-60.0 if left else t.x + 60.0, y0),
		"to": Vector2(t.x + 60.0 if left else -60.0, y0 + _rng.randf_range(-140.0, 120.0)), "t0": time,
		"dur": _rng.randf_range(4.5, 7.5), "size": _rng.randf_range(28.0, 42.0), "flap": _rng.randf_range(4.0, 5.5),
		"phase": _rng.randf_range(0.0, TAU), "bob": _rng.randf_range(12.0, 30.0), "depth": 0.0}


## A flight bursting from one of the towers and scattering up and out.
func _burst() -> void:
	var from := TOWERS[_rng.randi_range(0, TOWERS.size() - 1)]
	for k in _rng.randi_range(6, 9):
		var a := _rng.randf_range(-PI * 0.95, -PI * 0.05)
		var dist := _rng.randf_range(500.0, 900.0)
		_bats.append({"kind": "burst", "from": from, "to": from + Vector2(cos(a), sin(a) * 0.55) * dist, "t0": time + k * 0.12,
			"dur": _rng.randf_range(4.0, 6.5), "size": _rng.randf_range(10.0, 15.0), "flap": _rng.randf_range(6.5, 8.0),
			"phase": _rng.randf_range(0.0, TAU), "bob": _rng.randf_range(6.0, 18.0), "depth": 0.3})


## Where a bat is now (art pixels), how much it banks, and whether it's done.
func _bat_state(b: Dictionary) -> Dictionary:
	match str(b["kind"]):
		"orbit":
			var a := float(b["a0"]) + time * float(b["w"])
			var p := CASTLE + Vector2(cos(a) * float(b["rx"]), float(b["cy"]) + sin(a) * float(b["ry"]))
			p.y += sin(time * 1.3 + float(b["phase"])) * 6.0
			return {"p": p, "tilt": cos(a) * 0.25 * signf(float(b["w"])), "done": false, "alpha": 1.0}
		_:
			var u := (time - float(b["t0"])) / float(b["dur"])
			if u < 0.0:
				return {"p": Vector2.ZERO, "tilt": 0.0, "done": false, "alpha": 0.0}
			var from := b["from"] as Vector2
			var to := b["to"] as Vector2
			var e := u if str(b["kind"]) == "fly" else 1.0 - pow(1.0 - u, 1.6)
			var p2 := from.lerp(to, e) + Vector2(0, sin(u * TAU * 1.5 + float(b["phase"])) * float(b["bob"]))
			var fade := clampf(u * 6.0, 0.0, 1.0) * (1.0 - clampf((u - 0.85) * 6.0, 0.0, 1.0)) if str(b["kind"]) == "burst" else 1.0
			return {"p": p2, "tilt": (to.y - from.y) / maxf(absf(to.x - from.x), 1.0) * 0.4, "done": u >= 1.0, "alpha": fade}


func _draw_bats(c: Control) -> void:
	var s := _scale()
	var sky := Look.color("ash_violet")
	for b in _bats:
		var st := _bat_state(b)
		if float(st["alpha"]) <= 0.0:
			continue
		var depth := float(b["depth"])
		var colour := Look.color("void").lerp(sky, depth * 0.55)
		colour.a = float(st["alpha"]) * lerpf(1.0, 0.8, depth)
		var beat := time * float(b["flap"]) + float(b["phase"])
		_bat(c, to_screen(st["p"] as Vector2), float(b["size"]) * s, beat, float(st["tilt"]), colour)


## One bat: a body, a head with ears, and two wings rotated about the shoulders by the beat (down quickly, up
## slowly), drawn `half_span` pixels from the body to each wing tip.
func _bat(c: CanvasItem, at: Vector2, half_span: float, beat: float, tilt: float, colour: Color) -> void:
	var f := sin(beat)
	var lift := (f if f > 0.0 else f * 0.7) * 0.75
	var fold := 0.82 + 0.18 * cos(beat)
	c.draw_set_transform(at, tilt, Vector2(half_span, half_span))
	for side: float in [1.0, -1.0]:
		var pts := PackedVector2Array()
		var rot := -lift * side
		for w in WING:
			var q := Vector2(w.x * fold, w.y).rotated(rot)
			pts.append(Vector2(q.x * side, q.y))
		c.draw_colored_polygon(pts, colour)
	var body := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		body.append(Vector2(cos(a) * 0.08, 0.04 + sin(a) * 0.17))
	c.draw_colored_polygon(body, colour)
	c.draw_circle(Vector2(0, -0.13), 0.065, colour)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-0.06, -0.15), Vector2(-0.045, -0.26), Vector2(-0.01, -0.17)]), colour)
	c.draw_colored_polygon(PackedVector2Array([Vector2(0.06, -0.15), Vector2(0.045, -0.26), Vector2(0.01, -0.17)]), colour)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Time ---------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	time += delta
	if time >= _next_flyby:
		_bats.append(_flyby())
		_next_flyby = time + _rng.randf_range(4.0, 9.0)
	if time >= _next_burst:
		_burst()
		_next_burst = time + _rng.randf_range(16.0, 26.0)
	var keep: Array[Dictionary] = []
	for b in _bats:
		if not bool(_bat_state(b)["done"]):
			keep.append(b)
	_bats = keep
	var s := _scale()
	# The moon breathes; the coach lamp flickers.
	_place_glow(_moon_glow, to_screen(MOON), MOON_R * s * 1.9)
	_moon_glow.modulate.a = 0.14 + 0.05 * sin(time * 0.55) + 0.02 * sin(time * 1.7)
	var flicker := 0.55 + 0.18 * sin(time * 13.0) * sin(time * 7.3 + 1.0) + 0.12 * sin(time * 23.0)
	_place_glow(_lamp_glow, to_screen(LAMP), 46.0 * s * (0.92 + 0.08 * sin(time * 9.0)))
	_lamp_glow.modulate.a = clampf(flicker, 0.25, 0.9)
	# Far-off lightning now and then: two quick pulses of pale light over the sky behind the castle.
	if time >= _next_flash:
		_flash = 0.0
		_next_flash = time + _rng.randf_range(18.0, 34.0)
	_flash += delta
	var pulse := 0.0
	if _flash < 0.7:
		pulse = maxf(0.0, 1.0 - absf(_flash - 0.06) / 0.06) * 0.22 + maxf(0.0, 1.0 - absf(_flash - 0.3) / 0.12) * 0.16
	_place_glow(_sky_flash, to_screen(Vector2(MOON.x - 120.0, MOON.y + 60.0)), 640.0 * s)
	_sky_flash.modulate.a = pulse
	_bat_layer.queue_redraw()
