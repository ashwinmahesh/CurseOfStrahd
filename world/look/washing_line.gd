class_name WashingLine
extends RefCounted
## A washing line strung between two posts with the week's wash pegged out on it, swaying (lane 28, owner request
## 2026-10-08: villages that look lived in). A mood's `lines` lists them: {"from": [x, z], "to": [x, z] (world units,
## the posts' feet), "height" (the line, default 1.6), "colours" (palette names for the wash)}. With "kind": "bunting"
## it is a festival string of little pennants instead, strung high from eave to eave with no posts (Vallaki's forced
## cheer). Built in code from boxes, quads and prisms in palette colours, so the screen pass outlines and snaps it like
## everything else. Cosmetic only.

const DEFAULT_COLOURS: Array[String] = ["bone", "parchment", "slate", "rust", "moss", "pewter", "leather"]
## Vallaki's festival yellow, "a yellow that nobody here would choose for themselves".
const BUNTING_COLOURS: Array[String] = ["wick", "flame", "wick", "candle"]


static func build(spec: Dictionary, rng: RandomNumberGenerator) -> Node3D:
	var a := spec.get("from", [0, 0]) as Array
	var b := spec.get("to", [1, 0]) as Array
	var p0 := Vector3(float(a[0]), 0, float(a[1]))
	var p1 := Vector3(float(b[0]), 0, float(b[1]))
	var bunting := str(spec.get("kind", "")) == "bunting"
	var h := float(spec.get("height", 2.5 if bunting else 1.6))
	var root := Node3D.new()
	root.name = "WashingLine"
	var wood := Look.cel("umber")
	if not bunting:
		for p: Vector3 in [p0, p1]:
			root.add_child(_box(Vector3(0.08, h + 0.1, 0.08), p + Vector3(0, (h + 0.1) / 2.0, 0), wood))
	var span := p1 - p0
	var length := span.length()
	var mid := (p0 + p1) / 2.0 + Vector3(0, h - 0.08, 0)   # the rope sags a little in the middle
	var rope := _box(Vector3(length, 0.018, 0.018), mid, Look.cel("bone_dark"))
	rope.rotation.y = -atan2(span.z, span.x)
	root.add_child(rope)
	var colours := spec.get("colours", BUNTING_COLOURS if bunting else DEFAULT_COLOURS) as Array
	if bunting:
		_pennants(root, p0, p1, h, colours)
		return root
	var n := maxi(2, int(length / 0.55))
	for i in n:
		var t := (float(i) + 0.5) / float(n)
		if rng.randf() < 0.18:
			continue   # a gap on the line
		var w := rng.randf_range(0.28, 0.48)
		var drop := rng.randf_range(0.3, 0.62)
		# Hung from a peg on the line: the piece swings about the line, not its own middle.
		var peg := Node3D.new()
		peg.name = "Wash"
		var sag := 0.08 * (1.0 - absf(t - 0.5) * 2.0)
		peg.position = p0.lerp(p1, t) + Vector3(0, h - sag - 0.02, 0)
		peg.rotation.y = -atan2(span.z, span.x)
		var mat := Look.cel(str(colours[rng.randi_range(0, colours.size() - 1)]))
		for back: bool in [false, true]:
			var cloth := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(w, drop)
			cloth.mesh = q
			cloth.material_override = mat
			cloth.position = Vector3(0, -drop / 2.0, 0)
			if back:
				cloth.rotation.y = PI   # its back, so it shows from both sides
			peg.add_child(cloth)
		root.add_child(peg)
		_sway(peg, rng)
	return root


## Little pennants, points down, every few inches along a string that sags between `p0` and `p1` at height `h`.
static func _pennants(root: Node3D, p0: Vector3, p1: Vector3, h: float, colours: Array) -> void:
	var span := p1 - p0
	var n := maxi(3, int(span.length() / 0.32))
	for i in n:
		var t := (float(i) + 0.5) / float(n)
		var sag := 0.25 * (1.0 - pow(absf(t - 0.5) * 2.0, 2.0))
		var flag := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.2, 0.26, 0.012)
		flag.mesh = pm
		flag.material_override = Look.cel(str(colours[i % colours.size()]))
		flag.position = p0.lerp(p1, t) + Vector3(0, h - sag - 0.13, 0)
		flag.rotation = Vector3(0, -atan2(span.z, span.x), PI)   # point down
		flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(flag)
	var string := _box(Vector3(span.length(), 0.012, 0.012), (p0 + p1) / 2.0 + Vector3(0, h - 0.18, 0), Look.cel("bone_dark"))
	string.rotation.y = -atan2(span.z, span.x)
	root.add_child(string)


static func _box(size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	return mi


## The wash stirs in the wind: each piece swings a little about the line, out of step with its neighbours.
static func _sway(peg: Node3D, rng: RandomNumberGenerator) -> void:
	var amount := rng.randf_range(0.08, 0.18)
	var period := rng.randf_range(1.6, 2.6)
	peg.ready.connect(func() -> void:
		var tw := peg.create_tween().set_loops()
		tw.tween_property(peg, "rotation:x", amount, period / 2.0).set_trans(Tween.TRANS_SINE)
		tw.tween_property(peg, "rotation:x", -amount * 0.6, period / 2.0).set_trans(Tween.TRANS_SINE))
