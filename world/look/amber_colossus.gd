class_name AmberColossus
extends RefCounted
## The two colossi at the Amber Temple's doors (Amber Temple Look Plan §4a and step 8, docs/art/interiors.md): the Sentinel
## stands on a low dais of the temple's black stone with an amber seam round its edge (a prop, `sentinel_dais`, 2 x 2
## squares and 1 ft high; the people at the doors stand on it, `on` in their entry), and its eyes are lit: a light that
## breathes while it watches, flares with each line it speaks, sinks to an ember once it is stilled and is gone when it is
## destroyed (then the dais lies cracked through and shards of amber lie round it). The doors give off a warm wedge of
## light across the snow, and icicles hang from their lintel. The dead twin's colour is its prop's `tint`. As the party
## comes into its reach, the Sentinel turns its head to the leader. Only looks, only in the Modern finish; Classic keeps
## the figure on the bare snow.

const SHADER := preload("res://shaders/world/amber_colossus.gdshader")
const PLACE := "amber_temple_entrance"
## The Sentinel as a person (its npc id, and the id its lines are spoken under) and the flags that say how it is.
const NPC := "amber_sentinel"
const STILLED := "sentinel_stilled"
const DESTROYED := "sentinel_destroyed"
const SURFACE := "amber/black_stone"
## The dais: one foot high, and how far its seam is drawn inside its edge (the shader's own).
const DAIS_H := 0.2
## How high a figure's eyes are above its feet (the sprite draws them a tenth of its height below its crown, and it is
## 6.0 units tall), how large the halo they sit in is, how far their light reaches and how bright it burns.
const EYE_UP := 5.42
const EYE_HALO := 2.4
const EYE_GLOW := 1.0
const EYE_REACH := 8.0
const EYE_ENERGY := 0.9
## The brightness of the eyes' light and halo for each state (a share of the watching breath), and how fast the level eases.
const EYE_SPEAKING := 2.0
const EYE_STILLED := 0.2
const EYE_EASE := 3.0
## How long the Sentinel keeps its head turned to the party once nobody speaks (seconds) before it looks out again.
const TURN_BACK := 3.0
## The wedge of light from the doors: how far it runs from the doors' face and how wide it is at its far end (squares), and
## its strength by the phase of the day (the snow is bright at noon).
const WEDGE_LENGTH := 4.8
const WEDGE_WIDTH := 4.6
const WEDGE_STRENGTH := {"day": 0.45, "dusk": 0.8, "dawn": 0.8, "night": 1.05}
## The icicles on the doors' lintel: the sprite, how far along the doors from their middle (squares), its scale and how
## far in front of the door leaves it hangs.
const LINTEL: Array[Dictionary] = [
	{"art": "icicles_short", "dx": -0.52, "scale": 0.62}, {"art": "icicles_short", "dx": 0.5, "scale": 0.62},
	{"art": "icicles_long", "dx": -0.98, "scale": 0.8}, {"art": "icicles_long", "dx": 0.96, "scale": 0.7},
	{"art": "icicles_cluster", "dx": -0.2, "scale": 0.85}, {"art": "icicles_cluster", "dx": 0.28, "scale": 0.7},
	{"art": "icicles_single", "dx": 0.05, "scale": 1.0}, {"art": "icicles_single", "dx": -0.78, "scale": 0.9},
]
const LINTEL_OUT := 0.16
## The split colossus's prop, and the shards of amber that lie before its feet: how far from the middle of its square (squares
## across and down) and how large each is (clear of its feet: 3D pieces keep 2D sprites out of their footprint, test_models_3d). They are drawn here, not as props, because a prop on a square next to a building-sized
## piece makes it shrink to fit (ModelPiece.big_fit).
const TWIN := "cracked_colossus"
const TWIN_SHARDS: Array[Vector3] = [Vector3(-1.6, 1.3, 1.3), Vector3(1.5, 1.2, 1.6), Vector3(0.1, 1.6, 1.8)]


# --- The dais ---------------------------------------------------------------------------------------------------------

## The prop `sentinel_dais` (SetDressing.place), built under `root` over the squares its `span` covers from `cell`: a slab
## of black stone with an amber seam drawn round its top edge, or, `cracked` (once the Sentinel is destroyed), broken in
## two with the seam dim and the cracks run across it. The slab's top is where a person standing on it stands: `root`'s
## `seat` (LocationNpcs reads it for an entry with `on`). Nothing in the rules grid changes.
static func dais(board: ArenaBoard, root: Node3D, cell: Vector2i, spec: Dictionary, cracked: bool) -> Node3D:
	var span := spec.get("span", [2, 2]) as Array
	var across := float(span[0]) if span.size() == 2 else 2.0
	var down := float(span[1]) if span.size() == 2 else 2.0
	var low := INF
	var high := -INF
	for z in range(int(down)):
		for x in range(int(across)):
			var y := board.cell_center(cell + Vector2i(x, z)).y
			low = minf(low, y)
			high = maxf(high, y)
	var top := high + DAIS_H
	var middle := board.cell_center(cell) + Vector3((across - 1.0) / 2.0, 0.0, (down - 1.0) / 2.0)
	var mat: Material = Look.cel_textured(SURFACE)
	if mat == null:
		mat = Look.cel("stone_deep")
	root.set_meta("seat", Vector3(middle.x, top, middle.z))
	var thick := top - low + 0.12
	if cracked:
		# Two halves, the east one dropped a little and turned, with a gap between that the cracks glow in.
		for side: float in [-1.0, 1.0]:
			var bm := BoxMesh.new()
			bm.size = Vector3(across / 2.0 - 0.03, thick, down - 0.02)
			var mi := MeshInstance3D.new()
			mi.name = "DaisHalfEast" if side > 0.0 else "DaisHalfWest"
			mi.mesh = bm
			mi.material_override = mat
			mi.position = Vector3(middle.x + side * (across / 4.0 + 0.015), top - thick / 2.0 - (0.03 if side > 0.0 else 0.0), middle.z)
			mi.rotation = Vector3(0.0, 0.0, 0.03 * side) if side > 0.0 else Vector3.ZERO
			root.add_child(mi)
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(across - 0.02, thick, down - 0.02)
		var mi := MeshInstance3D.new()
		mi.name = "Dais"
		mi.mesh = bm
		mi.material_override = mat
		mi.position = Vector3(middle.x, top - thick / 2.0, middle.z)
		root.add_child(mi)
	# (The warmth of the amber keeps its top clear of the snow that lies on every other top face out here.)
	var plate := BoxMesh.new()
	plate.size = Vector3(across - 0.04, 0.012, down - 0.04)
	var cap := MeshInstance3D.new()
	cap.name = "DaisTop"
	cap.mesh = plate
	var dark := StandardMaterial3D.new()   # (lit stone takes the snow's white on every top face: this one does not)
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Look.color("ink").lerp(Look.color("ember_deep"), 0.25)
	cap.material_override = dark
	cap.position = Vector3(middle.x, top - 0.004, middle.z)
	root.add_child(cap)
	var seam := _material(0, "flame" if not cracked else "ember", 1.0 if not cracked else 0.5)
	seam.set_shader_parameter("crack", 1.0 if cracked else 0.0)
	seam.set_shader_parameter("seed", float(cell.x * 7 + cell.y * 3) / 10.0)
	var plane := PlaneMesh.new()
	plane.size = Vector2(across - 0.1, down - 0.1)
	var glow := MeshInstance3D.new()
	glow.name = "DaisSeam"
	glow.mesh = plane
	glow.material_override = seam
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position = Vector3(middle.x, top + 0.006, middle.z)
	root.add_child(glow)
	return root


static func _material(kind: int, colour: String, strength: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.render_priority = 2
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("colour", Look.color(colour))
	m.set_shader_parameter("strength", strength)
	return m


# --- The doors and the Sentinel's eyes ----------------------------------------------------------------------------------

## Built once as the place is built (AmberGlow.dress_place): the wedge of light, the icicles and the Sentinel's eyes.
static func dress(view: LocationView) -> void:
	if view.loc_id != PLACE or not Look.modern():
		return
	var doors := _doors(view)
	if not doors.is_empty():
		_wedge(view, doors)
		_icicles(view, doors)
	_twin_shards(view)
	var eye := Eye.new()
	eye.name = "SentinelEyes"
	eye.view = view
	view.add_child(eye)
	eye.build()
	# As the party comes into its reach, the Sentinel turns its head to the leader (the arrival line says so).
	view.dialogue_requested.connect(func(_ref: String, npc: String) -> void:
		if npc == NPC and is_instance_valid(eye):
			eye.turn_to_leader())


## Kept up as the party moves and as the story changes (AmberGlow.refresh): how the eyes burn, and how bright the doors' light
## is for the hour.
static func refresh(view: LocationView) -> void:
	if view.loc_id != PLACE:
		return
	var eye := view.get_node_or_null("SentinelEyes") as Eye
	if eye != null:
		eye.stilled = bool(view.st.get_flag(STILLED, false))
		eye.destroyed = bool(view.st.get_flag(DESTROYED, false))
		eye.speaking = view.speaking == NPC
	var wedge := view.board.get_node_or_null("DoorsWedge") as MeshInstance3D
	if wedge != null:
		var phase := view.time_phase()
		(wedge.material_override as ShaderMaterial).set_shader_parameter("strength", float(WEDGE_STRENGTH.get(phase, WEDGE_STRENGTH["night"])))


## The great doors' squares (the entry's `doors` whose ids begin "great_doors"), as the middle of them across and the south
## face of their wall: {x, z (the face), y (the floor), top (the lintel's height), width}.
static func _doors(view: LocationView) -> Dictionary:
	var xs: Array[float] = []
	var cell := Vector2i.ZERO
	var look := {}
	for d: Variant in view.loc.get("doors", []):
		var door := d as Dictionary
		if str(door.get("id", "")).begins_with("great_doors"):
			var c := LocationView._cell(door["cell"])
			xs.append(view.board.cell_center(c).x)
			cell = c
			look = SetDressing.door_look(door)
	if xs.is_empty():
		return {}
	var left: float = xs.min() - 0.5
	var right: float = xs.max() + 0.5
	var h := float(look.get("height", SetDressing.INTERIOR_DOOR_H))
	return {"x": (left + right) / 2.0, "z": float(cell.y) + 1.0, "y": view.board.floor_y(cell), "top": h, "width": right - left}


## A warm wedge of light on the snow, from the doors' seams out over the shelf.
static func _wedge(view: LocationView, doors: Dictionary) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_near := float(doors["width"]) / 2.0
	var half_far := WEDGE_WIDTH / 2.0
	var corners := [Vector2(-half_near, 0.0), Vector2(half_near, 0.0), Vector2(half_far, WEDGE_LENGTH), Vector2(-half_far, WEDGE_LENGTH)]
	var uvs := [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]
	for i: int in [0, 1, 2, 0, 2, 3]:
		var c := corners[i] as Vector2
		st.set_uv(uvs[i] as Vector2)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(c.x, 0.0, c.y))
	var mi := MeshInstance3D.new()
	mi.name = "DoorsWedge"
	mi.mesh = st.commit()
	mi.material_override = _material(2, "flame", float(WEDGE_STRENGTH["day"]))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(float(doors["x"]), float(doors["y"]) + 0.03, float(doors["z"]) + 0.02)
	view.board.add_child(mi)


## Icicles hung along the doors' lintel (the cut sprites icicles_*): they hang flat against the wall's face, their tops at the
## lintel, a few longer at the ends.
static func _icicles(view: LocationView, doors: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "DoorsIcicles"
	view.board.add_child(root)
	for piece: Dictionary in LINTEL:
		var sp := SetDressing.wall_sprite(str(piece["art"]))
		if sp == null:
			continue
		sp.pixel_size *= float(piece["scale"])
		var info := SetDressing.manifest()[str(piece["art"])] as Dictionary
		var drop := float(info.get("world_height", 0.4)) * float(piece["scale"])
		sp.position = Vector3(float(doors["x"]) + float(piece["dx"]), float(doors["y"]) + float(doors["top"]) - drop, float(doors["z"]) - 0.5 + LINTEL_OUT)
		root.add_child(sp)


## Shards of amber lying round the split colossus's feet.
static func _twin_shards(view: LocationView) -> void:
	var at: Variant = view.prop_cell(TWIN)
	if at == null:
		return
	var root := Node3D.new()
	root.name = "TwinShards"
	view.board.add_child(root)
	for shard in TWIN_SHARDS:
		var c := (at as Vector2i) + Vector2i(roundi(shard.x), roundi(shard.y))
		var piece := SetDressing.stand_piece(view.board, root, "amber_shards", c, shard.z)
		if piece != null:
			piece.position += Vector3(shard.x - roundf(shard.x), 0.0, shard.y - roundf(shard.y))


## The Sentinel's eyes: a light and a soft halo at head height over wherever its figure stands (the person on the dais, or
## the foe in a fight), burning as its state says. `follow` is the figure to light when it is not the person at the doors.
class Eye extends Node3D:
	var view: LocationView = null
	var follow: Node3D = null
	var light: CandleFlicker = null
	var halo: MeshInstance3D = null
	var speaking := false
	var stilled := false
	var destroyed := false
	var _level := 1.0
	var _flare := 0.0
	var _clock := 0.0
	var _quiet := 0.0
	var _turned := false

	func build() -> void:
		light = CandleFlicker.new()
		light.name = "EyeLight"
		light.light_color = Look.color("flame")
		light.omni_range = AmberColossus.EYE_REACH
		light.base_energy = AmberColossus.EYE_ENERGY
		light.flicker = 0.0   # (the amber kind's own breath takes over once Atmosphere has dressed it)
		light.set_meta("amber", true)
		light.set_meta("no_shadow", true)
		add_child(light)
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * AmberColossus.EYE_HALO
		halo = MeshInstance3D.new()
		halo.name = "EyeHalo"
		halo.mesh = quad
		var m := AmberColossus._material(1, "flame", 1.0)
		m.render_priority = 4
		halo.material_override = m
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(halo)
		visible = false

	## A flash of the eyes (the wake of a step-down), fading over a second or so.
	func flare(power: float = 1.0) -> void:
		_flare = maxf(_flare, power)

	## The figure whose eyes these are now: `follow` while it is alive in the scene, else the person at the doors.
	func figure() -> Node3D:
		if is_instance_valid(follow) and follow.is_inside_tree():
			return follow
		var tok := view.npc_tokens.get(AmberColossus.NPC) as Node3D
		return tok if is_instance_valid(tok) and tok.is_inside_tree() else null

	func turn_to_leader() -> void:
		var tok := view.npc_tokens.get(AmberColossus.NPC) as CombatToken
		var leader := view.leader()
		if tok == null or leader == null:
			return
		_turned = true
		_quiet = 0.0
		tok.face(Vector2(view.grid.cell_at(leader_position()) - view.grid.cell_at(tok.global_position)), false)

	func leader_position() -> Vector3:
		var tok := view.tokens.get(view.leader().id) as Node3D
		return tok.global_position if tok != null else Vector3.ZERO

	func _process(delta: float) -> void:
		var fig := figure()
		var lit := fig != null and fig.visible and not destroyed
		visible = lit
		if not lit:
			return
		_clock += delta
		global_position = fig.global_position + Vector3(0.0, AmberColossus.EYE_UP, 0.0)
		var want := AmberColossus.EYE_STILLED if stilled else (AmberColossus.EYE_SPEAKING * (1.0 + 0.12 * sin(_clock * 6.0)) if speaking else 1.0)
		_level = lerpf(_level, want, clampf(delta * AmberColossus.EYE_EASE, 0.0, 1.0))
		_flare = move_toward(_flare, 0.0, delta * 1.2)
		var level := _level + _flare * 2.5
		light.base_energy = AmberColossus.EYE_ENERGY * level
		light.light_color = Look.color("flame").lerp(Color.WHITE, clampf(_flare * 0.5, 0.0, 0.5))
		(halo.material_override as ShaderMaterial).set_shader_parameter("strength", AmberColossus.EYE_GLOW * level)
		# It looks out over the valley again once nobody has spoken for a while.
		if _turned:
			_quiet = 0.0 if speaking else _quiet + delta
			if _quiet > AmberColossus.TURN_BACK:
				_turned = false
				var tok := view.npc_tokens.get(AmberColossus.NPC) as CombatToken
				if tok != null:
					tok.face(Vector2(0.0, 1.0), false)
