extends TestCase
## The Amber Temple's paid art (Amber Temple Look Plan P1 to P3: six Gemini sheets cut by Blender): the violet-black marble and
## the amber-glazed wall, the seeps, rime, scrapes and gold inlay decals, and the pact ledger, shards, offering candles and
## icicles props are all there, named by the places that use them, and drawn in the Modern finish.

const PLACES := ["amber_temple_faceless_god", "amber_temple_library", "amber_temple_vault"]
const PROPS := ["copper_ledger", "amber_shards", "offering_candles", "amber_spire", "icicles_long", "icicles_short",
	"icicles_cluster", "icicles_single"]


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	Look.set_style("modern", false)


func after_each() -> void:
	Look.set_style(Look.DEFAULT_STYLE, false)


func _view(loc_id: String) -> LocationView:
	var v := LocationView.create(loc_id, GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


func test_the_surfaces_decals_and_props_are_all_there() -> void:
	assert_true(Look.cel_textured("amber/violet_marble") != null, "the violet-black marble")
	assert_true(Look.cel_textured("amber/glazed_wall") != null, "the amber-glazed wall")
	for id: String in ["wall_seeps_1", "wall_seeps_2", "wall_seeps_3", "wall_seeps_4", "floor_temple_1", "floor_temple_2", "floor_temple_3",
			"floor_temple_4"]:
		assert_true(Clutter.manifest().has(id), "the decal %s" % id)
		var info := Clutter.manifest().get(id, {}) as Dictionary
		assert_true(ResourceLoader.exists(ArtPaths.of(str(info.get("file", "")))), "%s is imported" % id)
	for id: String in PROPS:
		assert_true(SetDressing.has_art(id), "the prop %s" % id)
	var rules := (SetDressing.catalog().get("clutter", {}) as Dictionary).get("places", {}) as Dictionary
	for place: String in PLACES:
		assert_true(rules.has(place), "%s has its own decal rules" % place)
		for r: Variant in rules.get(place, []):
			for name: Variant in (r as Dictionary).get("decals", []):
				assert_true(not Clutter.ids_for([name]).is_empty(), "%s: the rule's decal %s exists" % [place, name])


func test_the_ring_has_its_gold_inlay_and_seeps_run_down_its_walls() -> void:
	var v := _view("amber_temple_faceless_god")
	await get_tree().process_frame
	var inlay := v.get_node_or_null("GoldInlay")
	assert_true(inlay != null and inlay.get_child_count() == 4, "four gold arcs make the ring")
	if inlay != null:
		var centres := {}
		for d in inlay.get_children():
			var offset := (d as Decal).position - Vector3(AmberMotion.INLAY_AT.x, (d as Decal).position.y, AmberMotion.INLAY_AT.y)
			assert_true(absf(offset.length() - AmberMotion.INLAY_RADIUS / sqrt(2.0)) < 0.05, "each arc is the same distance from the middle (%.2f)" % offset.length())
			centres[Vector2(snappedf(offset.x, 0.1), snappedf(offset.z, 0.1))] = true
		assert_eq(centres.size(), 4, "and each in its own quarter")
	var seeps := 0
	var rime := 0
	for d in v.board.find_children("Decal_*", "Decal", true, false):
		if str(d.name).begins_with("Decal_wall_seeps"):
			seeps += 1
		elif str(d.name).begins_with("Decal_floor_temple"):
			rime += 1
	assert_true(seeps >= 1, "amber seeps down the glazed walls (%d)" % seeps)
	assert_true(rime >= 1, "and frost and scrapes lie on the cold floors (%d)" % rime)
	v.queue_free()


func test_the_ledger_the_shards_and_the_candle_dishes_are_drawn() -> void:
	var v := _view("amber_temple_vault")
	await get_tree().process_frame
	var ledger := v.prop_nodes.get("pact_ledger") as Node3D
	assert_true(ledger != null, "the pact ledger is in the sanctum")
	var arts := {}
	for n: Node in ledger.find_children("*", "Node3D", true, false):
		if n.has_meta("art"):
			arts[str(n.get_meta("art"))] = true
	assert_true(arts.has("copper_ledger"), "drawn as the copper ledger on its lectern")
	assert_true(v.get_node_or_null("LedgerGlow") != null, "with a low copper light on it")
	v.queue_free()
	var deep := _view("amber_deep")
	await get_tree().process_frame
	for id: String in ["eye_shards_a", "eye_shards_b", "eye_spire"]:
		assert_true(deep.prop_nodes.has(id), "%s lies by the Eye's broken block" % id)
	deep.queue_free()
	var hall := _view("amber_temple_faceless_god")
	await get_tree().process_frame
	var dish := hall.prop_nodes.get("pilgrim_candles_3") as Node3D
	var dish_art := ""
	for n: Node in dish.find_children("*", "Node3D", true, false):
		if n.has_meta("art"):
			dish_art = str(n.get_meta("art"))
	assert_eq(dish_art, "offering_candles", "two of the pilgrims' candles are dishes of offerings")
	hall.queue_free()
