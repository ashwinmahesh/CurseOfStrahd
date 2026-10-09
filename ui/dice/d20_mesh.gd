class_name D20Mesh
extends RefCounted
## The big d20's shape (docs/ui/d20_roll.md): a regular icosahedron with its edges and corners ground off, like a cut
## gem, built once and shared by every die. Each of the 20 faces has its number (opposite faces add up to 21, as on a
## real d20), its centre, its outward normal and the way its numeral reads up, so a die can be turned to land with any
## number toward the camera. All in the die's own space, circumradius 1.
##
## The mesh's vertex colour carries what the gem shader needs: r a steady per-facet shade (cut stones throw each facet
## a little differently), g 1 on the ground-off edges and corners and 0 on the faces; UV.x runs from 0 at a face's
## middle to 1 at its rim, so the stone can look clearer in the middle of each face. CUSTOM0 holds the facet behind
## each third of a face (a gem's back facets, seen through the front one), which the shader bends the view off.

## How far each face's corners are pulled in toward its middle; the rest of the edge is the bevel.
const BEVEL := 0.11
## How far each third of a face's back facet leans out toward its edge.
const BACK_TILT := 0.55

static var _mesh: ArrayMesh = null
static var _faces: Array[Dictionary] = []


## The 20 faces: {number, center, normal, up}, in face order.
static func faces() -> Array[Dictionary]:
	if _faces.is_empty():
		_build()
	return _faces


static func mesh() -> ArrayMesh:
	if _mesh == null:
		_build()
	return _mesh


## The face showing `number`.
static func face_of(number: int) -> Dictionary:
	for f in faces():
		if int(f["number"]) == number:
			return f
	return faces()[19]


## The die's rotation that puts `number` square to the camera (+Z) with its numeral reading upright (+Y).
static func rest_basis(number: int) -> Basis:
	var f := face_of(clampi(number, 1, 20))
	var n := f["normal"] as Vector3
	var up := f["up"] as Vector3
	return Basis(up.cross(n), up, n).transposed()


## Distance from the middle to a face (the inradius): how high the die's centre sits when it lies on a face.
static func inradius() -> float:
	return ((faces()[0] as Dictionary)["center"] as Vector3).length()


static func _corners() -> Array[Vector3]:
	var p := (1.0 + sqrt(5.0)) / 2.0
	var out: Array[Vector3] = []
	for s1: float in [-1.0, 1.0]:
		for s2: float in [-1.0, 1.0]:
			out.append(Vector3(0, s1, s2 * p).normalized())
			out.append(Vector3(s1, s2 * p, 0).normalized())
			out.append(Vector3(s2 * p, 0, s1).normalized())
	return out


static func _build() -> void:
	var v := _corners()
	var edge := INF
	for i in range(1, v.size()):
		edge = minf(edge, v[0].distance_to(v[i]))
	# The faces: every three corners an edge apart from each other, wound clockwise seen from outside (Godot's front).
	var tris: Array[PackedInt32Array] = []
	for i in v.size():
		for j in range(i + 1, v.size()):
			if absf(v[i].distance_to(v[j]) - edge) > 0.01:
				continue
			for k in range(j + 1, v.size()):
				if absf(v[i].distance_to(v[k]) - edge) > 0.01 or absf(v[j].distance_to(v[k]) - edge) > 0.01:
					continue
				var c := (v[i] + v[j] + v[k]) / 3.0
				if (v[j] - v[i]).cross(v[k] - v[i]).dot(c) > 0.0:
					tris.append(PackedInt32Array([i, k, j]))
				else:
					tris.append(PackedInt32Array([i, j, k]))
	assert(tris.size() == 20, "an icosahedron has 20 faces")
	_number(v, tris)
	# Each face's corners, pulled in: [face][corner] -> point.
	var inset: Array = []
	for f in 20:
		var t := tris[f]
		var c := (v[t[0]] + v[t[1]] + v[t[2]]) / 3.0
		inset.append([v[t[0]].lerp(c, BEVEL), v[t[1]].lerp(c, BEVEL), v[t[2]].lerp(c, BEVEL)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var shade := RandomNumberGenerator.new()
	shade.seed = 20   # the same facets every run
	var face_shade: Array[float] = []
	for f in 20:
		face_shade.append(shade.randf())
	# Each face as a fan round its middle, so UV.x can run from the middle out to the rim.
	for f in 20:
		var n := _faces[f]["normal"] as Vector3
		var p := inset[f] as Array
		var mid := ((p[0] as Vector3) + (p[1] as Vector3) + (p[2] as Vector3)) / 3.0
		for k in 3:
			var toward := ((p[k] as Vector3) + (p[(k + 1) % 3] as Vector3)) / 2.0 - mid
			var back := (n + toward.normalized() * BACK_TILT).normalized()
			_tri(st, [mid, p[k], p[(k + 1) % 3]], [n, n, n], face_shade[f], 0.0, [0.0, 1.0, 1.0], back)
	# The bevels: one strip along each edge, between the two faces that share it, its normal turning from one face's to
	# the other's so it catches the light like a rounded edge.
	for f in 20:
		for g in range(f + 1, 20):
			var shared: Array[int] = []
			for a in 3:
				if tris[g].has(tris[f][a]):
					shared.append(a)
			if shared.size() != 2:
				continue
			var nf := _faces[f]["normal"] as Vector3
			var ng := _faces[g]["normal"] as Vector3
			var u := tris[f][shared[0]]
			var w := tris[f][shared[1]]
			var fu := (inset[f] as Array)[shared[0]] as Vector3
			var fw := (inset[f] as Array)[shared[1]] as Vector3
			var gu := (inset[g] as Array)[Array(tris[g]).find(u)] as Vector3
			var gw := (inset[g] as Array)[Array(tris[g]).find(w)] as Vector3
			var s := (face_shade[f] + face_shade[g]) / 2.0
			_quad(st, [fu, fw, gw, gu], [nf, nf, ng, ng], s)
	# The corners: a small five-sided cap where five faces meet.
	for corner in v.size():
		var around: Array[Vector3] = []
		var normals: Array[Vector3] = []
		for f in 20:
			var at := Array(tris[f]).find(corner)
			if at >= 0:
				around.append((inset[f] as Array)[at] as Vector3)
				normals.append(_faces[f]["normal"] as Vector3)
		var mid := Vector3.ZERO
		for p in around:
			mid += p
		mid /= float(around.size())
		var axis := v[corner]
		var ref := (around[0] - mid).normalized()
		var order := range(around.size())
		order.sort_custom(func(a: int, b: int) -> bool:
			return _angle(around[a] - mid, ref, axis) < _angle(around[b] - mid, ref, axis))
		for i in order.size():
			var a := order[i] as int
			var b := order[(i + 1) % order.size()] as int
			_tri(st, [mid, around[a], around[b]], [axis, normals[a], normals[b]], 0.5, 1.0, [1.0, 1.0, 1.0])
	_mesh = st.commit()


## The numbers: one face of each opposite pair gets 1 to 10, the other 21 minus it. Each numeral reads up toward one of
## its face's corners, the one nearest the die's top.
static func _number(v: Array[Vector3], tris: Array[PackedInt32Array]) -> void:
	_faces.clear()
	var normals: Array[Vector3] = []
	for t in tris:
		normals.append(((v[t[0]] + v[t[1]] + v[t[2]]) / 3.0).normalized())
	var numbers: Array[int] = []
	numbers.resize(20)
	numbers.fill(0)
	# A fixed order round the die (by height, then by angle) so the low numbers are spread about, not bunched.
	var order := range(20)
	order.sort_custom(func(a: int, b: int) -> bool:
		var na := normals[a]
		var nb := normals[b]
		if absf(na.y - nb.y) > 0.01:
			return na.y > nb.y
		return atan2(na.z, na.x) < atan2(nb.z, nb.x))
	var next := 1
	var swap := false
	for f: int in order:
		if numbers[f] != 0:
			continue
		var opposite := 0
		for g in 20:
			if normals[g].dot(normals[f]) < -0.99:
				opposite = g
		numbers[f] = next if not swap else 21 - next
		numbers[opposite] = 21 - numbers[f]
		next += 1
		swap = not swap
	for f in 20:
		var t := tris[f]
		var c := (v[t[0]] + v[t[1]] + v[t[2]]) / 3.0
		var best := v[t[0]]
		for k in 3:
			if v[t[k]].y > best.y + 0.001 or (absf(v[t[k]].y - best.y) <= 0.001 and v[t[k]].x < best.x):
				best = v[t[k]]
		var up := (best - c).normalized()
		_faces.append({"number": numbers[f], "center": c, "normal": normals[f], "up": up})


static func _angle(d: Vector3, ref: Vector3, axis: Vector3) -> float:
	return atan2(ref.cross(d).dot(axis), ref.dot(d))


## A triangle wound clockwise seen from outside, with its own normals and how far out from its face's middle each
## corner is (UV.x).
static func _tri(st: SurfaceTool, p: Array, n: Array, shade: float, bevel: float, rim: Array = [1.0, 1.0, 1.0],
		back: Vector3 = Vector3.ZERO) -> void:
	var out := (p[0] as Vector3) + (p[1] as Vector3) + (p[2] as Vector3)
	var order := [0, 1, 2]
	if ((p[1] as Vector3) - (p[0] as Vector3)).cross((p[2] as Vector3) - (p[0] as Vector3)).dot(out) > 0.0:
		order = [0, 2, 1]
	for i: int in order:
		st.set_color(Color(shade, bevel, 0.0))
		st.set_uv(Vector2(float(rim[i]), 0.0))
		var b := back if back != Vector3.ZERO else n[i] as Vector3
		st.set_custom(0, Color(b.x, b.y, b.z, 0.0))
		st.set_normal(n[i] as Vector3)
		st.add_vertex(p[i] as Vector3)


static func _quad(st: SurfaceTool, p: Array, n: Array, shade: float) -> void:
	_tri(st, [p[0], p[1], p[2]], [n[0], n[1], n[2]], shade, 1.0)
	_tri(st, [p[0], p[2], p[3]], [n[0], n[2], n[3]], shade, 1.0)
