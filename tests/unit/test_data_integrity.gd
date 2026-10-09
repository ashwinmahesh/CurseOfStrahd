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
	assert_eq(c.table("monsters").size(), 147, "76 from Phase 1, 36 that magic items summon or become, Death House's mimic, Castle Ravenloft's 12 (P6-02), the side quests' twenty-one bosses (Old Greytooth, the Bone Marshal, the Rag Queen, Granny Ash, the Vine Mother, the Count's Huntsman, the Penitent, the Tinker's Wagon, the Grandsire, Corvina, Sarkhaza, Khazan, the Eye Below, the Ash Effigy, the Lantern Girl, the Count's Likeness, Querreth, the Gilded Knight, the Forgotten Storm, the Guide and Grandfather Stone) and the Eye's dream-gazer")
	assert_eq(c.table("pregens").size(), 10, "the six on the roster and the first four, kept for older saves and tests")
	assert_true(c.table("feats").size() >= 70)
	assert_true(c.table("spells").size() >= 170)
	for level in 4:
		assert_true(c.spells_for("cleric", level).size() >= 7, "cleric level %d spells" % level)
		assert_true(c.spells_for("wizard", level).size() >= 20, "wizard level %d spells" % level)


## The class-and-subclass builds in slices by class, so make test can run them side by side (they took three minutes
## in one test). Together they cover every class.
const CLASS_SLICES := [["barbarian", "bard", "cleric"], ["druid", "fighter", "monk"], ["paladin", "ranger", "rogue"],
	["sorcerer", "warlock", "wizard"]]


func test_the_class_slices_cover_every_class() -> void:
	var sliced := {}
	for slice: Array in CLASS_SLICES:
		for cls: String in slice:
			assert_false(sliced.has(cls), "%s is in one slice only" % cls)
			sliced[cls] = true
	for sub in Compendium.shared().all_playable("subclasses"):
		assert_true(sliced.has(str(sub["class"])), "%s's class %s is built" % [sub["id"], sub["class"]])


func test_every_barbarian_bard_and_cleric_subclass_builds_and_levels_to_11() -> void:
	_build_to_11(CLASS_SLICES[0])


func test_every_druid_fighter_and_monk_subclass_builds_and_levels_to_11() -> void:
	_build_to_11(CLASS_SLICES[1])


func test_every_paladin_ranger_and_rogue_subclass_builds_and_levels_to_11() -> void:
	_build_to_11(CLASS_SLICES[2])


func test_every_sorcerer_warlock_and_wizard_subclass_builds_and_levels_to_11() -> void:
	_build_to_11(CLASS_SLICES[3])


## Builds every playable subclass of `classes` from level 1 and levels it to 11 with automatic picks.
func _build_to_11(classes: Array) -> void:
	var c := Compendium.shared()
	var built := 0
	# Every subclass a player can pick (entries marked "playable": false aren't offered yet, docs/tasks/FR-AU-01.md).
	for sub in c.all_playable("subclasses"):
		var cls := str(sub["class"])
		if not cls in classes:
			continue
		built += 1
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
	assert_true(built >= classes.size(), "built the subclasses of %s (%d)" % [classes, built])


func test_every_species_and_background_builds() -> void:
	var c := Compendium.shared()
	var backgrounds := c.all_playable("backgrounds")   # the ones a player can pick (docs/tasks/FR-AU-01.md)
	var i := 0
	for sp in c.all_playable("species"):
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


## A speaker's name picks its NPC (DialogueRunner._npc_for), so two NPCs with one display name share a portrait and a
## voice. Only interchangeable extras may share one.
func test_npc_display_names_are_unique() -> void:
	const SHARED := ["A Goat", "Belview", "A Camp Dog", "A Raven"]
	var seen := {}
	for n in Compendium.shared().all("npcs"):
		var name := str(n["name"])
		if name in SHARED:
			continue
		assert_false(seen.has(name), "%s and %s are both called %s" % [seen.get(name, ""), n["id"], name])
		seen[name] = str(n["id"])
