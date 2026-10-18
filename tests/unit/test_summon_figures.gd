extends TestCase
## Owner's art todos (2026-10-17): "Cosmin is a young boy squire, but he has a female sprite and avatar" (he wore the old
## woman's commoner sprite and portrait), and "Guardian of Faith should have a sprite when summoned" (it put only a floor
## tint on the board). The Dinosaur and Plant Spirits stood as plain capsules the same way. Each has art of its own now.


## Cosmin is a boy of fourteen, not the shared commoner woman: sprite and portrait of his own, a head under a grown man.
func test_cosmin_is_a_boy_with_his_own_sprite_and_portrait() -> void:
	var npc := Compendium.shared().get_entry("npcs", "argynvostholt_cosmin")
	assert_eq(str(npc.get("sprite", "")), "cosmin", "he walks as himself")
	assert_eq(str(npc.get("portrait", "")), "cosmin", "and speaks as himself")
	assert_true(ResourceLoader.exists("res://art/portraits/cosmin.png"), "a portrait of him")
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
