extends Node3D
## make capture SCENE=res://tools/capture/item_spells_hotbar_capture.tscn NAME=item_spells_hotbar FRAMES=10
## The spells items give, on the combat hotbar (Ashwin, 2026-10-24): Liriel (Cleric 9) with an attuned Staff of Healing on her
## Spells and Items tabs, and Ilse (Fighter 5, no spells of her own) with a Circlet of Blasting on her Spells tab, so a change
## to where an item's spells sit can be shown before and after.

var e: Encounter
var view: CombatView
var rig: CameraRig
var heroes: Dictionary = {}


func _ready() -> void:
	InputActions.ensure()
	ModeController.force(ModeController.Mode.COMBAT)
	(load("res://world/combat/combat_arena.gd") as GDScript).build_environment(self)
	e = TestCombat.open_field()
	heroes["liriel_dawnsong"] = TestCombat.hero(e, "liriel_dawnsong", Vector2i(3, 3), 9)
	heroes["ilse_varga"] = TestCombat.hero(e, "ilse_varga", Vector2i(3, 5), 5)
	for cell: Vector2i in [Vector2i(8, 2), Vector2i(9, 4)]:
		TestCombat.foe(e, "zombie", cell)
	var liriel := (heroes["liriel_dawnsong"] as Combatant).creature as Character
	liriel.add_item("staff_of_healing__quarterstaff")
	liriel.equip("staff_of_healing__quarterstaff", "main_hand")
	liriel.attune("staff_of_healing__quarterstaff")
	var ilse := (heroes["ilse_varga"] as Combatant).creature as Character
	ilse.add_item("circlet_of_blasting")
	ilse.equip("circlet_of_blasting", "head")
	TestCombat.start_with(e, heroes["liriel_dawnsong"] as Combatant)
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
	for shot: Array in [["liriel_dawnsong", ActionCatalog.SPELLS, "1_liriel_spells"], ["liriel_dawnsong", ActionCatalog.ITEMS, "2_liriel_items"],
			["ilse_varga", ActionCatalog.SPELLS, "3_ilse_spells"], ["ilse_varga", ActionCatalog.ITEMS, "4_ilse_items"]]:
		var c := heroes[str(shot[0])] as Combatant
		if e.current() != c:
			e.turn_index = e.order.find(c)
			e._begin_turn()
		view.hud.shown = c
		view.hud.set_tab(str(shot[1]))
		view.hud.refresh()
		await tool.call("wait_frames", 8)
		tool.call("_shot", "%s_%s.png" % [out, str(shot[2])])
		# The rest of a long tab, under the first rows.
		var scroll := view.hud.get("_slot_scroll") as ScrollContainer
		if scroll.get_v_scroll_bar().max_value > scroll.size.y + 4.0:
			scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
			await tool.call("wait_frames", 4)
			tool.call("_shot", "%s_%s_end.png" % [out, str(shot[2])])
			scroll.scroll_vertical = 0
