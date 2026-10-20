class_name SeeThrough
extends Node
## Walls, roofs and the like in the party's way (owner 2026-10-17: "the walls collapse down when looking from certain
## angles ... I don't like this behavior", and whole buildings going see-through "looks really weird"; 2026-10-19: "remove
## the weird visual effect where we get an x-ray if a player is blocked by an object, and instead use the opacity change"):
## every wall, house, castle piece, town wall, pillar and tower stands whole from every heading, and the pieces that
## hide the party (or whoever the camera follows) fade to the trees' opacity while they do, back to solid when they no
## longer do. Only the pieces on the line of sight fade (a house's walls and its roof as the one piece each is, an interior's
## walls a square at a time), nothing beside or behind the party, and no hole is cut in anything: it replaces the oval
## window that was drawn in them. Only the pieces marked here fade (mark()); floors, furniture, props and figures never do.
## Trees and rocks fade the same way (ArenaBoard.fade_occluders).
##
## One per view (LocationView): each frame it takes the pieces whose way from the camera to the party is crossed, by a few
## sight lines to the figure (head, chest, feet, either side; the rest of the party exploring) and eases their
## transparency up to FADED, the others back down to nothing. On a boss making an entrance (CameraRig.cutaway_focus), on
## whoever the camera follows (the leader exploring, the one acting in a fight), else on the point the camera looks at.

## The transparency of a piece that hides the party: the trees' billboards fade to 28% opacity (ArenaBoard.fade_occluders).
const FADED := 0.72
## How fast a piece fades in and out (transparency per second): a quarter of a second, as the trees do.
const SPEED := 4.0
## How often the pieces on the line of sight are looked for while the camera or the party moves (seconds).
const LOOK_EVERY := 0.05
## A piece wider than this (world units) is only taken for in the way where one of its faces is: a house's walls, a castle
## wall, rather than the box round them (which holds the party whenever it is inside).
const LARGE := 3.2
## The group the marked pieces are in.
const GROUP := &"see_fade"
## Meta on a piece made of glass with a shader of its own that fades by a uniform (mark_glass).
const GLASS := &"see_fade_glass"
## The sight lines: how high up a figure they aim (feet, chest, head) and how far to either side at the chest.
const HEIGHTS: Array[float] = [0.25, 0.9, 1.65]
const SIDE := 0.4
## A line stops this short of the figure, so a wall it stands against, behind it, is not in the way.
const STOP := 0.12

var rig: CameraRig = null
## Other things to keep in sight besides the one the camera is on: a Callable returning their feet (Array[Vector3]), the
## rest of the party exploring.
var also: Callable = Callable()

var _fading: Dictionary = {}     ## piece's instance id -> [piece, how transparent it is now]
var _goal: Dictionary = {}       ## piece's instance id -> piece, for the pieces that hide the party at the last look
var _since := 0.0
var _seen_from := Vector3.INF
var _seen_at := Vector3.INF
var _seen_count := -1
static var _meshes: Dictionary = {}   ## mesh instance id -> its TriangleMesh (null: it has none)


static func create(rig_: CameraRig) -> SeeThrough:
	var s := SeeThrough.new()
	s.name = "SeeThrough"
	s.rig = rig_
	return s


func _exit_tree() -> void:
	clear()


func _process(delta: float) -> void:
	update(delta)


## Where the camera is on (the party's feet, or what the camera clears the view to); null for none.
func focus() -> Variant:
	if not is_instance_valid(rig):
		return null
	if is_instance_valid(rig.cutaway_focus):
		return rig.cutaway_focus.global_position
	if is_instance_valid(rig.follow) and rig.follow.is_inside_tree():
		return rig.follow.global_position
	return rig.global_position if rig.is_inside_tree() else null


## One step: looks for the pieces in the way when the camera or the party has moved (or pieces came or went), and eases
## every piece toward its goal.
func update(delta: float) -> void:
	_since += delta
	var at: Variant = focus()
	if at is Vector3 and is_inside_tree() and is_instance_valid(rig.camera) and rig.camera.is_inside_tree():
		var eye := rig.camera.global_position
		var count := get_tree().get_node_count_in_group(GROUP)
		var moved := not eye.is_equal_approx(_seen_from) or not (at as Vector3).is_equal_approx(_seen_at) or count != _seen_count
		if moved and _since >= LOOK_EVERY:
			_since = 0.0
			_seen_from = eye
			_seen_at = at as Vector3
			_seen_count = count
			look(at as Vector3, eye, also.call() if also.is_valid() else [])
	else:
		_goal = {}
	step(delta)


## Takes the pieces in the way of a figure at `feet` (and the `others`) for a camera at `eye` as the ones to fade.
func look(feet: Vector3, eye: Vector3, others: Array = []) -> void:
	_goal = in_the_way(feet, eye, others)


## The marked pieces of this view whose way from `eye` to a figure standing at `feet` (and to the `others`' feet) is
## crossed: {instance id: piece}.
func in_the_way(feet: Vector3, eye: Vector3, others: Array = []) -> Dictionary:
	var spots: Array[Vector3] = [feet]
	for o: Variant in others:
		if o is Vector3:
			spots.append(o as Vector3)
	var lines: Array[Vector3] = []
	for i in spots.size():
		lines.append_array(sight_lines(spots[i], eye, i == 0))
	var view := get_parent()
	var out := {}
	if not is_inside_tree():
		return out
	# Only the pieces inside the box round the camera and every point looked at can be in the way: the rest are passed over
	# with one test.
	var span := AABB(eye, Vector3.ZERO)
	for t in lines:
		span = span.expand(t)
	span = span.grow(0.5)
	for n in get_tree().get_nodes_in_group(GROUP):
		var g := n as GeometryInstance3D
		if g == null:
			continue
		var box := g.global_transform * g.get_aabb()
		if not span.intersects(box) or not g.is_visible_in_tree() or (view != null and not view.is_ancestor_of(g)):
			continue
		if hides(g, eye, lines, box):
			out[g.get_instance_id()] = g
	return out


## The points a figure standing at `feet` is looked at in, from `eye`: feet, chest and head, and (for the one the camera is
## on, `full`) either side of the chest too.
static func sight_lines(feet: Vector3, eye: Vector3, full: bool = true) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for h in HEIGHTS:
		out.append(feet + Vector3(0.0, h, 0.0))
	if full:
		var d := Vector3(feet.x - eye.x, 0.0, feet.z - eye.z)
		var right := d.normalized().cross(Vector3.UP) * SIDE if d.length() > 0.001 else Vector3(SIDE, 0.0, 0.0)
		out.append(feet + Vector3(0.0, HEIGHTS[1], 0.0) + right)
		out.append(feet + Vector3(0.0, HEIGHTS[1], 0.0) - right)
	return out


## Whether piece `g` stands in the way of any line from `eye` to a point in `targets`: the box of the piece (`box`, or its
## own) is crossed by it and, for a piece wider than LARGE, one of its faces is.
static func hides(g: GeometryInstance3D, eye: Vector3, targets: Array[Vector3], box: AABB = AABB()) -> bool:
	if box.size == Vector3.ZERO:
		box = g.global_transform * g.get_aabb()
	var large := maxf(box.size.x, box.size.z) > LARGE
	var tri := _triangles(g) if large else null
	for t in targets:
		var end := t - (t - eye).normalized() * STOP
		if not box.intersects_segment(eye, end):
			continue
		if tri == null:
			return true
		var inv := g.global_transform.affine_inverse()
		if not tri.intersect_segment(inv * eye, inv * end).is_empty():
			return true
	return false


## The faces of `g`'s mesh, made once for each mesh; null for a piece that is not a mesh or has none.
static func _triangles(g: GeometryInstance3D) -> TriangleMesh:
	var mi := g as MeshInstance3D
	if mi == null or mi.mesh == null:
		return null
	var id := mi.mesh.get_instance_id()
	if not _meshes.has(id):
		_meshes[id] = mi.mesh.generate_triangle_mesh()
	return _meshes[id] as TriangleMesh


## Eases every piece toward its goal: FADED while it is in the way, nothing once it is not; a piece that is whole again
## is let go.
func step(delta: float) -> void:
	for id: int in _goal.keys():
		if not is_instance_valid(_goal[id]):
			_goal.erase(id)   # freed since the look (a place rebuilding its rock or unloading)
		elif not _fading.has(id):
			_fading[id] = [_goal[id], 0.0]
	for id: int in _fading.keys():
		var e := _fading[id] as Array
		# Asked of the Variant: casting a freed object to its class is an error of its own ("Trying to cast a freed object").
		if not is_instance_valid(e[0]):
			_fading.erase(id)
			continue
		var g := e[0] as GeometryInstance3D
		var to := FADED if _goal.has(id) else 0.0
		var a := move_toward(float(e[1]), to, delta * SPEED)
		e[1] = a
		set_fade(g, a)
		if a <= 0.0 and to <= 0.0:
			_fading.erase(id)


## Every piece back to solid.
func clear() -> void:
	for id: int in _fading:
		var piece: Variant = (_fading[id] as Array)[0]
		if is_instance_valid(piece):
			set_fade(piece as GeometryInstance3D, 0.0)
	_fading.clear()
	_goal = {}
	_seen_count = -1


## How faded piece `g` is (0 solid, 1 gone): its transparency, or the uniform of its glass.
static func set_fade(g: GeometryInstance3D, amount: float) -> void:
	if g.has_meta(GLASS):
		var m := g.material_override as ShaderMaterial
		if m != null:
			m.set_shader_parameter(&"see_fade", amount)
		return
	g.transparency = amount


## How faded piece `g` is now.
static func faded(g: GeometryInstance3D) -> float:
	if g.has_meta(GLASS):
		var m := g.material_override as ShaderMaterial
		var v: Variant = m.get_shader_parameter(&"see_fade") if m != null else null
		return float(v) if v != null else 0.0
	return g.transparency


## Marks `node` and every piece of geometry under it to fade where it stands between the camera and the party. A smoke
## or a spray (particles) is left as it is.
static func mark(node: Node) -> void:
	var pieces := node.find_children("*", "GeometryInstance3D", true, false)
	if node is GeometryInstance3D:
		pieces.append(node)
	for p in pieces:
		if p is GPUParticles3D or (p as Node).get_parent() is GPUParticles3D:
			continue
		(p as Node).add_to_group(GROUP)


## Marks one piece of glass that fades by the `see_fade` uniform of its own material (the Amber Temple's tall blocks,
## whose shader has its own alpha), since transparency would not reach it.
static func mark_glass(g: GeometryInstance3D) -> void:
	g.set_meta(GLASS, true)
	g.add_to_group(GROUP)


## Whether piece `g` fades: it was marked here.
static func marked(g: GeometryInstance3D) -> bool:
	return g.is_in_group(GROUP)
