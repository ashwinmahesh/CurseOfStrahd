extends Node3D
## Phase 0 exit scene (plan §10): a gray-box hall where a placeholder party walks around under the
## final camera and look shaders. Built in code so agents can diff it; the .tscn is a thin root.
## One world unit = one 5 ft grid square (ADR 0004).

const ROOM := Vector2i(18, 14)
const WALL_H := 1.4

var party: PartyController
var rig: CameraRig
var hud: ExplorationHud
var post: MeshInstance3D
var villager: NpcWalker


func _ready() -> void:
	InputActions.ensure()
	GameState.current_scene = scene_file_path
	_build_environment()
	_build_room()
	_build_party()
	_build_villager()
	_build_camera()
	hud = ExplorationHud.new()
	add_child(hud)
	var names: Array[String] = []
	for m in party.members:
		names.append(m.display_name)
	hud.build(names)
	EventBus.leader_changed.connect(hud.set_leader)
	party.set_leader(0)
	rig.snap_to_target()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"quick_save"):
		_sync_state()
		var err := SaveSystem.save("quick")
		hud.toast("Saved." if err == OK else "Can't save now.")
	elif event.is_action_pressed(&"quick_load"):
		if SaveSystem.load_slot("quick") == OK:
			party.restore_positions(GameState.party_positions)
			party.set_leader(GameState.leader_index)
			rig.snap_to_target()
			hud.toast("Loaded.")
		else:
			hud.toast("No quick save yet.")
	elif event.is_action_pressed(&"toggle_palette"):
		var mat := (post.mesh as QuadMesh).material as ShaderMaterial
		var on := not bool(mat.get_shader_parameter("quantize"))
		mat.set_shader_parameter("quantize", on)
		hud.toast("Palette pass " + ("on" if on else "off"))


func _sync_state() -> void:
	GameState.party.clear()
	for m in party.members:
		GameState.party.append({"name": m.display_name})
	GameState.party_positions = party.positions()
	GameState.leader_index = party.leader_index


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Look.color("void")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Look.color("bruise")
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Look.color("grave")
	env.fog_density = 0.012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.light_color = Look.color("moonlight")
	moon.light_energy = 0.9
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-55, 30, 0)
	add_child(moon)


func _build_room() -> void:
	var floor_mat := Look.cel_checker("stone", "stone_deep", "ink")
	_box("Floor", Vector3(ROOM.x, 0.2, ROOM.y), Vector3(0, -0.1, 0), floor_mat)
	var wall := Look.cel("slate")
	var hx := ROOM.x / 2.0
	var hz := ROOM.y / 2.0
	_box("WallNorth", Vector3(ROOM.x, WALL_H, 0.4), Vector3(0, WALL_H / 2, -hz), wall)
	# South wall has a doorway in the middle.
	_box("WallSouthW", Vector3(hx - 1.5, WALL_H, 0.4), Vector3(-(hx + 1.5) / 2, WALL_H / 2, hz), wall)
	_box("WallSouthE", Vector3(hx - 1.5, WALL_H, 0.4), Vector3((hx + 1.5) / 2, WALL_H / 2, hz), wall)
	_box("WallWest", Vector3(0.4, WALL_H, ROOM.y), Vector3(-hx, WALL_H / 2, 0), wall)
	_box("WallEast", Vector3(0.4, WALL_H, ROOM.y), Vector3(hx, WALL_H / 2, 0), wall)

	var pillar := Look.cel("pewter")
	for p: Vector3 in [Vector3(-4, 0, -3), Vector3(4, 0, -3), Vector3(-4, 0, 3), Vector3(4, 0, 3)]:
		_box("Pillar", Vector3(0.8, 2.6, 0.8), p + Vector3(0, 1.3, 0), pillar)
		_candle(p + Vector3(0.0, 2.75, 0.0))
	_box("Table", Vector3(3.0, 0.8, 1.4), Vector3(0, 0.4, -4.5), Look.cel("leather"))
	_box("Rug", Vector3(4.0, 0.04, 6.0), Vector3(0, 0.02, 1.0), Look.cel("blood"))
	_candle(Vector3(0.9, 0.95, -4.5))
	_box("Coffin", Vector3(1.0, 0.6, 2.2), Vector3(-7, 0.3, -4.5), Look.cel("ash_violet"))
	_box("Crate", Vector3(1.0, 1.0, 1.0), Vector3(7, 0.5, 4.5), Look.cel("bone_dark"))
	_box("Crate2", Vector3(0.8, 0.8, 0.8), Vector3(6.2, 0.4, 5.2), Look.cel("bone"))


func _build_party() -> void:
	party = PartyController.new()
	party.name = "Party"
	add_child(party)
	var specs := [["Fighter", "crimson", "silver"], ["Rogue", "bog", "leather"], ["Cleric", "parchment", "flame"], ["Wizard", "bruise", "lilac"]]
	for i in specs.size():
		var s: Array = specs[i]
		var m := PartyMember.create(str(s[0]), str(s[1]), str(s[2]))
		party.add_member(m)
		m.global_position = Vector3(-1.2 + i * 0.8, 0.0, 5.0)


## Phase 0 pipeline proof: a GPT Image villager rigged and rendered in Blender, walking a loop.
func _build_villager() -> void:
	var frames := load("res://art/sprites/villager/walk.tres") as SpriteFrames
	if frames == null:
		return
	var route: Array[Vector3] = [Vector3(-2.6, 0, -1.6), Vector3(2.6, 0, -1.6), Vector3(2.6, 0, 3.6), Vector3(-2.6, 0, 3.6)]
	villager = NpcWalker.create(frames, route)
	add_child(villager)


func _build_camera() -> void:
	rig = CameraRig.new()
	add_child(rig)
	rig.follow = party.members[0]
	party.rig = rig
	rig.camera.current = true
	post = Look.make_post_process()
	rig.camera.add_child(post)


func _box(n: String, size: Vector3, pos: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = n
	body.position = pos
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)
	add_child(body)
	return body


func _candle(pos: Vector3) -> void:
	var wax := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.07
	cm.height = 0.3
	wax.mesh = cm
	wax.position = pos
	wax.material_override = Look.cel("ivory")
	add_child(wax)
	var flame := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.12
	flame.mesh = sm
	flame.position = pos + Vector3(0, 0.2, 0)
	var fm := Look.cel("wick")
	fm.set_shader_parameter("emission", Look.color("flame") * 2.0)
	flame.material_override = fm
	add_child(flame)
	var light := CandleFlicker.new()
	light.light_color = Look.color("candle")
	light.omni_range = 6.0
	light.position = pos + Vector3(0, 0.35, 0)
	light.base_energy = 1.8
	add_child(light)


## Test / capture hook: walk the leader to a point.
func debug_move_leader(point: Vector3) -> void:
	party.command_move(point)
