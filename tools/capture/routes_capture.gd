extends Node
## People walking their routes (NpcRoutes, F2): Vallaki's main street by morning, two shots a few seconds apart, then
## the Vistani camp. make capture SCENE=res://tools/capture/routes_capture.tscn NAME=routes FRAMES=30

var root: Node


func _start(location: String, cells: Array[Vector2i]) -> void:
	if root != null:
		root.queue_free()
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = location
	GameState.story.minute_of_day = 9 * 60
	GameState.story.set_flag("vallaki_arrived")
	GameState.story.positions = cells
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _ready() -> void:
	_start("vallaki", [Vector2i(27, 17), Vector2i(26, 17), Vector2i(27, 16), Vector2i(26, 16)])


func _shoot(tool: Node, path: String) -> void:
	await tool.call("wait_frames", 10)
	tool.call("_shot", path)


func capture_shots(tool: Node, out: String) -> void:
	(root.get("hud") as ExploreHud).close_narration()
	await tool.call("wait_frames", 240)
	await _shoot(tool, out + "_1_vallaki.png")
	await tool.call("wait_frames", 300)
	await _shoot(tool, out + "_2_vallaki_later.png")
	_start("vallaki_vistani_camp", [Vector2i(10, 17), Vector2i(9, 17), Vector2i(10, 18), Vector2i(9, 18)])
	await tool.call("wait_frames", 20)
	(root.get("hud") as ExploreHud).close_narration()
	await tool.call("wait_frames", 300)
	await _shoot(tool, out + "_3_vistani_camp.png")
