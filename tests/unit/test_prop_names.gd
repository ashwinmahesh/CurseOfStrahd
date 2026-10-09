extends TestCase
## A prop with no label of its own is named by what it is (Storyline QA via UI QA, 2026-10-08: unlabelled decor said
## "Look at it" in its menu and on its name plate).


func test_props_are_named_by_label_then_model() -> void:
	assert_eq(LocationInteraction.prop_name({"label": "the old well", "model": "well"}), "the old well")
	assert_eq(LocationInteraction.prop_name({"model": "fishing_nets"}), "the fishing nets")
	assert_eq(LocationInteraction.prop_name({"model": "bramble_b"}), "the bramble", "a variant letter goes")
	assert_eq(LocationInteraction.prop_name({"model": "grave_open"}), "the open grave")
	assert_eq(LocationInteraction.prop_name({}), "it")


func test_no_prop_in_the_game_is_just_it() -> void:
	var c := Compendium.shared()
	for id: String in c.table("locations"):
		for p: Variant in c.get_entry("locations", id).get("props", []):
			var name := LocationInteraction.prop_name(p as Dictionary)
			assert_ne(name, "it", "%s's %s has a name" % [id, (p as Dictionary)["id"]])
			assert_false(name.contains("_"), "%s reads as words" % name)
