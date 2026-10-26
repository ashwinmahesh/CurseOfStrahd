extends Node3D
## make capture SCENE=res://tools/capture/area_aim_capture.tscn NAME=area_aim/shot FRAMES=10
## Areas placed at a point, centred on the pointer (owner, 2026-10-13: "when selecting for radius AOE spells (fireball,
## slow, etc), the pointer should be at the middle of the area"): a level 7 wizard's Fireball and Slow aimed with the
## pointer on the middle of one square (<out>_1_fireball.png, <out>_2_slow.png), then Slow placed, with the foes in its
## cube picked to start (<out>_3_slow_choose.png) and the ally added in place of one of them (<out>_4_slow_picked.png).
## The pointer's square is marked by a small figure-less ring (the capture has no mouse): the outline's middle sits on it.

var e: Encounter
var view: CombatView
var rig: CameraRig
var board: ArenaBoard
var wizard: Combatant
var ally: Combatant
var foes: Array[Combatant] = []
var _focus: Node3D

## The square the pointer is on in every shot (its middle).
const POINTER := Vector2(10.5, 5.5)


func _ready() -> void:
	InputActions.ensure()
	ModeController.force(ModeController.Mode.COMBAT)
	(load("res://addons/dnd_core/world/combat/combat_arena.gd") as GDScript).build_environment(self)
	var rows: Array = []
	for z in 12:
		rows.append("..................")
	e = TestCombat.encounter(rows)
	var ch := TestChars.custom("wizard", "human", 7)
	var prepared := (ch.spellcasting[0] as Dictionary)["prepared"] as Array
	for id: String in ["fireball", "slow"]:
		if not id in prepared:
			prepared.append(id)
	ch.finish_long_rest()
	wizard = e.add(ch, &"party", Vector2i(2, 5))
	ally = TestCombat.hero(e, "hedda_ironvow", Vector2i(9, 6), 6)
	for cell: Vector2i in [Vector2i(8, 3), Vector2i(11, 4), Vector2i(12, 7), Vector2i(10, 8), Vector2i(13, 5), Vector2i(7, 7), Vector2i(12, 2)]:
		foes.append(TestCombat.foe(e, "zombie", cell))
	TestCombat.start_with(e, wizard)
	board = ArenaBoard.build(e.grid)
	add_child(board)
	var tokens := {}
	for c in e.combatants:
		var token := CombatToken.create(c)
		token.position = board.cell_center(c.cell, c.size_cells)
		add_child(token)
		tokens[c.id] = token
	rig = CameraRig.new()
	add_child(rig)
	rig.distance = 18.0
	rig.camera.current = true
	rig.camera.add_child(Look.make_post_process())
	view = CombatView.new()
	view.input_locked = true
	add_child(view)
	view.begin(e, board, rig, tokens)
	_focus = Node3D.new()
	add_child(_focus)
	_focus.position = Vector3(POINTER.x, 0, POINTER.y)
	rig.follow = _focus
	rig.snap_to_target()


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 120)
	await _aim(tool, "%s_1_fireball.png" % out, "fireball")
	view._cancel_targeting()
	await _aim(tool, "%s_2_slow.png" % out, "slow")
	# A click there places the cube: the foes in it are picked to start.
	view._confirm_target(wizard, null)
	_point_at()
	view._update_hover()
	view.overlay.show_cells("goal", [Vector2i(floori(POINTER.x), floori(POINTER.y))])
	_look()
	await tool.call("wait_frames", 20)
	tool.call("_shot", "%s_3_slow_choose.png" % out)
	# Drop one zombie, add the ally.
	view.picker.pick(foes[0].cell, foes[0])
	view.picker.pick(ally.cell, ally)
	view.hover_cell = ally.cell
	view._update_hover()
	_look()
	await tool.call("wait_frames", 20)
	tool.call("_shot", "%s_4_slow_picked.png" % out)


## The camera on the pointer's square, from far enough back to see the whole area above the hotbar, with the area's
## saves panel and the tooltip put away so the floor shows.
func _look() -> void:
	view.hud.hide_area_saves()
	view.hud.hide_tooltip()
	rig.distance = 21.0
	_focus.position = Vector3(POINTER.x, 0, POINTER.y + 2.5)
	rig.follow = _focus
	rig.snap_to_target()


func _point_at() -> void:
	view.using_pad = true
	view.hover_token = null
	view.hover_world = Vector3(POINTER.x, 0.0, POINTER.y)
	view.hover_cell = Vector2i(floori(POINTER.x), floori(POINTER.y))


func _aim(tool: Node, path: String, spell_id: String) -> void:
	view.hud.shown = wizard
	view.hud.set_tab(ActionCatalog.SPELLS)
	view.hud.refresh()
	view.mode = CombatView.Mode.IDLE
	var a := view.catalog.find(wizard, "spell:" + spell_id)
	if a.is_empty() or not bool(a["legal"]):
		push_warning("area_aim_capture: %s can't be cast (%s)" % [spell_id, str(a.get("reason", "not known"))])
		return
	view._choose(a)
	_point_at()
	view._update_hover()
	_look()
	# Where the pointer is (the capture has no mouse): a small ring on its square.
	view.overlay.show_cells("goal", [view.hover_cell])
	await tool.call("wait_frames", 20)
	tool.call("_shot", path)
