extends TestCase
## Owner report (2026-10-08): Old Kolya wore the generic commoner portrait, a woman in a headscarf. The men who walk as
## the villager sprite wear the villager's own face, and Kolya his own, aged; every portrait they name exists.


func test_the_villagers_wear_a_mans_face() -> void:
	var checked := 0
	for npc: Variant in (Compendium.shared().tables["npcs"] as Dictionary).values():
		var d := npc as Dictionary
		if str(d.get("sprite", "")) != "villager":
			continue
		checked += 1
		var portrait := str(d.get("portrait", d["id"]))
		assert_true(portrait != "commoner", "%s walks as a villager but wears the commoner woman's face" % d["id"])
		assert_true(ResourceLoader.exists("res://art/portraits/%s.png" % portrait), "%s's portrait %s exists" % [d["id"], portrait])
	assert_true(checked >= 6, "Kolya and the five village men (%d)" % checked)


func test_old_kolya_has_his_own_portrait() -> void:
	assert_eq(str(Compendium.shared().get_entry("npcs", "vallaki_carter")["portrait"]), "vallaki_carter")
	assert_true(ResourceLoader.exists("res://art/portraits/vallaki_carter.png"))
