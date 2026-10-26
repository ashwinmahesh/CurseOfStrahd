extends Node
## The followed quest at the top right of the exploring HUD (its name above its objective): the Blue Water Inn with the
## newest open quest followed, then a quest with the longest name and objective at the biggest interface and text sizes.
## make capture SCENE=res://tools/capture/hud_quest_capture.tscn NAME=hud_quest FRAMES=40

var root: Node


func _ready() -> void:
	GameState.reset()
	GameSettings.set_value("turn_based", false, false)
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 4)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "vallaki_blue_water_inn"
	GameState.story.set_quest_stage("escort_ireena", "asked")
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func capture_shots(tool: Node, out: String) -> void:
	var hud := root.get("hud") as ExploreHud
	hud.close_narration()
	root.call("_refresh")
	await tool.call("wait_frames", 30)
	tool.call("_shot", out + "_1_followed.png")
	var st := GameState.story
	st.set_quest_stage("mothers_ninth_improvement", "rumored")
	QuestLog.track(st, "mothers_ninth_improvement")
	GameSettings.set_ui_scale(GameSettings.UI_SCALES.back())
	GameSettings.set_text_scale(GameSettings.TEXT_SCALES.back())
	root.call("_refresh")
	await tool.call("wait_frames", 30)
	tool.call("_shot", out + "_2_longest_largest.png")
