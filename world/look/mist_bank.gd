class_name MistBank
extends RefCounted
## A bank of the Mists standing on the map (lane 28, 2026-10-08: the Mists wall read as a hard-edged cartoon cloud,
## "a flat pale slab"): a loose crowd of soft, camera-facing puffs (shaders/world/mist_puff.gdshader) in the mist's own
## colour, each stirring on its own, piled higher in the middle. Stands in for the `fog_bank` art. Cosmetic only.

const SHADER := preload("res://shaders/world/mist_puff.gdshader")


## A bank about `width` across and `height` high, centred on its node's origin at ground level.
static func build(width: float, height: float, seed: int, tint: Color) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var root := Node3D.new()
	root.name = "MistBank"
	var n := maxi(8, int(width * 3.0))
	for i in n:
		var t := (float(i) + rng.randf_range(-0.3, 0.3)) / float(n - 1) - 0.5
		var hump := 1.0 - absf(t) * 1.4   # higher in the middle
		var size := rng.randf_range(0.65, 1.0) * height * (0.75 + 0.5 * hump)
		var puff := MeshInstance3D.new()
		puff.name = "Puff%d" % i
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		puff.mesh = q
		puff.scale = Vector3(size, size * rng.randf_range(0.75, 0.95), 1.0)
		puff.position = Vector3(t * width, size * 0.42 + rng.randf_range(0.0, 0.25) * height * hump, rng.randf_range(-0.8, 0.8))
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("tint", tint.lerp(Color.WHITE, rng.randf_range(0.0, 0.12)))
		mat.set_shader_parameter("seed", rng.randf_range(0.0, 10.0))
		mat.set_shader_parameter("opacity", rng.randf_range(0.8, 0.95))
		puff.material_override = mat
		root.add_child(puff)
	return root
