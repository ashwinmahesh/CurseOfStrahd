extends TestCase
## Every creature is drawn as big as the squares it holds (owner, 2026-10-14: "make sure every enemy sprite is sized
## correctly when laid out in the world"): a Huge giant constrictor snake had stood no taller than a man (1.2) in the
## middle of its 3 x 3 squares, a Large rug of smothering 0.4 on its 2 x 2. DrawnCreatures lists every monster, summon
## and shape; make capture SCENE=res://tools/capture/creature_sizes_capture.tscn shoots them all beside a hero.


## Each figure's drawn height (its tallest or widest view: every sheet frames its biggest view to the cell) is within
## its size category's band, so a new monster on the default height or a smaller creature's sprite shows up here.
func test_every_creature_is_drawn_at_its_size() -> void:
	var off: Array[String] = []
	var drawn := 0
	for b in DrawnCreatures.blocks():
		var h := DrawnCreatures.drawn_height(b["data"] as Dictionary)
		if h <= 0.0:
			continue   # no sprite yet: the placeholder capsule grows with its squares
		drawn += 1
		var band := DrawnCreatures.BANDS[str(b["size"])] as Array
		if h < float(band[0]) or h > float(band[1]):
			off.append("%s (%s: %.2f, wants %.2f to %.2f)" % [b["label"], b["size"], h, band[0], band[1]])
	for s in DrawnCreatures.shapes():
		var h2 := CombatToken.height_for(str(s["art"]))
		var band2 := DrawnCreatures.BANDS[str(s["size"])] as Array
		if h2 < float(band2[0]) or h2 > float(band2[1]):
			off.append("%s (%s: %.2f, wants %.2f to %.2f)" % [s["label"], s["size"], h2, band2[0], band2[1]])
	assert_true(drawn >= 150, "every monster and summon found (%d)" % drawn)
	assert_true(off.is_empty(), "drawn too small or too big for their squares: %s" % ", ".join(off))


## A bigger size category is drawn bigger: from Large up each band starts above where the one two sizes down ends, and
## covers at least 0.65 of its squares' width (a dire wolf's share of its 2 x 2, Old Greytooth's of his 3 x 3).
func test_the_bands_grow_with_the_size() -> void:
	var sizes := DrawnCreatures.SIZES
	for i in range(3, sizes.size()):
		var band := DrawnCreatures.BANDS[sizes[i]] as Array
		var two_down := DrawnCreatures.BANDS[sizes[i - 2]] as Array
		assert_true(float(band[0]) > float(two_down[1]), "%s starts above where %s ends" % [sizes[i], sizes[i - 2]])
		var cells := CombatGrid.size_cells_for(StringName(sizes[i]))
		if cells > 1:
			assert_true(float(band[0]) >= 0.65 * cells - 0.001, "%s fills its %d squares" % [sizes[i], cells])


## A sheet cut to its figure (each frame an AtlasTexture with a margin, as every HD sheet is) stands the figure on the
## ground line DirectionalSprite.create draws it to (its cell's bottom a 25th of the cell under the floor), centred on
## its squares, its biggest view filling the cell as the height assumes (1 / 1.12), in every direction it stands in.
func test_cut_sheets_stand_on_their_squares() -> void:
	var arts := {}
	for b in DrawnCreatures.blocks():
		arts[CombatToken.monster_art(b["data"] as Dictionary)] = str(b["label"])
	for s in DrawnCreatures.shapes():
		arts[str(s["art"])] = str(s["label"])
	var checked := 0
	var off: Array[String] = []
	for art: String in arts:
		var frames := DirectionalSprite.frames_for(art)
		if frames == null:
			continue
		var biggest := 0.0
		var cut := true
		for d in DirectionalSprite.DIRECTIONS:
			var anim := DirectionalSprite.anim_for(frames, "idle", d)[0] as StringName
			for i in frames.get_frame_count(anim):
				var tex := frames.get_frame_texture(anim, i) as AtlasTexture
				if tex == null or tex.margin == Rect2():
					cut = false
					break
				var cell := float(tex.get_height())
				var feet := (0.96 * cell - (tex.margin.position.y + tex.region.size.y)) / cell
				var centre := (tex.margin.position.x + tex.region.size.x / 2.0 - tex.get_width() / 2.0) / cell
				if absf(feet) > 0.035:
					off.append("%s idle_%s stands %.0f%% of its height off the ground" % [art, d, feet * 112.0])
				if absf(centre) > 0.03:
					off.append("%s idle_%s is %.0f%% off its squares' centre" % [art, d, centre * 112.0])
				biggest = maxf(biggest, maxf(tex.region.size.y, tex.region.size.x) / cell * 1.12)
			if not cut:
				break
		if not cut:
			continue
		checked += 1
		if biggest < 0.85 or biggest > 1.12:
			off.append("%s fills %.0f%% of its height" % [art, biggest * 100.0])
	assert_true(checked >= 60, "found the cut sheets (%d)" % checked)
	assert_true(off.is_empty(), ", ".join(off))


## The walk's front view stands on the ground too (owner, 2026-10-14): the giant hyena's hopped half its frames a
## sixteenth of its height into the air.
func test_the_giant_hyena_walks_on_the_ground() -> void:
	var frames := DirectionalSprite.frames_for("giant_hyena")
	for anim: StringName in [&"walk_s", &"attack_s"]:
		for i in frames.get_frame_count(anim):
			var tex := frames.get_frame_texture(anim, i) as AtlasTexture
			var cell := float(tex.get_height())
			var feet := (0.96 * cell - (tex.margin.position.y + tex.region.size.y)) / cell
			assert_between(feet, -0.035, 0.035, "%s frame %d" % [anim, i])


## The board grows or shrinks a figure from the size it was drawn for (CombatToken.size_scale): a Medium hero Enlarged
## to Large twice as big, an ogre Enlarged to Huge half again, and a Large ogre back from Banishment as it was, not
## twice its size.
func test_a_figure_grows_from_its_own_size() -> void:
	var e := TestCombat.open_field()
	var ogre := TestCombat.foe(e, "ogre", Vector2i(4, 2))
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1))
	var ot := CombatToken.create(ogre)
	var ht := CombatToken.create(hero)
	assert_eq(ot.size_scale(), Vector3.ONE, "a Large ogre is drawn at its own height")
	assert_eq(ht.size_scale(), Vector3.ONE, "a Medium hero too")
	hero.size_cells = 2
	ogre.size_cells = 3
	assert_eq(ht.size_scale(), Vector3.ONE * 2.0, "Enlarged to Large: twice as big")
	assert_eq(ot.size_scale(), Vector3.ONE * 1.5, "Enlarged to Huge: half again")
	ogre.size_cells = 1
	assert_eq(ot.size_scale(), Vector3.ONE * 0.5, "Reduced to Medium: half as big")
	ot.free()
	ht.free()


## A rider sits on its mount's back as the mount is drawn: on a Large steed (1.7 high) at 0.8 of its height, not at
## twice that (the old rule doubled a Large mount's height, as if its figure were drawn twice as tall).
func test_a_rider_sits_on_a_large_mount() -> void:
	var e := TestCombat.open_field()
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	var steed := e.add(Monster.from_data(SummonBlocks.otherworldly_steed(2, "celestial", 5, 13)), &"party", Vector2i(3, 2))
	TestCombat.start_with(e, hero)
	var board := ArenaBoard.build(e.grid)
	add_child(board)
	var tokens := {}
	for c in e.combatants:
		var t := CombatToken.create(c)
		t.position = board.cell_center(c.cell, c.size_cells)
		add_child(t)
		tokens[c.id] = t
	assert_true(e.mount(hero, steed).ok, "mounts")
	# Where the board stands the rider (CombatView._token_spot reads only the fight, the board and the figures).
	var view := CombatView.new()
	view.e = e
	view.board = board
	view.tokens = tokens
	var spot := view._token_spot(hero, hero.cell)
	var back := CombatToken.height_of(steed) * 0.8
	assert_between(spot.y - board.cell_center(steed.cell, steed.size_cells).y, back - 0.01, back + 0.01, "on its back")
	view.free()
	board.queue_free()
	for t: CombatToken in tokens.values():
		t.queue_free()
