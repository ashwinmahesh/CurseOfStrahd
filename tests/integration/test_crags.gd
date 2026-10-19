extends TestCase
## Mountain tops with shape (owner 2026-10-19: "why are all of our mountain tops flat? ... Things should look natural"):
## a place whose look says `rock_shape: "crags"` draws its rock squares as one shaped mountain (Crags) instead of a field
## of flat-topped columns, in the Modern look; Classic keeps the columns. Mount Baratok was the first; the rest of the
## rock places follow (the vault's Natural Maps Plan, N5).

const LOC := "mount_baratok"
## Every place whose look says `rock_shape: "crags"` (catalog place_looks). The castle's overlook has `rock_walls` too, but
## the castle's own builder claims every one of its wall squares, so it has no loose rock to shape.
const PLACES: Array[String] = ["mount_baratok", "mount_baratok_trail", "tsolenka_pass", "werewolf_den",
	"castle_ravenloft_gates", "amber_temple_road", "ghakis_quarry", "amber_road_camp"]

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


func _view(loc: String = LOC) -> LocationView:
	view = LocationView.create(loc, GameState.story, null, Dice.roller, "default")
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


## Every place the catalog gives crags to is drawn as one (and the list above is that list).
func test_every_rock_place_has_crags() -> void:
	Look.set_style("modern", false)
	var looks := (SetDressing.catalog().get("place_looks", {}) as Dictionary)
	var named: Array[String] = []
	for place: String in looks:
		if str((looks[place] as Dictionary).get("rock_shape", "")) == "crags":
			named.append(place)
	named.sort()
	var want := PLACES.duplicate()
	want.sort()
	assert_eq(named, want, "the places the catalog gives crags to")
	for place in PLACES:
		var v := await _view(place)
		assert_true(v.board.crags != null and not v.board.crags.cells.is_empty(), "%s's rock is one shaped mountain" % place)
		v.queue_free()
		view = null
		await get_tree().process_frame


## The rock stays clear of where the party stands (the plan's rule 2): in a walkable square the face is never more than a
## quarter of a square out from the grid line, the scree never more than half, so the middle of the square is at the
## ground, a token's ring clear of the face, and the foot never runs straight along the grid line for long.
func test_the_rock_leaves_the_walkable_middles_clear() -> void:
	Look.set_style("modern", false)
	for place in PLACES:
		var v := await _view(place)
		var crags := v.board.crags
		if crags == null:
			assert_true(false, "no crags at %s" % place)
			continue
		var bad_middle := 0
		var bad_face := 0
		var bad_scree := 0
		var reached := 0
		for z in v.grid.depth:
			for x in v.grid.width:
				var c := Vector2i(x, z)
				if crags.cells.has(c) or v.grid.has_flag(c, CombatGrid.WALL):
					continue
				if crags.height_at(x * Crags.RES + 2, z * Crags.RES + 2) > 0.05:   # (RES 4: the middle point)
					bad_middle += 1
				for b in Crags.RES + 1:
					for a in Crags.RES + 1:
						var h := crags.height_at(x * Crags.RES + a, z * Crags.RES + b)
						if h <= 0.0:
							continue
						reached += 1
						var d := _away_from_rock(crags, Vector2(x + float(a) / Crags.RES, z + float(b) / Crags.RES))
						if d > 0.3 and h > Crags.SCREE + 0.01:
							bad_face += 1
						if d > 0.52 and h > 0.0:
							bad_scree += 1
		assert_eq(bad_middle, 0, "%s: the middle of every walkable square is at the ground" % place)
		assert_eq(bad_face, 0, "%s: nothing taller than the scree stands more than a quarter square out" % place)
		assert_eq(bad_scree, 0, "%s: no scree reaches more than half a square out" % place)
		v.queue_free()
		view = null
		await get_tree().process_frame
	# The foot does reach out over the squares beside it, on Mount Baratok at least.
	var bar := await _view()
	var out := 0
	for z in bar.grid.depth:
		for x in bar.grid.width:
			var c := Vector2i(x, z)
			if bar.board.crags.cells.has(c) or bar.grid.has_flag(c, CombatGrid.WALL):
				continue
			for q in Crags.RES + 1:
				for p in Crags.RES + 1:
					if bar.board.crags.height_at(x * Crags.RES + p, z * Crags.RES + q) > 0.0:
						out += 1
	assert_true(out > 40, "the rock and its scree reach out over the walkable squares beside them (%d points)" % out)


## N8: the range carries on past the map's edge. On the Baratok trail, whose north rows are rock, the land just past the
## north edge is raised into the mountain (in the place's rock), settles into the land within BEYOND squares, and ramps
## down beside a way out; on the map and further out the rock adds nothing.
func test_the_range_carries_on_past_the_edge() -> void:
	Look.set_style("modern", false)
	var v := await _view("mount_baratok_trail")
	await get_tree().process_frame
	var crags := v.board.crags
	var land := v.atmosphere.land
	assert_true(crags != null and land != null, "the trail has crags and land around it")
	if crags == null or land == null:
		return
	var near := Vector2(16.0, -1.5)
	assert_true(crags.beyond_edge(near) > 1.0, "the rock stands past the north edge (%.2f)" % crags.beyond_edge(near))
	assert_true(land.surface_y(near) > 1.0, "the land is raised there (%.2f)" % land.surface_y(near))
	assert_true(crags.beyond_edge(Vector2(16.0, -Crags.BEYOND - 0.5)) == 0.0, "it has settled into the land by %d squares" % int(Crags.BEYOND))
	assert_true(crags.beyond_edge(Vector2(16.0, 9.0)) == 0.0, "on the map the rock adds nothing")
	assert_true(crags.beyond_edge(Vector2(-1.0, 10.0)) < 0.3 * crags.beyond_edge(Vector2(-1.0, 6.0)), "it ramps down beside the way out on the west edge")
	var rock := false
	for node in land.root.get_children():
		if node is MeshInstance3D and node.name == "Land":
			var mi := node as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var mat := mi.get_surface_override_material(i)
				if mat != null and str(mat.get_meta("surface", "")) == "mountain/cliff":
					rock = true
	assert_true(rock, "the raised land is drawn in the place's rock")


## The distance (squares) from point `p` to the nearest rock square of `crags`.
func _away_from_rock(crags: Crags, p: Vector2) -> float:
	var best := INF
	var sq := Vector2i(floori(p.x), floori(p.y))
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var o := sq + Vector2i(dx, dz)
			if crags.cells.has(o):
				var nearest := Vector2(clampf(p.x, o.x, o.x + 1.0), clampf(p.y, o.y, o.y + 1.0))
				best = minf(best, p.distance_to(nearest))
	return best


## A thin band of rock keeps a height (`crag_floor`) instead of breaking into lone spikes: on the Amber Temple road every
## rock square stands at least the floor's low crest tall (and some stand taller), and the castle gates' `crag_scale`
## lowers their rock.
func test_floor_and_scale() -> void:
	Look.set_style("modern", false)
	var road := await _view("amber_temple_road")
	var floor_h := float((SetDressing.catalog().get("place_looks", {}) as Dictionary)["amber_temple_road"]["crag_floor"])
	var low := INF
	var high := 0.0
	for c: Vector2i in road.board.crags.cells:
		low = minf(low, road.board.crags.top_of(c))
		high = maxf(high, road.board.crags.top_of(c))
	assert_true(low >= floor_h * Crags.CREST_LOW - 0.05, "no rock square on the Amber Temple road stands under %.1f (lowest %.2f)" % [floor_h * Crags.CREST_LOW, low])
	assert_true(high - low > 0.5, "the crest rises and falls (%.2f to %.2f)" % [low, high])
	road.queue_free()
	view = null
	await get_tree().process_frame
	var gates := await _view("castle_ravenloft_gates")
	var scaled := 0.0
	for c: Vector2i in gates.board.crags.cells:
		scaled = maxf(scaled, gates.board.crags.top_of(c))
	var plain := Crags.plan(gates.board, gates.board.crags.cells, {})
	var full := 0.0
	for c: Vector2i in gates.board.crags.cells:
		full = maxf(full, plain.top_of(c))
	assert_true(scaled < full * 0.8, "the gates' rock is lower with crag_scale (%.1f against %.1f)" % [scaled, full])


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
