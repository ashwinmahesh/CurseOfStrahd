extends TestCase
## Livelier outdoor places (lane 28, owner requests 2026-10-08): the world matches what the narration says of it.
## Tser Pool is black and perfectly still; Madam Eva's tent is the size of a cottage and shows on the map as a tent;
## the camp's wagons ring the fire facing it, its horses stand in a railed pen, and more people live there.


func before_each() -> void:
	GameState.reset()
	ModeController.force(ModeController.Mode.EXPLORATION)
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.minute_of_day = 15 * 60


func _view(loc_id: String) -> LocationView:
	var v := LocationView.create(loc_id, GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The world box around everything a piece draws.
func _bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var b := mi.global_transform * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## The prop's piece (its Dressing_ root's model).
func _model_of(v: LocationView, prop_id: String) -> Node3D:
	var root := v.prop_nodes.get(prop_id) as Node3D
	if root == null:
		return null
	var found := root.find_children("Model_*", "Node3D", true, false)
	return found[0] as Node3D if not found.is_empty() else null


## "Tser Pool is black and perfectly still": its water has no current and no ripples, and is drawn near black.
func test_tser_pool_is_black_and_still() -> void:
	var v := _view("tser_pool")
	await _frames(1)
	var water := v.atmosphere.water
	assert_true(water != null, "the pool has its water")
	assert_eq(water.get_shader_parameter("flow") as Vector2, Vector2.ZERO, "no current")
	if Look.modern():
		assert_eq(float(water.get_shader_parameter("ripple_strength")), 0.0, "no ripples")
	var deep := water.get_shader_parameter("deep") as Color
	assert_true(deep.get_luminance() < 0.06, "black water: %s" % deep)
	var lake := _view("lake_zarovich")
	await _frames(1)
	assert_ne(lake.atmosphere.water.get_shader_parameter("flow") as Vector2, Vector2.ZERO, "Lake Zarovich still moves")
	v.queue_free()
	lake.queue_free()


## Owner reports (2026-10-08): the great tent was tiny and had nothing to show for it. It is the size of a cottage
## (wider than five squares, taller than three), stands over its block of squares with no tree poking through it, and
## blocks sight like a building.
func test_the_great_tent_is_cottage_sized() -> void:
	var v := _view("tser_pool")
	await _frames(1)
	var tent := _model_of(v, "eva_tent_outside")
	assert_true(tent != null and str(tent.get_meta("model")) == "great_tent", "the great tent is its own model")
	if tent == null:
		v.queue_free()
		return
	var box := _bounds(tent)
	assert_true(box.size.x > 5.0 and box.size.z > 3.5, "as big as a cottage: %s" % box.size)
	assert_true(box.size.y > 3.0, "tall: %.2f" % box.size.y)
	for x in range(30, 35):
		for z in range(3, 6):
			var c := Vector2i(x, z)
			assert_true(v.grid.has_flag(c, CombatGrid.WALL), "the tent blocks %s" % c)
			for n: Node3D in v.board.dressing.get(c, []):
				assert_false(n.visible, "no tree shows through the tent at %s" % c)
	v.queue_free()


## A prop's `facing` turns its piece; `span` stands it over the middle of its squares.
func test_wagons_face_the_fire_over_their_squares() -> void:
	var v := _view("tser_pool")
	await _frames(1)
	var loc := v.loc
	for p: Variant in loc["props"]:
		var spec := p as Dictionary
		if str(spec.get("model", "")) != "vardo":
			continue
		var m := _model_of(v, str(spec["id"]))
		assert_true(m != null, "%s is a 3D wagon" % spec["id"])
		if m == null:
			continue
		var want := float(SetDressing.facing_yaw(spec))
		assert_true(absf(angle_difference(m.rotation.y, want)) < 0.01, "%s faces %s" % [spec["id"], spec["facing"]])
		var at := SetDressing.span_centre(v.board, spec) as Vector3
		assert_true(Vector2(m.global_position.x, m.global_position.z).distance_to(Vector2(at.x, at.z)) < 0.01,
			"%s stands over the middle of its squares" % spec["id"])
	v.queue_free()


## The horse pen's rails are fences, and the ones on its east and west sides run up the map.
func test_the_pen_is_railed() -> void:
	var v := _view("tser_pool")
	await _frames(1)
	var rails := {Vector2i(7, 18): 0.0, Vector2i(5, 20): PI / 2.0, Vector2i(13, 20): PI / 2.0, Vector2i(9, 21): 0.0}
	for c: Vector2i in rails:
		var fence: Node3D = null
		for n: Node3D in v.board.dressing.get(c, []):
			if str(n.get_meta("model", "")) == "fence":
				fence = n
		assert_true(fence != null, "a fence on the rail at %s" % c)
		if fence != null:
			assert_true(absf(angle_difference(fence.rotation.y, float(rails[c]))) < 0.01, "the rail at %s lies along the pen" % c)
	v.queue_free()


## The great tent, the small tents and the wagons are drawn on the minimap in their own colours.
func test_the_map_shows_the_tents() -> void:
	var v := _view("tser_pool")
	await _frames(1)
	var mm := Minimap.new()
	add_child(mm)
	mm.show_location(v)
	var img := mm.call("_render") as Image
	var mark := SetDressing.catalog()["map_marks"]["great_tent"] as Dictionary
	var canvas: Array[Color] = []
	for name: Variant in mark["stripes"]:
		canvas.append(Look.color(str(name)))
	var at := Vector2i(int(32.5 * Minimap.PX), int(4.0 * Minimap.PX))   # inside the tent, off its middle
	var px := img.get_pixelv(at)
	var hit := false
	for c in canvas:
		hit = hit or px.is_equal_approx(c)
	assert_true(hit, "the great tent's canvas on the map at %s: %s" % [at, px])
	var wagon := img.get_pixelv(Vector2i(int(18.0 * Minimap.PX), int(7.0 * Minimap.PX)))
	assert_true(wagon.is_equal_approx(Look.color("blood")), "a wagon on the map: %s" % wagon)
	var pool := img.get_pixelv(Vector2i(int(9.5 * Minimap.PX), int(9.5 * Minimap.PX)))
	assert_true(pool.is_equal_approx(Look.color("void")), "the pool is black on the map too: %s" % pool)
	mm.queue_free()
	v.queue_free()


## More people to talk to: the camp's five new folk stand there, each with something to say.
func test_the_camp_has_people() -> void:
	var v := _view("tser_pool")
	await _frames(1)
	var here: Array[String] = []
	for s: Variant in v.get("_npc_shown") as Array:
		here.append(str((s as Dictionary)["spec"]["npc"]))
	for id: String in ["tser_dorina", "tser_radu", "tser_petru", "tser_tobar", "tser_zora", "stanimir", "luminita"]:
		assert_true(id in here, "%s is in the camp" % id)
	v.queue_free()
	GameState.story.set_flag("tser_pool_brawl_won", true)
	var after := _view("tser_pool")
	await _frames(1)
	for s: Variant in after.get("_npc_shown") as Array:
		assert_false(str((s as Dictionary)["spec"]["npc"]).begins_with("tser_"), "the camp is empty after the brawl")
	after.queue_free()
