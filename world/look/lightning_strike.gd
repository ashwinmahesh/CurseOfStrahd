class_name LightningStrike
extends RefCounted
## One lightning strike outdoors (lane 28, owner 2026-10-09: "in rain, we can also have lightning effects happen
## sometimes (with a lighting change) and associated thunder"). Atmosphere lights the scene for it (its flash); this
## draws the bolt coming down beyond the map's edge, in front of the camera, and plays the thunder after it: soon and
## loud with a crack when the strike is close, late, low and soft when it's far. Cosmetic only.

## How often a strike is a close one.
const NEAR_CHANCE := 0.3
## Seconds from the flash to the thunder: close, and far.
const NEAR_DELAY := Vector2(0.15, 0.6)
const FAR_DELAY := Vector2(1.6, 3.8)
## How far beyond the map's edge the bolt comes down (squares): close, and far.
const NEAR_REACH := Vector2(4.0, 9.0)
const FAR_REACH := Vector2(16.0, 34.0)
const SKY := 34.0


## Draws the bolt over `board`, beyond its edge in the direction the camera looks; it comes down in a few hundredths
## of a second and fades in a quarter of one. Returns its root (freed by itself).
static func bolt(parent: Node, board: ArenaBoard, near: bool, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "LightningBolt"
	parent.add_child(root)
	var w := float(board.grid.width)
	var d := float(board.grid.depth)
	var centre := Vector3(w / 2.0, 0.0, d / 2.0)
	var ahead := Vector3(0, 0, -1)
	var cam := parent.get_viewport().get_camera_3d() if parent.is_inside_tree() else null
	if cam != null:
		var f := -cam.global_basis.z
		f.y = 0.0
		if f.length_squared() > 1e-6:
			ahead = f.normalized()
	var side := Vector3(-ahead.z, 0.0, ahead.x)
	var reach := NEAR_REACH if near else FAR_REACH
	var edge := absf(ahead.x) * w / 2.0 + absf(ahead.z) * d / 2.0
	var ground := centre + ahead * (edge + rng.randf_range(reach.x, reach.y)) + side * rng.randf_range(-0.4, 0.4) * maxf(w, d)
	var sky := ground + Vector3(rng.randf_range(-3.0, 3.0), SKY, rng.randf_range(-3.0, 3.0))
	var cols := SpellFx.colours("lightning")
	var width := 0.9 if near else 0.55
	var strands: Array[MeshInstance3D] = [FxKit.beam(root, sky, ground, width, cols, 1.6, 4.0),
		FxKit.beam(root, sky, ground, width * 0.45, cols, 2.4, 3.2)]
	for b in strands:
		FxKit.tween_param(b, "reach", 0.3, 1.0, 0.02)   # down in an instant, as lightning comes
	var out := root.create_tween()
	out.tween_interval(0.12)
	for b in strands:
		out.parallel().tween_method(func(v: float) -> void: (b.material_override as ShaderMaterial).set_shader_parameter("fade", v), 1.0, 0.0, 0.25)
	out.tween_callback(root.queue_free)
	return root


## The thunder after a strike: a crack and a roll soon after a close one, a low roll late after a far one. Returns the
## delay (seconds) it waits.
static func thunder(host: Node, near: bool, rng: RandomNumberGenerator) -> float:
	var delay := rng.randf_range(NEAR_DELAY.x, NEAR_DELAY.y) if near else rng.randf_range(FAR_DELAY.x, FAR_DELAY.y)
	if not host.is_inside_tree() or not Audio.audible():
		return delay
	var pitch := rng.randf_range(0.95, 1.08) if near else rng.randf_range(0.62, 0.8)
	var loud := rng.randf_range(-1.0, 1.0) if near else rng.randf_range(-12.0, -6.0)
	host.get_tree().create_timer(delay).timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		_play(host, "thunder_near" if near else "thunder_far", pitch, loud)
		if near:
			_play(host, "thunder_crack", rng.randf_range(0.9, 1.05), rng.randf_range(-6.0, -3.0)))
	return delay


## One take of `id` (art/audio.json sfx), at `pitch`, `loud` dB over its level, on the effects bus; freed when done.
static func _play(host: Node, id: String, pitch: float, loud: float) -> void:
	var takes := Audio.files("sfx", id)
	if takes.is_empty():
		return
	var stream := load(takes[randi() % takes.size()]) as AudioStream
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.bus = &"SFX"
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = Audio.level_db(id) + loud
	host.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
