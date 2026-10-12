extends TestCase
## The decor horses (owner report 2026-10-12: "The Horse sprites are really glitchy (the ones in the overworld as
## decor)"): sculpted into 3D slabs from their pictures, they tore at the edges whenever the camera turned. They are
## drawn flat again, like the characters, and at a horse's full height even in a pen two squares long.


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func test_horses_are_flat_and_full_size() -> void:
	var want := {"tser_pool": ["vistani_horses", "tser_horse_bay", "tser_horse_grey"],
		"vallaki_vistani_camp": ["camp_horse_bay", "camp_horse_grey", "arrigal_black_horse"],
		"castle_ravenloft_gates": ["crg_carriage_horse"], "van_richtens_tower": ["vrt_hobbled_horse"]}
	var real := float((SetDressing.catalog()["feet"] as Dictionary)["horse"]) / 5.0
	for loc: String in want:
		var v := LocationView.create(loc, GameState.story, null, Dice.roller, "default")
		add_child(v)
		await get_tree().process_frame
		for id: String in want[loc]:
			var root := v.board.find_child("Dressing_" + id, true, false)
			assert_true(root != null, "%s: %s stands" % [loc, id])
			if root == null:
				continue
			assert_eq(root.find_children("Model_*", "Node3D", true, false).size(), 0, "%s: %s is no 3D slab" % [loc, id])
			var flat := root.find_children("*", "Sprite3D", true, false)
			assert_false(flat.is_empty(), "%s: %s is drawn flat" % [loc, id])
			if flat.is_empty():
				continue
			var sp := flat[0] as Sprite3D
			var tall := sp.texture.get_height() * sp.pixel_size * sp.global_basis.y.length()
			assert_between(tall, real * 0.95, real * 1.05, "%s: %s stands a horse's height, not a pony's (%.2f)" % [loc, id, tall])
		v.queue_free()
		await get_tree().process_frame


## Kept at full size, a horse two squares long clears only those squares: the rails of Tser Pool's pen stay up
## round it.
func test_the_pen_keeps_its_rails() -> void:
	var v := LocationView.create("tser_pool", GameState.story, null, Dice.roller, "default")
	add_child(v)
	await get_tree().process_frame
	for c: Vector2i in [Vector2i(6, 21), Vector2i(7, 21), Vector2i(8, 21), Vector2i(10, 21), Vector2i(11, 21), Vector2i(5, 20)]:
		var up := false
		for n: Node3D in v.board.dressing.get(c, []):
			up = up or n.visible
		assert_true(up, "the rail at %s stands" % c)
	v.queue_free()
	await get_tree().process_frame
