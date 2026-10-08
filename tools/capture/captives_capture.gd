extends Node
## F13 for captures, in the Wachterhaus cellar: Lady Wachter's cultists who threw down their weapons (the Surrendered
## chips on their tokens), then the captives' conversation after the fight with its choices.
## make capture SCENE=res://tools/capture/captives_capture.tscn NAME=captives FRAMES=30

var root: Node


func _ready() -> void:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "kip_smudgewick"]:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "vallaki_wachter_house"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _shoot(tool: Node, path: String) -> void:
	await tool.call("wait_frames", 12)
	tool.call("_shot", path)


func capture_shots(tool: Node, out: String) -> void:
	var view := root.get("view") as LocationView
	await tool.call("wait_frames", 20)
	(root.get("hud") as ExploreHud).close_narration()
	view.start_encounter("wachter_cellar_cult")
	await tool.call("wait_frames", 40)
	var e := view.combat_view.e
	for c in e.combatants:
		if c.side != &"enemy":
			continue
		if str((c.creature as Monster).data.get("id", "")) == "cultist":
			c.creature.hp = c.creature.max_hp() / 2
			AiTactics.surrender(e, c)
		(view.combat_view.call("_tok", c.id) as CombatToken).refresh()
	view.rig.follow = view.combat_view.call("_tok", e.combatants.filter(func(c: Combatant) -> bool: return c.side == &"enemy")[0].id) as Node3D
	await _shoot(tool, out + "_1_surrendered.png")
	for c in e.combatants:
		if c.side == &"enemy" and not c.creature.has_flag("surrendered"):
			c.creature.take_damage(500, &"slashing")
	e._check_over()
	view.combat_view.finished.emit("victory")
	await tool.call("wait_frames", 20)
	var d := root.get("dialogue") as DialogueUI
	if d == null:
		return
	for i in 8:
		if not d.options_shown.is_empty():
			break
		d.call("_advance")
		await tool.call("wait_frames", 3)
	await _shoot(tool, out + "_2_conversation.png")
