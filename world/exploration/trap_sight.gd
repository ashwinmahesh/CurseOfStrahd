class_name TrapSight
extends RefCounted
## Traps the party has noticed, and how it notices them (owner ask 2026-10-06, docs/ui/travel_map.md "Traps").
## A noticed trap shows its own piece (a wolf trap, rotten boards, a tripwire ...; art/sprites/props) with a red dashed
## border round its squares that never covers it. Every living party member's passive Perception is checked against
## every trap square they can see, on arriving and after every step (2024: meeting the DC is enough). A trap above
## everyone's passive Perception stays hidden until a Search (a Wisdom (Perception) check) or magic finds it.

## The piece a trap shows, by a word in its id or label; a trap's `model` names one directly. First match wins.
const LOOKS: Array[Array] = [
	[["wolf_trap", "jaw"], "wolf_trap"],
	[["tripwire"], "tripwire"],
	[["pit"], "spiked_pit"],
	[["floorboard", "boards", "weak_floor", "hatch"], "broken_boards"],
	[["glyph", "ward"], "floor_glyphs"],
	[["ice"], "ice_patch"],
	[["snow", "cornice"], "snowdrift"],
	[["crack", "vent"], "floor_crack"],
	[["soot"], "soot_patch"],
	[["blade"], "blade_slits"],
]
## The border: dashes this long with these gaps, this wide, inset this far from the squares' edges (world units).
const DASH := 0.26
const GAP := 0.14
const LINE := 0.06
const INSET := 0.05

static var _line_mat: StandardMaterial3D
static var _xray: ShaderMaterial
const XRAY_SHADER := preload("res://shaders/world/xray_mark.gdshader")


## Red hatching drawn only where a wall in front hides the mark (a trap in a one-square passage).
static func xray() -> ShaderMaterial:
	if _xray == null:
		_xray = ShaderMaterial.new()
		_xray.shader = XRAY_SHADER
		_xray.set_shader_parameter("tint", Look.color("vampire_red"))
		_xray.render_priority = 2
	return _xray


## The prop art a trap shows, or "" for a border alone (a statue's gaze, a chandelier overhead).
static func look_for(trap: Dictionary) -> String:
	var model := str(trap.get("model", ""))
	if model != "":
		return model if SetDressing.has_art(model) else ""
	var words := (str(trap["id"]) + " " + str(trap.get("label", ""))).to_lower()
	for l: Array in LOOKS:
		for w: String in l[0]:
			if words.contains(w):
				return str(l[1]) if SetDressing.has_art(str(l[1])) else ""
	return ""


## Can this party member see any of these squares? (Walls and closed doors, secret ones included, block the view.)
static func in_sight(view: LocationView, m: Combatant, cells: Array[Vector2i]) -> bool:
	for c in cells:
		if view.grid.can_see(m.cell, 1, c, 1):
			return true
	return false


## Passive Perception against one unnoticed trap: the first living member who can see it and whose passive
## Perception meets its DC notices it (it's marked found, shown and its line said). True if someone did.
static func notice(view: LocationView, trap: Dictionary) -> bool:
	var cells: Array[Vector2i] = []
	for c: Variant in trap["cells"]:
		cells.append(Vector2i(int((c as Array)[0]), int((c as Array)[1])))
	# Fog, a storm or a blizzard in the open (Weather, F12): Disadvantage on sight, so -5 to passive Perception.
	var murk := -5 if not Weather.sight_penalty(view.st, view.loc_id).is_empty() else 0
	for m in view.members:
		if m.creature.hp <= 0:
			continue
		var passive := m.creature.passive_score(&"perception").total() + murk
		if passive >= int(trap["detect_dc"]) and in_sight(view, m, cells):
			var id := str(trap["id"])
			(view.st.loc_state(view.loc_id)["traps"] as Dictionary)[id] = "found"
			view.call("_show_trap", trap)
			if trap.has("flag"):
				view.st.set_flag(str(trap["flag"]))
			view.call("_say", "trap:%s:found" % id, m.creature as Character, "%s spots something: %s (passive Perception %d)." % [
				m.name().get_slice(" ", 0), str(trap.get("label", "a trap")), passive])
			return true
	return false


## On arriving: open pits put back (and anyone in them), then every trap the party can already see and whose DC its
## passive Perception meets.
static func notice_all(view: LocationView) -> void:
	if view == null or not is_instance_valid(view) or view.in_combat:
		return
	PitFall.restore(view)
	var states := view.st.loc_state(view.loc_id)["traps"] as Dictionary
	for t: Variant in view.loc.get("traps", []):
		var trap := t as Dictionary
		if str(states.get(str(trap["id"]), "")) == "" and StoryConditions.check(str(trap.get("when", "")), view.st):
			notice(view, trap)


## What a noticed trap shows: its piece on each square (unless something already stands there) and the border.
## Freeing the returned nodes takes it all away (a disarmed trap).
static func dress(view: LocationView, trap: Dictionary) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var cells: Array[Vector2i] = []
	for c: Variant in trap["cells"]:
		cells.append(Vector2i(int((c as Array)[0]), int((c as Array)[1])))
	var taken := {}
	for key: String in ["props", "containers"]:
		for e: Variant in view.loc.get(key, []):
			var a := (e as Dictionary)["cell"] as Array
			taken[Vector2i(int(a[0]), int(a[1]))] = true
	var art := look_for(trap)
	if PitFall.is_pit(trap):
		# A real hole in 3D, its cover tipped (found) or swung down (sprung).
		var state := str((view.st.loc_state(view.loc_id)["traps"] as Dictionary).get(str(trap["id"]), ""))
		out.append(PitFall.build(view, trap, state == "triggered"))
		art = ""
	if art != "":
		for i in cells.size():
			if taken.has(cells[i]):
				continue
			var piece := SetDressing.place(view.board, {"id": "trap_%s_%d" % [trap["id"], i], "cell": [cells[i].x, cells[i].y], "model": art})
			if piece != null:
				out.append(piece)
	# A pit's border runs just outside its pale lip; any other trap's just inside its squares.
	out.append(_border(view, cells, -0.07 if PitFall.is_pit(trap) else INSET))
	return out


## A red dashed line round the outside of the trap's squares, just off the ground.
static func _border(view: LocationView, cells: Array[Vector2i], inset: float = INSET) -> Node3D:
	if _line_mat == null:
		_line_mat = StandardMaterial3D.new()
		_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_line_mat.albedo_color = Look.color("vampire_red")
		_line_mat.next_pass = xray()   # the dashes show through a wall in front, hatched
	var root := Node3D.new()
	root.name = "TrapBorder"
	view.board.add_child(root)
	var inside := {}
	for c in cells:
		inside[c] = true
	for c in cells:
		var y := view.board.floor_y(c) + 0.035
		for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if inside.has(c + dir):
				continue
			# The edge on that side, inset so the line sits just inside the square.
			var mid := Vector2(c) + Vector2(0.5, 0.5) + Vector2(dir) * (0.5 - inset)
			var along := Vector2(dir).orthogonal()
			var length := 1.0 - inset * 2.0
			var t := -length / 2.0
			while t < length / 2.0 - 0.01:
				var d := minf(DASH, length / 2.0 - t)
				var at := mid + along * (t + d / 2.0)
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(d if along.x != 0.0 else LINE, 0.012, d if along.y != 0.0 else LINE)
				mi.mesh = bm
				mi.material_override = _line_mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.position = Vector3(at.x, y, at.y)
				root.add_child(mi)
				t += d + GAP
	return root
