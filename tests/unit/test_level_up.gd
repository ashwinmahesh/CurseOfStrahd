extends TestCase
## LevelUpController (plan §5.6 "Level up"): class choice and multiclass rules, Hit Points, new features and
## choices, before/after, retroactive Hit Points, and that nothing changes until confirm().


func test_hit_point_options_and_rolls() -> void:
	var ilse := TestChars.pregen("ilse_varga")
	var up := LevelUpController.new(ilse)
	assert_true(up.choose_class("fighter"))
	var hp := up.hit_point_options()
	assert_eq(int(hp["die"]), 10)
	assert_eq(int(hp["fixed"]), 6)
	var roll := up.roll_hit_points(DiceRoller.new(3))
	assert_between(roll, 1, 10)
	assert_eq(up.preview().max_hp(), 14 + roll + 2 + 2, "roll + Con + Tough")
	up.take_fixed_hit_points()
	assert_eq(up.preview().max_hp(), 24)


func test_nothing_changes_until_confirm() -> void:
	var ilse := TestChars.pregen("ilse_varga", 2)
	var up := LevelUpController.new(ilse)
	up.choose_class("fighter")
	assert_eq(ilse.character_level(), 2)
	assert_false(up.confirm(), "the subclass is still unchosen")
	assert_true(up.errors()[0].contains("Fighter Subclass"), up.errors()[0])
	assert_eq(ilse.character_level(), 2, "a blocked confirm changes nothing")
	up.choose("fighter.3.fighter_subclass", ["battle_master"])
	assert_false(up.confirm(), "Battle Master asks for maneuvers, a tool and a skill")
	var stuck := TestChars.auto_pick(up.pending_choices, up.choose)
	assert_eq(stuck, [] as Array[String])
	assert_true(up.confirm(), str(up.errors()))
	assert_eq(ilse.character_level(), 3)
	assert_eq(ilse.resource_max("superiority_dice"), 4)
	assert_eq(ilse.maneuvers.size(), 3)


func test_new_features_and_before_after() -> void:
	var ilse := TestChars.pregen("ilse_varga")
	var up := LevelUpController.new(ilse)
	up.choose_class("fighter")
	var names: Array[String] = []
	for f in up.new_features():
		names.append(str(f["name"]))
	assert_true("Action Surge" in names and "Tactical Mind" in names, str(names))
	var rows := {}
	for r in up.changes():
		rows[str(r["label"])] = r
	assert_true(rows.has("Hit Point maximum"))
	assert_eq(int((rows["Hit Point maximum"] as Dictionary)["after"]), 24)
	assert_true(rows.has("Action Surge"))


func test_tough_is_retroactive() -> void:
	var tamsin := TestChars.pregen("tamsin_tealeaf", 3)
	var up := LevelUpController.new(tamsin)
	up.choose_class("rogue")
	up.choose("rogue.4.ability_score_improvement", ["tough"])
	assert_true(up.confirm(), str(up.errors()))
	assert_eq(tamsin.max_hp(), 25 + 7 + 2 * 4, "Tough adds 2 per level, earlier levels included")
	assert_eq(tamsin.hp, tamsin.max_hp(), "current Hit Points rise too")


func test_multiclass_prerequisites_and_proficiencies() -> void:
	var ilse := TestChars.pregen("ilse_varga", 2)
	var up := LevelUpController.new(ilse)
	var by_id := {}
	for o in up.available_classes():
		by_id[o.id] = o
	assert_false((by_id["wizard"] as ChoiceOption).legal)
	assert_true((by_id["wizard"] as ChoiceOption).reason.contains("Intelligence 13 (you have 8)"))
	assert_true((by_id["rogue"] as ChoiceOption).legal, "Dexterity 14 meets Rogue's 13 and Fighter's Str or Dex 13")
	assert_true(up.choose_class("rogue"))
	var after := up.preview()
	assert_eq(after.class_summary(), "Fighter 2 / Rogue 1")
	assert_true(after.has_proficiency("tools", "thieves_tools"), "multiclass Rogue: Thieves' Tools")
	assert_eq(after.save_proficiency(&"dex"), "", "no Rogue saving throws when multiclassing")
	assert_eq(after.choice("rogue.1.skills").count, 1, "one Rogue skill")
	assert_eq(after.proficiency_bonus(), 2)
	assert_eq(int(up.hit_point_options()["fixed"]), 5, "a multiclass level never gets level 1 Hit Points")


func test_eldritch_knight_wizard_multiclass_slots() -> void:
	var b := CharacterBuilder.new()
	b.set_class("fighter")
	b.set_background("soldier")
	b.set_species("human")
	b.set_name("Gwen")
	b.set_base_scores({"str": 15, "dex": 12, "con": 14, "int": 13, "wis": 10, "cha": 8})
	TestChars.auto_pick(b.pending_choices, b.choose)
	var ch := b.build_character()
	assert_true(ch != null, str(b.errors()))
	for level: int in [2, 3]:
		var up := LevelUpController.new(ch)
		up.choose_class("fighter")
		if level == 3:
			up.choose("fighter.3.fighter_subclass", ["eldritch_knight"])
		TestChars.auto_pick(up.pending_choices, up.choose)
		assert_true(up.confirm(), str(up.errors()))
	assert_eq(ch.spell_slots(), [2, 0, 0, 0, 0, 0, 0, 0, 0] as Array[int], "Eldritch Knight 3 alone")
	for level: int in [4, 5]:
		var up2 := LevelUpController.new(ch)
		assert_true(up2.choose_class("wizard"), "Int 13 and Str 15 qualify")
		TestChars.auto_pick(up2.pending_choices, up2.choose)
		assert_true(up2.confirm(), str(up2.errors()))
	assert_eq(ch.class_summary(), "Fighter (Eldritch Knight) 3 / Wizard 2")
	assert_eq(ch.spell_slots(), [4, 2, 0, 0, 0, 0, 0, 0, 0] as Array[int], "floor(3/3) + 2 = caster level 3")
	assert_eq(ch.spellcasting.size(), 2, "two Spellcasting features, each with its own list")


func test_level_twenty_is_the_cap() -> void:
	var ilse := TestChars.pregen("ilse_varga")
	ilse.build["levels"] = []
	for i in 20:
		(ilse.build["levels"] as Array).append({"class": "fighter", "hp": 0})
	ilse.refresh()
	var up := LevelUpController.new(ilse)
	assert_false(up.can_level_up())
	assert_false(up.choose_class("fighter"))
