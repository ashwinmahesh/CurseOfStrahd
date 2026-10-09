extends "res://tools/capture/look_capture.gd"
## The heat shimmer's shots (Visual Polish Plan 8, HeatShimmer): the camera on the first fire of each place, as a
## short run of frames (the shimmer only shows moving). Not part of the game.
##   make capture SCENE=res://tools/capture/shimmer_capture.tscn NAME=shimmer/after FRAMES=10   # LOOK_OFF=shimmer

const PLACES := {
	"camp": {"loc": "vallaki_vistani_camp", "hour": 22, "cells": [[14, 14], [16, 14], [13, 13], [17, 11]]},
	"pool_camp": {"loc": "tser_pool", "hour": 21},
}
const FRAMES_EACH := 24


func capture_shots(tool: Node, out: String) -> void:
	for id: String in PLACES:
		_build(PLACES[id] as Dictionary)
		await tool.call("wait_frames", 45)
		var h := view.atmosphere.get_node_or_null("HeatShimmer") as HeatShimmer
		var fire: Node3D = null
		if h != null:
			for f in h.fires:
				if is_instance_valid(f[0]):
					fire = f[0] as Node3D
					break
		print("shimmer %s: %d fires" % [id, h.fires.size() if h != null else 0])
		if fire != null:
			view.rig.follow = null
			view.rig.global_position = fire.global_position
			view.rig.distance = 8.0
			view.rig.snap_to_target()
		await tool.call("wait_frames", 30)
		if h != null and h.visible:
			# What it costs: frames uncapped with the shimmer, against the same frames without.
			var with_ms := await _frame_ms(tool)
			HeatShimmer.set_enabled(false)
			var without_ms := await _frame_ms(tool)
			HeatShimmer.set_enabled(true)
			print("shimmer %s: %.2f ms a frame with it, %.2f without (%.2f ms)" % [id, with_ms, without_ms,
				with_ms - without_ms])
		for i in FRAMES_EACH:
			await tool.call("wait_frames", 1)
			tool.call("_shot", "%s_%s_%03d.png" % [out, id, i])


func _frame_ms(tool: Node) -> float:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await tool.call("wait_frames", 20)
	var t0 := Time.get_ticks_usec()
	await tool.call("wait_frames", 120)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / 120.0
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	return ms
