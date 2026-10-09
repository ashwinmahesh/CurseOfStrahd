class_name PitFall
extends RefCounted
## Pit traps (owner playtest 2026-10-07, docs/ui/travel_map.md "Pits"): a trap with `pit_ft` is a real hole that deep
## (the Death House crypt passage's 10-foot spiked pit). Once found or sprung the board shows it in 3D: the floor
## gone, stone sides going down, stakes at the bottom and the tipping slab that covered it. Whoever springs it makes the
## trap's saving throw: a success catches the edge; a failure falls in, takes 1d6 bludgeoning per 10 ft (2024 falling)
## plus the trap's own damage (a pit whose own damage is bludgeoning, like an oubliette, already counts the fall),
## lands Prone and stays at the bottom until they climb out. With a rope in the party
## the climb needs no check; without one it's a DC 15 Strength (Athletics) check (2024: climbing a sheer surface), a
## minute a try. While someone is down there the party doesn't drag them along, and clicking to walk with them leading
## tries the climb first. An open pit is walked round where there's room, and jumped where it fills a passage; a found
## pit that hasn't opened is walked over like any trap (it springs).

const CLIMB_DC := 15
## How high the walls right beside a shown pit stay (world units), so the camera can see into it.
const WALL_STUB := 0.08
## World units per 10 ft.
const UNITS_PER_10FT := 2.0

static var _mats: Dictionary = {}


static func is_pit(trap: Dictionary) -> bool:
	return int(trap.get("pit_ft", 0)) > 0


static func depth(trap: Dictionary) -> float:
	return int(trap.get("pit_ft", 0)) / 10.0 * UNITS_PER_10FT


## Party members at the bottom of a pit here: character name -> trap id (kept in the location's state, so saved).
static func fallen(view: LocationView) -> Dictionary:
	var ls := view.st.loc_state(view.loc_id)
	if not ls.has("in_pit"):
		ls["in_pit"] = {}
	return ls["in_pit"] as Dictionary


static func holds(view: LocationView, m: Combatant) -> bool:
	return m != null and fallen(view).has(m.name())


static func _trap(view: LocationView, id: String) -> Dictionary:
	for t: Variant in view.loc.get("traps", []):
		if str((t as Dictionary)["id"]) == id:
			return t as Dictionary
	return {}


## A pit the party walks round (or jumps): found, or sprung and open.
static func open_hole(trap: Dictionary, state: String) -> bool:
	return is_pit(trap) and state == "triggered"


# --- Springing and climbing ------------------------------------------------------------------------

## The pit opens under `victim`: the save to catch the edge, else the fall. Replaces the generic trap springing. Set off
## on purpose with nobody on it (`victim` null), it just opens.
static func spring(view: LocationView, trap: Dictionary, victim: Combatant) -> void:
	var id := str(trap["id"])
	(view.st.loc_state(view.loc_id)["traps"] as Dictionary)[id] = "triggered"
	if victim == null:
		if trap.has("flag"):
			view.st.set_flag(str(trap["flag"]))
		_redress(view, trap)
		view.narration.emit("%s tips open with nobody on it." % str(trap.get("label", "The pit")).capitalize())
		return
	var lines: Array[String] = []
	var save := trap.get("save", {}) as Dictionary
	var caught := false
	if not save.is_empty():
		var t := victim.creature.roll_save(view.dice, StringName(str(save["ability"])), int(save["dc"]))
		caught = t.success
		lines.append(t.describe())
		view.big_roll.emit(t, victim.name(), "%s saving throw" % Creature.ABILITY_NAMES.get(StringName(str(save["ability"])), "A"))
	var label := str(trap.get("label", "a pit"))
	if not caught:
		var feet := int(trap["pit_ft"])
		# A pit whose own damage is bludgeoning (an oubliette) already counts the fall; any other (stakes) adds to it.
		var own_fall := str(trap.get("damage_type", "")) == "bludgeoning" and str(trap.get("damage", "")) != ""
		if not own_fall:
			var fall := view.dice.roll_expr("%dd6" % maxi(1, feet / 10), "Falling %d ft" % feet)
			var dr := victim.creature.take_damage(FaerunItems.thimble(victim.creature, int(fall["total"])), &"bludgeoning", false, view.dice, "the fall")
			lines.append(dr.describe(victim.name()))
		if str(trap.get("damage", "")) != "":
			var rolled := view.dice.roll_expr(str(trap["damage"]), "Trap: %s" % label)
			var dr2 := victim.creature.take_damage(FaerunItems.thimble(victim.creature, int(rolled["total"])), StringName(str(trap.get("damage_type", "piercing"))), false, view.dice, label)
			lines.append(dr2.describe(victim.name()))
		victim.creature.add_condition(&"prone", label)
		fallen(view)[victim.name()] = id
		(view.tokens[victim.id] as CombatToken).flash(Look.color("vampire_red"))
	if trap.has("flag"):
		view.st.set_flag(str(trap["flag"]))
	_redress(view, trap)
	_place_fallen(view)
	(view.tokens[victim.id] as CombatToken).refresh()
	view.check_rolled.emit(" · ".join(lines))
	var first := victim.name().get_slice(" ", 0)
	if caught:
		view.call("_say", "trap:%s:caught" % id, victim.creature as Character, "The floor tips away under %s, who catches the edge and hauls back up. The pit below is ten feet deep and full of stakes." % first)
	else:
		view.call("_say", "trap:%s:triggered" % id, victim.creature as Character, str(trap.get("text", "The floor gives way!")))
		view.toast.emit("%s is in the pit. Right-click %s to climb out." % [first, first])


## The menu entries for a party member at the bottom of a pit.
static func actions_for(view: LocationView, m: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not holds(view, m):
		return out
	if view.st.party_has_item("rope"):
		out.append({"id": "climb", "label": "Climb out of the pit (rope)"})
	elif m.creature.hp <= 0:
		out.append({"id": "climb", "label": "Climb out of the pit", "enabled": false, "why": "Down: the party needs a rope to haul them up"})
	else:
		var ch := m.creature as Character
		out.append({"id": "climb", "label": "Climb out of the pit (Athletics %s, DC %d)" % [ch.skill_bonus(&"athletics").signed(), CLIMB_DC]})
	return out


## A climb out for the member standing at `cell`. Returns true if they're out.
static func climb_out(view: LocationView, cell: Vector2i) -> bool:
	var m: Combatant = null
	for mm in view.members:
		if mm.cell == cell and holds(view, mm):
			m = mm
	if m == null:
		return false
	var first := m.name().get_slice(" ", 0)
	view.st.advance_minutes(1)
	if view.st.party_has_item("rope"):
		view.narration.emit("The party drops a rope over the edge, and %s climbs out of the pit." % first)
	else:
		if m.creature.hp <= 0:
			view.toast.emit("%s can't climb while down: the party needs a rope." % first)
			return false
		var ch := m.creature as Character
		var t := ch.roll_check(view.dice, &"athletics", CLIMB_DC, CheckAids.before_check(ch, &"athletics"), [], "%s climbs the pit wall" % first)
		view.check_rolled.emit(t.describe())
		view.big_roll.emit(t, ch.name, "Athletics")
		if not t.success:
			view.narration.emit("%s gets halfway up the slick stone and slides back down. (A rope would help.)" % first)
			return false
		view.narration.emit("%s finds the cracks in the stone and climbs out of the pit." % first)
	var trap := _trap(view, str(fallen(view)[m.name()]))
	fallen(view).erase(m.name())
	m.creature.remove_condition(&"prone", str(trap.get("label", "a pit")))
	var to := _ledge(view, m, trap)
	m.cell = to
	var tok := view.tokens[m.id] as CombatToken
	tok.position = view.board.cell_center(to)
	_place_fallen(view)
	tok.refresh()
	view.call("_save_positions")
	return true


## The nearest free square out of the pit (through the pit's own squares, for a wide pit), else any open one.
static func _ledge(view: LocationView, m: Combatant, trap: Dictionary) -> Vector2i:
	var pit := {}
	for c: Variant in trap.get("cells", []):
		pit[Vector2i(int((c as Array)[0]), int((c as Array)[1]))] = true
	var taken := {}
	for o in view.members:
		if o != m:
			taken[o.cell] = true
	var spare := Vector2i(-1, -1)
	var seen := {m.cell: true}
	var todo: Array[Vector2i] = [m.cell]
	while not todo.is_empty():
		var at: Vector2i = todo.pop_front()
		for dir: Vector2i in CombatGrid.DIRS:
			var c := at + dir
			if seen.has(c) or not view.grid.in_bounds(c) or view.grid.is_solid(c):
				continue
			seen[c] = true
			if pit.has(c):
				todo.append(c)
			elif not taken.has(c):
				return c
			elif spare.x < 0:
				spare = c
	return spare if spare.x >= 0 else m.cell


## On arriving: open pits shown and anyone saved at the bottom of one put back there.
static func restore(view: LocationView) -> void:
	var states := view.st.loc_state(view.loc_id)["traps"] as Dictionary
	for t: Variant in view.loc.get("traps", []):
		var trap := t as Dictionary
		if open_hole(trap, str(states.get(str(trap["id"]), ""))):
			view.call("_show_trap", trap)
	_place_fallen(view)


## Lowers the figure of whoever is at the bottom of a pit (the token, its ring and its labels stay at floor level, so
## the camera following it stays above ground), and raises it again for whoever is out.
static func _place_fallen(view: LocationView) -> void:
	for m in view.members:
		var tok := view.tokens.get(m.id) as CombatToken
		if tok == null:
			continue
		var drop := depth(_trap(view, str(fallen(view)[m.name()]))) if holds(view, m) else 0.0
		var was := float(tok.get_meta("pit_drop", 0.0))
		if is_equal_approx(drop, was):
			continue
		# The figure goes down; the ring, bar, labels and the party's lantern stay at the edge.
		var parts: Array[Node3D] = []
		for c: Variant in [tok.sprite, tok.get("_lying"), tok.get("body")]:
			if c is Node3D and is_instance_valid(c) and not parts.has(c as Node3D):
				parts.append(c as Node3D)   # (body is the sprite itself when the creature has art)
		for c in parts:
			c.position.y -= drop - was
		tok.set_meta("pit_drop", drop)


## Rebuilds a pit's pieces (found, then sprung: the slab swings down).
static func _redress(view: LocationView, trap: Dictionary) -> void:
	var id := str(trap["id"])
	for n: Variant in view.trap_marks.get(id, []):
		if is_instance_valid(n):
			# Out of the tree now, so the old pit gives back the floor and walls it took before the new one takes them.
			if (n as Node).get_parent() != null:
				(n as Node).get_parent().remove_child(n as Node)
			(n as Node).queue_free()
	view.trap_marks.erase(id)
	view.call("_show_trap", trap)


# --- The hole ---------------------------------------------------------------------------------------

static func _mat(key: String) -> Material:
	if not _mats.has(key):
		var m: Material = null
		match key:
			"side":
				m = Look.cel_textured("dungeon/stone_wall")
			"slab":
				m = Look.cel_textured("dungeon/stone_floor")
		if key in ["stake", "rim"]:
			# Drawn unlit, so the hole's edge and its stakes read even in a dark dungeon (like the trap's border).
			var u := StandardMaterial3D.new()
			u.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			u.albedo_color = Look.color("bone" if key == "stake" else "silver")
			m = u
		if m == null:
			m = Look.cel({"side": "stone_deep", "slab": "stone", "bottom": "peat"}.get(key, "stone") as String)
		_mats[key] = m
	return _mats[key] as Material


static func _box(root: Node3D, size: Vector3, pos: Vector3, mat_key: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(mat_key)
	mi.position = pos
	root.add_child(mi)
	return mi


## The pit in 3D on its squares: the board's floor there is hidden (and given back if the pit goes), stone sides go
## down `depth`, stakes stand at the bottom, a dark rim marks the edge, the slab that covered it is tipped (found) or
## hangs down inside (sprung), and the walls around it are cut down so the camera can see in.
static func build(view: LocationView, trap: Dictionary, sprung: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Pit_%s" % trap["id"]
	view.board.add_child(root)
	var d := depth(trap)
	var cells: Array[Vector2i] = []
	for c: Variant in trap["cells"]:
		cells.append(Vector2i(int((c as Array)[0]), int((c as Array)[1])))
	var inside := {}
	for c in cells:
		inside[c] = true
	# The floor boxes on the pit's squares go, and come back if the pit is taken away (disarmed).
	var covered: Array[Node3D] = []
	for n in view.board.get_children():
		if n is MeshInstance3D and (n as MeshInstance3D).mesh is BoxMesh:
			var p := (n as Node3D).position
			var bm := (n as MeshInstance3D).mesh as BoxMesh
			if inside.has(Vector2i(floori(p.x), floori(p.z))) and p.y < 0.0 and bm.size.x > 0.9 and bm.size.z > 0.9 and (n as Node3D).visible:
				(n as Node3D).visible = false
				covered.append(n as Node3D)
	# The cut-away walls within two squares of the pit come down to their footing, so the diagonal camera sees into it
	# even in a one-square passage; they go back up if the pit is taken away.
	var near := {}
	for c in cells:
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var w := c + Vector2i(dx, dz)
				if not inside.has(w) and view.grid.has_flag(w, CombatGrid.WALL):
					near[w] = true
	var lowered: Array[Array] = []   # [node, mesh, position, visible]
	for n in view.board.get_children():
		if not (n is MeshInstance3D) or not ((n as MeshInstance3D).mesh is BoxMesh):
			continue
		var mi := n as MeshInstance3D
		var p := mi.position
		var bm := mi.mesh as BoxMesh
		if not near.has(Vector2i(floori(p.x), floori(p.z))) or bm.size.x < 0.95 or bm.size.z < 0.95 or p.y <= 0.0:
			continue
		lowered.append([mi, mi.mesh, mi.position, mi.visible])
		if bm.size.y > 0.5:
			var stub := bm.duplicate() as BoxMesh
			stub.size.y = WALL_STUB
			mi.mesh = stub
			mi.position.y = WALL_STUB / 2.0
		else:
			mi.visible = false   # the wall's dark cap goes with it
	root.tree_exiting.connect(func() -> void:
		for n in covered:
			if is_instance_valid(n):
				n.visible = true
		for l in lowered:
			if is_instance_valid(l[0]):
				(l[0] as MeshInstance3D).mesh = l[1] as Mesh
				(l[0] as MeshInstance3D).position = l[2] as Vector3
				(l[0] as MeshInstance3D).visible = bool(l[3]))
	var wall := 0.08
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(trap["id"]))   # cosmetic only: where the stakes stand
	for c in cells:
		var top := view.board.floor_y(c)
		var mid := Vector3(c.x + 0.5, top - d / 2.0, c.y + 0.5)
		for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if inside.has(c + dir):
				continue
			var off := Vector3(dir.x, 0, dir.y) * (0.5 - wall / 2.0)
			var size := Vector3(wall if dir.x != 0 else 1.0, d, wall if dir.y != 0 else 1.0)
			_box(root, size, mid + off, "side")
			# A pale lip at floor level, so the edge of the hole reads from above.
			_box(root, Vector3(size.x + 0.02, 0.03, size.z + 0.02), Vector3(mid.x, top + 0.015, mid.z) + off, "rim").cast_shadow = \
				GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_box(root, Vector3(1.0, 0.1, 1.0), Vector3(c.x + 0.5, top - d - 0.05, c.y + 0.5), "bottom")
		# Stakes only where the trap's own damage says so (piercing); an oubliette is a bare shaft.
		for i in (9 if str(trap.get("damage_type", "")) == "piercing" else 0):
			var stake := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = 0.05
			cm.height = rng.randf_range(0.45, 0.8)
			stake.mesh = cm
			stake.material_override = _mat("stake")
			stake.position = Vector3(c.x + rng.randf_range(0.15, 0.85), top - d + cm.height / 2.0, c.y + rng.randf_range(0.15, 0.85))
			stake.rotation = Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.2, 0.2))
			root.add_child(stake)
	# The tipping slab, hinged on the first square's north edge.
	var c0 := cells[0]
	var hinge := Node3D.new()
	hinge.position = Vector3(c0.x + 0.5, view.board.floor_y(c0), c0.y + 0.04)
	hinge.rotation = Vector3(deg_to_rad(80.0 if sprung else -28.0), 0, 0)   # propped up, or hanging down inside
	root.add_child(hinge)
	var slab := _box(hinge, Vector3(0.9, 0.09, 0.9), Vector3(0, -0.045, 0.45), "slab")
	slab.name = "Slab"
	return root
