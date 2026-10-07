extends TestCase
## The HD surfaces and decals (Improvement Ideas W4 and W10, docs/art/textures.md and docs/art/decals.md): every
## surface the recipes name has its 2K set in the Modern look (albedo, normal and ORM maps, and its edge-matched
## variants, all one size), and boards are dressed with decals by rule, on floors and on walls, in the Modern look only.


func before_each() -> void:
	GameState.reset()
	ModeController.force(ModeController.Mode.EXPLORATION)
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func after_each() -> void:
	Look.set_style(Look.DEFAULT_STYLE, false)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Every recipe's surface has its HD set, and the files load at matching sizes.
func test_every_surface_has_its_hd_set() -> void:
	var rec := JSON.parse_string(FileAccess.get_file_as_string("res://tools/art/surface_recipes.json")) as Dictionary
	var themes := Look.textures().get("themes", {}) as Dictionary
	for key: String in rec["surfaces"]:
		var parts := key.split("/")
		var info := (themes.get(parts[0], {}) as Dictionary).get(parts[1], {}) as Dictionary
		assert_false(info.is_empty(), "%s is in the manifest" % key)
		var size := -1
		for f: String in ["hd_file", "normal_file", "orm_file"]:
			assert_true(ResourceLoader.exists("res://" + str(info.get(f, ""))), "%s has its %s" % [key, f])
		var albedo := load("res://" + str(info.get("hd_file", ""))) as Texture2D
		if albedo != null:
			size = albedo.get_width()
		var want := int((rec["surfaces"][key] as Dictionary).get("variants", 1))
		var variants := info.get("variants", []) as Array
		assert_eq(variants.size(), want - 1, "%s has its variants" % key)
		for v: Dictionary in variants:
			var t := load("res://" + str(v.get("file", ""))) as Texture2D
			assert_true(t != null and t.get_width() == size, "%s's variants match its size" % key)
			for f: String in ["normal_file", "orm_file"]:
				assert_true(ResourceLoader.exists("res://" + str(v.get(f, ""))), "%s's variant has its %s" % [key, f])
	assert_true(ResourceLoader.exists("res://" + str(Look.textures().get("macro_file", ""))), "the macro noise exists")


## Every decal loads, and a village street, a dungeon and a castle hall are dressed with them in the Modern look; the
## Classic look keeps its bare floors.
func test_boards_are_dressed_with_decals() -> void:
	for id: String in Clutter.manifest():
		var info := Clutter.manifest()[id] as Dictionary
		assert_true(load("res://" + str(info["file"])) is Texture2D, "decal %s loads" % id)
	Look.set_style("modern", false)
	for loc_id: String in ["village_of_barovia", "death_house_dungeon_2", "castle_ravenloft_main_floor"]:
		var v := LocationView.create(loc_id, GameState.story, null, Dice.roller, "default")
		add_child(v)
		await _frames(1)
		var decals := v.board.find_children("*", "Decal", true, false)
		assert_true(decals.size() >= 8, "%s has its decals (%d)" % [loc_id, decals.size()])
		var walls := 0
		for d: Decal in decals:
			if absf(d.global_basis.y.y) < 0.1:
				walls += 1
		if loc_id != "village_of_barovia":
			assert_true(walls > 0, "%s has marks on its walls" % loc_id)
		v.queue_free()
		await _frames(1)
	# Wheel ruts run along the roads between the crossroads' ways out (W11's GroundRelief.roads()).
	var x := LocationView.create("svalich_crossroads", GameState.story, null, Dice.roller, "default")
	add_child(x)
	await _frames(1)
	var ruts := 0
	for d: Decal in x.board.find_children("*", "Decal", true, false):
		if d.texture_albedo != null and d.texture_albedo.resource_path.contains("floor_ruts"):
			ruts += 1
	assert_true(ruts >= 40, "the crossroads' roads are rutted (%d)" % ruts)
	x.queue_free()
	await _frames(1)
	Look.set_style("classic", false)
	var c := LocationView.create("village_of_barovia", GameState.story, null, Dice.roller, "default")
	add_child(c)
	await _frames(1)
	assert_eq(c.board.find_children("*", "Decal", true, false).size(), 0, "Classic is left as it was")
	c.queue_free()
