extends TestCase
## Books on hold (owner, 2026-10-07: Faerun and Arcana Unleashed, "hide until ready"): their entries carry
## "playable": false and stay out of creation, level-up and spell choices and random treasure until each one works.

func test_choices_and_treasure_leave_them_out() -> void:
	var comp := Compendium.shared()
	for cls: String in ["cleric", "wizard", "fighter", "rogue", "bard", "druid", "paladin", "ranger", "sorcerer", "warlock", "monk", "barbarian"]:
		for s in comp.subclasses_of(cls):
			assert_true(Compendium.playable(s), "subclass %s offered" % s["id"])
	for s in comp.spells_for(""):
		assert_true(Compendium.playable(s), "spell %s offered" % s["id"])
	for f in comp.feats_in(""):
		assert_true(Compendium.playable(f), "feat %s offered" % f["id"])
	for folder: String in ["backgrounds", "magic_items", "species"]:
		for e in comp.all_playable(folder):
			assert_true(Compendium.playable(e), "%s/%s offered" % [folder, e["id"]])
	var hidden := comp.all("subclasses").filter(func(e: Dictionary) -> bool: return not Compendium.playable(e))
	for e: Dictionary in hidden:
		assert_false(comp.subclasses_of(str(e["class"])).has(e), "a subclass that isn't playable isn't offered")


func test_lookups_by_id_still_find_them() -> void:
	var comp := Compendium.shared()
	for e in comp.all("subclasses"):
		if not Compendium.playable(e):
			assert_false(comp.get_entry("subclasses", str(e["id"])).is_empty(), "a save that names %s still loads" % e["id"])
			return
