class_name Charm
extends Node3D
## A charm hanging on a thread from a tent's rope (TentWalls): a painted eye, a bell, a bone, a little mirror, a dried
## bird's foot, a string of beads or a tooth. They turn slowly on their threads; the eyes and mirrors turn, very slowly,
## to face the camera. Cosmetic only (no rules, no rolls).

## Radians a second: how fast the eyes find the camera, and how fast the rest turn.
const FACE_SPEED := 0.22
const SPIN_SPEED := 0.25

var kind := ""
var _spin := 0.0


static func make(kind_: String, colour: String, drop: float) -> Charm:
	var ch := Charm.new()
	ch.name = "Charm"
	ch.kind = kind_
	ch._spin = SPIN_SPEED * (0.6 + 0.8 * fposmod(drop * 37.0, 1.0)) * (1.0 if int(drop * 100.0) % 2 == 0 else -1.0)
	_part(ch, _box_mesh(Vector3(0.006, drop, 0.006)), Vector3(0, -drop / 2.0, 0), Vector3.ZERO, "ink")
	var at := Vector3(0, -drop, 0)
	match kind_:
		"eye", "mirror":
			# A disc facing +z: an eye painted on both sides, or a mirror in a dark rim.
			var r := 0.045 if kind_ == "eye" else 0.038
			_part(ch, _disc(r, 0.01), at + Vector3(0, -r, 0), Vector3(PI / 2.0, 0, 0), colour if kind_ == "eye" else "umber")
			if kind_ == "mirror":
				for s: float in [1.0, -1.0]:
					_part(ch, _disc(r * 0.78, 0.004), at + Vector3(0, -r, 0.005 * s), Vector3(PI / 2.0, 0, 0), colour)
			else:
				for s: float in [1.0, -1.0]:
					_part(ch, _disc(r * 0.58, 0.004), at + Vector3(0, -r, 0.006 * s), Vector3(PI / 2.0, 0, 0), "moon_blue")
					_part(ch, _disc(r * 0.26, 0.004), at + Vector3(0, -r, 0.009 * s), Vector3(PI / 2.0, 0, 0), "ink")
		"bell":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.01
			cm.bottom_radius = 0.034
			cm.height = 0.05
			cm.radial_segments = 10
			_part(ch, cm, at + Vector3(0, -0.025, 0), Vector3.ZERO, colour)
			_part(ch, _ball(0.009), at + Vector3(0, -0.052, 0), Vector3.ZERO, "ink")
		"bone":
			var bm := CapsuleMesh.new()
			bm.radius = 0.011
			bm.height = 0.1
			bm.radial_segments = 8
			_part(ch, bm, at + Vector3(0, -0.012, 0), Vector3(0, 0, PI / 2.0 - 0.3), colour)
			for s: float in [1.0, -1.0]:
				_part(ch, _ball(0.017), at + Vector3(0.045 * s, -0.012 - 0.014 * s, 0), Vector3.ZERO, colour)
		"foot":
			# A dried bird's foot: a shank and three toes spread under it.
			_part(ch, _box_mesh(Vector3(0.008, 0.05, 0.008)), at + Vector3(0, -0.025, 0), Vector3.ZERO, colour)
			for k in 3:
				_part(ch, _box_mesh(Vector3(0.006, 0.04, 0.006)), at + Vector3((k - 1) * 0.012, -0.065, 0),
					Vector3(0, 0, (k - 1) * 0.5), colour)
		"beads":
			for k in 4:
				_part(ch, _ball(0.012), at + Vector3(0, -0.014 - k * 0.026, 0), Vector3.ZERO, colour if k % 2 == 0 else "bone")
		"tooth":
			var tm := CylinderMesh.new()
			tm.top_radius = 0.012
			tm.bottom_radius = 0.0
			tm.height = 0.04
			tm.radial_segments = 8
			_part(ch, tm, at + Vector3(0, -0.02, 0), Vector3.ZERO, colour)
	return ch


func _process(delta: float) -> void:
	if kind == "eye" or kind == "mirror":
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		if cam == null:
			return
		var to := cam.global_position - global_position
		var want := atan2(to.x, to.z) - (get_parent_node_3d().global_rotation.y if get_parent_node_3d() != null else 0.0)
		var diff := wrapf(want - rotation.y, -PI, PI)
		rotation.y += clampf(diff, -FACE_SPEED * delta, FACE_SPEED * delta)
	else:
		rotation.y += _spin * delta


static func _part(parent: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3, colour: String) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = _material(colour)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static var _mats: Dictionary = {}


## One material per colour and look, shared by every charm.
static func _material(colour: String) -> Material:
	var key := "%s|%s" % [colour, Look.style()]
	if not _mats.has(key):
		_mats[key] = Look.cel(colour)
	return _mats[key] as Material


static func _box_mesh(size: Vector3) -> BoxMesh:
	var bm := BoxMesh.new()
	bm.size = size
	return bm


static func _disc(r: float, h: float) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 14
	return cm


static func _ball(r: float) -> SphereMesh:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	return sm
