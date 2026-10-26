extends Node3D
## make capture SCENE=res://tools/capture/area_map_capture.tscn NAME=area_map FRAMES=10
## The map screen's local area view (Ashwin, 2026-10-25): the toggle on the valley's map, then the village, a walled town, a
## house and a mountain camp as the local area, each way out named by where it goes, so a change to the view can be shown
## before and after. LOCATIONS=a,b picks other places.

const PLACES: Array[String] = ["village_of_barovia", "vallaki", "death_house_ground", "argynvostholt"]

var st: StoryState


func _ready() -> void:
	InputActions.ensure()
	GameState.reset()
	st = GameState.story
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		st.party.append(ch)
	for id: String in PLACES:
		st.visited[id] = true
	st.visited["into_the_mists_road"] = true


func capture_shots(tool: Node, out: String) -> void:
	var places := PLACES
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--locations="):
			places = [] as Array[String]
			for p in arg.get_slice("=", 1).split(",", false):
				places.append(p)
	var first := true
	for id in places:
		st.location = id
		var view := LocationView.create(id, st, Narrator.new(), Dice.roller, "default")
		add_child(view)
		var screen := TravelScreen.new()
		screen.area_view = view
		add_child(screen)
		screen.open_map(st, Travel.place_for_location(id), false)
		await tool.call("wait_frames", 20)
		if first:
			first = false
			tool.call("_shot", "%s_0_valley_with_toggle.png" % out)
		screen.set_area_mode(true)
		await tool.call("wait_frames", 20)
		tool.call("_shot", "%s_%s.png" % [out, id])
		var area := screen.get("_area") as AreaMap
		if not area.exits.is_empty():
			area.pick(str(area.exits[0]["id"]))
			await tool.call("wait_frames", 6)
			tool.call("_shot", "%s_%s_picked.png" % [out, id])
		screen.queue_free()
		view.queue_free()
		await tool.call("wait_frames", 4)
