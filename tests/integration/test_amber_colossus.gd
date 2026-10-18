extends TestCase
## The colossi at the Amber Temple's doors (Amber Temple Look Plan step 8, AmberColossus): the Sentinel stands on a low dais
## its entry says it is `on` (a prop, nothing in the rules grid changes), its eyes are lit and follow its state, the doors
## give off a wedge of light and hang icicles, the dead twin is dark amber (the prop's `tint`) and keeps its full size
## among its shards, the Sentinel turns its head to the leader as its first line starts, and once it is destroyed the dais
## lies cracked with shards of amber round it. Classic keeps the figure on the bare snow.

const DAIS_SQUARES: Array[Vector2i] = [Vector2i(18, 10), Vector2i(19, 10), Vector2i(18, 11), Vector2i(19, 11)]


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	Look.set_style("modern", false)


func after_each() -> void:
	Look.set_style(Look.DEFAULT_STYLE, false)


func _view() -> LocationView:
	var v := LocationView.create("amber_temple_entrance", GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


func test_the_sentinel_stands_on_its_dais() -> void:
	var v := _view()
	await get_tree().process_frame
	var dais := v.prop_nodes.get("sentinel_dais") as Node3D
	assert_true(dais != null and dais.has_meta("seat"), "the dais is built and says where to stand")
	var slab := dais.find_child("Dais", true, false) as MeshInstance3D
	var box := slab.global_transform * slab.mesh.get_aabb()
	assert_true(absf(box.size.x - 2.0) < 0.1 and absf(box.size.z - 2.0) < 0.1, "two squares by two (%.2f by %.2f)" % [box.size.x, box.size.z])
	var seat := dais.get_meta("seat") as Vector3
	assert_true(absf(box.end.y - seat.y) < 0.02, "the seat is its top")
	assert_true(seat.y - v.board.cell_center(Vector2i(18, 10)).y < 0.4, "a foot or so up (%.2f)" % (seat.y - v.board.cell_center(Vector2i(18, 10)).y))
	var tok := v.npc_tokens.get("amber_sentinel") as Node3D
	assert_true(tok != null and tok.position.is_equal_approx(seat), "the Sentinel stands in the middle of it")
	for c in DAIS_SQUARES:
		assert_true(not v.grid.is_solid(c) and not v.grid.has_flag(c, CombatGrid.LOW), "the dais changes no square of the rules' grid (%s)" % str(c))
	assert_true(dais.find_child("DaisSeam", true, false) != null, "with its amber seam")
	v.queue_free()


func test_the_eyes_burn_as_the_state_says() -> void:
	var v := _view()
	await get_tree().process_frame
	var eye := v.get_node_or_null("SentinelEyes") as AmberColossus.Eye
	assert_true(eye != null, "the Sentinel has its eyes")
	for _i in 12:
		eye._process(0.5)
	var tok := v.npc_tokens.get("amber_sentinel") as Node3D
	assert_true(eye.visible, "lit while it stands there")
	assert_true(absf(eye.global_position.y - (tok.global_position.y + AmberColossus.EYE_UP)) < 0.01, "at its head")
	var watching := eye.light.base_energy
	v.set_speaking("amber_sentinel")
	for _i in 12:
		eye._process(0.5)
	assert_true(eye.light.base_energy > watching * 1.5, "flaring while it speaks (%.2f over %.2f)" % [eye.light.base_energy, watching])
	v.set_speaking("")
	GameState.story.set_flag("sentinel_stilled")
	AmberColossus.refresh(v)
	for _i in 12:
		eye._process(0.5)
	assert_true(eye.light.base_energy < watching * 0.4, "an ember once it is stilled (%.2f under %.2f)" % [eye.light.base_energy, watching])
	v.queue_free()


func test_the_dais_cracks_and_the_shards_lie_when_it_is_destroyed() -> void:
	GameState.story.set_flag("sentinel_destroyed")
	var v := _view()
	await get_tree().process_frame
	assert_true(v.prop_nodes.get("sentinel_dais") == null, "no whole dais")
	var dais := v.prop_nodes.get("sentinel_dais_cracked") as Node3D
	assert_true(dais != null and dais.find_children("DaisHalf*", "MeshInstance3D", true, false).size() == 2, "it is broken in two")
	var shards := 0
	for id: String in v.prop_nodes:
		if id.begins_with("sentinel_shard_"):
			shards += 1
	assert_eq(shards, 6, "shards of amber lie round it")
	assert_true(v.npc_tokens.get("amber_sentinel") == null, "and nobody stands on it")
	var eye := v.get_node_or_null("SentinelEyes") as AmberColossus.Eye
	eye._process(0.1)
	assert_true(not eye.visible, "its eyes are out")
	v.queue_free()


func test_the_doors_give_light_and_hang_icicles() -> void:
	var v := _view()
	await get_tree().process_frame
	var wedge := v.board.get_node_or_null("DoorsWedge") as MeshInstance3D
	assert_true(wedge != null, "a wedge of light")
	var box := wedge.global_transform * wedge.mesh.get_aabb()
	assert_true(box.position.z >= 9.9 and box.end.z > 14.0, "from the doors' face out over the snow (%.1f to %.1f)" % [box.position.z, box.end.z])
	assert_true(absf((box.position.x + box.end.x) / 2.0 - 16.0) < 0.1, "from the middle of the pair of doors")
	var strength := float((wedge.material_override as ShaderMaterial).get_shader_parameter("strength"))
	v.st.minute_of_day = 23 * 60
	AmberColossus.refresh(v)
	assert_true(float((wedge.material_override as ShaderMaterial).get_shader_parameter("strength")) > strength, "brighter by night (%.2f)" % strength)
	var icicles := v.board.get_node_or_null("DoorsIcicles")
	assert_true(icicles != null and icicles.get_child_count() == AmberColossus.LINTEL.size(), "icicles hang from the lintel")
	var floor_y := v.board.floor_y(Vector2i(16, 9))
	for sp: Node in icicles.get_children():
		var up := (sp as Sprite3D).global_position.y - floor_y
		assert_true(up > 0.4 and up < 1.3, "at the doors' height (%.2f over the floor)" % up)
	v.queue_free()


func test_the_dead_twin_is_dark_amber_and_keeps_its_size() -> void:
	var v := _view()
	await get_tree().process_frame
	var twin := v.prop_nodes.get("cracked_colossus") as Node3D
	assert_true(twin != null, "the split colossus stands")
	var tinted := 0
	for n: Node in twin.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var m := mi.get_active_material(0) as ShaderMaterial
		if m != null and m.get_shader_parameter("tint") is Color:
			var c := m.get_shader_parameter("tint") as Color
			if c.r > c.g and c.g > c.b and c.r < 1.0:
				tinted += 1
	assert_true(tinted >= 1, "its colours are amber, darkened")
	var model := twin.find_children("Model_*", "Node3D", true, false)
	assert_true(not model.is_empty(), "a 3D piece")
	var box := AABB()
	var first := true
	for n: Node in twin.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var b := mi.global_transform * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	assert_true(box.size.y > 5.5, "as tall as the Sentinel, thirty feet (%.2f units): its shards don't crowd it smaller" % box.size.y)
	var shards := v.board.get_node_or_null("TwinShards")
	assert_true(shards != null and shards.get_child_count() == AmberColossus.TWIN_SHARDS.size(), "shards of amber round its feet")
	v.queue_free()


func test_the_sentinel_turns_its_head_to_the_leader() -> void:
	var v := _view()
	await get_tree().process_frame
	var tok := v.npc_tokens.get("amber_sentinel") as CombatToken
	var away := Vector3(tok.sprite.facing.x, 0.0, tok.sprite.facing.z)
	assert_true(away.dot(Vector3(0.0, 0.0, 1.0)) > 0.9, "it watches the valley (south) at rest")
	v.dialogue_requested.emit("amber_temple/sentinel:arrival", "amber_sentinel")
	var to_leader := ((v.tokens[v.leader().id] as Node3D).global_position - tok.global_position)
	to_leader.y = 0.0
	assert_true(tok.sprite.facing.dot(to_leader.normalized()) > 0.95, "and turns to the leader as its first line starts")
	v.queue_free()


func test_classic_keeps_the_figure_on_the_snow() -> void:
	Look.set_style("classic", false)
	var v := _view()
	await get_tree().process_frame
	var dais := v.prop_nodes.get("sentinel_dais") as Node3D
	assert_true(dais == null or not dais.has_meta("seat"), "no dais in Classic")
	var tok := v.npc_tokens.get("amber_sentinel") as Node3D
	assert_true(tok.position.is_equal_approx(v.board.cell_center(Vector2i(18, 10))), "the figure stands on its own square")
	assert_true(v.get_node_or_null("SentinelEyes") == null and v.board.get_node_or_null("DoorsWedge") == null, "and nothing else is added")
	v.queue_free()
