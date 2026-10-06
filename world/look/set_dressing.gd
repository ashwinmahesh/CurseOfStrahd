class_name SetDressing
extends RefCounted
## The art that dresses a location's things (docs/art/set_dressing.md): its props, containers and doors, from the
## billboard sprites in art/sprites/props (manifest.json) picked by catalog.json. Three ways a piece is shown:
##   stand  a billboard on its square that turns to face the camera (furniture, chests, signposts, trees)
##   wall   flat on the face of a wall, looking into the room (paintings, fireplaces, windows)
##   floor  flat on the ground (rugs, stairwells, rubble)
## Something standing on a wall square (a signpost among the trees, a well in a dungeon wall) takes that square's
## place: the board hides its tree or wall block while the prop is there. Doors get a frame in the wall line and a
## leaf the size of the opening. Only looks: the rules never read any of this.

const CATALOG_JSON := "res://art/sprites/props/catalog.json"
const MANIFEST_JSON := "res://art/sprites/props/manifest.json"
## How far a wall piece sits in front of the wall face, and the widest it may be on one square's face.
const WALL_GAP := 0.012
const WALL_FACE := 0.96
## A door leaf fills this much of its square's width.
const DOOR_WIDTH := 0.86
## Interior walls are cut away at this height (ArenaBoard._wall), so doors indoors are the same height.
const INTERIOR_DOOR_H := 1.15
const OUTDOOR_DOOR_H := 1.9
## Open sides of a wall square in order of preference: the faces the default camera looks at come first.
const FACES: Array[Vector2i] = [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]

static var _catalog: Dictionary = {}
static var _manifest: Dictionary = {}


static func catalog() -> Dictionary:
	if _catalog.is_empty() and FileAccess.file_exists(CATALOG_JSON):
		_catalog = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_JSON)) as Dictionary
	return _catalog


## Every prop sprite: id -> {file, pixel_size, world_height, world_width, mount ...}.
static func manifest() -> Dictionary:
	if _manifest.is_empty() and FileAccess.file_exists(MANIFEST_JSON):
		_manifest = (JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_JSON)) as Dictionary).get("props", {}) as Dictionary
	return _manifest


static func has_art(art: String) -> bool:
	var info := manifest().get(art, {}) as Dictionary
	return not info.is_empty() and ResourceLoader.exists("res://" + str(info.get("file", "")))


## How a location prop or container is dressed: {art, mount, scale, on_wall} with art "" for an invisible spot,
## or {} when nothing in the catalog fits (the caller falls back to a plain marker).
static func look_for(spec: Dictionary, is_container: bool = false) -> Dictionary:
	var cat := catalog()
	var ids := cat.get("ids", {}) as Dictionary
	var models := cat.get("models", {}) as Dictionary
	var id := str(spec.get("id", ""))
	var model := str(spec.get("model", ""))
	var entry: Variant = null
	var found := false
	if ids.has(id):
		entry = ids[id]
		found = true
	elif model != "" and models.has(model):
		entry = models[model]
		found = true
	elif model != "" and has_art(model):
		entry = model
		found = true
	elif is_container:
		entry = str(cat.get("container_default", "chest"))
		found = true
	if not found:
		return {}
	if entry == null:
		return {"art": ""}
	var out := {"art": str(entry)} if entry is String else (entry as Dictionary).duplicate()
	if not has_art(str(out.get("art", ""))):
		return {}
	return out


## Builds the piece for a location prop or container at its square; null if the catalog has no art for it. The
## returned node owns everything drawn for it, so freeing it removes the piece (and gives back a square it took).
static func place(board: ArenaBoard, spec: Dictionary, is_container: bool = false) -> Node3D:
	var look := look_for(spec, is_container)
	if look.is_empty():
		return null
	var cell := Vector2i(int((spec["cell"] as Array)[0]), int((spec["cell"] as Array)[1]))
	var root := Node3D.new()
	root.name = "Dressing_" + str(spec.get("id", "prop"))
	board.add_child(root)
	var art := str(look.get("art", ""))
	if art == "":
		return root   # an invisible spot: still clickable, nothing drawn
	var on_wall_square := _wall_at(board, cell)
	if on_wall_square and has_art(str(look.get("on_wall", ""))):
		art = str(look["on_wall"])
	var mount := str(look.get("mount", (manifest()[art] as Dictionary).get("mount", "stand")))
	var scale_ := float(look.get("scale", 1.0))
	match mount:
		"wall":
			if not _hang(board, root, art, cell, scale_):
				_stand(board, root, art, cell, scale_)
		"floor":
			if on_wall_square:
				_take_square(board, root, cell)
			_lay(board, root, art, cell, scale_)
		_:
			if on_wall_square and board.house_cells.has(cell) and bool(look.get("building", false)):
				# The whole building is this piece (Old Bonegrinder's windmill, the Abbey's bell tower): the house
				# hides while it exists and the art stands over its ground.
				var at := board.hide_building(cell)
				root.tree_exiting.connect(func() -> void:
					if is_instance_valid(board):
						board.show_building(cell))
				var tower := _sprite(art)
				tower.pixel_size *= scale_
				tower.position = at
				root.add_child(tower)
				_fade_with_trees(board, tower)
				return root
			var front := str(look.get("front", "")) if has_art(str(look.get("front", ""))) else front_of(art)
			if on_wall_square and (board.house_cells.has(cell) or front != ""):
				# On a house, or furniture set into a wall (a bookcase on a wall square): its front, hung on the wall.
				if _hang(board, root, front if front != "" else art, cell, scale_):
					return root
			if on_wall_square:
				_take_square(board, root, cell)
			elif board.grid.has_flag(cell, CombatGrid.LOW) or board.grid.has_flag(cell, CombatGrid.DIFFICULT):
				_take_square(board, root, cell)   # its own art replaces the board's furniture or brambles there
			var piece := stand_piece(board, root, art, cell, scale_, null, front, bool(look.get("fade", false)) or bool(look.get("big", false)))
			if bool(look.get("fade", false)) and piece is Sprite3D:
				_fade_with_trees(board, piece as Sprite3D)
	return root


## A tall piece (the Gulthias Tree, a windmill) fades like the trees when it stands between the camera and the party.
static func _fade_with_trees(board: ArenaBoard, sp: Sprite3D) -> void:
	board.occluders.append(sp)
	sp.tree_exiting.connect(func() -> void:
		if is_instance_valid(board):
			board.occluders.erase(sp))


## A container that's been emptied looks dimmer.
static func mark_looted(node: Node3D) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = Look.cel("peat")
		return
	for c: Node in node.find_children("*", "SpriteBase3D", true, false):
		(c as SpriteBase3D).modulate = Color(0.55, 0.5, 0.55)


# --- Doors ----------------------------------------------------------------------------------------

## The art for a door: catalog ids, then the first rule whose words are in its id or label.
static func door_look(spec: Dictionary) -> Dictionary:
	if spec.has("art"):
		return {"art": str(spec["art"])}
	var doors := catalog().get("doors", {}) as Dictionary
	var id := str(spec.get("id", ""))
	var by_id := doors.get("ids", {}) as Dictionary
	if by_id.has(id):
		return (by_id[id] as Dictionary).duplicate()
	var words := ("%s %s" % [id.replace("_", " "), spec.get("label", "")]).to_lower()
	for rule: Array in doors.get("rules", []):
		for w: String in rule[0]:
			if words.contains(w):
				return {"art": str(rule[1])}
	return {"art": str(doors.get("default", "door_wood"))}


## A door in the wall line: a frame that stays (posts and a lintel, in the wall's material) and the leaf, which is
## the returned node (hidden when the door is open). A secret door nobody has found looks like the wall around it
## until reveal_door. Returns null if there's no door art, so the caller can fall back.
static func door(board: ArenaBoard, spec: Dictionary, secret: bool) -> Node3D:
	var look := door_look(spec)
	var art := str(look.get("art", ""))
	if not has_art(art):
		return null
	var cell := Vector2i(int((spec["cell"] as Array)[0]), int((spec["cell"] as Array)[1]))
	board.door_cells[cell] = true
	var along_x := _wall_at(board, cell + Vector2i(-1, 0)) or _wall_at(board, cell + Vector2i(1, 0))
	var outdoors := board.theme in ArenaBoard.WILD or board.theme in ArenaBoard.TOWNS
	var h := float(look.get("height", OUTDOOR_DOOR_H if outdoors else INTERIOR_DOOR_H))
	var w := float(look.get("width", DOOR_WIDTH))
	var base := board.cell_center(cell)
	var yaw := 0.0 if along_x else PI / 2.0   # the leaf's face looks along z when the wall runs along x
	var leaf := Node3D.new()
	leaf.name = "Door_" + str(spec.get("id", ""))
	leaf.position = base
	leaf.rotation.y = yaw
	board.add_child(leaf)
	var sp := _sprite(art)
	var info := manifest()[art] as Dictionary
	sp.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sp.double_sided = true
	sp.scale = Vector3(w / float(info.get("world_width", 1.0)), h / float(info.get("world_height", 1.0)), 1.0)
	sp.position = Vector3(0, 0, 0)
	sp.name = "Leaf"
	leaf.add_child(sp)
	var statue := str(look.get("statue", ""))
	if bool(look.get("pillars", false)):
		# A gateway between two stone pillars (the Gates of Barovia), each with a statue on top where there's art:
		# the pillars take the squares either side of the gate.
		for side: Vector2i in ([Vector2i(-1, 0), Vector2i(1, 0)] if along_x else [Vector2i(0, -1), Vector2i(0, 1)]):
			var pc := cell + side
			if board.grid.in_bounds(pc):
				_pillar(board, pc, h + 0.1, statue)
	elif not secret:
		_frame(board, base, along_x, h)
	if secret:
		# Hidden: a block of wall (the bookcase door shows its shelves on the wall faces) until it is found.
		sp.visible = false
		var disguise := Node3D.new()
		disguise.name = "Disguise"
		leaf.add_child(disguise)
		var block := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1, h, 1)
		block.mesh = bm
		block.position = Vector3(0, h / 2.0, 0)
		block.material_override = board.wall_material()
		disguise.add_child(block)
		if art == "door_bookcase":
			for s: float in [-1.0, 1.0]:
				var face := _sprite(art)
				face.billboard = BaseMaterial3D.BILLBOARD_DISABLED
				face.scale = sp.scale
				face.position = Vector3(0, 0, s * (0.5 + WALL_GAP))
				face.rotation.y = 0.0 if s > 0 else PI
				disguise.add_child(face)
	return leaf


## A secret door that has just been found shows as a door.
static func reveal_door(leaf: Node3D) -> void:
	if leaf is MeshInstance3D:
		(leaf as MeshInstance3D).material_override = Look.cel("walnut")
		return
	var disguise := leaf.get_node_or_null("Disguise")
	if disguise != null:
		disguise.queue_free()
	var sp := leaf.get_node_or_null("Leaf") as Node3D
	if sp != null:
		sp.visible = true


## A square stone pillar on `cell` (its tree or wall hidden), capped, with a statue billboard on top if given.
static func _pillar(board: ArenaBoard, cell: Vector2i, h: float, statue: String) -> void:
	board.clear_cell(cell)
	var stone: Material = Look.cel_textured("church/stone_wall")
	if stone == null:
		stone = Look.cel("stone")
	var base := board.cell_center(cell)
	_frame_box(board, Vector3(0.84, h, 0.84), base + Vector3(0, h / 2.0, 0), stone)
	_frame_box(board, Vector3(1.0, 0.16, 1.0), base + Vector3(0, h + 0.08, 0), Look.cel("stone_deep"))
	_frame_box(board, Vector3(1.0, 0.2, 1.0), base + Vector3(0, 0.1, 0), Look.cel("stone_deep"))
	if statue != "" and has_art(statue):
		var sp := _sprite(statue)
		sp.position = base + Vector3(0, h + 0.16, 0)
		board.add_child(sp)


static func _frame(board: ArenaBoard, base: Vector3, along_x: bool, h: float) -> void:
	var mat := board.wall_material()
	var post := Vector3(0.12, h, 0.34) if along_x else Vector3(0.34, h, 0.12)
	for s: float in [-1.0, 1.0]:
		var off := Vector3(s * 0.47, h / 2.0, 0) if along_x else Vector3(0, h / 2.0, s * 0.47)
		_frame_box(board, post, base + off, mat)
	_frame_box(board, Vector3(1.0, 0.12, 0.34) if along_x else Vector3(0.34, 0.12, 1.0), base + Vector3(0, h + 0.06, 0),
		Look.cel("bone_dark" if board.theme in ArenaBoard.TOWNS else ArenaBoard.CUT_FACE))


static func _frame_box(board: ArenaBoard, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "DoorFrame"
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	board.add_child(mi)


# --- Exits ----------------------------------------------------------------------------------------

## The art for an exit (catalog "exits"): stairs, a tent flap, a church's doors ... or "" for none (roads).
static func exit_look(spec: Dictionary, outdoors: bool) -> String:
	var exits := catalog().get("exits", {}) as Dictionary
	var words := ("%s %s" % [str(spec.get("id", "")).replace("_", " "), spec.get("label", "")]).to_lower()
	for rule: Array in exits.get("rules", []):
		for w: String in rule[0]:
			if words.contains(w):
				return "" if rule[1] == null else str(rule[1])
	return str(exits.get("outdoor_default" if outdoors else "indoor_default", ""))


## What marks a way out: a door on a house front (an exit set into a wall), a door in an interior's outer wall,
## stairs up or down. Roads off the edge of a map get nothing. Returns the piece, or null.
static func exit_piece(board: ArenaBoard, spec: Dictionary) -> Node3D:
	var outdoors := board.theme in ArenaBoard.WILD or board.theme in ArenaBoard.TOWNS
	var art := exit_look(spec, outdoors)
	if not has_art(art):
		return null
	var cell := Vector2i(int((spec["cell"] as Array)[0]), int((spec["cell"] as Array)[1]))
	var mount := str((manifest()[art] as Dictionary).get("mount", "stand"))
	var root := Node3D.new()
	root.name = "Exit_" + str(spec.get("id", ""))
	board.add_child(root)
	# Stairs are the way itself, so they show only while the way is open (LocationView keeps them hidden while the
	# exit's `when` is false: a secret stair nobody has found). A door stays drawn even when it's barred.
	if mount == "floor":
		_lay(board, root, art, cell, 1.0)
		root.set_meta("only_when_open", true)
		return root
	if mount == "stand":
		_stand(board, root, art, cell, 1.0)
		root.set_meta("only_when_open", true)
		return root
	if _wall_at(board, cell):
		if _hang(board, root, art, cell, 1.0):
			return root
	elif not outdoors and (_wall_at(board, cell + Vector2i(-1, 0)) and _wall_at(board, cell + Vector2i(1, 0)) \
			or _wall_at(board, cell + Vector2i(0, -1)) and _wall_at(board, cell + Vector2i(0, 1))):
		# A door in the outer wall of an interior, shut behind the party.
		var leaf := door(board, {"id": spec.get("id", ""), "cell": spec["cell"], "art": art}, false)
		if leaf != null:
			leaf.reparent(root)
			return root
	root.queue_free()
	return null


# --- Pieces ---------------------------------------------------------------------------------------

## A fire's flame: a bright billboard (unshaded, it gives light rather than taking it) about `size` units tall,
## swaying a little. Null without the art.
static func flame(size: float) -> Sprite3D:
	if not has_art("flame"):
		return null
	var sp := _sprite("flame")
	sp.shaded = false
	sp.pixel_size *= size / float((manifest()["flame"] as Dictionary).get("world_height", 0.9))
	sp.ready.connect(func() -> void:
		var t := sp.create_tween().set_loops()
		t.tween_property(sp, "scale", Vector3(1.08, 0.9, 1.0), 0.23).set_trans(Tween.TRANS_SINE)
		t.tween_property(sp, "scale", Vector3(0.95, 1.08, 1.0), 0.31).set_trans(Tween.TRANS_SINE))
	return sp


## A wall piece by itself (billboard off, seen from its front only), its foot at the node; null without art.
static func wall_sprite(art: String) -> Sprite3D:
	if not has_art(art):
		return null
	var sp := _sprite(art)
	sp.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sp.double_sided = false
	return sp


static func _sprite(art: String) -> Sprite3D:
	var info := manifest()[art] as Dictionary
	var sp := Sprite3D.new()
	sp.texture = load("res://" + str(info["file"])) as Texture2D
	sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sp.shaded = true
	sp.pixel_size = float(info.get("pixel_size", 0.01))
	sp.offset = Vector2(0, float(info.get("height_px", 256)) / 2.0)   # the node's origin is the piece's foot
	return sp


static func _stand(board: ArenaBoard, root: Node3D, art: String, cell: Vector2i, scale_: float) -> void:
	stand_piece(board, root, art, cell, scale_)


## A standing piece on `cell` with a fixed place and facing (owner request 2026-10-06: environment pieces show the
## side that faces the camera rather than turning with it). Furniture with a front view stands flat against a wall
## beside it; a piece drawn from the front and from behind is a PropView facing away from that wall (or south, toward
## the opening camera); anything else looks the same from every side (a barrel, a tree) and is a plain billboard.
## Added to `parent`; returns the piece.
static func stand_piece(board: ArenaBoard, parent: Node3D, art: String, cell: Vector2i, scale_: float = 1.0,
		at_override: Variant = null, front_override: String = "", big: bool = false) -> Node3D:
	scale_ *= float((catalog().get("scales", {}) as Dictionary).get(art, 1.0))
	var at: Vector3 = board.cell_center(cell) if at_override == null else at_override as Vector3
	var wall := wall_side(board, cell)
	var front := front_override if front_override != "" else front_of(art)
	if front != "" and wall != Vector2i.ZERO:
		var against := _against_wall(board, parent, art, front, cell, wall, scale_ * real_scale(front))
		against.set_meta("art", front)
		return against
	scale_ *= real_scale(art)
	big = big or is_big(art)
	var info := manifest()[art] as Dictionary
	var back := str(info.get("back", ""))
	if big and at_override == null:
		_clear_trees_around(board, parent, cell, maxf(_width(art), _width(back) if back != "" else 0.0) * scale_)
	if not big and at_override == null:
		# Owner report (2026-10-06): pieces overlapped walls and each other. A piece is no wider than its square,
		# unless all eight squares around it are open floor with nothing standing there.
		var w := maxf(_width(art), _width(back) if back != "" and has_art(back) else 0.0) * scale_
		var room := room_at(board, cell)
		if w > room:
			scale_ *= room / w
	var piece: Sprite3D
	if back != "" and has_art(back):
		var binfo := manifest()[back] as Dictionary
		var faces := Vector3(-wall.x, 0, -wall.y) if wall != Vector2i.ZERO else Vector3(0, 0, 1)
		piece = PropView.create(load("res://" + str(info["file"])) as Texture2D, float(info.get("pixel_size", 0.01)) * scale_,
			load("res://" + str(binfo["file"])) as Texture2D, float(binfo.get("pixel_size", 0.01)) * scale_, faces)
	else:
		piece = _sprite(art)
		piece.pixel_size *= scale_
	piece.position = at
	piece.set_meta("art", art)
	parent.add_child(piece)
	return piece


## How wide a standing piece is drawn (its real size and catalog scale included; the wider of its front and back).
static func footprint(art: String) -> float:
	var back := str((manifest().get(art, {}) as Dictionary).get("back", ""))
	var w := maxf(_width(art), _width(back) if back != "" else 0.0)
	return w * real_scale(art) * float((catalog().get("scales", {}) as Dictionary).get(art, 1.0))


## Owner report (2026-10-06): the opening road's cottage was drawn tiny. Each standing piece has a real height in feet
## (catalog "feet"; a person is 6 ft and one unit is 5 ft): this is the scale that draws `art` at that height.
static func real_scale(art: String) -> float:
	var feet := float((catalog().get("feet", {}) as Dictionary).get(art, 0.0))
	var info := manifest().get(art, {}) as Dictionary
	if feet <= 0.0 or info.is_empty():
		return 1.0
	return (feet / 5.0) / float(info.get("world_height", 1.0))


## A building-sized piece (a cottage, a tent, a wagon: wider than catalog "big_width" at its real size) keeps its real
## size whatever the room, and clears the trees it would stand among.
static func is_big(art: String) -> bool:
	return footprint(art) > float(catalog().get("big_width", 1.6))


## Hides the trees (and rock) on the squares a big piece covers, plus one more row on the sides the opening camera
## looks from (west and south), so the forest neither cuts through it nor hides it, and the board's own scenery (a
## stump, brambles) on the open squares it covers. They come back if it goes.
static func _clear_trees_around(board: ArenaBoard, parent: Node3D, cell: Vector2i, width: float) -> void:
	var k := clampi(int(round(width / 2.0 - 0.5)), 1, 2)
	var cleared: Array[Vector2i] = []
	for dx: int in range(-k - 1, k + 1):
		for dy: int in range(-k, k + 2):
			var c := cell + Vector2i(dx, dy)
			var furnished := not board.grid.has_flag(c, CombatGrid.WALL) and board.dressing.has(c) and absi(dx) <= k and dy <= k
			if c == cell or not (board.is_tree(c) or furnished):
				continue
			board.clear_cell(c)
			cleared.append(c)
	if parent != board and not cleared.is_empty():
		parent.tree_exiting.connect(func() -> void:
			if is_instance_valid(board):
				for c: Vector2i in cleared:
					board.restore_cell(c))


static func _width(art: String) -> float:
	var info := manifest().get(art, {}) as Dictionary
	return float(info.get("world_width", float(info.get("width_px", 100)) * float(info.get("pixel_size", 0.01))))


## How wide a standing piece on `cell` may be: its square, or nearly two if every square around it is open floor
## that nothing else stands on (board.occupied: the location's things, SetDressing.reserve).
static func room_at(board: ArenaBoard, cell: Vector2i) -> float:
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var n := cell + Vector2i(dx, dy)
			if not board.grid.in_bounds(n) or board.grid.has_flag(n, CombatGrid.WALL) or board.grid.has_flag(n, CombatGrid.LOW) \
					or board.grid.has_flag(n, CombatGrid.VOID) or board.occupied.has(n):
				return 1.0
	return 1.8


## Marks the squares a location's things stand on, before any of them are built, so pieces size themselves to the
## room they really have (room_at).
static func reserve(board: ArenaBoard, loc: Dictionary) -> void:
	for key: String in ["props", "containers", "doors", "exits", "npcs"]:
		for t: Variant in loc.get(key, []):
			var c := (t as Dictionary).get("cell", []) as Array
			if c.size() == 2:
				board.occupied[Vector2i(int(c[0]), int(c[1]))] = key


## The front view of furniture that stands against a wall (catalog "fronts"), or "".
static func front_of(art: String) -> String:
	var f: Variant = (catalog().get("fronts", {}) as Dictionary).get(art, "")
	var front := str(f) if f is String else str((f as Dictionary).get("art", ""))
	return front if has_art(front) else ""


## The side of `cell` with a wall next to it, the one furniture would stand against (Vector2i.ZERO if none). Walls to
## the north come first, so a piece faces south toward the opening camera when it can.
static func wall_side(board: ArenaBoard, cell: Vector2i) -> Vector2i:
	for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
		if _wall_at(board, cell + d):
			return d
	return Vector2i.ZERO


## Furniture against a wall: its front view stands flat, parallel to the wall and facing into the room, with a body
## of wood behind it back to the wall (catalog "fronts": depth, body), so from the side it has thickness.
static func _against_wall(board: ArenaBoard, parent: Node3D, art: String, front: String, cell: Vector2i, wall: Vector2i, scale_: float) -> Node3D:
	var spec: Variant = (catalog().get("fronts", {}) as Dictionary).get(art, "")
	var depth := float((spec as Dictionary).get("depth", 0.35)) if spec is Dictionary else 0.35
	var body := bool((spec as Dictionary).get("body", true)) if spec is Dictionary else true
	var info := manifest()[front] as Dictionary
	var w := float(info.get("world_width", 1.0)) * scale_
	var h := float(info.get("world_height", 1.0)) * scale_
	# About a square wide (a little over, as furniture is), but just one square when the next square along the wall
	# has something of its own.
	var along := Vector2i(wall.y, wall.x)
	var crowded := false
	for side: Vector2i in [along, -along]:
		var n := cell + side
		crowded = crowded or board.occupied.has(n) or board.grid.has_flag(n, CombatGrid.LOW) or board.door_cells.has(n)
	var fit := minf(1.0, (0.98 if crowded else 1.25) / w)
	board.used_faces["%d,%d,%d,%d" % [cell.x + wall.x, cell.y + wall.y, -wall.x, -wall.y]] = true   # no portrait behind it
	var root := Node3D.new()
	root.name = "AgainstWall_" + art
	var n := Vector3(-wall.x, 0, -wall.y)   # into the room
	var c := board.cell_center(cell)
	root.position = c + Vector3(wall.x, 0, wall.y) * 0.5
	root.rotation.y = atan2(n.x, n.z)
	parent.add_child(root)
	var sp := wall_sprite(front)
	sp.pixel_size *= scale_
	sp.scale.x = fit   # squeezed to fit along the wall, never shortened: it keeps its real height
	sp.position = Vector3(0, 0, depth)
	root.add_child(sp)
	if body:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w * fit * 0.9, h * 0.86, depth - 0.02)
		mi.mesh = bm
		mi.position = Vector3(0, bm.size.y / 2.0, depth / 2.0)
		mi.material_override = Look.cel("walnut")
		root.add_child(mi)
	return root


## A floor piece lying flat, centred on its node (rotate the node about y to turn it).
static func flat_sprite(art: String) -> Sprite3D:
	var sp := _sprite(art)
	sp.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sp.offset = Vector2.ZERO
	sp.axis = Vector3.AXIS_Y
	return sp


static func _lay(board: ArenaBoard, root: Node3D, art: String, cell: Vector2i, scale_: float) -> void:
	var sp := flat_sprite(art)
	sp.pixel_size *= scale_
	sp.position = board.cell_center(cell) + Vector3(0, WALL_GAP, 0)
	root.add_child(sp)


## Hangs a wall piece on the wall face between `cell` and its open neighbour (or, for a piece on an open square,
## on the wall beside it). False if there's no such face.
static func _hang(board: ArenaBoard, root: Node3D, art: String, cell: Vector2i, scale_: float) -> bool:
	var wall := cell
	var normal := Vector2i.ZERO
	if _wall_at(board, cell):
		# The side facing the piece's own room first (an area containing its square), then the usual order.
		for own: bool in [true, false]:
			for d in FACES:
				if normal == Vector2i.ZERO and _open_at(board, cell + d) and (not own or _same_area(board, cell, cell + d)):
					normal = d
	else:
		for d in FACES:
			if _wall_at(board, cell - d):
				wall = cell - d
				normal = d
				break
	if normal == Vector2i.ZERO:
		return false
	# One piece per wall face: a second one moves to another open face of the same wall square if it has one.
	var key := "%d,%d,%d,%d" % [wall.x, wall.y, normal.x, normal.y]
	if board.used_faces.has(key) and _wall_at(board, cell):
		for d in FACES:
			var k2 := "%d,%d,%d,%d" % [wall.x, wall.y, d.x, d.y]
			if _open_at(board, cell + d) and not board.used_faces.has(k2):
				normal = d
				key = k2
				break
	board.used_faces[key] = true
	var info := manifest()[art] as Dictionary
	var sp := _sprite(art)
	sp.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sp.double_sided = false
	var w := float(info.get("world_width", 1.0)) * scale_
	var h := float(info.get("world_height", 1.0)) * scale_
	var fit := minf(1.0, WALL_FACE / w)   # never wider than the square's face
	sp.pixel_size *= scale_ * fit
	h *= fit
	# Tall pieces (fireplaces, clocks, windows) stand on the floor; small ones hang at about eye level.
	var bottom := 0.0 if h >= 0.85 else maxf(0.0, 0.7 - h / 2.0)
	var n := Vector3(normal.x, 0, normal.y)
	var c := board.cell_center(wall)
	sp.position = Vector3(c.x, board.floor_y(cell if not _wall_at(board, cell) else cell + normal) + bottom, c.z) + n * (0.5 + WALL_GAP)
	sp.rotation.y = atan2(n.x, n.z)
	root.add_child(sp)
	board.attach_to_building(wall, root)
	var window := board.windows.get("%d,%d,%d,%d" % [wall.x, wall.y, normal.x, normal.y], null) as Node3D
	if window != null and is_instance_valid(window):
		window.visible = false   # this piece hangs where a house had a window
	return true


## The prop takes a square the board dressed (a tree, a wall block, furniture): the board's piece hides while the
## prop exists and comes back when it's freed.
static func _take_square(board: ArenaBoard, root: Node3D, cell: Vector2i) -> void:
	board.clear_cell(cell)
	root.tree_exiting.connect(func() -> void:
		if is_instance_valid(board):
			board.restore_cell(cell))


static func _same_area(board: ArenaBoard, a: Vector2i, b: Vector2i) -> bool:
	for r in board.areas:
		if r.has_point(a) and r.has_point(b):
			return true
	return false


static func _wall_at(board: ArenaBoard, c: Vector2i) -> bool:
	return board.grid.in_bounds(c) and board.grid.has_flag(c, CombatGrid.WALL) and not board.door_cells.has(c)


static func _open_at(board: ArenaBoard, c: Vector2i) -> bool:
	return board.grid.in_bounds(c) and not board.grid.has_flag(c, CombatGrid.VOID) \
		and (not board.grid.has_flag(c, CombatGrid.WALL) or board.door_cells.has(c))
