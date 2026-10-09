class_name D20Die
extends Control
## The big d20 itself (docs/ui/d20_roll.md): a 3D emerald die with gold numerals, drawn in a small 3D world of its own
## (a SubViewport) and shown as a picture reaching well past this control's box on every side, so the die can tumble in
## from outside it; the picture fades out toward its edges. `roll()` throws it onto an unseen table: in from the lower
## left, bouncing lower each time, spinning slower and slower, tipping over one last edge and rocking back, until it
## rests square to the camera on the true number. A band of light crosses it as it lands, the number swells, and
## `landed` fires. `show_landed()` puts it there at once (no motion: headless runs, still captures).
##
## Under Advantage or Disadvantage two dice roll together; the one not kept lands to the right, shrinks and greys.
## The whole motion is a function of time (`seek`), so a capture can step it frame by frame. The 3D world draws only
## while something moves, then keeps its last picture.

signal landed

const SHADER := preload("res://shaders/ui/emerald_die.gdshader")
const FEATHER := preload("res://shaders/ui/die_feather.gdshader")
const CAPS_FACE := "res://art/sourced/google_fonts/cinzel/Cinzel[wght].ttf"

## Seconds from the throw to resting, at pace 1 (fast combat halves it).
const ROLL_SECONDS := 1.45
## The landing's band of light, flash and swelling number, after it rests.
const SHINE_SECONDS := 0.6
## The picture reaches this share of the box's height past each side.
const MARGIN := 0.7
## Half the box's height in the die's world: a die (circumradius 1) just fits.
const BOX_HALF := 1.0
const CAMERA_DISTANCE := 9.0
## The second die (the one not kept) ends this size beside the first, in a box this much wider than tall.
const SECOND_SCALE := 0.62
const TWO_WIDE := 1.62
## When it bounces, as shares of the roll, and how high each bounce goes (die widths toward the camera).
const BOUNCES: Array[float] = [0.24, 0.45, 0.62, 0.74]
const BOUNCE_HEIGHTS: Array[float] = [1.8, 0.85, 0.35, 0.1]
## The spin stops this far through the roll, tipped a little past its face; the rest is the rock back.
const SPIN_SHARE := 0.84
const TIP := 0.5

## The number on top: the kept die.
var number := 20
## The other die under Advantage or Disadvantage, or 0.
var other := 0
## Seconds are multiplied by this (fast combat: GameSettings.combat_pace()).
var pace := 1.0
## Greyed out (an automatic failure: no die is really rolled).
var dim := false
## "crit" (gold flash, a natural 20), "fumble" (red, a natural 1) or "".
var tone := ""
## A capture steps the motion itself (seek) instead of the clock.
var manual := false

var _vp: SubViewport
var _pic: TextureRect
var _cam: Camera3D
var _dice: Array[Node3D] = []
var _mats: Array[ShaderMaterial] = []
var _labels: Array[Dictionary] = []   ## per die: number -> Label3D
var _plans: Array[Dictionary] = []
var _t := 0.0
var _moving := false
var _did_land := false
var _bounced := 0
var _rng := RandomNumberGenerator.new()   # cosmetic: how this throw tumbles
var _fov := 30.0

static var _font: Font = null


func _init() -> void:
	name = "D20Die"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic = TextureRect.new()
	_pic.name = "Picture"
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_SCALE
	var feather := ShaderMaterial.new()
	feather.shader = FEATHER
	_pic.material = feather
	_pic.z_index = 1   # over the words beside it while it flies in
	add_child(_pic)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.size = Vector2i(64, 64)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_pic.add_child(_vp)
	_pic.texture = _vp.get_texture()
	_build_world()
	resized.connect(_fit)


func _ready() -> void:
	_fit()


## Throws the die to land on `kept` (and a second die on `other_`, under Advantage or Disadvantage).
func roll(kept: int, other_: int = 0) -> void:
	number = clampi(kept, 1, 20)
	other = clampi(other_, 0, 20)
	_rng.randomize()
	_plan()
	_t = 0.0
	_did_land = false
	_bounced = 0
	_moving = true
	if not manual:
		Audio.sfx("die_throw", 0.03)
	_fit()
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	set_process(not manual)
	_pose()


## The die already at rest on `kept`, no motion.
func show_landed(kept: int, other_: int = 0) -> void:
	number = clampi(kept, 1, 20)
	other = clampi(other_, 0, 20)
	_rng.seed = 1
	_plan()
	_t = _end_time() + SHINE_SECONDS
	_did_land = true
	_moving = false
	set_process(false)
	_pose()
	_redraw_once()


## Skips to the end of the throw (a click, a key or a button while it rolls): it rests at once and still shines.
func finish() -> void:
	if _moving and _t < ROLL_SECONDS * pace:
		_t = ROLL_SECONDS * pace
		_pose()


## Seconds since the throw, set by hand (captures).
func seek(t: float) -> void:
	_t = maxf(t, 0.0)
	_moving = _t < _end_time()
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_pose()


func rolling() -> bool:
	return _moving and not _did_land


func _process(delta: float) -> void:
	if not _moving:
		set_process(false)
		return
	_t += delta
	_pose()
	if _t >= _end_time():
		_moving = false
		set_process(false)
		_redraw_once()


func _end_time() -> float:
	return ROLL_SECONDS * pace + SHINE_SECONDS * clampf(pace, 0.7, 1.0)


func _redraw_once() -> void:
	# One more picture with everything at its end, then the 3D world rests.
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


# --- The little world the die lives in ---------------------------------------------------------------------------------

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Look.color("emerald_light").lerp(Look.color("vellum"), 0.5)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	# A warm key light up and to the left in front, a cool emerald rim from behind, a faint fill from below.
	_light(Vector3(-0.55, 0.75, 0.9), Look.color("ivory"), 1.15)
	_light(Vector3(0.7, 0.55, -0.8), Look.color("emerald_light"), 0.9)
	_light(Vector3(0.35, -0.8, 0.5), Look.color("frost"), 0.25)
	_cam = Camera3D.new()
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.near = 0.5
	_cam.far = 40.0
	_cam.position = Vector3(0.0, -1.5, CAMERA_DISTANCE)
	_vp.add_child(_cam)
	_cam.look_at_from_position(_cam.position, Vector3.ZERO, Vector3.UP)
	_fov = rad_to_deg(2.0 * atan(BOX_HALF * (1.0 + 2.0 * MARGIN) / _cam.position.length()))
	_cam.fov = _fov
	for i in 2:
		_dice.append(_make_die(i))


func _light(from: Vector3, colour: Color, energy: float) -> void:
	var l := DirectionalLight3D.new()
	l.light_color = colour
	l.light_energy = energy
	_vp.add_child(l)
	l.look_at_from_position(from.normalized() * 5.0, Vector3.ZERO, Vector3.UP if absf(from.normalized().y) < 0.95 else Vector3.FORWARD)


func _make_die(i: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Die%d" % i
	var mi := MeshInstance3D.new()
	mi.mesh = D20Mesh.mesh()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("deep", Look.color("emerald_deep"))
	mat.set_shader_parameter("body", Look.color("emerald"))
	mat.set_shader_parameter("bright", Look.color("emerald_bright"))
	mat.set_shader_parameter("light", Look.color("emerald_light"))
	mat.set_shader_parameter("glint", Look.color("emerald_glint"))
	mi.material_override = mat
	root.add_child(mi)
	_mats.append(mat)
	var labels := {}
	for f in D20Mesh.faces():
		var n := int(f["number"])
		var l := Label3D.new()
		l.text = str(n) + ("." if n in [6, 9] else "")
		l.font = numeral_font()
		l.font_size = 112
		l.pixel_size = 0.0027
		l.outline_size = 9
		l.modulate = Look.color("gilt_light")
		l.outline_modulate = Look.color("emerald_deep")
		l.shaded = true
		l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
		l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var nrm := f["normal"] as Vector3
		var up := f["up"] as Vector3
		l.transform = Transform3D(Basis(up.cross(nrm), up, nrm), (f["center"] as Vector3) + nrm * 0.004)
		root.add_child(l)
		labels[n] = l
	_labels.append(labels)
	_vp.add_child(root)
	root.visible = i == 0
	return root


## The face numerals' type: Cinzel at its boldest, a distance field so it stays sharp at any size.
static func numeral_font() -> Font:
	if _font == null:
		var v := FontVariation.new()
		v.base_font = load(CAPS_FACE) as FontFile
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
		_font = v
	return _font


## The picture's size: past the box by MARGIN of its height each side, in screen pixels so the die is sharp.
func _fit() -> void:
	var m := size.y * MARGIN
	_pic.position = Vector2(-m, -m)
	_pic.size = size + Vector2(m, m) * 2.0
	var px := _pic.size
	if is_inside_tree():
		# The canvas's scale and the window's (its stretch, the player's interface size, a Retina screen).
		px *= get_global_transform_with_canvas().get_scale().x * get_viewport().get_final_transform().get_scale().x
	_vp.size = Vector2i(clampi(int(px.x), 16, 2048), clampi(int(px.y), 16, 2048))
	_cam.fov = _fov


# --- The throw ---------------------------------------------------------------------------------------------------------

## Where each die rests, how it starts, and how it tumbles: picked once a throw, then the motion is only a function of
## time.
func _plan() -> void:
	_plans.clear()
	var two := other > 0
	_dice[1].visible = two
	var half_w := BOX_HALF * TWO_WIDE
	var rest0 := Vector2(-(half_w - 1.0), 0.04) if two else Vector2.ZERO
	var rest1 := Vector2(half_w - SECOND_SCALE, -(BOX_HALF - SECOND_SCALE) - 0.05)
	_plans.append(_plan_die(number, rest0, Vector2(-3.9, -2.6), 0.0))
	if two:
		_plans.append(_plan_die(other, rest1, Vector2(-3.1, -3.3), 0.07))
	for i in _dice.size():
		var m := _mats[i]
		m.set_shader_parameter("dim", 0.0)
		m.set_shader_parameter("flash", 0.0)
		m.set_shader_parameter("sweep", -9.0)
		var fc := "emerald_glint"
		if i == 0 and tone == "crit":
			fc = "gilt_light"
		elif i == 0 and tone == "fumble":
			fc = "vampire_red"
		m.set_shader_parameter("flash_color", Look.color(fc))
		for l: Label3D in (_labels[i] as Dictionary).values():
			l.modulate = Look.color("gilt_light")
			l.scale = Vector3.ONE


func _plan_die(face: int, rest: Vector2, start: Vector2, delay: float) -> Dictionary:
	var from := rest + start + Vector2(_rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.4, 0.4))
	var dir := (rest - from).normalized()
	# Rolling along `dir` on the table turns the die about the table's normal crossed with it, tilted a little.
	var axis := Vector3(-dir.y, dir.x, 0.0).rotated(Vector3(0, 0, 1), _rng.randf_range(-0.45, 0.45))
	axis = axis.rotated(Vector3(dir.x, dir.y, 0).normalized(), _rng.randf_range(-0.35, 0.35)).normalized()
	return {"face": face, "rest": rest, "from": from, "delay": delay, "axis": axis,
		"spin": _rng.randf_range(10.0, 13.0), "twist": _rng.randf_range(-1.3, 1.3), "final": D20Mesh.rest_basis(face)}


## Every die at time `_t`, and what happens as it passes each moment (a bounce, the landing).
func _pose() -> void:
	var roll_time := ROLL_SECONDS * pace
	for i in _plans.size():
		var p := _plans[i]
		var t := clampf((_t - float(p["delay"]) * pace) / maxf(roll_time - float(p["delay"]) * pace, 0.001), 0.0, 1.0)
		var size_now := 1.0 if i == 0 else lerpf(1.0, SECOND_SCALE, _ease(clampf((_t - roll_time) / 0.25, 0.0, 1.0)))
		var at := pose_at(p, t, size_now)
		_dice[i].transform = at
	var since := _t - roll_time
	# Bounces: a clink each time the first die meets the table, softer each time.
	while _bounced < BOUNCES.size() and _t >= BOUNCES[_bounced] * roll_time:
		if _moving and not manual:
			Audio.sfx("die_bounce", 0.1, -4.0 * _bounced)
		_bounced += 1
	if since >= 0.0 and not _did_land:
		_did_land = true
		if _moving and not manual:
			Audio.sfx("die_land", 0.04)
		landed.emit()
	_shine(since)


## Die `p`'s place and turn at `t` (0 thrown, 1 at rest), drawn `scale_` times its size.
static func pose_at(p: Dictionary, t: float, scale_: float = 1.0) -> Transform3D:
	var spin_t := clampf(t / SPIN_SHARE, 0.0, 1.0)
	var theta: float
	if t < SPIN_SHARE:
		# Slowing evenly (an easing of two): the last faces still turn past near the end, so the number shows late.
		theta = -float(p["spin"]) + (float(p["spin"]) + TIP) * (1.0 - pow(1.0 - spin_t, 2.0))
	else:
		var s := (t - SPIN_SHARE) / (1.0 - SPIN_SHARE)
		theta = TIP * pow(1.0 - s, 2.0) * cos(2.5 * PI * s)
	var twist := float(p["twist"]) * (1.0 - _ease(spin_t))
	var b := Basis(Vector3(0, 0, 1), twist) * Basis(p["axis"] as Vector3, theta) * (p["final"] as Basis)
	var slide := _ease(clampf(t / 0.9, 0.0, 1.0))
	var xy := (p["from"] as Vector2).lerp(p["rest"] as Vector2, slide)
	var r := D20Mesh.inradius()
	var z := -r + r * scale_ + height_at(t)
	return Transform3D(b.scaled(Vector3.ONE * scale_), Vector3(xy.x, xy.y, z))


## How high above the table the die is at `t`: dropped from above, then each bounce lower than the last.
static func height_at(t: float) -> float:
	if t < BOUNCES[0]:
		var u := t / BOUNCES[0]
		return BOUNCE_HEIGHTS[0] * (1.0 - u * u)
	for k in range(1, BOUNCES.size()):
		if t < BOUNCES[k]:
			var u := (t - BOUNCES[k - 1]) / (BOUNCES[k] - BOUNCES[k - 1])
			return 4.0 * BOUNCE_HEIGHTS[k] * u * (1.0 - u)
	return 0.0


static func _ease(u: float) -> float:
	return 1.0 - pow(1.0 - u, 3.0)


## The landing: a flash, a band of light across the stone, the camera leaning in, the number swelling; the die not
## kept shrinks and greys.
func _shine(since: float) -> void:
	var shine := SHINE_SECONDS * clampf(pace, 0.7, 1.0)
	var s := clampf(since / shine, 0.0, 1.0) if since >= 0.0 else -1.0
	var m := _mats[0]
	if s < 0.0:
		m.set_shader_parameter("flash", 0.0)
		m.set_shader_parameter("sweep", -9.0)
		m.set_shader_parameter("dim", 1.0 if dim else 0.0)
		_cam.fov = _fov
		return
	var flash := pow(maxf(0.0, 1.0 - s / 0.4), 2.0) * (0.9 if tone == "crit" else 0.35)
	m.set_shader_parameter("flash", flash)
	m.set_shader_parameter("sweep", lerpf(-1.9, 1.9, _ease(s)) if s < 1.0 else -9.0)
	m.set_shader_parameter("dim", 1.0 if dim else 0.0)
	_cam.fov = _fov - 1.6 * sin(PI * minf(s / 0.6, 1.0))
	var swell := 1.0 + 0.22 * sin(PI * minf(s / 0.55, 1.0))
	var top := (_labels[0] as Dictionary).get(number) as Label3D
	if top != null:
		top.scale = Vector3.ONE * swell
		var glow := "vampire_red" if tone == "fumble" else ("wick" if tone == "crit" else "gilt_light")
		top.modulate = Look.color(glow).lerp(Look.color("ivory"), 0.5 * sin(PI * minf(s / 0.55, 1.0)))
	if _plans.size() > 1:
		_mats[1].set_shader_parameter("dim", _ease(minf(s / 0.5, 1.0)))
		for l: Label3D in (_labels[1] as Dictionary).values():
			l.modulate = Look.color("gilt_light").lerp(Look.color("pewter"), _ease(minf(s / 0.5, 1.0)))


## Makes the die's shader and type ready before a roll first needs them (game start), so the first big roll doesn't
## hitch: a die drawn once off to the side, then freed.
static func warm(host: Node) -> void:
	if DisplayServer.get_name() == "headless" or not is_instance_valid(host) or not host.is_inside_tree():
		return
	var d := D20Die.new()
	d.size = Vector2(32, 32)
	d.position = Vector2(-4000, -4000)
	d.modulate.a = 0.0
	host.add_child(d)
	d.show_landed(20, 1)
	var ref: WeakRef = weakref(d)
	host.get_tree().create_timer(0.5, true).timeout.connect(func() -> void:
		var n := ref.get_ref() as Node
		if n != null:
			n.queue_free())
