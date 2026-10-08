class_name ObjectView
extends Node3D
## Draws what happens to the fight's breakable things (combat/encounter_objects.gd): an object keeps the board's
## dressing on its squares (the board's own piece, a location prop or door) until it breaks, when that art hides and
## wreckage lies there instead (left on the board: it stays for the rest of the visit); a burning object has a flame
## and its light; oil on the floor is a dark slick, and burning oil or webbing burns; a spider's web wraps the
## creature it holds; a chandelier hangs on its chain over its squares and drops when the chain breaks; a location
## door's leaf shows while it's shut; a shoved thing's art slides (or drops) to its new square, and carries the move
## with it (meta `moved_cell`, for the rest of the visit: BattleScenery); a pushed-over thing tips and lies across the
## squares it fell on; a barrel of lamp oil goes up in a fireball. It only shows state (`sync`), and plays the encounter's
## object events (`play`: a blow landing, the damage, a break, a fall, a door, a shove, a topple, a burst).

const FLOAT_TIME := 1.1
## A chandelier hangs this high over the floor.
const HANG_Y := 2.25

var board: ArenaBoard
var _broken: Dictionary = {}     ## object id -> true once its break is shown
var _flames: Dictionary = {}     ## object id or square key -> Node3D
var _webs: Dictionary = {}       ## object id -> Node3D (its squares in meta "cells")
var _hung: Dictionary = {}       ## object id -> the chandelier drawn here (no location prop draws it)
var _moved_to: Dictionary = {}   ## object id -> the square its art stands on, once a shove has moved it
var _rng := RandomNumberGenerator.new()


static func create(board_: ArenaBoard) -> ObjectView:
	var v := ObjectView.new()
	v.name = "ObjectView"
	v.board = board_
	v._rng.seed = 11   # cosmetic only (where wreckage lies)
	return v


## Matches what's drawn to the encounter's objects and squares on fire.
func sync(objects: EncounterObjects) -> void:
	for o in objects.list:
		# Shoved since the board was built (a fight resumed from a save): its art goes where it is now.
		if o.home.x >= 0 and o.cells.size() == 1 and (_moved_to.get(o.id, o.home) as Vector2i) != o.cells[0]:
			_slide_now(o, _moved_to.get(o.id, o.home) as Vector2i, o.cells[0])
		if o.door_id != "" and not o.destroyed:
			var leaf := board.get_node_or_null("Door_" + o.door_id) as Node3D
			if leaf != null:
				leaf.visible = not o.open
		if o.destroyed:
			if not _broken.has(o.id):
				_show_broken(o, objects, false)
			_drop(_flames, o.id)
			_drop(_webs, o.id)
			continue
		if o.hangs and not _hung.has(o.id) and _prop_piece(o) == null:
			_hung[o.id] = _make_chandelier(objects.cells_of(o), bool(o.fall.get("lit", false)))
		if o.burning and not _flames.has(o.id):
			_flames[o.id] = _flame(objects.cells_of(o))
		elif not o.burning:
			_drop(_flames, o.id)
		if o.holds != "":
			var cells := objects.cells_of(o)
			var web: Variant = _webs.get(o.id)
			if web != null and is_instance_valid(web) and (web as Node).get_meta("cells") == cells:
				continue
			_drop(_webs, o.id)
			_webs[o.id] = _web(cells)
	var live := {}
	for sq in objects.squares:
		var key := EncounterObjects.square_key(sq["cell"] as Vector2i)
		live[key] = true
		var lit := bool(sq.get("lit", false))
		var shown: Variant = _flames.get(key)
		if shown != null and is_instance_valid(shown) and bool((shown as Node).get_meta("lit", false)) == lit:
			continue
		_drop(_flames, key)
		_flames[key] = _square(sq["cell"] as Vector2i, lit)
	for key: String in _flames.keys():
		if key.begins_with("square:") and not live.has(key):
			_drop(_flames, key)


func _drop(d: Dictionary, key: String) -> void:
	var n: Variant = d.get(key)
	if n != null and is_instance_valid(n):
		(n as Node).queue_free()
	d.erase(key)


## Plays one object event (with the fight's SpellFx, for a spell's or a shot's missile); awaits it.
func play(ev: Dictionary, objects: EncounterObjects, tokens: Dictionary, fx: SpellFx) -> void:
	var o := objects.get_object(str(ev.get("id", "")))
	match str(ev["type"]):
		"object_attack", "object_throw":
			var by := tokens.get(str(ev.get("by", ""))) as CombatToken
			var at := _spot(o, objects) if o != null else board.cell_center(ev.get("cell", Vector2i.ZERO) as Vector2i)
			if by != null and is_instance_valid(by):
				var dir := at - by.position
				var action := str(ev.get("action", ""))
				var cue := {}
				if SpellFx.enabled and fx != null:
					cue = SpellFx.spell_cue(action.substr(6)) if action.begins_with("spell:") else SpellFx.attack_cue(by.combatant, action)
				if by.start_attack(Vector2(dir.x, dir.z)):
					await by.wait_for_strike()
				else:
					by.face(Vector2(dir.x, dir.z), false)
				# A bolt, a ray, an arrow flies to it.
				if not cue.is_empty() and str(cue["family"]) in SpellFx.MISSILES and str(cue["family"]) != "touch":
					await FxMissiles.fly(fx, str(cue["family"]), cue, SpellFx.hand(by, at + Vector3(0, 0.4, 0)), at + Vector3(0, 0.4, 0), bool(ev.get("hit", true)))
			if str(ev["type"]) == "object_attack" and not bool(ev.get("hit", false)):
				_float(at, "Miss", "parchment")
			elif bool(ev.get("critical", false)):
				_float(at + Vector3(0, 0.35, 0), "Critical!", "candle")
		"object_damage":
			if o != null:
				_float(_spot(o, objects) + Vector3(0, -0.3, 0), "-%d" % int(ev.get("amount", 0)), "rose")
		"object_broken", "object_fall":
			if o != null and not _broken.has(o.id):
				_show_broken(o, objects, true)
				await get_tree().create_timer(0.35).timeout
		"object_door":
			if o != null and o.door_id != "":
				var leaf := board.get_node_or_null("Door_" + o.door_id) as Node3D
				if leaf != null:
					leaf.visible = not bool(ev.get("open", false))
				Audio.sfx("door")
		"object_move":
			if o != null:
				await _slide(o, ev["from"] as Vector2i, ev["to"] as Vector2i)
		"object_topple":
			if o != null and not _broken.has(o.id):
				await _tip(o, ev)
				_show_broken(o, objects, true)
		"object_burst":
			if o != null:
				_burst(o, fx)
				if not _broken.has(o.id):
					_show_broken(o, objects, true)
				await get_tree().create_timer(0.5).timeout


## Where `o` is for a missile or a number: up on its chain while a chandelier still hangs, else on its squares.
func _spot(o: BattleObject, objects: EncounterObjects) -> Vector3:
	var at := _centre(objects.cells_of(o))
	if o.hangs and not _broken.has(o.id):
		at.y += HANG_Y
	return at


func _centre(cells: Array[Vector2i]) -> Vector3:
	if cells.is_empty():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	for c in cells:
		sum += board.cell_center(c)
	return sum / float(cells.size())


# --- Breaking ----------------------------------------------------------------------------------------

## What `o` looked like goes (the board's piece, the location's prop or door) and its wreckage stays; a chandelier
## drops. `animate`: as it happens (a fight resumed from a save shows it broken at once).
func _show_broken(o: BattleObject, objects: EncounterObjects, animate: bool) -> void:
	_broken[o.id] = true
	if o.hangs:
		var piece := _prop_piece(o)
		if piece == null:
			piece = _hung.get(o.id) as Node3D
		if piece != null:
			ObjectView.drop_piece(board, piece, animate)
		return
	if o.holds != "":
		return
	if o.door_id != "":
		var door := board.get_node_or_null("Door_" + o.door_id) as Node3D
		if door != null:
			door.visible = false
	var prop := _prop_piece(o)
	if prop != null:
		prop.visible = false
	for cell in o.cells:
		for n: Variant in board.dressing.get(cell, []):
			if is_instance_valid(n) and n is Node3D:
				(n as Node3D).visible = false
	for cell2 in (o.wreck if not o.wreck.is_empty() else o.cells):
		if board.grid.in_bounds(cell2) and not board.grid.has_flag(cell2, CombatGrid.VOID):
			_wreckage(cell2, o.substance, animate)


## Broken bits on a square, in the colours of what it was made of, flat on the floor (no shadows).
func _wreckage(cell: Vector2i, substance: String, animate: bool) -> void:
	var colours := {"wood": ["walnut", "umber", "leather"], "stone": ["stone", "slate", "stone_deep"], "iron": ["pewter", "slate", "rust"],
		"steel": ["pewter", "silver", "slate"], "cloth": ["bone", "tan", "parchment"], "rope": ["tan", "umber", "bone"],
		"glass": ["silver", "mist_blue", "pewter"], "crystal": ["silver", "mist_blue", "lilac"]}.get(substance, ["umber", "stone", "slate"]) as Array
	var y := board.floor_y(cell)
	for i in 6:
		var size := Vector3(_rng.randf_range(0.12, 0.3), _rng.randf_range(0.05, 0.14), _rng.randf_range(0.08, 0.22))
		var at := Vector3(cell.x + _rng.randf_range(0.15, 0.85), y + size.y / 2.0, cell.y + _rng.randf_range(0.15, 0.85))
		# A name of its own: a second "Wreckage" beside the first would be renamed to an unreadable one.
		var bit := board.add_box("Wreckage_%d_%d_%d" % [cell.x, cell.y, i], size, at, Look.cel(str(colours[i % colours.size()])))
		bit.rotation.y = _rng.randf_range(0.0, TAU)
		bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if animate:
			bit.scale = Vector3(0.1, 0.1, 0.1)
			bit.create_tween().tween_property(bit, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK)


## The art standing for `o` on `cell`: the board's pieces there and the location prop that dresses it.
func _art(o: BattleObject, cell: Vector2i) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n: Variant in board.dressing.get(cell, []):
		if is_instance_valid(n) and n is Node3D:
			out.append(n as Node3D)
	var prop := _prop_piece(o)
	if prop != null and not prop in out:
		out.append(prop)
	return out


## A shove: the art slides to the new square (and drops to a lower floor), or over the edge and out of sight.
func _slide(o: BattleObject, from: Vector2i, to: Vector2i) -> void:
	var nodes := _art(o, from)
	var shift := Vector3(to.x - from.x, 0, to.y - from.y)
	var drop := _drop_to(from, to)
	_drop(_flames, o.id)
	var tw: Tween = null
	for n in nodes:
		if not n.is_inside_tree():
			n.position += shift + Vector3(0, drop, 0)
			continue
		if tw == null:
			tw = n.create_tween().set_parallel(true)
		tw.tween_property(n, "position", n.position + shift, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if absf(drop) > 0.01:
			tw.tween_property(n, "position:y", n.position.y + drop, 0.3).set_delay(0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_moved(o, from, to, nodes)
	if tw != null:
		await tw.finished
	if _gone(to):
		for n2 in nodes:
			n2.visible = false


## A shove the board hasn't shown (a fight resumed from a save): the art is put where the thing is now, at once.
func _slide_now(o: BattleObject, from: Vector2i, to: Vector2i) -> void:
	var nodes := _art(o, from)
	var shift := Vector3(to.x - from.x, _drop_to(from, to), to.y - from.y)
	for n in nodes:
		n.position += shift
		n.visible = n.visible and not _gone(to)
	_drop(_flames, o.id)
	_moved(o, from, to, nodes)


## Over the map's open drop or into deep water: out of sight.
func _gone(cell: Vector2i) -> bool:
	return not board.grid.in_bounds(cell) or board.grid.has_flag(cell, CombatGrid.VOID)


func _drop_to(from: Vector2i, to: Vector2i) -> float:
	return -4.0 if _gone(to) else board.floor_y(to) - board.floor_y(from)


## The board's record of a shove: the pieces belong to the new square, and each carries where it went (and as what) for
## the rest of the visit (BattleScenery); gone over the edge, it carries nothing.
func _moved(o: BattleObject, from: Vector2i, to: Vector2i, nodes: Array[Node3D]) -> void:
	_moved_to[o.id] = to
	for n in nodes:
		if _gone(to):
			n.remove_meta("moved_cell")
			continue
		n.set_meta("moved_cell", to)
		n.set_meta("moved_kind", o.kind)
		n.set_meta("moved_art", o.art)
		n.set_meta("moved_prop", o.prop_id)
	var pieces: Array = board.dressing.get(from, [])
	if not pieces.is_empty():
		board.dressing.erase(from)
		if not _gone(to):
			board.dressing[to] = pieces


## Pushed over: the art tips away from the pusher, toward the squares it falls across, and goes (its wreckage follows).
func _tip(o: BattleObject, ev: Dictionary) -> void:
	var line := ev.get("cells", []) as Array
	var nodes := _art(o, o.cells[0])
	if line.is_empty() or nodes.is_empty():
		return
	var d := (line[0] as Vector2i) - o.cells[0]
	var axis := Vector3(d.y, 0, -d.x).normalized()
	var tw: Tween = null
	for n in nodes:
		var start := n.transform.basis
		if tw == null:
			tw = n.create_tween().set_parallel(true)
		tw.tween_method(func(a: float) -> void: n.transform.basis = start.rotated(axis, a), 0.0, PI * 0.45, 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished


## A barrel of lamp oil goes up: the fireball's explosion over its burst (SpellFx), else a flash of light.
func _burst(o: BattleObject, fx: SpellFx) -> void:
	var at := _centre(o.cells)
	var radius := float(o.bursts.get("radius", 10)) / 5.0
	if SpellFx.enabled and fx != null:
		var cue := SpellFx.spell_cue("fireball")
		if not cue.is_empty():
			FxAreas.explode(fx, cue, at + Vector3(0, 0.6, 0), board.floor_y(o.cells[0]), radius)
			return
	var light := OmniLight3D.new()
	light.light_color = Look.color("flame")
	light.light_energy = 6.0
	light.omni_range = radius * 2.5
	light.position = at + Vector3(0, 1.0, 0)
	add_child(light)
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.6)
	tw.tween_callback(light.queue_free)


## The location prop that dresses `o` (SetDressing.place names it Dressing_<id>), or null.
func _prop_piece(o: BattleObject) -> Node3D:
	if o.prop_id == "" or board == null:
		return null
	return board.get_node_or_null("Dressing_" + o.prop_id) as Node3D


# --- Chandeliers ---------------------------------------------------------------------------------------

## A location prop's node made a chandelier hanging over `cells` (its own art hidden: an iron ring of candles on a chain
## draws it), the node's child "Chandelier".
static func hang_piece(board_: ArenaBoard, node: Node3D, cells: Array[Vector2i], lit: bool) -> void:
	for ch in node.get_children():
		if ch is Node3D:
			(ch as Node3D).visible = false
	var piece := _chandelier(board_, cells, lit)
	piece.name = "Chandelier"
	node.add_child(piece)


func _make_chandelier(cells: Array[Vector2i], lit: bool) -> Node3D:
	var piece := _chandelier(board, cells, lit)
	add_child(piece)
	return piece


static func _chandelier(board_: ArenaBoard, cells: Array[Vector2i], lit: bool) -> Node3D:
	var root := Node3D.new()
	var mid := Vector3.ZERO
	var floor_y := 0.0
	for c in cells:
		mid += board_.cell_center(c)
		floor_y = maxf(floor_y, board_.floor_y(c))
	mid /= maxf(1.0, float(cells.size()))
	root.position = Vector3(mid.x, floor_y + HANG_Y, mid.z)
	var iron := Look.cel("pewter")
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.5
	_part(root, ring, Vector3.ZERO, iron)
	for a in 2:
		var bar := BoxMesh.new()
		bar.size = Vector3(0.9, 0.03, 0.03)
		_part(root, bar, Vector3.ZERO, iron).rotation.y = PI / 2.0 * a
	var chain := CylinderMesh.new()
	chain.top_radius = 0.02
	chain.bottom_radius = 0.02
	chain.height = 2.4
	_part(root, chain, Vector3(0, 1.2, 0), iron).name = "Chain"
	var wax := Look.cel("vellum")
	var flame := StandardMaterial3D.new()
	flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.albedo_color = Look.color("candle")
	flame.emission_enabled = true
	flame.emission = Look.color("candle")
	for i in 6:
		var ang := TAU * i / 6.0
		var at := Vector3(cos(ang) * 0.46, 0.08, sin(ang) * 0.46)
		var candle := CylinderMesh.new()
		candle.top_radius = 0.035
		candle.bottom_radius = 0.035
		candle.height = 0.16
		_part(root, candle, at, wax)
		if lit:
			var tip := SphereMesh.new()
			tip.radius = 0.035
			tip.height = 0.09
			_part(root, tip, at + Vector3(0, 0.12, 0), flame).set_meta("flame", true)
	if lit:
		var light := CandleFlicker.new()
		light.light_color = Look.color("candle")
		light.base_energy = 0.9
		light.flicker = 0.25
		light.omni_range = 4.0
		light.shadow_enabled = false
		light.set_meta("flame", true)
		root.add_child(light)
	return root


static func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## A chandelier comes down: it drops to the floor, tips over and its candles go out (`animate`), or lies there already.
static func drop_piece(_board: ArenaBoard, node: Node3D, animate: bool) -> void:
	var piece := node.get_node_or_null("Chandelier") as Node3D
	if piece == null:
		piece = node
	var low := piece.position.y - HANG_Y + 0.06
	for ch in piece.find_children("*", "", true, false):
		if ch.has_meta("flame") or str(ch.name) == "Chain":
			(ch as Node3D).visible = false
	if not animate or not piece.is_inside_tree():
		piece.position.y = low
		piece.rotation.z = 0.35
		return
	var tw := piece.create_tween()
	tw.tween_property(piece, "position:y", low, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(piece, "rotation:z", 0.35, 0.12)


# --- Fire, oil and webs --------------------------------------------------------------------------------

## A burning object's flame (the flame art where it exists, else a few glowing cones) and its flickering light.
func _flame(cells: Array[Vector2i]) -> Node3D:
	var root := Node3D.new()
	root.name = "Burning"
	add_child(root)
	for c in cells:
		var spot := board.cell_center(c) + Vector3(0, ArenaBoard.LOW_H if board.grid.has_flag(c, CombatGrid.LOW) else 0.1, 0)
		var art := SetDressing.flame(0.9)
		if art != null:
			art.position = spot
			root.add_child(art)
		else:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.3
			cone.height = 0.7
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Look.color("flame")
			m.emission_enabled = true
			m.emission = Look.color("flame")
			_part(root, cone, spot + Vector3(0, 0.35, 0), m)
	var light := CandleFlicker.new()
	light.light_color = Look.color("flame")
	light.base_energy = 1.6
	light.flicker = 0.4
	light.omni_range = 5.0
	light.shadow_enabled = false
	light.position = _centre(cells) + Vector3(0, 1.0, 0)
	root.add_child(light)
	return root


## Oil on a square: a dark slick, or (lit) flames on the floor.
func _square(cell: Vector2i, lit: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Fire" if lit else "Oil"
	root.set_meta("lit", lit)
	add_child(root)
	var cells: Array = [cell]
	if SpellFx.enabled:
		if lit:
			FxZones.flames(root, cells, board, SpellFx.colours("fire"))
		else:
			FxZones.slick(root, cells, board, SpellFx.colours("earth"), 0.0)
		return root
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.9, 0.9)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(Look.color("flame" if lit else "peat"), 0.55)
	_part(root, pm, board.cell_center(cell) + Vector3(0, 0.02, 0), m)
	return root


## A giant spider's webbing round the creature it holds.
func _web(cells: Array[Vector2i]) -> Node3D:
	var root := Node3D.new()
	root.name = "Web"
	root.set_meta("cells", cells.duplicate())
	add_child(root)
	if SpellFx.enabled:
		FxZones.growth(root, cells, board, SpellFx.colour_names("ward"), "web", 1.0)
		return root
	for c in cells:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.32
		ring.outer_radius = 0.36
		_part(root, ring, board.cell_center(c) + Vector3(0, 0.6, 0), Look.cel("bone"))
	return root


## A number or word rising over a spot and fading.
func _float(at: Vector3, text: String, colour: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 52
	l.outline_size = 10
	l.pixel_size = 0.006
	l.modulate = Look.color(colour)
	l.position = at + Vector3(0, 1.0, 0)
	add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 0.7, FLOAT_TIME)
	tw.tween_property(l, "modulate:a", 0.0, FLOAT_TIME).set_delay(FLOAT_TIME * 0.4)
	tw.chain().tween_callback(l.queue_free)
