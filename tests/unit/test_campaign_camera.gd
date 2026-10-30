extends TestCase
## This game's camera settings (data/campaign.json "camera"): free turning is on, and the tilt stays close to the 40
## degrees its sprites are drawn for (ADR 0004), so figures are never squashed or stretched.


func test_the_game_turns_freely_and_tilts_around_forty_degrees() -> void:
	assert_true(CameraRig.turns_freely(), "free turning is on")
	var tilt := CameraRig.tilt_limits()
	assert_ne(tilt, Vector2.ZERO, "tilt is on")
	assert_true(tilt.x <= -CameraRig.PITCH_DEG and -CameraRig.PITCH_DEG <= tilt.y, "the sprites' 40 degrees is inside the range")
	assert_true(tilt.y - tilt.x <= 30.0, "no wider than 30 degrees: %s" % tilt)


func test_a_new_rig_starts_at_the_sprites_pitch_with_the_range() -> void:
	var rig := CameraRig.new()
	add_child(rig)
	rig.snap_to_target()
	assert_between(rig.camera.rotation_degrees.x, -40.01, -39.99, "starts at 40 degrees")
	assert_true(rig.free_turn and rig.tilt_range != Vector2.ZERO, "the rig picks both up from the campaign")
	rig.free()
