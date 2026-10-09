extends "res://tools/capture/look_capture.gd"
## The fight pulses' shots (Visual Polish Plan 3, ScreenPulse): the village square at dusk, then each pulse held near
## its peak. Not part of the game.
##   make capture SCENE=res://tools/capture/pulse_capture.tscn NAME=pulse/after FRAMES=10

const PULSES: Array[String] = ["engage", "crit", "kill", "spell"]
## How far into its pulse each shot holds it.
const HOLD := 0.8


func capture_shots(tool: Node, out: String) -> void:
	_build({"loc": "village_of_barovia", "hour": 18})
	await tool.call("wait_frames", 60)
	tool.call("_shot", "%s_none.png" % out)
	# The party for the fight breaking out; a spot a few squares off for a blow or a spell landing.
	var party := view.rig.global_position
	for kind in PULSES:
		var p := ScreenPulse.play(view, kind, party if kind == "engage" else party + Vector3(3.0, 0.0, -1.5))
		if p == null:
			push_error("pulse_capture: no pulse (ScreenPulse off?)")
			return
		await tool.call("wait_frames", 1)   # the layer joins the window at the end of its first frame
		p._tw.kill()
		p._set_amount(HOLD)
		await tool.call("wait_frames", 4)
		if kind == "engage":
			# What a pulse costs while it plays: frames uncapped with it held, against the same frames without.
			var with_ms := await _frame_ms(tool)
			p.visible = false
			var without_ms := await _frame_ms(tool)
			p.visible = true
			print("pulse: %.2f ms a frame while it plays, %.2f without (%.2f ms)" % [with_ms, without_ms,
				with_ms - without_ms])
		tool.call("_shot", "%s_%s.png" % [out, kind])
		p._set_amount(0.0)
		p.visible = false
		await tool.call("wait_frames", 2)


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
