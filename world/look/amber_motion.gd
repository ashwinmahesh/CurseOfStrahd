class_name AmberMotion
extends RefCounted
## The Amber Temple's small motion (Amber Temple Look Plan step 11, docs/art/interiors.md), in the Modern finish: the hall
## of echoes is the cold room (its desks' candles burn frost-blue, the one warm candle is on Patrina's clear desk, and
## a slow fall of paper flakes crumbles and re-forms over her book); Vosk's cup steams in the library and Exethanter's
## pinned notes stir as if in a draught; Yrrga's eye follows the leader; and amber seeps from the weeping crack in the
## vaults. AmberGlow.dress_place builds them as a place is built and AmberGlow.refresh keeps what moves with the party.
## Only looks: nothing here reads or changes a rule.

const SEEP_SHADER := preload("res://shaders/world/amber_seep.gdshader")
## The hall of echoes' squares (the great hall's west room), and Patrina's desk, whose candle stays warm.
const ECHOES := Rect2i(0, 6, 11, 16)
const PATRINA_DESK := Vector2i(6, 8)
## The middle of the six blocks of the ring of amber (world x, z), how far out the gold inlay's outer edge reaches, and
## the decal it is made of.
const INLAY_AT := Vector2(36.0, 14.0)
const INLAY_RADIUS := 3.4
const INLAY_DECAL := "floor_temple_2"
## Where her book lies (squares, world x and z) and how high the flakes start above the floor.
const BOOK_AT := Vector2(6.55, 8.55)
const FLAKE_TOP := 1.25
## How near (squares) a desk's own candle light counts as the warm one's.
const WARM_NEAR := 1.4
## How far (squares) the eye of Yrrga's block moves within it to look at the leader, across and up.
const GAZE_ACROSS := 0.1
const GAZE_UP := 0.07
## Squares the leader's distance is measured over for the gaze (farther than this looks straight out).
const GAZE_REACH := 6.0


## Built once as a place is built.
static func dress(view: LocationView) -> void:
	match view.loc_id:
		"amber_temple_faceless_god":
			_flakes(view)
			_inlay(view)
		"amber_temple_library":
			_steam(view)
			_stir(view)
		"amber_temple_vault":
			_seep(view)


## Kept up as the party moves (AmberGlow.refresh, a few times a second): the hall of echoes' candles once Atmosphere has
## lit them, and the eye of Yrrga's block toward the leader.
static func refresh(view: LocationView) -> void:
	if view.loc_id == "amber_temple_faceless_god":
		_frost(view)
	var leader := view.leader()
	if leader != null and view.tokens.has(leader.id) and is_instance_valid(view.tokens[leader.id]):
		var at := (view.tokens[leader.id] as Node3D).global_position
		for n: Node in view.get_tree().get_nodes_in_group(&"amber_cases"):
			var c := n as AmberGlow.Case
			if c != null and c.gaze_quad != null and view.is_ancestor_of(c):
				c.set_gaze(at)


# --- The hall of echoes ------------------------------------------------------------------------------------------------

## The candles of the hall of echoes burn frost-blue, and their light with them, but for the one on Patrina's clear desk.
## Atmosphere lights the modelled candles a moment after the place is built, so this tries each refresh until it has.
static func _frost(view: LocationView) -> void:
	if view.has_meta("echoes_frosted") or not Look.modern():
		return
	var lit := false
	for l: Node in view.find_children("*", "OmniLight3D", true, false):
		if not str(l.name).begins_with("PropLight") and not str(l.name).begins_with("FlameLight"):
			continue   # (the lights Atmosphere gives the candles modelled into the pieces)
		var light := l as OmniLight3D
		var cell := view.grid.cell_at(light.global_position)
		if not ECHOES.has_point(cell) or _near_patrina(light.global_position):
			continue
		light.light_color = Look.color("frost")
		lit = true
	if not lit:
		return
	view.set_meta("echoes_frosted", true)
	for n: Node in view.find_children("Model_*", "Node3D", true, false):
		var piece := n as Node3D
		if ECHOES.has_point(view.grid.cell_at(piece.global_position)) and view.grid.cell_at(piece.global_position) != PATRINA_DESK:
			SetDressing.tint_candles(piece, "frost")


static func _near_patrina(at: Vector3) -> bool:
	return Vector2(at.x, at.z).distance_to(Vector2(PATRINA_DESK.x + 0.5, PATRINA_DESK.y + 0.5)) < WARM_NEAR


## Paper flakes falling slowly over Patrina's book: they come apart, drift down and fade before they land, and more come.
static func _flakes(view: LocationView) -> void:
	var p := GPUParticles3D.new()
	p.name = "PaperFlakes"
	p.amount = 14
	p.lifetime = 3.2
	p.preprocess = 3.0
	p.visibility_aabb = AABB(Vector3(-1, -2, -1), Vector3(2, 3, 2))
	p.position = Vector3(BOOK_AT.x, FLAKE_TOP, BOOK_AT.y)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.28, 0.02, 0.2)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.18
	pm.gravity = Vector3(0.02, -0.12, 0.0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pm.angular_velocity_min = -120.0
	pm.angular_velocity_max = 120.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 0.9))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Look.color("vellum")
	quad.material = m
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.add_child(p)


## The ring of amber's gold inlay (the paid decal `floor_temple_2`, a quarter of a ring of black stone set with gold lines):
## four of them turned a quarter each make a ring in the floor round the middle of the six blocks.
static func _inlay(view: LocationView) -> void:
	var info := Clutter.manifest().get(INLAY_DECAL, {}) as Dictionary
	if info.is_empty() or not ResourceLoader.exists("res://" + str(info.get("file", ""))):
		return
	var albedo := load("res://" + str(info["file"])) as Texture2D
	var normal: Texture2D = load("res://" + str(info["normal_file"])) as Texture2D if ResourceLoader.exists("res://" + str(info.get("normal_file", ""))) else null
	var root := Node3D.new()
	root.name = "GoldInlay"
	view.add_child(root)
	var c := Vector3(INLAY_AT.x, view.board.floor_y(Vector2i(int(INLAY_AT.x), int(INLAY_AT.y))) + 0.02, INLAY_AT.y)
	var aspect := float(info.get("aspect", 1.0))
	var w := INLAY_RADIUS * sqrt(aspect)
	var tall := INLAY_RADIUS / sqrt(aspect)
	for k in 4:
		var turn := Basis(Vector3.UP, float(k) * PI / 2.0)
		var d := Decal.new()
		d.name = "InlayQuarter%d" % k
		d.texture_albedo = albedo
		if normal != null:
			d.texture_normal = normal
		d.size = Vector3(w, Clutter.DEPTH, tall)
		d.basis = turn
		d.position = c + turn * Vector3(w / 2.0, 0.0, -tall / 2.0)   # (the arc bends round the picture's bottom left corner: the ring's middle)
		d.upper_fade = 0.25
		d.lower_fade = 0.25
		root.add_child(d)


# --- The library -------------------------------------------------------------------------------------------------------

## A thread of steam off Vosk's cup, while he sits at his table with it.
static func _steam(view: LocationView) -> void:
	var here := false   # (his token isn't built yet as the place is: read his entry, whose `when` says if he sits there)
	for npc: Variant in view.loc.get("npcs", []):
		if str((npc as Dictionary).get("npc", "")) == "vosk" and StoryConditions.check(str((npc as Dictionary).get("when", "")), view.st):
			here = true
	if not here:
		return
	var table := view.prop_nodes.get("vosk_table") as Node3D
	if table == null:
		return
	var cell := Vector2i(6, 13)
	for prop: Variant in view.loc.get("props", []):
		if str((prop as Dictionary)["id"]) == "vosk_table":
			cell = LocationView._cell((prop as Dictionary)["cell"])
	var p := GPUParticles3D.new()
	p.name = "CupSteam"
	p.amount = 14
	p.lifetime = 2.8
	p.preprocess = 2.0
	p.visibility_aabb = AABB(Vector3(-1, -0.5, -1), Vector3(2, 2.5, 2))
	p.position = view.board.cell_center(cell) + Vector3(0.18, 0.88, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 8.0
	pm.initial_velocity_min = 0.12
	pm.initial_velocity_max = 0.2
	pm.gravity = Vector3(0.02, 0.0, 0.0)
	pm.scale_min = 0.5
	pm.scale_max = 1.6
	pm.scale_curve = _grow()
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.25, Color(1, 1, 1, 0.7))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.17, 0.17)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Look.color("frost").lerp(Color.WHITE, 0.5)
	quad.material = m
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.add_child(p)


static func _grow() -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.5))
	c.add_point(Vector2(1.0, 1.6))
	var t := CurveTexture.new()
	t.curve = c
	return t


## Exethanter's pinned notes stir as if in a draught: the piece tips a little one way and the other, never twice alike.
static func _stir(view: LocationView) -> void:
	var node := view.prop_nodes.get("exethanter_notes") as Node3D
	if node == null:
		return
	for n: Node in node.find_children("Model_*", "Node3D", false, false):
		var piece := n as Node3D
		var seed_ := float(absi(hash(view.loc_id + "/notes")) % 100) / 100.0
		var t := piece.create_tween().set_loops()
		t.tween_property(piece, "rotation:z", 0.05, 2.3 + seed_).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(piece, "rotation:z", -0.03, 1.7 + seed_).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(piece, "rotation:z", 0.015, 2.9 - seed_).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var u := piece.create_tween().set_loops()
		u.tween_property(piece, "rotation:x", -0.04, 3.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		u.tween_property(piece, "rotation:x", 0.02, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --- The vaults --------------------------------------------------------------------------------------------------------

## A little amber seeping from the weeping crack (it shows only once the crack does: the prop's own `when`): a pool of honey
## light on the floor round it, with specks lifting out, and a low amber light.
static func _seep(view: LocationView) -> void:
	var crack := view.prop_nodes.get("vault_weeping_crack") as Node3D
	if crack == null:
		return
	var cell := Vector2i(36, 14)
	for p: Variant in view.loc.get("props", []):
		if str((p as Dictionary)["id"]) == "vault_weeping_crack":
			cell = LocationView._cell((p as Dictionary)["cell"])
	var pool := MeshInstance3D.new()
	pool.name = "AmberSeep"
	var quad := PlaneMesh.new()
	quad.size = Vector2(1.5, 1.1)
	pool.mesh = quad
	var m := ShaderMaterial.new()
	m.shader = SEEP_SHADER
	m.render_priority = 1
	pool.material_override = m
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.position = view.board.cell_center(cell) + Vector3(0.0, 0.04, 0.0)
	crack.add_child(pool)
	var light := CandleFlicker.new()
	light.name = "SeepLight"
	light.light_color = Look.color("flame")
	light.omni_range = 2.6
	light.base_energy = 0.7
	light.flicker = 0.0
	light.position = pool.position + Vector3(0.0, 0.25, 0.0)
	light.set_meta("amber", true)
	light.set_meta("no_shadow", true)
	crack.add_child(light)
