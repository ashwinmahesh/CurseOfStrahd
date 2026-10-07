extends Node
## The animated title screen for captures: a full-size still, then FRAMES small frames of the right of the screen, 1/20 s
## apart, across a burst of bats from the towers, crows lifting from the pines, a flyby and a flash of lightning (the ambience is stepped by hand, so
## the frames are evenly spaced however long a shot takes). tools/capture/apng.py joins them into an animated PNG.
## make capture SCENE=res://tools/capture/title_capture.tscn NAME=title_anim FRAMES=10

const STEP := 0.05
const FRAMES := 48
## The frames show the right of the screen (castle, sky, road and pines: the moving part), small, to keep the animated
## PNG light.
const CROP := Rect2i(640, 0, 960, 900)
const SMALL := Vector2i(512, 480)

var menu: Control


func _ready() -> void:
	menu = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate() as Control
	add_child(menu)


func capture_shots(tool: Node, out: String) -> void:
	var amb := menu.find_children("*", "TitleAmbience", true, false)[0] as TitleAmbience
	amb.set_process(false)
	amb.set("_next_flyby", 7.6)
	amb.set("_next_burst", 8.0)
	amb.set("_next_flash", 9.6)
	amb.set("_next_crows", 8.2)
	while amb.time < 8.4:
		amb.call("_process", STEP)
	await tool.call("wait_frames", 2)
	tool.call("_shot", out + "_still_a.png")
	for i in FRAMES:
		amb.call("_process", STEP)
		await tool.call("wait_frames", 1)
		var img := get_viewport().get_texture().get_image().get_region(CROP)
		img.resize(SMALL.x, SMALL.y, Image.INTERPOLATE_LANCZOS)
		img.convert(Image.FORMAT_RGB8)
		img.save_png("%s_f%03d.png" % [out, i])
	tool.call("_shot", out + "_still_b.png")
