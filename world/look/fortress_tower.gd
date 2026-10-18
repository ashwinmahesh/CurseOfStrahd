class_name FortressTower
extends RefCounted
## Daern's Instant Fortress drawn on a map (docs/story/fortress.md): the square adamantine tower of the 2024 Dungeon
## Master's Guide, 20 ft on a side and 30 ft high, with arrow slits in every wall, a battlement on top and one door at
## the foot of the face that looks at the party, shut by the magic that opens it only at its owner's word. Built in
## code from the palette (dark adamantine plates with pale blue light in the seams), one node that stands over the 4 x 4
## squares of its plot and rises out of the ground when it is called (rise()), or sinks back (sink()).

const SIDE := 4.0          ## 20 ft
const PLINTH := 0.4
const BODY_TOP := 5.2
const CORBEL_TOP := 5.4
const PARAPET_TOP := 5.7
const TOP := 6.0           ## 30 ft: the merlons' tops
const HALF := 1.92         ## half the body's width


## The tower with its door looking along `looks` (south, east, west or north), standing on the ground at the plot's
## middle `at`.
static func build(at: Vector3, looks: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Fortress"
	root.position = at
	root.rotation.y = {"south": 0.0, "east": PI / 2.0, "west": -PI / 2.0, "north": PI}.get(looks, 0.0)
	var steel := Look.cel("stone")
	var plate := Look.cel("slate")
	var dark := Look.cel("stone_deep")
	var metal := Look.cel("pewter")
	var slit := Look.cel("void")
	# Footing and body.
	_box(root, "Plinth", Vector3(SIDE + 0.16, PLINTH, SIDE + 0.16), Vector3(0, PLINTH / 2.0, 0), plate)
	_box(root, "Body", Vector3(HALF * 2.0, BODY_TOP - PLINTH, HALF * 2.0), Vector3(0, (BODY_TOP + PLINTH) / 2.0, 0), steel)
	# Corner piers and the two bands that mark the floors.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_box(root, "Pier", Vector3(0.36, BODY_TOP - PLINTH, 0.36), Vector3(sx * HALF, (BODY_TOP + PLINTH) / 2.0, sz * HALF), plate)
	for y: float in [3.0, 4.9]:
		_box(root, "Band", Vector3(HALF * 2.0 + 0.1, 0.16, HALF * 2.0 + 0.1), Vector3(0, y, 0), plate)
	# Arrow slits: two on each face at each floor (none beside the door at the ground floor but the two that flank it).
	for face in 4:
		var yaw := face * PI / 2.0
		for level: float in [1.7, 4.0]:
			for off: float in [-1.15, 1.15]:
				var slit_pos := Vector3(off, level, HALF + 0.03)
				_slit(root, yaw, slit_pos, slit, dark)
	# Corbels and the battlement.
	_box(root, "Corbel", Vector3(SIDE + 0.3, CORBEL_TOP - BODY_TOP, SIDE + 0.3), Vector3(0, (BODY_TOP + CORBEL_TOP) / 2.0, 0), plate)
	var wall_h := PARAPET_TOP - CORBEL_TOP
	for sz: float in [-1.0, 1.0]:
		_box(root, "Parapet", Vector3(SIDE + 0.3, wall_h, 0.28), Vector3(0, CORBEL_TOP + wall_h / 2.0, sz * (SIDE / 2.0 + 0.01)), steel)
	for sx: float in [-1.0, 1.0]:
		_box(root, "Parapet", Vector3(0.28, wall_h, SIDE + 0.02), Vector3(sx * (SIDE / 2.0 + 0.01), CORBEL_TOP + wall_h / 2.0, 0), steel)
	var merlon_h := TOP - PARAPET_TOP
	for off: float in [-1.5, -0.5, 0.5, 1.5]:
		for sz: float in [-1.0, 1.0]:
			_box(root, "Merlon", Vector3(0.5, merlon_h, 0.28), Vector3(off, PARAPET_TOP + merlon_h / 2.0, sz * (SIDE / 2.0 + 0.01)), plate)
		for sx: float in [-1.0, 1.0]:
			_box(root, "Merlon", Vector3(0.28, merlon_h, 0.5), Vector3(sx * (SIDE / 2.0 + 0.01), PARAPET_TOP + merlon_h / 2.0, off), plate)
	# The roof inside the battlement, with its trapdoor.
	_box(root, "Deck", Vector3(SIDE - 0.1, 0.1, SIDE - 0.1), Vector3(0, CORBEL_TOP + 0.02, 0), dark)
	_box(root, "Trapdoor", Vector3(0.8, 0.07, 0.8), Vector3(-1.0, CORBEL_TOP + 0.1, -1.0), metal)
	_door(root, metal, plate, dark)
	return root


## One arrow slit: a pale-edged dark cut on the face the node is turned to by `yaw`.
static func _slit(root: Node3D, yaw: float, pos: Vector3, slit: Material, edge: Material) -> void:
	var holder := Node3D.new()
	holder.name = "Slit"
	holder.rotation.y = yaw
	root.add_child(holder)
	_box(holder, "Surround", Vector3(0.26, 0.9, 0.05), pos + Vector3(0, 0, 0.0), edge)
	_box(holder, "Cut", Vector3(0.11, 0.78, 0.05), pos + Vector3(0, 0, 0.03), slit)


## The door on the south face, at the foot, with the pale light that holds it shut.
static func _door(root: Node3D, metal: Material, plate: Material, dark: Material) -> void:
	var z := HALF + 0.04
	_box(root, "Step", Vector3(1.7, 0.2, 0.5), Vector3(0, 0.1, HALF + 0.3), plate)
	for sx: float in [-1.0, 1.0]:
		_box(root, "Jamb", Vector3(0.24, 1.8, 0.34), Vector3(sx * 0.64, PLINTH + 0.9, z), plate)
	_box(root, "Lintel", Vector3(1.52, 0.26, 0.36), Vector3(0, PLINTH + 1.93, z), plate)
	_box(root, "Door", Vector3(1.04, 1.78, 0.14), Vector3(0, PLINTH + 0.89, z - 0.04), metal)
	for sy: float in [0.5, 1.0, 1.5]:
		for sx: float in [-0.34, 0.34]:
			_box(root, "Rivet", Vector3(0.1, 0.1, 0.05), Vector3(sx, PLINTH + sy, z + 0.05), dark)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Look.color("moonlight")
	glow.emission_enabled = true
	glow.emission = Look.color("moonlight")
	_box(root, "Seam", Vector3(0.05, 1.7, 0.03), Vector3(0, PLINTH + 0.89, z + 0.04), glow)
	_box(root, "Rune", Vector3(1.3, 0.05, 0.03), Vector3(0, PLINTH + 1.82, z + 0.2), glow)
	var light := OmniLight3D.new()
	light.name = "DoorLight"
	light.light_color = Look.color("moonlight")
	light.omni_range = 3.5
	light.light_energy = 0.9
	light.position = Vector3(0, 1.4, HALF + 0.9)
	root.add_child(light)


static func _box(root: Node3D, node_name: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	root.add_child(mi)
	return mi


## Grows the tower out of the ground (it was set down as a statuette): a quick, heavy swell, not a slide.
static func rise(tower: Node3D, seconds: float = 1.1) -> Tween:
	tower.scale = Vector3(1.0, 0.02, 1.0)
	var tw := tower.create_tween()
	tw.tween_property(tower, "scale:y", 1.0, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw


## Shrinks it back into the statuette and removes it.
static func sink(tower: Node3D, seconds: float = 0.8) -> Tween:
	var tw := tower.create_tween()
	tw.tween_property(tower, "scale", Vector3(0.05, 0.02, 0.05), seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(tower.queue_free)
	return tw
