extends Node3D
## make capture SCENE=res://tools/capture/creature_sizes_capture.tscn NAME=sizes/sheet FRAMES=10
## Every creature the board draws as a foe, a summon or a shape (DrawnCreatures), by size category, each on its squares
## (outlined) with a Medium hero (Ilse) beside it, PER_SHOT to a shot (<out>_<n>_<size>.png), so a figure too small or
## too big for its squares shows (owner, 2026-10-14: "make sure every enemy sprite is sized correctly when laid out in
## the world"). SIZES_ONLY="id,id" (environment) shoots just those creatures. The last shot (<out>_<n>_board.png) is the
## board resizing figures in a fight: an ogre as drawn, one Enlarged to Huge, one back from Banishment, and Ilse riding
## an otherworldly steed.

## Creatures to a shot (three for Large and up).
const PER_SHOT := 5
const HERO := "ilse_varga"

var rig: CameraRig
var _focus: Node3D


func _ready() -> void:
	InputActions.ensure()
	ModeController.force(ModeController.Mode.COMBAT)
	(load("res://addons/dnd_core/world/combat/combat_arena.gd") as GDScript).build_environment(self)
	rig = CameraRig.new()
	add_child(rig)
	rig.camera.current = true
	rig.camera.add_child(Look.make_post_process())
	_focus = Node3D.new()
	add_child(_focus)


## [{label, size, data | art, height}] in size order, smallest drawn first within a size.
func _cast() -> Array[Dictionary]:
	var only := OS.get_environment("SIZES_ONLY").split(",", false)
	var all: Array[Dictionary] = []
	for b in DrawnCreatures.blocks():
		b["height"] = DrawnCreatures.drawn_height(b["data"] as Dictionary)
		all.append(b)
	for s in DrawnCreatures.shapes():
		s["height"] = CombatToken.height_for(str(s["art"]))
		all.append(s)
	if not only.is_empty():
		all = all.filter(func(x: Dictionary) -> bool: return str(x["id"]) in only)
	# By size, then the smallest drawn first; or SIZES_ONLY's order, so a before and an after shoot match.
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := DrawnCreatures.SIZES.find(str(a["size"]))
		var sb := DrawnCreatures.SIZES.find(str(b["size"]))
		if sa != sb:
			return sa < sb
		if not only.is_empty():
			return only.find(str(a["id"])) < only.find(str(b["id"]))
		return float(a["height"]) < float(b["height"]))
	return all


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 30)
	var cast := _cast()
	var shot := 0
	var i := 0
	while i < cast.size():
		var size := str(cast[i]["size"])
		var group: Array[Dictionary] = []
		var per := PER_SHOT if DrawnCreatures.SIZES.find(size) < 3 else 3
		while i < cast.size() and str(cast[i]["size"]) == size and group.size() < per:
			group.append(cast[i])
			i += 1
		shot += 1
		await _shoot(tool, group, "%s_%02d_%s.png" % [out, shot, size])
	await _board_shot(tool, "%s_%02d_board.png" % [out, shot + 1])


## One row: each creature on its squares, the hero on the square to its left, the row running across the screen.
func _shoot(tool: Node, group: Array[Dictionary], path: String) -> void:
	var cells := CombatGrid.size_cells_for(StringName(str(group[0]["size"])))
	var step := cells + 2
	var n := group.size()
	var span := n * step + 4
	var rows: Array = []
	for z in span:
		rows.append(".".repeat(span))
	var e := TestCombat.encounter(rows)
	var board := ArenaBoard.build(e.grid)
	add_child(board)
	var made: Array[Node] = [board]
	for k in n:
		var g := group[k]
		var at := Vector2i(2 + k * step, span - 2 - cells - k * step)
		var c: Combatant
		if g.has("data"):
			c = e.add(Monster.from_data(g["data"] as Dictionary), &"enemy", at)
		else:
			var d := {"id": str(g["id"]).get_slice("/", 1), "name": str(g["label"]), "size": str(g["size"]), "art": str(g["art"]),
				"type": "beast", "ac": 10, "hp": {"average": 10, "dice": "10"}, "speed": {"walk": 30}}
			c = e.add(Monster.from_data(d), &"enemy", at)
		var hero := TestCombat.hero(e, HERO, at + Vector2i(-1, cells))
		for who: Combatant in [c, hero]:
			var tok := CombatToken.create(who)
			tok.position = board.cell_center(who.cell, who.size_cells)
			tok.face(Vector2(1, 1), false)
			add_child(tok)
			tok._label.visible = who == c
			if who == c:
				tok._label.text = "%s %.2f" % [str(g["id"]), float(g["height"])]
			made.append(tok)
			made.append(_outline(board, who.cell, who.size_cells, Look.color("candle") if who == hero else Look.color("crimson")))
	# The row runs along the board's diagonal; the camera sees about its own distance across.
	rig.distance = maxf(12.0, 1.15 * ((n - 1) * step + cells + 1) * sqrt(2.0))
	_focus.position = board.cell_center(Vector2i(2 + (n - 1) * step / 2, span - 2 - cells - (n - 1) * step / 2), cells)
	rig.follow = _focus
	rig.snap_to_target()
	await tool.call("wait_frames", 40)
	tool.call("_shot", path)
	for node in made:
		node.queue_free()
	await tool.call("wait_frames", 2)


## A thin frame round the squares a creature holds.
func _outline(board: ArenaBoard, cell: Vector2i, size: int, colour: Color) -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = colour
	var centre := board.cell_center(cell, size)
	var half := size / 2.0
	for side in 4:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(size, 0.03, 0.05) if side < 2 else Vector3(0.05, 0.03, size)
		mi.mesh = bm
		mi.material_override = mat
		var off := [Vector3(0, 0, -half), Vector3(0, 0, half), Vector3(-half, 0, 0), Vector3(half, 0, 0)][side] as Vector3
		mi.position = Vector3(centre.x, centre.y + 0.03, centre.z) + off
		root.add_child(mi)
	add_child(root)
	return root


## A fight's board resizing figures (CombatToken.size_scale, CombatView._token_spot): an ogre as drawn, an ogre Enlarged
## to Huge (half again as big), an ogre back from Banishment (as it was), Ilse riding a Large steed (on its back).
func _board_shot(tool: Node, path: String) -> void:
	var rows: Array = []
	for z in 16:
		rows.append(".".repeat(16))
	var e := TestCombat.encounter(rows)
	var hero := TestCombat.hero(e, HERO, Vector2i(2, 9))
	var steed := e.add(Monster.from_data(SummonBlocks.otherworldly_steed(2, "celestial", 5, 13)), &"party", Vector2i(3, 9))
	var plain := TestCombat.foe(e, "ogre", Vector2i(5, 5))
	var grown := TestCombat.foe(e, "ogre", Vector2i(8, 3))
	var back := TestCombat.foe(e, "ogre", Vector2i(12, 2))
	TestCombat.start_with(e, hero)
	var board := ArenaBoard.build(e.grid)
	add_child(board)
	var tokens := {}
	for c in e.combatants:
		var tok := CombatToken.create(c)
		tok.position = board.cell_center(c.cell, c.size_cells)
		tok.face(Vector2(1, 1), false)
		add_child(tok)
		tokens[c.id] = tok
	var view := CombatView.new()
	view.input_locked = true
	add_child(view)
	view.begin(e, board, rig, tokens)
	e.mount(hero, steed)
	grown.creature.size = &"huge"
	grown.size_cells = 3
	e.events.append({"type": "resize", "id": grown.id})
	(tokens[back.id] as CombatToken).hide()
	e.events.append({"type": "teleport", "id": back.id, "to": back.cell})
	await view._play_events()
	for c: Combatant in [plain, grown, back]:
		var lt := tokens[c.id] as CombatToken
		lt._label.visible = true
		lt._label.text = {plain: "ogre", grown: "ogre Enlarged to Huge", back: "ogre back from Banishment"}[c]
	rig.distance = 22.0
	_focus.position = board.cell_center(Vector2i(7, 6))
	rig.follow = _focus
	rig.snap_to_target()
	await tool.call("wait_frames", 60)
	tool.call("_shot", path)
