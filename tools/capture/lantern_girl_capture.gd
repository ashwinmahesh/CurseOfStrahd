extends Node
## The Lantern Girl (owner, 2026-10-13: "the lantern girl at the Lake doesn't have a sprite"): Lake Zarovich at night
## with the quest open, the camera on the end of the fishers' jetty where she stands, then the fight that opens when
## she turns on the party (her and her drowned lights). Not part of the game.
##   make capture SCENE=res://tools/capture/lantern_girl_capture.tscn NAME=lantern/after FRAMES=10

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]
const LOC := "lake_zarovich"
const HOME := Vector2i(18, 3)
const DEEP := Vector2i(18, 11)

var view: LocationView = null


func _ready() -> void:
	InputActions.ensure()


func capture_shots(tool: Node, out: String) -> void:
	GameState.reset()
	var st := GameState.story
	for pid in PARTY:
		var ch := Pregens.build(pid, 5)
		ch.finish_long_rest()
		st.party.append(ch)
	st.minute_of_day = 22 * 60
	st.set_quest_stage("one_lantern_too_many", "asked")
	st.location = LOC
	st.positions.clear()
	for i in st.party.size():
		st.positions.append(DEEP + [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)][i % 4])
	view = LocationView.create(LOC, st, Narrator.new(), Dice.roller, "")
	view.input_locked = true
	add_child(view)
	await tool.call("wait_frames", 20)
	_aim(HOME, 4.5)
	await tool.call("wait_frames", 12)
	tool.call("_shot", "%s_jetty_close.png" % out)
	_aim(HOME, 9.0)
	await tool.call("wait_frames", 6)
	tool.call("_shot", "%s_jetty_wide.png" % out)
	LocationNpcs.hide_npcs_of(view, "vallaki/one_lantern_too_many:girl")   # as the dialogue's combat step does
	if not view.start_encounter("lantern_girl"):
		push_warning("lantern_girl_capture: no fight lantern_girl at %s" % LOC)
		return
	await tool.call("wait_frames", 20)
	_aim(Vector2i(18, 6), 10.0)
	await tool.call("wait_frames", 12)
	tool.call("_shot", "%s_fight.png" % out)


## The camera on square `look`, `dist` away.
func _aim(look: Vector2i, dist: float) -> void:
	var rig := view.rig
	rig.follow = null
	rig.zoom_min = 3.0
	rig.distance = dist
	rig.global_position = view.board.cell_center(look)
	rig.snap_to_target()
