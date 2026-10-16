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
	assert_eq(str(gesture.move(0, Vector2(40, 0))["kind"]), "pan")
	assert_eq(str(gesture.release(1, Vector2(100, 0), 90)["owner"]), "button")


func test_hold_offers_context_and_background_cancels_every_contact() -> void:
	var gesture := TouchGesture.new()
	gesture.press(0, Vector2.ZERO, "world", 0)
	assert_eq(str(gesture.release(0, Vector2.ZERO, 600)["kind"]), "context")
	gesture.press(0, Vector2.ZERO, "world", 700)
	gesture.cancel()
	assert_true(gesture.release(0, Vector2.ZERO, 750).is_empty())
