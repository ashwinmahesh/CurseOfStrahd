extends TestCase
## Phase 1 exit test (plan §10): build the four pregenerated characters through CharacterBuilder, level them
## to 5 with LevelUpController, and compare every number with the hand-worked sheets in
## docs/rules/reference_party.md (tests/fixtures/reference_party.json).

const FIXTURE := "res://tests/fixtures/reference_party.json"
const PARTY: Array[String] = ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]

var reference: Dictionary


func before_each() -> void:
	reference = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE)) as Dictionary


func test_fighter_levels_1_to_5_match_the_hand_worked_sheet() -> void:
	_check_character("ilse_varga")


func test_rogue_levels_1_to_5_match_the_hand_worked_sheet() -> void:
	_check_character("tamsin_tealeaf")


func test_cleric_levels_1_to_5_match_the_hand_worked_sheet() -> void:
	_check_character("hedda_ironvow")


func test_wizard_levels_1_to_5_match_the_hand_worked_sheet() -> void:
	_check_character("silvain_aster")


func test_cleric_multiclass_options_at_level_5() -> void:
	var ch := _level_to("hedda_ironvow", 5)
	var up := LevelUpController.new(ch)
	var by_id := {}
	for o in up.available_classes():
		by_id[o.id] = o
	assert_true((by_id["fighter"] as ChoiceOption).legal, "Strength 14 meets Fighter's Str or Dex 13: %s" % (by_id["fighter"] as ChoiceOption).reason)
	assert_false((by_id["wizard"] as ChoiceOption).legal, "Intelligence 10 can't multiclass into Wizard")
	assert_true((by_id["wizard"] as ChoiceOption).reason.contains("Intelligence 13 (you have 10)"), (by_id["wizard"] as ChoiceOption).reason)
	assert_true((by_id["cleric"] as ChoiceOption).legal)
	# The Phase 4 classes: Strength 14, Dexterity 8, Wisdom 18 and Charisma 13 decide them.
	for cid: String in ["barbarian", "bard", "druid", "paladin", "sorcerer", "warlock"]:
		assert_true((by_id[cid] as ChoiceOption).legal, "%s: %s" % [cid, (by_id[cid] as ChoiceOption).reason])
	assert_eq((by_id["monk"] as ChoiceOption).reason, "Monk needs Dexterity 13 (you have 8)")
	assert_eq((by_id["ranger"] as ChoiceOption).reason, "Ranger needs Dexterity 13 (you have 8)")
	# Taking Paladin: armor and Martial weapons she lacks, no new saves, and its half-caster slots join hers.
	assert_true(up.choose_class("paladin"))
	var after := up.preview()
	assert_eq(after.class_summary(), "Cleric (Life Domain) 5 / Paladin 1")
	assert_true(after.has_proficiency("weapons", "martial"), "multiclass Paladin: Martial weapons")
	assert_eq(after.save_proficiency(&"str"), "", "no Paladin saving throws")
	assert_eq(after.spell_slots(), [4, 3, 3, 0, 0, 0, 0, 0, 0] as Array[int], "Cleric 5 + Paladin 1 halved, rounded up = caster level 6")


func test_party_builds_without_errors_or_unexpected_warnings() -> void:
	for id in PARTY:
		var pregen := Compendium.shared().get_entry("pregens", id)
		var builder := CharacterBuilder.new(null, pregen["build"] as Dictionary)
		assert_eq(builder.errors(), [] as Array[String], "%s level 1 build errors" % id)
		assert_true(builder.build_character() != null, "%s builds" % id)


func test_party_coverage_names_gaps() -> void:
	var party: Array[Character] = []
	for id in PARTY:
		party.append(_level_to(id, 1))
	var cov := PartyCoverage.analyze(party)
	assert_true("Hedda Ironvow" in ((cov["roles"] as Dictionary)["healing"] as Array), "the cleric heals")
	assert_true("Silvain Aster" in ((cov["roles"] as Dictionary)["arcane"] as Array), "the wizard is arcane")
	assert_true("Ilse Varga" in ((cov["roles"] as Dictionary)["front_line"] as Array), "the fighter holds the line")
	assert_true((cov["damage_types"] as Dictionary).has("radiant"), "Sacred Flame and Toll the Dead cover radiant/necrotic")
	var dark := cov["darkvision"] as Array
	assert_eq(dark.size(), 2, "the dwarf and the elf see in the dark")


# --- helpers -------------------------------------------------------------------------------------

func _level_to(id: String, level: int) -> Character:
	var pregen := Compendium.shared().get_entry("pregens", id)
	var builder := CharacterBuilder.new(null, pregen["build"] as Dictionary)
	var ch := builder.build_character()
	if ch == null:
		fail("%s: level 1 build has errors: %s" % [id, builder.errors()])
		return null
	for step: Variant in pregen["level_plan"]:
		var plan := step as Dictionary
		if int(plan["level"]) > level:
			break
		var up := LevelUpController.new(ch)
		if not up.choose_class(str(plan["class"])):
			fail("%s level %d: can't choose %s" % [id, plan["level"], plan["class"]])
			return ch
		if int(plan.get("hp", 0)) > 0:
			((up.build["levels"] as Array).back() as Dictionary)["hp"] = int(plan["hp"])
		else:
			up.take_fixed_hit_points()
		var choices := plan.get("choices", {}) as Dictionary
		for key: String in choices:
			up.choose(key, choices[key] as Array)
		if not up.confirm():
			fail("%s level %d: level-up blocked: %s" % [id, plan["level"], up.errors()])
			return ch
	return ch


func _check_character(id: String) -> void:
	var sheets := reference[id] as Dictionary
	for level in range(1, 6):
		var ch := _level_to(id, level)
		if ch == null:
			return
		assert_eq(ch.character_level(), level, "%s level" % id)
		_check_level(ch, sheets[str(level)] as Dictionary, "%s L%d" % [id, level])


func _check_level(ch: Character, want: Dictionary, where: String) -> void:
	if want.has("pb"):
		assert_eq(ch.proficiency_bonus(), int(want["pb"]), "%s PB" % where)
	if want.has("hp"):
		assert_eq(ch.max_hp(), int(want["hp"]), "%s HP max (%s)" % [where, ch.max_hp_breakdown().describe()])
		assert_eq(ch.hp, ch.max_hp(), "%s current HP rose with the maximum" % where)
	if want.has("ac"):
		assert_eq(ch.ac_value(), int(want["ac"]), "%s AC (%s)" % [where, ch.armor_class().describe()])
	if want.has("initiative"):
		assert_eq(ch.initiative_bonus().total(), int(want["initiative"]), "%s initiative (%s)" % [where, ch.initiative_bonus().describe()])
	if want.has("speed"):
		assert_eq(ch.speed().total(), int(want["speed"]), "%s speed" % where)
	var scores := want.get("scores", {}) as Dictionary
	for ab: String in scores:
		assert_eq(ch.ability_score(StringName(ab)), int(scores[ab]), "%s %s score (%s)" % [where, ab, ch.ability_breakdown(StringName(ab)).describe()])
	var saves := want.get("saves", {}) as Dictionary
	for ab: String in saves:
		assert_eq(ch.save_bonus(StringName(ab)).total(), int(saves[ab]), "%s %s save (%s)" % [where, ab, ch.save_bonus(StringName(ab)).describe()])
	var skills := want.get("skills", {}) as Dictionary
	for sk: String in skills:
		assert_eq(ch.skill_bonus(StringName(sk)).total(), int(skills[sk]), "%s %s (%s)" % [where, sk, ch.skill_bonus(StringName(sk)).describe()])
	if want.has("passive_perception"):
		assert_eq(ch.passive_score(&"perception").total(), int(want["passive_perception"]), "%s passive Perception" % where)
	if want.has("attack"):
		var a := want["attack"] as Dictionary
		var found := false
		for p in ch.attacks():
			if p.item_id == str(a["weapon"]) and not p.thrown:
				found = true
				assert_eq(p.attack.total(), int(a["bonus"]), "%s %s to hit (%s)" % [where, a["weapon"], p.attack.describe()])
				assert_eq("%s+%d" % [p.damage_dice, p.damage_bonus.total()], str(a["damage"]), "%s %s damage" % [where, a["weapon"]])
		assert_true(found, "%s has a %s attack" % [where, a["weapon"]])
	if want.has("crit_range"):
		var greatsword := _profile(ch, "greatsword")
		assert_eq(greatsword.crit_range if greatsword != null else -1, int(want["crit_range"]), "%s Critical Hit range" % where)
	if want.has("attacks_per_action"):
		var best := 1
		for m in ch.modifiers_for(&"attacks_per_action"):
			best = maxi(best, ch.mod_value(m, ch.formula_context()))
		assert_eq(best, int(want["attacks_per_action"]), "%s attacks per Attack action" % where)
	var resources := want.get("resources", {}) as Dictionary
	for r: String in resources:
		assert_eq(ch.resource_max(r), int(resources[r]), "%s %s uses" % [where, r])
	var counts := want.get("choice_counts", {}) as Dictionary
	for key: String in counts:
		var c := ch.choice(key)
		assert_true(c != null, "%s has choice %s" % [where, key])
		if c != null:
			assert_eq(c.count, int(counts[key]), "%s %s count" % [where, key])
			assert_true(c.is_complete(), "%s %s complete (%d of %d)" % [where, key, c.picks.size(), c.count])
	if want.has("advantage"):
		for key: Variant in want["advantage"]:
			var keys: Array[String] = [str(key)]
			assert_false((ch.d20_sources(keys)["advantage"] as Array).is_empty(), "%s Advantage on %s" % [where, key])
	var subclass := want.get("subclass", {}) as Dictionary
	for cid: String in subclass:
		assert_eq(str(ch.subclasses.get(cid, "")), str(subclass[cid]), "%s %s subclass" % [where, cid])
	if want.has("sneak_attack"):
		assert_eq(str(ch.class_column("rogue", "sneak_attack")), str(want["sneak_attack"]), "%s Sneak Attack" % where)
	if want.has("spell"):
		var sp := want["spell"] as Dictionary
		assert_eq(ch.spell_save_dc(str(sp["class"])).total(), int(sp["dc"]), "%s spell save DC" % where)
		assert_eq(ch.spell_attack_bonus(str(sp["class"])).total(), int(sp["attack"]), "%s spell attack" % where)
	if want.has("slots"):
		var expected: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0]
		var listed := want["slots"] as Array
		for i in listed.size():
			expected[i] = int(listed[i])
		assert_eq(ch.spell_slots(), expected, "%s spell slots" % where)
	if want.has("cantrip"):
		var cd := want["cantrip"] as Dictionary
		assert_eq(Spellcasting.damage_dice(ch.compendium.spell_data(str(cd["id"])), ch.character_level()), str(cd["dice"]), "%s %s dice" % [where, cd["id"]])
	if want.has("darkvision"):
		assert_eq(ch.darkvision(), int(want["darkvision"]), "%s darkvision" % where)
	for r: Variant in want.get("resistances", []):
		assert_ne(ch.resistance_source(StringName(str(r))), "", "%s Resistance to %s" % [where, r])
	for key: String in ["heal", "heal2"]:
		if want.has(key):
			var h := want[key] as Dictionary
			var p := ch.spell_preview(str(h["spell"]), int(h["slot"]))
			assert_eq(str(p.get("heal_dice", "")), str(h["dice"]), "%s %s slot %d dice" % [where, h["spell"], h["slot"]])
			var hb := p.get("heal_bonus", null) as Breakdown
			assert_eq(hb.total() if hb != null else -99, int(h["bonus"]), "%s %s slot %d bonus (%s)" % [where, h["spell"], h["slot"], hb.describe() if hb != null else ""])
	if want.has("damage"):
		var d := want["damage"] as Dictionary
		var p2 := ch.spell_preview(str(d["spell"]), int(d["slot"]))
		assert_eq(str(p2.get("damage_dice", "")), str(d["dice"]), "%s %s dice" % [where, d["spell"]])
	if want.has("always_prepared"):
		var always := {}
		for s in ch.known_spells():
			if str(s["kind"]) == "always":
				always[str(s["id"])] = true
		for s: Variant in want["always_prepared"]:
			assert_true(always.has(str(s)), "%s always has %s prepared" % [where, s])
	if want.has("spellbook"):
		assert_eq((ch.spellcasting_entry("wizard")["spellbook"] as Array).size(), int(want["spellbook"]), "%s spellbook size" % where)
	if want.has("granted"):
		var granted: Array[String] = []
		for s in ch.known_spells():
			if str(s["kind"]) == "granted" and str(s["source"]).contains("Lineage"):
				granted.append(str(s["id"]))
		for s: Variant in want["granted"]:
			assert_true(str(s) in granted, "%s species grants %s (has %s)" % [where, s, granted])
	if want.has("mage_armor_ac"):
		var spell := ch.compendium.spell_data("mage_armor")
		var e := Effect.new("Mage Armor", &"spell", "mage_armor")
		for fx: Variant in spell.get("effects", []):
			for md: Variant in ((fx as Dictionary).get("params", {}) as Dictionary).get("modifiers", []):
				var m := Modifier.make(md as Dictionary, "Mage Armor", &"spell", "mage_armor")
				e.modifiers.append(m)
		ch.add_effect(e)
		assert_eq(ch.ac_value(), int(want["mage_armor_ac"]), "%s AC with Mage Armor (%s)" % [where, ch.armor_class().describe()])
		ch.remove_effect(e)


func _profile(ch: Character, item_id: String) -> WeaponProfile:
	for p in ch.attacks():
		if p.item_id == item_id:
			return p
	return null
