class_name AmberGlow
extends RefCounted
## The Amber Temple's amber (Amber Temple Look Plan §3, docs/art/interiors.md): in the Modern finish every block of amber
## the temple holds is built in code and lit from inside (shaders/world/amber.gdshader), not drawn as one lying, blown-out
## box. The sixteen vestiges stand upright, about two squares tall, on a low plinth of the temple's black stone with a
## carved lid band, each with a light of its own inside (the `amber` light kind: a slow breath that the block's glow
## follows). The others are the same amber made differently, picked by the catalog id's `case`:
##   vestige  an upright block, alive, with its light (the ring of amber, the hall of vestiges)
##   cracked  the same, dead and split down the middle, amber shards round its foot
##   sleeper  a person asleep in amber, lying down (the hall of sleepers under the vaults)
##   hollow   the Thirst's empty sarcophagus: the largest block of all, lying across the squares of low cover it covers,
##            dead and clouded, with the shape of a man hollowed out of its top
##   plinth   the empty plinth where a sarcophagus stood, a ring of frost round it and scrape marks toward the way out
##   block    the cottage-sized block of amber in the Eye's chamber, split open from the inside like an egg
## Only looks: a case stands on the squares its prop already has ('=' low cover), so the rules never read any of it.
## Classic keeps the old lying box (SetDressing.place).

const BODY_SHADER := preload("res://shaders/world/amber.gdshader")
const SHAPE_SHADER := preload("res://shaders/world/amber_shape.gdshader")
## What each vestige holds in its block (art/amber_shapes.json, built by make vestige_shapes) and where its picture is.
const SHAPES_JSON := "res://art/amber_shapes.json"
const SHAPE_DIR := "res://art/textures/amber/shapes/"
## The touches the shape shader draws (amber_shape.gdshader's `touch`), by name in the data.
const TOUCHES := {"flecks": 1, "bubbles": 2, "twitch": 3, "cracks": 4, "glints": 5, "stars_down": 6, "fade": 7,
	"sparks_up": 8, "ring": 9, "orbit": 10, "void": 11}
## The colour of what a touch draws: flecks gold, bubbles the sick green of bile, sparks and glints bright.
const TOUCH_COLOURS := {"flecks": "wick", "bubbles": "bile", "twitch": "flame", "cracks": "ember_deep", "glints": "frost",
	"stars_down": "frost", "fade": "flame", "sparks_up": "flame", "ring": "wick", "orbit": "flame", "void": "flame"}
const FLOOR_SURFACE := "amber/black_stone"
## How many squares of low cover at most a case spreads over (a runaway fill of a long row of cover is no amber).
const MAX_SQUARES := 25
## How strongly a block's own light lights the haze round it (the amber kind's own is 1.5).
const FOG_ENERGY := 0.3
## Render order of a block's parts (higher draws later): the far inside of the glass, its near face, and over that what is
## held in it (drawn after the near face so its dark shows through the glow; it hangs in the middle of the block, so it
## still reads as inside).
const PRIORITY_INSIDE := 0
const PRIORITY_OUTSIDE := 1
const PRIORITY_SHAPE := 2

static var _inside_shader: Shader = null
static var _shapes: Dictionary = {}


## The amber shown or hidden everywhere (tools/perf/perf_probe.gd switches an effect named by its class off and on to
## price it; a case's glass and its light go with it).
static func set_enabled(on: bool) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for n in tree.get_nodes_in_group(&"amber_cases"):
		(n as Node3D).visible = on


## A block of amber's size in squares (width, height, depth), by case, and how it is made (see the header).
const CASES := {
	"vestige": {"size": Vector3(0.8, 1.84, 0.54), "plinth": Vector3(0.96, 0.16, 0.72), "lid": true, "light": true,
		"dead": 0.0, "cloud": 0.12, "window": true},
	"cracked": {"size": Vector3(0.8, 1.84, 0.54), "plinth": Vector3(0.96, 0.16, 0.72), "lid": true, "light": false,
		"dead": 0.9, "cloud": 0.7, "crack": true, "window": true},
	"sleeper": {"size": Vector3(0.96, 0.46, 0.6), "plinth": Vector3.ZERO, "lid": false, "light": false, "dead": 0.0,
		"cloud": 0.3},
	"hollow": {"height": 1.0, "depth": 0.9, "plinth_height": 0.12, "dead": 0.82, "cloud": 0.8},
	"plinth": {},
	"block": {"size": Vector3(3.3, 3.2, 2.4), "dead": 0.35, "cloud": 0.55, "window": true},
}


## What each vestige holds, by its id (art/amber_shapes.json: its shape layers, tint, touch and block colours).
static func shapes() -> Dictionary:
	if _shapes.is_empty():
		_shapes = (JSON.parse_string(FileAccess.get_file_as_string(SHAPES_JSON)) as Dictionary).get("shapes", {}) as Dictionary
	return _shapes


## The vestige a prop id names ("sarc_zantras" is "zantras"), or "".
static func vestige_of(prop_id: String) -> String:
	var v := prop_id.trim_prefix("sarc_")
	return v if v != prop_id and shapes().has(v) else ""


# --- The temple answers (Amber Temple Look Plan §3.1, LocationView refreshes this a few times a second) ----------------

## A block's states. The wardens' seal over everything, then a line of its vestige on screen (a flare that pulses with it),
## then its gift taken, then its conversation open while another voice speaks, then waiting.
const WAITING := "waiting"
const ATTENDING := "attending"
const SPEAKING := "speaking"
const SATED := "sated"
const SEALED := "sealed"
## What each state asks of a block: how bright its glass glows (a share of its light's own breath), how far toward murk its
## glass is (0 as built, 1 dead), how bright its light burns, how strongly and how softly the shape inside shows (1 as it
## was made), whether the light still breathes, the share a second it eases there, and the flare's pulse.
const LOOKS := {
	WAITING: {"glow": 1.0, "dead": 0.0, "light": 1.0, "shown": 1.0, "soft": 1.0, "breath": true, "ease": 1.5},
	ATTENDING: {"glow": 1.3, "dead": 0.0, "light": 1.35, "shown": 1.05, "soft": 1.0, "breath": true, "ease": 3.0},
	SPEAKING: {"glow": 2.1, "dead": 0.0, "light": 2.6, "shown": 1.15, "soft": 1.0, "breath": true, "ease": 7.0,
		"pulse": 0.25},
	SATED: {"glow": 0.5, "dead": 0.0, "light": 0.4, "shown": 1.45, "soft": 0.45, "breath": false, "ease": 0.8},
	SEALED: {"glow": 0.0, "dead": 1.0, "light": 0.0, "shown": 0.5, "soft": 1.3, "breath": false, "ease": 0.5},
}
## How near (squares) the party brightens a waiting block, and by how much at its foot (a share of its glow).
const NEAR_RANGE := 5.0
const NEAR_GAIN := 0.35
## How dead the glass is once the temple is sealed (never fully flat: the shape is still faintly there).
const SEALED_DEAD := 0.96
## The speaker ids of the vestiges' lines: "vestige_<name>".
const SPEAKER_PREFIX := "vestige_"


## The state of the block of `vestige` ("zantras") whose prop is `prop_id`, given the story and what is on screen.
static func state_of(view: LocationView, vestige: String, prop_id: String) -> String:
	if bool(view.st.get_flag("amber_temple_sealed", false)):
		return SEALED
	if vestige == "":
		return WAITING
	if view.speaking == SPEAKER_PREFIX + vestige:
		return SPEAKING
	if StoryConditions.check("gift:gift_of_" + vestige, view.st):
		return SATED
	if view.dialogue_prop == prop_id:
		return ATTENDING
	return WAITING


## Every block of amber in `view` takes the state the story and the screen give it (a few times a second, from
## LocationView._process; and when whose line is on screen changes): sealed, speaking, sated, attending or waiting, with how
## near the party stands. A block that has no state yet takes its first at once (a sealed temple opens dark, not fading).
static func refresh(view: LocationView) -> void:
	if view == null or view.st == null or not view.is_inside_tree():
		return
	var cases := view.get_tree().get_nodes_in_group(&"amber_cases")
	if cases.is_empty():
		return
	var party: Array[Vector2] = []
	for m: Combatant in view.members:
		if view.tokens.has(m.id) and is_instance_valid(view.tokens[m.id]):
			var at := (view.tokens[m.id] as Node3D).global_position
			party.append(Vector2(at.x, at.z))
	for n: Node in cases:
		var c := n as Case
		if c == null or c.glass.is_empty() or not view.is_ancestor_of(c):
			continue
		var from := Vector2(c.global_position.x, c.global_position.z)
		var near := 0.0
		for p: Vector2 in party:
			near = maxf(near, 1.0 - clampf(p.distance_to(from) / NEAR_RANGE, 0.0, 1.0))
		c.set_state(state_of(view, c.vestige, c.prop_id), smoothstep(0.0, 1.0, near))


## Builds the case for a location prop at `cell` under `root` (SetDressing.place's node for it): `look` is its catalog
## entry ({art: "amber_case", case: ...}). Returns `root`.
static func place(board: ArenaBoard, root: Node3D, cell: Vector2i, look: Dictionary) -> Node3D:
	var kind := str(look.get("case", "vestige"))
	if not CASES.has(kind):
		kind = "vestige"
	var spec := CASES[kind] as Dictionary
	var spread := kind in ["hollow", "block"]
	var foot := _footprint(board, cell, spread)
	for z in range(foot.position.y, foot.end.y):
		for x in range(foot.position.x, foot.end.x):
			var c := Vector2i(x, z)
			if board.grid.has_flag(c, CombatGrid.LOW) or board.grid.has_flag(c, CombatGrid.WALL):
				SetDressing.take_square(board, root, c)   # it stands where the board's own cover lay
	var case := Case.new()
	case.name = "AmberCase_" + str(root.name).trim_prefix("Dressing_")
	case.kind = kind
	case.prop_id = str(root.name).trim_prefix("Dressing_")
	case.vestige = vestige_of(case.prop_id)
	case.base_dead = float(spec.get("dead", 0.0))
	var a := board.cell_center(foot.position)
	var b := board.cell_center(foot.end - Vector2i.ONE)
	case.position = Vector3((a.x + b.x) / 2.0, minf(a.y, b.y), (a.z + b.z) / 2.0)
	case.rotation.y = _yaw(board, cell) if kind in ["vestige", "cracked", "sleeper"] else 0.0
	root.add_child(case)
	case.add_to_group(&"amber_cases")
	match kind:
		"vestige", "cracked":
			_upright(case, spec, kind)
		"sleeper":
			_sleeper(case, spec)
		"hollow":
			_hollow(case, spec, foot)
		"plinth":
			_empty_plinth(board, case, cell)
		"block":
			_egg(case, spec, foot)
	case.finish()
	return root


# --- The squares and the way a case faces --------------------------------------------------------------------------------

## The squares the case lies over: its own, or with `spread` the run of low cover it belongs to (eight ways joined).
static func _footprint(board: ArenaBoard, cell: Vector2i, spread: bool) -> Rect2i:
	if not spread:
		return Rect2i(cell, Vector2i.ONE)
	var seen := {cell: true}
	var todo: Array[Vector2i] = [cell]
	var lo := cell
	var hi := cell
	while not todo.is_empty() and seen.size() < MAX_SQUARES:
		var c: Vector2i = todo.pop_back()
		for dz: int in [-1, 0, 1]:
			for dx: int in [-1, 0, 1]:
				var n := c + Vector2i(dx, dz)
				if seen.has(n) or not board.grid.in_bounds(n) or not board.grid.has_flag(n, CombatGrid.LOW) \
						or board.grid.has_flag(n, CombatGrid.WALL):
					continue
				seen[n] = true
				todo.append(n)
				lo = Vector2i(mini(lo.x, n.x), mini(lo.y, n.y))
				hi = Vector2i(maxi(hi.x, n.x), maxi(hi.y, n.y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)


## A block faces the middle of the room it stands in, to the nearest quarter turn (so a nave of them face each other).
static func _yaw(board: ArenaBoard, cell: Vector2i) -> float:
	var best := -1
	for i in board.areas.size():
		if board.areas[i].has_point(cell) and (best < 0 or board.areas[i].get_area() < board.areas[best].get_area()):
			best = i
	if best < 0:
		return 0.0
	var mid := Vector2(board.areas[best].position) + Vector2(board.areas[best].size) / 2.0
	var toward := mid - (Vector2(cell) + Vector2(0.5, 0.5))
	if toward.length() < 0.6:
		return 0.0
	return roundf(atan2(toward.x, toward.y) / (PI / 2.0)) * (PI / 2.0)


# --- The cases ---------------------------------------------------------------------------------------------------------

## An upright block on its plinth with a carved lid band: the vestiges' amber, and the dead cracked one.
static func _upright(case: Case, spec: Dictionary, kind: String) -> void:
	var size := spec["size"] as Vector3
	var plinth := spec["plinth"] as Vector3
	var held := shapes().get(case.vestige, {}) as Dictionary   # what it holds, and how its own amber is coloured
	spec = _coloured(spec, held)
	_stone(case, "Plinth", plinth, Vector3(0, plinth.y / 2.0, 0))
	var base := plinth.y - 0.01
	case.body_height = size.y
	_glass(case, _block_mesh(size, 0.08), Vector3(0, base, 0), spec, case)
	_stone(case, "Lid", Vector3(size.x + 0.1, 0.08, size.z + 0.08), Vector3(0, base + size.y + 0.03, 0), "stone_deep")
	if bool(spec.get("light", false)):
		case.add_light(Vector3(0, base + size.y * 0.55, 0), 4.2, 1.4 * float(held.get("glow", 1.0)),
			str(held.get("light", held.get("core", "flame"))))
	if kind == "vestige" and not held.is_empty():
		_hold(case, held, Vector3(0, base + size.y * 0.52, 0))
		case.glow = float(held.get("glow", 1.0))
		case.locked = bool(held.get("locked", false))
	if bool(spec.get("crack", false)):
		_crack(case, size, base)


## The block's own colours (its entry's `core`, `edge`, `cloud`, `cloud_tint`, `alpha`) laid over the case's.
static func _coloured(spec: Dictionary, held: Dictionary) -> Dictionary:
	var out := spec.duplicate()
	for k: String in ["core", "edge", "cloud", "cloud_tint"]:
		if held.has(k):
			out[k] = held[k]
	if held.has("alpha"):
		out["alpha_core"] = held["alpha"]
	return out


## The shape (and the orbiting plane, if it has one) hung dark in the middle of the block, at `at`, with the touch drawn
## on it: a quad turned to the camera, between the far inside of the glass and its near face.
static func _hold(case: Case, held: Dictionary, at: Vector3) -> void:
	var id := case.vestige
	var touch := str(held.get("touch", ""))
	case.soft_base = float(held.get("soft", 1.6))
	for plane: String in ["main", "orbit"]:
		var file := SHAPE_DIR + ("%s.png" % id if plane == "main" else "%s_orbit.png" % id)
		var tex: Texture2D = load(file) as Texture2D if ResourceLoader.exists(file) else null
		if tex == null and not (plane == "main" and touch == "void"):
			continue   # (a vestige with no picture, or none on this plane)
		var qm := QuadMesh.new()
		qm.size = Vector2(0.7, 0.7)
		var mi := MeshInstance3D.new()
		mi.name = "Shape" if plane == "main" else "ShapeOrbit"
		mi.mesh = qm
		mi.position = at
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := ShaderMaterial.new()
		m.shader = SHAPE_SHADER
		m.render_priority = PRIORITY_SHAPE
		if tex != null:
			m.set_shader_parameter("shape", tex)
		m.set_shader_parameter("tint", Look.color(str(held.get("tint", "void"))))
		m.set_shader_parameter("speck_col", Look.color(str(TOUCH_COLOURS.get(touch, "flame"))))
		m.set_shader_parameter("softness", float(held.get("soft", 1.6)))
		m.set_shader_parameter("touch", int(TOUCHES.get(touch, 0)) if plane == "main" else int(TOUCHES["orbit"]))
		m.set_shader_parameter("spin", 0.25 if plane == "orbit" else 0.0)
		m.set_shader_parameter("clock", float(absi(hash(id)) % 997) * 0.37)
		mi.material_override = m
		case.add_child(mi)
		case.shape_materials.append(m)


## A person asleep in amber: a low block lying on the floor.
static func _sleeper(case: Case, spec: Dictionary) -> void:
	var size := spec["size"] as Vector3
	case.body_height = size.y
	_glass(case, _block_mesh(size, 0.08), Vector3(0, 0.0, 0), spec, case)


## The Thirst's empty sarcophagus: lying across all the low cover it covers, higher and longer than any other block,
## on a low stone base, dead and clouded, with the shape of a man hollowed out of its top.
static func _hollow(case: Case, spec: Dictionary, foot: Rect2i) -> void:
	var length := float(foot.size.x if foot.size.x >= foot.size.y else foot.size.y) - 0.1
	var along_z := foot.size.y > foot.size.x
	var plinth_h := float(spec["plinth_height"])
	var height := float(spec["height"])
	var depth := float(spec["depth"])
	var body := Vector3(depth, height, length) if along_z else Vector3(length, height, depth)
	_stone(case, "Plinth", Vector3(body.x + 0.16, plinth_h, body.z + 0.16), Vector3(0, plinth_h / 2.0, 0))
	case.body_height = height
	_glass(case, _block_mesh(body, 0.1), Vector3(0, plinth_h - 0.01, 0), spec, case)
	# The hollow in the top: a man's shape, head and shoulders and long body, darker than the glass, lying along it.
	var top := plinth_h + height
	var dark := Look.cel("void")
	var shape := Node3D.new()
	shape.name = "Hollow"
	shape.position = Vector3(0, top + 0.012, 0)
	if along_z:
		shape.rotation.y = PI / 2.0
	case.add_child(shape)
	var span := length * 0.34
	_flat(shape, CylinderMesh.new(), Vector3(-span * 1.0, 0, 0), dark, Vector3(0.13, 0.012, 0.13), "Head")
	_flat(shape, BoxMesh.new(), Vector3(-span * 0.55, 0, 0), dark, Vector3(0.2, 0.012, 0.42), "Shoulders")
	_flat(shape, BoxMesh.new(), Vector3(span * 0.35, 0, 0), dark, Vector3(span * 1.3, 0.012, 0.24), "Body")


## The empty plinth where a sarcophagus stood: a stone pedestal with a ring of frost round its foot and a few scrape
## marks on the floor leading toward the nearest way out, where something was dragged.
static func _empty_plinth(board: ArenaBoard, case: Case, cell: Vector2i) -> void:
	_stone(case, "Plinth", Vector3(0.96, 0.5, 0.74), Vector3(0, 0.25, 0))
	_stone(case, "Top", Vector3(0.84, 0.06, 0.62), Vector3(0, 0.53, 0), "stone_deep")
	var frost := CylinderMesh.new()
	frost.top_radius = 0.72
	frost.bottom_radius = 0.72
	frost.height = 0.012
	var ring := MeshInstance3D.new()
	ring.name = "Frost"
	ring.mesh = frost
	ring.position = Vector3(0, 0.008, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(Look.color("frost"), 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	case.add_child(ring)
	var way := _nearest_exit(board, cell)
	if way != Vector2.ZERO:
		var dir := way.normalized()
		var scrape := Look.cel("stone_deep")
		for k in 3:
			var side := Vector2(-dir.y, dir.x) * (float(k) - 1.0) * 0.15
			var centre := dir * (1.5 + 0.1 * float(k)) + side
			var line := Node3D.new()
			line.name = "Scrape%d" % k
			line.position = Vector3(centre.x, 0.012, centre.y)
			line.rotation.y = atan2(dir.x, dir.y)
			case.add_child(line)
			_flat(line, BoxMesh.new(), Vector3.ZERO, scrape, Vector3(0.035, 0.012, 1.4 + 0.25 * float(k)), "Mark")


## The cell offset (x, z, squares) from `cell` to the closest way out of this place within a dozen squares, else zero.
static func _nearest_exit(board: ArenaBoard, cell: Vector2i) -> Vector2:
	if board.place == "" or not Compendium.shared().has("locations", board.place):
		return Vector2.ZERO
	var best := Vector2.ZERO
	var best_d := 13.0
	for ex: Variant in (Compendium.shared().get_entry("locations", board.place) as Dictionary).get("exits", []):
		var at := (ex as Dictionary).get("cell", []) as Array
		if at.size() != 2:
			continue
		var d := Vector2(float(at[0]) - cell.x, float(at[1]) - cell.y)
		if d.length() > 0.5 and d.length() < best_d:
			best_d = d.length()
			best = d
	return best


## The Eye's chamber's block of amber the size of a cottage, split open from the inside like an egg: a shell of thick,
## clouded glass over the squares of rubble round the hollow the Eye came out of, its smooth round hollow open toward
## the south. (The squares it spreads over are the '=' squares its prop already has.)
static func _egg(case: Case, spec: Dictionary, foot: Rect2i) -> void:
	var size := spec["size"] as Vector3
	var wide := maxf(size.x, float(foot.size.x) + 0.3)
	var deep := maxf(size.z, float(foot.size.y) + 0.3)
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 48
	sphere.rings = 24
	case.body_height = 1.0
	case.body_base = -0.5
	var holder := Node3D.new()
	holder.name = "Egg"
	holder.position = Vector3(0, size.y * 0.34, 0)
	holder.scale = Vector3(wide, size.y, deep)
	case.add_child(holder)
	case.shell_extra = {"cut_dir": Vector2(0, 1), "cut_open": 0.25, "cut_foot": -0.18}
	_glass(holder, sphere, Vector3.ZERO, spec, case)


## A crack down the middle of the dead block and a few shards of amber at its foot.
static func _crack(case: Case, size: Vector3, base: float) -> void:
	var dark := Look.cel("void")
	_flat(case, BoxMesh.new(), Vector3(0, base + size.y * 0.5, size.z * 0.5 + 0.004), dark, Vector3(0.035, size.y * 0.96, 0.012), "Crack")
	_flat(case, BoxMesh.new(), Vector3(0.09, base + size.y * 0.6, size.z * 0.5 + 0.005), dark, Vector3(0.14, 0.03, 0.012), "Branch")
	_flat(case, BoxMesh.new(), Vector3(-0.1, base + size.y * 0.35, size.z * 0.5 + 0.005), dark, Vector3(0.16, 0.03, 0.012), "Branch")
	var shard := _block_mesh(Vector3(0.14, 0.09, 0.1), 0.02)
	for k in 5:
		var around := float(k) / 5.0 * TAU + 0.4
		var murk := {"dead": 0.5, "cloud": 0.4}
		_glass(case, shard, Vector3(sin(around) * 0.62, 0.0, cos(around) * 0.5), murk, null, Vector3(0.3 * k, around, 0.2 * k))


# --- Parts -------------------------------------------------------------------------------------------------------------

## The block's glass: two passes of the one shader (the far inside, then the near face), on `parent`. A block that is the
## case's (not a shard lying at its foot) is `join`ed to it, so its glow follows the case's light; `turn` turns the mesh
## about its middle.
static func _glass(parent: Node3D, mesh: Mesh, at: Vector3, spec: Dictionary, join: Case, turn: Vector3 = Vector3.ZERO) -> void:
	for pass_id in 2:
		var mi := MeshInstance3D.new()
		mi.name = "Glass" if pass_id == 1 else "GlassInside"
		mi.mesh = mesh
		mi.position = at
		mi.rotation = turn
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := ShaderMaterial.new()
		m.shader = BODY_SHADER if pass_id == 1 else _inside()
		m.render_priority = PRIORITY_OUTSIDE if pass_id == 1 else PRIORITY_INSIDE
		m.set_shader_parameter("core", Look.color(str(spec.get("core", "flame"))))
		m.set_shader_parameter("edge", Look.color(str(spec.get("edge", "ember"))))
		if spec.has("cloud_tint"):
			m.set_shader_parameter("cloud_tint", Look.color(str(spec["cloud_tint"])))
		if spec.has("alpha_core"):
			m.set_shader_parameter("alpha_core", float(spec["alpha_core"]))
		m.set_shader_parameter("dead_tint", Look.color("ember_deep"))
		m.set_shader_parameter("dead", float(spec.get("dead", 0.0)))
		m.set_shader_parameter("cloud", float(spec.get("cloud", 0.15)))
		m.set_shader_parameter("see_through", bool(spec.get("window", false)))   # a tall block opens a window round the party, as a wall does
		mi.material_override = m
		parent.add_child(mi)
		if join != null:
			join.glass.append(m)


## The shader's copy for the far inside of the glass: the same, but drawing the faces seen from inside.
static func _inside() -> Shader:
	if _inside_shader == null:
		_inside_shader = Shader.new()
		_inside_shader.code = BODY_SHADER.code.replace("cull_back", "cull_front")
	return _inside_shader


## A stone part (the plinth, the lid band) in the temple's black stone, or a palette colour where `colour` is named.
static func _stone(parent: Node3D, part: String, size: Vector3, at: Vector3, colour: String = "") -> void:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.name = part
	mi.mesh = bm
	mi.position = at
	var mat: Material = Look.cel_textured(FLOOR_SURFACE) if colour == "" else Look.cel(colour)
	mi.material_override = mat if mat != null else Look.cel("stone_deep")
	parent.add_child(mi)


## A thin flat piece (a mark on the floor, a hollow's shape): `mesh` sized by `size` (a cylinder: radius x, height y).
static func _flat(parent: Node3D, mesh: Mesh, at: Vector3, mat: Material, size: Vector3, part: String) -> void:
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	elif mesh is CylinderMesh:
		(mesh as CylinderMesh).top_radius = size.x
		(mesh as CylinderMesh).bottom_radius = size.x
		(mesh as CylinderMesh).height = size.y
	var mi := MeshInstance3D.new()
	mi.name = part
	mi.mesh = mesh
	mi.position = at
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## A box with its edges cut off by `bevel`, standing on y = 0: four octagonal rings (the foot, the start of the full
## width, the top of it, the top face) joined into faces, flat shaded, the top closed.
static func _block_mesh(size: Vector3, bevel: float) -> ArrayMesh:
	var hx := size.x / 2.0
	var hz := size.z / 2.0
	var b := minf(bevel, minf(hx, hz) * 0.8)
	var cut := b * 1.4
	var rings: Array[PackedVector3Array] = [
		_ring(hx - b, hz - b, cut * 0.6, 0.0), _ring(hx, hz, cut, b), _ring(hx, hz, cut, size.y - b),
		_ring(hx - b, hz - b, cut * 0.6, size.y)]
	var centre := Vector3(0, size.y / 2.0, 0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for r in rings.size() - 1:
		var low := rings[r]
		var high := rings[r + 1]
		for i in low.size():
			var j := (i + 1) % low.size()
			_tri(st, low[i], high[i], high[j], centre)
			_tri(st, low[i], high[j], low[j], centre)
	var top := rings[rings.size() - 1]
	var middle := Vector3(0, size.y, 0)
	for i in top.size():
		_tri(st, middle, top[i], top[(i + 1) % top.size()], centre)
	st.generate_normals()
	return st.commit()


static func _ring(hx: float, hz: float, c: float, y: float) -> PackedVector3Array:
	return PackedVector3Array([Vector3(-hx + c, y, -hz), Vector3(hx - c, y, -hz), Vector3(hx, y, -hz + c),
		Vector3(hx, y, hz - c), Vector3(hx - c, y, hz), Vector3(-hx + c, y, hz), Vector3(-hx, y, hz - c),
		Vector3(-hx, y, -hz + c)])


## One triangle wound clockwise seen from outside (Godot's front face), whichever way round it was given.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, centre: Vector3) -> void:
	var outward := ((a + b + c) / 3.0 - centre)
	if (b - a).cross(c - a).dot(outward) > 0.0:
		var t := b
		b = c
		c = t
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


# --- The node ----------------------------------------------------------------------------------------------------------

## One block of amber: its glass materials, its light and how bright it glows, and the state it is in (AmberGlow.refresh).
## Its glow follows the light inside as that breathes (a block with none glows at `glow` alone); the state eases it to
## brighter (a vestige speaking, the party near), held low and still (its gift taken) or dark (the temple sealed).
class Case extends Node3D:
	var kind := ""
	## The vestige it holds ("zantras"), or "", and the id of the prop it stands as ("sarc_zantras").
	var vestige := ""
	var prop_id := ""
	var body_height := 2.0
	var body_base := 0.0
	## How dead its glass is as built (the hollow, the cracked one), before the temple is sealed.
	var base_dead := 0.0
	## The shader settings only some blocks have (the egg's break), set on every glass material of the case.
	var shell_extra: Dictionary = {}
	var glass: Array[ShaderMaterial] = []
	var shape_materials: Array[ShaderMaterial] = []
	## How soft the shape inside is as built (the entry's `soft`; a state sharpens or blurs it from there).
	var soft_base := 1.6
	## Its light stops breathing (Savnok's amber is locked, like its mouth).
	var locked := false
	var light: CandleFlicker = null
	## How bright the block's own entry asks it to glow, over the light's own breath (1: as it breathes).
	var glow := 1.0
	## The state it is in (AmberGlow.WAITING...), and how near the party stands (0 far, 1 at its foot).
	var state := ""
	var _near := 0.0
	var _near_to := 0.0
	var _fogged := false
	## Where the state's look has eased to: glow and light as a share of their own, deadness, shape strength and softness.
	var _lift := 1.0
	var _dead := 0.0
	var _burn := 1.0
	var _shown := 1.0
	var _soft := 1.0
	var _jump := false
	var _clock := 0.0
	## The energy written to the light last frame, and whether its breath has been set to the state's.
	var _written := 0.0
	var _breath := -1
	var _light_base := 0.0

	## Once the case is built: its materials' own sizes, and its light's breath to follow.
	func finish() -> void:
		for m in glass:
			m.set_shader_parameter("body_base", body_base)
			m.set_shader_parameter("body_height", body_height)
			for k: String in shell_extra:
				m.set_shader_parameter(k, shell_extra[k])
		if light != null:
			_light_base = light.base_energy
			_written = _light_base
		set_process(light != null)

	## The case's own light: shadowless, a slow breath (the `amber` kind, given by Atmosphere), warm.
	func add_light(at: Vector3, reach: float, energy: float, colour: String = "flame") -> void:
		light = CandleFlicker.new()
		light.name = "AmberLight"
		light.light_color = Look.color(colour)
		light.omni_range = reach
		light.base_energy = energy
		light.flicker = 0.0   # (the amber kind's own breath takes over once Atmosphere has dressed it)
		light.position = at
		light.set_meta("amber", true)
		light.set_meta("no_shadow", true)
		add_child(light)

	## Takes the state it is given and how near the party is: eased to, or at once the first time (a sealed temple opens
	## dark; a block never fades in from a state it was not in).
	func set_state(to: String, near: float) -> void:
		_near_to = near
		if to == state:
			set_process(true)
			return
		_jump = _jump or state == ""
		state = to
		_breath = -1   # (set again once its light is dressed)
		set_process(true)

	func _process(delta: float) -> void:
		_clock += delta
		if light != null and is_instance_valid(light) and not _fogged and light.has_meta("light_kind"):
			# Dressed as an amber light now (Atmosphere gives it the kind's haze): a light inside the glass would light
			# the haze it stands in into a white blob, so its own haze is thin.
			light.light_volumetric_fog_energy = AmberGlow.FOG_ENERGY
			_fogged = true
			if locked and LightFlicker.of(light) != null:
				LightFlicker.of(light).queue_free()   # its light holds still at its own energy, as its mouth is sewn
		var look := (AmberGlow.LOOKS.get(state, AmberGlow.LOOKS[AmberGlow.WAITING]) as Dictionary)
		var k := 1.0 if _jump else clampf(delta * float(look["ease"]), 0.0, 1.0)
		_jump = false
		_near = _near_to if is_equal_approx(_near, _near_to) else lerpf(_near, _near_to, clampf(delta * 2.0, 0.0, 1.0))
		# The party's nearness brightens a block that is alive and waiting (not one that has flared, or sated, or gone dark).
		var near_gain := 1.0 + AmberGlow.NEAR_GAIN * _near if state in [AmberGlow.WAITING, AmberGlow.ATTENDING] else 1.0
		_lift = lerpf(_lift, float(look["glow"]) * near_gain, k)
		_burn = lerpf(_burn, float(look["light"]) * near_gain, k)
		_dead = lerpf(_dead, float(look["dead"]), k)
		_shown = lerpf(_shown, float(look["shown"]), k)
		_soft = lerpf(_soft, float(look["soft"]), k)
		var pulse := 1.0 + float(look.get("pulse", 0.0)) * sin(_clock * 5.0)
		var ratio := 1.0
		if light != null and is_instance_valid(light):
			if not locked and _written > 0.001:
				ratio = clampf(light.light_energy / _written, 0.0, 3.0)   # the breath: what the flicker made of the energy it was given
			_written = maxf(_light_base * _burn * pulse, 0.0)
			light.base_energy = _written
			light.visible = _burn > 0.01
			_set_breath(bool(look["breath"]))
		var lit := ratio * glow * _lift * pulse
		var murk := lerpf(base_dead, AmberGlow.SEALED_DEAD, _dead)
		for m in glass:
			m.set_shader_parameter("glow", lit)
			m.set_shader_parameter("dead", murk)
		for m in shape_materials:
			m.set_shader_parameter("shown", _shown)
			m.set_shader_parameter("softness", soft_base * _soft)
		# A block with no light of its own (a sleeper, the egg) is at rest once it has eased there.
		if light == null and absf(_lift - float(look["glow"]) * near_gain) < 0.002 and absf(_dead - float(look["dead"])) < 0.002 \
				and is_equal_approx(_near, _near_to):
			set_process(false)

	## Makes the light breathe (the `amber` kind's swell) or hold still; only once Atmosphere has given it its flicker.
	func _set_breath(on: bool) -> void:
		var want := 1 if on else 0
		if want == _breath or light == null:
			return
		var f := LightFlicker.of(light)
		if f == null:
			return   # (not dressed yet, or held at its energy for good: Savnok's)
		var style := (LightFlicker.STYLES["amber"] as Dictionary).duplicate()
		if not on:
			style["swell"] = 0.0
		f.set_style(style)
		_breath = want
