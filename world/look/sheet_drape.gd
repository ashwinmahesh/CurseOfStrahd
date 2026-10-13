class_name SheetDrape
extends RefCounted
## A linen sheet over a figure lying down (CombatToken.lie_down; owner 2026-10-13, Vasilka "on a long table under a
## clean linen sheet ... turned down to her collarbone"): a cloth from just past the feet to its hem, over the shape of
## the body under it (toes, shins, knees, hips, chest, and the head when it's drawn up over the face), wider than the
## body and hanging over the sides and the foot in soft folds. Built along +x (soles to the top of the head), across
## z, up y from the surface the figure lies on.

## The body under the sheet, from the soles (0) to the top of the head (1): [where, height, half width], both as
## shares of the figure's length. Toes stand up; the head is round.
const BODY := [[0.0, 0.06, 0.07], [0.05, 0.14, 0.09], [0.12, 0.08, 0.1], [0.27, 0.1, 0.11], [0.42, 0.11, 0.13],
	[0.52, 0.13, 0.15], [0.62, 0.12, 0.14], [0.72, 0.15, 0.15], [0.79, 0.13, 0.16], [0.84, 0.07, 0.06],
	[0.9, 0.14, 0.075], [0.96, 0.12, 0.07], [1.0, 0.04, 0.05]]
## Where the sheet is turned down to the chest: just under the collarbone.
const CHEST := 0.78
## The cloth's colour: linen a shade down from white, so its shape shows under a lamp (vellum glared).
const COLOUR := "parchment"
## Steps along the body and across it.
const ALONG := 56
const ACROSS := 24
## How far the cloth runs on past the soles (and past the head, over the face) before it falls.
const PAST := 0.05
## A hem turned down at the chest: this much of the length, standing this much proud.
const HEM := 0.06
const HEM_LIFT := 0.012


## The sheet over a figure `length` long whose soles are at x = `feet`: to the chest, or over the face. `half_width`
## is how far it spreads either side before it falls (the edge of the table under it), `drop` how far it then hangs.
static func build(length: float, feet: float, face: bool, half_width: float, drop: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var u0 := -PAST / length
	var u1 := 1.0 + PAST / length if face else CHEST
	# The cross-section at each step along: a fall at either side, the top across, from -z to +z.
	var rows: Array[PackedVector3Array] = []
	for i in ALONG + 1:
		var u := lerpf(u0, u1, float(i) / ALONG)
		var x := feet + u * length
		var row := PackedVector3Array()
		var hang := _hang(x, drop)
		row.append(Vector3(x, -hang, -half_width - _fold(x, 0.0)))
		for j in ACROSS + 1:
			var z := lerpf(-half_width, half_width, float(j) / ACROSS)
			row.append(Vector3(x, _height(u, z, length, face, u1), z))
		row.append(Vector3(x, -hang, half_width + _fold(x, 1.7)))
		rows.append(row)
	# The cloth falling off the foot end, and off the head end when it covers the face.
	var foot := PackedVector3Array()
	for v in rows[0]:
		foot.append(Vector3(v.x - _fold(v.z, 0.6), -drop, v.z))
	rows.push_front(foot)
	if face:
		var top := PackedVector3Array()
		for v in rows[rows.size() - 1]:
			top.append(Vector3(v.x + _fold(v.z, 2.3) * 0.5, -drop * 0.6, v.z))
		rows.append(top)
	for i in rows.size() - 1:
		var a := rows[i]
		var b := rows[i + 1]
		for j in a.size() - 1:
			# Wound so the outside (up, out) faces the camera.
			st.add_vertex(a[j])
			st.add_vertex(b[j])
			st.add_vertex(a[j + 1])
			st.add_vertex(a[j + 1])
			st.add_vertex(b[j])
			st.add_vertex(b[j + 1])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Sheet"
	mi.mesh = st.commit()
	mi.material_override = Look.cel(COLOUR)
	return mi


## How high the hem turned down at the chest stands over the surface, for a figure `length` long (the head rests on it).
static func hem_height(length: float) -> float:
	return _body(CHEST).x * length + HEM_LIFT


## The cloth's height over the surface at `u` along the body and `z` across it: the body's shape under it, eased off
## to lie flat beside the body, with the hem turned down at the chest.
static func _height(u: float, z: float, length: float, face: bool, u1: float) -> float:
	var body := _body(clampf(u, 0.0, 1.0))
	var h := body.x * length
	var w := body.y * length
	var y := maxf(h * exp(-pow(z / maxf(w, 0.01), 2.0)), 0.006)
	if u < 0.0:
		y *= clampf(1.0 + u * length / PAST, 0.0, 1.0) * 0.8 + 0.2   # past the soles it slopes down to fall
	if not face and u > u1 - HEM / length:
		y += HEM_LIFT
	return y


## [height, half width] of the body at `u`, eased between the BODY marks.
static func _body(u: float) -> Vector2:
	for i in BODY.size() - 1:
		var a := BODY[i] as Array
		var b := BODY[i + 1] as Array
		if u <= float(b[0]):
			var t := smoothstep(float(a[0]), float(b[0]), u)
			return Vector2(lerpf(float(a[1]), float(b[1]), t), lerpf(float(a[2]), float(b[2]), t))
	var last := BODY[BODY.size() - 1] as Array
	return Vector2(float(last[1]), float(last[2]))


## How far the cloth hangs below the surface at `x`: a little more and less along it, so the hem isn't ruled straight.
static func _hang(x: float, drop: float) -> float:
	return drop * (0.85 + 0.15 * sin(x * 17.0))


## A soft fold pushing the hanging cloth out from the surface's edge, along `x` (each side its own `phase`).
static func _fold(x: float, phase: float) -> float:
	return 0.012 + 0.012 * sin(x * 23.0 + phase)
