extends TestCase
## The 56 spells that left the game (Ashwin, 2026-10-12: the spells that did nothing and couldn't be given a use; and
## Detect Thoughts, 2026-10-13): their files stay, marked removed and not playable, so they're out of every spell list, picker and scroll, and a saved hero
## who knew one gets another spell of its level when the save loads (Character.swap_removed_spells).


func _removed() -> Array[String]:
	var out: Array[String] = []
	for s in Compendium.shared().all("spells"):
		if s.has("removed"):
			out.append(str(s["id"]))
	return out


func test_fifty_six_spells_are_out_of_every_list_and_scroll() -> void:
	var gone := _removed()
	assert_eq(gone.size(), 56, "54, Water Walk (nowhere in the game sits across deep water) and Detect Thoughts")
	for id in gone:
		assert_false(Compendium.playable(Compendium.shared().spell_data(id)), id)
	for cls: String in ["bard", "cleric", "druid", "paladin", "ranger", "sorcerer", "warlock", "wizard"]:
		for s in Compendium.shared().spells_for(cls):
			assert_false(str(s["id"]) in gone, "%s offers %s" % [cls, s["id"]])
	for lvl in range(1, 10):
		for seed_value in 40:
			var scroll := MagicItems.scroll_of_level(DiceRoller.new(seed_value), lvl, Compendium.shared())
			assert_false(scroll.get_slice(MagicItems.SEP, 1) in gone, scroll)
	for sub: String in ["gloom_stalker", "arcana_domain", "trickery_domain", "aberrant_sorcery", "great_old_one_patron", "knowledge_domain"]:
		for lv: Variant in (Compendium.shared().subclass_data(sub).get("always_prepared", {}) as Dictionary).values():
			for s: Variant in lv:
				assert_false(str(s) in gone, "%s still grants %s" % [sub, s])


## Replaces the first pick of `level` in `key` with `spell`, as a save from before the removal would have it.
func _plant(ch: Character, key: String, level: int, spell: String) -> String:
	var picks := (ch.build["choices"] as Dictionary)[key] as Array
	for i in picks.size():
		if int(Compendium.shared().spell_data(str(picks[i])).get("level", -1)) == level:
			var was := str(picks[i])
			picks[i] = spell
			return was
	picks.append(spell)
	return ""


func test_a_saved_wizard_who_knew_sending_gets_another_spell() -> void:
	var wiz := TestChars.custom("wizard", "human", 9)
	var book_key := "wizard.spellbook"
	var prep_key := "wizard.prepared"
	assert_true((wiz.build["choices"] as Dictionary).has(book_key), str((wiz.build["choices"] as Dictionary).keys()))
	_plant(wiz, book_key, 3, "sending")
	_plant(wiz, prep_key, 3, "sending")
	(wiz.build as Dictionary)["copied_spells"] = ["clone"]
	var book_size := ((wiz.build["choices"] as Dictionary)[book_key] as Array).size()
	var loaded := Character.from_dict(JSON.parse_string(JSON.stringify(wiz.to_dict())) as Dictionary)
	assert_false(loaded.knows_spell("sending"), "Sending is gone")
	var book := (loaded.build["choices"] as Dictionary)[book_key] as Array
	assert_eq(book.size(), book_size, "the spellbook keeps its size: a replacement")
	assert_false("sending" in book)
	assert_false("sending" in ((loaded.build["choices"] as Dictionary)[prep_key] as Array))
	assert_eq(((loaded.build["choices"] as Dictionary)[prep_key] as Array).size(), ((wiz.build["choices"] as Dictionary)[prep_key] as Array).size())
	assert_false("clone" in (loaded.build.get("copied_spells", []) as Array), "a copied removed spell is simply gone")
	assert_true(loaded.pending_choices().filter(func(c: Choice) -> bool: return c.kind in ["spell", "spellbook"]).is_empty(),
		"nothing left to pick")


func test_a_saved_bard_who_knew_geas_gets_another_fifth_level_spell() -> void:
	var bard := TestChars.custom("bard", "human", 9)
	var key := "bard.prepared"
	assert_true((bard.build["choices"] as Dictionary).has(key), str((bard.build["choices"] as Dictionary).keys()))
	_plant(bard, key, 5, "geas")
	var loaded := Character.from_dict(JSON.parse_string(JSON.stringify(bard.to_dict())) as Dictionary)
	assert_false(loaded.knows_spell("geas"))
	var fifth := ((loaded.build["choices"] as Dictionary)[key] as Array).filter(func(s: Variant) -> bool:
		return int(Compendium.shared().spell_data(str(s)).get("level", -1)) == 5)
	assert_false(fifth.is_empty(), "a 5th-level spell in its place")


func test_a_hero_who_never_knew_one_is_untouched() -> void:
	var cleric := TestChars.custom("cleric", "human", 9)
	var before := JSON.stringify((cleric.build["choices"] as Dictionary))
	assert_false(cleric.swap_removed_spells())
	assert_eq(JSON.stringify((cleric.build["choices"] as Dictionary)), before)
