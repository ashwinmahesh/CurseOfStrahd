extends TestCase
## Item cheat codes (story/cheat_codes.gd, owner 2026-10-08): six hex digits per item that stay put as items are added,
## only playable items answering, an item built on a base given as the base the player picks, and a code that works as
## often as the player likes. tools/data/cheat_codes.py pins the same three codes, so Cheat Codes.md and the game agree.

const PINNED := {"arrow": "359A02", "sunsword": "68D169", "weapon_plus_1": "3360D9"}


func after_each() -> void:
	CheatCodes.reset()


func _hero() -> Character:
	return TestChars.pregen("ilse_varga", 1)


func _all_ids() -> Array[String]:
	var ids: Array[String] = []
	for folder in CheatCodes.FOLDERS:
		for id: Variant in Compendium.shared().table(folder):
			ids.append(str(id))
	return ids


func test_the_codes_match_the_vault_list() -> void:
	for id: String in PINNED:
		assert_eq(CheatCodes.code_of(id), str(PINNED[id]), "%s's code (tools/data/cheat_codes.py pins it too)" % id)


func test_every_item_has_its_own_six_hex_digits() -> void:
	var seen := {}
	for id in _all_ids():
		var code := CheatCodes.code_of(id)
		assert_eq(code.length(), CheatCodes.LENGTH, "%s's code is six long" % id)
		assert_eq(CheatCodes.normalise(code), code, "%s's code is hex in upper case" % id)
		assert_false(seen.has(code), "%s shares %s with %s" % [id, code, seen.get(code, "")])
		seen[code] = id


func test_every_playable_item_answers_to_its_code() -> void:
	var listed := CheatCodes.entries()
	var playable := 0
	for folder in CheatCodes.FOLDERS:
		playable += Compendium.shared().all_playable(folder).size()
	assert_eq(listed.size(), playable, "every playable item is listed")
	for e in listed:
		assert_eq(CheatCodes.item_for(str(e["code"])), str(e["id"]), "%s answers to %s" % [e["id"], e["code"]])


func test_items_that_arent_playable_dont_answer() -> void:
	var hidden := Compendium.shared().all("magic_items").filter(func(d: Dictionary) -> bool: return not Compendium.playable(d))
	assert_true(not hidden.is_empty(), "the data has items on hold to check")
	for d: Dictionary in hidden:
		var code := CheatCodes.code_of(str(d["id"]))
		assert_ne(code, "", "%s still has a code, kept for when it's switched on" % d["id"])
		assert_eq(CheatCodes.item_for(code), "", "%s isn't given while it's on hold" % d["id"])


func test_typing_is_forgiving() -> void:
	assert_eq(CheatCodes.item_for("359a02"), "arrow", "lower case")
	assert_eq(CheatCodes.item_for(" #359 A0-2 "), "arrow", "spaces, a hash and a dash")
	assert_eq(CheatCodes.item_for("359A0"), "", "five digits name nothing")
	var unused := ""
	for i in 100:
		var c := "%06X" % i
		if CheatCodes.item_for(c) == "":
			unused = c
			break
	assert_eq(CheatCodes.item_for(unused), "", "a code no item has")


## Thousands of made-up ids are sure to share a few codes; each clash goes to the id that sorts first, and the codes
## already given never move when more ids arrive.
func test_clashes_settle_in_id_order_and_codes_stay_put() -> void:
	var ids: Array[String] = []
	for i in 20000:
		ids.append("made_up_%d" % i)
	var codes := CheatCodes.assign(ids)
	var by_code := {}
	for id: String in codes:
		assert_false(by_code.has(codes[id]), "%s's code is its own" % id)
		by_code[codes[id]] = id
	var clashes := 0
	for id: String in codes:
		var first := CheatCodes.hash_code(id)
		if str(codes[id]) != first:
			clashes += 1
			assert_true(str(by_code[first]) < id, "%s lost %s to %s, which sorts first" % [id, first, by_code[first]])
	assert_true(clashes > 0, "20000 ids share at least one code (else this test checks nothing)")
	var real := _all_ids()
	var before := CheatCodes.assign(real)
	var more: Array[String] = real.duplicate()
	more.append_array(["zz_new_dagger", "aa_new_amulet", "new_potion_of_haste"])
	var after := CheatCodes.assign(more)
	for id in real:
		assert_eq(after[id], before[id], "%s keeps its code when items are added" % id)


func test_a_code_gives_as_often_as_you_like() -> void:
	var ch := _hero()
	var before := ch.entry_of("arrow").get("qty", 0) as int
	assert_eq(CheatCodes.give(ch, CheatCodes.item_for(PINNED["arrow"])), 20, "a bundle of arrows")
	assert_eq(CheatCodes.give(ch, "arrow"), 20, "and again")
	assert_eq(int(ch.entry_of("arrow")["qty"]), before + 40)
	assert_eq(CheatCodes.give(ch, "sunsword"), 1)
	assert_eq(CheatCodes.give(ch, "sunsword"), 1)
	assert_eq(ch.inventory.filter(func(e: Dictionary) -> bool: return str(e["id"]) == "sunsword").size(), 2, "two Sunswords")
	assert_eq(CheatCodes.give(ch, "no_such_item"), 0)
	assert_eq(CheatCodes.give(null, "arrow"), 0)


func test_a_magic_item_arrives_identified() -> void:
	var ch := _hero()
	for id: String in ["dust_of_sneezing_and_choking", "armor_of_vulnerability_slashing__plate_armor"]:
		assert_eq(CheatCodes.give(ch, id), 1, id)
		var d := Compendium.shared().item_data(id)
		assert_true(bool(ch.entry_of(id).get("identified", false)), "%s is identified" % id)
		assert_eq(MagicItems.display_name(d, ch.entry_of(id)), str(d["name"]), "%s shows what it really is" % id)


func test_an_item_built_on_a_base_asks_which() -> void:
	assert_eq(CheatCodes.base_word("weapon_plus_1"), "Weapon")
	var swords := CheatCodes.choices("weapon_plus_1")
	assert_true("weapon_plus_1__longsword" in swords, "a +1 Longsword is on offer")
	assert_false("weapon_plus_1__plate_armor" in swords, "armor isn't")
	assert_eq(CheatCodes.default_choice("weapon_plus_1"), "weapon_plus_1__longsword", "the template's default first")
	assert_eq(CheatCodes.choice_name("weapon_plus_1__longsword"), "Longsword")
	var ch := _hero()
	assert_eq(CheatCodes.give(ch, "weapon_plus_1"), 0, "a template alone isn't an item")
	assert_eq(CheatCodes.give(ch, "weapon_plus_1__longsword"), 1)
	assert_true(ch.carries("weapon_plus_1__longsword"), "the +1 Longsword is in the pack")
	var scrolls := CheatCodes.choices("spell_scroll")
	assert_eq(CheatCodes.base_word("spell_scroll"), "Spell")
	assert_true("spell_scroll__fireball" in scrolls, "a scroll of any playable spell")
	assert_eq(CheatCodes.choice_name("spell_scroll__fireball"), "Fireball (level 3)")
	assert_eq(int(Compendium.shared().spell_data(scrolls[0].get_slice(MagicItems.SEP, 1)).get("level", -1)), 0, "cantrips first")
	for v in scrolls:
		assert_true(Compendium.playable(Compendium.shared().spell_data(v.get_slice(MagicItems.SEP, 1))), "%s is a playable spell" % v)
	assert_eq(CheatCodes.choices("armor_of_vulnerability_slashing"), ["armor_of_vulnerability_slashing__plate_armor"] as Array[String],
		"an item with one base has nothing to pick")
	assert_eq(CheatCodes.choices("arrow"), [] as Array[String], "a plain item has no base")
	assert_eq(CheatCodes.default_choice("arrow"), "")
