class_name LocationBuilder
extends RefCounted
## Builds a location's pieces on its board (LocationView): the light, sky and weather (Atmosphere) and the time of
## day outdoors, the doors and the pieces of its ways out, props, containers, lamps and fires.


static func _build_environment(view: LocationView) -> void:
	# Light, sky, fog, mist, weather and the land around the map: the place's mood (Atmosphere, docs/art/atmosphere.md).
	view.atmosphere = Atmosphere.create(view.loc_id, view.loc, view.board)
	view.add_child(view.atmosphere)
	view._env = view.atmosphere.env
	view._sun = view.atmosphere.sun
	# The party's lantern (or a Light cantrip): it goes where the leader goes, lit when it's dark.
	view.lantern = OmniLight3D.new()
	view.lantern.light_color = Look.color("candle")
	view.lantern.omni_range = 7.0
	view.lantern.light_energy = 2.4
	view.lantern.position = Vector3(0, 1.6, 0)
	update_daylight(view)


## The time of day outdoors (plan §5.2 day and night): an overcast Barovian day, a red dusk and dawn, and a blue
## night when the lantern comes out. Indoors only the map's light level counts.
static func update_daylight(view: LocationView) -> void:
	if view.atmosphere == null:
		return
	var light := str(view.loc["map"].get("light", "dim"))
	var outdoors := bool(view.loc["map"].get("outdoors", false))
	var phase := time_phase(view)
	if not outdoors:
		view.atmosphere.set_phase("any")
		view.lantern.visible = light != "bright" or view.st.spell_active("light")
		return
	view.atmosphere.set_phase(phase)
	view.lantern.visible = phase == "night" or light == "dark" or view.st.spell_active("light")


## "day" (7:00-17:59), "dusk" (18:00-18:59), "night" (19:00-5:59) or "dawn" (6:00-6:59).
static func time_phase(view: LocationView) -> String:
	var h := view.st.minute_of_day / 60
	if h >= 7 and h < 18:
		return "day"
	if h == 18:
		return "dusk"
	if h == 6:
		return "dawn"
	return "night"


static func _build_doors(view: LocationView) -> void:
	for ex: Variant in view.loc.get("exits", []):
		var piece := SetDressing.exit_piece(view.board, ex as Dictionary)
		if piece != null:
			view.exit_nodes[str((ex as Dictionary)["id"])] = piece
	refresh_exits(view)
	for d: Variant in view.loc.get("doors", []):
		var door := d as Dictionary
		var cell := LocationView._cell(door["cell"])
		var id := str(door["id"])
		var secret := int(door.get("secret_dc", 0)) > 0 and not bool((view.st.loc_state(view.loc_id)["found"] as Dictionary).get(id, false))
		var open := LocationLocks._door_state(view, id) == LocationView.DOOR_OPEN
		view.grid.set_flag(cell, CombatGrid.WALL, not open)
		var node: Node3D = SetDressing.door(view.board, door, secret)
		if node == null:
			node = _box(view, Vector3(0.9, 1.7, 0.9), view.board.cell_center(cell) + Vector3(0, 0.85, 0), "walnut" if not secret else "slate")
		node.visible = not open
		view.door_nodes[id] = node


## Stairs (and other pieces that are the way itself) show only while their exit's `when` holds, so a secret stair
## isn't drawn before anyone finds it. Checked a few times a second, since many things can open a way.
static func refresh_exits(view: LocationView) -> void:
	for ex: Variant in view.loc.get("exits", []):
		var e := ex as Dictionary
		var node := view.exit_nodes.get(str(e["id"]), null) as Node3D
		if node != null and is_instance_valid(node) and bool(node.get_meta("only_when_open", false)):
			node.visible = StoryConditions.check(str(e.get("when", "")), view.st)


static func _build_props(view: LocationView) -> void:
	for p: Variant in view.loc.get("props", []):
		var prop := p as Dictionary
		if not StoryConditions.check(str(prop.get("when", "")), view.st):
			continue
		var id := str(prop["id"])
		var kind := str(prop["kind"])
		if kind == "search" and not bool((view.st.loc_state(view.loc_id)["found"] as Dictionary).get(id, false)):
			continue
		if str(prop.get("burning", "")) != "" and StoryConditions.check(str(prop["burning"]), view.st):
			view.prop_nodes[id + "#fire"] = _flame(view, LocationView._cell(prop["cell"]), 1.6)
		view.prop_nodes[id] = _prop_node(view, prop)
	for c: Variant in view.loc.get("containers", []):
		var ct := c as Dictionary
		if not StoryConditions.check(str(ct.get("when", "")), view.st):
			continue
		var looted := bool((view.st.loc_state(view.loc_id)["looted"] as Dictionary).get(str(ct["id"]), false))
		var node: Node3D = SetDressing.place(view.board, ct, true)
		if node == null:
			node = _box(view, Vector3(0.8, 0.55, 0.55), view.board.cell_center(LocationView._cell(ct["cell"])) + Vector3(0, 0.28, 0), "umber")
		if looted:
			SetDressing.mark_looted(node)
		view.container_nodes[str(ct["id"])] = node


## A prop's piece (SetDressing, art/sprites/props/catalog.json), else a billboard by name, else a plain marker.
static func _prop_node(view: LocationView, prop: Dictionary) -> Node3D:
	var node: Node3D = SetDressing.place(view.board, prop)
	if node != null:
		return node
	var sprite := _prop_art(prop)
	if sprite != "":
		node = view.board.prop_sprite(sprite, view.board.cell_center(LocationView._cell(prop["cell"])), 0.8)
	if node == null:
		var colour := {"examine": "parchment", "book": "ember", "search": "bone", "lever": "pewter", "decor": "stone"}.get(str(prop["kind"]), "bone") as String
		node = _box(view, Vector3(0.45, 0.35, 0.45), view.board.cell_center(LocationView._cell(prop["cell"])) + Vector3(0, 0.2, 0), colour)
	return node


## Which billboard prop art (art/sprites/props) a prop looks like, from its model or id, or "" for a plain marker.
static func _prop_art(prop: Dictionary) -> String:
	var key := ("%s %s" % [prop.get("model", ""), prop.get("id", "")]).to_lower()
	for pair: Array in [["well", "well"], ["grave", "gravestone"], ["crypt", "gravestone"], ["lantern", "lantern_post"],
			["lamp", "lantern_post"], ["shelf", "bookshelf"], ["bookcase", "bookshelf"], ["bed", "bed"], ["table", "table"],
			["barrel", "barrel"], ["crate", "crate"], ["stall", "market_stall"], ["cart", "wagon"], ["wagon", "wagon"],
			["tree", "dead_tree"]]:
		if key.contains(str(pair[0])):
			return str(pair[1])
	return ""


static func _build_lights(view: LocationView) -> void:
	for l: Variant in view.loc.get("lights", []):
		var li := l as Dictionary
		var omni := CandleFlicker.new()
		omni.light_color = Look.color("candle")
		var dim := float(li.get("dim_ft", 20)) / 5.0
		omni.omni_range = maxf(2.0, dim)
		omni.base_energy = 1.4 if str(li["kind"]) in ["candle", "lamp"] else 2.2
		omni.position = view.board.cell_center(LocationView._cell(li["cell"])) + Vector3(0, 1.2, 0)
		view.add_child(omni)
		if str(li.get("kind", "")) == "torch" and ModelPiece.for_art(view.board, "torch") != "":
			ModelPiece.stand(view.board, view.board, ModelPiece.for_art(view.board, "torch"), "torch", LocationView._cell(li["cell"]))   # 3D (docs/art/models.md)
			omni.position.y = 1.9
		elif str(li.get("kind", "")) == "torch" and SetDressing.has_art("torch"):
			view.board.prop_sprite("torch", view.board.cell_center(LocationView._cell(li["cell"])))
			omni.position.y = 1.9
		elif str(li.get("kind", "")) in ["fire", "bonfire", "brazier", "torch"]:
			_flame(view, LocationView._cell(li["cell"]), 0.6 if str(li["kind"]) != "torch" else 0.35)


## A flame with a flicker of its own (watch fires, braziers, the burning wicker sun): the flame billboard where the
## art exists (SetDressing.flame), else a small emissive cone.
static func _flame(view: LocationView, cell: Vector2i, size: float) -> Node3D:
	var root := Node3D.new()
	root.position = view.board.cell_center(cell)
	view.add_child(root)
	var art := SetDressing.flame(size)
	if art != null:
		root.add_child(art)
	for i in (0 if art != null else 3):
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = size * (0.45 - i * 0.12)
		cm.height = size * (1.2 - i * 0.25)
		mi.mesh = cm
		mi.position = Vector3(0, cm.height / 2.0, 0)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Look.color(["ember", "flame", "wick"][i])
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mi.material_override = mat
		root.add_child(mi)
	var light := CandleFlicker.new()
	light.light_color = Look.color("flame")
	light.omni_range = 4.0 + size * 4.0
	light.base_energy = 1.8 + size
	light.position = Vector3(0, size, 0)
	root.add_child(light)
	return root


static func _box(view: LocationView, size: Vector3, pos: Vector3, colour: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = Look.cel(colour)
	view.add_child(mi)
	return mi
