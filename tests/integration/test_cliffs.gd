extends TestCase
## Cliffs and drops with shape (the vault's Natural Maps Plan, N6; owner 2026-10-19: "make our maps look more natural"):
## where natural ground drops 15 ft or more between two squares, or over an empty square, the Modern look draws the squares
## round it as one height field (CliffFace) instead of a straight slab of rock on a flat step: the face's line wanders in and
## out by no more than a quarter of a square, every square's middle stays where a token stands, and a cliff's face hangs
## from its high square's column like the slab did. Classic keeps the slabs.

## The places with a cliff or a drop over empty ground (from the maps' `elevation` rows).
const PLACES: Array[String] = ["mountain_pass", "mount_baratok_trail", "road_ravine", "frozen_tarn", "yester_hill",
	"lake_zarovich_trail", "old_bonegrinder_track", "werewolf_den", "mount_baratok", "amber_temple_road", "tsolenka_pass"]

var view: LocationView
var _was := ""


func before_each() -> void:
	_was = Look.style()
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func after_each() -> void:
	if view != null:
		view.queue_free()
		view = null
	Look.set_style(_was, false)
	GameState.reset()


func _view(loc: String) -> LocationView:
	view = LocationView.create(loc, GameState.story, null, Dice.roller, "default")
	add_child(view)
	await get_tree().process_frame
	return view


func _leave() -> void:
	view.queue_free()
	view = null
	await get_tree().process_frame


## Every one of those places has a plan with sides in the Modern look, and none in Classic.
func test_the_places_have_cliffs_in_modern_not_classic() -> void:
	Look.set_style("modern", false)
	for place in PLACES:
		var v := await _view(place)
		var f := v.board.cliffs
		assert_true(f != null and f.side_count() > 0, "%s has shaped cliffs" % place)
		await _leave()
	Look.set_style("classic", false)
	var c := await _view("mountain_pass")
	assert_true(c.board.cliffs == null, "Classic keeps the slabs")
	assert_true(c.board.floor_box(Vector2i(2, 2)) != null, "and its columns")


## The shape stays by the cliff: away from every cliff line (more than 0.56 of a square) the field is the board's own
## ground, and the middle of every natural square stands within 0.05 of where a token stands, so rings, paths and picking
## still sit right (the plan's rule 2).
func test_the_field_leaves_the_middles_and_the_far_ground_alone() -> void:
	Look.set_style("modern", false)
	for place in PLACES:
		var v := await _view(place)
		var f := v.board.cliffs
		if f == null:
			assert_true(false, "no cliffs at %s" % place)
			continue
		var bad_mid := 0
		var bad_far := 0
		for z in v.grid.depth:
			for x in v.grid.width:
				var c := Vector2i(x, z)
				if not v.grid.has_flag(c, CombatGrid.NATURAL) or v.grid.has_flag(c, CombatGrid.VOID):
					continue
				var mid := Vector2(x + 0.5, z + 0.5)
				if absf(f.height_at(mid) - v.board.ground_y(mid)) > 0.05:
					bad_mid += 1
				for q in 9:
					var p := Vector2(x + 0.1 + 0.8 * float(q % 3) / 2.0, z + 0.1 + 0.8 * float(floori(q / 3.0)) / 2.0)
					if f.line_distance(p) > 0.56 and absf(f.height_at(p) - v.board.ground_y(p)) > 0.001:
						bad_far += 1
		assert_eq(bad_mid, 0, "%s: the middle of every natural square is where a token stands" % place)
		assert_eq(bad_far, 0, "%s: away from a cliff the ground is the board's own" % place)
		await _leave()


## A face's line wanders but never more than a quarter of a square (a little over, the flutes' rounding): on every cliff
## side that isn't a drop, and enough of them are well off the grid line that none runs straight along it for long.
func test_the_face_wanders_within_a_quarter_square() -> void:
	Look.set_style("modern", false)
	var sides := 0
	var wandering := 0
	for place in PLACES:
		var v := await _view(place)
		var f := v.board.cliffs
		if f == null:
			assert_true(false, "no cliffs at %s" % place)
			continue
		var worst := 0.0
		for i in f.side_count():
			if f.side_is_drop(i):
				continue
			var far := 0.0
			for t: float in [0.3, 0.5, 0.7]:
				var off := f.contour_at(i, t)
				if is_nan(off):
					continue
				far = maxf(far, absf(off))
			worst = maxf(worst, far)
			sides += 1
			if far > 0.06:
				wandering += 1
		assert_true(worst <= 0.34, "%s: no face is more than a third of a square off its line (%.2f)" % [place, worst])
		await _leave()
	assert_true(sides > 100, "there are sides to measure (%d)" % sides)
	assert_true(float(wandering) / maxf(sides, 1.0) > 0.7, "most faces are off the grid line (%d of %d)" % [wandering, sides])


## A cliff's face and scree hang from its high square's column (a child named Cliff, as the slab was, so it hides with the
## floor), the low square's column has none of its own, and the high square's top is a child too.
func test_faces_hang_from_the_high_square() -> void:
	Look.set_style("modern", false)
	var v := await _view("mountain_pass")
	var f := v.board.cliffs
	var checked := 0
	var missing := 0
	for i in f.side_count():
		var c := f.side_high(i)
		var box := v.board.floor_box(c)
		if box == null:
			continue
		checked += 1
		if not box.has_node("Cliff") or not box.has_node("Top"):
			missing += 1
	assert_true(checked > 20, "the pass has high squares with columns (%d)" % checked)
	assert_eq(missing, 0, "each has its Cliff and its Top")
	await _leave()


## A place comes back the same on the next visit (the plan is kept), and the second build shares what the first made.
func test_a_place_comes_back_the_same() -> void:
	Look.set_style("modern", false)
	var v := await _view("frozen_tarn")
	var first := v.board.cliffs
	var probe := Vector2(10.5, 3.5)
	var h := first.height_at(probe)
	await _leave()
	var again := await _view("frozen_tarn")
	assert_true(again.board.cliffs == first, "the plan is kept")
	assert_eq(again.board.cliffs.height_at(probe), h, "and gives the same ground")
	await _leave()
