extends Node
## make capture SCENE=res://tools/capture/hotbar_capture.tscn NAME=hotbar FRAMES=10
## The hotbar for creatures that aren't a character sheet (ActionCatalog._feature_entries): a druid in Wild Shape
## with Leave Wild Shape on its Abilities tab, then a summoned steed's own actions (Healing Touch).

func capture_shots(tool: Node, out: String) -> void:
	InputActions.ensure()
	var e := TestCombat.open_field(3)
	var d := e.add(TestChars.custom("druid", "human", 2), &"party", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3), 300)
	TestCombat.start_with(e, d)
	e.feature_actions.perform(d, "cf:wild_shape:" + str(e.class_features.wild_forms(d)[0]["id"]), null, Vector2.INF)
	await _hud_shot(tool, e, out + "_1_wild_shape.png")
	var e2 := TestCombat.open_field(10)
	var c := TestCombat.caster_with(e2, ["find_steed"], Vector2i(2, 3))
	TestCombat.punching_bag(e2, Vector2i(9, 9), 100)
	TestCombat.start_with(e2, c)
	e2.spells.cast(c, "find_steed", 2, [], Vector2(3.5, 3.5), Vector2.ZERO, {"choice": "celestial"})
	for id: Variant in e2.spells.summoned.get(c.id, []):
		e2.turn_index = e2.order.find(e2.get_c(str(id)))
	await _hud_shot(tool, e2, out + "_2_steed.png")


func _hud_shot(tool: Node, e: Encounter, path: String) -> void:
	var catalog := ActionCatalog.new(e)
	var hud := CombatHud.new()
	add_child(hud)
	hud.build(e, catalog)
	hud.set_tab(catalog.class_tab(e.current()))
	hud.refresh()
	await tool.call("wait_frames", 10)
	tool.call("_shot", path)
	hud.queue_free()
