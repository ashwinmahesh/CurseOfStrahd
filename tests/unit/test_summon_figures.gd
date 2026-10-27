extends TestCase
## Owner's art todos (2026-10-17): "Cosmin is a young boy squire, but he has a female sprite and avatar" (he wore the old
## woman's commoner sprite and portrait), and "Guardian of Faith should have a sprite when summoned" (it put only a floor
## tint on the board). The Dinosaur and Plant Spirits stood as plain capsules the same way. Each has art of its own now.


## Cosmin is a boy of fourteen, not the shared commoner woman: sprite and portrait of his own, a head under a grown man.
func test_cosmin_is_a_boy_with_his_own_sprite_and_portrait() -> void:
	var npc := Compendium.shared().get_entry("npcs", "argynvostholt_cosmin")
	assert_eq(str(npc.get("sprite", "")), "cosmin", "he walks as himself")
	assert_eq(str(npc.get("portrait", "")), "cosmin", "and speaks as himself")
	assert_true(ArtPaths.exists("art/portraits/cosmin.png"), "a portrait of him")
	var frames := DirectionalSprite.frames_for("cosmin")
	assert_true(DirectionalSprite.has_attack(frames), "a walk and an attack")
	var sheet := (frames.get_frame_texture(&"idle_s", 0) as AtlasTexture).atlas.resource_path
	assert_true(sheet.contains("cosmin"), "drawn on his own images, not the commoner's (%s)" % sheet)
	var boy := CombatToken.height_for("cosmin")
	assert_true(boy > CombatToken.height_for("ilya_krezkov") and boy < CombatToken.height_for("commoner"),
		"taller than Ilya (8), shorter than a grown commoner (%.2f)" % boy)


## Guardian of Faith: a figure hovers where it was called, on top of the tinted area, and goes when the spell does.
func test_guardian_of_faith_stands_on_the_board() -> void:
	var board := ArenaBoard.build(CombatGrid.from_rows(["..........", "..........", "..........", "..........", ".........."]))
	add_child(board)
	var field := FieldView.create(board)
	add_child(field)
	var f := FieldObject.new(FieldObject.Kind.ZONE, "guardian_of_faith", "Guardian of Faith")
	f.cell = Vector2i(5, 2)
	f.origin = Vector2(5.5, 2.5)
	f.cells.assign([Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2), Vector2i(5, 1), Vector2i(5, 3)])
	f.rules = {"colour": "candle"}
	f.rounds_left = 5
	field.sync([f])
	var zone := field.node_for(f.id)
	var figure := zone.get_node_or_null("Figure_guardian_of_faith") as DirectionalSprite
	assert_true(figure != null, "the guardian is drawn")
	if figure != null:
		assert_eq(figure.position.x, 5.5, "at the middle of its square")
		assert_eq(figure.position.z, 2.5)
		assert_eq(figure.position.y, board.floor_y(Vector2i(5, 2)), "on the floor there")
	assert_between(CombatToken.height_for("guardian_of_faith"), 1.3, 2.8, "a Large guardian")
	assert_true(zone.get_child_count() >= 2, "the tinted area is still there with it")
	# It swings at what it strikes: turned toward that square, the attack playing.
	f.strikes = 1
	f.struck_cell = Vector2i(8, 2)
	field.sync([f])
	if figure != null:
		assert_true(figure.is_attacking(), "the guardian swings")
		assert_true(figure.facing.x > 0.9, "at the square it struck")
	# Another spell's area has no figure.
	var other := FieldObject.new(FieldObject.Kind.ZONE, "spirit_guardians", "Spirit Guardians")
	other.origin = Vector2(2.5, 2.5)
	other.cells.assign([Vector2i(2, 2)])
	other.rounds_left = 5
	field.sync([f, other])
	assert_eq(field.node_for(other.id).find_children("Figure_*", "", true, false).size(), 0, "Spirit Guardians draws none")
	f.ended = true
	other.ended = true
	field.sync([f, other])
	await get_tree().process_frame
	assert_false(is_instance_valid(zone), "gone with the spell")
	field.queue_free()
	board.queue_free()


## The area counts the blows it lands and remembers where the last one fell, which FieldView swings the guardian at.
func test_guardian_of_faith_counts_its_strikes() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.high_caster(e, ["guardian_of_faith"], Vector2i(0, 0))
	var t := TestCombat.punching_bag(e, Vector2i(6, 4), 300)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "guardian_of_faith", 4, [], Vector2(5.5, 4.5)).ok)
	var o := e.spells.zones.object_of(c.id, "guardian_of_faith")
	assert_eq(o.strikes, 0, "no blow yet")
	e.spells.zones._affect(o, t, "start_turn", CombatResult.new(), {})
	assert_eq(o.strikes, 1, "one blow")
	assert_eq(o.struck_cell, t.cell, "on the one it hurt")


## Every creature a spell calls up is drawn from a sprite with a walk and an attack sheet, and has a portrait for the turn
## bar: no capsule on the board (a stat block with no sprite is drawn as one).
func test_every_summoned_creature_has_a_sprite_and_a_portrait() -> void:
	var checked := 0
	var gaps: Array[String] = []
	for b in DrawnCreatures.blocks():
		var data := b["data"] as Dictionary
		if not bool(data.get("summon", false)):
			continue
		checked += 1
		var art := CombatToken.monster_art(data)
		if not DirectionalSprite.has_attack(DirectionalSprite.frames_for(art)):
			gaps.append("%s has no walk and attack sheet (%s)" % [b["label"], art])
		if not ArtPaths.exists("art/portraits/%s.png" % art):
			gaps.append("%s has no portrait (%s)" % [b["label"], art])
	assert_true(checked >= 20, "the summons are checked (%d)" % checked)
	assert_eq(gaps, [] as Array[String], "summons drawn as capsules")


## The two spirits that had none stand at the height their size asks for (test_creature_sizes checks the bands).
func test_the_dinosaur_and_plant_spirits_have_their_own_figures() -> void:
	for pair: Array in [["dinosaur_spirit", "huge"], ["plant_spirit", "large"]]:
		var id := str(pair[0])
		var block := SummonBlocks.for_spell("summon_" + id.trim_suffix("_spirit"), 9, "", {})
		assert_eq(str(block.get("id", "")), id)
		assert_eq(str(block.get("size", "")), str(pair[1]))
		assert_eq(CombatToken.monster_art(block), id, "%s wears its own sprite" % id)
		var band := DrawnCreatures.BANDS[str(pair[1])] as Array
		assert_between(DrawnCreatures.drawn_height(block), float(band[0]), float(band[1]), "%s fills its squares" % id)
