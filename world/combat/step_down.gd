class_name StepDown
extends RefCounted
## A colossus stepping down (Amber Temple Look Plan §4a and step 9, docs/art/interiors.md): when the Amber Sentinel's fight
## begins, the figure that stood on its dais is the foe, not a second one. LocationFights hands its place over (the
## person's token is hidden, the foe's token starts on the dais) and the foe's token carries META: where its fight begins.
## CombatView.begin plays the beat before the opening: the camera comes in on it while its eyes flare and a crack runs
## round the dais (the place's own `wake`, LocationView.stepping_down), then it strides to its start square in two or
## three footfalls (a tween of the token alone: the grid and the Encounter had it at its start square all along), each one
## landing with a jolt of the camera, a burst of snow and a ring of it along the ground. About a second and a half, never
## past MOST; where motion is off (UiMotion: headless runs and stills) it is skipped to a cut. Only looks.

const RING_SHADER := preload("res://shaders/world/stomp_ring.gdshader")
const META := &"step_down"
## The wake, a footfall and the camera's way back (seconds at the normal pace), and the longest the beat may take.
const WAKE := 0.4
const FOOTFALL := 0.32
const BACK := 0.3
const MOST := 1.8
## One footfall for each REACH of ground it strides (world units), at least one and at most MOST_FOOTFALLS.
const REACH := 2.0
const MOST_FOOTFALLS := 3
## How far a stride lifts the figure (units), how hard a landing jolts the camera, the width of the ring of snow it throws
## and how long that takes to spread and fade.
const HOP := 0.3
const JOLT := 0.5
const RING := 7.0
const RING_TIME := 0.8
## The camera while it wakes and strides: how close (shot_zoom), how much flatter (degrees), how far the view leans to it
## (shot_weight) and how high above its feet the view aims (units).
const SHOT := {"zoom": 0.72, "pitch": 6.0, "weight": 0.6, "aim": 2.6}

## The beat plays in headless runs too only when a test asks (`headless_too`); `enabled` switches it off for captures that
## compare, as the other effects have.
static var enabled := true
static var headless_too := false


## Whether the beat plays now.
static func on() -> bool:
	return enabled and (headless_too or UiMotion.on())


## `tok`, a foe that is a person's figure standing at its fight's start square, takes the place of that person, who stood
## at `home`: with motion on it starts there and carries its way to its start (META) and the `wake` to play as the beat
## begins; with motion off it is at its start at once, on the person's dais where that is its start.
static func take_place(tok: CombatToken, home: Vector3, wake: Callable) -> void:
	var to := tok.position
	var in_place := Vector2(to.x - home.x, to.z - home.z).length() < 0.3
	if in_place:
		to = home   # its start is the dais itself: it stands on top of it
		tok.position = home
	if not on():
		return
	tok.position = home
	tok.set_meta(META, {"to": to, "wake": wake})


## The tokens of `tokens` (combatant id -> CombatToken) with a beat still to play.
static func pending(tokens: Dictionary) -> Array[CombatToken]:
	var out: Array[CombatToken] = []
	for id: Variant in tokens:
		var t := tokens[id] as CombatToken
		if t != null and is_instance_valid(t) and t.has_meta(META):
			out.append(t)
	return out


## Plays the beat for `tok` in `cv`: awaited by CombatView.begin before the opening. It ends with the token exactly on its
## start square, the camera back where it was and nothing left running; the token keeps META until then.
static func play(cv: CombatView, tok: CombatToken) -> void:
	var data := tok.get_meta(META) as Dictionary
	var rig := cv.rig
	var to := data["to"] as Vector3
	var from := tok.position
	var pace := GameSettings.combat_pace()
	var span := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var feet := clampi(roundi(span.length() / REACH), 1, MOST_FOOTFALLS)
	var facing := Vector2(tok.sprite.facing.x, tok.sprite.facing.z) if tok.sprite != null else Vector2.ZERO
	var wake := data["wake"] as Callable
	if wake.is_valid():
		wake.call()
	# The wake: the camera comes in and leans toward the figure.
	var aim := Vector3(0.0, float(SHOT["aim"]), 0.0)
	if rig.shot_weight < 0.01:
		rig.shot_focus = from + aim
	var shot := cv.create_tween().set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	shot.tween_property(rig, "shot_zoom", float(SHOT["zoom"]), WAKE * pace)
	shot.tween_property(rig, "shot_pitch", float(SHOT["pitch"]), WAKE * pace)
	shot.tween_property(rig, "shot_weight", float(SHOT["weight"]), WAKE * pace)
	shot.tween_property(rig, "shot_focus", from + aim, WAKE * pace)
	await shot.finished
	# The stride: a footfall each time it lands, the camera following it over the ground.
	var here := from
	for i in feet:
		if cv._closed or not is_instance_valid(tok):
			_rest(rig)
			return
		var there := from.lerp(to, float(i + 1) / float(feet))
		if span.length() > 0.3 and tok.sprite != null:
			tok.face(Vector2(there.x - here.x, there.z - here.z), true, FOOTFALL * pace)
		var step := cv.create_tween().set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		var start := here
		var stride := func(u: float) -> void:
			if is_instance_valid(tok):
				tok.position = start.lerp(there, u) + Vector3(0.0, sin(PI * u) * HOP, 0.0)
		step.tween_method(stride, 0.0, 1.0, FOOTFALL * pace)
		step.tween_property(rig, "shot_focus", there + aim, FOOTFALL * pace)
		await step.finished
		if cv._closed or not is_instance_valid(tok):
			_rest(rig)
			return
		here = there
		tok.position = there
		_footfall(cv, there)
	tok.position = to
	if tok.sprite != null:
		tok.face(facing, false)
	# The way back: the camera eases off to the play view as the opening begins.
	var back := cv.create_tween().set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	back.tween_property(rig, "shot_zoom", 1.0, BACK * pace)
	back.tween_property(rig, "shot_pitch", 0.0, BACK * pace)
	back.tween_property(rig, "shot_weight", 0.0, BACK * pace)
	await back.finished
	_rest(rig)
	if is_instance_valid(tok):
		tok.remove_meta(META)   # (the beat is over: it is on its square and nothing is left to play)


## The camera back at the play view at once.
static func _rest(rig: CameraRig) -> void:
	if is_instance_valid(rig):
		rig.shot_zoom = 1.0
		rig.shot_pitch = 0.0
		rig.shot_weight = 0.0


## A footfall landing at `at`: the camera jolts, snow bursts up (the place's StepPuffs, a bigger kind than a person's) and a
## ring of it spreads along the ground.
static func _footfall(cv: CombatView, at: Vector3) -> void:
	cv.rig.shake = maxf(cv.rig.shake, JOLT)
	var puffs := cv.get_tree().root.find_child("StepPuffs", true, false) as StepPuffs
	if puffs != null:
		puffs.puff("stomp", at)
	var ring := MeshInstance3D.new()
	ring.name = "StompRing"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * RING
	ring.mesh = plane
	var m := ShaderMaterial.new()
	m.shader = RING_SHADER
	m.render_priority = 1
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cv.board.add_child(ring)
	ring.position = at + Vector3(0.0, 0.06, 0.0)
	var tw := ring.create_tween()
	tw.tween_method(func(p: float) -> void: m.set_shader_parameter("progress", p), 0.0, 1.0, RING_TIME * GameSettings.combat_pace())
	tw.tween_callback(ring.queue_free)
