extends TestCase
## Ground cover and small built things drawn as natural land (owner 2026-10-19: "Basically we want the world to look
## more natural"; the vault's Natural Maps Plan, N7): difficult ground is planted as thickets across its squares instead
## of one bush a square (GroundCover), a yard's inner pillars are weathered standing stones (StandingStone), its outer
## and low walls are dry stone with an uneven top (Drystone), and a place in ruin (place_looks `ruin`) has its walls
## broken. The rules grid never sees any of it; Classic keeps what it had.

var view: LocationView
var _was := ""


func before_each() -> void:
	_was = Look.style()
	GameState.reset()
	ModeController.force(ModeController.Mode.EXPLORATION)
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func after_each() -> void:
	if view != null:
		view.queue_free()
		view = null
	Look.set_style(_was, false)
	GameState.reset()


func _view(loc_id: String) -> LocationView:
	view = LocationView.create(loc_id, GameState.story, null, Dice.roller, "default")
	add_child(view)
	await get_tree().process_frame
	return view


## The board's dry stone pieces of one kind ("outer", "low", "yard"), and its standing stones ("stone"). (Repeated
## names become @MeshInstance3D@N, so they are found by what they are.)
func _pieces(board: ArenaBoard, kind: String) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c: Node in board.get_children():
		if not c is MeshInstance3D:
			continue
		if kind == "stone":
			if c.has_meta("standing_stone"):
				out.append(c as MeshInstance3D)
		elif c.has_meta("drystone") and str(c.get_meta("drystone")) == kind:
			out.append(c as MeshInstance3D)
	return out


# --- Ground cover -------------------------------------------------------------------------------------------------

## The Zarovich reed island is ringed by difficult squares (reeds round the shore). Modern plants them as thickets: every
## difficult square has a clump near its middle, no clump stands on water, and the whole is no heavier than the one bush a
## square it replaces. Clumps differ in size and heading, and don't sit on a lattice.
func test_difficult_squares_are_planted_as_thickets() -> void:
	Look.set_style("modern", false)
	var v := await _view("zarovich_reed_island")
	var board := v.board
	assert_true(board._cover != null, "the island's reeds and brambles are planted together")
	if board._cover == null:
		return
	var diff := 0
	var bare: Array[Vector2i] = []
	var on_water := 0
	var scales: Array[float] = []
	var offsets: Array[float] = []
	for z in board.grid.depth:
		for x in board.grid.width:
			var c := Vector2i(x, z)
			if not board.grid.has_flag(c, CombatGrid.DIFFICULT) or board.grid.has_flag(c, CombatGrid.WALL | CombatGrid.WATER):
				continue
			diff += 1
			var mid := Vector2(c.x + 0.5, c.y + 0.5)
			var near := false
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					for k: Variant in board._cover.clumps_in(c + Vector2i(dx, dz)):
						var cl := k as GroundCover.Clump
						if cl.at.distance_to(mid) <= maxf(GroundCover.COVER * 0.9, cl.radius * 0.85) + 0.01:
							near = true
			if not near:
				bare.append(c)
			for k: Variant in board._cover.clumps_in(c):
				var cl := k as GroundCover.Clump
				scales.append(cl.scale)
				offsets.append(cl.at.distance_to(mid))
				# Its smallest half-width never reaches into water.
				for dz in range(-2, 3):
					for dx in range(-2, 3):
						var n := c + Vector2i(dx, dz)
						if board.grid.in_bounds(n) and board.grid.has_flag(n, CombatGrid.WATER):
							var ex := maxf(maxf(float(n.x) - cl.at.x, cl.at.x - float(n.x + 1)), 0.0)
							var ez := maxf(maxf(float(n.y) - cl.at.y, cl.at.y - float(n.y + 1)), 0.0)
							if sqrt(ex * ex + ez * ez) + GroundCover.REACH_WET + 0.02 < cl.half_min:
								on_water += 1
	assert_eq(bare, [] as Array[Vector2i], "every difficult square has a clump near its middle")
	assert_eq(on_water, 0, "no clump reaches into water")
	assert_true(board._cover.count <= int(ceil(diff * 1.5)), "no heavier than a bush a square (%d clumps, %d squares)" % [board._cover.count, diff])
	assert_true(board._cover.count >= int(diff * 0.5), "thick enough to read as a thicket (%d clumps, %d squares)" % [board._cover.count, diff])
	var lo := 9.0
	var hi := 0.0
	for s in scales:
		lo = minf(lo, s)
		hi = maxf(hi, s)
	assert_true(hi - lo > 0.4, "clumps differ in size (%.2f to %.2f)" % [lo, hi])
	var spread := 0.0
	for o in offsets:
		spread = maxf(spread, o)
	assert_true(spread > 0.3, "clumps stand off the squares' middles (%.2f)" % spread)


## The clumps are the place's own dressing (catalog `difficult`), marked ground cover so they may grow into each other.
func test_clumps_are_ground_cover() -> void:
	Look.set_style("modern", false)
	var v := await _view("zarovich_reed_island")
	var n := 0
	for g: Node in v.board.find_children("*", "Node3D", true, false):
		if g.has_meta("ground_cover"):
			n += 1
	assert_true(n > 20, "the reed island's thickets are on the board (%d clumps)" % n)


## Classic keeps one bush on each difficult square.
func test_classic_keeps_a_bush_a_square() -> void:
	Look.set_style("classic", false)
	var v := await _view("zarovich_reed_island")
	assert_true(v.board._cover == null, "Classic plants no thickets")


# --- Standing stones ----------------------------------------------------------------------------------------------

## Krezk's pool has seven shrine pillars. Each is a standing stone: narrower than its square, differing in height, one
## leaning off its middle, and standing over its own '#'.
func test_pillars_are_standing_stones() -> void:
	Look.set_style("modern", false)
	var v := await _view("krezk_pool_of_the_white_sun")
	var board := v.board
	var stones := _pieces(board, "stone")
	assert_eq(stones.size(), 7, "seven standing stones at the pool")
	var tops: Array[float] = []
	var leaned := false
	for s in stones:
		var cell := Vector2i(floori(s.position.x), floori(s.position.z))
		assert_true(board.grid.has_flag(cell, CombatGrid.WALL), "a stone stands on a wall square %s" % cell)
		assert_true(StandingStone.reach_of(s) <= StandingStone.REACH + 0.02, "a stone stays inside its square (%.2f)" % StandingStone.reach_of(s))
		var box := s.get_aabb()
		tops.append(box.position.y + box.size.y)
		var mid := box.get_center()
		if Vector2(mid.x, mid.z).length() > 0.03:
			leaned = true
	var lo := 9.0
	var hi := 0.0
	for t in tops:
		lo = minf(lo, t)
		hi = maxf(hi, t)
	assert_true(lo > 1.0 and hi < ArenaBoard.WALL_H * 1.15, "the stones stand about a pillar high (%.2f to %.2f)" % [lo, hi])
	assert_true(hi - lo > 0.12, "no two stones the same height (%.2f to %.2f)" % [lo, hi])
	assert_true(leaned, "a stone leans")


## A free-standing block of 2 x 2 pillar squares is one tor, and a lone pillar its own stone.
func test_a_two_by_two_block_is_one_tor() -> void:
	Look.set_style("modern", false)
	var rows := [
		"##########",
		"#........#",
		"#.##..#..#",
		"#.##.....#",
		"#........#",
		"##########",
	]
	var board := ArenaBoard.build(CombatGrid.from_rows(rows), "shrine_yard", "")
	add_child(board)
	var stones := _pieces(board, "stone")
	assert_eq(stones.size(), 2, "the block is one tor and the lone pillar a stone")
	var wide := 0
	for s in stones:
		if StandingStone.reach_of(s) > 0.6:
			wide += 1
	assert_eq(wide, 1, "one of them is the tor")
	board.queue_free()


# --- Dry stone ----------------------------------------------------------------------------------------------------

## The outer wall's coping rises and falls, a stone now and then broken or missing, but no stone is lower than half the
## whole wall: tried over many squares of wall, whole and in ruin (three fifths, and a little lower to begin with).
func test_walls_never_drop_below_half() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 1.0
	for ruin: float in [0.0, 1.0]:
		var frame := Drystone.frame_of(1.4, ruin)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var lo := INF
		var hi := -INF
		var broken := 0
		var total := 0
		for u in 400:
			for s: Dictionary in Drystone._stones(rng, noise, float(u), frame.x, frame.y, ruin, 2):
				for k: String in ["h0", "h1"]:
					lo = minf(lo, float(s[k]))
					hi = maxf(hi, float(s[k]))
					total += 1
					if float(s[k]) < frame.x * 0.85:
						broken += 1
		assert_true(lo >= (0.5 + 0.1 * ruin) * 1.4 - 0.001, "ruin %.1f: no stone below %.2f of the whole wall (lowest %.2f)" % [ruin, 0.5 + 0.1 * ruin, lo / 1.4])
		assert_true(hi - lo > 0.3, "ruin %.1f: the coping rises and falls (%.2f to %.2f)" % [ruin, lo, hi])
		assert_true(broken > 0, "ruin %.1f: some stones are broken" % ruin)
		if ruin > 0.0:
			assert_true(float(broken) / total > 0.1, "a ruin has more broken than a whole wall (%d of %d)" % [broken, total])


## A ruin falls in stretches: along a wall the broken stones come in runs (a stretch of wall down, a stretch standing),
## not scattered one by one as chips are.
func test_a_ruin_falls_in_stretches() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 1.0
	var frame := Drystone.frame_of(1.0, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var down: Array[bool] = []
	for u in 300:
		for s: Dictionary in Drystone._stones(rng, noise, float(u), frame.x, frame.y, 1.0, 2):
			down.append(float(s["h0"]) < frame.x * 0.82)
	var same := 0
	var fallen := 0
	for i in range(1, down.size()):
		if down[i] == down[i - 1]:
			same += 1
	for d in down:
		if d:
			fallen += 1
	var f := float(fallen) / down.size()
	assert_true(f > 0.15 and f < 0.85, "some of the wall is down and some stands (%d of %d)" % [fallen, down.size()])
	var scattered := f * f + (1.0 - f) * (1.0 - f)   # how often neighbours would agree if stones fell one by one
	assert_true(float(same) / (down.size() - 1) > scattered + 0.08, "neighbours agree more than chips would (%.2f against %.2f)" % [float(same) / (down.size() - 1), scattered])


## A place whose look says `rough` lays its walls more evenly: a castle's parapet (rough 0.25) rises and falls far less
## than a churchyard's wall, with fewer broken stones.
func test_a_castles_parapet_is_laid_nearly_straight() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 1.0
	var spread: Array[float] = []
	for rough: float in [1.0, 0.25]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var all: Array[float] = []
		for u in 400:
			for s: Dictionary in Drystone._stones(rng, noise, float(u), 1.0, 0.5, 0.0, 2, rough):
				all.append(float(s["h0"]))
				all.append(float(s["h1"]))
		var mean := 0.0
		for h in all:
			mean += h / all.size()
		var variance := 0.0
		for h in all:
			variance += (h - mean) * (h - mean) / all.size()
		spread.append(sqrt(variance))
	assert_true(spread[1] < spread[0] * 0.6, "the parapet varies less (%.3f against %.3f)" % [spread[1], spread[0]])
	Look.set_style("modern", false)
	var v := await _view("castle_ravenloft_overlook")
	assert_eq(float(v.board._look.get("rough", 1.0)), 0.25, "the overlook's look says how evenly its walls are laid")


## The Abbey garden's outer wall is built stone by stone: every border square has its piece, none stands taller than the
## wall it replaces could (OUTER_H and a little), and the heights along it differ.
func test_the_outer_wall_is_dry_stone() -> void:
	Look.set_style("modern", false)
	var v := await _view("abbey_of_st_markovia_garden")
	var board := v.board
	var walls := _pieces(board, "outer")
	var border := 0
	for z in board.grid.depth:
		for x in board.grid.width:
			var c := Vector2i(x, z)
			if board.grid.has_flag(c, CombatGrid.WALL) and board._on_border(c):
				border += 1
	assert_eq(walls.size(), border, "a piece of wall on every border wall square")
	var lo := 9.0
	var hi := 0.0
	for w in walls:
		var box := w.get_aabb()
		lo = minf(lo, box.position.y + box.size.y)
		hi = maxf(hi, box.position.y + box.size.y)
		# Inside its own square, bar a hair.
		assert_true(box.position.x >= -0.02 and box.position.z >= -0.02 and box.end.x <= 1.02 and box.end.z <= 1.02, "a wall piece stays in its square")
	assert_true(hi <= ArenaBoard.OUTER_H * 1.35, "no wall piece taller than the old wall could be (%.2f)" % hi)
	assert_true(hi - lo > 0.1, "the wall's height changes along it (%.2f to %.2f)" % [lo, hi])


## Low walls are dry stone, stay inside their squares and keep the name battle scenery reads them by.
func test_low_walls_are_dry_stone() -> void:
	Look.set_style("modern", false)
	var v := await _view("krezk_pool_of_the_white_sun")
	var walls := _pieces(v.board, "low")
	assert_true(walls.size() >= 3, "the pool's low wall run is built (%d pieces)" % walls.size())
	for w in walls:
		var box := w.get_aabb()
		assert_true(box.position.x >= -0.02 and box.position.z >= -0.02 and box.end.x <= 1.02 and box.end.z <= 1.02, "a low wall piece stays in its square")
		assert_true(box.position.y + box.size.y <= ArenaBoard.LOW_H * 1.3, "no taller than a low wall")


# --- Ruin ---------------------------------------------------------------------------------------------------------

## Argynvostholt, Berez and the Gulthias Tree's yard are ruins (place_looks `ruin`): their walls are drawn broken, in
## Modern; Classic keeps what it had.
func test_ruins_have_broken_walls() -> void:
	assert_eq(Ruin.amount({"ruin": true}), 1.0, "true is a full ruin")
	assert_eq(Ruin.amount({}), 0.0, "no ruin key, no ruin")
	assert_eq(Ruin.amount({"ruin": 0.5}), 0.5, "a number is how far")
	Look.set_style("modern", false)
	var v := await _view("argynvostholt")
	var yard := _pieces(v.board, "yard")
	assert_true(yard.size() > 10, "Argynvostholt's yard walls are drawn (%d)" % yard.size())
	for w in yard:
		var box := w.get_aabb()
		assert_true(box.position.y + box.size.y <= TownBuilder.YARD_WALL_H * 1.3, "no taller than a yard wall")
	v.queue_free()
	view = null
	var b := await _view("berez")
	var low := _pieces(b.board, "low")
	assert_true(low.size() > 20, "Berez's ruined foundations are broken stone (%d)" % low.size())
	b.queue_free()
	view = null
	Look.set_style("classic", false)
	var c := await _view("argynvostholt")
	assert_eq(_pieces(c.board, "yard").size(), 0, "Classic keeps the kit's wall")
