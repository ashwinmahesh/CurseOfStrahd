extends TestCase
## Livelier outdoor places (lane 28, owner requests 2026-10-08): the world matches what the narration says of it.
## Tser Pool is black and perfectly still; Madam Eva's tent is the size of a cottage and shows on the map as a tent;
## the camp's wagons ring the fire facing it, its horses stand in a railed pen, and more people live there.


func before_each() -> void:
	GameState.reset()
	ModeController.force(ModeController.Mode.EXPLORATION)
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.minute_of_day = 15 * 60


func _view(loc_id: String) -> LocationView:
	var v := LocationView.create(loc_id, GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The world box around everything a piece draws.
func _bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var b := mi.global_transform * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## The prop's piece (its Dressing_ root's model).
func _model_of(v: LocationView, prop_id: String) -> Node3D:
	var root := v.prop_nodes.get(prop_id) as Node3D
	if root == null:
		return null
	var found := root.find_children("Model_*", "Node3D", true, false)
	return found[0] as Node3D if not found.is_empty() else null


## "Tser Pool is black and perfectly still": its water has no current and no ripples, and is drawn near black.
func test_tser_pool_is_black_and_still() -> void:
	var v := _view("tser_pool")
	await _frames(1)
	var water := v.atmosphere.water
	assert_true(water != null, "the pool has its water")
	assert_eq(water.get_shader_parameter("flow") as Vector2, Vector2.ZERO, "no current")
	if Look.modern():
		assert_eq(float(water.get_shader_parameter("ripple_strength")), 0.0, "no ripples")
	var deep := water.get_shader_parameter("deep") as Color
	assert_true(deep.get_luminance() < 0.06, "black water: %s" % deep)
	var lake := _view("lake_zarovich")
	await _frames(1)
	assert_ne(lake.atmosphere.water.get_shader_parameter("flow") as Vector2, Vector2.ZERO, "Lake Zarovich still moves")
	v.queue_free()
	lake.queue_free()


## Owner reports (2026-10-08): the great tent was tiny and had nothing to show for it. It is the size of a cottage
## (wider than five squares, taller than three), stands over its block of squares with no tree poking through it, and
## blocks sight like a building.
func test_the_great_tent_is_cottage_sized() -> void:
	var v := _view("tser_pool")
	await _frames(1)
	var tent := _model_of(v, "eva_tent_outside")
	assert_true(tent != null and str(tent.get_meta("model")) == "great_tent", "the great tent is its own model")
	if tent == null:
		v.queue_free()
		return
	var box := _bounds(tent)
	assert_true(box.size.x > 5.0 and box.size.z > 3.5, "as big as a cottage: %s" % box.size)
	assert_true(box.size.y > 3.0, "tall: %.2f" % box.size.y)
	for x in range(30, 35):
		for z in range(3, 6):
			var c := Vector2i(x, z)
			assert_true(v.grid.has_flag(c, CombatGrid.WALL), "the tent blocks %s" % c)
			for n: Node3D in v.board.dressing.get(c, []):
				assert_false(n.visible, "no tree shows through the tent at %s" % c)
	v.queue_free()


## A prop's `facing` turns its piece; `span` stands it over the middle of its squares.
func test_wagons_face_the_fire_over_their_squares() -> void:
	var v := _view("tser_pool")
	await _frames(1)
	var loc := v.loc
	for p: Variant in loc["props"]:
		var spec := p as Dictionary
		if str(spec.get("model", "")) != "vardo":
			continue
		var m := _model_of(v, str(spec["id"]))
		assert_true(m != null, "%s is a 3D wagon" % spec["id"])
		if m == null:
			continue
		var want := float(SetDressing.facing_yaw(spec))
		assert_true(absf(angle_difference(m.rotation.y, want)) < 0.01, "%s faces %s" % [spec["id"], spec["facing"]])
		var at := SetDressing.span_centre(v.board, spec) as Vector3
		assert_true(Vector2(m.global_position.x, m.global_position.z).distance_to(Vector2(at.x, at.z)) < 0.01,
			"%s stands over the middle of its squares" % spec["id"])
	v.queue_free()


## The horse pen's rails are fences, and the ones on its east and west sides run up the map.
func test_the_pen_is_railed() -> void:
	var v := _view("tser_pool")
	await _frames(1)
	var rails := {Vector2i(7, 18): 0.0, Vector2i(5, 20): PI / 2.0, Vector2i(13, 20): PI / 2.0, Vector2i(9, 21): 0.0}
	for c: Vector2i in rails:
		var fence: Node3D = null
		for n: Node3D in v.board.dressing.get(c, []):
			if str(n.get_meta("model", "")) == "fence":
				fence = n
		assert_true(fence != null, "a fence on the rail at %s" % c)
		if fence != null:
			assert_true(absf(angle_difference(fence.rotation.y, float(rails[c]))) < 0.01, "the rail at %s lies along the pen" % c)
	v.queue_free()


## The great tent, the small tents and the wagons are drawn on the minimap in their own colours.
func test_the_map_shows_the_tents() -> void:
	var v := _view("tser_pool")
	await _frames(1)
	var mm := Minimap.new()
	add_child(mm)
	mm.show_location(v)
	var img := mm.call("_render") as Image
	var mark := SetDressing.catalog()["map_marks"]["great_tent"] as Dictionary
	var canvas: Array[Color] = []
	for name: Variant in mark["stripes"]:
		canvas.append(Look.color(str(name)))
	var at := Vector2i(int(32.5 * Minimap.PX), int(4.0 * Minimap.PX))   # inside the tent, off its middle
	var px := img.get_pixelv(at)
	var hit := false
	for c in canvas:
		hit = hit or px.is_equal_approx(c)
	assert_true(hit, "the great tent's canvas on the map at %s: %s" % [at, px])
	var wagon := img.get_pixelv(Vector2i(int(18.0 * Minimap.PX), int(7.0 * Minimap.PX)))
	assert_true(wagon.is_equal_approx(Look.color("blood")), "a wagon on the map: %s" % wagon)
	var pool := img.get_pixelv(Vector2i(int(9.5 * Minimap.PX), int(9.5 * Minimap.PX)))
	assert_true(pool.is_equal_approx(Look.color("void")), "the pool is black on the map too: %s" % pool)
	mm.queue_free()
	v.queue_free()


## More people to talk to: the camp's five new folk stand there, each with something to say.
func test_the_camp_has_people() -> void:
	var v := _view("tser_pool")
	await _frames(1)
	var here: Array[String] = []
	for s: Variant in v.get("_npc_shown") as Array:
		here.append(str((s as Dictionary)["spec"]["npc"]))
	for id: String in ["tser_dorina", "tser_radu", "tser_petru", "tser_tobar", "tser_zora", "stanimir", "luminita"]:
		assert_true(id in here, "%s is in the camp" % id)
	v.queue_free()
	GameState.story.set_flag("tser_pool_brawl_won", true)
	var after := _view("tser_pool")
	await _frames(1)
	for s: Variant in after.get("_npc_shown") as Array:
		assert_false(str((s as Dictionary)["spec"]["npc"]).begins_with("tser_"), "the camp is empty after the brawl")
	after.queue_free()


## In a fight a wagon is one cart over its two squares by two (its `span`), not a cart and three bits of fence.
func test_a_wagon_is_one_cart_in_a_fight() -> void:
	GameState.story.location = "tser_pool"
	for c: Dictionary in Cutscenes.all():
		Cutscenes.mark_played(str(c["id"]), GameState.story)
	Dice.reseed(11)
	var root := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	var v := root.get("view") as LocationView
	assert_true(v.start_encounter("tser_pool_brawl"), "the brawl starts")
	await _frames(3)
	var e := v.combat_view.e
	var cart := e.objects.blocking_at(Vector2i(17, 6))
	assert_true(cart != null and cart.kind == "cart" and cart.prop_id == "vistani_wagons", "the wagon is a cart")
	if cart != null:
		assert_eq(cart.cells.size(), 4, "over all four of its squares")
		assert_true(e.objects.blocking_at(Vector2i(18, 7)) == cart, "one object")
	ModeController.force(ModeController.Mode.EXPLORATION)
	root.queue_free()
	await _frames(2)


## The Svalich Road against its descriptions (lane 28): Tser Falls has its falls, the Ivlis runs under the crossroads
## bridge the colour of strong tea, and Lake Zarovich behind the Vistani camp is black.
func test_the_svalich_road_matches_its_words() -> void:
	var falls := _view("tser_falls")
	await _frames(1)
	assert_false(falls.board.find_children("Waterfall", "MeshInstance3D", true, false).is_empty(), "the river goes over the edge")
	falls.queue_free()
	var cross := _view("svalich_crossroads")
	await _frames(1)
	assert_true(cross.grid.has_flag(Vector2i(8, 5), CombatGrid.WATER), "the Ivlis is water under the bridge")
	var tea := cross.atmosphere.water.get_shader_parameter("shallow") as Color
	assert_true(tea.r > tea.b, "the colour of strong tea, not lake blue: %s" % tea)
	cross.queue_free()
	var camp := _view("vallaki_vistani_camp")
	await _frames(1)
	assert_true((camp.atmosphere.water.get_shader_parameter("deep") as Color).get_luminance() < 0.06, "black water")
	camp.queue_free()


## The Village of Barovia and Old Bonegrinder against their words (lane 28): smoke leaks from the mill on its bare
## crag; the village has more of its people out by day.
func test_old_bonegrinder_and_the_village() -> void:
	var hill := _view("old_bonegrinder_hill")
	await _frames(1)
	var smoke := hill.board.find_children("Smoke", "GPUParticles3D", true, false)
	assert_false(smoke.is_empty(), "smoke leaks from the mill")
	var mill := hill.board.find_children("Model_windmill", "Node3D", true, false)
	if not smoke.is_empty() and not mill.is_empty():
		var a := (smoke[0] as Node3D).global_position
		var b := (mill[0] as Node3D).global_position
		print("  smoke at %s, mill at %s" % [a, b])
		assert_true(Vector2(a.x - b.x, a.z - b.z).length() < 1.5, "at the mill's side")
	hill.queue_free()
	var village := _view("village_of_barovia")
	await _frames(1)
	var here: Array[String] = []
	for s: Variant in village.get("_npc_shown") as Array:
		here.append(str((s as Dictionary)["spec"]["npc"]))
	for id: String in ["barovia_woodcutter", "barovia_widow"]:
		assert_true(id in here, "%s is out by day" % id)
	village.queue_free()


## The Village of Barovia lived in (lane 28, owner request 2026-10-08: "make them look more lively, like an actual
## village"; "more people walking around and doing things"): washing hung out, more people out by day, and the
## sexton swinging his spade at the grave he's digging.
func test_barovia_is_lived_in() -> void:
	GameState.story.minute_of_day = 11 * 60
	var v := _view("village_of_barovia")
	await _frames(2)
	assert_true(v.board.find_children("WashingLine*", "Node3D", true, false).size() >= 3, "washing on the lines")
	var here: Array[String] = []
	for s: Variant in v.get("_npc_shown") as Array:
		here.append(str((s as Dictionary)["spec"]["npc"]))
	for id: String in ["barovia_gravedigger", "barovia_acolyte", "barovia_vasile", "barovia_petre", "barovia_goat",
			"barovia_woodcutter", "barovia_widow", "barovia_goodwife"]:
		assert_true(id in here, "%s is about" % id)
	var mihail := v.npc_tokens["barovia_gravedigger"] as CombatToken
	var routes := NpcRoutes.of(v)
	var swung := false
	for i in 30:
		routes._process(0.1)
		swung = swung or bool(mihail.sprite.get("_attacking"))
	assert_true(swung, "the sexton digs")
	assert_true(mihail.sprite.facing.x > 0.7, "facing his grave, east (%s)" % mihail.sprite.facing)
	v.queue_free()


## Vallaki lived in (lane 28): "festival bunting in a yellow that nobody here would choose", stalls on the market row,
## and the town at work - the porter, the raker, the ribbon girl, the painter at the wicker sun, a patrol, a dog.
func test_vallaki_is_lived_in() -> void:
	GameState.story.minute_of_day = 10 * 60
	var v := _view("vallaki")
	await _frames(2)
	var bunting := 0
	for n in v.board.find_children("WashingLine*", "Node3D", true, false):
		if n.find_children("*", "MeshInstance3D", true, false).size() > 10:
			bunting += 1
	assert_true(bunting >= 6, "bunting over the streets and the square (%d)" % bunting)
	var here: Array[String] = []
	for s: Variant in v.get("_npc_shown") as Array:
		here.append(str((s as Dictionary)["spec"]["npc"]))
	for id: String in ["vallaki_herbwife", "vallaki_cloth_merchant", "vallaki_porter", "vallaki_ribbon_girl",
			"vallaki_sun_painter", "vallaki_patrol", "vallaki_raker", "vallaki_dog"]:
		assert_true(id in here, "%s is about" % id)
	assert_true(v.grid.height(Vector2i(40, 9)) > v.grid.height(Vector2i(24, 21)), "St. Andral's stands on its rise")
	assert_true(v.grid.height(Vector2i(24, 21)) > v.grid.height(Vector2i(24, 30)), "the lower town a step down")
	v.queue_free()


## Krezk lived in (lane 28): walled and pious - goats in the pens, women at the well and the shrine, a boy by the gate,
## wash on the lines, and snow underfoot even under a clear sky.
func test_krezk_is_lived_in() -> void:
	GameState.story.minute_of_day = 10 * 60
	var was := Look.style()
	Look.set_style("modern", false)
	Weather.use({"kinds": {"clear": {}}, "climates": {"valley": {"clear": 1.0}}, "default_climate": "valley"})
	var v := _view("krezk")
	await _frames(2)
	var here: Array[String] = []
	for s: Variant in v.get("_npc_shown") as Array:
		here.append(str((s as Dictionary)["spec"]["npc"]))
	for id: String in ["krezk_goatherd", "krezk_fence_mender", "krezk_well_wife", "krezk_bucket_wife", "krezk_gate_boy",
			"krezk_carver", "krezk_wall_watch", "krezk_billy_goat", "krezk_goat", "krezk_goat_2", "krezk_goat_3"]:
		assert_true(id in here, "%s is about" % id)
	assert_true(v.board.find_children("WashingLine*", "Node3D", true, false).size() >= 4, "wash on the lines")
	assert_true(v.atmosphere.snow_cover >= 0.4, "snow lies in Krezk under a clear sky (%.2f)" % v.atmosphere.snow_cover)
	v.queue_free()
	Weather.use({})
	Look.set_style(was, false)


## The two Vistani camps lived in (lane 28): at Tser Pool a dancer on a plank stage, a knife-thrower, a hunter and a
## dog, the cook and the smiths at their work, the pool down in its hollow and Madam Eva's tent up on its knoll; by
## Lake Zarovich a fisherman, a cook, a horse-keeper, a lookout and a dog, the camp a step above the shore.
func test_the_vistani_camps_are_lived_in() -> void:
	GameState.story.minute_of_day = 11 * 60
	var v := _view("tser_pool")
	await _frames(2)
	var here: Array[String] = []
	for s: Variant in v.get("_npc_shown") as Array:
		here.append(str((s as Dictionary)["spec"]["npc"]))
	for id: String in ["tser_lavinia", "tser_iancu", "tser_marin", "tser_dog", "tser_dorina", "tser_petru", "tser_tobar"]:
		assert_true(id in here, "%s is about" % id)
	var pool := v.grid.height(Vector2i(8, 12))
	var fire := v.grid.height(Vector2i(22, 14))
	assert_true(pool < fire, "the pool lies in a hollow below the fire")
	assert_true(v.grid.height(Vector2i(36, 6)) > fire, "Madam Eva's tent stands on a knoll")
	assert_true(v.grid.height(Vector2i(29, 16)) > fire, "the dancer's stage stands above the ground")
	v.queue_free()
	await _frames(1)
	var c := _view("vallaki_vistani_camp")
	await _frames(2)
	here.clear()
	for s: Variant in c.get("_npc_shown") as Array:
		here.append(str((s as Dictionary)["spec"]["npc"]))
	for id: String in ["camp_fisher", "camp_cook", "camp_groom", "camp_lookout", "camp_dog"]:
		assert_true(id in here, "%s is about" % id)
	assert_true(c.grid.height(Vector2i(15, 6)) < c.grid.height(Vector2i(15, 12)), "the camp a step above the shore")
	assert_true(c.grid.height(Vector2i(26, 12)) > c.grid.height(Vector2i(15, 12)), "Arrigal's wagons on the higher ground")
	c.queue_free()


## The Wizard of Wines lived in (lane 28): while the winery is lost the Martikovs' camp keeps a watch on a platform, a
## washerwoman and a woodsplitter; once it is theirs again, hands work the vines and the casks. Ravens watch either way,
## and the vineyard climbs in terraces from the camp to the yard.
func test_the_wizard_of_wines_is_lived_in() -> void:
	GameState.story.minute_of_day = 11 * 60
	GameState.story.set_flag("vineyard_cleared")
	var v := _view("wizard_of_wines")
	await _frames(2)
	var here: Array[String] = []
	for s: Variant in v.get("_npc_shown") as Array:
		here.append(str((s as Dictionary)["spec"]["npc"]))
	for id: String in ["wine_watch", "wine_washer", "wine_woodsplitter", "wine_raven_1", "wine_raven_2", "wine_raven_3"]:
		assert_true(id in here, "%s is about while the family is in the woods" % id)
	assert_false("wine_cooper" in here, "the cooper waits until the winery is theirs")
	var yard := v.grid.height(Vector2i(22, 10))
	var rows := v.grid.height(Vector2i(22, 20))
	var foot := v.grid.height(Vector2i(22, 29))
	assert_true(yard > rows and rows > foot, "the vineyard climbs from the lane's foot to the yard")
	assert_true(v.grid.height(Vector2i(13, 29)) > v.grid.height(Vector2i(12, 29)), "the camp's watch platform")
	v.queue_free()
	await _frames(1)
	GameState.story.set_flag("winery_reclaimed")
	var h := _view("wizard_of_wines")
	await _frames(2)
	here.clear()
	for s: Variant in h.get("_npc_shown") as Array:
		here.append(str((s as Dictionary)["spec"]["npc"]))
	for id: String in ["wine_pruner", "wine_picker", "wine_cooper"]:
		assert_true(id in here, "%s is at work once the family is home" % id)
	assert_false("wine_watch" in here, "no watch needed at home")
	h.queue_free()
## Houses stand on the town's ground (lane 28, 2026-10-08: on natural ground Vallaki's houses and St. Andral's were
## buried to the eaves): each building's base is within a step of the open ground at its walls.
func test_houses_stand_on_raised_ground() -> void:
	var v := _view("vallaki")
	await _frames(1)
	var checked := 0
	for b: Dictionary in v.board.buildings:
		if b.has("interior") or b.has("castle") or not b.has("rect"):
			continue
		var r := b["rect"] as Rect2i
		var base := (b["root"] as Node3D).position.y
		var out := Vector2i(-1, -1)
		for i in r.size.x:
			for c: Vector2i in [Vector2i(r.position.x + i, r.position.y - 1), Vector2i(r.position.x + i, r.end.y)]:
				if v.grid.in_bounds(c) and not v.grid.has_flag(c, CombatGrid.WALL) and out == Vector2i(-1, -1):
					out = c
		if out == Vector2i(-1, -1):
			continue
		checked += 1
		var ground := v.grid.height(out) / float(CombatGrid.FEET)
		assert_true(absf(base - ground) <= 1.01, "the house at %s stands at %.1f, the ground beside it at %.1f" % [r.position, base, ground])
	assert_true(checked >= 10, "Vallaki's houses checked (%d)" % checked)
	v.queue_free()


## The Abbey lived in (lane 28): the Belviews about their chores, benches in the cloister, the switchback climbing to
## the gate and the west court a step above the courtyard; in the garden the stitched scarecrows face the gate.
func test_the_abbey_is_lived_in() -> void:
	GameState.story.minute_of_day = 11 * 60
	var v := _view("abbey_of_st_markovia")
	await _frames(2)
	var here: Array[String] = []
	for s: Variant in v.get("_npc_shown") as Array:
		here.append(str((s as Dictionary)["spec"]["npc"]))
	for id: String in ["belview_sweeper", "belview_hauler", "belview_feathers", "belview_gate"]:
		assert_true(id in here, "%s is about" % id)
	var court := v.grid.height(Vector2i(12, 12))
	assert_true(v.grid.height(Vector2i(8, 28)) < v.grid.height(Vector2i(8, 23)), "the switchback climbs")
	assert_true(v.grid.height(Vector2i(8, 23)) < court, "the gate above the switchback")
	assert_true(v.grid.height(Vector2i(5, 4)) > court, "the west court a step up")
	v.queue_free()
	var garden := Compendium.shared().get_entry("locations", "abbey_of_st_markovia_garden") as Dictionary
	for p: Variant in garden["props"]:
		if str((p as Dictionary)["id"]).begins_with("scarecrow_"):
			assert_eq(str((p as Dictionary)["model"]), "scarecrow_stitched", "%s is a stitched scarecrow" % (p as Dictionary)["id"])


## Berez as a drowned village (lane 28): marsh mud and black water, the mound and the witch's stump as real rises of
## ground rather than boxes, the hut on its roots, a causeway a step above the marsh, and the scarecrow field.
func test_berez_is_a_drowned_village() -> void:
	var v := _view("berez")
	await _frames(1)
	assert_true(v.grid.has_flag(Vector2i(7, 14), CombatGrid.NATURAL), "the mound is ground, not a platform")
	assert_true(v.grid.height(Vector2i(7, 14)) > v.grid.height(Vector2i(13, 14)), "the mound rises above the marsh")
	assert_true(v.grid.has_flag(Vector2i(30, 16), CombatGrid.NATURAL), "the stump is ground, not a platform")
	assert_true(v.grid.height(Vector2i(30, 16)) > v.grid.height(Vector2i(25, 16)), "the stump rises above the field")
	assert_true(v.grid.height(Vector2i(39, 27)) > v.grid.height(Vector2i(36, 27)), "the causeway a step above the water")
	var loc := Compendium.shared().get_entry("locations", "berez") as Dictionary
	var scarecrows := 0
	for p: Variant in loc["props"]:
		var q := p as Dictionary
		if str(q["id"]) == "berez_hut":
			assert_eq(str(q["model"]), "hut_lysaga", "the witch's hut on its stump")
		if str(q.get("model", "")) == "scarecrow":
			scarecrows += 1
	assert_true(scarecrows >= 6, "a field of scarecrows (%d)" % scarecrows)
	assert_eq(str(v.atmosphere.mood["water"]["deep"]), "void", "black water")
	v.queue_free()


## Lake Zarovich's landing (lane 28): black water, the empty racks and cold fires, a boat drawn as a boat, the last old
## fisherman at his nets, and the shingle sloping down to the water.
func test_the_fishers_landing() -> void:
	GameState.story.minute_of_day = 11 * 60
	var v := _view("lake_zarovich")
	await _frames(2)
	var here: Array[String] = []
	for s: Variant in v.get("_npc_shown") as Array:
		here.append(str((s as Dictionary)["spec"]["npc"]))
	assert_true("lz_old_fisher" in here, "the last fisherman at his nets")
	assert_eq(str(v.atmosphere.mood["water"]["deep"]), "void", "black water")
	assert_true(v.grid.height(Vector2i(17, 20)) > v.grid.height(Vector2i(17, 10)), "the shingle slopes down to the water")
	v.queue_free()


## The Pool of the White Sun (lane 28): black water with a warm glint, Krezk's mourners at the water and the graves,
## and the pool in a hollow below the graveyard; the side-quest lane's toys and Sorin's watchers stay where they are.
func test_the_pool_of_the_white_sun() -> void:
	GameState.story.minute_of_day = 11 * 60
	var v := _view("krezk_pool_of_the_white_sun")
	await _frames(2)
	var here: Array[String] = []
	for s: Variant in v.get("_npc_shown") as Array:
		here.append(str((s as Dictionary)["spec"]["npc"]))
	for id: String in ["pool_mourner", "pool_grave_keeper"]:
		assert_true(id in here, "%s is about" % id)
	assert_eq(str(v.atmosphere.mood["water"]["deep"]), "void", "black water")
	assert_true(v.grid.height(Vector2i(4, 1)) > v.grid.height(Vector2i(4, 12)), "the north graves on their bank")
	var loc := Compendium.shared().get_entry("locations", "krezk_pool_of_the_white_sun") as Dictionary
	var ids: Array[String] = []
	for p: Variant in loc["props"]:
		ids.append(str((p as Dictionary)["id"]))
	assert_true("krezkov_toys" in ids, "the side quest's toys are kept")
	v.queue_free()


## Old Bonegrinder lived in (lane 28): villagers wait at the mill's door for dream pastries while the hags still bake,
## and are gone once Morgantha is dead.
func test_villagers_wait_at_the_mill() -> void:
	GameState.story.minute_of_day = 11 * 60
	var v := _view("old_bonegrinder_hill")
	await _frames(2)
	var here: Array[String] = []
	for s: Variant in v.get("_npc_shown") as Array:
		here.append(str((s as Dictionary)["spec"]["npc"]))
	for id: String in ["pastry_customer_man", "pastry_customer_woman"]:
		assert_true(id in here, "%s waits at the mill" % id)
	v.queue_free()
	await _frames(1)
	GameState.story.set_flag("morgantha_slain")
	var after := _view("old_bonegrinder_hill")
	await _frames(2)
	here.clear()
	for s: Variant in after.get("_npc_shown") as Array:
		here.append(str((s as Dictionary)["spec"]["npc"]))
	assert_false("pastry_customer_man" in here, "no one waits once the baking stops")
	after.queue_free()


## The emptiest wilderness paths dressed (lane 28, on lane 3's ground): boulders, cairns, logs and reeds, a frozen
## traveller on the Ice Stair, a hunter on the hill trail, and a thing to find on each.
func test_the_empty_paths_are_dressed() -> void:
	for loc: String in ["lake_zarovich_trail", "berez_marsh_track", "mount_baratok_trail", "amber_temple_road", "road_forest"]:
		var d := Compendium.shared().get_entry("locations", loc) as Dictionary
		var props := d.get("props", []) as Array
		var finds := 0
		for p: Variant in props:
			if str((p as Dictionary)["kind"]) == "search":
				finds += 1
		assert_true(props.size() >= 6, "%s is dressed (%d props)" % [loc, props.size()])
		assert_true(finds >= 1, "%s has something to find" % loc)
	GameState.story.minute_of_day = 11 * 60
	var v := _view("lake_zarovich_trail")
	await _frames(2)
	var here: Array[String] = []
	for s: Variant in v.get("_npc_shown") as Array:
		here.append(str((s as Dictionary)["spec"]["npc"]))
	assert_true("lzt_hunter" in here, "a hunter on the hill trail")
	v.queue_free()


## The tarn, the den and Yester Hill's slope dressed (lane 28, on lane 3's ground): still black water at Van Richten's
## tower with a horse in the reeds, the den's household by the stream, and the druids' bedrolls, cages and skull cairns
## with smoke from their fire.
func test_the_tarn_the_den_and_the_hill() -> void:
	var v := _view("van_richtens_tower")
	await _frames(1)
	assert_eq(str(v.atmosphere.mood["water"]["deep"]), "void", "the tarn is black")
	v.queue_free()
	for loc: String in ["van_richtens_tower", "werewolf_den", "yester_hill"]:
		var finds := 0
		for p: Variant in (Compendium.shared().get_entry("locations", loc) as Dictionary)["props"]:
			if str((p as Dictionary)["kind"]) == "search":
				finds += 1
		assert_true(finds >= 2, "%s has things to find (%d)" % [loc, finds])
	var h := _view("yester_hill")
	await _frames(2)
	assert_true(h.board.find_children("Smoke*", "GPUParticles3D", true, false).size() > 0, "smoke from the druids' fire")
	h.queue_free()


## Mount Baratok, Argynvostholt and the Tsolenka Pass dressed (lane 28, on lane 3's ground): frost round the summit
## cairn, the dragon's frost scar across Argynvostholt's courtyard and names over the stables, the roc's nest on the
## Tsolenka crag.
func test_baratok_argynvostholt_and_tsolenka() -> void:
	var want := {"mount_baratok": ["summit_frost_1", "hut_yard_notes"],
		"argynvostholt": ["holt_frost_scar_3", "holt_stall_names", "holt_squire_token"],
		"tsolenka_pass": ["tsolenka_roc_nest", "landing_roc_quill"]}
	for loc: String in want:
		var ids: Array[String] = []
		for p: Variant in (Compendium.shared().get_entry("locations", loc) as Dictionary)["props"]:
			ids.append(str((p as Dictionary)["id"]))
		for id: String in want[loc]:
			assert_true(id in ids, "%s has %s" % [loc, id])


## The Mists standing on the map are soft (lane 28): the fog bank on the road out is a crowd of soft puffs, not a drawn
## cartoon cloud.
func test_the_mists_bank_is_soft() -> void:
	var v := _view("into_the_mists_road")
	await _frames(1)
	var banks := v.board.find_children("MistBank", "Node3D", true, false)
	assert_true(banks.size() >= 1, "a bank of the Mists on the road")
	if not banks.is_empty():
		assert_true((banks[0] as Node3D).get_child_count() >= 8, "made of many soft puffs")
	for d: Node in v.board.find_children("Dressing_mists_wall", "Node3D", true, false):
		assert_eq(d.find_children("*", "Sprite3D", true, false).size(), 0, "no drawn cloud")
	v.queue_free()


## Raised things to stand on in the settlements (lane 28, Ashwin: "larger things that change elevation and can be
## interacted with"): a vardo's roof at Tser Pool and by the lake, the raven oak at Old Bonegrinder, a hay cart in
## Barovia's square, the treading vat at the winery and a wall walk inside Krezk's gate.
func test_settlements_have_things_to_stand_on() -> void:
	var raised := {"tser_pool": [Vector2i(29, 11), 10], "vallaki_vistani_camp": [Vector2i(18, 18), 10],
		"old_bonegrinder_hill": [Vector2i(7, 12), 10], "village_of_barovia": [Vector2i(24, 16), 5],
		"wizard_of_wines": [Vector2i(27, 8), 5], "krezk": [Vector2i(30, 14), 10]}
	for loc: String in raised:
		var d := Compendium.shared().get_entry("locations", loc) as Dictionary
		var g := LocationView.grid_for(d)
		var flat := CombatGrid.from_rows(d["map"]["rows"] as Array, d["map"].get("elevation", []) as Array)
		var c := (raised[loc] as Array)[0] as Vector2i
		var ft := int((raised[loc] as Array)[1])
		if loc == "krezk":
			assert_eq(g.height(c) - g.height(Vector2i(28, 14)), ft, "Krezk's wall walk stands %d ft up" % ft)
		else:
			assert_eq(g.height(c) - flat.height(c), ft, "%s: %s is stood on %d ft up" % [loc, c, ft])
