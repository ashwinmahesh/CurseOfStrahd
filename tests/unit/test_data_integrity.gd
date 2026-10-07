extends TestCase
## The rules content is all there and every class and subclass can be built and levelled 1 to 11 (the Phase 5 level
## cap, ADR 0011) through CharacterBuilder and LevelUpController with no dead ends (plan §5.6 acceptance). All twelve
## 2024 PHB classes since Phase 4 (P4-01); levels 8 to 11 since Phase 5 (P5-01).


func test_phase_1_content_counts() -> void:
	var c := Compendium.shared()
	assert_eq(c.table("classes").size(), 12)
	var phb_only := func(rows: Array) -> Array: return rows.filter(func(x: Dictionary) -> bool: return str((x["source"] as Dictionary)["book"]) == "PHB2024")
	var rthw_only := func(rows: Array) -> Array: return rows.filter(func(x: Dictionary) -> bool: return str((x["source"] as Dictionary)["book"]) == "RtHW")
	assert_eq((phb_only.call(c.all("subclasses")) as Array).size(), 48)
	assert_eq((rthw_only.call(c.all("subclasses")) as Array).size(), 6, "Ravenloft: The Horrors Within (no Reanimator: no Artificer)")
	for cls: String in ["barbarian", "bard", "cleric", "druid", "fighter", "monk", "paladin", "ranger", "rogue",
			"sorcerer", "warlock", "wizard"]:
		assert_eq((phb_only.call(c.subclasses_of(cls)) as Array).size(), 4, "%s has its four PHB subclasses" % cls)
	assert_eq((phb_only.call(c.all("species")) as Array).size(), 10)
	assert_eq((rthw_only.call(c.all("species")) as Array).size(), 4, "Dhampir, Hexblood, Lupin, Reborn")
	assert_eq(c.all("feats").filter(func(f: Dictionary) -> bool: return str(f["category"]) == "dark_gift").size(), 9, "nine Ravenloft Dark Gifts")
	assert_eq((phb_only.call(c.all("backgrounds")) as Array).size(), 16)
	assert_eq((rthw_only.call(c.all("backgrounds")) as Array).size(), 4, "Haunted One, Investigator, Mist Wanderer, Spirit Medium")
	assert_eq(c.table("monsters").size(), 125, "76 from Phase 1, 36 that magic items summon or become, Death House's mimic, and Castle Ravenloft's 12 (P6-02)")
	assert_eq(c.table("pregens").size(), 10, "the six on the roster and the first four, kept for older saves and tests")
	assert_true(c.table("feats").size() >= 70)
	assert_true(c.table("spells").size() >= 170)
	for level in 4:
		assert_true(c.spells_for("cleric", level).size() >= 7, "cleric level %d spells" % level)
		assert_true(c.spells_for("wizard", level).size() >= 20, "wizard level %d spells" % level)


func test_every_class_and_subclass_builds_and_levels_to_11() -> void:
	var c := Compendium.shared()
	for sub in c.all("subclasses"):
		var cls := str(sub["class"])
		var b := CharacterBuilder.new()
		b.set_class(cls)
		b.set_background("soldier" if cls in ["fighter", "rogue"] else "sage")
		b.set_species("human")
		b.set_name("Auto %s" % sub["name"])
		b.apply_recommended_scores()
		TestChars.auto_pick(b.pending_choices, b.choose)
		var ch := b.build_character()
		if ch == null:
			fail("%s level 1: %s" % [sub["id"], b.errors()])
			continue
		for level in range(2, 12):
			var up := LevelUpController.new(ch)
			up.choose_class(cls)
			if level == 3:
				up.choose("%s.3.%s_subclass" % [cls, cls], [str(sub["id"])])
			TestChars.auto_pick(up.pending_choices, up.choose)
			if not up.confirm():
				fail("%s level %d: %s" % [sub["id"], level, up.errors()])
				break
		assert_eq(ch.character_level(), 11, "%s reached level 11" % sub["id"])
		assert_eq(ch.proficiency_bonus(), 4, "%s Proficiency Bonus at 11" % sub["id"])
		var open: Array = ch.pending_choices().map(func(pc: Choice) -> String: return pc.key)
		assert_eq(open, [], "%s has nothing left to choose" % sub["id"])
		assert_eq(str(ch.subclasses.get(cls, "")), str(sub["id"]))
		assert_true(ch.max_hp() > 0)
		for f in ch.features:
			assert_ne(str(f["name"]), "", "%s feature names" % sub["id"])


func test_every_species_and_background_builds() -> void:
	var c := Compendium.shared()
	var backgrounds := c.all("backgrounds")
	var i := 0
	for sp in c.all("species"):
		var bg := backgrounds[i % backgrounds.size()]
		i += 1
		var b := CharacterBuilder.new()
		b.set_class("cleric")
		b.set_background(str(bg["id"]))
		b.set_species(str(sp["id"]))
		b.set_name("Test")
		b.apply_recommended_scores()
		TestChars.auto_pick(b.pending_choices, b.choose)
		assert_eq(b.errors(), [] as Array[String], "%s %s" % [sp["id"], bg["id"]])
	for bg2 in backgrounds:
		var b2 := CharacterBuilder.new()
		b2.set_class("rogue")
		b2.set_background(str(bg2["id"]))
		b2.set_species("dwarf")
		b2.set_name("Test")
		b2.apply_recommended_scores()
		TestChars.auto_pick(b2.pending_choices, b2.choose)
		assert_eq(b2.errors(), [] as Array[String], "background %s" % bg2["id"])
		var ch := b2.build_character()
		assert_true(ch != null and ch.inventory.size() > 0, "%s starting gear" % bg2["id"])


func test_monster_stat_blocks_are_self_consistent() -> void:
	var xp_by_cr := {0.0: [0, 10], 0.125: [25], 0.25: [50], 0.5: [100], 1.0: [200], 2.0: [450], 3.0: [700],
		4.0: [1100], 5.0: [1800], 6.0: [2300], 7.0: [2900], 8.0: [3900]}
	for data in Compendium.shared().all("monsters"):
		var m := Monster.from_data(data)
		var id := str(data["id"])
		var hp := data["hp"] as Dictionary
		var p := DiceRoller.parse_expr(str(hp["dice"]))
		var avg := floori(int(p["count"]) * (int(p["sides"]) + 1) / 2.0) + int(p["modifier"])
		assert_eq(int(hp["average"]), avg, "%s HP average matches %s" % [id, hp["dice"]])
		assert_eq(m.max_hp(), int(hp["average"]))
		if data.has("passive_perception"):
			assert_eq(m.passive_score(&"perception").total(), int(data["passive_perception"]), "%s passive Perception" % id)
		assert_eq(m.proficiency_bonus(), Abilities.proficiency_for_cr(float(data["cr"])), "%s PB" % id)
		if xp_by_cr.has(float(data["cr"])):
			assert_true(int(data.get("xp", -1)) in (xp_by_cr[float(data["cr"])] as Array), "%s XP for CR %s" % [id, data["cr"]])
		for a: Variant in data.get("actions", []):
			var act := a as Dictionary
			if act.has("attack"):
				assert_false((act.get("damage", []) as Array).is_empty() and not act.has("conditions"), "%s %s has an effect" % [id, act["id"]])
			for d: Variant in act.get("damage", []):
				var dd := d as Dictionary
				var dp := DiceRoller.parse_expr(str(dd["dice"]))
				var davg := floori(int(dp["count"]) * (int(dp["sides"]) + 1) / 2.0) + int(dp["modifier"])
				assert_eq(int(dd["average"]), davg, "%s %s damage average" % [id, act["id"]])
