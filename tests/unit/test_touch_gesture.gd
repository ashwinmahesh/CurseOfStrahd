extends TestCase


func test_tap_commits_only_once_on_release() -> void:
	var gesture := TouchGesture.new()
	gesture.press(0, Vector2(100, 100), "world", 0)
	assert_eq(str(gesture.release(0, Vector2(103, 101), 80)["kind"]), "tap")
	assert_true(gesture.release(0, Vector2(103, 101), 90).is_empty())


func test_drag_and_cancellation_never_activate_a_target() -> void:
	var gesture := TouchGesture.new()
	gesture.press(1, Vector2.ZERO, "inventory", 0)
	assert_eq(str(gesture.move(1, Vector2(0, 30))["kind"]), "scroll")
	assert_true(gesture.release(1, Vector2.ZERO, 300).is_empty())
	gesture.press(2, Vector2.ZERO, "world", 0)
	assert_true(gesture.release(2, Vector2.ZERO, 100, true).is_empty())


func test_two_world_fingers_zoom_without_a_release_tap() -> void:
	var gesture := TouchGesture.new()
	gesture.press(0, Vector2.ZERO, "world", 0)
	gesture.press(1, Vector2(100, 0), "world", 10)
	var update := gesture.move(1, Vector2(150, 0))
	assert_eq(str(update["kind"]), "camera")
	assert_eq(float(update["scale"]), 1.5)
	assert_true(gesture.release(1, Vector2(150, 0), 80).is_empty())
	assert_true(gesture.move(0, Vector2(0, 50)).is_empty())
	assert_true(gesture.release(0, Vector2.ZERO, 120).is_empty())


func test_ui_contact_does_not_join_world_camera_gesture() -> void:
	var gesture := TouchGesture.new()
	gesture.press(0, Vector2.ZERO, "world", 0)
	gesture.press(1, Vector2(100, 0), "button", 10)
	assert_true(gesture.move(0, Vector2(40, 0)).is_empty(), "mixed ownership cannot become a camera gesture")
	assert_true(gesture.release(1, Vector2(100, 0), 90).is_empty(), "a second finger cancels UI activation")
	assert_true(gesture.release(0, Vector2(40, 0), 100).is_empty())


func test_hold_offers_context_and_background_cancels_every_contact() -> void:
	var gesture := TouchGesture.new()
	gesture.press(0, Vector2.ZERO, "world", 0)
	assert_eq(str(gesture.release(0, Vector2.ZERO, 600)["kind"]), "context")
	gesture.press(0, Vector2.ZERO, "world", 700)
	gesture.cancel()
	assert_true(gesture.release(0, Vector2.ZERO, 750).is_empty())


func test_twisting_both_fingers_reports_small_signed_angles_without_snapping() -> void:
	for direction: float in [-1.0, 1.0]:
		var gesture := TouchGesture.new()
		var center := Vector2(400, 200)
		var radius := Vector2(150, 0)
		gesture.press(7, center - radius, "world", 0)
		gesture.press(42, center + radius, "world", 1)
		var angle := direction * deg_to_rad(20)
		var first := gesture.move(7, center - radius.rotated(angle))
		var second := gesture.move(42, center + radius.rotated(angle))
		assert_between(float(first["rotation"]) + float(second["rotation"]), angle - 0.0001, angle + 0.0001)
		assert_between(float(first["scale"]) * float(second["scale"]), 0.9999, 1.0001, "twisting is not net zoom")
		assert_true(gesture.release(7, center - radius.rotated(angle), 100).is_empty())
		assert_true(gesture.release(42, center + radius.rotated(angle), 110).is_empty())


func test_twist_crosses_angle_wrap_and_ignores_coincident_fingers() -> void:
	var gesture := TouchGesture.new()
	var radius := Vector2(200, 0)
	gesture.press(0, Vector2.ZERO, "world", 0)
	gesture.press(1, radius.rotated(deg_to_rad(175)), "world", 1)
	var update := gesture.move(1, radius.rotated(deg_to_rad(-175)))
	assert_between(rad_to_deg(float(update["rotation"])), 9.999, 10.001, "crossing 180 degrees does not reverse or jump")
	update = gesture.move(1, Vector2.ZERO)
	assert_eq(float(update["rotation"]), 0.0)
	assert_eq(float(update["scale"]), 1.0)
	update = gesture.move(1, Vector2(100, 0))
	assert_eq(float(update["rotation"]), 0.0, "spreading from zero span reestablishes the baseline")
	assert_eq(float(update["scale"]), 1.0)


func test_third_contact_cannot_rotate_or_zoom_the_world() -> void:
	var gesture := TouchGesture.new()
	gesture.press(0, Vector2.ZERO, "world", 0)
	gesture.press(1, Vector2(200, 0), "world", 1)
	gesture.press(2, Vector2(300, 0), "ui", 2)
	assert_true(gesture.move(1, Vector2(200, 100)).is_empty())
