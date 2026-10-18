class_name SeeThrough
extends Node
## Walls in the party's way (owner 2026-10-17: "the walls collapse down when looking from certain angles ... I don't
## like this behavior", and big walls all round going see-through "looks really weird"): every wall, house, castle
## piece, town wall, pillar and tower stands whole from every heading, and a window opens in whatever stands nearer the
## camera than the party: an oval round the party on screen with a dithered rim, the party and the ground round it
## showing through (shaders/world/see_through.gdshaderinc). It moves with the party and turns with the camera; nothing
## beside or behind the party ever opens. Only the pieces marked here open (mark()); floors, furniture, props and
## figures never do. Trees and rocks still fade whole like foliage (ArenaBoard.fade_occluders). Replaces the walls
## that dropped to a stub (TownBuilder.cut_away, InteriorWalls.cut) and the houses that went see-through whole.
##
## One per view (LocationView): just before each frame is drawn it puts the window where the view's camera sees the
## party: on a boss making an entrance (CameraRig.cutaway_focus), on whoever the camera follows (the leader exploring,
## the one acting in a fight), else on the point the camera looks at.

## The window's half-width at the party (world units, a square each); it's a little taller than wide (SEE_TALL).
const RADIUS := 1.9
## How much nearer the camera than the party's middle a piece must stand to open: a wall beside the party stays.
const MARGIN := 0.75

var rig: CameraRig = null


static func create(rig_: CameraRig) -> SeeThrough:
	var s := SeeThrough.new()
	s.name = "SeeThrough"
	s.rig = rig_
	return s


func _enter_tree() -> void:
	if not RenderingServer.frame_pre_draw.is_connected(_place):
		RenderingServer.frame_pre_draw.connect(_place)


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_place):
		RenderingServer.frame_pre_draw.disconnect(_place)
	shut()


## Where the window is (the party's feet, or what the camera clears the view to); null for none.
func focus() -> Variant:
	if not is_instance_valid(rig):
		return null
	if is_instance_valid(rig.cutaway_focus):
		return rig.cutaway_focus.global_position
	if is_instance_valid(rig.follow) and rig.follow.is_inside_tree():
		return rig.follow.global_position
	return rig.global_position if rig.is_inside_tree() else null


## Each frame, once everything has moved: the window on the party, for this view's camera.
func _place() -> void:
	var at: Variant = focus()
	if not at is Vector3 or rig.camera == null or not rig.camera.is_inside_tree():
		shut()
		return
	open_at(at as Vector3, rig.camera.get_camera_transform().origin)


## Puts the window on `at` (the party's feet; the shader centres it on their middle) for a camera at `eye`.
static func open_at(at: Vector3, eye: Vector3) -> void:
	RenderingServer.global_shader_parameter_set(&"see_window", Vector4(at.x, at.y, at.z, RADIUS))
	RenderingServer.global_shader_parameter_set(&"see_window_eye", Vector4(eye.x, eye.y, eye.z, MARGIN))


## No window: every wall drawn whole.
static func shut() -> void:
	RenderingServer.global_shader_parameter_set(&"see_window", Vector4.ZERO)


## Marks `node` and every mesh under it to open where it stands between the camera and the party: each is drawn with
## a copy of its material that has the shader's `see_through` on (one copy per material, shared). A material the
## window's shaders don't draw (a sprite's, smoke) is left as it is.
static func mark(node: Node) -> void:
	var meshes := node.find_children("*", "GeometryInstance3D", true, false)
	if node is GeometryInstance3D:
		meshes.append(node)
	for g in meshes:
		var gi := g as GeometryInstance3D
		if gi.material_override != null:
			gi.material_override = opening(gi.material_override)
			continue
		var mi := gi as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m != null:
				var o := opening(m)
				if o != m:
					mi.set_surface_override_material(i, o)


## The copy of material `m` that opens round the party (`m` itself where its shader has no window), made once and kept
## on `m` (meta COPY), so it lives as long as `m` does: a shared texture's walls share it (Look.set_surface_tints tints
## it with `m`), and a material made for one wall goes with it.
static func opening(m: Material) -> Material:
	var sm := m as ShaderMaterial
	if sm == null or not _cuts(sm.shader) or _on(sm):
		return m
	if not sm.has_meta(COPY):
		var c := sm.duplicate() as ShaderMaterial
		c.set_shader_parameter(&"see_through", true)
		sm.set_meta(COPY, c)
	return sm.get_meta(COPY) as Material


const COPY := &"see_through_copy"
static var _cutting: Dictionary = {}  ## shader -> whether it has the window


static func _on(sm: ShaderMaterial) -> bool:
	var v: Variant = sm.get_shader_parameter(&"see_through")
	return v != null and bool(v)


## Whether `shader` draws the window (includes see_through.gdshaderinc).
static func _cuts(shader: Shader) -> bool:
	if shader == null:
		return false
	if not _cutting.has(shader):
		_cutting[shader] = shader.code.contains("see_through.gdshaderinc")
	return bool(_cutting[shader])


## Whether mesh `g` opens: it's drawn with the window's shaders, every material of it with `see_through` on.
static func marked(g: GeometryInstance3D) -> bool:
	var mats: Array[Material] = []
	if g.material_override != null:
		mats.append(g.material_override)
	elif g is MeshInstance3D and (g as MeshInstance3D).mesh != null:
		for i in (g as MeshInstance3D).mesh.get_surface_count():
			mats.append((g as MeshInstance3D).get_active_material(i))
	var any := false
	for m in mats:
		var sm := m as ShaderMaterial
		if sm == null or not _cuts(sm.shader):
			continue
		if not _on(sm):
			return false
		any = true
	return any
