class_name Waterfall
extends RefCounted
## A river going over an edge (lane 28, 2026-10-08: Tser Falls had no falls). A mood's `falls` lists them:
## {"at": [x, z] (the middle of the lip, world units), "width", "drop" (how far it falls), "facing" (which way it pours:
## north, south, east or west; south by default), "lean" (how far out it arcs before it drops)}. Each is one curved sheet
## of falling water (shaders/world/waterfall.gdshader) in the place's water colours, built in code. Cosmetic only: the
## rules never see it.

const SHADER := preload("res://shaders/world/waterfall.gdshader")
const DIRS := {"north": Vector2(0, -1), "south": Vector2(0, 1), "east": Vector2(1, 0), "west": Vector2(-1, 0)}
## Rows down the fall and columns across it.
const ROWS := 14
const COLS := 6


static func build(spec: Dictionary, water: Dictionary) -> MeshInstance3D:
	var at := spec.get("at", [0, 0]) as Array
	var lip := Vector3(float(at[0]), float(spec.get("height", 0.0)), float(at[1]))
	var width := float(spec.get("width", 2.0))
	var drop := float(spec.get("drop", 6.0))
	var lean := float(spec.get("lean", 0.7))
	var fwd2 := DIRS.get(str(spec.get("facing", "south")), Vector2(0, 1)) as Vector2
	var fwd := Vector3(fwd2.x, 0, fwd2.y)
	var across := Vector3(-fwd.z, 0, fwd.x)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in ROWS + 1:
		var t := float(j) / ROWS
		# Off the lip it arcs out, then falls nearly straight down; it widens a little as it falls.
		var out := lean * sqrt(t)
		var down := -drop * t
		var spread := width * (1.0 + 0.25 * t)
		for i in COLS + 1:
			var u := float(i) / COLS
			st.set_uv(Vector2(u, t))
			st.set_normal(-fwd)
			st.add_vertex(lip + fwd * out + Vector3.UP * down + across * (u - 0.5) * spread)
	for j in ROWS:
		for i in COLS:
			var a := j * (COLS + 1) + i
			var b := a + 1
			var c := a + COLS + 1
			var d := c + 1
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	var mi := MeshInstance3D.new()
	mi.name = "Waterfall"
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("deep", Look.color(str(water.get("deep", "night"))))
	mat.set_shader_parameter("foam", Look.color(str(water.get("foam", "frost"))))
	mat.set_shader_parameter("speed", float(spec.get("speed", 1.6)))
	mat.set_shader_parameter("streaks", width * 3.0)
	mi.material_override = mat
	return mi
