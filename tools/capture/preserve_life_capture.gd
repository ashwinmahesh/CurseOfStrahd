extends Node
## Preserve Life's prompt (owner question 2026-10-14: the pool never seemed to go down): the default division, a
## slider moved so the count of what is left to share falls, and the same prompt with the pool spent.
## make capture SCENE=res://tools/capture/preserve_life_capture.tscn NAME=preserve_life FRAMES=10

func capture_shots(tool: Node, out: String) -> void:
	InputActions.ensure()
	var e := TestCombat.open_field()
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var i := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3), 5)
	var t := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(3, 4), 5)
	var s := TestCombat.hero(e, "silvain_aster", Vector2i(2, 4), 5)
	TestCombat.foe(e, "zombie", Vector2i(10, 6))
	TestCombat.start_with(e, h)
	i.creature.hp = 4
	t.creature.hp = 6
	s.creature.hp = 5
	var hud := CombatHud.new()
	add_child(hud)
	hud.build(e, ActionCatalog.new(e))
	hud.refresh()
	var req := e.features.preserve_life_prompt(h).pending
	hud.show_prompt(req)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_1_default.png")
	var sliders := hud.get("_prompt_sliders") as Dictionary
	(sliders[i.id] as HSlider).value = 4
	(sliders[t.id] as HSlider).value = 3
	await tool.call("wait_frames", 4)
	tool.call("_shot", out + "_2_part_shared.png")
	hud.answer_prompt(false)
	hud.hide_prompt()
	hud.queue_free()
