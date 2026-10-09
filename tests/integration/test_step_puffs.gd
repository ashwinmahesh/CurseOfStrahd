extends TestCase
## What the party's feet kick up (Visual Polish Plan 4, StepPuffs): dust on dry roads, kicked snow where it lies, a
## splash in marsh mud and on any ground in the rain, nothing on dry grass; a few puffs made and used again; none
## indoors or in the Classic finish.


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func after_each() -> void:
	Look.set_style(Look.DEFAULT_STYLE, false)
	StepPuffs.set_enabled(true)


func _view(loc_id: String) -> LocationView:
	var v := LocationView.create(loc_id, GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


func _puffs(v: LocationView) -> StepPuffs:
	return v.atmosphere.get_node_or_null("StepPuffs") as StepPuffs


## The first square of the map whose floor's surface holds `word`, or (-1, -1).
func _square_of(v: LocationView, word: String) -> Vector2i:
	for z in v.board.grid.depth:
		for x in v.board.grid.width:
			var box := v.board.floor_box(Vector2i(x, z))
			var m := box.material_override as ShaderMaterial if box != null else null
			if m != null and str(m.get_meta("surface", "")).contains(word):
				return Vector2i(x, z)
	return Vector2i(-1, -1)


func test_the_ground_decides_the_puff() -> void:
	Look.set_style("modern", false)
	var v := _view("berez")
	var s := _puffs(v)
	assert_true(s != null, "Berez has footstep puffs")
	if s == null:
		v.queue_free()
		return
	v.atmosphere.wetness = 0.0
	v.atmosphere.snow_cover = 0.0
	var marsh := _square_of(v, "marsh")
	var grass := _square_of(v, "grass")
	assert_true(marsh.x >= 0 and grass.x >= 0, "the marsh has mud and grass squares")
	assert_eq(s.kind_at(marsh), "splash", "marsh mud splashes")
	assert_eq(s.kind_at(grass), "", "dry grass kicks up nothing")
	v.atmosphere.wetness = 1.0
	assert_eq(s.kind_at(grass), "splash", "in the rain any ground splashes")
	v.atmosphere.snow_cover = 1.0
	assert_eq(s.kind_at(grass), "snow", "where snow lies it's kicked up")
	assert_eq(s.kind_at(Vector2i(-5, -5)), "", "nothing off the map")
	v.queue_free()


func test_a_few_puffs_made_and_used_again() -> void:
	Look.set_style("modern", false)
	var v := _view("berez")
	var s := _puffs(v)
	if s == null:
		fail("no puffs at Berez")
		v.queue_free()
		return
	var first := s.puff("dust", Vector3(5, 0, 5))
	assert_eq(first.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "a puff casts no shadow")
	for i in StepPuffs.POOL:
		s.puff("dust", Vector3(5 + i, 0, 5))
	assert_eq(s.get_child_count(), StepPuffs.POOL, "no more than POOL of a kind")
	assert_true(first.global_position.is_equal_approx(Vector3(5 + StepPuffs.POOL - 1, 0.04, 5)), "the oldest is used again")
	StepPuffs.set_enabled(false)
	assert_true(s.puff("dust", Vector3.ZERO) == null, "switched off (captures and the perf probe)")
	v.queue_free()


func test_none_indoors_or_in_classic() -> void:
	Look.set_style("modern", false)
	var inside := _view("death_house_ground")
	assert_true(_puffs(inside) == null, "none indoors")
	inside.queue_free()
	Look.set_style("classic", false)
	var marsh := _view("berez")
	assert_true(_puffs(marsh) == null, "Classic stays as it was frozen")
	marsh.queue_free()
