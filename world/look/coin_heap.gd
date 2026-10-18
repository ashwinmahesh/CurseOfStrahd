class_name CoinHeap
extends RefCounted
## A heap of loose coins, built from the coins (owner todo 2026-10-17: "show real big piles of silver on the ground" in
## the Argynvostholt undercroft). The `gold_heap` model scaled up read as a smooth blob with a few big discs on it, so a
## big heap is a lumpy dune of dark metal with a thousand small discs lying over it and strays round its foot. The
## catalog's `silver_heap` names it with a `heap` kind; a prop's `scale` sizes it against the gold heap's model (SIZE at
## scale 1). Cosmetic only, and the same every time the place is built.

## Width, height and depth of the heap at scale 1: the gold heap model's (art/models/manifest.json).
const SIZE := Vector3(1.086, 0.471, 0.781)
## Each kind's tones (palette colours): the coins that show most, a second, a duller third, then the dune under them.
const KINDS := {"silver": ["frost", "silver", "pewter", "stone"], "gold": ["wick", "flame", "candle", "umber"]}
const COIN_RADIUS := 0.034
const COIN_THICK := 0.012
## Coins lie over each square unit of the heap's footprint this thickly (they overlap, as a heap's do), up to a cap.
const COINS_PER_UNIT := 330.0
const MAX_COINS := 1800
## The dune's grid, across and down.
const GRID := Vector2i(26, 20)


## A heap of `kind` (silver or gold) `scale_` times the gold heap's size, its middle at the node's origin on the ground.
static func build(kind: String, scale_: float, seed: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var tones := KINDS.get(kind, KINDS["silver"]) as Array
	var shape := _Shape.new(rng, SIZE.x * scale_ / 2.0, SIZE.z * scale_ / 2.0, SIZE.y * scale_)
	var root := Node3D.new()
	root.name = "CoinHeap"
	var dune := MeshInstance3D.new()
	dune.name = "Dune"
	dune.mesh = _dune(shape)
	dune.material_override = _tone(str(tones[3]))
	root.add_child(dune)
	var coin := CylinderMesh.new()
	coin.top_radius = COIN_RADIUS
	coin.bottom_radius = COIN_RADIUS
	coin.height = COIN_THICK
	coin.radial_segments = 6
	coin.rings = 1
	coin.cap_bottom = false
	var total := clampi(int(PI * shape.a * shape.b * COINS_PER_UNIT), 150, MAX_COINS)
	var spots: Array[Transform3D] = []
	var tone_of: Array[int] = []
	for i in total:
		var skirt := i % 13 == 0
		var rho := rng.randf_range(0.95, 1.3) if skirt else sqrt(rng.randf()) * 1.02
		var theta := rng.randf() * TAU
		var x := rho * cos(theta) * shape.a
		var z := rho * sin(theta) * shape.b
		var y := shape.height(x, z)
		var up := shape.normal(x, z) if y > 0.01 else Vector3.UP
		up = (up + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.0, 0.25), rng.randf_range(-0.4, 0.4))).normalized()
		var side := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
		var ex := side.cross(up).normalized()
		var ez := ex.cross(up).normalized()
		var basis := Basis(ex, up, ez).rotated(up, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.35))
		spots.append(Transform3D(basis, Vector3(x, y + COIN_THICK * 0.6, z)))
		var roll := rng.randf()
		tone_of.append(0 if roll < 0.45 else (1 if roll < 0.8 else 2))
	for t in 3:
		var n := tone_of.count(t)
		if n == 0:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = coin
		mm.instance_count = n
		var at := 0
		for i in total:
			if tone_of[i] == t:
				mm.set_instance_transform(at, spots[i])
				at += 1
		var mi := MultiMeshInstance3D.new()
		mi.name = "Coins%d" % t
		mi.multimesh = mm
		mi.material_override = _tone(str(tones[t]))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	return root


## The dune as a mesh: the shape's height over a grid, sunk a little so the coins on it stand clear, left out where
## it is flat on the floor.
static func _dune(shape: _Shape) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	for j in GRID.y + 1:
		for i in GRID.x + 1:
			var x := (float(i) / GRID.x * 2.0 - 1.0) * shape.a * 1.1
			var z := (float(j) / GRID.y * 2.0 - 1.0) * shape.b * 1.1
			pts.append(Vector3(x, shape.height(x, z) - 0.02, z))
	for j in GRID.y:
		for i in GRID.x:
			var p00 := pts[j * (GRID.x + 1) + i]
			var p10 := pts[j * (GRID.x + 1) + i + 1]
			var p01 := pts[(j + 1) * (GRID.x + 1) + i]
			var p11 := pts[(j + 1) * (GRID.x + 1) + i + 1]
			if maxf(maxf(p00.y, p10.y), maxf(p01.y, p11.y)) < 0.0:
				continue
			for tri: Array in [[p00, p10, p11], [p00, p11, p01]]:
				for v: Vector3 in tri:
					st.add_vertex(v)
	st.generate_normals()
	return st.commit()


## A coin tone: the palette colour, duller metal than the Modern look gives silver so a heap shows in a dim vault.
static func _tone(colour: String) -> ShaderMaterial:
	var m := Look.cel(colour)
	if Look.modern():
		m.set_shader_parameter("metallic", 0.2)
		m.set_shader_parameter("roughness", 0.55)
	return m


## The heap's height over the floor: a main peak and a couple of lower ones, falling to nothing at the edge of its
## ellipse (half-widths a and b), the tallest point `peak` high.
class _Shape:
	var a := 1.0
	var b := 1.0
	var peak := 1.0
	var bumps: Array[Vector4] = []   ## x, z, height share, spread (of the ellipse)
	var _top := 1.0

	func _init(rng: RandomNumberGenerator, half_x: float, half_z: float, height: float) -> void:
		a = half_x
		b = half_z
		peak = height
		bumps.append(Vector4(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12), 1.0, 0.5))
		for k in 2:
			var ang := rng.randf() * TAU
			var far := rng.randf_range(0.35, 0.55)
			bumps.append(Vector4(cos(ang) * far, sin(ang) * far, rng.randf_range(0.5, 0.75), rng.randf_range(0.3, 0.4)))
		_top = 1.0
		_top = maxf(0.001, _raw_max())

	func _raw_max() -> float:
		var best := 0.0
		for i in 15:
			for j in 15:
				best = maxf(best, _raw(((i / 14.0) * 2.0 - 1.0) * a * 0.6, ((j / 14.0) * 2.0 - 1.0) * b * 0.6))
		return best

	func _raw(x: float, z: float) -> float:
		var u := x / a
		var v := z / b
		var rho := sqrt(u * u + v * v)
		if rho >= 1.0:
			return 0.0
		var h := 0.0
		for bump in bumps:
			var du := (u - bump.x) / bump.w
			var dv := (v - bump.y) / bump.w
			h += bump.z * exp(-(du * du + dv * dv) * 0.5)
		return h * (1.0 - rho * rho * rho)   # a steep foot and a rounded top

	func height(x: float, z: float) -> float:
		return _raw(x, z) / _top * peak

	func normal(x: float, z: float) -> Vector3:
		var e := 0.03
		var dx := (height(x + e, z) - height(x - e, z)) / (2.0 * e)
		var dz := (height(x, z + e) - height(x, z - e)) / (2.0 * e)
		return Vector3(-dx, 1.0, -dz).normalized()
