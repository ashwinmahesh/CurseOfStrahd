extends TestCase
## The custom hero (docs/art/creator.md, docs/ui/character_creation.md): the creator's options, the paper doll the
## game puts together from art/creator/pieces, and a custom character's place in the party and the story.


func _look(over: Dictionary = {}) -> Dictionary:
	var app := HeroLook.default_appearance("female", "fighter")
	app.merge(over, true)
	return app


func test_catalog_has_every_category_and_sensible_counts() -> void:
	for cat: String in ["genders", "builds", "heights", "skins", "heads", "hair", "hair_colours", "beards", "outfits",
			"portraits", "voices"]:
		assert_true(HeroLook.options(cat).size() >= 2, cat + " has options")
	assert_eq(HeroLook.options("portraits").size(), 10, "ten portraits (owner, 2026-10-06)")
	assert_eq(HeroLook.options("voices").size(), 2, "one woman's and one man's voice (owner, 2026-10-06)")
	for gender: String in ["female", "male"]:
		var d := HeroLook.default_appearance(gender)
		for key: String in HeroLook.LOOK_KEYS + ["height", "portrait", "voice"]:
			assert_true(str(d.get(key, "")) != "", "%s default has %s" % [gender, key])
		assert_true(bool(d["custom"]), "defaults are custom")
		assert_eq(str(d["art"]), str(d["portrait"]), "the art id is the portrait")


func test_ramps_are_palette_colours() -> void:
	var palette := JSON.parse_string(FileAccess.get_file_as_string(Look.PALETTE_JSON)) as Dictionary
	for cat: String in ["skins", "hair_colours"]:
		for o: Variant in HeroLook.options(cat):
			var ramp := (o as Dictionary)["ramp"] as Array
			assert_eq(ramp.size(), 4, "%s %s has four shades" % [cat, (o as Dictionary)["id"]])
			for n: Variant in ramp:
				assert_true(palette.has(str(n)), "%s is a palette colour" % n)


## The creator offers only looks whose art exists (owner, 2026-10-06: merge now, add the art options as they're
## drawn), so every look it can offer must be complete: each offered body walks and attacks, and every offered head,
## hairstyle, beard and portrait has its art. What's still to draw is listed, not failed.
func test_every_offered_look_is_complete() -> void:
	var looks := 0
	for g: String in HeroLook.offered_ids({}, "genders"):
		var app := {"gender": g}
		for b: String in HeroLook.offered_ids(app, "builds"):
			app["build"] = b
			for o: String in HeroLook.offered_ids(app, "outfits"):
				var id := "%s_%s_%s" % [g, b, o]
				var piece := HeroLook._piece_json("bodies", id)
				assert_true(piece.has("walk") and piece.has("attack"), "body %s walks and attacks" % id)
				looks += 1
		for h: String in HeroLook.offered_ids(app, "heads"):
			assert_true(FileAccess.file_exists("%s/pieces/heads/%s_%s.png" % [HeroLook.ROOT, g, h]), "head %s_%s" % [g, h])
	assert_true(looks >= 1, "the creator offers at least one complete body")
	for p: String in HeroLook.offered_ids({}, "portraits"):
		assert_true(ResourceLoader.exists("res://art/portraits/%s.png" % p), "portrait " + p)
	assert_false(HeroLook.offered_ids({}, "portraits").is_empty(), "at least one portrait")
	for g: String in ["female", "male"]:
		var d := HeroLook.default_appearance(g, "fighter")
		assert_true(HeroLook.has_pieces(d), "the %s default look is complete" % g)
	var missing: Array[String] = []
	for g: Variant in HeroLook.options("genders"):
		for b: Variant in HeroLook.options("builds"):
			for o: Variant in HeroLook.options("outfits"):
				var id := "%s_%s_%s" % [(g as Dictionary)["id"], (b as Dictionary)["id"], (o as Dictionary)["id"]]
				if not HeroLook._body_ready(id):
					missing.append(id)
	if not missing.is_empty():
		print("  note  creator art still to draw: %d of %d bodies (tools/art/creator_art.py --dry)" % [missing.size(), 36])


func test_a_pick_without_art_settles_onto_art_that_exists() -> void:
	var app := HeroLook.default_appearance("female")
	app["hair"] = "no_such_style"
	app["outfit"] = "no_such_outfit"
	var settled := HeroLook.settle(app)
	assert_true(str(settled["hair"]) in HeroLook.offered_ids(settled, "hair"), "hair moved onto drawn art")
	assert_true(str(settled["outfit"]) in HeroLook.offered_ids(settled, "outfits"), "outfit moved onto drawn art")
	assert_true(HeroLook.has_pieces(settled), "the settled look is complete")


func test_a_look_walks_and_attacks_in_every_direction() -> void:
	var app := _look({"beard": "full", "hair": "wavy", "skin": "bronze", "hair_colour": "copper"})
	var frames := HeroLook.frames(app)
	assert_true(frames != null, "the look composes")
	if frames == null:
		return
	for d in DirectionalSprite.DIRECTIONS:
		assert_eq(frames.get_frame_count(StringName("walk_" + d)), 8, "walk_" + d)
		assert_eq(frames.get_frame_count(StringName("idle_" + d)), 1, "idle_" + d)
		assert_true(frames.get_frame_count(StringName("attack_" + d)) >= 3, "attack_" + d)
		assert_false(frames.get_animation_loop(StringName("attack_" + d)), "attack_%s plays once" % d)
	assert_true(frames.has_meta("hit_frame"), "the attack knows its hit frame")
	assert_true(DirectionalSprite.has_attack(frames), "DirectionalSprite sees the attack")
	assert_eq(DirectionalSprite.cell_size(frames), 384, "walk cells are the usual size")


func test_composed_sheets_have_no_keys_left_and_wear_the_chosen_colours() -> void:
	var app := _look({"hair": "wavy", "skin": "deep", "hair_colour": "white"})
	var sheet := HeroLook.compose_sheet(app, "walk")
	var data := sheet.get_data()
	var keyed := 0
	for i in range(3, data.size(), 4 * 7):
		if data[i] == HeroLook.ALPHA_SKIN or data[i] == HeroLook.ALPHA_HAIR:
			keyed += 1
	assert_eq(keyed, 0, "every keyed pixel was tinted")
	var skin := HeroLook.ramp("skins", "deep")
	var hair := HeroLook.ramp("hair_colours", "white")
	var seen_skin := false
	var seen_hair := false
	for i in range(0, data.size(), 4 * 3):
		if data[i + 3] != 255:
			continue
		var c := Color8(data[i], data[i + 1], data[i + 2])
		seen_skin = seen_skin or c.is_equal_approx(skin[2])
		seen_hair = seen_hair or c.is_equal_approx(hair[2])
	assert_true(seen_skin, "the skin wears the chosen tone")
	assert_true(seen_hair, "the hair wears the chosen colour")


func test_tint_maps_shades_to_the_ramp() -> void:
	var img := Image.create_empty(4, 1, false, Image.FORMAT_RGBA8)
	for x in 4:
		img.set_pixel(x, 0, Color8(x, 0, 0, HeroLook.ALPHA_SKIN if x < 2 else HeroLook.ALPHA_HAIR))
	var skin := PackedColorArray([Color.RED, Color.GREEN, Color.BLUE, Color.WHITE])
	var hair := PackedColorArray([Color.BLACK, Color.YELLOW, Color.CYAN, Color.ORANGE])
	var boxes: Array[Rect2i] = [Rect2i(0, 0, 4, 1)]
	HeroLook.tint(img, boxes, skin, hair)
	assert_true(img.get_pixel(0, 0).is_equal_approx(Color.RED), "skin shade 0")
	assert_true(img.get_pixel(1, 0).is_equal_approx(Color.GREEN), "skin shade 1")
	assert_true(img.get_pixel(2, 0).is_equal_approx(Color.CYAN), "hair shade 2")
	assert_true(img.get_pixel(3, 0).is_equal_approx(Color.ORANGE), "hair shade 3")
	assert_eq(img.get_pixel(3, 0).a8, 255, "tinted pixels are opaque")


func test_height_follows_species_and_pick() -> void:
	var tall := HeroLook.height_units(_look({"height": "tall"}), "human")
	var short := HeroLook.height_units(_look({"height": "short"}), "human")
	var halfling := HeroLook.height_units(_look(), "halfling")
	assert_true(tall > short, "tall stands taller than short")
	assert_true(halfling < short, "a halfling is shorter than a short human")


func _hero(name: String = "Vasha Dunmere") -> Character:
	var b := CharacterBuilder.new(null, {"appearance": _look(), "identity": {"pronouns": "she/her"}})
	b.set_class("fighter")
	b.set_background("soldier")
	b.set_species("human")
	b.set_name(name)
	return b.preview()


func test_a_custom_character_gets_its_paper_doll_in_game() -> void:
	var ch := _hero()
	var aid := CombatToken.art_for(ch)
	assert_eq(aid, "hero_01", "the art id is the portrait")
	assert_true(HeroLook.known(aid), "registered with the look")
	var frames := DirectionalSprite.frames_for(aid)
	assert_true(frames != null and frames.has_animation(&"walk_s"), "its sprite is the composed look")
	assert_true(absf(CombatToken.height_for(aid) - HeroLook.height_units(ch.build["appearance"] as Dictionary, "human")) < 0.001,
		"its height comes from its picks")


func test_a_hero_cannot_take_a_companions_name() -> void:
	var b := CharacterBuilder.new(null, {"appearance": _look()})
	b.set_name("Ilse Varga")
	assert_false(b.name_problems().is_empty(), "a pregen's name is refused")
	b.set_name("Ilse Hartmann")
	assert_true(b.name_problems().is_empty(), "a different name is fine")
	var plain := CharacterBuilder.new(null, {})
	plain.set_name("Ilse Varga")
	assert_true(plain.name_problems().is_empty(), "the pregen herself keeps her name")


func test_a_hero_never_answers_for_a_companion() -> void:
	var ch := _hero()
	ch.name = "Tamsin Tealeaf"
	assert_false(StoryState.member_matches(ch, "name:tamsin_tealeaf"), "name: selectors skip the custom hero")
	var tamsin := Pregens.build("tamsin_tealeaf", 1)
	assert_true(StoryState.member_matches(tamsin, "name:tamsin_tealeaf"), "the real Tamsin still answers")
