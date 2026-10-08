extends Node3D
## make capture SCENE=res://tools/capture/object_actions_capture.tscn NAME=object_actions FRAMES=10
## What creatures do with the battlefield's objects (F5 piece 3): Ilse shoves a crate off a raised dais onto a zombie
## below; Hedda pulls a bookcase down off the wall onto a ghoul; Silvain's Fire Bolt sets a table alight, and as the
## round ends the fire spreads to the spilled oil and the settee beside it; as the next one ends, the burning oil
## reaches a barrel of lamp oil and it bursts.

const ROWS: Array[String] = [
	"################",
	"#.......===....#",
	"#..............#",
	"#222...........#",
	"#222...........#",
	"#222...........#",
	"#..............#",
	"#.....==.......#",
	"#..............#",
	"#..............#",
	"#..............#",
	"################"]
const CRATE := Vector2i(3, 4)
const CASE := Vector2i(9, 1)
const TABLE := Vector2i(7, 7)
const SETTEE := Vector2i(6, 7)
const OIL := Vector2i(8, 7)
const BARREL := Vector2i(9, 7)

var e: Encounter
var board: ArenaBoard
var rig: CameraRig
var view: CombatView
var tokens := {}
var ilse: Combatant
var hedda: Combatant
var silvain: Combatant
var zombie: Combatant
var ghoul: Combatant
var crate: BattleObject
var barrel: BattleObject


func _ready() -> void:
	InputActions.ensure()
	ModeController.force(ModeController.Mode.COMBAT)
	(load("res://world/combat/combat_arena.gd") as GDScript).build_environment(self)
	e = TestCombat.encounter(ROWS, 5)
	board = ArenaBoard.build(e.grid, "manor")
	add_child(board)
	# A crate on the dais's edge and a barrel of lamp oil by the table, drawn as the board draws its own pieces; the
	# board's '=' squares are its bookcases, sideboards, table and settee (BattleScenery).
	crate = _stand("crate", CRATE, "crate")
	barrel = _stand("oil_barrel", BARREL, "barrel")
	BattleScenery.from_board(e, board)
	e.objects.squares.append({"cell": OIL, "oil": true, "lit": false, "hit": {}})
	ilse = TestCombat.hero(e, "ilse_varga", Vector2i(2, 4))
	hedda = TestCombat.hero(e, "hedda_ironvow", Vector2i(9, 2))
	silvain = TestCombat.caster_with(e, ["fire_bolt"], Vector2i(5, 9), 3)
	zombie = TestCombat.foe(e, "zombie", Vector2i(4, 4))
	ghoul = TestCombat.foe(e, "ghoul", Vector2i(9, 3))
	e.start()
	var turn_order: Array[Combatant] = [ilse, hedda, silvain, zombie, ghoul]
	for i in turn_order.size():
		turn_order[i].initiative = 30 - i
	e.order.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.initiative > b.initiative)
	e.turn_index = 0
	e._begin_turn()
	for o in e.objects.list:
		print("object actions capture: %s %s on %s (%s)" % [o.id, o.kind, str(o.cells), o.art])
	for c in e.combatants:
		var token := CombatToken.create(c)
		token.position = board.cell_center(c.cell, c.size_cells)
		token.face(Vector2(1, 0) if c.side == &"party" else Vector2(-1, 0), false)
		add_child(token)
		tokens[c.id] = token
	rig = CameraRig.new()
	add_child(rig)
	rig.zoom_max = 30.0
	rig.distance = 15.0
	rig.camera.current = true
	rig.camera.add_child(Look.make_post_process())
	view = CombatView.new()
	view.input_locked = true
	add_child(view)
	view.begin(e, board, rig, tokens)
	rig.snap_to_target()


## An object of `kind` on `cell` with `art` standing there, recorded as the square's dressing (the view moves and wrecks it).
func _stand(kind: String, cell: Vector2i, art: String) -> BattleObject:
	var piece := SetDressing.stand_piece(board, board, art, cell)
	board.dressing[cell] = [piece]
	var one: Array[Vector2i] = [cell]
	return e.objects.add(kind, one, {"art": art})


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 150)
	# 1. Ilse shoves the crate off the dais: it falls on the zombie below and breaks.
	_frame(Vector2(3.5, 3.5), 13.5)
	e.dice.reseed(_seed_for(ilse, func(e2: Encounter) -> void: e2.objects.actions.shove(e2.get_c(ilse.id), crate.id),
		func(e2: Encounter) -> bool: return e2.get_c(zombie.id).creature.has_condition(&"prone")))
	view._perform(_line(view.catalog.square_actions(ilse, CRATE), "act:shove:" + crate.id), [], Vector2.INF, Vector2.ZERO)
	await tool.call("wait_frames", 80)
	_frame(Vector2(3.5, 3.5), 13.5)
	await tool.call("wait_frames", 8)
	tool.call("_shot", out + "_1_shoved_off_the_dais.png")
	print("object actions capture: crate broken %s, zombie hp %d, prone %s" % [str(crate.destroyed), zombie.creature.hp, str(zombie.creature.has_condition(&"prone"))])
	# 2. Hedda pulls the bookcase down off the wall onto the ghoul (she steps clear).
	e.end_turn()
	view._advance()
	await tool.call("wait_frames", 20)
	var case := e.objects.blocking_at(CASE)
	print("object actions capture: by the wall %s" % (case.kind if case != null else "nothing"))
	if case != null:
		e.dice.reseed(_seed_for(hedda, func(e2: Encounter) -> void: e2.objects.actions.topple(e2.get_c(hedda.id), case.id),
			func(e2: Encounter) -> bool: return e2.get_c(ghoul.id).creature.has_condition(&"prone")))
		view._perform(_line(view.catalog.square_actions(hedda, CASE), "act:topple:" + case.id), [], Vector2.INF, Vector2.ZERO)
	_frame(Vector2(9.5, 3.0), 11.0)
	await tool.call("wait_frames", 80)
	_frame(Vector2(9.5, 3.0), 11.0)
	await tool.call("wait_frames", 8)
	tool.call("_shot", out + "_2_bookcase_pulled_down.png")
	print("object actions capture: ghoul hp %d, prone %s" % [ghoul.creature.hp, str(ghoul.creature.has_condition(&"prone"))])
	# 3. Silvain's Fire Bolt sets the table alight; as the round ends the fire spreads to the oil and the settee.
	e.end_turn()
	view._advance()
	await tool.call("wait_frames", 20)
	var table := e.objects.blocking_at(TABLE)
	TestCombat.next_d20(e, 19)
	if table != null:
		view._perform(_line(view.catalog.square_actions(silvain, TABLE), "act:object:%s:spell:fire_bolt" % table.id), [], Vector2.INF, Vector2.ZERO)
	await tool.call("wait_frames", 90)
	print("object actions capture: table %s burning %s" % [table.kind if table != null else "none", str(table != null and table.burning)])
	var settee := e.objects.blocking_at(SETTEE)
	if settee != null:
		e.dice.reseed(_seed_for(silvain, _end_round, func(e2: Encounter) -> bool: return e2.objects.get_object(settee.id).burning))
	_end_round(e)
	e.events.clear()
	view._refresh_all()
	_frame(Vector2(7.5, 7.5), 11.0)
	await tool.call("wait_frames", 40)
	tool.call("_shot", out + "_3_fire_spreads.png")
	print("object actions capture: oil lit %s, settee burning %s" % [str(bool(e.objects.square_at(OIL).get("lit", false))), str(settee != null and settee.burning)])
	# 4. As the next round ends the burning oil reaches the barrel of lamp oil: it bursts.
	_end_round(e)
	_object_events()
	_frame(Vector2(7.5, 7.5), 11.0)
	view._play_events()
	await tool.call("wait_frames", 16)
	tool.call("_shot", out + "_4_barrel_bursts.png")
	await tool.call("wait_frames", 120)
	print("object actions capture: barrel burst %s" % str(barrel.destroyed))


## Ends turns until a new round begins (as the round ends, fire spreads: ObjectFire.spread).
func _end_round(enc: Encounter) -> void:
	var r := enc.round_no
	for guard in 12:
		if enc.round_no != r or enc.pending != null:
			break
		enc.end_turn()


## Keeps only the objects' events for the view to play (the turns that passed meanwhile needn't be shown).
func _object_events() -> void:
	var kept: Array[Dictionary] = []
	for ev in e.events:
		if str(ev.get("type", "")).begins_with("object_"):
			kept.append(ev)
	e.events.assign(kept)


## A seed for the dice that makes `wanted` come true when `act` is tried on a copy of the fight on `who`'s turn (only so
## the shot shows its outcome at its clearest); else the first d20 of 15 or more.
func _seed_for(who: Combatant, act: Callable, wanted: Callable) -> int:
	var snap := JSON.parse_string(JSON.stringify(EncounterSnapshot.capture(e))) as Dictionary
	for s in range(1, 400):
		var e2 := EncounterSnapshot.restore(snap, DiceRoller.new(s))
		e2.turn_index = e2.order.find(e2.get_c(who.id))
		e2.dice.reseed(s)
		act.call(e2)
		if bool(wanted.call(e2)):
			print("object actions capture: seed %d" % s)
			return s
	return TestChars.seed_for_d20(15)


## The square menu line `id` among `items`, as an action ({} if it isn't there).
func _line(items: Array[Dictionary], id: String) -> Dictionary:
	for it in items:
		if str(it["id"]) == id:
			return it.get("action", {}) as Dictionary
	print("object actions capture: no line %s" % id)
	return {}


## The camera on `at` (grid units), `dist` away.
func _frame(at: Vector2, dist: float) -> void:
	rig.follow = null
	rig.position = Vector3(at.x, 0, at.y)
	rig.distance = dist
