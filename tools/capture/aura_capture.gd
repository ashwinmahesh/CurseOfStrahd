extends Node
## Auras round figures (world/look/aura_fx.gd, owner 2026-10-09): Strahd's dark aura and a level 6 paladin's glow.
## make capture SCENE=res://tools/capture/aura_capture.tscn NAME=aura/after FRAMES=10 [ARGS="--day"]
## Godrick (level 6, so he has Aura of Protection) leads the party in the village at night with Strahd beside them:
## exploring (<out>_explore.png), as in a fight with the paladin's area on the floor (<out>_fight.png), Strahd mid-surge
## (<out>_surge.png), close on the two of them (<out>_close.png), and three seconds of them filmed (<out>_film_NNN.jpg).

var root: Node


func _ready() -> void:
	Look.set_style("modern", false)
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 6)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.minute_of_day = (11 if "--day" in OS.get_cmdline_user_args() else 22) * 60
	GameState.story.location = "village_of_barovia"
	for c: Dictionary in Cutscenes.all():
		Cutscenes.mark_played(str(c["id"]), GameState.story)   # the arrival picture would cover the shots
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func capture_shots(tool: Node, out: String) -> void:
	var hud := root.get("hud") as ExploreHud
	var view := root.get("view") as LocationView
	view.input_locked = true
	await tool.call("wait_frames", 45)
	hud.close_narration()
	var lead := view.leader()
	var strahd := CombatToken.create(Combatant.new(Monster.from_data(Compendium.shared().monster_data("strahd_von_zarovich")),
		&"enemy", lead.cell + Vector2i(3, -1)))
	view.add_child(strahd)
	strahd.position = view.board.cell_center(strahd.combatant.cell)
	strahd.face(Vector2(-1, 0.4), false)
	view.rig.distance = 11.0
	await tool.call("wait_frames", 60)
	tool.call("_shot", out + "_explore.png")
	var was := ModeController.mode
	ModeController.mode = ModeController.Mode.COMBAT
	await tool.call("wait_frames", 20)
	tool.call("_shot", out + "_fight.png")
	strahd.start_cast(Vector2(-1, 0.4))
	await tool.call("wait_frames", 6)
	tool.call("_shot", out + "_surge.png")
	ModeController.mode = was
	view.rig.distance = 6.5
	await tool.call("wait_frames", 70)
	tool.call("_shot", out + "_close.png")
	# Three seconds of the two of them at 12 frames a second (<out>_film_NNN.jpg), to see the auras move.
	var start := Time.get_ticks_msec()
	var next := 0.0
	var n := 0
	while next < 3.0:
		await get_tree().process_frame
		if (Time.get_ticks_msec() - start) / 1000.0 < next:
			continue
		get_viewport().get_texture().get_image().save_jpg("%s_film_%03d.jpg" % [out, n], 0.9)
		n += 1
		next += 1.0 / 12.0
