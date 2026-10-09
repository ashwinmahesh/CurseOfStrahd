extends TestCase
## The tactical camera (Combat HUD plan, owner pick 2026-10-09, after Baldur's Gate 3): O eases the view steeper and
## further back, and back again (CameraRig.tactical).


func test_the_tactical_view_looks_down_from_further_back() -> void:
	var rig := CameraRig.new()
	rig._process(0.0)
	var play_pitch := rig.camera.rotation.x
	var play_reach := rig.camera.position.length()
	rig.tactical = true
	rig._process(1.0)
	assert_between(rad_to_deg(rig.camera.rotation.x), CameraRig.TACTICAL_PITCH_DEG - 0.5, CameraRig.TACTICAL_PITCH_DEG + 0.5, "66 degrees down")
	assert_true(rig.camera.rotation.x < play_pitch, "steeper than the play view")
	assert_true(rig.camera.position.length() > play_reach, "and further back")
	rig.tactical = false
	rig._process(1.0)
	assert_between(rig.camera.rotation.x, play_pitch - 0.01, play_pitch + 0.01, "O again: back to the play view")
	rig.free()


func test_o_switches_it() -> void:
	InputActions.ensure()
	var rig := CameraRig.new()
	var ev := InputEventAction.new()
	ev.action = &"camera_tactical"
	ev.pressed = true
	rig._unhandled_input(ev)
	assert_true(rig.tactical)
	rig._unhandled_input(ev)
	assert_false(rig.tactical)
	rig.free()
