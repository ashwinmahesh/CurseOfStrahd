extends TestCase
## A saved desktop High setting or the Classic finish must not enable effects absent from Mobile.


func test_every_mobile_preset_clamps_unsupported_effects_without_mutating_desktop() -> void:
	var presets: Array[Dictionary] = [Graphics.CLASSIC]
	for key: String in Graphics.PRESETS:
		presets.append(Graphics.SPECS[key] as Dictionary)
	for source in presets:
		var before := source.duplicate(true)
		var mobile := Graphics.for_renderer(source, true)
		for key: String in ["ao", "bounce"]:
			assert_eq(int(mobile[key]), -1, key)
		for key: String in ["haze", "reflections", "swaying"]:
			assert_eq(int(mobile[key]), 0, key)
		assert_false(bool(mobile["sun_soft"]))
		assert_true(int(mobile["lamp_atlas"]) <= 2048)
		assert_true(int(mobile["sun_map"]) <= 2048)
		assert_true(int(mobile["lamp_shadows"]) <= 2)
		assert_eq(source, before, "mobile keeps the shared desktop presets intact")
		assert_eq(Graphics.for_renderer(source, false), before, "Forward+ keeps every setting")


func test_mobile_keeps_the_selected_resolution_and_antialiasing() -> void:
	var source := (Graphics.SPECS["high"] as Dictionary).duplicate()
	var mobile := Graphics.for_renderer(source, true)
	for key: String in ["scale", "edge_aa", "msaa"]:
		assert_eq(mobile[key], source[key], key)


func test_mobile_capabilities_apply_to_capture_overrides_too() -> void:
	var source := (Graphics.SPECS["low"] as Dictionary).duplicate()
	source.merge({"haze": 64, "reflections": 64, "bounce": 3, "sun_soft": true}, true)
	var mobile := Graphics.for_renderer(source, true)
	assert_eq(int(mobile["haze"]), 0)
	assert_eq(int(mobile["reflections"]), 0)
	assert_eq(int(mobile["bounce"]), -1)
