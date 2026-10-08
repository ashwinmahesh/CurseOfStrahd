extends TestCase
## A reward that names only a template ("give dragon_scale_mail_silver", a rack holding "dragon_slayer") is that
## template on its default base (MagicItems.concrete, in Character.add_item): a real weapon or armour that equips and
## works. Before, it went into the pack as the bare template, and wearing it broke the wearer's AC.


func _comp() -> Compendium:
	return Compendium.shared()


func test_the_warm_snows_rewards_equip_and_work() -> void:
	var ch := TestChars.pregen("ilse_varga", 9)
	ch.add_item("dragon_scale_mail_silver")
	assert_true(ch.carries("dragon_scale_mail_silver__scale_mail"), "the mail is scale mail")
	assert_true(ch.equip("dragon_scale_mail_silver__scale_mail", "armor"))
	assert_true(ch.ac_value() >= 15, "scale mail's AC plus its +1, not a broken 0: %d" % ch.ac_value())
	ch.add_item("dragon_slayer")
	assert_true(ch.carries("dragon_slayer__longsword"), "the Dragon Slayer is a longsword")
	assert_true(ch.equip("dragon_slayer__longsword", "main_hand"))
	assert_eq(str(ch.equipped("main_hand").get("base_item", "")), "longsword")


func test_concrete_picks_the_default_the_only_base_or_a_shield() -> void:
	assert_eq(MagicItems.concrete("weapon_plus_1", _comp()), "weapon_plus_1__longsword", "its default")
	assert_eq(MagicItems.concrete("staff_of_frost", _comp()), "staff_of_frost__quarterstaff", "its only base")
	assert_eq(MagicItems.concrete("elven_chain", _comp()), "elven_chain__chain_shirt")
	assert_eq(MagicItems.concrete("arrow_catching_shield", _comp()), "arrow_catching_shield__shield", "a shield")
	assert_eq(MagicItems.concrete("weapon_plus_1__dagger", _comp()), "weapon_plus_1__dagger", "a base already named")
	assert_eq(MagicItems.concrete("potion_of_healing", _comp()), "potion_of_healing", "not a template")
	assert_eq(MagicItems.concrete("spell_scroll", _comp()), "spell_scroll", "a scroll's template has no default spell")


## Every template a conversation gives or a place holds on its own turns into a real weapon, armour or shield.
func test_every_bare_template_reward_becomes_a_real_item() -> void:
	var given: Array[String] = []
	var re := RegEx.create_from_string("^\\s*give\\s+([a-z0-9_]+)")
	for path in _dialogue_files("res://narrative"):
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var m := re.search(line)
			if m != null:
				given.append(m.get_string(1))
	for loc: Dictionary in _comp().all("locations"):
		for c: Variant in loc.get("containers", []):
			for it: Variant in (c as Dictionary).get("items", []):
				given.append(str((it as Dictionary)["id"]))
		for p: Variant in loc.get("props", []):
			if (p as Dictionary).has("item"):
				given.append(str((p as Dictionary)["item"]))
	var n := 0
	for id in given:
		var data := _comp().item_data(id)
		if not MagicItems.is_template(data) or str((data["template"] as Dictionary).get("on", "")) == "spell":
			continue
		n += 1
		var real := _comp().item_data(MagicItems.concrete(id, _comp()))
		assert_true(real.has("weapon") or real.has("armor") or str(real.get("category", "")) == "shield",
			"%s becomes a real item (%s)" % [id, MagicItems.concrete(id, _comp())])
	assert_true(n >= 2, "the Warm Snow's two at least (%d)" % n)


func _dialogue_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".dialogue"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_dialogue_files(dir.path_join(d)))
	return out
