extends Node3D
## make capture SCENE=res://tools/capture/combat_hud_capture.tscn NAME=combat_hud FRAMES=10
## The combat HUD's hotbar for four level 5 heroes on an open field (Combat HUD Plan, the owner's BG3 audit, 2026-10-09):
## Ilse's Common and Fighter tabs, Godrick's Paladin, Spells and Reactions tabs, Thistle's Common and Tamsin's Rogue tab,
## and Command's choices open at its slot, so a change to the hotbar can be shown before and after.

var e: Encounter
var view: CombatView
var rig: CameraRig
var heroes: Dictionary = {}


func _ready() -> void:
	InputActions.ensure()
	ModeController.force(ModeController.Mode.COMBAT)
	(load("res://world/combat/combat_arena.gd") as GDScript).build_environment(self)
	e = TestCombat.open_field()
	var cells := {"ilse_varga": Vector2i(3, 2), "godrick_pendlebrook": Vector2i(3, 4), "thistle": Vector2i(2, 3), "tamsin_tealeaf": Vector2i(2, 5)}
	for id: String in cells:
		heroes[id] = TestCombat.hero(e, id, cells[id] as Vector2i, 5)
	for cell: Vector2i in [Vector2i(8, 2), Vector2i(9, 4), Vector2i(8, 6)]:
		TestCombat.foe(e, "zombie", cell)
	TestCombat.start_with(e, heroes["ilse_varga"] as Combatant)
	var board := ArenaBoard.build(e.grid)
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
	rig.snap_to_target()


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 150)
	var shots: Array = [["ilse_varga", ActionCatalog.COMMON, "1_ilse_common"], ["ilse_varga", "", "2_ilse_class"],
		["godrick_pendlebrook", "", "3_godrick_class"], ["godrick_pendlebrook", ActionCatalog.SPELLS, "4_godrick_spells"],
		["thistle", ActionCatalog.COMMON, "5_thistle_common"], ["tamsin_tealeaf", "", "6_tamsin_class"],
		["godrick_pendlebrook", ActionCatalog.REACTIONS, "7_godrick_reactions"]]
	for shot: Variant in shots:
		var s := shot as Array
		var c := heroes[str(s[0])] as Combatant
		if e.current() != c:
			e.turn_index = e.order.find(c)
			e._begin_turn()
		view.hud.shown = c
		view.hud.set_tab(str(s[1]) if str(s[1]) != "" else view.catalog.class_tab(c))
		view.hud.refresh()
		await tool.call("wait_frames", 8)
		tool.call("_shot", "%s_%s.png" % [out, str(s[2])])
	# A container open at its slot: Command's words.
	var god := heroes["godrick_pendlebrook"] as Combatant
	view.hud.shown = god
	view.hud.set_tab(ActionCatalog.SPELLS)
	view.hud.refresh()
	await tool.call("wait_frames", 4)
	for i in view.hud.slot_count():
		if str(view.hud.slot_action(i).get("label", "")) == "Command":
			view.hud.use_slot(i)
	await tool.call("wait_frames", 6)
	tool.call("_shot", "%s_8_command_open.png" % out)
