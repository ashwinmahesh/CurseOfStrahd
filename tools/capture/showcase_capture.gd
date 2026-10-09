extends Node
## Films the animation before/after (tools/art/preview/anim_showcase.tscn) off screen, so recording it never opens a
## window over the owner's work: frames at FPS as <out>_NNN.jpg until the showcase ends.
## make capture SCENE=res://tools/capture/showcase_capture.tscn NAME=showcase/strahd FRAMES=5 \
##   ARGS="--size=1280x720 --id=strahd --villain"
## (the showcase reads its own arguments: --id, --villain, --labels, --short). Join the frames with PIL or
## tools/capture/apng.py.

const FPS := 12.0
const MAX_SECONDS := 90.0

var show: Node


func _ready() -> void:
	show = (load("res://tools/art/preview/anim_showcase.tscn") as PackedScene).instantiate()
	add_child(show)


func capture_shots(_tool: Node, out: String) -> void:
	var start := Time.get_ticks_msec()
	var next := 0.0
	var n := 0
	# The showcase quits the game when it's done; every frame is written as it's taken.
	while next <= MAX_SECONDS:
		await get_tree().process_frame
		if (Time.get_ticks_msec() - start) / 1000.0 < next:
			continue
		get_viewport().get_texture().get_image().save_jpg("%s_%03d.jpg" % [out, n], 0.9)
		n += 1
		next += 1.0 / FPS
