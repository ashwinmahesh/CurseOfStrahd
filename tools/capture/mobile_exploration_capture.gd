extends Node3D
## Real location/minimap with isolated mobile chrome, captured offscreen without player saves.

var view: LocationView
var hud: ExploreHud


func _ready() -> void:
	var state := StoryState.new()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		state.party.append(Pregens.build(id, 1))
	state.minute_of_day = 12 * 60
	view = LocationView.create("into_the_mists_road", state, Narrator.new(), DiceRoller.new(42), "default")
	add_child(view)
	hud = ExploreHud.new()
	add_child(hud)
	hud.build(state)
	hud.show_location(view)
	hud.refresh("The Old Svalich Road", false, false, false)
	hud.narrate("The road disappears into the mist. This narration stays in the menu until you choose to read it.")


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 24)
	tool.call("_shot", out + "_world.png")
	hud.mobile.menu()
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_menu.png")
	hud.mobile.history()
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_messages.png")
