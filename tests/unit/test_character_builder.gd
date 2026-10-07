extends TestCase
## CharacterBuilder (plan §5.6 "Character creation"): steps, legality with reasons, warnings, pruning when an
## earlier step changes, ability score methods, and that nothing exists until build_character().


func _fighter_builder() -> CharacterBuilder:
	var b := CharacterBuilder.new()
	b.set_class("fighter")
	b.set_background("soldier")
	b.set_species("human")
	b.set_name("Test")
	return b


func test_lists_the_phase_1_classes() -> void:
	var ids: Array[String] = []
	for o in CharacterBuilder.new().available_classes():
		ids.append(o.id)
	for c: String in ["cleric", "fighter", "rogue", "wizard"]:
		assert_true(c in ids, c)
	var preview := CharacterBuilder.new().class_preview("cleric")
	# The four PHB domains and Grave, plus the book domains once they're playable (Knowledge is; Arcana isn't yet).
	assert_eq((preview["subclasses"] as Array).size(), Compendium.shared().subclasses_of("cleric").size(), "every playable domain")
	assert_true((preview["subclasses"] as Array).size() >= 5, "four PHB domains and Grave at least")
	assert_eq(int(preview["hit_die"]), 8)


func test_fresh_build_lists_what_is_missing() -> void:
	var b := CharacterBuilder.new()
	var errs := b.errors()
	assert_true("Choose a class." in errs)
	assert_true("Choose a background." in errs)
	assert_true("Give your character a name." in errs)
	assert_true(b.build_character() == null, "nothing is built while errors remain")


func test_background_increases_follow_the_2024_rule() -> void:
	var b := _fighter_builder()
	assert_eq(b.choose("background.abilities", ["str", "str", "con"]), [] as Array[String], "+2/+1")
	assert_eq(b.choose("background.abilities", ["str", "dex", "con"]), [] as Array[String], "+1/+1/+1")
	var three := b.choose("background.abilities", ["str", "str", "str"])
	assert_false(three.is_empty(), "+3 to one ability isn't allowed")
	var wrong := b.choose("background.abilities", ["int", "str", "con"])
	assert_true(wrong[0].contains("isn't an option"), wrong[0])


func test_changing_class_prunes_its_choices() -> void:
	var b := _fighter_builder()
	b.choose("fighter.1.fighting_style", ["defense"])
	b.choose("fighter.1.skills", ["survival", "insight"])
	assert_true((b.build["choices"] as Dictionary).has("fighter.1.fighting_style"))
	b.set_class("wizard")
	assert_false((b.build["choices"] as Dictionary).has("fighter.1.fighting_style"), "old class choices are gone")
	assert_true(b.get_choice("wizard.spellbook") != null)


func test_skill_already_from_background_is_a_warning_not_an_error() -> void:
	var b := _fighter_builder()
	var c := b.get_choice("fighter.1.skills")
	var athletics := c.option("athletics")
	assert_true(athletics.legal)
	assert_true(athletics.warning.contains("Background: Soldier"), athletics.warning)


func test_origin_feat_choice_only_offers_origin_feats() -> void:
	var b := _fighter_builder()
	var versatile := b.get_choice("species.versatile")
	var ids: Array[String] = []
	for o in versatile.options:
		ids.append(o.id)
	assert_true("tough" in ids and "alert" in ids)
	assert_false("great_weapon_master" in ids, "general feats aren't Origin feats")
	b.choose("species.versatile", ["skilled"])
	assert_true(b.get_choice("species.versatile/skilled.skilled_proficiencies") != null, "picking Skilled adds its own choice")


func test_feat_prerequisites_explain_themselves() -> void:
	var wiz := TestChars.pregen("silvain_aster", 3)
	var up := LevelUpController.new(wiz)
	up.choose_class("wizard")
	var asi: Choice = null
	for c in up.pending_choices():
		if c.kind == "feat":
			asi = c
	assert_true(asi != null)
	var ham := asi.option("heavy_armor_master")
	assert_false(ham.legal)
	assert_true(ham.reason.contains("Requires"), ham.reason)
	assert_true(asi.option("ability_score_improvement").legal)
	assert_true(asi.option("tough").legal, "Origin feats are open at level 4 too")


func test_expertise_needs_proficiency() -> void:
	var rogue := TestChars.pregen("tamsin_tealeaf")
	var c := rogue.choice("rogue.1.expertise")
	ChoiceOptions.populate(c, rogue)
	assert_false(c.option("arcana").legal)
	assert_eq(c.option("arcana").reason, "Requires proficiency in Arcana")
	assert_true(c.option("perception").legal)


func test_point_buy_and_standard_array() -> void:
	var b := _fighter_builder()
	b.set_ability_method("point_buy")
	assert_eq(b.point_buy_remaining(), 27)
	b.set_base_scores({"str": 15, "dex": 15, "con": 15, "int": 8, "wis": 8, "cha": 8})
	assert_eq(b.point_buy_remaining(), 0)
	assert_eq(b.ability_problems(), [] as Array[String])
	b.set_base_scores({"str": 15, "dex": 15, "con": 15, "int": 15, "wis": 8, "cha": 8})
	assert_true(b.ability_problems()[0].contains("36 points spent"), b.ability_problems()[0])
	b.set_ability_method("standard_array")
	assert_eq(int((b.build["base_scores"] as Dictionary)["str"]), 15, "Recommended puts 15 in Strength for a Fighter")
	b.set_base_scores({"str": 15, "dex": 15, "con": 13, "int": 12, "wis": 10, "cha": 8})
	assert_false(b.ability_problems().is_empty(), "15 twice isn't the Standard Array")


func test_rolled_scores_use_the_seeded_dice() -> void:
	var b := _fighter_builder()
	var rolled := b.roll_scores(DiceRoller.new(77))
	assert_eq(rolled.size(), 6)
	for r in rolled:
		var rolls := r["rolls"] as Array
		var sorted := rolls.duplicate()
		sorted.sort()
		assert_eq(int(r["total"]), int(sorted[1]) + int(sorted[2]) + int(sorted[3]), "drop the lowest")
	assert_eq(b.ability_problems(), [] as Array[String], "assigned in the recommended order")
	var again := CharacterBuilder.new()
	again.set_class("fighter")
	assert_eq(again.roll_scores(DiceRoller.new(77))[0]["total"], rolled[0]["total"], "same seed, same rolls")


func test_complete_build_and_warnings() -> void:
	var b := _fighter_builder()
	b.set_base_scores({"str": 8, "dex": 10, "con": 13, "int": 15, "wis": 14, "cha": 12})
	b.choose("background.abilities", ["con", "con", "dex"])
	b.choose("species.size", ["medium"])
	b.choose("species.skillful", ["perception"])
	b.choose("species.versatile", ["alert"])
	b.choose("origin.languages", ["elvish", "dwarvish"])
	b.choose("background.tool", ["dice_set"])
	b.choose("fighter.1.skills", ["survival", "insight"])
	b.choose("fighter.1.fighting_style", ["archery"])
	b.choose("fighter.1.weapon_mastery", ["longbow", "longsword", "dagger"])
	assert_eq(b.errors(), [] as Array[String])
	var warns := b.warnings()
	assert_true(warns.size() > 0 and warns[0].contains("relies on Strength or Dexterity"), str(warns))
	var ch := b.build_character()
	assert_true(ch != null)
	assert_eq(ch.ac_value(), 16, "Chain Mail 16, Dex 11 doesn't count")


func test_steps_report_their_own_problems() -> void:
	var b := _fighter_builder()
	var origin := b.step_status(CharacterBuilder.Step.ORIGIN)
	assert_false(bool(origin["complete"]))
	assert_true((origin["errors"] as Array).size() > 0)
	var cls := b.step_status(CharacterBuilder.Step.CLASS)
	assert_true(bool(cls["complete"]))


func test_magic_initiate_list_fixed_by_background() -> void:
	var b := CharacterBuilder.new()
	b.set_class("cleric")
	b.set_background("acolyte")
	var c := b.get_choice("background.feat.two_cantrips.cantrips")
	assert_true(c != null)
	assert_true(c.option("sacred_flame") != null, "Acolyte's Magic Initiate uses the Cleric list")
	assert_true(c.option("fire_bolt") == null, "no Wizard cantrips")
	assert_true(b.get_choice("background.feat.list") == null, "no list choice when the background fixes it")
