extends TestCase
## The eight classes added in Phase 4 (P4-01): each is created through CharacterBuilder and levelled to 7 through
## LevelUpController without dead ends, and its level 7 sheet matches numbers worked out by hand from the 2024 PHB
## (Hit Points, slots, resources, choices). Also multiclassing into every class and Pact Magic kept apart from the
## Spellcasting slots, coming back on a Short Rest.

const NEW_CLASSES: Array[String] = ["barbarian", "bard", "druid", "monk", "paladin", "ranger", "sorcerer", "warlock"]


# --- helpers -------------------------------------------------------------------------------------

## Level 1 character: Standard Array scores as given, the background's increases as given, a human with Alert,
## and every other choice auto-picked (or set in `picks`).
func _create(cid: String, background: String, scores: Dictionary, increases: Array, picks: Dictionary = {}) -> Character:
	var b := CharacterBuilder.new()
	b.set_class(cid)
	b.set_background(background)
	b.set_species("human")
	b.set_name("Test %s" % cid)
	var values: Array = scores.values()
	values.sort()
	if values != [8, 10, 12, 13, 14, 15]:
		b.set_ability_method("manual")
	b.set_base_scores(scores)
	b.choose("background.abilities", increases)
	b.choose("species.versatile", ["alert"])
	for key: String in picks:
		assert_eq(b.choose(key, picks[key] as Array), [] as Array[String], "%s level 1 %s" % [cid, key])
	var stuck := TestChars.auto_pick(b.pending_choices, b.choose)
	assert_eq(stuck, [] as Array[String], "%s level 1 choices" % cid)
	var ch := b.build_character()
	assert_true(ch != null, "%s builds: %s" % [cid, b.errors()])
	return ch


## Levels `ch` in `cid` to `level` with fixed Hit Points. `picks` maps a class level to {choice key: picks}, applied
## in order; everything else is auto-picked.
func _level_to(ch: Character, cid: String, level: int, picks: Dictionary = {}) -> void:
	while ch.class_level_of(cid) < level:
		var up := LevelUpController.new(ch)
		if not up.choose_class(cid):
			fail("%s can't take another level" % cid)
			return
		up.take_fixed_hit_points()
		var n := ch.class_level_of(cid) + 1
		var mine := picks.get(n, {}) as Dictionary
		for key: String in mine:
			assert_eq(up.choose(key, mine[key] as Array), [] as Array[String], "%s %d %s" % [cid, n, key])
		var stuck := TestChars.auto_pick(up.pending_choices, up.choose)
		assert_eq(stuck, [] as Array[String], "%s level %d choices" % [cid, n])
		if not up.confirm():
			fail("%s level %d blocked: %s" % [cid, n, up.errors()])
			return


func _asi(cid: String, level: int, abilities: Array) -> Dictionary:
	var key := "%s.%d.ability_score_improvement" % [cid, level]
	return {key: ["ability_score_improvement"], "%s/ability_score_improvement.abilities" % key: abilities}


func _slots(listed: Array) -> Array[int]:
	var out: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0]
	for i in listed.size():
		out[i] = int(listed[i])
	return out


func _known(ch: Character, spell_id: String) -> Dictionary:
	for k in ch.known_spells():
		if str(k["id"]) == spell_id:
			return k
	return {}


func _has_feature(ch: Character, feature_id: String) -> bool:
	for f in ch.features:
		if str(f["id"]) == feature_id:
			return true
	return false


func _advantage(ch: Character, keys: Array[String]) -> bool:
	return not (ch.d20_sources(keys)["advantage"] as Array).is_empty()


func _profile(ch: Character, item_id: String) -> WeaponProfile:
	for p in ch.attacks():
		if p.item_id == item_id and not p.thrown:
			return p
	return null


# --- content -------------------------------------------------------------------------------------

func test_all_twelve_classes_and_their_subclasses_are_there() -> void:
	var c := Compendium.shared()
	for cid in NEW_CLASSES:
		var cls := c.class_data(cid)
		assert_false(cls.is_empty(), cid)
		assert_eq((cls["levels"] as Array).size(), 20, "%s levels" % cid)
		var phb := c.subclasses_of(cid).filter(func(s: Dictionary) -> bool: return str((s["source"] as Dictionary)["book"]) == "PHB2024")
		assert_eq(phb.size(), 4, "%s has its four PHB subclasses" % cid)
		for lv in 7:
			for f: Variant in ((cls["levels"] as Array)[lv] as Dictionary)["features"]:
				var fd := f as Dictionary
				assert_true(str(fd.get("text", "")) != "" or str(fd["id"]) in ["subclass_feature"], "%s %s has text" % [cid, fd["id"]])


# --- one test per class, level 1 to 7 ------------------------------------------------------------

func test_barbarian_berserker_to_level_7() -> void:
	var ch := _create("barbarian", "soldier", {"str": 15, "dex": 13, "con": 14, "int": 10, "wis": 12, "cha": 8},
		["str", "str", "con"])
	_level_to(ch, "barbarian", 7, {3: {"barbarian.3.barbarian_subclass": ["path_of_the_berserker"]},
		4: _asi("barbarian", 4, ["con", "con"])})
	assert_eq(ch.class_summary(), "Barbarian (Path of the Berserker) 7")
	assert_eq(ch.max_hp(), 75, "d12: 12 + 6 × 7, Con +3 × 7 (%s)" % ch.max_hp_breakdown().describe())
	assert_eq(ch.ac_value(), 14, "Unarmored Defense 10 + Dex 1 + Con 3 (%s)" % ch.armor_class().describe())
	assert_eq(ch.speed().total(), 40, "Fast Movement")
	assert_eq(ch.resource_max("rage"), 4)
	assert_eq(str((ch.resources["rage"] as Dictionary)["recharge"]), "short_one")
	assert_eq(ch.choice("barbarian.1.weapon_mastery").count, 3, "Weapon Mastery column at 7")
	assert_true(_advantage(ch, ch.save_keys(&"dex")), "Danger Sense")
	assert_true(_advantage(ch, ch.initiative_keys()), "Feral Instinct")
	assert_eq(str(ch.class_column("barbarian", "rage_damage")), "+2")
	assert_true(_has_feature(ch, "frenzy") and _has_feature(ch, "mindless_rage"), "Berserker 3 and 6")
	assert_eq(ch.spell_slots(), _slots([]), "no spellcasting")
	ch.add_condition(&"incapacitated", "test")
	assert_false(_advantage(ch, ch.save_keys(&"dex")), "no Danger Sense while Incapacitated")


func test_bard_lore_to_level_7() -> void:
	var ch := _create("bard", "entertainer", {"str": 8, "dex": 14, "con": 12, "int": 13, "wis": 10, "cha": 15},
		["cha", "cha", "dex"])
	_level_to(ch, "bard", 7, {3: {"bard.3.bard_subclass": ["college_of_lore"]},
		4: _asi("bard", 4, ["cha", "cha"]),
		6: {"college_of_lore.6.magical_discoveries": ["magic_missile", "guiding_bolt"]}})
	assert_eq(ch.max_hp(), 45, "d8: 8 + 6 × 5, Con +1 × 7")
	assert_eq(ch.spell_slots(), _slots([4, 3, 3, 1]))
	assert_eq(ch.choice("bard.cantrips").count, 3)
	assert_eq(ch.choice("bard.prepared").count, 11)
	assert_eq(ch.resource_max("bardic_inspiration"), 4, "Charisma 19")
	assert_eq(str((ch.resources["bardic_inspiration"] as Dictionary)["recharge"]), "short", "Font of Inspiration")
	assert_eq(str(ch.class_column("bard", "bardic_die")), "d8")
	assert_true(ch.choice("bard.2.expertise").is_complete())
	assert_eq(ch.choice("bard.1.tools").count, 3, "three Musical Instruments")
	assert_eq(ch.choice("college_of_lore.3.bonus_proficiencies").count, 3)
	var jack := false
	for skill: StringName in Abilities.SKILLS:
		if ch.skill_rank(skill) == 0:
			for p in ch.skill_bonus(skill).parts:
				if str(p["label"]) == "Jack of All Trades":
					jack = int(p["value"]) == 1
			break
	assert_true(jack, "Jack of All Trades adds half of PB 3")
	var mm := _known(ch, "magic_missile")
	assert_eq(str(mm.get("class_id", "")), "bard", "Magical Discoveries are Bard spells")
	assert_eq(ch.spell_save_dc("bard").total(), 15, "8 + Cha 4 + PB 3")


func test_druid_land_to_level_7() -> void:
	var ch := _create("druid", "sage", {"str": 8, "dex": 12, "con": 14, "int": 13, "wis": 15, "cha": 10},
		["wis", "wis", "con"])
	_level_to(ch, "druid", 7, {3: {"druid.3.druid_subclass": ["circle_of_the_land"],
			"circle_of_the_land.3.circle_of_the_land_spells": ["arid"]},
		4: _asi("druid", 4, ["con", "wis"]), 7: {"druid.7.elemental_fury": ["potent_spellcasting"]}})
	assert_eq(ch.max_hp(), 59, "d8: 8 + 6 × 5, Con +3 × 7")
	assert_eq(ch.spell_slots(), _slots([4, 3, 3, 1]))
	assert_eq(ch.resource_max("wild_shape"), 3)
	assert_eq(str((ch.resources["wild_shape"] as Dictionary)["recharge"]), "short_one")
	var forms := ch.choice("druid.2.wild_shape")
	assert_eq(forms.count, mini(6, ch.beast_forms_for(forms).size()), "six known forms at Druid 7, or every Beast there is")
	for f in ch.wild_shape_forms:
		var m := ch.compendium.monster_data(f)
		assert_eq(str(m["type"]), "beast")
		assert_true(float(m["cr"]) <= 0.5, "%s CR" % f)
	var fireball := _known(ch, "fireball")
	assert_eq(str(fireball.get("class_id", "")), "druid", "arid land gives Fireball at Druid 5")
	assert_true(_known(ch, "wall_of_stone").is_empty(), "Wall of Stone waits for Druid 9")
	assert_true(not _known(ch, "speak_with_animals").is_empty(), "Druidic")
	assert_true(ch.has_proficiency("languages", "druidic"))
	var thorn := ch.spell_preview("thorn_whip")
	assert_eq((thorn["damage_bonus"] as Breakdown).total(), 4, "Potent Spellcasting adds Wisdom 18")


func test_monk_open_hand_to_level_7() -> void:
	var ch := _create("monk", "guide", {"str": 12, "dex": 15, "con": 13, "int": 10, "wis": 14, "cha": 8},
		["dex", "dex", "wis"])
	_level_to(ch, "monk", 7, {3: {"monk.3.monk_subclass": ["warrior_of_the_open_hand"]},
		4: _asi("monk", 4, ["dex", "wis"])})
	assert_eq(ch.max_hp(), 45, "d8: 8 + 6 × 5, Con +1 × 7")
	assert_eq(ch.ac_value(), 17, "Unarmored Defense 10 + Dex 4 + Wis 3 (%s)" % ch.armor_class().describe())
	assert_eq(ch.speed().total(), 45, "Unarmored Movement +15 at Monk 6 (%s)" % ch.speed().describe())
	assert_eq(ch.resource_max("focus_points"), 7)
	assert_eq(str((ch.resources["focus_points"] as Dictionary)["recharge"]), "short")
	assert_eq(ch.resource_max("uncanny_metabolism"), 1)
	assert_eq(ch.resource_max("wholeness_of_body"), 3, "Wisdom 16")
	assert_true(ch.has_flag("evasion"))
	assert_true(ch.choice("monk.1.tools").is_complete())
	var fist := WeaponProfile.unarmed(ch)
	assert_eq(fist.damage_dice, "1d8", "Martial Arts die at Monk 5")
	assert_eq(fist.attack.total(), 7, "Dexterity 4 + PB 3")
	ch.add_item("shield")
	ch.equip("shield", "off_hand")
	assert_eq(WeaponProfile.unarmed(ch).damage_dice, "1", "no Martial Arts with a Shield")
	assert_eq(ch.speed().total(), 30, "no Unarmored Movement with a Shield")


func test_paladin_devotion_to_level_7() -> void:
	var ch := _create("paladin", "noble", {"str": 15, "dex": 10, "con": 13, "int": 8, "wis": 12, "cha": 14},
		["str", "cha", "cha"])
	_level_to(ch, "paladin", 7, {2: {"paladin.2.fighting_style": ["blessed_warrior"],
			"paladin.2.fighting_style/blessed_warrior": ["guidance", "sacred_flame"]},
		3: {"paladin.3.paladin_subclass": ["oath_of_devotion"]}, 4: _asi("paladin", 4, ["cha", "cha"])})
	assert_eq(ch.max_hp(), 53, "d10: 10 + 6 × 6, Con +1 × 7")
	assert_eq(ch.ac_value(), 18, "Chain Mail and Shield")
	assert_eq(ch.spell_slots(), _slots([4, 3]), "half caster 7 = caster level 4")
	assert_eq(ch.choice("paladin.prepared").count, 7)
	assert_eq(ch.resource_max("lay_on_hands"), 35)
	assert_eq(ch.resource_max("paladin_channel_divinity"), 2)
	assert_eq(ch.resource_max("spell:divine_smite"), 1, "Paladin's Smite")
	assert_eq(ch.resource_max("spell:find_steed"), 1, "Faithful Steed")
	var aura := 0
	for p in ch.save_bonus(&"str").parts:
		if str(p["label"]) == "Aura of Protection":
			aura = int(p["value"])
	assert_eq(aura, 4, "Aura of Protection adds Charisma 18")
	for s: String in ["protection_from_evil_and_good", "shield_of_faith", "aid", "zone_of_truth"]:
		assert_eq(str(_known(ch, s).get("kind", "")), "always", "Oath of Devotion: %s" % s)
	var flame := _known(ch, "sacred_flame")
	assert_eq(str(flame.get("class_id", "")), "paladin", "Blessed Warrior cantrips are Paladin spells")
	assert_eq(ch.spell_save_dc("paladin").total(), 15, "8 + Cha 4 + PB 3")
	assert_true(_has_feature(ch, "aura_of_devotion"))


func test_ranger_hunter_to_level_7() -> void:
	var ch := _create("ranger", "guide", {"str": 12, "dex": 15, "con": 13, "int": 8, "wis": 14, "cha": 10},
		["dex", "dex", "wis"])
	_level_to(ch, "ranger", 7, {2: {"ranger.2.fighting_style": ["archery"]},
		3: {"ranger.3.ranger_subclass": ["hunter"], "hunter.3.hunters_prey": ["colossus_slayer"]},
		4: _asi("ranger", 4, ["dex", "wis"])})
	assert_eq(ch.max_hp(), 53, "d10: 10 + 6 × 6, Con +1 × 7")
	assert_eq(ch.spell_slots(), _slots([4, 3]))
	assert_eq(ch.resource_max("spell:hunters_mark"), 3, "Favored Enemy column at 7")
	assert_eq(ch.speed().total(), 40, "Roving in light armor")
	assert_eq(ch.ac_value(), 16, "Studded Leather 12 + Dex 4")
	assert_eq(_profile(ch, "longbow").attack.total(), 9, "Dex 4 + PB 3 + Archery 2")
	assert_eq(ch.choice("ranger.2.deft_explorer.expertise").count, 1)
	assert_eq(ch.choice("ranger.2.deft_explorer.languages").count, 2)
	assert_eq(ch.choice("ranger.1.weapon_mastery").count, 2)
	assert_eq(str(_known(ch, "hunters_mark").get("class_id", "")), "ranger")


func test_sorcerer_draconic_to_level_7() -> void:
	var ch := _create("sorcerer", "noble", {"str": 10, "dex": 13, "con": 14, "int": 8, "wis": 12, "cha": 15},
		["cha", "cha", "str"])
	_level_to(ch, "sorcerer", 7, {3: {"sorcerer.3.sorcerer_subclass": ["draconic_sorcery"]},
		4: _asi("sorcerer", 4, ["cha", "cha"]), 6: {"draconic_sorcery.6.elemental_affinity": ["fire"]}})
	assert_eq(ch.max_hp(), 51, "d6: 6 + 6 × 4, Con +2 × 7, Draconic Resilience +7 (%s)" % ch.max_hp_breakdown().describe())
	assert_eq(ch.ac_value(), 15, "Draconic Resilience 10 + Dex 1 + Cha 4")
	assert_eq(ch.spell_slots(), _slots([4, 3, 3, 1]))
	assert_eq(ch.resource_max("sorcery_points"), 7)
	assert_eq(ch.resource_max("innate_sorcery"), 2)
	assert_eq(ch.resource_max("sorcerous_restoration"), 1)
	assert_eq(ch.choice("sorcerer.2.metamagic").count, 2)
	assert_eq(ch.metamagic.size(), 2)
	assert_eq(ch.choice("sorcerer.cantrips").count, 5)
	assert_eq(ch.choice("sorcerer.prepared").count, 11)
	assert_ne(ch.resistance_source(&"fire"), "", "Elemental Affinity: fire")
	assert_eq((ch.spell_preview("fire_bolt")["damage_bonus"] as Breakdown).total(), 4, "Charisma on fire spells")
	assert_eq((ch.spell_preview("ray_of_frost")["damage_bonus"] as Breakdown).total(), 0, "not on cold spells")


func test_warlock_fiend_to_level_7_with_pact_magic() -> void:
	var ch := _create("warlock", "charlatan", {"str": 8, "dex": 14, "con": 13, "int": 12, "wis": 10, "cha": 15},
		["cha", "cha", "con"], {"warlock.1.eldritch_invocations": ["pact_of_the_blade"],
			"warlock.cantrips": ["chill_touch", "mind_sliver"]})
	var inv := ch.choice("warlock.1.eldritch_invocations")
	ChoiceOptions.populate(inv, ch)
	assert_eq(inv.option("agonizing_blast").reason, "Requires Warlock level 2")
	assert_eq(ch.pact_magic()["count"], 1)
	_level_to(ch, "warlock", 7, {
		2: {"warlock.1.eldritch_invocations": ["pact_of_the_blade", "agonizing_blast", "eldritch_mind"],
			"warlock.1.eldritch_invocations/agonizing_blast": ["chill_touch"]},
		3: {"warlock.3.warlock_subclass": ["fiend_patron"]}, 4: _asi("warlock", 4, ["cha", "cha"]),
		5: {"warlock.1.eldritch_invocations": ["pact_of_the_blade", "agonizing_blast", "eldritch_mind",
			"thirsting_blade", "devils_sight"]},
		7: {"warlock.1.eldritch_invocations": ["pact_of_the_blade", "agonizing_blast", "eldritch_mind",
			"thirsting_blade", "devils_sight", "whispers_of_the_grave"]}})
	assert_eq(ch.max_hp(), 52, "d8: 8 + 6 × 5, Con +2 × 7")
	assert_eq(ch.spellcasting_slots(), _slots([]), "Pact Magic isn't Spellcasting")
	assert_eq(ch.pact_magic()["count"], 2)
	assert_eq(ch.pact_magic()["level"], 4)
	assert_eq(ch.spell_slots(), _slots([0, 0, 0, 2]), "both slots cast at level 4")
	assert_eq(ch.choice("warlock.1.eldritch_invocations").count, 6)
	assert_eq(ch.choice("warlock.cantrips").count, 3)
	assert_eq(ch.choice("warlock.prepared").count, 8)
	assert_eq(ch.resource_max("magical_cunning"), 1)
	assert_eq(ch.resource_max("dark_ones_own_luck"), 4)
	assert_eq((ch.spell_preview("chill_touch")["damage_bonus"] as Breakdown).total(), 4, "Agonizing Blast on Chill Touch")
	assert_eq((ch.spell_preview("mind_sliver")["damage_bonus"] as Breakdown).total(), 0, "only the chosen cantrip")
	assert_true(not _known(ch, "speak_with_dead").is_empty(), "Whispers of the Grave")
	for s: String in ["burning_hands", "command", "scorching_ray", "suggestion", "fireball", "stinking_cloud"]:
		assert_eq(str(_known(ch, s).get("kind", "")), "always", "Fiend spell %s" % s)
	var prepared := ch.choice("warlock.prepared")
	ChoiceOptions.populate(prepared, ch)
	assert_true(prepared.option("counterspell").legal, "level 3 spells fit a level 4 Pact slot")
	# Pact Magic slots come back on a Short Rest.
	assert_true(ch.expend_slot(4))
	assert_true(ch.expend_slot(4))
	assert_eq(ch.slots_left(4), 0)
	assert_false(ch.expend_slot(4), "no third slot")
	ch.finish_short_rest()
	assert_eq(ch.slots_left(4), 2, "Short Rest restores Pact Magic")
	ch.expend_slot(4)
	var saved := Character.from_dict(ch.to_dict())
	assert_eq(saved.slots_left(4), 1, "spent Pact slots are saved")


func test_invocation_prerequisites_explain_themselves() -> void:
	var ch := _create("warlock", "charlatan", {"str": 8, "dex": 14, "con": 13, "int": 12, "wis": 10, "cha": 15},
		["cha", "cha", "con"], {"warlock.1.eldritch_invocations": ["armor_of_shadows"]})
	_level_to(ch, "warlock", 5, {2: {"warlock.1.eldritch_invocations": ["armor_of_shadows", "eldritch_mind",
		"pact_of_the_chain"]}, 3: {"warlock.3.warlock_subclass": ["archfey_patron"]}})
	var inv := ch.choice("warlock.1.eldritch_invocations")
	ChoiceOptions.populate(inv, ch)
	assert_eq(inv.option("thirsting_blade").reason, "Requires Pact of the Blade")
	assert_true(inv.option("investment_of_the_chain_master").legal, "Pact of the Chain is picked")
	assert_eq(inv.option("lifedrinker").reason, "Requires Warlock level 9")
	assert_true(inv.option("ascendant_step").legal)
	assert_eq(ch.resource_max("spell:misty_step"), 3, "Steps of the Fey: Charisma 17")


# --- multiclassing -------------------------------------------------------------------------------

func _all_thirteens(cid: String) -> Character:
	return _create(cid, "sage", {"str": 13, "dex": 13, "con": 13, "int": 13, "wis": 13, "cha": 13}, ["con", "int", "wis"])


func test_multiclass_proficiencies_for_every_new_class() -> void:
	var wiz := _all_thirteens("wizard")
	var want := {
		"barbarian": {"armor": ["shields"], "weapons": ["martial"], "skills": 0, "tools": 0},
		"bard": {"armor": ["light"], "weapons": [], "skills": 1, "tools": 1},
		"druid": {"armor": ["light", "shields"], "weapons": [], "skills": 0, "tools": 0},
		"monk": {"armor": [], "weapons": [], "skills": 0, "tools": 0},
		"paladin": {"armor": ["light", "medium", "shields"], "weapons": ["martial"], "skills": 0, "tools": 0},
		"ranger": {"armor": ["light", "medium", "shields"], "weapons": ["martial"], "skills": 1, "tools": 0},
		"sorcerer": {"armor": [], "weapons": [], "skills": 0, "tools": 0},
		"warlock": {"armor": ["light"], "weapons": [], "skills": 0, "tools": 0},
	}
	for cid: String in want:
		var w := want[cid] as Dictionary
		var up := LevelUpController.new(wiz)
		assert_true(up.choose_class(cid), "%s with 13s everywhere" % cid)
		var after := up.preview()
		for a: String in ["light", "medium", "heavy", "shields"]:
			assert_eq(after.has_proficiency("armor", a), a in (w["armor"] as Array), "%s armor %s" % [cid, a])
		assert_eq(after.has_proficiency("weapons", "martial"), "martial" in (w["weapons"] as Array), "%s martial" % cid)
		var skills := after.choice("%s.1.skills" % cid)
		assert_eq(skills.count if skills != null else 0, int(w["skills"]), "%s skill picks" % cid)
		var tools := after.choice("%s.1.tools" % cid)
		assert_eq(tools.count if tools != null else 0, int(w["tools"]), "%s tool picks" % cid)
		var saves := Compendium.shared().class_data(cid)["saving_throws"] as Array
		for ab: Variant in saves:
			if not str(ab) in ["int", "wis"]:
				assert_eq(after.save_proficiency(StringName(str(ab))), "", "%s gives no saving throws when multiclassing" % cid)
		var die := int(Compendium.shared().class_data(cid)["hit_die"])
		assert_eq(int(up.hit_point_options()["fixed"]), die / 2 + 1, "%s fixed Hit Points" % cid)
		assert_true(TestChars.auto_pick(up.pending_choices, up.choose).is_empty(), "%s level 1 as a multiclass" % cid)
		assert_true(up.errors().is_empty(), "%s: %s" % [cid, up.errors()])


func test_multiclass_prerequisites_name_every_missing_score() -> void:
	var ilse := TestChars.pregen("ilse_varga", 2)
	var up := LevelUpController.new(ilse)
	var by_id := {}
	for o in up.available_classes():
		by_id[o.id] = o
	assert_true((by_id["barbarian"] as ChoiceOption).legal, "Strength 17")
	assert_eq((by_id["monk"] as ChoiceOption).reason, "Monk needs Wisdom 13 (you have 10)")
	assert_eq((by_id["paladin"] as ChoiceOption).reason, "Paladin needs Charisma 13 (you have 12)")
	assert_eq((by_id["ranger"] as ChoiceOption).reason, "Ranger needs Wisdom 13 (you have 10)")
	for cid: String in ["bard", "sorcerer", "warlock"]:
		assert_eq((by_id[cid] as ChoiceOption).reason, "%s needs Charisma 13 (you have 12)" % cid.capitalize())
	assert_eq((by_id["druid"] as ChoiceOption).reason, "Druid needs Wisdom 13 (you have 10)")


func test_pact_magic_stays_apart_from_multiclass_spell_slots() -> void:
	var ch := _create("warlock", "noble", {"str": 13, "dex": 10, "con": 14, "int": 8, "wis": 12, "cha": 15},
		["cha", "str", "str"], {"warlock.1.eldritch_invocations": ["pact_of_the_blade"]})
	var first := LevelUpController.new(ch)
	first.choose_class("warlock")
	var rows := {}
	for r in first.changes():
		rows[str(r["label"])] = r
	assert_eq(str((rows["Pact Magic slots"] as Dictionary)["before"]), "1 × level 1")
	assert_eq(str((rows["Pact Magic slots"] as Dictionary)["after"]), "2 × level 1", "the level-up summary shows Pact Magic")
	_level_to(ch, "warlock", 3, {3: {"warlock.3.warlock_subclass": ["celestial_patron"]}})
	_level_to(ch, "paladin", 2)
	assert_eq(ch.class_summary(), "Warlock (Celestial Patron) 3 / Paladin 2")
	assert_eq(ch.spellcasting_slots(), _slots([2]), "Paladin 2 alone: caster level 1")
	assert_eq(ch.pact_magic()["count"], 2)
	assert_eq(ch.pact_magic()["level"], 2)
	assert_eq(ch.spell_slots(), _slots([2, 2]))
	assert_true(ch.expend_slot(2), "a level 2 cast uses a Pact slot")
	assert_true(ch.expend_slot(1), "a level 1 cast uses a Paladin slot")
	assert_eq([ch.slots_left(1), ch.slots_left(2)], [1, 1])
	ch.finish_short_rest()
	assert_eq([ch.slots_left(1), ch.slots_left(2)], [1, 2], "Short Rest: Pact slots only")
	ch.finish_long_rest()
	assert_eq([ch.slots_left(1), ch.slots_left(2)], [2, 2])
	var pal := ch.choice("paladin.prepared")
	ChoiceOptions.populate(pal, ch)
	assert_false(pal.option("aid").legal if pal.option("aid") != null else false, "Paladin prepares as a Paladin 2: level 1 only")
	var war := ch.choice("warlock.prepared")
	ChoiceOptions.populate(war, ch)
	assert_true(war.option("misty_step").legal, "Warlock 3 prepares level 2 spells")
	var up := LevelUpController.new(ch)
	up.choose_class("warlock")
	var labels: Array = up.changes().map(func(r: Dictionary) -> String: return str(r["label"]))
	assert_false("Pact Magic slots" in labels, "Warlock 4 keeps two level 2 slots: %s" % [labels])


func test_spellcasting_classes_combine_slots() -> void:
	var slots := Spellcasting.slots_for([{"progression": "full", "level": 3}, {"progression": "half", "level": 3}])
	assert_eq(slots, _slots([4, 3, 2]), "Druid 3 + Paladin 3: 3 + 2 = caster level 5")
	slots = Spellcasting.slots_for([{"progression": "half", "level": 5}, {"progression": "half", "level": 1}])
	assert_eq(slots, _slots([4, 3]), "Ranger 5 + Paladin 1: 3 + 1 = 4")
	slots = Spellcasting.slots_for([{"progression": "pact", "level": 5}, {"progression": "full", "level": 1}])
	assert_eq(slots, _slots([2]), "Pact Magic adds nothing to the caster level")
	var ch := _create("druid", "sage", {"str": 8, "dex": 13, "con": 14, "int": 12, "wis": 15, "cha": 10}, ["wis", "wis", "con"])
	ch.build["base_scores"]["dex"] = 13
	_level_to(ch, "druid", 2)
	_level_to(ch, "ranger", 2)
	assert_eq(ch.class_summary(), "Druid 2 / Ranger 2")
	assert_eq(ch.spell_slots(), _slots([4, 2]), "2 + 1 = caster level 3")
	assert_eq(ch.spellcasting.size(), 2, "two Spellcasting features with their own lists")


func test_attunement_limits_and_item_modifiers() -> void:
	var c := Compendium.shared()
	for i in 4:
		c.tables["magic_items"]["test_ring_%d" % i] = {"id": "test_ring_%d" % i, "name": "Ring %d" % i, "category": "ring",
			"magic": {"rarity": "rare", "attunement": true}, "modifiers": [{"stat": "ac", "value": 1}]}
	c.tables["magic_items"]["test_charm"] = {"id": "test_charm", "name": "Charm", "category": "wondrous",
		"magic": {"rarity": "uncommon", "attunement": "by a cleric"}, "modifiers": [{"stat": "ac", "value": 1}]}
	var ilse := TestChars.pregen("ilse_varga", 3)
	var ac := ilse.ac_value()
	for i in 4:
		ilse.add_item("test_ring_%d" % i, 1)
	assert_eq(ilse.ac_value(), ac, "unattuned rings do nothing")
	assert_true(ilse.attune("test_ring_0"))
	assert_eq(ilse.ac_value(), ac + 1)
	assert_true(ilse.attune("test_ring_1"))
	assert_true(ilse.attune("test_ring_2"))
	assert_eq(ilse.attune_blocker("test_ring_3"), "Already attuned to three items")
	ilse.add_item("test_charm", 1)
	ilse.end_attunement("test_ring_2")
	assert_true(ilse.attune_blocker("test_charm").begins_with("Requires attunement"), "a fighter isn't a cleric")
	var copy := Character.from_dict(JSON.parse_string(JSON.stringify(ilse.to_dict())) as Dictionary)
	assert_eq(copy.attuned.size(), 2, "attunement is saved")
	assert_eq(copy.ac_value(), ac + 2)
	for i in 4:
		c.tables["magic_items"].erase("test_ring_%d" % i)
	c.tables["magic_items"].erase("test_charm")
