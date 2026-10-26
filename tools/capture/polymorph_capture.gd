extends Node3D
## make capture SCENE=res://tools/capture/polymorph_capture.tscn NAME=polymorph/shot FRAMES=10
## Polymorphed figures (owner, 2026-10-13: "When an enemy or character is polymorphed, their sprite should reflect their
## transformed shape"): a scout and Hedda as drawn (<out>_1_before.png); the scout a rat and Hedda a giant constrictor
## snake, their rings, names and health bars at the beasts' size (<out>_2_polymorphed.png); both themselves again once
## the casters' Concentration ends (<out>_3_after.png); and every Beast form Polymorph offers, side by side, as the
## board draws it on a creature that becomes it (<out>_4_forms.png).

var e: Encounter
var view: CombatView
var rig: CameraRig
var board: ArenaBoard
var wizard: Combatant
var druid: Combatant
var hedda: Combatant
var scout: Combatant
var _focus: Node3D


func _ready() -> void:
	InputActions.ensure()
	ModeController.force(ModeController.Mode.COMBAT)
	(load("res://addons/dnd_core/world/combat/combat_arena.gd") as GDScript).build_environment(self)
	var rows: Array = []
	for z in 12:
		rows.append("................")
	e = TestCombat.encounter(rows)
	wizard = TestCombat.high_caster(e, ["polymorph"], Vector2i(3, 7))
	druid = TestCombat.high_caster(e, ["polymorph"], Vector2i(3, 4))
	hedda = TestCombat.hero(e, "hedda_ironvow", Vector2i(6, 3))
	scout = TestCombat.foe(e, "scout", Vector2i(9, 7))
	TestCombat.foe(e, "zombie", Vector2i(11, 5))
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
	rig.distance = 15.0
	rig.camera.current = true
	rig.camera.add_child(Look.make_post_process())
	view = CombatView.new()
	view.input_locked = true
	add_child(view)
	view.begin(e, board, rig, tokens)
	_focus = Node3D.new()
	add_child(_focus)
	_look(Vector2(8, 6))


func _look(p: Vector2) -> void:
	_focus.position = Vector3(p.x, 0, p.y)
	rig.follow = _focus
	rig.snap_to_target()


## The camera back on the four (the fight's own camera follows whoever acts), with the names shown.
func _frame() -> void:
	rig.distance = 15.0
	_look(Vector2(7, 7))
	_names(true)


func _names(on: bool) -> void:
	for id: String in view.tokens:
		var tok := view.tokens[id] as CombatToken
		if is_instance_valid(tok):
			tok._label.visible = on


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 90)
	_frame()
	await tool.call("wait_frames", 10)
	tool.call("_shot", "%s_1_before.png" % out)
	TestCombat.next_d20(e, 1)
	e.spells.cast(wizard, "polymorph", 4, [scout], Vector2.INF, Vector2.ZERO, {"choice": "rat"})
	await view._play_events()
	e.turn_index = e.order.find(druid)
	e._begin_turn()
	e.spells.cast(druid, "polymorph", 4, [hedda], Vector2.INF, Vector2.ZERO, {"choice": "giant_constrictor_snake"})
	await view._play_events()
	view.hud.hide_tooltip()
	_frame()
	await tool.call("wait_frames", 60)
	tool.call("_shot", "%s_2_polymorphed.png" % out)
	wizard.creature.concentration.end("capture")
	druid.creature.concentration.end("capture")
	await view._play_events()
	_frame()
	await tool.call("wait_frames", 60)
	tool.call("_shot", "%s_3_after.png" % out)
	await _forms(tool, out)


## Every form Polymorph offers, eight to a shot (<out>_4_forms_<n>.png), weakest first: each a scout turned into it, in a
## line across the screen.
func _forms(tool: Node, out: String) -> void:
	view.queue_free()
	for child in get_children():
		if child is CombatToken or child is ArenaBoard:
			child.queue_free()
	var forms := ShapeChange.beast_forms(30.0)
	var rows: Array = []
	for z in 34:
		rows.append(".".repeat(34))
	var shot := 0
	for from in range(0, forms.size(), 8):
		shot += 1
		var e2 := TestCombat.encounter(rows)
		var b2 := ArenaBoard.build(e2.grid)
		add_child(b2)
		var made: Array[Node] = [b2]
		# Side by side, as close as the biggest of the eight allows.
		var step := 1
		for i in range(from, mini(from + 8, forms.size())):
			step = maxi(step, CombatGrid.size_cells_for(StringName(str(forms[i].get("size", "medium")))))
		for i in range(from, mini(from + 8, forms.size())):
			var k := i - from
			var c := TestCombat.foe(e2, "scout", Vector2i(2 + k * step, 30 - k * step))
			e2.shapes.transform(c, forms[i], {"temp_hp": 1, "label": "Polymorph"})
			var tok := CombatToken.create(c)
			tok.position = b2.cell_center(c.cell, c.size_cells)
			add_child(tok)
			tok._label.text = "%s (CR %s)" % [forms[i]["name"], SpellSpecials._cr_text(float(forms[i]["cr"]))]
			tok._label.visible = true
			made.append(tok)
		rig.distance = 1.0 + step * 10.0
		_look(Vector2(2.5 + 3.5 * step, 30.5 - 3.5 * step))
		await tool.call("wait_frames", 45)
		tool.call("_shot", "%s_4_forms_%d.png" % [out, shot])
		for n in made:
			n.queue_free()
		await tool.call("wait_frames", 2)
