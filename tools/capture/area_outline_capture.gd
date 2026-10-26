extends Node3D
## make capture SCENE=res://tools/capture/area_outline_capture.tscn NAME=area_outline/shot FRAMES=10
## Area spells aimed on an open field (owner, 2026-10-12: "for AoE spells, don't make the floor orange. Instead show a
## circular border which shows the area that would be affected"): a level 7 wizard's Fireball, Hypnotic Pattern,
## Burning Hands and Thunderwave, each as the board draws it now (<out>_<n>_<spell>.png) and with its squares painted
## orange as before (<out>_<n>_<spell>_before.png); then a level 6 paladin's Aura of Protection on the floor in a fight,
## with no glow round the figure (<out>_5_paladin_aura.png).

var e: Encounter
var view: CombatView
var rig: CameraRig
var board: ArenaBoard
var wizard: Combatant
var paladin: Combatant
var _focus: Node3D


func _ready() -> void:
	InputActions.ensure()
	ModeController.force(ModeController.Mode.COMBAT)
	(load("res://addons/dnd_core/world/combat/combat_arena.gd") as GDScript).build_environment(self)
	var rows: Array = []
	for z in 12:
		rows.append("................")
	e = TestCombat.encounter(rows)
	var ch := TestChars.custom("wizard", "human", 7)
	var prepared := (ch.spellcasting[0] as Dictionary)["prepared"] as Array
	for id: String in ["fireball", "hypnotic_pattern", "burning_hands", "thunderwave"]:
		if not id in prepared:
			prepared.append(id)
	ch.finish_long_rest()
	wizard = e.add(ch, &"party", Vector2i(4, 5))
	paladin = TestCombat.hero(e, "godrick_pendlebrook", Vector2i(3, 9), 6)
	TestCombat.hero(e, "ilse_varga", Vector2i(5, 9), 6)
	TestCombat.hero(e, "thistle", Vector2i(2, 7), 6)
	for cell: Vector2i in [Vector2i(10, 3), Vector2i(11, 5), Vector2i(12, 3), Vector2i(10, 6), Vector2i(12, 7), Vector2i(6, 4),
			Vector2i(7, 6), Vector2i(14, 5)]:
		TestCombat.foe(e, "zombie", cell)
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
	rig.distance = 12.0
	rig.camera.current = true
	rig.camera.add_child(Look.make_post_process())
	view = CombatView.new()
	view.input_locked = true
	add_child(view)
	view.begin(e, board, rig, tokens)
	_focus = Node3D.new()
	add_child(_focus)
	rig.snap_to_target()


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 120)
	# [spell, the point pointed at (x, z), where the camera looks (x, z), how far back it stands]
	var shots: Array = [["fireball", Vector2(11, 5), Vector2(11, 6), 17.0], ["hypnotic_pattern", Vector2(9.5, 4.5), Vector2(12, 6), 18.0],
		["burning_hands", Vector2(7.5, 5.5), Vector2(6, 6), 11.0], ["thunderwave", Vector2(7.5, 5.5), Vector2(6, 6), 11.0]]
	for i in shots.size():
		var s := shots[i] as Array
		rig.distance = float(s[3])
		await _aim(tool, "%s_%d_%s" % [out, i + 1, str(s[0])], str(s[0]), s[1] as Vector2, s[2] as Vector2)
	# The paladin's aura on the floor in a fight, and no glow round him.
	view.overlay.clear_all()
	view.hud.hide_tooltip()
	view.hud.hide_area_saves()
	_look_at(Vector2(3.5, 10))
	rig.distance = 10.0
	await tool.call("wait_frames", 30)
	tool.call("_shot", "%s_5_paladin_aura.png" % out)


func _look_at(p: Vector2) -> void:
	_focus.position = Vector3(p.x, 0, p.y)
	rig.follow = _focus
	rig.snap_to_target()


## Aims `spell_id` from the wizard at `point` and shoots the board as it draws it now, then with the same squares
## painted orange the way it drew them before.
func _aim(tool: Node, name: String, spell_id: String, point: Vector2, look: Vector2) -> void:
	e.turn_index = e.order.find(wizard)
	e._begin_turn()
	view.hud.shown = wizard
	view.hud.set_tab(ActionCatalog.SPELLS)
	view.hud.refresh()
	view.mode = CombatView.Mode.IDLE
	var a := view.catalog.find(wizard, "spell:" + spell_id)
	if a.is_empty() or not bool(a["legal"]):
		push_warning("area_outline_capture: %s can't be cast (%s)" % [spell_id, str(a.get("reason", "not known"))])
		return
	view._choose(a)
	view.using_pad = true
	view.hover_world = Vector3(point.x, 0.0, point.y)
	view.hover_cell = Vector2i(floori(point.x), floori(point.y))
	view._update_hover()
	_look_at(look)
	await tool.call("wait_frames", 20)
	tool.call("_shot", name + ".png")
	var dir: Vector2 = view._aim_dir(wizard)
	var pv := view.catalog.spell_preview(wizard, view.selected, view._aim_point(), dir, view.slot_level)
	view.overlay.clear_outline()
	view.overlay.show_cells("area", pv["cells"] as Array)
	await tool.call("wait_frames", 4)
	tool.call("_shot", name + "_before.png")
	view._cancel_targeting()
