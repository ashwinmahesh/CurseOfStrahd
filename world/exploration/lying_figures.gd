class_name LyingFigures
extends RefCounted
## Figures the story has lying down (owner, 2026-10-13: the text has Vasilka lying under a sheet, very still, and she
## stood beside her table): an NPC entry's or an encounter monster's `lying` (docs/contracts/locations.md) lays its
## figure down (CombatToken.lie_down) until it wakes or its fight starts. A person lies on their back: on their own
## square, on top of the furniture standing there, or on the prop `on` names (a bier beside them), head along the
## furniture (else east) or toward `head`, under a linen sheet to the `chest` or over the `face`. A beast or a dragon
## lies on its belly, low on the ground. A foe lying before its fight gets up as it opens (LocationFights).

const HEADS := {"north": Vector2(0, -1), "south": Vector2(0, 1), "east": Vector2(1, 0), "west": Vector2(-1, 0)}
## Creature types that lie on their bellies (four legs, or wings and a tail) unless the entry says `pose`.
const BELLY_TYPES: Array[StringName] = [&"beast", &"dragon"]
## Where a `picture` (a drawing of the figure lying down) is: art/sprites/lying/<id>.png.
const PICTURES := "res://art/sprites/lying/%s.png"
## How far a sheet hangs over the edge of what the figure lies on, and its spread on bare floor (half the width).
const SHEET_DROP := 0.14
const FLOOR_SPREAD := 0.34
## The parts of a piece of furniture this close to its highest point make its top (top_of).
const TOP_BAND := 0.1


## Lays `tok` (in the tree, on square `cell`) down as `how` says: true, or {on, head, sheet, pose, lift, picture}. A
## `picture` that has been drawn (picture_path) stands in for the figure; until it is, the figure lies as it would.
static func lay(view: LocationView, tok: CombatToken, how: Variant, cell: Vector2i) -> void:
	var spec := how as Dictionary if how is Dictionary else {}
	var pose := str(spec.get("pose", "belly" if tok.combatant.creature.creature_type in BELLY_TYPES else "back"))
	var rest := {"pose": pose, "sheet": str(spec.get("sheet", "")), "lift": 0.0, "offset": Vector2.ZERO,
		"half": FLOOR_SPREAD, "drop": 0.0}
	var picture := picture_path(str(spec.get("picture", "")))
	if picture != "":
		rest["pose"] = "picture"
		rest["picture"] = picture
	if HEADS.has(str(spec.get("head", ""))):
		rest["head"] = HEADS[str(spec["head"])]
	var under := furniture(view, str(spec.get("on", "")), cell)
	if under != null:
		var box := top_of(under)
		var mid := under.global_transform * box.get_center()
		rest["lift"] = float(spec.get("lift", (under.global_transform * box.end).y - tok.global_position.y))
		rest["offset"] = Vector2(mid.x - tok.global_position.x, mid.z - tok.global_position.z)
		# Along its longer side, the end the data's `head` points to if it gives one.
		var along := under.global_basis.x if box.size.x >= box.size.z else under.global_basis.z
		var flat := Vector2(along.x, along.z).normalized()
		if rest.has("head") and flat.dot(rest["head"] as Vector2) < 0.0:
			flat = -flat
		if flat.length() > 0.5:
			rest["head"] = flat
		var scale := under.global_basis.get_scale()
		rest["half"] = minf(box.size.x * scale.x, box.size.z * scale.z) / 2.0 + 0.02
		rest["long"] = maxf(box.size.x * scale.x, box.size.z * scale.z)
		rest["drop"] = SHEET_DROP
	elif spec.has("lift"):
		rest["lift"] = float(spec["lift"])
	tok.lie_down(rest)


## The drawing of figure `id` lying down (PICTURES), or "" when there is none (yet).
static func picture_path(id: String) -> String:
	if id == "":
		return ""
	var path := PICTURES % id
	return path if ResourceLoader.exists(path) else ""


## The prop node the figure lies on: the one `on` names, else furniture standing on its own square; null for none.
static func furniture(view: LocationView, on: String, cell: Vector2i) -> Node3D:
	if on != "":
		return view.prop_nodes.get(on, null) as Node3D
	for p: Variant in view.loc.get("props", []):
		var prop := p as Dictionary
		if LocationView._cell(prop["cell"]) == cell and view.prop_nodes.has(str(prop["id"])):
			return view.prop_nodes[str(prop["id"])] as Node3D
	return null


## The top of the furniture `node`: the bounds (in its own space) of the parts of its meshes that reach within TOP_BAND
## of its highest point, so a figure lies on the planks of a table and not on the tray hanging off its side.
static func top_of(node: Node3D) -> AABB:
	var parts: Array[AABB] = []
	var inv := node.global_transform.affine_inverse()
	for n: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var to_node := inv * mi.global_transform
		var found := false
		for i in mi.mesh.get_surface_count():
			var verts := mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array
			if verts.is_empty():
				continue
			var b := AABB(to_node * verts[0], Vector3.ZERO)
			for v in verts:
				b = b.expand(to_node * v)
			parts.append(b)
			found = true
		if not found:
			parts.append(to_node * mi.mesh.get_aabb())   # no vertices to read (a headless run): the whole piece
	if parts.is_empty():
		return AABB(Vector3(-0.4, 0, -0.4), Vector3(0.8, 0, 0.8))
	var high := -INF
	for b in parts:
		high = maxf(high, b.end.y)
	var box := AABB()
	var first := true
	for b in parts:
		if b.end.y >= high - TOP_BAND:
			box = b if first else box.merge(b)
			first = false
	return box


## A foe's `lying` from its encounter entry (LocationFights.monsters_for keeps it on the creature), or null.
static func of(cr: Creature) -> Variant:
	return cr.get_meta(&"lying") if cr.has_meta(&"lying") else null
