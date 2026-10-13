extends Node
## What a Search finds glows orange (world/exploration/found_glow.gd) for captures: one place per run, in one look. The
## party searches from a few spots with dice that roll high; each search is shot as it lands (<out>_<stop>_found.png,
## the pulse) and a few seconds on (<out>_<stop>_steady.png), then everything found from further out (<out>_all.png).
## make capture SCENE=res://tools/capture/found_glow_capture.tscn NAME=found_glow/after FRAMES=10 \
##   ARGS="--look=classic --place=death_house_upper"
## Places: death_house_upper (a dark house at night: a hollow book, the study's secret door, a rotten floorboard) and
## into_the_mists_road (outdoors: a severed head, a shrine's board, a wolf trap; --day for noon, else night).

## Where the party stands to search, per place: [cell, name, the square the camera looks at, camera turns (rotate_step:
## 2 looks from the north-east, so a south wall is behind what's found), camera distance]. The hollow book lies behind
## the library's cut-away west wall from the usual camera: it shows through.
const STOPS := {
	"death_house_upper": [[Vector2i(2, 4), "book", Vector2i(2, 3), 0, 8.0],
		[Vector2i(4, 7), "door", Vector2i(4, 9), 2, 8.0], [Vector2i(12, 6), "trap", Vector2i(12, 8), 0, 8.0]],
	"into_the_mists_road": [[Vector2i(22, 15), "road", Vector2i(21, 15), 0, 13.0]],
}
## Where the camera looks for the last shot, per place: [cell, distance].
const OVERVIEW := {"death_house_upper": [Vector2i(7, 5), 17.0], "into_the_mists_road": [Vector2i(22, 15), 14.0]}


## Every die rolls its highest, so each Search finds what's near.
class Loaded extends DiceRoller:
	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		var out: Array[int] = []
		for i in count:
			out.append(sides)
		_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
		return out


var root: Node
var place := "death_house_upper"


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.get_slice("=", 1)
	place = str(args.get("place", place))
	Look.set_style(str(args.get("look", "modern")), false)
	GameState.reset()
	# Nobody who casts Guidance, so each Search is rolled at once.
	for id: String in ["ilse_varga", "tamsin_tealeaf", "silvain_aster", "godrick_pendlebrook"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.minute_of_day = (12 if "--day" in OS.get_cmdline_user_args() else 23) * 60
	GameState.story.location = place
	GameState.story.visited[place] = true
	for c: Dictionary in Cutscenes.all():
		Cutscenes.mark_played(str(c["id"]), GameState.story)   # no arrival picture in the way
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func capture_shots(tool: Node, out: String) -> void:
	var hud := root.get("hud") as ExploreHud
	var view := root.get("view") as LocationView
	view.input_locked = true
	view.dice = Loaded.new()
	await tool.call("wait_frames", 30)
	hud.close_narration()
	var look_at := Node3D.new()
	view.add_child(look_at)
	view.rig.follow = look_at
	for stop: Array in STOPS[place]:
		LocationChecks._move_party(view, stop[0] as Vector2i)
		look_at.position = view.board.cell_center(stop[2] as Vector2i)
		view.rig.rotate_step(int(stop[3]))
		view.rig.distance = float(stop[4])
		view.rig.snap_to_target()
		await tool.call("wait_frames", 40)
		view.search()
		await get_tree().create_timer(0.3).timeout
		hud.close_narration()   # what's found, not the narrator's box over it
		await get_tree().create_timer(0.15).timeout
		tool.call("_shot", "%s_%s_found.png" % [out, stop[1]])
		await get_tree().create_timer(3.0).timeout
		hud.close_narration()   # a party member's aside, if one came
		await tool.call("wait_frames", 2)
		tool.call("_shot", "%s_%s_steady.png" % [out, stop[1]])
		view.rig.rotate_step(-int(stop[3]))
	var o: Array = OVERVIEW[place]
	look_at.position = view.board.cell_center(o[0] as Vector2i)
	view.rig.distance = float(o[1])
	view.rig.snap_to_target()
	await tool.call("wait_frames", 60)
	hud.close_narration()
	await tool.call("wait_frames", 2)
	tool.call("_shot", out + "_all.png")

