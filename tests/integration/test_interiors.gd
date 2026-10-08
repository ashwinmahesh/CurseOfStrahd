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
