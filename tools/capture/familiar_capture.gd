extends Node
## make capture SCENE=res://tools/capture/familiar_capture.tscn NAME=familiar FRAMES=10
## A summoned familiar in a real location fight (EncounterSetup.bring_familiars): Silvain's owl beside him as the
## fight starts, then the map after the fight with no owl left standing on it.

const LOC := {
	"id": "capture_den", "name": "Capture Den", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"##########",
		"#........#",
		"#........#",
		"#........#",
		"#........#",
		"##########"], "light": "dim"},
	"spawns": {"default": [3, 2]},
	"encounters": [{"id": "rats", "trigger": "manual",
		"monsters": [{"monster": "rat", "cell": [7, 2]}, {"monster": "rat", "cell": [7, 4]}]}],
}


func capture_shots(tool: Node, out: String) -> void:
	Compendium.shared().tables["locations"]["capture_den"] = LOC.duplicate(true)
	GameState.reset()
	for id: String in ["silvain_aster", "godrick_pendlebrook", "thistle"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.party[0].familiar = "here"
	GameState.story.location = "capture_den"
	var game := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await tool.call("wait_frames", 20)
	var view := game.get("view") as LocationView
	view.start_encounter("rats")
	await tool.call("wait_frames", 40)
	tool.call("_shot", out + "_1_fight.png")
	view.combat_view.finished.emit("victory")
	await tool.call("wait_frames", 40)
	tool.call("_shot", out + "_2_after.png")
