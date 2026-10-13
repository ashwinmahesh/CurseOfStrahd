extends TestCase
## Each region's own look in the Modern finish (the vault's Region Variety Plan, art/atmosphere/moods.json `modern`):
## its own daylight, mist and shade so no two regions look alike, its ground tinted its own colour or swapped for its
## own (the woods' moss), autumn in the Vistani camps' undergrowth, Vallaki's streets wet whatever the sky, and the
## frozen Classic look left as it was.

## One place from each region the plan names.
const REGIONS := ["road_forest", "village_of_barovia", "old_bonegrinder_hill", "tser_pool", "tser_falls",
	"svalich_crossroads", "vallaki", "lake_zarovich", "wizard_of_wines", "yester_hill", "krezk",
	"abbey_of_st_markovia", "argynvostholt", "werewolf_den", "berez", "barrow_moor", "mount_baratok",
	"ghakis_shoulder", "tsolenka_pass", "amber_temple_entrance"]


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func _view(loc_id: String) -> LocationView:
	var v := LocationView.create(loc_id, GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


## The mood a place gets, dressed as Atmosphere dresses it (its `modern` block in the Modern finish).
func _dressed(loc_id: String) -> Dictionary:
	var a := Atmosphere.new()
	a.loc_id = loc_id
	a.outdoors = true
	a.mood_id = Atmosphere.mood_for(loc_id, Compendium.shared().get_entry("locations", loc_id))
	var m := a._dressed()
	a.free()
	return m


## What a place looks like by day: its light, the light filling its shade, its mist and its shade's colour.
func _day_look(mood: Dictionary) -> String:
	var day := (mood.get("times", {}) as Dictionary).get("day", {}) as Dictionary
	return "%s/%s/%s/%s" % [day.get("key", ""), day.get("ambient", ""), day.get("mist", ""),
		(mood.get("tone", {}) as Dictionary).get("shade", "-")]


func test_no_two_regions_share_a_daylight() -> void:
	var was := Look.style()
	Look.set_style("modern", false)
	var seen := {}
	for loc_id: String in REGIONS:
		var look := _day_look(_dressed(loc_id))
		assert_false(seen.has(look), "%s's daylight is its own (%s, as %s)" % [loc_id, look, seen.get(look, "")])
		seen[look] = loc_id
	Look.set_style(was, false)


func test_classic_keeps_its_frozen_look() -> void:
	var was := Look.style()
	Look.set_style("classic", false)
	for loc_id: String in REGIONS:
		var mood := _dressed(loc_id)
		assert_false(mood.has("modern"), "%s: the Modern block never reaches Classic" % loc_id)
		assert_false(mood.has("ground_tint"), "%s: nor its ground tint" % loc_id)
	assert_eq(str(((_dressed("road_forest")["times"] as Dictionary)["day"] as Dictionary)["key"]), "frost",
		"the woods' day in Classic is the old overcast silver")
	Look.set_style(was, false)


func test_the_ground_takes_the_regions_tint() -> void:
	var was := Look.style()
	Look.set_style("modern", false)
	var woods := _view("road_forest")
	await get_tree().process_frame
	var grass := Look.cel_textured("village/grass")
	var want := Color(str((_dressed("road_forest")["ground_tint"] as Dictionary)["village/grass"]))
	assert_true(ModelPiece.colour_of(grass.get_shader_parameter("tint")).is_equal_approx(want), "the woods' grass is mossy")
	woods.queue_free()
	await get_tree().process_frame
	var inn := _view("vallaki_blue_water_inn")
	await get_tree().process_frame
	assert_true(ModelPiece.colour_of(grass.get_shader_parameter("tint")).is_equal_approx(Color.WHITE),
		"and goes back to its own colour where a place doesn't tint it")
	inn.queue_free()
	Look.set_style(was, false)


func test_autumn_in_the_camps_not_the_woods() -> void:
	var was := Look.style()
	Look.set_style("modern", false)
	var camp := _view("tser_pool")
	await get_tree().process_frame
	assert_true(float(Flora._material("leaf|bush").get_shader_parameter("autumn")) > 0.5, "the camp's undergrowth turns")
	assert_true(float(Flora._material("leaf|broadleaf").get_shader_parameter("autumn")) > 0.5, "and its oaks")
	assert_eq(float(Flora._material("leaf|tree").get_shader_parameter("autumn")), 0.0, "but its spruces stay green")
	camp.queue_free()
	await get_tree().process_frame
	var woods := _view("road_forest")
	await get_tree().process_frame
	assert_eq(float(Flora._material("leaf|bush").get_shader_parameter("autumn")), 0.0, "the woods stay green")
	woods.queue_free()
	Look.set_style(was, false)


## Vallaki's streets never dry (a mood's `lying_wet`): wet under a clear sky in the Modern finish; Classic stays as it was.
func test_vallaki_stays_wet() -> void:
	var was := Look.style()
	Look.set_style("modern", false)
	Weather.use({"kinds": {"clear": {}}, "climates": {"valley": {"clear": 1.0}}, "default_climate": "valley"})
	var v := _view("vallaki")
	await get_tree().process_frame
	assert_true(v.atmosphere.wetness >= 0.7, "Vallaki's streets are wet under a clear sky")
	v.queue_free()
	await get_tree().process_frame
	Look.set_style("classic", false)
	var c := _view("vallaki")
	await get_tree().process_frame
	assert_eq(c.atmosphere.wetness, 0.0, "Classic stays as it was")
	c.queue_free()
	Weather.use({})
	Look.set_style(was, false)


## A region lays its own ground (a mood's `ground_swap`): the woods' maps walk on moss in the Modern finish, Classic
## and places without a swap keep theirs.
func test_regions_lay_their_own_ground() -> void:
	var was := Look.style()
	Look.set_style("modern", false)
	assert_eq(Atmosphere.region_surface("road_forest", "village/grass"), "wild/moss", "the woods walk on moss")
	assert_eq(Atmosphere.region_surface("tser_pool", "village/grass"), "wild/leaf_litter", "the camp on fallen leaves")
	assert_eq(Atmosphere.region_surface("werewolf_den", "mountain/scree"), "wild/red_scree", "the den on red scree")
	assert_eq(Atmosphere.region_surface("village_of_barovia", "village/grass"), "village/grass", "the village keeps its own")
	assert_eq(Atmosphere.region_surface("", "village/grass"), "village/grass", "and a board with no place")
	var woods := _view("road_forest")
	await get_tree().process_frame
	assert_eq(str(woods.board.floor_material().get_meta("surface", "")), "wild/moss", "the woods' board is laid in moss")
	woods.queue_free()
	Look.set_style("classic", false)
	assert_eq(Atmosphere.region_surface("road_forest", "village/grass"), "village/grass", "Classic stays as it was")
	Look.set_style(was, false)


## The regions grow their own trees (blender/plants_3d.py): oaks round the camps, birches and willows by the lake,
## willows in the marsh, Scots pines in the mountains and on the heath, staked vines in the winery's rows.
func test_regions_grow_their_own_trees() -> void:
	var want := {"autumn": "oak_a", "lake": "birch_a", "marsh": "willow_a", "mountain": "scots_a", "heath": "scots_b",
		"spectral": "birch_b"}
	for set_id: String in want:
		var pines := (Flora.resolve(set_id)["trees"] as Dictionary)["pine"] as Array
		assert_true(str(want[set_id]) in pines, "%s grows %s" % [set_id, want[set_id]])
		assert_true(Flora.mesh(str(want[set_id])) != null, "%s is built" % want[set_id])
	var vines := false
	for e: Array in Flora.resolve("vineyard")["open"] as Array:
		vines = vines or str(e[0]) == "vine"
	assert_true(vines, "vines stand in the winery's rows")
