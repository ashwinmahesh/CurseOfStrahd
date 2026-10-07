extends Node3D
## Reproducible supplemental spell targeting QA. No game save is read or written.
## make capture SCENE=res://tools/capture/faerun_capture.tscn NAME=faerun FRAMES=10

var e: Encounter
var winter: Combatant
var foe: Combatant
var caster: Combatant
var view: CombatView

func _ready() -> void:
	var book_content := BookContentFixture.new()
	tree_exiting.connect(book_content.restore, CONNECT_ONE_SHOT)
	InputActions.ensure()
	ModeController.force(ModeController.Mode.COMBAT)
	(load("res://world/combat/combat_arena.gd") as GDScript).build_environment(self)
	e = TestCombat.open_field()
	var ch := TestChars.custom("wizard", "human", 14, {"wizard_subclass": ["conjurer"]})
	ch.name = "Conjurer"
	(ch.spellcasting[0]["prepared"] as Array).append("summon_beast")
	caster = e.add(ch, &"party", Vector2i(3, 3))
	TestCombat.hero(e, "ilse_varga", Vector2i(3, 5))
	foe = TestCombat.foe(e, "zombie", Vector2i(7, 3))
	var ranger := TestChars.custom("ranger", "human", 15, {"ranger_subclass": ["winter_walker"]})
	ranger.name = "Winter Walker"
	winter = e.add(ranger, &"party", Vector2i(4, 3))
	TestCombat.start_with(e, caster)
	var board := ArenaBoard.build(e.grid)
	add_child(board)
	var tokens := {}
	for c in e.combatants:
		var token := CombatToken.create(c)
		token.position = board.cell_center(c.cell, c.size_cells)
		add_child(token)
		tokens[c.id] = token
	var rig := CameraRig.new()
	add_child(rig)
	rig.distance = 14.0
	rig.camera.current = true
	rig.camera.add_child(Look.make_post_process())
	view = CombatView.new()
	view.input_locked = true
	add_child(view)
	view.begin(e, board, rig, tokens)
	rig.snap_to_target()

func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 180)
	var action := view.catalog.find(caster, "spell:summon_beast:splintered")
	view._choose(action, 2)
	view.hover_cell = Vector2i(5, 3)
	view._confirm_target(caster, null)
	view.hover_cell = Vector2i(6, 5)
	view._target_hover(caster, null, Vector2(950, 400))
	await tool.call("wait_frames", 5)
	tool.call("_shot", out + "_two_spaces.png")
	view._cancel_targeting()
	await tool.call("wait_frames", 90)
	view._choose(view.catalog.find(caster, "feat:recipe:benign_transposition"))
	view.hover_cell = Vector2i(3, 5)
	view._target_hover(caster, null, Vector2(950, 400))
	await tool.call("wait_frames", 5)
	tool.call("_shot", out + "_teleport.png")

	view._cancel_targeting()
	TestCombat.start_with(e, winter)
	winter.reaction_rules["frozen_haunt_pulse"] = "ask"
	e.spells.cast(winter, "hunters_mark", 1, [foe], Vector2.INF, Vector2.ZERO, {"cast_form": "frozen_haunt"})
	view.hud.show_prompt(e.pending)
	await tool.call("wait_frames", 90)
	tool.call("_shot", out + "_frozen_haunt.png")

	e.answer_reaction(false)
	view.hud.hide_prompt()
