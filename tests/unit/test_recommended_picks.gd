extends TestCase
## Recommended picks on level up (Q10): LevelUpController.recommend() fills every pick a level asks for, legally, from a
## companion's own level plan or from RecommendedPicks, and the player can still change them.


## Every class levelled from 1 to the campaign's cap with nothing but the recommended picks: no level is left with an
## error or an empty pick.
func test_every_class_levels_to_the_cap_on_recommendations_alone() -> void:
	for cid: String in MagicItems.CLASSES:
		var ch := TestChars.custom(cid, "human", 1)
		while ch.character_level() < StoryState.LEVEL_CAP:
			var up := LevelUpController.new(ch)
			up.choose_class(cid)
			up.recommend()
			var errors := up.errors()
			assert_eq(errors, [] as Array[String], "%s level %d: %s" % [cid, ch.character_level() + 1, errors])
			if not errors.is_empty() or not up.confirm():
				break
		assert_eq(ch.character_level(), StoryState.LEVEL_CAP, "%s reached the cap" % cid)


## A companion's own plan comes first: what recommend() picks is what their level plan says.
func test_a_companion_follows_their_own_plan() -> void:
	var checked := 0
	for id in Pregens.roster_ids():
		var plan := Compendium.shared().get_entry("pregens", id).get("level_plan", []) as Array
		for s: Variant in plan:
			var step := s as Dictionary
			var level := int(step["level"])
			if (step.get("choices", {}) as Dictionary).is_empty() or level > 6:
				continue
			var ch := TestChars.pregen(id, level - 1)
			var up := LevelUpController.new(ch)
			up.choose_class(str(step["class"]))
			var filled := up.recommend()
			for key: String in (step["choices"] as Dictionary):
				var want: Array = (step["choices"] as Dictionary)[key]
				for c in up.level_choices():
					if c.key == key and not c.is_complete():
						fail("%s level %d: %s left incomplete" % [id, level, key])
				var got: Array = (up.build["choices"] as Dictionary).get(key, [])
				if got != want:
					# Only a choice the level actually asked for is filled from the plan.
					var asked := filled.any(func(r: Dictionary) -> bool: return str(r["key"]) == key)
					assert_false(asked, "%s level %d %s: plan %s, recommended %s" % [id, level, key, want, got])
			for r in filled:
				if (step["choices"] as Dictionary).has(str(r["key"])):
					assert_true(bool(r["plan"]), "%s level %d: %s came from the plan" % [id, level, r["key"]])
			checked += 1
	assert_true(checked >= 6, "the companions' plans were checked (%d levels)" % checked)


func test_an_ability_score_improvement_raises_the_main_ability() -> void:
	var ch := TestChars.custom("fighter", "human", 3)
	var up := LevelUpController.new(ch)
	up.choose_class("fighter")
	var str_before := ch.ability_score(&"str")
	up.recommend()
	assert_eq(up.errors(), [] as Array[String])
	assert_true("ability_score_improvement" in up.preview().picks_for("fighter.4.ability_score_improvement"),
		"the feat pick is the Ability Score Improvement while Strength is under 20")
	assert_true(up.preview().ability_score(&"str") > str_before, "Strength goes up: %d → %d" % [str_before, up.preview().ability_score(&"str")])


func test_a_subclass_and_spells_for_a_new_hero() -> void:
	var cleric := TestChars.custom("cleric", "human", 2)
	var up := LevelUpController.new(cleric)
	up.choose_class("cleric")
	up.recommend()
	assert_eq(up.preview().picks_for("cleric.3.cleric_subclass"), ["life_domain"] as Array[String], "the class's recommended subclass")
	var wizard := TestChars.custom("wizard", "human", 4)
	var up2 := LevelUpController.new(wizard)
	up2.choose_class("wizard")
	up2.recommend()
	assert_eq(up2.errors(), [] as Array[String])
	# The two best level 3 spells end up in the book (an Abjurer's Abjuration Savant may give Counterspell first, and
	# the book's two picks then take Fireball and the next best).
	var book: Array = up2.preview().spellcasting_entry("wizard").get("spellbook", [])
	assert_true("fireball" in book and "counterspell" in book, "a level 5 Wizard's book has Fireball and Counterspell: %s" % [book])


## The picks stay the player's: changing one after recommend() keeps the change, and Recommended puts them back.
func test_recommendations_can_be_changed_and_restored() -> void:
	var ch := TestChars.custom("cleric", "human", 2)
	var up := LevelUpController.new(ch)
	up.choose_class("cleric")
	up.recommend()
	up.choose("cleric.3.cleric_subclass", ["war_domain"])
	up.recommend()
	assert_eq(up.preview().picks_for("cleric.3.cleric_subclass"), ["war_domain"] as Array[String], "a pick made is left alone")
	up.reset_picks()
	up.recommend()
	assert_eq(up.preview().picks_for("cleric.3.cleric_subclass"), ["life_domain"] as Array[String], "Recommended puts it back")


func test_the_level_up_screen_opens_filled_in() -> void:
	Compendium.shared().tables["locations"]["rec_hall"] = {"id": "rec_hall", "name": "Rec Hall", "region": "test", "summary": "",
		"map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	for id: String in Pregens.roster_ids().slice(0, 4):
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "rec_hall"
	GameState.story.milestones = 10
	var root := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await get_tree().process_frame
	root.call("open_screen", "level_up", 0)
	await get_tree().process_frame
	var screen := root.get("screen") as LevelUpScreen
	assert_eq(screen.ctl.errors(), [] as Array[String], "nothing left to pick")
	var text := ""
	for l in screen.find_children("*", "Label", true, false):
		text += (l as Label).text + "\n"
	assert_true(text.contains("Filled in"), "the card says the picks were filled in")
	var confirm: Button = null
	for b in screen.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Confirm level"):
			confirm = b as Button
	assert_true(confirm != null and not confirm.disabled, "Confirm is ready straight away")
	root.queue_free()
