class_name TitleAmbience
extends Control
## Movement on the title screen (owner, 2026-10-06: "the bats are flying around, there's movement happening", then
## "more motion ... wind blowing, people walking"): bats circling the castle, now and then one flying past close by and
## a flight bursting from the towers; crows lifting out of the pines; wind swaying the pines (shaders/ui/
## title_wind.gdshader) and blowing leaves and ash across, stronger in gusts; travellers walking the castle road, one
## with a lantern (their walk cycles from art/sprites); the moon's glow breathing, crimson cloud and valley mist
## drifting (shaders/ui/title_mist.gdshader), the coach lamp flickering, and far-off lightning now and then.
## Everything is drawn over the key art (art/ui/title_backdrop.png) with no new images and no grain; positions are in
## the art's own pixels, mapped through its cover scaling, so it holds at any window size. Cosmetic randomness only,
## from its own generator.

## Landmarks in the key art's pixels (1376 x 768).
const MOON := Vector2(918.0, 140.0)
const MOON_R := 152.0
const CASTLE := Vector2(925.0, 215.0)
const LAMP := Vector2(741.0, 650.0)
const TOWERS: Array[Vector2] = [Vector2(918.0, 40.0), Vector2(866.0, 160.0), Vector2(968.0, 170.0), Vector2(1077.0, 262.0),
	Vector2(757.0, 255.0)]
const CIRCLERS := 14
## The castle road from just past the coach, up the switchback, in the art's pixels.
const ROAD: Array[Vector2] = [Vector2(796.0, 676.0), Vector2(850.0, 655.0), Vector2(917.0, 634.0), Vector2(977.0, 613.0),
	Vector2(1003.0, 596.0), Vector2(1006.0, 583.0), Vector2(984.0, 564.0), Vector2(927.0, 555.0), Vector2(870.0, 549.0),
	Vector2(850.0, 545.0), Vector2(910.0, 528.0), Vector2(967.0, 507.0), Vector2(1024.0, 485.0), Vector2(1069.0, 461.0),
	Vector2(1083.0, 449.0)]
## Who walks the road: a sprite with a walk sheet, whether they carry a lantern, and which way they go (1 up to the
## castle, -1 down from it; owner: "more travellers, and someone leaving the castle").
## Travellers' sheets are drawn some 20 times smaller than rendered (shaders/ui/sprite_small.gdshader).
const SMALL_SPRITE := preload("res://shaders/ui/sprite_small.gdshader")
const WALKERS := [["luvash", true, 1], ["commoner", false, 1], ["arabelle", false, 1], ["villager", false, 1],
	["vistana", true, -1], ["noble", false, -1]]
## Pine forests in the key art (min and max corner, in its pixels): the wind sways them.
const FORESTS := [[Vector2(1130, 330), Vector2(1376, 768)], [Vector2(880, 560), Vector2(1180, 768)],
	[Vector2(0, 420), Vector2(270, 660)], [Vector2(100, 500), Vector2(480, 640)]]
## Where crows roost (the tops of the near pines, right).
const ROOSTS: Array[Vector2] = [Vector2(1200.0, 470.0), Vector2(1290.0, 430.0), Vector2(1335.0, 520.0), Vector2(1010.0, 600.0)]
const FLECKS := 34
## A bat's right wing at rest, from the shoulder (0, 0) to the tip (1, 0), with a scalloped trailing edge. The left
## wing mirrors it; flapping rotates it about the shoulder.
const WING: Array[Vector2] = [Vector2(0.04, -0.06), Vector2(0.30, -0.16), Vector2(0.58, -0.20), Vector2(1.0, -0.06),
	Vector2(0.86, 0.06), Vector2(0.74, 0.0), Vector2(0.60, 0.14), Vector2(0.46, 0.06), Vector2(0.32, 0.18),
	Vector2(0.16, 0.10), Vector2(0.04, 0.10)]

## A crow's wing: broader than a bat's, with fingered tips.
const CROW_WING: Array[Vector2] = [Vector2(0.04, -0.08), Vector2(0.35, -0.16), Vector2(0.70, -0.14), Vector2(0.92, -0.10),
	Vector2(1.0, -0.03), Vector2(0.93, 0.0), Vector2(0.97, 0.05), Vector2(0.86, 0.06), Vector2(0.88, 0.11),
	Vector2(0.74, 0.12), Vector2(0.50, 0.14), Vector2(0.20, 0.12), Vector2(0.04, 0.08)]

## The key art this lies over; its texture's size and the control's size give the cover scaling.
var art: TextureRect
var time := 0.0
## Wind strength now, 0 (still) to 1 (a gust); it sways the pines, blows the flecks and bends the lantern flame.
var gust := 0.4
var _wind: ShaderMaterial
var _walkers: Array[Dictionary] = []
var _flecks: Array[Dictionary] = []
var _next_crows := 6.0
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
	var ups := 0
	var downs := 0
	for w: Variant in WALKERS:
		var way := int((w as Array)[2])
		_add_walker(str((w as Array)[0]), bool((w as Array)[1]), way, ups if way > 0 else downs)
		if way > 0:
			ups += 1
		else:
			downs += 1
	_bat_layer = UiParts.drawn(Vector2.ZERO, _draw_bats)
	_bat_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bat_layer)
	_sky_flash = _glow(Look.color("frost"))
	_sky_flash.modulate.a = 0.0
	add_child(_sky_flash)
	for i in CIRCLERS:
		_bats.append(_circler(i))
	for i in FLECKS:
		_flecks.append(_fleck(true))
	if art != null:
		_wind = ShaderMaterial.new()
		_wind.shader = preload("res://shaders/ui/title_wind.gdshader")
		var t := _art_size()
		var rects: Array[Vector4] = []
		for f: Variant in FORESTS:
			var lo := ((f as Array)[0] as Vector2) / t
			var hi := ((f as Array)[1] as Vector2) / t
			rects.append(Vector4(lo.x, lo.y, hi.x, hi.y))
		while rects.size() < 6:
			rects.append(Vector4.ZERO)
		_wind.set_shader_parameter("forests", rects)
		_wind.set_shader_parameter("forest_count", FORESTS.size())
		art.material = _wind


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
	_draw_flecks(c)
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
		_bat(c, to_screen(st["p"] as Vector2), float(b["size"]) * s, beat, float(st["tilt"]), colour, bool(b.get("crow", false)))


## One bat: a body, a head with ears, and two wings rotated about the shoulders by the beat (down quickly, up
## slowly), drawn `half_span` pixels from the body to each wing tip.
func _bat(c: CanvasItem, at: Vector2, half_span: float, beat: float, tilt: float, colour: Color, crow: bool = false) -> void:
	var f := sin(beat)
	var lift := (f if f > 0.0 else f * 0.7) * 0.75
	var fold := 0.82 + 0.18 * cos(beat)
	c.draw_set_transform(at, tilt, Vector2(half_span, half_span))
	for side: float in [1.0, -1.0]:
		var pts := PackedVector2Array()
		var rot := -lift * side
		for w in (CROW_WING if crow else WING):
			var q := Vector2(w.x * fold, w.y).rotated(rot)
			pts.append(Vector2(q.x * side, q.y))
		c.draw_colored_polygon(pts, colour)
	var body := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		body.append(Vector2(cos(a) * 0.08, 0.04 + sin(a) * 0.17))
	c.draw_colored_polygon(body, colour)
	c.draw_circle(Vector2(0, -0.13), 0.065, colour)
	if crow:
		# A beak and a fanned tail instead of ears.
		c.draw_colored_polygon(PackedVector2Array([Vector2(-0.025, -0.17), Vector2(0.0, -0.26), Vector2(0.025, -0.17)]), colour)
		c.draw_colored_polygon(PackedVector2Array([Vector2(-0.05, 0.18), Vector2(-0.10, 0.34), Vector2(0.10, 0.34), Vector2(0.05, 0.18)]), colour)
	else:
		c.draw_colored_polygon(PackedVector2Array([Vector2(-0.06, -0.15), Vector2(-0.045, -0.26), Vector2(-0.01, -0.17)]), colour)
		c.draw_colored_polygon(PackedVector2Array([Vector2(0.06, -0.15), Vector2(0.045, -0.26), Vector2(0.01, -0.17)]), colour)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Travellers on the road -------------------------------------------------------------------------

## A traveller: their walk sheet (sized by its cell, which is 384 or, for HD sheets, 768 px), darkened to the night,
## starting partway along the road so the road is never empty; `way` 1 climbs to the castle, -1 comes down from it.
func _add_walker(sprite_id: String, lantern: bool, way: int, i: int) -> void:
	var path := "res://art/sprites/%s/walk.tres" % sprite_id
	if not ResourceLoader.exists(path):
		return
	var s := AnimatedSprite2D.new()
	s.sprite_frames = load(path) as SpriteFrames
	var cell := float(DirectionalSprite.cell_size(s.sprite_frames))
	s.animation = DirectionalSprite.anim_for(s.sprite_frames, "walk", "e")[0] as StringName
	# The figure stands about 7/8 of its cell tall, its feet 7/16 of a cell below the centre.
	s.offset = Vector2(0, -cell * 0.4375)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := ShaderMaterial.new()
	mat.shader = SMALL_SPRITE
	s.material = mat
	s.modulate = Look.color("silver").lerp(Look.color("moon_blue"), 0.3)
	add_child(s)
	var glow: TextureRect = null
	if lantern:
		glow = _glow(Look.color("flame"))
		add_child(glow)
	var total := _road_length()
	var start := 0.08 + 0.23 * i if way > 0 else 0.9 - 0.4 * i
	_walkers.append({"sprite": s, "glow": glow, "d": total * start, "speed": _rng.randf_range(8.5, 12.0), "way": way,
		"figure": cell * 0.875,
		"wait": 0.0, "phase": _rng.randf_range(0.0, 8.0)})


func _road_length() -> float:
	var total := 0.0
	for i in range(1, ROAD.size()):
		total += ROAD[i - 1].distance_to(ROAD[i])
	return total


## The point `d` along the road and the direction it heads there.
func _road_at(d: float) -> Array:
	var left := d
	for i in range(1, ROAD.size()):
		var seg := ROAD[i - 1].distance_to(ROAD[i])
		if left <= seg:
			return [ROAD[i - 1].lerp(ROAD[i], left / seg), (ROAD[i] - ROAD[i - 1]).normalized()]
		left -= seg
	return [ROAD[ROAD.size() - 1], (ROAD[ROAD.size() - 1] - ROAD[ROAD.size() - 2]).normalized()]


func _step_walkers(delta: float) -> void:
	var s := _scale()
	var total := _road_length()
	for w in _walkers:
		var sprite := w["sprite"] as AnimatedSprite2D
		var glow := w["glow"] as TextureRect
		if float(w["wait"]) > 0.0:
			w["wait"] = float(w["wait"]) - delta
			sprite.visible = false
			if glow != null:
				glow.visible = false
			continue
		var way := int(w["way"])
		w["d"] = float(w["d"]) + float(w["speed"]) * delta * way
		if float(w["d"]) >= total or float(w["d"]) <= 0.0:
			# At the end of the road: gone a while, then someone sets out again from the start.
			w["d"] = 0.0 if way > 0 else total
			w["wait"] = _rng.randf_range(3.0, 10.0)
			continue
		var at := _road_at(float(w["d"]))
		var p := at[0] as Vector2
		var dir := (at[1] as Vector2) * way
		# Smaller as the road climbs away; faded in at the start and out at the castle end.
		var near := clampf(inverse_lerp(449.0, 676.0, p.y), 0.0, 1.0)
		var height := lerpf(18.0, 36.0, near)
		var u := float(w["d"]) / total
		var fade := clampf(u * 12.0, 0.0, 1.0) * clampf((1.0 - u) * 10.0, 0.0, 1.0)
		sprite.visible = true
		sprite.position = to_screen(p)
		sprite.scale = Vector2.ONE * height * s / float(w["figure"])
		# HD sheets draw only one of each mirror pair of directions (DirectionalSprite.anim_for).
		var shown := DirectionalSprite.anim_for(sprite.sprite_frames, "walk", "ne" if dir.y < -0.75 else ("se" if dir.y > 0.75 else "e"))
		sprite.flip_h = (dir.x > 0.0) != bool(shown[1])
		sprite.animation = shown[0] as StringName
		sprite.frame = int(float(w["d"]) / 3.2) % sprite.sprite_frames.get_frame_count(sprite.animation)
		sprite.modulate.a = fade
		if glow != null:
			var hand := p + Vector2(4.0 * (1.0 if dir.x > 0.0 else -1.0), -height * 0.42) * (height / 30.0)
			var flicker := 0.7 + 0.2 * sin(time * 11.0 + float(w["phase"])) * sin(time * 6.3) - gust * 0.15
			_place_glow(glow, to_screen(hand), 9.0 * s * (height / 30.0) * (0.9 + 0.1 * sin(time * 8.0)))
			glow.visible = true
			glow.modulate.a = clampf(flicker, 0.3, 0.95) * fade


# --- Wind -------------------------------------------------------------------------------------------

## Gusts come and go: a slow swell with quicker flurries on top.
func _gust_at(t: float) -> float:
	var swell := 0.5 + 0.5 * sin(t * 0.21) * sin(t * 0.083 + 1.3)
	var flurry := 0.5 + 0.5 * sin(t * 1.1 + sin(t * 0.37) * 2.0)
	return clampf(0.25 + swell * 0.55 + flurry * 0.2, 0.0, 1.0)


## A leaf or a fleck of ash on the wind, starting anywhere (or off the left edge).
func _fleck(anywhere: bool) -> Dictionary:
	var t := _art_size()
	var leaf := _rng.randf() < 0.45
	return {"p": Vector2(_rng.randf_range(0.0, t.x) if anywhere else _rng.randf_range(-60.0, -10.0), _rng.randf_range(t.y * 0.25, t.y)),
		"speed": _rng.randf_range(40.0, 90.0), "fall": _rng.randf_range(4.0, 14.0), "phase": _rng.randf_range(0.0, TAU),
		"size": _rng.randf_range(3.5, 5.5) if leaf else _rng.randf_range(1.6, 2.6), "leaf": leaf,
		"spin": _rng.randf_range(1.5, 4.0)}


func _step_flecks(delta: float) -> void:
	var t := _art_size()
	for i in _flecks.size():
		var f := _flecks[i]
		var p := f["p"] as Vector2
		p.x += float(f["speed"]) * (0.25 + gust * 1.2) * delta
		p.y += (float(f["fall"]) + sin(time * 1.7 + float(f["phase"])) * 18.0 * (0.4 + gust)) * delta
		f["p"] = p
		if p.x > t.x + 30.0 or p.y > t.y + 20.0:
			_flecks[i] = _fleck(false)


func _draw_flecks(c: Control) -> void:
	var s := _scale()
	for f in _flecks:
		var at := to_screen(f["p"] as Vector2)
		var r := float(f["size"]) * s
		var turn := time * float(f["spin"]) + float(f["phase"])
		if bool(f["leaf"]):
			# A leaf tumbling: a lozenge that narrows as it turns edge-on.
			var w := r * (0.35 + 0.65 * absf(cos(turn)))
			var pts := PackedVector2Array([Vector2(0, -r), Vector2(w * 0.6, 0), Vector2(0, r), Vector2(-w * 0.6, 0)])
			c.draw_set_transform(at, turn * 0.5, Vector2.ONE)
			c.draw_colored_polygon(pts, Color(Look.color("tan").lerp(Look.color("rust"), 0.4), 0.9))
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			c.draw_circle(at, r * 0.5, Color(Look.color("silver"), 0.55))


# --- Crows ------------------------------------------------------------------------------------------

## A few crows lift out of the pines together and fly off over the valley.
func _crows() -> void:
	var from := ROOSTS[_rng.randi_range(0, ROOSTS.size() - 1)]
	var away := -1.0 if from.x > 900.0 else 1.0
	for k in _rng.randi_range(3, 6):
		var a := _rng.randf_range(-0.9, -0.25)
		var dist := _rng.randf_range(700.0, 1000.0)
		_bats.append({"kind": "burst", "crow": true, "from": from + Vector2(_rng.randf_range(-25.0, 25.0), _rng.randf_range(-10.0, 10.0)),
			"to": from + Vector2(cos(a) * away, sin(a)) * dist, "t0": time + k * 0.25, "dur": _rng.randf_range(6.0, 9.0),
			"size": _rng.randf_range(11.0, 15.0), "flap": _rng.randf_range(3.0, 4.2), "phase": _rng.randf_range(0.0, TAU),
			"bob": _rng.randf_range(8.0, 16.0), "depth": 0.1})


# --- Time ---------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	time += delta
	if time >= _next_flyby:
		_bats.append(_flyby())
		_next_flyby = time + _rng.randf_range(4.0, 9.0)
	if time >= _next_burst:
		_burst()
		_next_burst = time + _rng.randf_range(16.0, 26.0)
	if time >= _next_crows:
		_crows()
		_next_crows = time + _rng.randf_range(12.0, 22.0)
	gust = _gust_at(time)
	if _wind != null:
		_wind.set_shader_parameter("gust", gust)
	_step_flecks(delta)
	_step_walkers(delta)
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
