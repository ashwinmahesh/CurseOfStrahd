extends Node3D
## make capture SCENE=res://tools/capture/objects_capture.tscn NAME=objects FRAMES=10
## Objects and surfaces in fights (F5 piece 2, combat/encounter_objects.gd): a storeroom's breakable things (its door,
## the crates, barrels and counters on its '=' squares, a lit chandelier hanging over a zombie, oil spilled on the
## floor) with the square menu open on a crate; the crate smashed into rubble; the chandelier shot down onto the
## zombie; Burning Hands lighting the oil and setting a barrel and a counter alight.

const ROWS: Array[String] = [
	"######.#######",
	"#............#",
	"#........==..#",
	"#............#",
	"#...==.....=.#",
	"#..........=.#",
	"#.......==...#",
	"#............#",
	"#............#",
	"##############"]
const DOOR := Vector2i(6, 0)
const CRATE := Vector2i(4, 4)

var e: Encounter
var board: ArenaBoard
var rig: CameraRig
var view: CombatView
var tokens := {}
var ilse: Combatant
var tamsin: Combatant
var silvain: Combatant
var zombie: Combatant
var bandit: Combatant
var lamp: BattleObject


func _ready() -> void:
	InputActions.ensure()
	ModeController.force(ModeController.Mode.COMBAT)
	(load("res://world/combat/combat_arena.gd") as GDScript).build_environment(self)
	e = TestCombat.encounter(ROWS, 3)
	board = ArenaBoard.build(e.grid, "shop")
	add_child(board)
	# The door is drawn as a location draws one; the '=' squares are what the board stands there (BattleScenery).
	SetDressing.door(board, {"id": "storeroom_door", "cell": [DOOR.x, DOOR.y], "label": "the storeroom door"}, false)
	var door_cells: Array[Vector2i] = [DOOR]
	e.objects.add("door_wood", door_cells, {"door_id": "storeroom_door", "name": "the storeroom door"})
	BattleScenery.from_board(e, board)
	var lamp_cells: Array[Vector2i] = [Vector2i(8, 4), Vector2i(9, 4)]
	lamp = e.objects.add("chandelier", lamp_cells, {"name": "the chandelier"})
	lamp.fall["lit"] = true
	ilse = TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	tamsin = TestCombat.hero(e, "tamsin_tealeaf", Vector2i(2, 6))
	silvain = TestCombat.caster_with(e, ["burning_hands"], Vector2i(6, 5), 3)
	zombie = TestCombat.foe(e, "zombie", lamp_cells[0])
	bandit = TestCombat.foe(e, "bandit", Vector2i(10, 5))
	# The heroes act first, in this order.
	e.start()
	var turn_order: Array[Combatant] = [ilse, tamsin, silvain, zombie, bandit]
	for i in turn_order.size():
		turn_order[i].initiative = 30 - i
	e.order.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.initiative > b.initiative)
	e.turn_index = 0
	e._begin_turn()
	# Oil someone spilled earlier, on the open floor Silvain's Burning Hands will sweep (east from his square).
	var bh := Compendium.shared().spell_data("burning_hands")
	var cone := e.spells.targeting.area_for(silvain, bh, Vector2.INF, Vector2.RIGHT, 1)
	for cell in cone:
		if not cell in lamp_cells and e.occupant_at(cell) == null and not e.grid.has_flag(cell, CombatGrid.LOW) and cell.x >= 8:
			e.objects.squares.append({"cell": cell, "oil": true, "lit": false, "hit": {}})
	for o in e.objects.list:
		print("objects capture: %s %s on %s (%s)" % [o.id, o.kind, str(o.cells), o.art])
	print("objects capture: Burning Hands covers %s" % str(cone))
	for c in e.combatants:
		var token := CombatToken.create(c)
		token.position = board.cell_center(c.cell, c.size_cells)
		token.face(Vector2(1, -1) if c.side == &"party" else Vector2(-1, 1), false)
		add_child(token)
		tokens[c.id] = token
	rig = CameraRig.new()
	add_child(rig)
	rig.zoom_max = 30.0
	rig.distance = 15.0
	rig.rotate_step(-1)   # look north-east: the party bottom-left, the storeroom's far end up the screen
	rig.camera.current = true
	rig.camera.add_child(Look.make_post_process())
	view = CombatView.new()
	view.input_locked = true
	add_child(view)
	view.begin(e, board, rig, tokens)
	rig.snap_to_target()


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 150)
	# 1. The field: the door, the crates and barrels, the chandelier, the oil; Ilse's square menu on a crate.
	_frame(Vector2(6.0, 4.0), 16.0)
	await tool.call("wait_frames", 20)
	var items := view.catalog.square_actions(ilse, CRATE)
	var shown: Array[Dictionary] = []
	for it in items:
		shown.append({"id": it["id"], "label": it["label"], "enabled": it.get("enabled", true), "why": it.get("why", "")})
	var crate := e.objects.blocking_at(CRATE)
	view.hud.open_square_menu(crate.title() if crate != null else "This square", shown, _screen(CRATE) + Vector2(60, -40))
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_1_field.png")
	view.hud._menu.hide()
	# 2. Ilse's greatsword smashes the crate: rubble.
	var smash := _line(items, "act:object:%s:attack:weapon:greatsword" % (crate.id if crate != null else ""))
	print("objects capture: smash %s" % str(smash.get("label", "none")))
	TestCombat.next_d20(e, 17)
	view._perform(smash.get("action", {}) as Dictionary, [], Vector2.INF, Vector2.ZERO)
	_frame(Vector2(4.0, 3.8), 10.0)
	await tool.call("wait_frames", 70)
	_frame(Vector2(4.0, 3.8), 10.0)
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_2_rubble.png")
	print("objects capture: crate destroyed %s, rubble %s" % [str(crate != null and crate.destroyed), str(e.grid.has_flag(CRATE, CombatGrid.DIFFICULT))])
	# 3. Tamsin's turn: an arrow through the chandelier's chain, and it comes down on the zombie.
	e.end_turn()
	view._advance()
	await tool.call("wait_frames", 20)
	var shot := _line(view.catalog.square_actions(tamsin, zombie.cell), "act:object:%s:attack:weapon:shortbow" % lamp.id)
	print("objects capture: shoot %s (%s)" % [str(shot.get("label", "none")), str(shot.get("why", ""))])
	e.dice.reseed(_prone_seed("weapon:shortbow"))
	view._perform(shot.get("action", {}) as Dictionary, [], Vector2.INF, Vector2.ZERO)
	_frame(Vector2(8.0, 4.5), 11.0)
	await tool.call("wait_frames", 75)
	_frame(Vector2(8.0, 4.5), 11.0)
	await tool.call("wait_frames", 8)
	tool.call("_shot", out + "_3_chandelier.png")
	print("objects capture: chandelier down %s, zombie hp %d, prone %s" % [str(lamp.destroyed), zombie.creature.hp, str(zombie.creature.has_condition(&"prone"))])
	await tool.call("wait_frames", 60)
	# 4. Silvain's turn: Burning Hands sweeps east, lighting the oil and the barrel and counter in its cone.
	e.end_turn()
	view._advance()
	await tool.call("wait_frames", 20)
	view.slot_level = 1
	var burn := view.catalog.find(silvain, "spell:burning_hands")
	print("objects capture: Burning Hands %s (%s)" % [str(burn.get("legal", false)), str(burn.get("reason", ""))])
	view._perform(burn, [], Vector2.INF, Vector2.RIGHT)
	_frame(Vector2(8.5, 5.5), 10.5)
	await tool.call("wait_frames", 260)
	_frame(Vector2(8.5, 5.5), 10.5)
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_4_fire.png")
	var burning: Array[String] = []
	for o in e.objects.list:
		if o.burning:
			burning.append(o.kind)
	var lit := e.objects.squares.filter(func(sq: Dictionary) -> bool: return bool(sq.get("lit", false))).size()
	print("objects capture: burning %s, lit squares %d" % [str(burning), lit])


## A seed whose first d20 is a 20 (the arrow breaks the chain) and whose falling chandelier knocks the zombie Prone:
## each tried on a copy of the fight, so the shot shows the fall at its fullest.
func _prone_seed(option_id: String) -> int:
	var snap := JSON.parse_string(JSON.stringify(EncounterSnapshot.capture(e))) as Dictionary
	for s in range(1, 4000):
		if DiceRoller.new(s).d20() != 20:
			continue
		var e2 := EncounterSnapshot.restore(snap, DiceRoller.new(s))
		e2.dice.reseed(s)
		var t2 := e2.get_c(tamsin.id)
		e2.objects._strike(t2, e2.objects.get_object(lamp.id), e2.option_by_id(t2, option_id))
		if e2.get_c(zombie.id).creature.has_condition(&"prone"):
			print("objects capture: seed %d drops the zombie" % s)
			return s
	return TestChars.seed_for_d20(20)


## The square menu line `id` from `items`, or {}.
func _line(items: Array[Dictionary], id: String) -> Dictionary:
	for it in items:
		if str(it["id"]) == id:
			return it
	return {}


## Where `cell` is on the screen.
func _screen(cell: Vector2i) -> Vector2:
	return rig.camera.unproject_position(board.cell_center(cell) + Vector3(0, 0.5, 0))


## The camera on `at` (grid units), `dist` away.
func _frame(at: Vector2, dist: float) -> void:
	rig.follow = null
	rig.position = Vector3(at.x, 0, at.y)
	rig.distance = dist
