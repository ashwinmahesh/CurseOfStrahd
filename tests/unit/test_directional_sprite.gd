extends TestCase
## Picking which of the 8 rendered directions to show, relative to the camera.


func test_directions_relative_to_an_unrotated_camera() -> void:
	var cam := Basis() # looks down -Z, screen-right is +X
	assert_eq(DirectionalSprite.direction_for(Vector3(0, 0, 1), cam), "s", "facing the camera")
	assert_eq(DirectionalSprite.direction_for(Vector3(0, 0, -1), cam), "n", "facing away")
	assert_eq(DirectionalSprite.direction_for(Vector3(1, 0, 0), cam), "e", "facing screen-right")
	assert_eq(DirectionalSprite.direction_for(Vector3(-1, 0, 0), cam), "w")
	assert_eq(DirectionalSprite.direction_for(Vector3(1, 0, 1).normalized(), cam), "se")
	assert_eq(DirectionalSprite.direction_for(Vector3(-1, 0, -1).normalized(), cam), "nw")


func test_directions_follow_camera_rotation() -> void:
	# Camera turned 90 degrees to the right (yaw -90): world +X is now "away from the camera".
	var cam := Basis(Vector3.UP, -PI / 2.0)
	assert_eq(DirectionalSprite.direction_for(Vector3(1, 0, 0), cam), "n")
	assert_eq(DirectionalSprite.direction_for(Vector3(0, 0, 1), cam), "e")


func test_pitched_camera_still_works() -> void:
	var cam := Basis(Vector3.RIGHT, deg_to_rad(-40.0))
	assert_eq(DirectionalSprite.direction_for(Vector3(0, 0, 1), cam), "s")


func test_villager_sprite_frames_have_every_direction() -> void:
	var frames := load("res://art/sprites/villager/walk.tres") as SpriteFrames
	assert_true(frames != null, "walk.tres loads")
	if frames == null:
		return
	for d in DirectionalSprite.DIRECTIONS:
		assert_eq(frames.get_frame_count(StringName("walk_" + d)), 8, "walk_" + d)
		assert_eq(frames.get_frame_count(StringName("idle_" + d)), 1, "idle_" + d)
