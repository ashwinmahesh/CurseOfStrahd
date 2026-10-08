extends TestCase
## Interiors that look like their descriptions (docs/art/interiors.md, owner request 2026-10-08: "madam eva's tent
## should look like its description (and not have its wall textures be wooden)"). Madam Eva's tent is patched canvas
## on poles hung with charms, not a timber room: a low round table under a red cloth with the cards laid out, cushions
## for the querents, lanterns and a censer.


func before_each() -> void:
	GameState.reset()
	ModeController.force(ModeController.Mode.EXPLORATION)
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func after_each() -> void:
	Look.set_style(Look.DEFAULT_STYLE, false)


func _view(loc_id: String) -> LocationView:
	var v := LocationView.create(loc_id, GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _surface(n: Node) -> String:
	var mi := n as MeshInstance3D
	if mi == null or mi.material_override == null:
		return ""
	return str(mi.material_override.get_meta("surface", ""))


## The tent's walls are canvas sheets on poles with charms on their ropes, standing a tent wall high, and none of the
## timber style's walls or coping; the floor is rugs.
func test_madam_evas_tent_is_canvas() -> void:
	Look.set_style("modern", false)
	var v := _view("tser_pool_eva_tent")
	await _frames(2)
	var board := v.board
	assert_eq(BuildingKit.interior_style(board), "tent", "the tent is built as a tent")
	var sheets := board.find_children("Canvas", "MeshInstance3D", true, false)
	assert_true(sheets.size() >= 30, "canvas on every side of the room (%d sheets)" % sheets.size())
	for s in sheets:
		assert_eq(_surface(s), "tent/canvas", "the sheets are the patched canvas")
	assert_true(board.find_children("Pole", "MeshInstance3D", true, false).size() >= 4, "poles at the corners")
	var charms := board.find_children("Charm", "Node3D", true, false)
	assert_true(charms.size() >= 20, "charms hang from the ropes (%d)" % charms.size())
	var eyes := 0
	for c in charms:
		if (c as Charm).kind == "eye":
			eyes += 1
	assert_true(eyes > 0, "painted eyes among them")
	assert_eq(board.find_children("InteriorWall", "Node3D", true, false).size(), 0, "no house walls")
	assert_eq(board.find_children("KitFaces", "MeshInstance3D", true, false).size(), 0, "no timber coping")
	var floor := board.floor_box(Vector2i(6, 6))
	assert_true(floor != null and _surface(floor) == "interior/rug", "rugs on the floor")
	var st := board.get_meta("interior_walls", {}) as Dictionary
	assert_eq(float(st.get("height", 0.0)), float(InteriorWalls.HEIGHTS["tent"]), "a tent wall's height")
	v.queue_free()
	await _frames(1)


## Like a room's walls, the canvas toward the camera drops to the cut-away height and the far side stands.
func test_the_tent_cuts_away_toward_the_camera() -> void:
	Look.set_style("modern", false)
	var v := _view("tser_pool_eva_tent")
	await _frames(2)
	var board := v.board
	var north: Dictionary = {}
	for w: Dictionary in (board.get_meta("interior_walls", {}) as Dictionary).get("walls", []):
		if w["cell"] == Vector2i(6, 0):
			north = w
	assert_false(north.is_empty(), "the north side is a tent wall")
	if north.is_empty():
		v.queue_free()
		return
	var focus := board.cell_center(Vector2i(6, 2))
	board.cut_buildings(focus + Vector3(0, 8, 10), focus, 1.0)
	assert_true((north["full"] as Node3D).visible, "the far side stands")
	board.cut_buildings(focus + Vector3(0, 8, -10), focus, 1.0)
	assert_true((north["low"] as Node3D).visible and not (north["full"] as Node3D).visible, "the near side is cut away")
	v.queue_free()
	await _frames(1)


## Classic keeps tents low: canvas at the cut-away height, no charms, no full walls.
func test_classic_keeps_the_tent_low() -> void:
	Look.set_style("classic", false)
	var v := _view("tser_pool_eva_tent")
	await _frames(2)
	var sheets := v.board.find_children("Canvas", "MeshInstance3D", true, false)
	assert_true(sheets.size() >= 30, "canvas all round")
	var top := 0.0
	for s in sheets:
		var b := (s as MeshInstance3D).global_transform * (s as MeshInstance3D).mesh.get_aabb()
		top = maxf(top, b.end.y)
	assert_true(top <= InteriorWalls.CUT + 0.05, "at the cut-away height (%.2f)" % top)
	assert_eq(v.board.find_children("Charm", "Node3D", true, false).size(), 0, "no charms")
	v.queue_free()
	await _frames(1)


## Her things are what the narration names: the reading table with its cloth and cards, an iron-bound chest, her
## painted chest, cushions for those who sit across from her, lanterns and incense; and it's her home (owner, 2026-10-08:
## "really make it look like the place where she lives and does her readings"): her bed, her cooking fire, books and
## papers, candles, wine and bread, apples, herbs drying, her shawls.
func test_madam_evas_things() -> void:
	Look.set_style("modern", false)
	var v := _view("tser_pool_eva_tent")
	await _frames(2)
	var want := {"tarokka_table": "reading_table", "eva_chest": "chest_iron", "querent_cushions_west": "cushions",
		"querent_cushions_east": "cushions", "tent_incense": "incense_burner", "tent_lantern_east": "lantern_stand",
		"eva_bed": "bedroll", "eva_cookfire": "cookpot", "eva_books_west": "book_stack", "eva_candles_west": "candle_cluster",
		"eva_wine": "wine_tray", "eva_apples": "basket", "eva_herbs_west": "drying_herbs", "eva_shawls": "shawl_line"}
	for id: String in want:
		var node := v.prop_nodes.get(id) as Node
		assert_true(node != null, "%s is there" % id)
		if node == null:
			continue
		var models := node.find_children("Model_*", "Node3D", true, false)
		assert_true(not models.is_empty() and str(models[0].get_meta("model", "")) == want[id], "%s is the %s" % [id, want[id]])
	var chest := v.container_nodes.get("eva_card_chest") as Node
	var found := chest.find_children("Model_*", "Node3D", true, false) if chest != null else []
	assert_true(not found.is_empty() and str(found[0].get_meta("model", "")) == "chest_painted", "her painted chest")
	v.queue_free()
	await _frames(1)


## Owner report (2026-10-08): "The stable at the Blue Water Inn doesnt resemble a stable at all." Its yard is packed
## earth strewn with straw inside rough board walls, with box stalls (horses in the two furthest from Rictavio's
## wagon), a trough, hay, tack on the walls, and no tavern furniture.
func test_the_blue_water_inns_stable_is_a_stable() -> void:
	Look.set_style("modern", false)
	var v := _view("vallaki_blue_water_inn")
	await _frames(2)
	var board := v.board
	var floor := board.floor_box(Vector2i(7, 14))
	assert_true(floor != null and _surface(floor) == "dungeon/packed_earth", "an earth floor")
	var boards := 0
	for w: Dictionary in (board.get_meta("interior_walls", {}) as Dictionary).get("walls", []):
		var c := w["cell"] as Vector2i
		if c.y == 17 and c.x >= 1 and c.x <= 14:
			for mi in (w["full"] as Node).find_children("*", "MeshInstance3D", true, false):
				if _surface(mi) == "interior/attic_boards":
					boards += 1
					break
	assert_true(boards >= 10, "rough board walls (%d)" % boards)
	var want := {"stable_stall_bay": "stall_horse", "stable_stall_grey": "stall_horse", "stable_stall_empty_1": "stall",
		"stable_trough": "trough", "stable_hay_1": "hay_bale", "stable_tack_west": "tack", "stable_lantern": "lantern_stand"}
	for id: String in want:
		var node := v.prop_nodes.get(id) as Node
		var models := node.find_children("Model_*", "Node3D", true, false) if node != null else []
		assert_true(not models.is_empty() and str(models[0].get_meta("model", "")) == want[id], "%s is the %s" % [id, want[id]])
	var straw := 0
	for d in board.find_children("*", "Decal", true, false):
		var at := (d as Decal).global_position
		var tex := (d as Decal).texture_albedo
		if tex != null and tex.resource_path.contains("floor_straw") and Rect2(1, 12, 24, 5).has_point(Vector2(at.x, at.z)):
			straw += 1
	assert_true(straw >= 15, "straw strewn over the yard (%d)" % straw)
	for m in board.find_children("Model_*", "Node3D", true, false):
		var at := (m as Node3D).global_position
		if (m as Node3D).is_visible_in_tree() and Rect2(1, 12, 24, 5).has_point(Vector2(at.x, at.z)):
			assert_false(str(m.get_meta("model", "")) in ["table_chairs", "bar_counter", "table"],
				"no tavern furniture in the yard (%s at %s)" % [m.get_meta("model", ""), board.grid.cell_at(at)])
	v.queue_free()
	await _frames(1)


## Room styles and furnishing go by the room's name before its id: a guardroom in the castle's larders is a guardroom,
## not a larder (the audit found the larders' cells and guardrooms in kitchen tiles).
func test_room_rules_read_the_name_first() -> void:
	var rules := SetDressing.catalog().get("rooms", []) as Array
	var style: Variant = SetDressing.room_rule(rules, {"name": "The guardroom", "id": "larders_guardroom"})
	assert_true(style != null and str((style as Dictionary).get("floor", "")) == "dungeon/stone_floor", "a guardroom's stone")
	style = SetDressing.room_rule(rules, {"name": "The north cells", "id": "larders_north_cells"})
	assert_true(style != null and str((style as Dictionary).get("wall", "")) == "interior/kitchen_wall" == false, "cells aren't a kitchen")
	style = SetDressing.room_rule(rules, {"name": "", "id": "dh_kitchen"})
	assert_true(style != null and str((style as Dictionary).get("floor", "")) == "interior/kitchen_flags", "an id still counts")


## A farmhouse bedroom is plaster and planks (the board theme's own rooms), not a manor's carpet and wallpaper.
func test_a_farmhouse_bedroom_is_plain() -> void:
	Look.set_style("modern", false)
	var v := _view("krezk_burgomaster_house")
	await _frames(2)
	var area := {}
	for a: Variant in v.loc["areas"]:
		if str((a as Dictionary)["id"]) == "guest_room":
			area = a as Dictionary
	var c := Vector2i(int(area["cells"][0][0]), int(area["cells"][0][1]))
	var floor := v.board.floor_box(c)
	assert_true(floor != null and _surface(floor) == "interior/wood_planks", "planks, not carpet")
	v.queue_free()
	await _frames(1)


## Lived-in rooms (world/look/furnish.gd): the Death House's rooms get what rooms of their kind hold, on free wall faces
## and along the walls, never on a square something stands on or beside a door, an exit or the spawn.
func test_rooms_are_furnished() -> void:
	Look.set_style("modern", false)
	var v := _view("death_house_ground")
	await _frames(2)
	var board := v.board
	var pieces := 0
	var kitchen := 0
	var clear := {}
	for key: String in ["doors", "exits"]:
		for t: Variant in v.loc.get(key, []):
			var c := Vector2i(int((t as Dictionary)["cell"][0]), int((t as Dictionary)["cell"][1]))
			for dz: int in [-1, 0, 1]:
				for dx: int in [-1, 0, 1]:
					clear[c + Vector2i(dx, dz)] = true
	var taken := {}
	for key: String in ["props", "containers", "npcs"]:
		for t: Variant in v.loc.get(key, []):
			taken[Vector2i(int((t as Dictionary)["cell"][0]), int((t as Dictionary)["cell"][1]))] = true
	for n in board.get_children():
		if not n.has_meta("furnish"):
			continue
		pieces += 1
		var c := Vector2i(int(str(n.name).get_slice("_", 2)), int(str(n.name).get_slice("_", 3)))
		assert_false(clear.has(c), "nothing furnished beside a door or exit (%s)" % c)
		assert_false(taken.has(c), "nothing furnished on a square something stands on (%s)" % c)
		if Rect2i(19, 1, 4, 5).has_point(c):
			kitchen += 1
	assert_true(pieces >= 12, "the house is furnished (%d pieces)" % pieces)
	assert_true(kitchen >= 1, "the kitchen has kitchen things (%d)" % kitchen)
	v.queue_free()
	await _frames(1)


## The Death House holds what its text names (the audit's list): the sword over the hall hearth, the stag's head over
## the den's, pots hung by size, cheeses under cloth, an umbrella stand, the broom in the storeroom, skeletons in
## shackles round the shrine, the reliquary's relics.
func test_the_death_house_has_what_its_text_names() -> void:
	Look.set_style("modern", false)
	var want := {"death_house_ground": {"hall_hearth": "fireplace_sword", "den_stag_head": "stag_head",
			"kitchen_pots": "pot_rack", "pantry_cheeses": "cheeses", "foyer_umbrella": "umbrella_stand"},
		"death_house_third": {"storage_broom": "broom"},
		"death_house_dungeon_1": {"shrine_shackled_east": "skeleton_shackles"},
		"death_house_dungeon_2": {"reliquary_relics": "relics", "ritual_brazier_west": "brazier"}}
	for loc_id: String in want:
		var v := _view(loc_id)
		await _frames(1)
		for id: String in want[loc_id]:
			var node := v.prop_nodes.get(id) as Node
			var models := node.find_children("Model_*", "Node3D", true, false) if node != null else []
			assert_true(not models.is_empty() and str(models[0].get_meta("model", "")) == str(want[loc_id][id]),
				"%s: %s is the %s" % [loc_id, id, want[loc_id][id]])
		v.queue_free()
		await _frames(1)


## Owner (2026-10-08): "some buildings could use a few more random people to make more lively. Stores, churches,
## taverns". By day the village's shop has a customer and its church two people praying; the tavern keeps the four
## drinkers its narration counts.
func test_village_buildings_have_people_by_day() -> void:
	GameState.story.minute_of_day = 10 * 60
	var want := {"bildraths_mercantile": ["barovia_shopper"],
		"village_church": ["barovia_worshipper_mihai", "barovia_worshipper_sorina"]}
	for loc_id: String in want:
		var v := _view(loc_id)
		await _frames(1)
		for npc: String in want[loc_id]:
			assert_true(v.npc_tokens.has(npc), "%s is in %s by day" % [npc, loc_id])
		v.queue_free()
		await _frames(1)
	for npc: String in ["barovia_shopper", "barovia_worshipper_mihai", "barovia_worshipper_sorina"]:
		var d := Compendium.shared().get_entry("npcs", npc)
		assert_eq(str(d["portrait"]), str(d["sprite"]), "%s wears the face of the figure it walks as" % npc)


## Vallaki (the audit, docs/art/interiors.md): what each room's text names, and Rictavio's carnival wagon in the inn's
## yard painted red with gold trim and wheels, instead of a dark block of wall.
func test_vallakis_rooms_have_what_their_text_names() -> void:
	Look.set_style("modern", false)
	var want := {"vallaki_blue_water_inn": {"inn_kitchen_cauldron": "stewpot", "rictavio_lute": "lute",
			"rictavio_washstand": "washstand"},
		"vallaki_burgomaster_mansion": {"hall_bunting_a": "bunting", "lydia_cloth_a": "festival_cloth"},
		"vallaki_blinsky_toys": {"toy_shelf_north": "toy_shelf"},
		"vallaki_coffin_maker": {"coffin_lid_north": "coffin_lid", "henrik_crucifix_bed": "crucifix"},
		"vallaki_wachter_house": {"cellar_bench_1": "bench"}}
	for loc_id: String in want:
		var v := _view(loc_id)
		await _frames(1)
		for id: String in want[loc_id]:
			var node := v.prop_nodes.get(id) as Node
			var models := node.find_children("Model_*", "Node3D", true, false) if node != null else []
			assert_true(not models.is_empty() and str(models[0].get_meta("model", "")) == str(want[loc_id][id]),
				"%s: %s is the %s" % [loc_id, id, want[loc_id][id]])
		v.queue_free()
		await _frames(1)
	var inn := _view("vallaki_blue_water_inn")
	await _frames(2)
	var wagon := inn.board.get_node_or_null("WallStyle")
	assert_true(wagon != null, "the wagon has its own look")
	var wheels := 0
	for mi in (wagon.find_children("*", "MeshInstance3D", true, false) if wagon != null else []):
		if (mi as MeshInstance3D).mesh is CylinderMesh:
			wheels += 1
	assert_eq(wheels, 4, "two wheels a side")
	var red := 0
	var paint := BuildingKit.painted("crimson")
	for w: Dictionary in (inn.board.get_meta("interior_walls", {}) as Dictionary).get("walls", []):
		if Rect2i(15, 13, 7, 3).has_point(w["cell"] as Vector2i):
			for mi in (w["full"] as Node).find_children("*", "MeshInstance3D", true, false):
				if (mi as MeshInstance3D).material_override == paint:
					red += 1
					break
	assert_true(red >= 10, "its sides are painted red (%d)" % red)
	inn.queue_free()
	await _frames(1)


## Vallaki's inn has two more regulars of an evening, and St. Andral's a woman praying by day.
func test_vallaki_has_people_indoors() -> void:
	for at: Array in [["vallaki_blue_water_inn", 19, ["vallaki_patron_dragan", "vallaki_patron_oana"]],
			["vallaki_st_andrals", 10, ["vallaki_parishioner_varvara"]]]:
		GameState.story.minute_of_day = int(at[1]) * 60
		var v := _view(str(at[0]))
		await _frames(1)
		for npc: Variant in at[2]:
			assert_true(v.npc_tokens.has(str(npc)), "%s is in %s at %d:00" % [npc, at[0], at[1]])
			var d := Compendium.shared().get_entry("npcs", str(npc))
			assert_eq(str(d["portrait"]), str(d["sprite"]), "%s wears the face of the figure it walks as" % npc)
		v.queue_free()
		await _frames(1)


## Krezk and the Abbey (the audit, docs/art/interiors.md): what their text names; the rooms it calls bare, plain or kept
## clean hold only their own things (an area's `furnish: false`); the orphans' cots are cots, not little tombs; and the
## cold infirmary has its curtain hooks and no rug or armchair.
func test_krezk_and_the_abbey_have_what_their_text_names() -> void:
	Look.set_style("modern", false)
	var want := {"krezk_burgomaster_house": {"eldest_sword_sill": "sill_sword", "ilya_cups_sill": "sill_cups",
			"spinning_wheel": "spinning_wheel", "bench_by_door": "bench"},
		"abbey_of_st_markovia_shrine": {"chapel_sunburst": "sunburst", "sacristy_surplice": "surplice",
			"sacristy_vestments": "robe_pegs"},
		"abbey_of_st_markovia_wards": {"corridor_suns_1": "charcoal_suns", "surgery_instruments": "instrument_tray"}}
	var pots := {"abbey_of_st_markovia_wards": {"belview_pot": "cookpot"}}
	var bare := {"krezk_burgomaster_house": [Rect2i(1, 1, 6, 4), Rect2i(15, 1, 6, 4)],
		"abbey_of_st_markovia_shrine": [Rect2i(1, 1, 4, 4)]}
	for loc_id: String in want:
		var v := _view(loc_id)
		await _frames(1)
		var board := v.board
		for id: String in want[loc_id]:
			var node := v.prop_nodes.get(id) as Node
			var models := node.find_children("Model_*", "Node3D", true, false) if node != null else []
			assert_true(not models.is_empty() and str(models[0].get_meta("model", "")) == str(want[loc_id][id]),
				"%s: %s is the %s" % [loc_id, id, want[loc_id][id]])
		for id: String in pots.get(loc_id, {}):
			var node := v.container_nodes.get(id) as Node
			var models := node.find_children("Model_*", "Node3D", true, false) if node != null else []
			assert_true(not models.is_empty() and str(models[0].get_meta("model", "")) == str(pots[loc_id][id]),
				"%s: %s is the %s" % [loc_id, id, pots[loc_id][id]])
		for r: Rect2i in bare.get(loc_id, []):
			for n in board.get_children():
				if n.has_meta("furnish"):
					var c := Vector2i(int(str(n.name).get_slice("_", 2)), int(str(n.name).get_slice("_", 3)))
					assert_false(r.has_point(c), "%s: nothing furnished in a room its text calls bare (%s)" % [loc_id, c])
			for rug in board.find_children("FurnishRug*", "MeshInstance3D", true, false):
				var at := (rug as Node3D).global_position
				assert_false(Rect2(r).has_point(Vector2(at.x, at.z)), "%s: no rug in a bare room" % loc_id)
		if loc_id == "abbey_of_st_markovia_wards":
			var cots := 0
			for z in range(1, 5):
				for x in range(1, 13):
					var c := Vector2i(x, z)
					if board.grid.has_flag(c, CombatGrid.LOW):
						assert_eq(BattleScenery.art_at(board, c), "crib", "the foundling ward's %s is a cot" % c)
						cots += 1
			assert_true(cots >= 8, "rows of little cots (%d)" % cots)
			var hooks := 0
			var infirmary := Rect2(9, 8, 7, 5)
			for m in board.find_children("Model_*", "Node3D", true, false):
				var at := (m as Node3D).global_position
				if not infirmary.has_point(Vector2(at.x, at.z)) or str(m.get_parent().name).begins_with("Model_"):
					continue
				hooks += 1 if str(m.get_meta("model", "")) == "curtain_hooks" else 0
				assert_false(str(m.get_meta("model", "")) in ["armchair", "candelabra", "settee"], "the infirmary is cold and bare")
			assert_true(hooks >= 4, "curtain hooks on the infirmary's walls (%d)" % hooks)
			for rug in board.find_children("FurnishRug*", "MeshInstance3D", true, false):
				var at := (rug as Node3D).global_position
				assert_false(infirmary.has_point(Vector2(at.x, at.z)), "no rug in the infirmary")
		v.queue_free()
		await _frames(1)


## Old Bonegrinder and the Wizard of Wines (the audit, docs/art/interiors.md): what their text names; the winery's eight
## great vats over their blocks, with no rug or armchairs among them; casks in the wine cellar where little tombs and
## bones stood; the hags' nest is straw.
func test_bonegrinder_and_the_winery_have_what_their_text_names() -> void:
	Look.set_style("modern", false)
	var want := {"old_bonegrinder_loft": {"morgantha_footstool": "footstool", "morgantha_knitting": "knitting_basket"},
		"wizard_of_wines_press_house": {"door_tools_1": "tool_rack", "great_press": "wine_press"},
		"wizard_of_wines_winery": {"fermenting_vats": "great_vat", "great_vat_8": "great_vat", "bottle_racks": "bottle_rack",
			"tasting_cups_north": "cup_hooks"},
		"wizard_of_wines_cellar": {"old_bottles": "bottle_rack"}}
	for loc_id: String in want:
		var v := _view(loc_id)
		await _frames(1)
		var board := v.board
		for id: String in want[loc_id]:
			var node := v.prop_nodes.get(id) as Node
			var models := node.find_children("Model_*", "Node3D", true, false) if node != null else []
			assert_true(not models.is_empty() and str(models[0].get_meta("model", "")) == str(want[loc_id][id]),
				"%s: %s is the %s" % [loc_id, id, want[loc_id][id]])
		if loc_id == "wizard_of_wines_winery":
			var hall := Rect2(10, 1, 21, 7)   # the vats' rows (the tasting room starts below them)
			for m in board.find_children("Model_*", "Node3D", true, false):
				var at := (m as Node3D).global_position
				if (m as Node3D).is_visible_in_tree() and hall.has_point(Vector2(at.x, at.z)):
					assert_false(str(m.get_meta("model", "")) in ["armchair", "settee", "table_meal", "table_chairs", "candelabra"],
						"no parlour or tavern furniture among the vats (%s)" % m.get_meta("model", ""))
			for rug in board.find_children("FurnishRug*", "MeshInstance3D", true, false):
				var at := (rug as Node3D).global_position
				assert_false(hall.has_point(Vector2(at.x, at.z)), "no rug in the fermenting hall")
		if loc_id == "wizard_of_wines_cellar":
			for z in range(1, 13):
				for x in range(6, 16):
					if board.grid.has_flag(Vector2i(x, z), CombatGrid.LOW):
						assert_true(BattleScenery.art_at(board, Vector2i(x, z)) in ["cask_rack", "barrel"],
							"the cask vaults' %s holds casks, not %s" % [Vector2i(x, z), BattleScenery.art_at(board, Vector2i(x, z))])
			for m in board.find_children("Model_*", "Node3D", true, false):
				assert_false(str(m.get_meta("model", "")) in ["crypt_small", "skeleton", "bones"], "no tombs or bones among the casks")
		if loc_id == "old_bonegrinder_loft":
			for c: Vector2i in [Vector2i(2, 4), Vector2i(3, 5)]:
				assert_eq(BattleScenery.art_at(board, c), "straw_pallet", "the nest's hollows are straw")
		v.queue_free()
		await _frames(1)
