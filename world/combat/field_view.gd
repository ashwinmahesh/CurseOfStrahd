class_name FieldView
extends Node3D
## Draws the encounter's FieldObjects (combat/field_object.gd): a spectral weapon hovering over its square, a
## rolling sphere of fire, floating lights, and lingering areas (Cloud of Daggers, Spirit Guardians, Web, Fog
## Cloud, Darkness...) as tinted squares on the floor. It only shows state: `sync()` matches the nodes to the
## encounter's objects and glides moved ones to their new square.

const GLIDE_TIME := 0.25
## Floor tint per spell, from the palette (anything else uses the zone's `colour` rule, then lilac).
const ZONE_COLOURS := {"darkness": "void", "fog_cloud": "mist_blue", "stinking_cloud": "sickly", "web": "bone",
	"sleet_storm": "frost", "silence": "night", "spirit_guardians": "candle", "cloud_of_daggers": "silver",
	"entangle": "moss", "grease": "umber", "aura_of_vitality": "bile", "crusaders_mantle": "flame",
	"faerie_fire": "orchid", "gust_of_wind": "moonlight", "hunger_of_hadar": "void", "spike_growth": "umber",
	"moonbeam": "moonlight", "wall_of_fire": "flame", "wind_wall": "mist_blue", "evards_black_tentacles": "night",
	"conjure_animals": "bone", "conjure_woodland_beings": "moss", "conjure_minor_elementals": "ember",
	"guardian_of_faith": "candle", "cordon_of_arrows": "silver", "ice_storm": "frost", "aura_of_life": "bile",
	"aura_of_purity": "moonlight", "call_lightning": "moon_blue", "plant_growth": "moss", "confusion": "orchid"}

var board: ArenaBoard
var _nodes: Dictionary = {}   ## object id -> Node3D
var _time := 0.0


static func create(board_: ArenaBoard) -> FieldView:
	var v := FieldView.new()
	v.name = "FieldView"
	v.board = board_
	return v


## Matches what's drawn to `objects` (Array[FieldObject]).
func sync(objects: Array) -> void:
	var live := {}
	for o: Variant in objects:
		var f := o as FieldObject
		if f.expired():
			continue
		live[f.id] = true
		var n := _nodes.get(f.id) as Node3D
		if n == null:
			n = _make(f)
			add_child(n)
			_nodes[f.id] = n
			n.position = _anchor(f)
			n.set_meta("cell", f.cell)
			n.set_meta("cells", f.cells.duplicate())
			continue
		if n.get_meta("cell") != f.cell:
			n.set_meta("cell", f.cell)
			var tw := create_tween()
			tw.tween_property(n, "position", _anchor(f), GLIDE_TIME).set_trans(Tween.TRANS_SINE)
		if f.kind == FieldObject.Kind.ZONE and n.get_meta("cells") != f.cells:
			n.set_meta("cells", f.cells.duplicate())
			_paint_zone(n, f)
	for id: String in _nodes.keys():
		if not live.has(id):
			(_nodes[id] as Node3D).queue_free()
			_nodes.erase(id)


func node_for(object_id: String) -> Node3D:
	return _nodes.get(object_id) as Node3D


func _anchor(f: FieldObject) -> Vector3:
	if f.kind == FieldObject.Kind.ZONE:
		return Vector3.ZERO
	return board.cell_center(f.cell)


func _make(f: FieldObject) -> Node3D:
	match f.kind:
		FieldObject.Kind.WEAPON:
			return _weapon()
		FieldObject.Kind.SPHERE:
			return _sphere()
		FieldObject.Kind.LIGHTS:
			return _lights()
		FieldObject.Kind.HAND:
			return _hand()
		FieldObject.Kind.ILLUSION:
			return _double()
		FieldObject.Kind.HOUND:
			return _hound()
		FieldObject.Kind.VINE:
			return _vine()
	var zone := Node3D.new()
	zone.name = "Zone_" + f.spell_id
	_paint_zone(zone, f)
	return zone


func _glow(colour: String, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(Look.color(colour), alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Look.color(colour)
	m.render_priority = 4
	return m


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## A floating spectral blade: blade, crossguard and grip in lilac light, slowly turning.
func _weapon() -> Node3D:
	var root := Node3D.new()
	root.name = "SpiritualWeapon"
	var spin := Node3D.new()
	spin.name = "Spin"
	spin.position.y = 0.9
	spin.scale = Vector3(1.6, 1.6, 1.6)
	root.add_child(spin)
	# A soft lilac ring on its square, so the weapon reads at a glance.
	var ring := TorusMesh.new()
	ring.inner_radius = 0.3
	ring.outer_radius = 0.38
	_part(root, ring, Vector3(0, 0.03, 0), _glow("lilac", 0.7))
	var blade := BoxMesh.new()
	blade.size = Vector3(0.09, 0.85, 0.03)
	var guard := BoxMesh.new()
	guard.size = Vector3(0.34, 0.06, 0.06)
	var grip := BoxMesh.new()
	grip.size = Vector3(0.05, 0.22, 0.05)
	var lit := _glow("lilac", 0.85)
	_part(spin, blade, Vector3(0, 0.05, 0), lit)
	_part(spin, guard, Vector3(0, -0.4, 0), _glow("orchid"))
	_part(spin, grip, Vector3(0, -0.54, 0), _glow("plum"))
	var light := OmniLight3D.new()
	light.light_color = Look.color("lilac")
	light.light_energy = 0.8
	light.omni_range = 2.2
	light.position.y = 0.9
	root.add_child(light)
	root.set_meta("bob", true)
	return root


func _sphere() -> Node3D:
	var root := Node3D.new()
	root.name = "FlamingSphere"
	var sm := SphereMesh.new()
	sm.radius = 0.45
	sm.height = 0.9
	_part(root, sm, Vector3(0, 0.47, 0), _glow("flame", 0.9))
	var light := OmniLight3D.new()
	light.light_color = Look.color("flame")
	light.light_energy = 1.6
	light.omni_range = 8.0
	light.position.y = 0.6
	root.add_child(light)
	return root


func _lights() -> Node3D:
	var root := Node3D.new()
	root.name = "DancingLights"
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.2
	for i in 4:
		var a := TAU * i / 4.0
		_part(root, sm, Vector3(cos(a) * 0.3, 1.0, sin(a) * 0.3), _glow("candle"))
	var light := OmniLight3D.new()
	light.light_color = Look.color("candle")
	light.light_energy = 0.7
	light.omni_range = 3.0
	light.position.y = 1.0
	root.add_child(light)
	root.set_meta("bob", true)
	return root


func _hand() -> Node3D:
	var root := Node3D.new()
	root.name = "MageHand"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.08, 0.3)
	_part(root, bm, Vector3(0, 0.8, 0), _glow("moon_blue", 0.7))
	root.set_meta("bob", true)
	return root


## Invoke Duplicity's double: a translucent, shimmering figure.
func _double() -> Node3D:
	var root := Node3D.new()
	root.name = "Duplicate"
	var cm := CapsuleMesh.new()
	cm.radius = 0.28
	cm.height = 1.1
	_part(root, cm, Vector3(0, 0.55, 0), _glow("moonlight", 0.35))
	return root


## Mordenkainen's Faithful Hound: a pale phantom dog (only its caster sees it; the player's view is the caster's).
func _hound() -> Node3D:
	var root := Node3D.new()
	root.name = "FaithfulHound"
	var body := CapsuleMesh.new()
	body.radius = 0.16
	body.height = 0.62
	_part(root, body, Vector3(0, 0.36, 0), _glow("moonlight", 0.45), Vector3(90, 0, 0))
	var head := SphereMesh.new()
	head.radius = 0.13
	head.height = 0.26
	_part(root, head, Vector3(0, 0.52, 0.32), _glow("moonlight", 0.55))
	return root


## Grasping Vine: a green stalk rising from its square.
func _vine() -> Node3D:
	var root := Node3D.new()
	root.name = "GraspingVine"
	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.04
	stalk.bottom_radius = 0.12
	stalk.height = 1.4
	_part(root, stalk, Vector3(0, 0.7, 0), _glow("moss", 0.9))
	var tip := TorusMesh.new()
	tip.inner_radius = 0.12
	tip.outer_radius = 0.18
	_part(root, tip, Vector3(0.1, 1.35, 0), _glow("bog", 0.9), Vector3(0, 0, 70))
	return root


## The area's squares as a translucent tint just above the floor.
func _paint_zone(zone: Node3D, f: FieldObject) -> void:
	for ch in zone.get_children():
		ch.queue_free()
	var colour := str(ZONE_COLOURS.get(f.spell_id, f.rule("colour", "lilac")))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.98, 0.98)
	mm.mesh = pm
	mm.instance_count = f.cells.size()
	for i in f.cells.size():
		var cell := f.cells[i]
		var y := board.floor_y(cell) + 0.014
		if board.grid.has_flag(cell, CombatGrid.LOW):
			y += ArenaBoard.LOW_H
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(cell.x + 0.5, y, cell.y + 0.5)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var heavy := str(f.rule("obscured", "")) == "heavy"
	mat.albedo_color = Color(Look.color(colour), 0.62 if heavy else 0.3)
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 5
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone.add_child(mmi)
	# Heavily Obscured areas (fog, darkness, stinking cloud) get a low wall of haze so they read as blocking sight.
	if heavy:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.98, 1.4, 0.98)
		var haze := MultiMesh.new()
		haze.transform_format = MultiMesh.TRANSFORM_3D
		haze.mesh = bm
		haze.instance_count = f.cells.size()
		for i in f.cells.size():
			var cell2 := f.cells[i]
			haze.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(cell2.x + 0.5, board.floor_y(cell2) + 0.7, cell2.y + 0.5)))
		var hz := MultiMeshInstance3D.new()
		hz.multimesh = haze
		var hm := mat.duplicate() as StandardMaterial3D
		hm.albedo_color = Color(Look.color(colour), 0.28)
		hz.material_override = hm
		hz.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		zone.add_child(hz)


func _process(delta: float) -> void:
	_time += delta
	for id: String in _nodes:
		var n := _nodes[id] as Node3D
		if n.has_meta("bob"):
			var spin := n.get_node_or_null("Spin") as Node3D
			if spin != null:
				spin.rotation.y += delta * 1.2
				spin.position.y = 1.0 + sin(_time * 2.4) * 0.08
