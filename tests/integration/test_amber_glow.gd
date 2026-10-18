extends TestCase
## The Amber Temple's amber (Amber Temple Look Plan, step 4: AmberGlow, shaders/world/amber.gdshader): in the Modern
## finish the sixteen vestiges stand upright, about two squares tall, lit from inside, each on the '=' square its prop
## already has; the Thirst's empty sarcophagus is the largest block of all, lying across its four squares; the cracked
## one is dead, the plinth empty, the sleepers under the vaults lie down, the Eye's block of amber is the size of a
## cottage; and Classic keeps the lying box it was frozen with.


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


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The case a prop stands as ("AmberCase_<id>" under its node), or null.
func _case(v: LocationView, prop_id: String) -> AmberGlow.Case:
	var node := v.prop_nodes.get(prop_id) as Node
	if node == null:
		return null
	for c in node.get_children():
		if c is AmberGlow.Case:
			return c as AmberGlow.Case
	return null


## The world-space box of a case's glass (its parts that are the amber itself).
func _glass_box(case: AmberGlow.Case) -> AABB:
	var box := AABB()
	var first := true
	for g in case.find_children("Glass", "MeshInstance3D", true, false):
		var mi := g as MeshInstance3D
		var b := mi.global_transform * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


const RING := ["sarc_zantras", "sarc_fekre", "sarc_taar_haak", "sarc_shami_amourae", "sarc_yog", "sarc_drizlash"]
const NAVE := ["sarc_khirad", "sarc_norganas", "sarc_savnok", "sarc_seriach", "sarc_sykane", "sarc_tarakamedes",
	"sarc_tenebrous", "sarc_yrrga", "sarc_zhudun", "sarc_dahlver_nar"]


## Every vestige is an upright block about two squares tall and under a square wide, standing on its own '=' square
## (the rules' squares are untouched), with a light of the amber kind inside it.
func test_the_vestiges_stand_upright_on_their_squares() -> void:
	for loc_id: String in ["amber_temple_faceless_god", "amber_temple_vault"]:
		var v := _view(loc_id)
		await _frames(3)
		for prop: Variant in v.loc["props"]:
			var id := str((prop as Dictionary)["id"])
			if not (id in RING or id in NAVE):
				continue
			var case := _case(v, id)
			assert_true(case != null, "%s is a case of amber" % id)
			if case == null:
				continue
			var cell := LocationView._cell((prop as Dictionary)["cell"])
			assert_true(v.grid.has_flag(cell, CombatGrid.LOW), "%s keeps its square's cover" % id)
			var box := _glass_box(case)
			assert_between(box.size.y, 1.7, 2.1, "%s stands about two squares tall (%.2f)" % [id, box.size.y])
			assert_true(box.size.x < 1.0 and box.size.z < 1.0, "and under a square wide (%.2f by %.2f)" % [box.size.x, box.size.z])
			var mid := box.get_center()
			var at := v.board.cell_center(cell)
			assert_true(absf(mid.x - at.x) < 0.25 and absf(mid.z - at.z) < 0.25, "on its own square")
			assert_true(case.light != null, "%s has a light inside it" % id)
			assert_eq(str(case.light.get_meta("light_kind", "")), "amber", "the amber kind, once dressed")
			assert_true(case.light.has_meta("no_shadow"), "casting no shadow")
			assert_true(LightFlicker.of(case.light) != null or case.locked, "and breathing (Savnok's holds still)")
			for m in case.glass:
				assert_true(bool(m.get_shader_parameter("see_through")), "%s opens a window round the party like a wall" % id)
		v.queue_free()
		await _frames(1)


## Each vestige holds its own shape and its own touch (Amber Temple Look Plan step 5): a quad turned to the camera hung in
## its block, dahlver_nar's teeth on a second plane that turns, Savnok's light holding still, Zhudun's light grey-white,
## Tenebrous's dim and its middle dark, Shami's glass rose.
func test_each_vestige_holds_its_own_shape() -> void:
	var held := {}
	var views: Array[LocationView] = []
	for loc_id: String in ["amber_temple_faceless_god", "amber_temple_vault"]:
		var v := _view(loc_id)
		views.append(v)
		await _frames(4)
		for prop: Variant in v.loc["props"]:
			var id := str((prop as Dictionary)["id"])
			if not (id in RING or id in NAVE):
				continue
			var case := _case(v, id)
			var vid := id.trim_prefix("sarc_")
			assert_eq(case.vestige, vid, "%s knows which vestige it holds" % id)
			assert_true(case.get_node_or_null("Shape") != null, "%s holds a shape in its block" % id)
			assert_true(case.shape_materials.size() == (2 if vid == "dahlver_nar" else 1), "%s: %d planes" % [id, case.shape_materials.size()])
			held[vid] = case
	await _frames(3)
	assert_eq(held.size(), 16, "all sixteen")
	var savnok := held["savnok"] as AmberGlow.Case
	assert_true(savnok.locked and savnok.light != null and LightFlicker.of(savnok.light) == null, "Savnok's light holds still")
	var normal := held["zantras"] as AmberGlow.Case
	assert_true(normal.light != null and LightFlicker.of(normal.light) != null, "the others breathe")
	var zhudun := held["zhudun"] as AmberGlow.Case
	assert_true(zhudun.light.light_color.r > 0.6 and absf(zhudun.light.light_color.r - zhudun.light.light_color.b) < 0.2, "Zhudun's light is grey-white")
	var tenebrous := held["tenebrous"] as AmberGlow.Case
	assert_true(tenebrous.light.base_energy < normal.light.base_energy * 0.5, "Tenebrous's is dim")
	assert_eq(int(tenebrous.shape_materials[0].get_shader_parameter("touch")), AmberGlow.TOUCHES["void"], "round a black middle")
	var shami := held["shami_amourae"] as AmberGlow.Case
	var core := shami.glass[0].get_shader_parameter("core") as Color
	assert_true(core.r > core.g and core.r > 0.6, "Shami's glass is rose-honey")
	var teeth := (held["dahlver_nar"] as AmberGlow.Case).shape_materials[1]
	assert_true(float(teeth.get_shader_parameter("spin")) > 0.0, "Dahlver-Nar's teeth turn slowly")
	for v in views:
		v.queue_free()
	await _frames(1)


## The hollow is the largest block of all: lying across all four squares of its cover, longer and higher than any
## vestige, dead and clouded, with the shape of a man hollowed out of its top.
func test_the_hollow_is_the_largest() -> void:
	var v := _view("amber_temple_vault")
	await _frames(3)
	var hollow := _case(v, "hollow_sarcophagus")
	assert_true(hollow != null, "the hollow is a case of amber")
	var box := _glass_box(hollow)
	assert_true(box.size.x >= 3.7 and box.size.x <= 4.1, "it lies across its four squares (%.2f long)" % box.size.x)
	var biggest := 0.0
	for id: String in NAVE:
		var b := _glass_box(_case(v, id))
		biggest = maxf(biggest, b.size.x * b.size.y * b.size.z)
	assert_true(box.size.x * box.size.y * box.size.z > biggest * 3.0, "the largest of all by far")
	assert_true(box.size.y >= 0.9, "and higher than a coffin (%.2f)" % box.size.y)
	assert_true(hollow.get_node_or_null("Hollow") != null, "with a man's shape hollowed out of its top")
	for m in hollow.glass:
		assert_true(float(m.get_shader_parameter("dead")) > 0.7, "dead")
	assert_true(hollow.light == null, "with no light")
	for c in 4:
		assert_true(v.grid.has_flag(Vector2i(18 + c, 26), CombatGrid.LOW), "its squares are still cover")
	var centre := box.get_center()
	assert_true(absf(centre.x - (v.board.cell_center(Vector2i(18, 26)).x + v.board.cell_center(Vector2i(21, 26)).x) / 2.0) < 0.2,
		"centred over the four")
	v.queue_free()


## The cracked one is dead and split, the empty plinth is a plinth with a ring of frost and no glass.
func test_the_cracked_one_and_the_empty_plinth() -> void:
	var v := _view("amber_temple_vault")
	await _frames(3)
	var cracked := _case(v, "cracked_sarcophagus")
	assert_true(cracked != null and cracked.get_node_or_null("Crack") != null, "split down the middle")
	for m in cracked.glass:
		assert_true(float(m.get_shader_parameter("dead")) > 0.8, "and dead")
	assert_true(cracked.light == null, "with no light")
	var plinth := _case(v, "empty_plinth")
	assert_true(plinth != null, "the empty plinth is a case too")
	assert_true(plinth.find_children("Glass", "MeshInstance3D", true, false).is_empty(), "with nothing in it")
	assert_true(plinth.get_node_or_null("Frost") != null, "a ring of frost round its foot")
	assert_true(plinth.get_node_or_null("Scrape0") != null, "and marks on the floor where something was dragged")
	v.queue_free()


## The eight sleepers under the vaults keep lying down, in the same amber.
func test_the_sleepers_lie_down() -> void:
	var v := _view("amber_deep")
	await _frames(3)
	for i in range(1, 9):
		var case := _case(v, "sleeper_%d" % i)
		assert_true(case != null, "sleeper %d is amber" % i)
		if case != null:
			var box := _glass_box(case)
			var long := maxf(box.size.x, box.size.z)   # (turned a quarter to face its room)
			assert_true(box.size.y < 0.7 and long > 0.8, "lying down (%.2f high, %.2f long)" % [box.size.y, long])
	v.queue_free()


## The block of amber in the Eye's chamber is the size of a cottage (its text: "a block of amber the size of a cottage,
## split from the inside like an egg"): over three squares wide and a storey tall, open on one side.
func test_the_eyes_block_is_the_size_of_a_cottage() -> void:
	var v := _view("amber_deep")
	await _frames(3)
	var block := _case(v, "eye_block")
	assert_true(block != null, "the Eye's block is a case of amber")
	var box := _glass_box(block)
	assert_true(box.size.x >= 3.0, "over fifteen feet across (%.2f squares)" % box.size.x)
	assert_true(box.size.y >= 2.8, "and about as high as a cottage (%.2f squares)" % box.size.y)
	for m in block.glass:
		assert_true(float(m.get_shader_parameter("cut_open")) < 0.9, "split open")
	v.queue_free()


## Classic keeps the lying box it was frozen with: nothing of the new amber is built.
func test_classic_keeps_the_lying_box() -> void:
	Look.set_style("classic", false)
	var v := _view("amber_temple_faceless_god")
	await _frames(2)
	assert_true(_case(v, "sarc_zantras") == null, "no case of amber in Classic")
	assert_true(v.prop_nodes.get("sarc_zantras") != null, "the old box stands")
	v.queue_free()


## The block's mesh is closed and faces outward: its normals point away from its middle, so the glass is lit from
## the right side and the two passes (the far inside, the near face) draw the faces they should.
func test_a_blocks_mesh_faces_outward() -> void:
	var mesh := AmberGlow._block_mesh(Vector3(0.8, 1.84, 0.54), 0.08)
	var arrays := mesh.surface_get_arrays(0)
	var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var centre := Vector3(0, 0.92, 0)
	var out := 0
	for i in verts.size():
		if normals[i].dot(verts[i] - centre) > 0.0:
			out += 1
	assert_true(verts.size() > 100 and out == verts.size(), "every one of %d vertices faces outward (%d do)" % [verts.size(), out])
	assert_true(absf(mesh.get_aabb().size.y - 1.84) < 0.001, "and it is as tall as asked")
