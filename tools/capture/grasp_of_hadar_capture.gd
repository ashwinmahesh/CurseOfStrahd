extends Node3D
## make capture SCENE=res://tools/capture/grasp_of_hadar_capture.tscn NAME=grasp_of_hadar FRAMES=10
## Grasp of Hadar (Ashwin, 2026-10-13: the pull that mirrors Repelling Blast): Kip, knowing both, faces a zombie 35 ft
## off with Ilse beside it (<out>_1_before.png). The Warlock tab holds both On / Off switches, Repelling Blast On and
## Grasp of Hadar Off (<out>_2_warlock_tab.png); switching Grasp of Hadar On turns Repelling Blast Off
## (<out>_3_grasp_on.png); two beams of Eldritch Blast drag the zombie toward him (<out>_4_pulling.png), 10 ft a hit,
## out of Ilse's reach without an Opportunity Attack (<out>_5_pulled.png).

var e: Encounter
var view: CombatView
var rig: CameraRig
var board: ArenaBoard
var kip: Combatant
var zombie: Combatant
var ilse: Combatant


func _ready() -> void:
	InputActions.ensure()
	ModeController.force(ModeController.Mode.COMBAT)
	(load("res://addons/dnd_core/world/combat/combat_arena.gd") as GDScript).build_environment(self)
	var rows: Array = []
	for z in 10:
		rows.append("................")
	e = TestCombat.encounter(rows, 3)
	var ch := TestChars.pregen("kip_smudgewick", 5)
	for cd in ch.choice_defs:
		if cd.kind == "invocation" and "repelling_blast" in cd.picks:
			cd.picks.append("grasp_of_hadar")
	ch.reaction_rules.clear()
	kip = e.add(ch, &"party", Vector2i(3, 5))
	ilse = TestCombat.hero(e, "ilse_varga", Vector2i(11, 5), 5)
	zombie = TestCombat.foe(e, "zombie", Vector2i(10, 5))
	(zombie.creature as Monster).hp_max_base = 120   # it lives through both beams
	zombie.creature.hp = 120
	TestCombat.start_with(e, kip)
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
	rig.distance = 15.0
	rig.camera.current = true
	rig.camera.add_child(Look.make_post_process())
	view = CombatView.new()
	view.input_locked = true
	add_child(view)
	view.begin(e, board, rig, tokens)
	_frame()


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 150)
	_frame()
	await tool.call("wait_frames", 20)
	tool.call("_shot", out + "_1_before.png")
	view.hud.set_tab(view.catalog.class_tab(kip))
	view.hud.refresh()
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_2_warlock_tab.png")
	view._choose(view.catalog.find(kip, "feat:reaction_policy:grasp_of_hadar:auto"))
	view.hud.refresh()
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_3_grasp_on.png")
	view.hud.set_tab(ActionCatalog.SPELLS)
	view.hud.refresh()
	var blast := {}
	for a in view.catalog.actions_for(kip):
		if str(a["id"]).ends_with("eldritch_blast") and bool(a.get("legal", true)):
			blast = a
			break
	var from := zombie.cell
	TestCombat.next_d20(e, 19)
	view._perform(blast, [zombie], Vector2.INF, Vector2.ZERO)
	await tool.call("wait_frames", 45)
	tool.call("_shot", out + "_4_pulling.png")
	await tool.call("wait_frames", 150)
	_frame()
	await tool.call("wait_frames", 20)
	tool.call("_shot", out + "_5_pulled.png")
	print("grasp of hadar capture: %s, zombie %s -> %s, Ilse's Reaction %s, rules %s" % [str(blast.get("id", "none")), str(from),
		str(zombie.cell), "unspent" if ilse.reaction_available else "spent", str(kip.reaction_rules)])


## The camera over Kip, the zombie and Ilse.
func _frame() -> void:
	rig.follow = null
	rig.position = board.cell_center(Vector2i(9, 5), 1)
	rig.distance = 18.0
