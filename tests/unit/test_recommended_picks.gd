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


## The picks stay the player's: a pick made before Use Recommended stays, and what it asks for is filled for it.
func test_use_recommended_keeps_the_players_picks() -> void:
	var ch := TestChars.custom("cleric", "human", 2)
	var up := LevelUpController.new(ch)
	up.choose_class("cleric")
	up.choose("cleric.3.cleric_subclass", ["war_domain"])
	up.recommend()
	assert_eq(up.preview().picks_for("cleric.3.cleric_subclass"), ["war_domain"] as Array[String], "the War Domain stays")
	assert_eq(up.errors(), [] as Array[String], "and the rest is filled around it")


## Owner question (2026-10-07): with a subclass other than the recommended one, does Use Recommended still work? Every
## subclass of every class, picked by hand at its level, then Use Recommended at that level and the next three: nothing
## is left blank or illegal, and the subclass stays.
func test_use_recommended_with_every_subclass() -> void:
	var checked := 0
	for cid: String in MagicItems.CLASSES:
		var at := int(Compendium.shared().class_data(cid).get("subclass_level", 3))
		var probe := TestChars.custom(cid, "human", at - 1)
		var up0 := LevelUpController.new(probe)
		up0.choose_class(cid)
		var sub: Choice = null
		for c in up0.level_choices():
			if c.kind == "subclass":
				sub = c
		assert_true(sub != null, "%s asks for a subclass at level %d" % [cid, at])
		if sub == null:
			continue
		for o in sub.options:
			if not o.legal:
				continue
			var ch := TestChars.custom(cid, "human", at - 1)
			var up := LevelUpController.new(ch)
			up.choose_class(cid)
			up.choose(sub.key, [o.id])
			up.recommend()
			var errors := up.errors()
			assert_eq(errors, [] as Array[String], "%s with %s: %s" % [cid, o.id, errors])
			if not errors.is_empty() or not up.confirm():
				continue
			assert_eq(ch.picks_for(sub.key), [o.id] as Array[String], "%s kept %s" % [cid, o.id])
			while ch.character_level() < mini(at + 3, StoryState.LEVEL_CAP):
				var next := LevelUpController.new(ch)
				next.choose_class(cid)
				next.recommend()
				var errs := next.errors()
				assert_eq(errs, [] as Array[String], "%s (%s) level %d: %s" % [cid, o.id, ch.character_level() + 1, errs])
				if not errs.is_empty() or not next.confirm():
					break
			checked += 1
	assert_true(checked >= 50, "every subclass checked (%d)" % checked)


func test_the_level_up_screen_opens_blank_until_use_recommended() -> void:
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
	assert_false(screen.ctl.errors().is_empty(), "level 4 opens with its picks blank (owner, 2026-10-07)")
	var use: Button = null
	var confirm: Button = null
	for b in screen.find_children("*", "Button", true, false):
		if (b as Button).text == "Use Recommended":
			use = b as Button
		if (b as Button).text.begins_with("Confirm level"):
			confirm = b as Button
	assert_true(confirm != null and confirm.disabled, "Confirm waits for the picks")
	assert_true(use != null and not use.disabled, "Use Recommended is offered")
	use.pressed.emit()
	await get_tree().process_frame
	assert_eq(screen.ctl.errors(), [] as Array[String], "every pick filled")
	var text := ""
	confirm = null
	for n in screen.find_children("*", "", true, false):
		if n is Label and not n.is_queued_for_deletion():
			text += (n as Label).text + "\n"
		if n is Button and not n.is_queued_for_deletion() and (n as Button).text.begins_with("Confirm level"):
			confirm = n as Button
	assert_true(text.contains("Filled in"), "the card says what was filled in")
	assert_true(confirm != null and not confirm.disabled, "Confirm is ready")
	root.queue_free()
