extends Node3D
## make capture SCENE=res://tools/capture/reaction_choice_capture.tscn NAME=reaction_choice FRAMES=10
## A hero with two Reactions on one prompt (owner report 2026-10-12): Godrick built as in the owner's game, with the
## Protection fighting style and Sentinel, beside Kip as a zombie swings at him: Protection, or Sentinel if the attack
## hits, then the same prompt with Sentinel picked.

var e: Encounter
var view: CombatView


func _ready() -> void:
	InputActions.ensure()
	ModeController.force(ModeController.Mode.COMBAT)
	(load("res://world/combat/combat_arena.gd") as GDScript).build_environment(self)
	e = TestCombat.open_field()
	var kip := TestCombat.hero(e, "kip_smudgewick", Vector2i(4, 4), 6)
	var g := e.add(_godrick(), &"party", Vector2i(4, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(5, 4))
	TestCombat.foe(e, "zombie", Vector2i(8, 2))
	TestCombat.start_with(e, z)
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
	rig.distance = 11.0
	rig.camera.current = true
	rig.camera.add_child(Look.make_post_process())
	view = CombatView.new()
	view.input_locked = true
	add_child(view)
	view.begin(e, board, rig, tokens)
	rig.follow = tokens[g.id] as Node3D
	rig.snap_to_target()
	e.attack(z, kip, "monster:slam")


## Godrick at level 6 as the owner built him: Protection at level 2, Sentinel at level 4.
func _godrick() -> Character:
	var comp := Compendium.shared()
	var data := comp.get_entry("pregens", "godrick_pendlebrook").duplicate(true)
	for step: Dictionary in data["level_plan"]:
		var picks := step.get("choices", {}) as Dictionary
		if picks.has("paladin.2.fighting_style"):
			picks["paladin.2.fighting_style"] = ["protection"]
		if picks.has("paladin.4.ability_score_improvement"):
			picks.erase("paladin.4.ability_score_improvement/ability_score_improvement.abilities")
			picks["paladin.4.ability_score_improvement"] = ["sentinel"]
			picks["paladin.4.ability_score_improvement/sentinel.abilities"] = ["str"]
	(comp.tables["pregens"] as Dictionary)["godrick_pendlebrook"] = data
	var ch := TestChars.pregen("godrick_pendlebrook", 6)
	ch.heroic_inspiration = false
	return ch


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 120)
	view.mode = CombatView.Mode.PROMPT
	view.hud.show_prompt(e.pending)
	await tool.call("wait_frames", 8)
	tool.call("_shot", "%s_1_protection.png" % out)
	var sentinel := (view.hud.get("_prompt_targets") as Node).get_child(1) as CheckButton
	sentinel.button_pressed = true
	await tool.call("wait_frames", 8)
	tool.call("_shot", "%s_2_sentinel.png" % out)
