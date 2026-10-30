extends Node
## The HD-2D look (data/campaign.json "hd2d", the moods' moths) against the look without it, for the owner to judge: the
## same place, hour and camera taken twice in one run, first with the game's HD-2D settings and the moods' file from
## before (HD2D_BEFORE_MOODS), then with the game's own, so a pair differs only in the data. The game's HUD shows, so
## names, rings and markers can be checked for sharpness. Not part of the game.
##   make capture SCENE=res://tools/capture/hd2d_capture.tscn NAME=hd2d/modern FRAMES=30 ARGS=--size=1920x1080
## Environment (each for this run only):
## - HD2D_STYLE=modern|toon: the finish (default modern).
## - HD2D_SHOTS=village_night,fight: which shots (default every one).
## - HD2D_BEFORE_MOODS=/abs/dir: a folder holding the "before" moods.json (default: the game's own, so only the
##   campaign.json settings differ).
## - HD2D_BLUR=off: Settings' depth blur off, to check the new blur goes with it.

## Each shot: the place, the hour, and what happens in it (a "fight" encounter id, a "talk" npc id), with the flags set first.
const SHOTS := {
	"village_dusk": {"loc": "village_of_barovia", "hour": 18},
	"village_night": {"loc": "village_of_barovia", "hour": 22},
	"inn": {"loc": "vallaki_blue_water_inn", "hour": 20},
	"vallaki_night": {"loc": "vallaki", "hour": 21},
	"fight": {"loc": "village_of_barovia", "hour": 22, "fight": "night_streets_dead", "flags": ["ismark_met"]},
	"talk": {"loc": "village_of_barovia", "hour": 22, "talk": "morgantha"},
	"castle": {"loc": "castle_ravenloft_gates", "hour": 23},
}
const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]

var root: Node


func _ready() -> void:
	var style := OS.get_environment("HD2D_STYLE")
	Look.set_style(style if style != "" else "modern", false)
	GameSettings.set_value("depth_blur", OS.get_environment("HD2D_BLUR") != "off", false)   # cache only: never the owner's settings file
	TalkCamera.headless_too = true
	var d := Weather.data().duplicate(true)
	for c: String in d["climates"]:
		d["climates"][c] = {"overcast": 1}   # the same sky every shot, not a fog day
	Weather.use(d)
	GameState.reset()
	for id: String in PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "village_of_barovia"
	for c: Dictionary in Cutscenes.all():
		Cutscenes.mark_played(str(c["id"]), GameState.story)   # an arrival's picture would cover the shot
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func capture_shots(tool: Node, out: String) -> void:
	var only := OS.get_environment("HD2D_SHOTS").split(",", false)
	var own := Campaign.config().duplicate(true)
	var without := own.duplicate(true)
	without.erase("hd2d")
	var before_dir := OS.get_environment("HD2D_BEFORE_MOODS")
	var before_moods := {}
	if before_dir != "":
		before_moods = JSON.parse_string(FileAccess.get_file_as_string(before_dir.path_join("moods.json"))) as Dictionary
	for id: String in SHOTS:
		if not only.is_empty() and not id in only:
			continue
		var shot := SHOTS[id] as Dictionary
		for which: String in ["before", "after"]:
			Campaign.use_config(without if which == "before" else own)
			Atmosphere._moods = before_moods if which == "before" else {}
			AtmosphereLand._kept.clear()
			AtmosphereLand._kept_order.clear()
			GroundRelief._kept.clear()
			GroundRelief._kept_order.clear()
			await _shoot(tool, shot, "%s_%s_%s.png" % [out, id, which])
	Campaign.use_config(own)


func _shoot(tool: Node, shot: Dictionary, path: String) -> void:
	var story := GameState.story
	story.minute_of_day = int(shot["hour"]) * 60
	for f: String in shot.get("flags", []):
		story.set_flag(f)
	root.call("enter_location", str(shot["loc"]), "default")
	await tool.call("wait_frames", 60)
	var hud := root.get("hud") as ExploreHud
	hud.close_narration()
	var view := root.get("view") as LocationView
	view.update_daylight()
	view.atmosphere.settle()
	if shot.has("fight"):
		LocationFights.start_encounter(view, str(shot["fight"]))
		await tool.call("wait_frames", 90)
	if shot.has("talk"):
		TalkCamera.open(view, str(shot["talk"]))
		await tool.call("wait_frames", 60)
	await tool.call("wait_frames", 20)
	print("hd2d %s: mood %s, hd2d focus %s" % [path.get_file(), view.atmosphere.mood_id, view.atmosphere.hd2d["focus"]])
	tool.call("_shot", path)
