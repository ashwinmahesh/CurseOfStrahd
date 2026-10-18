extends Node3D
## make capture SCENE=res://tools/capture/untrained_armor_capture.tscn NAME=untrained_armor FRAMES=10
## Liriel (a Thaumaturge Cleric, level 11) in Plate Armor +1 she has no training with: the Spell tab names the armor that
## shuts every spell (owner report 2026-10-18), then the same tab in the breastplate she is trained for, and the All tab.

var e: Encounter
var view: CombatView
var rig: CameraRig
var liriel: Combatant


func _ready() -> void:
	InputActions.ensure()
	ModeController.force(ModeController.Mode.COMBAT)
	(load("res://world/combat/combat_arena.gd") as GDScript).build_environment(self)
	e = TestCombat.open_field()
	liriel = TestCombat.hero(e, "liriel_dawnsong", Vector2i(3, 3), 11)
	(liriel.creature as Character).add_item("armor_plus_1__plate_armor")
	(liriel.creature as Character).equip("armor_plus_1__plate_armor", "armor")
	(liriel.creature as Character).add_item("breastplate")
	TestCombat.foe(e, "zombie", Vector2i(8, 3))
	TestCombat.start_with(e, liriel)
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
	view.hud.shown = liriel
	view.hud.set_tab(ActionCatalog.SPELLS)
	view.hud.refresh()
	await tool.call("wait_frames", 8)
	tool.call("_shot", "%s_1_plate_spells.png" % out)
	view.hud.set_tab(CombatHud.ALL)
	view.hud.refresh()
	await tool.call("wait_frames", 8)
	tool.call("_shot", "%s_2_plate_all.png" % out)
	var ch := liriel.creature as Character
	ch.equip("breastplate", "armor")
	view.hud.set_tab(ActionCatalog.SPELLS)
	view.hud.refresh()
	await tool.call("wait_frames", 8)
	tool.call("_shot", "%s_3_breastplate_spells.png" % out)
