class_name SkirmishField
extends RefCounted
## Dresses a Skirmish fight on a location's map (N1) the way the story shows that place: its mood (sky, fog, light,
## weather, the land around it) by Atmosphere, its furniture, chests and ways out by SetDressing, and its lamps and
## fires. Doors stand open and nobody else is there: the fight is the only thing happening. The arena map keeps the
## arena's own night (CombatArena.build_environment).


## Builds the place's look under `root` on `board`; `time` is "day" or "night" outdoors. Returns the Atmosphere (the
## camera attaches to it), or null when `loc` is empty.
static func dress(root: Node3D, board: ArenaBoard, loc_id: String, loc: Dictionary, time: String) -> Atmosphere:
	if loc.is_empty():
		return null
	var atmosphere := Atmosphere.create(loc_id, loc, board)
	root.add_child(atmosphere)
	var outdoors := bool((loc.get("map", {}) as Dictionary).get("outdoors", false))
	atmosphere.set_phase(("day" if time == "day" else "night") if outdoors else "any")
	var st := StoryState.new()
	for ex: Variant in loc.get("exits", []):
		SetDressing.exit_piece(board, ex as Dictionary)
	for p: Variant in loc.get("props", []):
		var prop := p as Dictionary
		if str(prop.get("kind", "")) == "search" or not StoryConditions.check(str(prop.get("when", "")), st):
			continue
		if SetDressing.place(board, prop) == null:
			var art := LocationBuilder._prop_art(prop)
			if art != "":
				board.prop_sprite(art, board.cell_center(_cell(prop["cell"])), 0.8)
	for c: Variant in loc.get("containers", []):
		var ct := c as Dictionary
		if StoryConditions.check(str(ct.get("when", "")), st):
			SetDressing.place(board, ct, true)
	for l: Variant in loc.get("lights", []):
		_light(root, board, l as Dictionary)
	return atmosphere


## A lamp, torch or fire: its flickering light, and the torch or flame where there's art for it.
static func _light(root: Node3D, board: ArenaBoard, li: Dictionary) -> void:
	var cell := _cell(li["cell"])
	var kind := str(li.get("kind", ""))
	var omni := CandleFlicker.new()
	omni.light_color = Look.color("candle")
	omni.omni_range = maxf(2.0, float(li.get("dim_ft", 20)) / 5.0)
	omni.base_energy = 1.4 if kind in ["candle", "lamp"] else 2.2
	omni.position = board.cell_center(cell) + Vector3(0, 1.2, 0)
	root.add_child(omni)
	if kind == "torch" and ModelPiece.for_art(board, "torch") != "":
		ModelPiece.stand(board, board, ModelPiece.for_art(board, "torch"), "torch", cell)
		omni.position.y = 1.9
	elif kind == "torch" and SetDressing.has_art("torch"):
		board.prop_sprite("torch", board.cell_center(cell))
		omni.position.y = 1.9
	elif kind in ["fire", "bonfire", "brazier"]:
		var art := SetDressing.flame(0.6)
		if art != null:
			art.position = board.cell_center(cell)
			root.add_child(art)


static func _cell(v: Variant) -> Vector2i:
	var a := v as Array
	return Vector2i(int(a[0]), int(a[1]))
