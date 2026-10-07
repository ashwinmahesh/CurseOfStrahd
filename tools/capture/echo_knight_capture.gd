extends Node3D
## make capture SCENE=res://tools/capture/echo_knight_capture.tscn NAME=echo_knight FRAMES=10
## The Echo Knight: its echoes as ghostly copies of the knight (Legion of One keeps two), the class tab's echo
## actions, a blow struck from an echo's space, and Shadow Martyr's prompt when a ghoul goes for an ally.

var e: Encounter
var knight: Combatant
var foe: Combatant
var ghoul: Combatant
var ally: Combatant
var view: CombatView
var rig: CameraRig
var board: ArenaBoard


func _ready() -> void:
	InputActions.ensure()
	ModeController.force(ModeController.Mode.COMBAT)
	(load("res://world/combat/combat_arena.gd") as GDScript).build_environment(self)
	e = TestCombat.open_field()
	var ch := TestChars.custom("fighter", "human", 18, {"fighter_subclass": ["echo_knight"]})
	ch.name = "Vasha"
	knight = e.add(ch, &"party", Vector2i(2, 3))
	foe = TestCombat.foe(e, "zombie", Vector2i(7, 3))
	ghoul = TestCombat.foe(e, "ghoul", Vector2i(8, 5))
	ally = TestCombat.hero(e, "ilse_varga", Vector2i(7, 6))
	TestCombat.start_with(e, knight)
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
	rig.snap_to_target()


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 150)
	view._choose(view.catalog.find(knight, "feat:ek:manifest_echo"))
	view.hover_cell = Vector2i(5, 3)
	view._target_hover(knight, null, Vector2(950, 400))
	await tool.call("wait_frames", 5)
	tool.call("_shot", out + "_1_aim.png")
	view._confirm_target(knight, null)
	await tool.call("wait_frames", 120)
	knight.bonus_available = true
	view._choose(view.catalog.find(knight, "feat:ek:manifest_echo"))
	view.hover_cell = Vector2i(4, 5)
	view._confirm_target(knight, null)
	await tool.call("wait_frames", 120)
	_frame()
	await tool.call("wait_frames", 30)
	tool.call("_shot", out + "_2_two_echoes.png")
	view.hud.set_tab(view.catalog.class_tab(knight))
	view.hud.refresh()
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_3_class_tab.png")
	var echo := e.echo_knight.echoes(knight)[0]
	view._perform(view.catalog.find(knight, "feat:ek:echo_move:" + echo.id), [], Vector2(6.5, 3.5), Vector2.ZERO)
	await tool.call("wait_frames", 90)
	var attack := {}
	for a in view.catalog.actions_for(knight):
		if str(a["kind"]) == "attack" and bool(a["legal"]) and view.catalog.target_why(knight, a, foe) == "":
			attack = a
			break
	print("echo knight capture: attack %s, echo at %s, zombie hp %d" % [str(attack.get("id", "none")), str(echo.cell), foe.creature.hp])
	view._perform(attack, [foe], Vector2.INF, Vector2.ZERO)
	_frame()
	await tool.call("wait_frames", 14)
	tool.call("_shot", out + "_4_strike_from_echo.png")
	await tool.call("wait_frames", 90)
	print("echo knight capture: zombie hp %d, knight at %s" % [foe.creature.hp, str(knight.cell)])
	tool.call("_shot", out + "_5_after.png")
	# The ghoul's turn: it claws at Ilse, and Vasha can send an echo to take the blow.
	e.end_turn()
	while e.current() != ghoul:
		e.end_turn()
	var r := e.monster_attack(ghoul, ally, "claw")
	print("echo knight capture: ghoul attack paused on %s" % (r.pending.kind if r.pending != null else "nothing"))
	if e.pending != null:
		view.hud.show_prompt(e.pending)
	_frame()
	await tool.call("wait_frames", 40)
	tool.call("_shot", out + "_6_shadow_martyr.png")
	if e.pending != null:
		view.hud.hide_prompt()
		e.answer_reaction(true)
		view._play_events()
		await tool.call("wait_frames", 120)
		tool.call("_shot", out + "_7_martyred.png")


## The camera on the knight, its echoes and the foes.
func _frame() -> void:
	rig.follow = null
	rig.position = board.cell_center(Vector2i(5, 4), 1)
	rig.distance = 15.0
