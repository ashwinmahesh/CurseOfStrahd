extends Node
## The party screen's approval panel (F3, ui/screens/approval_panel.gd) for captures: four of the six travelling and two
## at camp, each at a different tier with a few remembered moments, and Thistle and Wren courting. Two shots: the
## cards with their tier pills, and the panel itself.
## make capture SCENE=res://tools/capture/approval_capture.tscn NAME=approval FRAMES=10

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "wren_featherfoot"]
const CAMP: Array[String] = ["ratatoille", "kip_smudgewick"]
## [companion, score, [delta, why], ...]
const MOMENTS := [
	["godrick_pendlebrook", 31, [3, "You refused to give the house one of your own"], [4, "You took Ireena out of the village, away from him"],
		[-2, "You asked a grieving son what he'd pay you"], [3, "You promised two frightened children you'd find their brother"]],
	["liriel_dawnsong", 14, [5, "You brought St. Andral home to his church"], [-3, "You struck a bargain with a hag"],
		[2, "You told the Durst children the truth, gently"]],
	["thistle", 52, [3, "You opened the Abbot's cages"], [2, "You fed a raven on the road"], [3, "You found Grandda with me"]],
	["wren_featherfoot", -13, [-3, "You told Kasimir about the vestige that could buy his sister back"], [2, "You made the saddest toymaker in Barovia laugh"]],
	["ratatoille", 4, [1, "You told the Blue Water's barmaid her wine was thin"]],
	["kip_smudgewick", -31, [-5, "You let one of us take a Dark Gift from the amber"], [-2, "You lied to Bildrath about his strongbox"]],
]

var root: Node


func _ready() -> void:
	Compendium.shared().tables["locations"]["sheet_hall"] = {"id": "sheet_hall", "name": "Sheet Hall", "region": "test",
		"summary": "", "map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	var st := GameState.story
	for id in PARTY:
		var ch := Pregens.build(id, 6)
		ch.finish_long_rest()
		st.party.append(ch)
	for id in CAMP:
		st.bench.append(Pregens.build(id, 6))
	st.location = "sheet_hall"
	st.day = 9
	for m: Variant in MOMENTS:
		var row := m as Array
		var id := str(row[0])
		for e: Variant in row.slice(2):
			Approval.change(st, id, int((e as Array)[0]), str((e as Array)[1]))
		Approval.change(st, id, int(row[1]) - Approval.score(st, id))
	st.set_flag("romance_thistle_wren", "courting")
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func capture_shots(tool: Node, out: String) -> void:
	root.call("open_screen", "party", 0)
	await tool.call("wait_frames", 8)
	tool.call("_shot", "%s_party.png" % out)
	var screen := root.get("screen") as Node
	for s in screen.find_children("*", "ScrollContainer", true, false):
		var sc := s as ScrollContainer
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
	await tool.call("wait_frames", 8)
	tool.call("_shot", "%s_panel.png" % out)
	root.call("close_screen")
