extends TestCase
## Characters reflected where they stand by water, in a puddle or on polished stone (Visual Polish Plan 1,
## SpriteReflection): every figure has one mirrored copy that casts no shadow and draws under the figure and the
## floor's rings, it shows the figure's frame as it changes (paused too), and it shows only in the Modern finish on a
## preset with reflections.


func after_each() -> void:
	Look.set_style(Look.DEFAULT_STYLE, false)
	Graphics.set_preset(Graphics.DEFAULT_PRESET, false)
	SpriteReflection.set_enabled(true)


func _figure() -> DirectionalSprite:
	var s := DirectionalSprite.create(DirectionalSprite.frames_for("villager"), 1.5)
	add_child(s)
	return s


func _reflection(s: DirectionalSprite) -> SpriteReflection:
	var found := s.find_children("*", "SpriteReflection", false, false)
	assert_eq(found.size(), 1, "one reflection per figure")
	return found[0] as SpriteReflection if not found.is_empty() else null


func test_every_figure_has_a_reflection_that_casts_no_shadow() -> void:
	var s := _figure()
	var r := _reflection(s)
	if r == null:
		return
	assert_eq(s.reflection, r, "the figure keeps its reflection")
	assert_eq(r.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "a reflection never casts a shadow")
	assert_true(r.render_priority < DirectionalSprite.RENDER_PRIORITY, "drawn before the figures")
	assert_true(r.render_priority > Look.POST_PRIORITY, "drawn after the screen pass")
	s.queue_free()


func test_the_reflection_shows_the_figures_frame() -> void:
	var s := _figure()
	var r := _reflection(s)
	if r == null:
		return
	s.play(&"walk_e")
	s.frame = 3
	var shown := s.sprite_frames.get_frame_texture(&"walk_e", 3)
	assert_eq(r.texture, shown, "follows the figure's frame without waiting for a processed frame")
	assert_eq(r.pixel_size, s.pixel_size, "the same size as the figure")
	assert_eq(r.offset, s.offset, "standing on the same feet")
	s.queue_free()


func test_shown_only_in_the_modern_finish_with_reflections() -> void:
	var s := _figure()
	var r := _reflection(s)
	if r == null:
		return
	Look.set_style("modern", false)
	Graphics.set_preset("high", false)
	r._refresh()
	assert_true(r.visible, "Modern on High")
	Graphics.set_preset("low", false)
	r._refresh()
	assert_false(r.visible, "the Low preset has no reflections")
	Graphics.set_preset("high", false)
	Look.set_style("classic", false)
	r._refresh()
	assert_false(r.visible, "Classic stays as it was frozen")
	Look.set_style("modern", false)
	SpriteReflection.set_enabled(false)
	assert_false(r.visible, "switched off at once (captures and the perf probe)")
	SpriteReflection.set_enabled(true)
	assert_true(r.visible, "and back on")
	s.queue_free()
