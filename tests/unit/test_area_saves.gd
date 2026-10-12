extends TestCase
## The area spell's saves for the panel at the top left (owner, 2026-10-12): every creature caught with its chance to
## save, the damage it can expect, friend or foe, and those Sculpt Spells would shield marked safe.


func _evoker(e: Encounter, cell: Vector2i, wizard_subclass: String) -> Combatant:
	var ch := TestChars.custom("wizard", "human", 7, {"wizard_subclass": [wizard_subclass]})
	var prepared := (ch.spellcasting[0] as Dictionary)["prepared"] as Array
	if not "fireball" in prepared:
		prepared.append("fireball")
	ch.finish_long_rest()
	return e.add(ch, &"party", cell)


func _rows_by_id(pv: Dictionary) -> Dictionary:
	var out := {}
	for r: Dictionary in pv["creatures"]:
		out[str(r["id"])] = r
	return out


func test_each_creature_caught_has_its_chance_to_save() -> void:
	var e := TestCombat.open_field()
	var c := _evoker(e, Vector2i(1, 1), "abjurer")
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(5, 2))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3))
	TestCombat.start_with(e, c)
	var cat := ActionCatalog.new(e)
	var pv := cat.spell_preview(c, cat.find(c, "spell:fireball"), Vector2(5.5, 3.5), Vector2.ZERO)
	assert_eq(str(pv["save"]), "Dex", "the save for the header")
	assert_true(int(pv["dc"]) > 10)
	var rows := _rows_by_id(pv)
	assert_true(rows.has(ally.id) and rows.has(foe.id), "both caught")
	var fr := rows[foe.id] as Dictionary
	assert_false(bool(fr["ally"]))
	assert_between(float(fr["save_chance"]), 0.0, 1.0)
	assert_true(int(fr["damage"]) > 0, "the damage it can expect")
	assert_true(bool((rows[ally.id] as Dictionary)["ally"]), "a friend is marked")
	assert_false(bool((rows[ally.id] as Dictionary)["safe"]), "no Sculpt Spells for an Abjurer")
	assert_true((pv["warnings"] as Array).any(func(w: String) -> bool: return w.contains("Friendly fire")))


func test_sculpt_spells_marks_who_it_would_shield() -> void:
	var e := TestCombat.open_field()
	var c := _evoker(e, Vector2i(1, 1), "evoker")
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(5, 2))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3))
	TestCombat.start_with(e, c)
	var cat := ActionCatalog.new(e)
	var pv := cat.spell_preview(c, cat.find(c, "spell:fireball"), Vector2(5.5, 3.5), Vector2.ZERO)
	var rows := _rows_by_id(pv)
	assert_true(bool((rows[ally.id] as Dictionary)["safe"]), "the ally Sculpt Spells would shield")
	assert_false(bool((rows[foe.id] as Dictionary)["safe"]), "never the foe")
	assert_false((pv["warnings"] as Array).any(func(w: String) -> bool: return w.contains("Friendly fire")), "no friendly fire to warn of")
