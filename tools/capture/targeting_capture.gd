extends Node3D
## make capture SCENE=res://tools/capture/targeting_capture.tscn NAME=targeting FRAMES=10
## F10's picks after the first (TargetPicker): a Wall of Fire drawn square by square, the side it burns on, the wall
## cast, then Commander's Strike's ally and the foe the ally attacks.

var e: Encounter
var caster: Combatant
var fighter: Combatant
var ally: Combatant
var near_foe: Combatant
var view: CombatView
var rig: CameraRig
var board: ArenaBoard
var tokens := {}


func _ready() -> void:
	InputActions.ensure()
	ModeController.force(ModeController.Mode.COMBAT)
	(load("res://world/combat/combat_arena.gd") as GDScript).build_environment(self)
	e = TestCombat.open_field()
	e.default_player_reaction = "never"
	caster = TestCombat.caster_with(e, ["wall_of_fire"], Vector2i(1, 2))
	var bm := TestChars.custom("fighter", "human", 3, {"fighter_subclass": ["battle_master"],
		"combat_superiority": ["commanders_strike", "maneuvering_attack", "trip_attack"]})
	bm.name = "Ardeth"
	fighter = e.add(bm, &"party", Vector2i(2, 5))
	ally = TestCombat.hero(e, "hedda_ironvow", Vector2i(6, 5))
	near_foe = TestCombat.foe(e, "zombie", Vector2i(7, 5))
	TestCombat.foe(e, "zombie", Vector2i(10, 1))
	TestCombat.foe(e, "zombie", Vector2i(10, 4))
	# The caster first, then the Battle Master, then the rest.
	e.start()
	for c in e.order:
		c.initiative = 30 if c == caster else (25 if c == fighter else 1)
	e.order.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.initiative > b.initiative)
	e.turn_index = 0
	e._begin_turn()
	board = ArenaBoard.build(e.grid)
	add_child(board)
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
	_frame()
	# Wall of Fire at 4th level: a click on its first square, a click further along the line adds the squares between,
	# then a diagonal step.
	view._choose(view.catalog.find(caster, "spell:wall_of_fire"), 4)
	for cell: Vector2i in [Vector2i(8, 0), Vector2i(8, 3), Vector2i(9, 4)]:
		view.hover_cell = cell
		view._confirm_target(caster, null)
	view.hover_cell = Vector2i(9, 5)
	view._target_hover(caster, null, Vector2(980, 420))
	await tool.call("wait_frames", 20)
	print("targeting capture: drawing step %s, path %s" % [view.picker.step, str(view.picker.path)])
	tool.call("_shot", out + "_1_drawing.png")
	# A click on the last square ends the drawing; then the side it burns on (toward the zombies).
	view.hover_cell = Vector2i(9, 4)
	view._confirm_target(caster, null)
	view.hover_cell = Vector2i(10, 2)
	view._target_hover(caster, null, Vector2(980, 420))
	await tool.call("wait_frames", 20)
	print("targeting capture: side step %s" % view.picker.step)
	tool.call("_shot", out + "_2_burning_side.png")
	view._confirm_target(caster, null)
	await tool.call("wait_frames", 150)
	view.hover_cell = Vector2i(-1, -1)
	view.hud.hide_tooltip()
	_frame()
	await tool.call("wait_frames", 20)
	tool.call("_shot", out + "_3_wall_cast.png")
	# The Battle Master's turn: Commander's Strike picks Hedda, then the zombie she strikes.
	e.end_turn()
	view._advance()
	await tool.call("wait_frames", 60)
	view._choose(view.catalog.find(fighter, "feat:commanders_strike"))
	view.hover_cell = ally.cell
	view._confirm_target(fighter, tokens[ally.id] as CombatToken)
	view.hover_cell = near_foe.cell
	view._target_hover(fighter, tokens[near_foe.id] as CombatToken, Vector2(980, 420))
	_frame_on(Vector2i(5, 5), 12.0)
	await tool.call("wait_frames", 20)
	print("targeting capture: strike step %s, current %s" % [view.picker.step, e.current().name()])
	tool.call("_shot", out + "_4_strike_pick.png")


## The camera over the field between the party and the zombies.
func _frame() -> void:
	_frame_on(Vector2i(6, 3), 15.0)


func _frame_on(cell: Vector2i, distance: float) -> void:
	rig.follow = null
	rig.position = board.cell_center(cell, 1)
	rig.distance = distance
