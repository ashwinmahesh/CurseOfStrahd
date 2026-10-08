extends TestCase
## 2024 Eldritch Invocations taken more than once: Agonizing Blast for a second damaging cantrip and Lessons of the
## First Ones for a second Origin feat, each later copy picked as "<id>#2" with its own choice that can't repeat
## another copy's (choice_options.gd _invocation_copies, _repeat_limits; character.gd _walk_inline_option). Also
## Eldritch Spear's range, added on top of the cantrip's.

const INV := "warlock.1.eldritch_invocations"


## A level 1 Warlock (Charisma 17) knowing `cantrips`, with Armor of Shadows; a human with Alert.
func _create(cantrips: Array) -> Character:
	var b := CharacterBuilder.new()
	b.set_class("warlock")
	b.set_background("charlatan")
	b.set_species("human")
	b.set_name("Test Warlock")
	b.set_base_scores({"str": 8, "dex": 14, "con": 13, "int": 12, "wis": 10, "cha": 15})
	b.choose("background.abilities", ["cha", "cha", "con"])
	b.choose("species.versatile", ["alert"])
	assert_eq(b.choose(INV, ["armor_of_shadows"]), [] as Array[String])
	assert_eq(b.choose("warlock.cantrips", cantrips), [] as Array[String])
	assert_eq(TestChars.auto_pick(b.pending_choices, b.choose), [] as Array[String])
	var ch := b.build_character()
	assert_true(ch != null, "builds: %s" % [b.errors()])
	return ch


## Levels `ch` to `level`: `picks` maps a Warlock level to {choice key: picks}, chosen in order; the rest auto-picked.
func _level_to(ch: Character, level: int, picks: Dictionary = {}) -> void:
	while ch.class_level_of("warlock") < level:
		var up := LevelUpController.new(ch)
		assert_true(up.choose_class("warlock"))
		up.take_fixed_hit_points()
		var n := ch.class_level_of("warlock") + 1
		var mine := picks.get(n, {}) as Dictionary
		for key: String in mine:
			assert_eq(up.choose(key, mine[key] as Array), [] as Array[String], "level %d %s" % [n, key])
		assert_eq(TestChars.auto_pick(up.pending_choices, up.choose), [] as Array[String], "level %d" % n)
		if not up.confirm():
			fail("level %d blocked: %s" % [n, up.errors()])
			return


## Level 5, Agonizing Blast on Eldritch Blast and again on Toll the Dead, Lessons of the First Ones for Skilled and
## again for Tough; Mind Sliver gets neither.
func _twice() -> Character:
	var ch := _create(["eldritch_blast", "toll_the_dead"])
	_level_to(ch, 5, {
		2: {INV: ["armor_of_shadows", "agonizing_blast", "lessons_of_the_first_ones"],
			INV + "/agonizing_blast": ["eldritch_blast"], INV + "/lessons_of_the_first_ones": ["skilled"]},
		3: {"warlock.3.warlock_subclass": ["fiend_patron"]},
		4: {"warlock.4.ability_score_improvement": ["ability_score_improvement"],
			"warlock.4.ability_score_improvement/ability_score_improvement.abilities": ["cha", "cha"],
			"warlock.cantrips": ["eldritch_blast", "toll_the_dead", "mind_sliver"]},
		5: {INV: ["armor_of_shadows", "agonizing_blast", "lessons_of_the_first_ones", "agonizing_blast#2",
			"lessons_of_the_first_ones#2"], INV + "/agonizing_blast#2": ["toll_the_dead"],
			INV + "/lessons_of_the_first_ones#2": ["tough"]}})
	return ch


func _bonus(ch: Character, spell_id: String) -> int:
	return (ch.spell_preview(spell_id)["damage_bonus"] as Breakdown).total()


func _populated(ch: Character, key: String) -> Choice:
	var c := ch.choice(key)
	assert_true(c != null, "no choice %s" % key)
	ChoiceOptions.populate(c, ch)
	return c


func test_agonizing_blast_and_lessons_taken_twice() -> void:
	var ch := _twice()
	assert_eq(ch.class_level_of("warlock"), 5)
	assert_eq(_bonus(ch, "eldritch_blast"), 4, "Agonizing Blast: Charisma 19")
	assert_eq(_bonus(ch, "toll_the_dead"), 4, "the second Agonizing Blast")
	assert_eq(_bonus(ch, "mind_sliver"), 0, "a cantrip neither copy chose")
	assert_eq(ch.invocations.count("agonizing_blast"), 1, str(ch.invocations))
	assert_true("lessons_of_the_first_ones" in ch.invocations)
	assert_false(ch.invocations.any(func(i: String) -> bool: return i.contains("#")), str(ch.invocations))
	var feats: Array = ch.feats_taken.map(func(f: Dictionary) -> String: return str(f["id"]))
	for f: String in ["alert", "skilled", "tough"]:
		assert_true(f in feats, "%s in %s" % [f, feats])
	assert_true(ch.features.any(func(f: Dictionary) -> bool: return str(f["name"]) == "Agonizing Blast (2nd)"))
	assert_true(ch.features.any(func(f: Dictionary) -> bool: return str(f["name"]) == "Lessons of the First Ones (2nd)"))
	for c in ch.choice_defs:
		ChoiceOptions.populate(c, ch)
		assert_eq(ChoiceOptions.errors(c, ch), [] as Array[String], c.key)
	var saved := Character.from_dict(ch.to_dict())
	assert_eq(_bonus(saved, "toll_the_dead"), 4, "the second copy is saved")
	assert_eq(saved.choice(INV + "/agonizing_blast#2").picks, ["toll_the_dead"] as Array[String])
	assert_eq(saved.choice(INV + "/agonizing_blast#2").label, "Agonizing Blast (2nd)")


func test_each_copy_chooses_differently() -> void:
	var ch := _twice()
	var first := _populated(ch, INV + "/agonizing_blast")
	var second := _populated(ch, INV + "/agonizing_blast#2")
	assert_eq(second.option("eldritch_blast").reason, "Already chosen for Agonizing Blast")
	assert_eq(first.option("toll_the_dead").reason, "Already chosen for Agonizing Blast (2nd)")
	assert_true(first.option("mind_sliver").legal and second.option("mind_sliver").legal)
	# Skilled may be taken again as a feat, but Lessons of the First Ones wants a different one each time.
	var lessons := _populated(ch, INV + "/lessons_of_the_first_ones#2")
	assert_eq(lessons.option("skilled").reason, "Already chosen for Lessons of the First Ones")
	assert_false(lessons.option("alert").legal, "the species' Alert")
	# Both copies on one cantrip: the later copy is the one to change.
	(ch.build["choices"] as Dictionary)[INV + "/agonizing_blast#2"] = ["eldritch_blast"]
	ch.refresh()
	first = _populated(ch, INV + "/agonizing_blast")
	second = _populated(ch, INV + "/agonizing_blast#2")
	assert_eq(ChoiceOptions.errors(first, ch), [] as Array[String])
	assert_eq(ChoiceOptions.errors(second, ch).size(), 1, str(ChoiceOptions.errors(second, ch)))


func test_a_copy_waits_for_the_first_and_needs_its_own_cantrip() -> void:
	var ch := _create(["eldritch_blast", "prestidigitation"])
	var up := LevelUpController.new(ch)
	assert_true(up.choose_class("warlock"))
	up.take_fixed_hit_points()
	var inv := _level_choice(up, INV)
	assert_eq(inv.option("agonizing_blast#2").reason, "Take Agonizing Blast first")
	assert_eq(inv.option("lessons_of_the_first_ones#2").reason, "Take Lessons of the First Ones first")
	assert_eq(inv.option("agonizing_blast#3"), null, "one copy offered at a time")
	# The copies follow the book's list, so its order (and the usual picks) stay as they were.
	assert_true(_index(inv, "agonizing_blast#2") > _index(inv, "witch_sight"))
	assert_eq(up.choose(INV, ["armor_of_shadows", "agonizing_blast", "lessons_of_the_first_ones"]), [] as Array[String])
	inv = _level_choice(up, INV)
	assert_eq(inv.option("agonizing_blast#2").reason, "Requires another Warlock cantrip that deals damage")
	assert_true(inv.option("lessons_of_the_first_ones#2").legal)
	assert_eq(inv.option("lessons_of_the_first_ones#2").label, "Lessons of the First Ones (2nd)")
	assert_eq(up.choose(INV, ["armor_of_shadows", "lessons_of_the_first_ones", "lessons_of_the_first_ones#2"]),
		[] as Array[String], "Agonizing Blast swapped for a second Lessons")
	inv = _level_choice(up, INV)
	assert_true(inv.option("lessons_of_the_first_ones#3").legal, "the next copy")
	assert_true(_level_choice(up, INV + "/lessons_of_the_first_ones#2") != null, "the copy's own feat")


func _level_choice(up: LevelUpController, key: String) -> Choice:
	for c in up.level_choices():
		if c.key == key:
			return c
	return null


func _index(c: Choice, id: String) -> int:
	for i in c.options.size():
		if c.options[i].id == id:
			return i
	return -1


func test_eldritch_spear_adds_to_the_range_and_copies_read_as_the_invocation() -> void:
	var e := TestCombat.open_field(3)
	var w := e.add(_twice(), &"party", Vector2i(2, 3))
	var blast := Compendium.shared().spell_data("eldritch_blast")
	assert_eq(e.spells.range_ft(blast, w), 120)
	var picks := ClassFeatures.picks_of_kind(w, "invocation")
	assert_eq(picks.count("agonizing_blast"), 2, str(picks))
	var inv := (w.creature as Character).choice(INV)
	inv.picks.append("eldritch_spear")
	assert_eq(e.spells.range_ft(blast, w), 120 + 30 * 5, "Eldritch Spear: 30 ft per Warlock level on top")
	assert_eq(e.spells.range_ft(Compendium.shared().spell_data("toll_the_dead"), w), 60 + 150)
	# Only the second copy left: still Agonizing Blast.
	inv.picks.erase("agonizing_blast")
	assert_true(ClassFeatures.knows_invocation(w, "agonizing_blast"))
