extends Node3D
## Art QA for the Modern look's trees and plants (docs/art/plants.md): every plant in art/plants/manifest.json in a
## row on bare ground beside a 6 ft figure, lit by a low sun under an overcast sky, from the game's camera, and then
## a small stand of forest. Not part of the game.
##   make capture SCENE=res://tools/art/preview/plants_preview.tscn NAME=plants FRAMES=20
## Godot args after --: [--only=spruce_a,fern_a] [--set=forest] (whose wind, tint and snow) [--hour=day|dusk|night]

var _ids: Array[String] = []
var _cam: Camera3D
var _flora: Flora


func _ready() -> void:
	var only := []
	var set_id := "forest"
	var hour := "day"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = Array(a.get_slice("=", 1).split(","))
		elif a.begins_with("--set="):
			set_id = a.get_slice("=", 1)
		elif a.begins_with("--hour="):
			hour = a.get_slice("=", 1)
	Look.set_style("modern", false)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#4a4f5c") if hour != "night" else Color("#141826")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8890a8") if hour != "night" else Color("#2a3350")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.light_color = Color("#f4e2c4") if hour == "day" else (Color("#ff9a5c") if hour == "dusk" else Color("#8fa6ff"))
	sun.light_energy = 1.2 if hour == "day" else 0.9
	sun.rotation_degrees = Vector3(-35 if hour == "day" else -14, -120, 0)
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 40)
	ground.mesh = pm
	ground.material_override = Look.cel_textured("village/grass")
	add_child(ground)
	_flora = Flora.new()
	_flora.set_id = set_id
	_flora.spec = Flora.resolve(set_id)
	_flora._apply(Vector2(0.9, 0.35), 0.3)
	var x := 0.0
	for id: String in Flora.manifest():
		if (not only.is_empty() and not id in only) or id.ends_with("_far"):
			continue
		var size := (Flora.manifest()[id] as Dictionary).get("size", [1, 1, 1]) as Array
		var w := maxf(float(size[0]), 0.6)
		x += w * 0.5
		add_child(_flora.node(id, Vector3(x, 0, 0), 1.0, 0.6))
		var far := str((Flora.manifest()[id] as Dictionary).get("far", ""))
		if far != "":
			add_child(_flora.node(far, Vector3(x, 0, 4.0), 1.0, 0.6))
		_ids.append(id)
		x += w * 0.5 + 0.3
	var fig := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.16
	cm.height = 1.2
	fig.mesh = cm
	fig.position = Vector3(-0.6, 0.6, 0)
	fig.material_override = Look.cel("bone")
	add_child(fig)
	# A stand of forest behind the row: the trees as the land draws them, with ground plants between.
	var items := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 60:
		var p := Vector3(rng.randf_range(0, x), 0, rng.randf_range(-12, -4))
		var id := _flora.tree_for("pine" if rng.randf() > 0.25 else "dead_tree", i)
		if id == "":
			continue
		if not items.has(id):
			items[id] = []
		(items[id] as Array).append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p), Color.WHITE])
	for i in 500:
		var p := Vector3(rng.randf_range(0, x), 0, rng.randf_range(-12, -1.5))
		var id := _flora.pick_from(_flora.spec.get("land", []) as Array)
		if not items.has(id):
			items[id] = []
		(items[id] as Array).append(_flora.ground_item(p, 1.0))
	Flora.plant_all(self, items, true, "Stand")
	_cam = Camera3D.new()
	_cam.fov = 32.0
	add_child(_cam)
	_frame(Vector3(x * 0.5, 0, -2.0), maxf(x * 0.75, 12.0))


func _frame(target: Vector3, dist: float) -> void:
	var pitch := deg_to_rad(-40.0)
	_cam.position = target + Vector3(0, -sin(pitch) * dist, cos(pitch) * dist)
	_cam.rotation = Vector3(pitch, 0, 0)


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_row.png")
	# Half a second later: the wind has moved them.
	await tool.call("wait_frames", 30)
	tool.call("_shot", out + "_row_later.png")
	# Close-ups along the row, a few plants at a time.
	var x := 0.0
	var step := 6.0
	while x < float(_ids.size()) * 1.6:
		_frame(Vector3(x + step * 0.5, 0.8, 0.0), 7.5)
		await tool.call("wait_frames", 6)
		tool.call("_shot", "%s_near_%02d.png" % [out, int(x / step)])
		x += step
