extends TestCase
## Mountain tops with shape (owner 2026-10-19: "why are all of our mountain tops flat? ... Things should look natural"):
## a place whose look says `rock_shape: "crags"` draws its rock squares as one shaped mountain (Crags) instead of a field
## of flat-topped columns, in the Modern look; Classic keeps the columns. Mount Baratok is the first.

const LOC := "mount_baratok"

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


func _view() -> LocationView:
	view = LocationView.create(LOC, GameState.story, null, Dice.roller, "default")
	add_child(view)
	await get_tree().process_frame
	return view


## Peaks and saddles: the crags' tops differ by more than a column's random height did (1.2), the highest stands well
## above the old tallest column (3.8), and a square deep in the rock isn't flat on top.
func test_the_tops_have_shape() -> void:
	Look.set_style("modern", false)
	var v := await _view()
	var crags := v.board.crags
	assert_true(crags != null, "Mount Baratok's rock is one shaped mountain")
	if crags == null:
		return
	var lo := INF
	var hi := 0.0
	for c: Vector2i in crags.cells:
		if c.y <= 6:   # the crag band above the snowfield
			lo = minf(lo, crags.top_of(c))
			hi = maxf(hi, crags.top_of(c))
	assert_true(hi - lo > 2.0, "the tops rise and fall (%.1f to %.1f)" % [lo, hi])
	assert_true(hi > 5.0, "the peaks stand higher than the old columns (%.1f)" % hi)
	var deep := Vector2i(20, 3)
	var low := INF
	var high := -INF
	for b in Crags.RES + 1:
		for a in Crags.RES + 1:
			var h := crags.height_at(deep.x * Crags.RES + a, deep.y * Crags.RES + b)
			low = minf(low, h)
			high = maxf(high, h)
	assert_true(high - low > 0.3, "the top over %s isn't flat (%.2f to %.2f)" % [deep, low, high])


## The rock rises out of the ground: wherever it meets a square the party can stand on, it is at the ground or under it.
func test_the_rock_meets_the_ground() -> void:
	Look.set_style("modern", false)
	var v := await _view()
	var crags := v.board.crags
	if crags == null:
		assert_true(false, "no crags")
		return
	var bad := 0
	for c: Vector2i in crags.cells:
		for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var o := c + d
			if not v.board.grid.in_bounds(o) or crags.cells.has(o):
				continue
			# The grid points along the side the two squares share.
			for s in Crags.RES + 1:
				var i := c.x * Crags.RES + (Crags.RES if d.x > 0 else (0 if d.x < 0 else s))
				var j := c.y * Crags.RES + (Crags.RES if d.y > 0 else (0 if d.y < 0 else s))
				if crags.height_at(i, j) > 0.0:
					bad += 1
	assert_eq(bad, 0, "every point where the rock meets open ground is at the ground or under it")


## Each rock square keeps a piece of its own (it fades in the party's way and a prop can take its square), and the
## frozen Classic look keeps its columns.
func test_pieces_per_square_and_classic_columns() -> void:
	Look.set_style("modern", false)
	var v := await _view()
	var pieces := 0
	for n: Node3D in v.board.mesh_occluders:
		if is_instance_valid(n) and n.has_meta("crag"):
			pieces += 1
	assert_eq(pieces, v.board.crags.cells.size() if v.board.crags != null else -1, "a piece for each rock square")
	v.queue_free()
	view = null
	await get_tree().process_frame
	Look.set_style("classic", false)
	var classic := await _view()
	assert_true(classic.board.crags == null, "Classic keeps the rock columns")
