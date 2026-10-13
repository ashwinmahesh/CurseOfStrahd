extends Node3D
## make capture SCENE=res://tools/capture/smite_crit_capture.tscn NAME=smite_crit FRAMES=10
## Owner asks, 2026-10-13: Divine Smite's prompt on a Critical Hit (the red line, each slot's dice doubled) beside an
## ordinary hit's; a foe's tooltip once the hero is out of attacks ("No Action or attacks left", not "out of reach"); and
## an attack's tooltip with the target's Hit Points, as a spell's shows them.

var e: Encounter
var view: CombatView
var rig: CameraRig
var heroes: Dictionary = {}
var zombie: Combatant


func _ready() -> void:
	InputActions.ensure()
	ModeController.force(ModeController.Mode.COMBAT)
	(load("res://world/combat/combat_arena.gd") as GDScript).build_environment(self)
	e = TestCombat.open_field()
	var cells := {"godrick_pendlebrook": Vector2i(4, 3), "ilse_varga": Vector2i(4, 5)}
	for id: String in cells:
		heroes[id] = TestCombat.hero(e, id, cells[id] as Vector2i, 5)
	zombie = TestCombat.foe(e, "zombie", Vector2i(5, 4))
	zombie.creature.hp = 200   # standing through the hits
	TestCombat.foe(e, "zombie", Vector2i(9, 2))
	TestCombat.start_with(e, heroes["godrick_pendlebrook"] as Combatant)
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
	var god := heroes["godrick_pendlebrook"] as Combatant
	var melee := ""
	for o in e.attack_options(god):
		if bool(o["melee"]) and melee == "":
			melee = str(o["id"])
	# Godrick's melee weapon on a natural 20, then on an ordinary hit: the prompt each time.
	for shot: Array in [[20, "0_smite_crit"], [15, "1_smite_hit"]]:
		e.turn_index = e.order.find(god)
		e._begin_turn()
		view.hud.shown = god
		view.hud.refresh()
		TestCombat.next_d20(e, int(shot[0]))
		e.attack(god, zombie, melee)
		if e.pending == null or e.pending.kind != CombatFeatures.DIVINE_SMITE:
			push_warning("smite_crit_capture: no Divine Smite prompt (%s)" % [e.pending.kind if e.pending != null else "nothing"])
			continue
		view.mode = CombatView.Mode.PROMPT
		view.hud.show_prompt(e.pending)
		await tool.call("wait_frames", 8)
		tool.call("_shot", "%s_%s.png" % [out, str(shot[1])])
		view.hud.hide_prompt()
		while e.pending != null:
			e.answer_reaction(false)
	# Ilse beside the zombie: her greatsword's tooltip with its Hit Points, then with her attacks used up.
	var ilse := heroes["ilse_varga"] as Combatant
	zombie.creature.hp = mini(11, zombie.creature.max_hp())   # hurt, within its own Hit Points again
	for shot: Array in [[false, "2_attack_hp"], [true, "3_no_attacks_left"]]:
		e.turn_index = e.order.find(ilse)
		e._begin_turn()
		view.hud.shown = ilse
		view.hud.set_tab(ActionCatalog.COMMON)
		if bool(shot[0]):
			ilse.action_available = false
			ilse.attacks_left = 0
		view.hud.refresh()
		view.mode = CombatView.Mode.IDLE
		view.set("_reach", view.catalog.move_reach(ilse))
		view.hover_token = view.tokens[zombie.id] as CombatToken
		view.hover_cell = zombie.cell
		view.using_pad = true
		view.hover_world = (view.tokens[zombie.id] as Node3D).global_position
		rig.follow = view.tokens[zombie.id] as Node3D
		rig.snap_to_target()
		await tool.call("wait_frames", 4)
		view._update_hover()
		await tool.call("wait_frames", 6)
		tool.call("_shot", "%s_%s.png" % [out, str(shot[1])])
		view.using_pad = false
		view.hover_token = null
		view.hover_cell = Vector2i(-1, -1)
		view._update_hover()
