class_name FacelessGod
extends RefCounted
## The faceless god in the great hall (Amber Temple Look Plan step 7, docs/art/interiors.md): the 2 x 2 block of wall
## the statue stands on is drawn as three steps of the temple's black stone, low enough to see the whole god over
## (its squares still block, the rules' grid is untouched); the statue stands on the top step; a smooth void takes the
## place of its face, with a faint violet corona turning slowly round it; and a single cold shaft of light falls from far
## above onto its open hands and the offerings at its feet. Only in the Modern finish; Classic keeps the block.

const VOID_SHADER := preload("res://shaders/world/faceless_void.gdshader")
const SHAFT_SHADER := preload("res://addons/dnd_core/shaders/world/sun_shaft.gdshader")
const SURFACE := "amber/black_stone"
## The steps from the ground up: how wide each is (in squares; the block is two) and how high.
const STEPS: Array[Vector2] = [Vector2(2.0, 0.5), Vector2(1.62, 0.42), Vector2(1.24, 0.34)]
## Where the face is on the statue, as a share of its height (the oval in its picture), and the void's size.
const FACE_AT := 0.855
const FACE_SIZE := Vector2(1.5, 1.5)
## The shaft: how high it starts, how wide it is at the top and the foot, where it lands (squares south and west of the
## statue's middle), and how bright it is.
const SHAFT_TOP := 9.0
const SHAFT_RADIUS_TOP := 0.32
const SHAFT_RADIUS_FOOT := 0.85
const SHAFT_FOOT := Vector2(-0.25, 1.5)
const SHAFT_STRENGTH := 0.32
## How far (as a dot product with the way it faces) the camera must be in front of the statue for the void to show.
const FRONT := 0.15


## The height of the steps a wall square stands in, 0 where it is not part of any.
static func top_at(board: ArenaBoard, cell: Vector2i) -> float:
	if not Look.modern() or not bool(board.wall_style_at(cell).get("plinth", false)):
		return 0.0
	var total := 0.0
	for s in STEPS:
		total += s.y
	return total


## Builds the steps over the wall block `rect` (from its first square, once), in the temple's black stone.
static func steps(board: ArenaBoard, rect: Rect2i) -> void:
	var root := Node3D.new()
	root.name = "GodSteps"
	root.set_meta("stays", true)   # the statue's prop on its first square would clear what the board built there (ArenaBoard.clear_cell)
	board.add_child(root)
	var mat: Material = Look.cel_textured(SURFACE)
	if mat == null:
		mat = Look.cel("stone_deep")
	var middle := Vector3(rect.position.x + rect.size.x / 2.0, 0.0, rect.position.y + rect.size.y / 2.0)
	var y := 0.0
	var n := 0
	for s in STEPS:
		n += 1
		var bm := BoxMesh.new()
		bm.size = Vector3(s.x * float(rect.size.x) / 2.0, s.y, s.x * float(rect.size.y) / 2.0)
		var mi := MeshInstance3D.new()
		mi.name = "Step%d" % n
		mi.mesh = bm
		mi.material_override = mat
		mi.position = middle + Vector3(0.0, y + s.y / 2.0, 0.0)
		root.add_child(mi)
		y += s.y


## The statue `piece` (standing on `cell`, a square of the steps) stands on the top step, its face is a void and the shaft
## falls on it. `root` is the prop's node, which owns everything added here.
static func dress(board: ArenaBoard, root: Node3D, piece: Node3D, cell: Vector2i) -> void:
	if not Look.modern():
		return
	piece.position.y += top_at(board, cell)
	var height := _height(piece)
	var face := Face.new()
	face.name = "VoidFace"
	face.statue = piece
	var quad := QuadMesh.new()
	quad.size = FACE_SIZE
	face.mesh = quad
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = VOID_SHADER
	m.render_priority = 3
	m.set_shader_parameter("corona", Look.color("orchid"))
	face.material_override = m
	face.position = piece.position + Vector3(0.0, height * FACE_AT, 0.0)
	root.add_child(face)
	_shaft(root, piece.position + Vector3(SHAFT_FOOT.x, 0.0, SHAFT_FOOT.y))


## How tall the statue stands, in world units: its model's height at its scale.
static func _height(piece: Node3D) -> float:
	var id := str(piece.get_meta("model", ""))
	var info := ModelPiece.manifest().get(id, {}) as Dictionary
	var size := info.get("size", [0, 5.0, 0]) as Array
	var scale_ := 1.0
	if piece.get_child_count() > 0 and piece.get_child(0) is Node3D:
		scale_ = (piece.get_child(0) as Node3D).scale.y
	return float(size[1]) * scale_


## One cold shaft from far above onto `foot` (a cone of the sun-shaft shader's light, and a pool of it on the floor).
static func _shaft(root: Node3D, foot: Vector3) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = SHAFT_RADIUS_TOP
	cone.bottom_radius = SHAFT_RADIUS_FOOT
	cone.height = SHAFT_TOP
	cone.radial_segments = 20
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var beam := MeshInstance3D.new()
	beam.name = "GodShaft"
	beam.mesh = cone
	beam.material_override = _shaft_material(false)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position = foot + Vector3(0.0, SHAFT_TOP / 2.0, 0.0)
	root.add_child(beam)
	var patch := PlaneMesh.new()
	patch.size = Vector2.ONE * SHAFT_RADIUS_FOOT * 2.4
	var pool := MeshInstance3D.new()
	pool.name = "GodShaftPool"
	pool.mesh = patch
	pool.material_override = _shaft_material(true)
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.position = foot + Vector3(0.0, 0.05, 0.0)
	root.add_child(pool)


static func _shaft_material(pool: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHAFT_SHADER
	m.render_priority = 1
	m.set_shader_parameter("seed", 0.37)
	m.set_shader_parameter("pool", pool)
	m.set_shader_parameter("shaft_length", SHAFT_TOP)
	m.set_shader_parameter("strength", SHAFT_STRENGTH)
	m.set_shader_parameter("colour", Look.color("frost").lerp(Color.WHITE, 0.2))
	return m


## The void over the statue's face: shown only while the camera looks at the statue's front.
class Face extends MeshInstance3D:
	var statue: Node3D = null

	func _process(_delta: float) -> void:
		var cam := get_viewport().get_camera_3d()
		if cam == null or not is_instance_valid(statue):
			return
		var facing := statue.global_basis.z
		facing.y = 0.0
		var to_cam := cam.global_position - statue.global_position
		to_cam.y = 0.0
		visible = facing.normalized().dot(to_cam.normalized()) > FacelessGod.FRONT
