extends TestCase
## The sounds of a fight (art/audio.json "combat", world/combat/fx/combat_sfx.gd): every sound the picks name has a
## recording, every family, flavour and key they name is one the effects use, a family and its flavour layer, and a
## blow's sound follows what struck and how hard it landed.


func _combat() -> Dictionary:
	return CombatSfx.data()


func _named_ids() -> Array[String]:
	var out: Array[String] = []
	var d := _combat()
	for table: String in ["families", "keys"]:
		for k: String in d.get(table, {}) as Dictionary:
			for moment: String in (d[table] as Dictionary)[k] as Dictionary:
				for id in CombatSfx._list(((d[table] as Dictionary)[k] as Dictionary)[moment]):
					if not id.begins_with("@"):
						out.append(id)
	for table: String in ["flavours", "hits"]:
		for k: String in d.get(table, {}) as Dictionary:
			for moment: String in (d[table] as Dictionary)[k] as Dictionary:
				out.append_array(CombatSfx._list(((d[table] as Dictionary)[k] as Dictionary)[moment]))
	return out


func test_every_sound_named_has_a_recording() -> void:
	for id in _named_ids():
		assert_false(Audio.files("sfx", id).is_empty(), "art/audio.json combat names %s, which has no recording in sfx" % id)


func test_picks_name_real_families_flavours_and_keys() -> void:
	var d := _combat()
	var looks := SpellFx.data()
	for family: String in d.get("families", {}) as Dictionary:
		assert_true(SpellFx.has_family(family), "combat sounds for family %s, which SpellFx doesn't have" % family)
	for flavour: String in d.get("flavours", {}) as Dictionary:
		assert_true((looks["flavours"] as Dictionary).has(flavour), "combat sounds for flavour %s, which art/vfx/effects.json doesn't have" % flavour)
	for key: String in d.get("keys", {}) as Dictionary:
		var known := false
		for table: String in ["spells", "features", "monsters"]:
			known = known or (looks.get(table, {}) as Dictionary).has(key)
		known = known or not Compendium.shared().spell_data(key).is_empty()
		assert_true(known, "combat sounds for %s, which is no spell, feature or monster action" % key)
	for kind: String in ["blade", "point", "blunt", "shot"]:
		for tier: String in ["light", "heavy", "critical"]:
			assert_false(CombatSfx.hit_ids(kind, 10, 30, tier == "critical").is_empty() if tier != "heavy" else CombatSfx.hit_ids(kind, 20, 30, false).is_empty(),
				"%s hits have a %s sound" % [kind, tier])


func test_a_family_and_its_flavour_layer() -> void:
	var saved := CombatSfx._data
	CombatSfx._data = {
		"families": {"burst": {"impact": ["blast", "@impact"]}, "bolt": {"launch": "@launch", "impact": "@impact"}},
		"flavours": {"fire": {"launch": "fire_whoosh", "impact": "fire_burst"}},
		"keys": {"hold_person": {"cast": ["chains", "mind"]}}}
	assert_eq(CombatSfx.ids_for({"key": "fireball", "family": "burst", "flavour": "fire"}, "impact"), ["blast", "fire_burst"] as Array[String])
	assert_eq(CombatSfx.ids_for({"key": "fireball", "family": "burst", "flavour": "cold"}, "impact"), ["blast"] as Array[String],
		"a flavour with no sound leaves the family's")
	assert_eq(CombatSfx.ids_for({"key": "fire_bolt", "family": "bolt", "flavour": "fire"}, "launch"), ["fire_whoosh"] as Array[String])
	assert_eq(CombatSfx.ids_for({"key": "fire_bolt", "family": "bolt", "flavour": "fire"}, "cast"), [] as Array[String])
	assert_eq(CombatSfx.ids_for({"key": "hold_person", "family": "psychic", "flavour": "mind"}, "cast"), ["chains", "mind"] as Array[String],
		"a spell's own sound wins over its family's")
	CombatSfx._data = saved


func test_a_blow_sounds_by_what_struck_and_how_hard() -> void:
	assert_false(CombatSfx.heavy(4, 8), "a few points never land heavy")
	assert_true(CombatSfx.heavy(6, 20), "a quarter of the target's Hit Points lands heavy")
	assert_false(CombatSfx.heavy(10, 150), "a fair blow on a big foe is light")
	assert_true(CombatSfx.heavy(15, 150), "a big blow is heavy on anyone")
	assert_false(CombatSfx.heavy(-1, 20), "an unknown amount is light")
	assert_eq(CombatSfx.hit_kind(null, "weapon:longsword"), "blade")
	assert_eq(CombatSfx.hit_kind(null, "weapon:mace"), "blunt")
	assert_eq(CombatSfx.hit_kind(null, "weapon:spear"), "point")
	assert_eq(CombatSfx.hit_kind(null, "weapon:longbow@arrow"), "shot")
	assert_eq(CombatSfx.hit_kind(null, "thrown:handaxe"), "shot")
