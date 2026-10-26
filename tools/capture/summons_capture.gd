extends Node3D
## What a fight shows of the things spells call up (the art-fixes lane's before and after): Hedda's Guardian of Faith
## standing where she called it, a Dinosaur Spirit (Summon Dinosaur) and a Plant Spirit (Summon Plant) beside her party,
## zombies closing in. make capture SCENE=res://tools/capture/summons_capture.tscn NAME=art-fixes/summons FRAMES=10

var rig: CameraRig
var _focus: Node3D


func _ready() -> void:
	InputActions.ensure()
	ModeController.force(ModeController.Mode.COMBAT)
	(load("res://addons/dnd_core/world/combat/combat_arena.gd") as GDScript).build_environment(self)
	rig = CameraRig.new()
	add_child(rig)
	rig.camera.current = true
	rig.camera.add_child(Look.make_post_process())
	_focus = Node3D.new()
	add_child(_focus)


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 30)
	var rows: Array = []
	for z in 16:
		rows.append(".".repeat(18))
	var e := TestCombat.encounter(rows)
	var hedda := TestCombat.caster_with(e, ["guardian_of_faith"], Vector2i(4, 9), 9, "hedda_ironvow")
	TestCombat.hero(e, "godrick_pendlebrook", Vector2i(3, 6), 9)
	e.add(Monster.from_data(SummonBlocks.for_spell("summon_dinosaur", 6, "triceratops", {})), &"party", Vector2i(5, 12))
	e.add(Monster.from_data(SummonBlocks.for_spell("summon_plant", 5, "tree", {})), &"party", Vector2i(8, 12))
	var zombie := TestCombat.foe(e, "zombie", Vector2i(12, 5))
	TestCombat.foe(e, "zombie", Vector2i(13, 7))
	TestCombat.foe(e, "zombie", Vector2i(12, 9))
	TestCombat.start_with(e, hedda)
	var board := ArenaBoard.build(e.grid)
	add_child(board)
	var tokens := {}
	for c in e.combatants:
		var tok := CombatToken.create(c)
		tok.position = board.cell_center(c.cell, c.size_cells)
		tok.face(Vector2(1, 1), false)
		add_child(tok)
		tokens[c.id] = tok
	var view := CombatView.new()
	view.input_locked = true
	add_child(view)
	view.begin(e, board, rig, tokens)
	var cast := e.spells.cast(hedda, "guardian_of_faith", 4, [], Vector2(9.5, 7.5))
	assert(cast.ok)
	await view._play_events()
	await tool.call("wait_frames", 60)
	_focus.position = board.cell_center(Vector2i(8, 9))
	rig.follow = _focus
	rig.distance = 19.0
	rig.snap_to_target()
	await tool.call("wait_frames", 120)
	tool.call("_shot", out + "_hud.png")
	view.hud.visible = false
	await tool.call("wait_frames", 4)
	tool.call("_shot", out + "_board.png")
	# The first zombie to come within reach is struck: the guardian turns to it and swings.
	var guardian := e.spells.zones.object_of(hedda.id, "guardian_of_faith")
	e.spells.zones._affect(guardian, zombie, "enter", CombatResult.new(), {})
	view.field.sync(e.spells.zones.objects)
	await tool.call("wait_frames", 14)
	tool.call("_shot", out + "_strike.png")
