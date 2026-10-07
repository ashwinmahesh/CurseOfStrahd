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


## A playable entry can't hand out one that isn't: a background's origin feat, the spells a feat, subclass or item
## grants (`spell` modifiers, always-prepared lists, item powers). Otherwise turning a background on would sneak in a
## feat that doesn't work yet.
func test_playable_entries_only_grant_playable_ones() -> void:
	var comp := Compendium.shared()
	for b in comp.all_playable("backgrounds"):
		var feat := comp.feat_data(str(b.get("feat", "")))
		assert_true(feat.is_empty() or Compendium.playable(feat), "background %s grants feat %s, which isn't playable" % [b["id"], b.get("feat", "")])
	for folder: String in ["feats", "subclasses", "magic_items", "species"]:
		for e in comp.all_playable(folder):
			var spells: Array[String] = []
			_granted_spells(e, spells)
			for lv: Variant in (e.get("always_prepared", {}) as Dictionary).values():
				for id: Variant in lv as Array:
					spells.append(str(id))
			for id in spells:
				var s := comp.spell_data(id)
				assert_true(s.is_empty() or Compendium.playable(s), "%s/%s grants spell %s, which isn't playable" % [folder, e["id"], id])


func _granted_spells(node: Variant, out: Array[String]) -> void:
	if node is Array:
		for v: Variant in node as Array:
			_granted_spells(v, out)
	elif node is Dictionary:
		var d := node as Dictionary
		if str(d.get("stat", "")) == "spell" and d.get("value") is String and not str(d["value"]).begins_with("@"):
			out.append(str(d["value"]))
		if d.get("spell") is String:
			out.append(str(d["spell"]))
		for v: Variant in d.values():
			_granted_spells(v, out)
