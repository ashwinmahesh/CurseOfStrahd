class_name BattleScenery
extends RefCounted
## Where a fight's breakable things come from (F5, combat/encounter_objects.gd), and what they leave behind.
## - Any board (the arena, a Skirmish map): each '=' square becomes the piece of furniture, crate, gravestone or
##   boulder the board shows there (data/objects/kinds.json `art`), else the theme's default kind.
## - A location: each closed door is a breakable door (iron or wood by its words), unless it's a secret nobody found or
##   the story keeps it shut; each '=' square is the prop standing there (the story's own props and containers stay as
##   they are) or the board's art; a prop that `hangs` is a chandelier over its squares.
## After a location fight what broke stays broken for the rest of the visit (the location's grid keeps the squares
## open, the board keeps the wreckage), a broken door stays open for good (its door state), and a dropped chandelier's
## trap is sprung or its flag set. The board's art for a prop that hangs is drawn up on its chain here too.


## The arena or a Skirmish map: every '=' square not holding something yet. Done once per fight.
static func from_board(e: Encounter, board: ArenaBoard) -> void:
	if e.objects.placed:
		return
	e.objects.placed = true
	for z in e.grid.depth:
		for x in e.grid.width:
			var cell := Vector2i(x, z)
			if e.grid.has_flag(cell, CombatGrid.LOW) and e.objects.blocking_at(cell) == null:
				_place(e, cell, art_at(board, cell), board.theme)


## A location's fight (LocationFights.start_encounter): its doors, its '=' squares and its chandeliers.
static func for_location(view: LocationView, e: Encounter) -> void:
	e.objects.placed = true
	var table := EncounterObjects.kinds()
	var states := view.st.loc_state(view.loc_id)
	for d: Variant in view.loc.get("doors", []):
		var door := d as Dictionary
		var id := str(door["id"])
		if LocationLocks._door_state(view, id) == LocationView.DOOR_OPEN:
			continue
		var secret := int(door.get("secret_dc", 0)) > 0 and not bool((states["found"] as Dictionary).get(id, false))
		if secret or not StoryConditions.check(str(door.get("when", "")), view.st):
			continue
		var cells: Array[Vector2i] = [LocationView._cell(door["cell"])]
		var extra := {"door_id": id}
		if str(door.get("label", "")) != "":
			extra["name"] = str(door["label"])
		e.objects.add(door_kind(door, table), cells, extra)
	# The things standing on squares: a prop the story uses (one you search, read or pull, one that starts a
	# conversation or holds an item) and every container stay whole.
	var props := {}
	var kept := {}
	for p: Variant in view.loc.get("props", []):
		var prop := p as Dictionary
		var cell := LocationView._cell(prop["cell"])
		if prop.has("hangs") or not StoryConditions.check(str(prop.get("when", "")), view.st):
			continue
		if str(prop["kind"]) in ["book", "search", "lever"] or prop.has("dialogue") or prop.has("item") or prop.has("flag") \
				or prop.has("codex") or prop.has("burning"):
			kept[cell] = true
		else:
			props[cell] = prop
	for ct: Variant in view.loc.get("containers", []):
		kept[LocationView._cell((ct as Dictionary)["cell"])] = true
	var rows := (view.loc["map"] as Dictionary)["rows"] as Array
	for z in rows.size():
		var row := str(rows[z])
		for x in row.length():
			if row[x] != "=":
				continue
			var cell := Vector2i(x, z)
			if not view.grid.has_flag(cell, CombatGrid.LOW):
				# Broken in an earlier fight of this visit: still open (or rubble).
				e.grid.set_flag(cell, CombatGrid.LOW, false)
				e.grid.set_flag(cell, CombatGrid.DIFFICULT, view.grid.has_flag(cell, CombatGrid.DIFFICULT))
				continue
			if kept.has(cell) or e.objects.blocking_at(cell) != null:
				continue
			if props.has(cell):
				var prop2 := props[cell] as Dictionary
				var art := str(SetDressing.look_for(prop2).get("art", ""))
				var kind := kind_for_art(art, table)
				if kind != "":
					var extra2 := {"prop_id": str(prop2["id"]), "art": art}
					if str(prop2.get("label", "")) != "":
						extra2["name"] = str(prop2["label"])
					var one: Array[Vector2i] = [cell]
					e.objects.add(kind, one, extra2)
				continue
			_place(e, cell, art_at(view.board, cell), view.board.theme)
	for p2: Variant in view.loc.get("props", []):
		var hung := p2 as Dictionary
		if not hung.has("hangs") or not StoryConditions.check(str(hung.get("when", "")), view.st) or fallen(view, hung):
			continue
		var spec := hung["hangs"] as Dictionary
		var cells2: Array[Vector2i] = []
		for c: Variant in spec["cells"]:
			cells2.append(LocationView._cell(c))
		var o := e.objects.add(str(spec.get("kind", "chandelier")), cells2, {"name": str(hung.get("label", "the chandelier")), "prop_id": str(hung["id"])})
		o.fall["lit"] = bool(spec.get("lit", false))
		# A chandelier that's also a trap falls as hard as the trap says.
		for t: Variant in view.loc.get("traps", []):
			var trap := t as Dictionary
			if str(trap["id"]) == str(spec.get("trap", "")):
				var sv := trap.get("save", {}) as Dictionary
				if not sv.is_empty():
					o.fall["save"] = str(sv["ability"])
					o.fall["dc"] = int(sv["dc"])
				if str(trap.get("damage", "")) != "":
					o.fall["damage"] = str(trap["damage"])
					o.fall["type"] = str(trap.get("damage_type", "bludgeoning"))


## One '=' square: the kind of the art standing there, else (no art to go by) the board theme's default. Art no kind
## names stays as it is.
static func _place(e: Encounter, cell: Vector2i, art: String, theme: String) -> void:
	var table := EncounterObjects.kinds()
	var kind := kind_for_art(art, table) if art != "" else str((table.get("themes", {}) as Dictionary).get(theme, table.get("default_kind", "crate")))
	if kind != "":
		var one: Array[Vector2i] = [cell]
		e.objects.add(kind, one, {"art": art})


## The kind data/objects/kinds.json gives an art id (a front view counts as its piece), or "".
static func kind_for_art(art: String, table: Dictionary) -> String:
	if art == "":
		return ""
	var base := art.trim_suffix("_front").trim_suffix("_back")
	var kinds := table.get("kinds", {}) as Dictionary
	for id: String in kinds:
		var arts := (kinds[id] as Dictionary).get("art", []) as Array
		if art in arts or base in arts:
			return id
	return ""


## A location door's kind: the first rule with one of its words in the door's id or label, else the default.
static func door_kind(door: Dictionary, table: Dictionary) -> String:
	var doors := table.get("doors", {}) as Dictionary
	var words := ("%s %s" % [str(door.get("id", "")).replace("_", " "), door.get("label", "")]).to_lower()
	for rule: Variant in doors.get("rules", []):
		for w: Variant in (rule as Dictionary)["words"]:
			if words.contains(str(w)):
				return str((rule as Dictionary)["kind"])
	return str(doors.get("default", "door_wood"))


## The art the board shows on `cell` ('=' squares): a piece's own art, else what a plain piece is (a low wall, a
## gravestone, a piece of furniture, rubble), else "".
static func art_at(board: ArenaBoard, cell: Vector2i) -> String:
	if board == null:
		return ""
	for n: Variant in board.dressing.get(cell, []):
		if not is_instance_valid(n):
			continue
		var node := n as Node
		if node.has_meta("art"):
			return str(node.get_meta("art"))
		for plain: String in ["LowWall", "Gravestone", "Plinth", "Furniture", "Rubble"]:
			if str(node.name).contains(plain):
				return plain
		if node is Sprite3D and (node as Sprite3D).texture != null:
			var path := (node as Sprite3D).texture.resource_path
			if path.contains("/props/"):
				return path.get_file().get_basename()
	return ""


## Whether a prop that hangs has already come down: its trap sprung, or its flag set.
static func fallen(view: LocationView, prop: Dictionary) -> bool:
	var spec := prop.get("hangs", {}) as Dictionary
	var trap := str(spec.get("trap", ""))
	if trap != "" and str((view.st.loc_state(view.loc_id)["traps"] as Dictionary).get(trap, "")) == "triggered":
		return true
	return str(spec.get("flag", "")) != "" and bool(view.st.get_flag(str(spec["flag"])))


## LocationBuilder: a prop that hangs is drawn up over its squares on its chain, or lying wrecked on the floor once it
## has fallen.
static func hang(view: LocationView, prop: Dictionary, node: Node3D) -> void:
	if node == null:
		return
	var cells: Array[Vector2i] = []
	for c: Variant in (prop["hangs"] as Dictionary)["cells"]:
		cells.append(LocationView._cell(c))
	var down := fallen(view, prop)
	ObjectView.hang_piece(view.board, node, cells, bool((prop["hangs"] as Dictionary).get("lit", false)) and not down)
	if down:
		ObjectView.drop_piece(view.board, node, false)


## LocationTraps: a trap that is a chandelier sprang outside a fight, so the chandelier drops.
static func trap_sprung(view: LocationView, trap_id: String) -> void:
	for p: Variant in view.loc.get("props", []):
		var prop := p as Dictionary
		if str((prop.get("hangs", {}) as Dictionary).get("trap", "")) == trap_id and view.prop_nodes.has(str(prop["id"])):
			ObjectView.drop_piece(view.board, view.prop_nodes[str(prop["id"])] as Node3D, true)


## After a location fight (LocationFights._end_encounter): a broken door stays open for good; what else broke stays
## broken for the rest of the visit (the location's grid), and a fallen chandelier's trap is sprung or its flag set.
static func after_fight(view: LocationView, e: Encounter) -> void:
	var states := view.st.loc_state(view.loc_id)
	for o in e.objects.list:
		if not o.destroyed or o.holds != "":
			continue
		if o.door_id != "":
			(states["doors"] as Dictionary)[o.door_id] = LocationView.DOOR_OPEN
			for cell in o.cells:
				view.grid.set_flag(cell, CombatGrid.WALL, false)
			if view.door_nodes.has(o.door_id):
				(view.door_nodes[o.door_id] as Node3D).visible = false
		elif o.hangs:
			for p: Variant in view.loc.get("props", []):
				var spec := (p as Dictionary).get("hangs", {}) as Dictionary
				if str((p as Dictionary)["id"]) != o.prop_id:
					continue
				if str(spec.get("trap", "")) != "":
					(states["traps"] as Dictionary)[str(spec["trap"])] = "triggered"
				if str(spec.get("flag", "")) != "":
					view.st.set_flag(str(spec["flag"]))
			for cell in o.cells:
				view.grid.set_flag(cell, CombatGrid.DIFFICULT, true)
		elif o.blocks == CombatGrid.LOW:
			for cell in o.cells:
				view.grid.set_flag(cell, CombatGrid.LOW, false)
				if o.leaves == "rubble":
					view.grid.set_flag(cell, CombatGrid.DIFFICULT, true)
