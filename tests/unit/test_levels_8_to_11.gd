extends TestCase
## Levels 8 to 11 (P5-01, ADR 0011's level cap): one character of every class is created through CharacterBuilder and
## levelled to 11 through LevelUpController with fixed Hit Points and set Ability Score Improvements, and its sheet at
## levels 8, 9, 10 and 11 matches numbers worked out by hand from the 2024 PHB: Hit Points, Proficiency Bonus 4 from
## level 9, spell slots (5th-level slots at 9 and 6th at 11 for full casters, 3rd at 9 for half casters, Pact Magic
## at level 5 from Warlock 9 with a third slot at 11), Extra Attack and Two Extra Attacks, cantrip dice at 11, class
## columns (Rage, Sneak Attack, Martial Arts, Focus, Bardic die, Wild Shape, Psionic dice) and the level 8-11
## features the rules engine runs (Magical Secrets, Mystic Arcanum, Nature's Ward, Aura of Courage, Tireless,
## Fiendish Resilience, Celestial Resilience, Empowered Evocation). Also a multiclass character at level 11.
## The arithmetic for each number is in its message; docs/rules/reference_party.md has the sheets.


# --- helpers -------------------------------------------------------------------------------------

## Level 1 human with Alert (Versatile): Standard Array scores as given, the background's increases as given, every
## other choice auto-picked unless set in `picks`.
func _create(cid: String, background: String, scores: Dictionary, increases: Array, picks: Dictionary = {}) -> Character:
	var b := CharacterBuilder.new()
	b.set_class(cid)
	b.set_background(background)
	b.set_species("human")
	b.set_name("Test %s" % cid)
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


## Levels `ch` in `cid` to `level` with fixed Hit Points; `picks` maps a class level to {choice key: picks}.
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


func _known(ch: Character, spell_id: String, kind: String = "") -> Dictionary:
	for k in ch.known_spells():
		if str(k["id"]) == spell_id and (kind == "" or str(k["kind"]) == kind):
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


func _weapon(ch: Character, item_id: String) -> String:
	var p := _profile(ch, item_id)
	if p == null:
		return "no %s" % item_id
	return "%+d, %s+%d" % [p.attack.total(), p.damage_dice, p.damage_bonus.total()]


func _attacks_per_action(ch: Character) -> int:
	var best := 1
	for m in ch.modifiers_for(&"attacks_per_action"):
		best = maxi(best, ch.mod_value(m, ch.formula_context()))
	return best


func _hp(ch: Character, want: int, why: String) -> void:
	assert_eq(ch.max_hp(), want, "%s HP: %s (%s)" % [ch.class_summary(), why, ch.max_hp_breakdown().describe()])


func _cantrip(ch: Character, spell_id: String) -> String:
	return Spellcasting.damage_dice(ch.compendium.spell_data(spell_id), ch.character_level())


func _bonus(ch: Character, spell_id: String, slot: int = 0) -> int:
	return (ch.spell_preview(spell_id, slot)["damage_bonus"] as Breakdown).total()


# --- content -------------------------------------------------------------------------------------

## Every class and subclass feature a character can reach (levels 1 to 11) has rules text and an `implemented`
## label, so the level-up screen can show what the new level does.
func test_every_feature_to_level_11_has_text() -> void:
	var c := Compendium.shared()
	for cls in c.all("classes"):
		for lv in 11:
			for f: Variant in ((cls["levels"] as Array)[lv] as Dictionary)["features"]:
				var fd := f as Dictionary
				if str(fd["id"]) == "subclass_feature":
					continue
				assert_ne(str(fd.get("text", "")), "", "%s %d %s has text" % [cls["id"], lv + 1, fd["id"]])
				assert_true(str(fd.get("implemented", "")) in ["data", "engine", "text"], "%s %s label" % [cls["id"], fd["id"]])
	for sub in c.all("subclasses"):
		for e: Variant in sub["features"]:
			var entry := e as Dictionary
			if int(entry["level"]) <= 11:
				var fd := entry["feature"] as Dictionary
				assert_ne(str(fd.get("text", "")), "", "%s %d %s has text" % [sub["id"], entry["level"], fd["id"]])
				assert_true(str(fd.get("implemented", "")) in ["data", "engine", "text"], "%s %s label" % [sub["id"], fd["id"]])


# --- Barbarian -----------------------------------------------------------------------------------

## Str 15 Dex 13 Con 14 + Soldier (Str +2, Con +1) = Str 17, Con 15; ASI 4: Con +2 = 17; ASI 8: Str +2 = 19.
func test_barbarian_berserker_levels_8_to_11() -> void:
	var ch := _create("barbarian", "soldier", {"str": 15, "dex": 13, "con": 14, "int": 10, "wis": 12, "cha": 8},
		["str", "str", "con"])
	_level_to(ch, "barbarian", 8, {3: {"barbarian.3.barbarian_subclass": ["path_of_the_berserker"]},
		4: _asi("barbarian", 4, ["con", "con"]), 8: _asi("barbarian", 8, ["str", "str"])})
	assert_eq(ch.proficiency_bonus(), 3, "PB 3 at level 8")
	_hp(ch, 85, "d12: 12 + 7 × 7, Con +3 × 8")
	assert_eq(ch.ability_score(&"str"), 19, "ASI at 8")
	assert_eq(str(ch.class_column("barbarian", "rage_damage")), "+2")
	_level_to(ch, "barbarian", 9)
	assert_eq(ch.proficiency_bonus(), 4, "PB 4 at level 9")
	_hp(ch, 95, "12 + 8 × 7 + 3 × 9")
	assert_eq(str(ch.class_column("barbarian", "rage_damage")), "+3", "Rage Damage +3 at 9")
	assert_true(_has_feature(ch, "brutal_strike"))
	assert_eq(ch.save_bonus(&"str").total(), 8, "Str 4 + PB 4")
	_level_to(ch, "barbarian", 10)
	_hp(ch, 105, "12 + 9 × 7 + 3 × 10")
	assert_eq(ch.choice("barbarian.1.weapon_mastery").count, 4, "Weapon Mastery 4 at 10")
	assert_true(_has_feature(ch, "retaliation"), "Berserker 10")
	_level_to(ch, "barbarian", 11)
	_hp(ch, 115, "12 + 10 × 7 + 3 × 11")
	assert_eq(ch.class_summary(), "Barbarian (Path of the Berserker) 11")
	assert_eq(ch.resource_max("rage"), 4, "Rages: 4 at 6-11")
	assert_true(_has_feature(ch, "relentless_rage"))
	assert_eq(ch.ac_value(), 14, "Unarmored Defense 10 + Dex 1 + Con 3")
	assert_eq(ch.speed().total(), 40, "Fast Movement")
	assert_eq(_weapon(ch, "greataxe"), "+8, 1d12+4", "Str 4 + PB 4")
	assert_eq(_attacks_per_action(ch), 2, "Extra Attack")
	assert_eq(ch.initiative_bonus().total(), 5, "Dex 1 + Alert 4")
	assert_true(_advantage(ch, ch.initiative_keys()), "Feral Instinct")
	assert_eq(ch.save_bonus(&"con").total(), 7, "Con 3 + PB 4")


# --- Bard ----------------------------------------------------------------------------------------

## Cha 15 Dex 14 Con 12 + Entertainer (Cha +2, Dex +1) = Cha 17, Dex 15; ASI 4: Cha +2 = 19; ASI 8: Cha +1, Dex +1.
func test_bard_lore_levels_8_to_11_with_magical_secrets() -> void:
	var ch := _create("bard", "entertainer", {"str": 8, "dex": 14, "con": 12, "int": 13, "wis": 10, "cha": 15},
		["cha", "cha", "dex"], {"bard.cantrips": ["vicious_mockery", "minor_illusion"]})
	_level_to(ch, "bard", 8, {3: {"bard.3.bard_subclass": ["college_of_lore"]}, 4: _asi("bard", 4, ["cha", "cha"]),
		6: {"college_of_lore.6.magical_discoveries": ["magic_missile", "guiding_bolt"]}, 8: _asi("bard", 8, ["cha", "dex"])})
	_hp(ch, 51, "d8: 8 + 7 × 5, Con +1 × 8")
	assert_eq(ch.spell_slots(), _slots([4, 3, 3, 2]))
	assert_eq(ch.resource_max("bardic_inspiration"), 5, "Charisma 20")
	_level_to(ch, "bard", 9)
	assert_eq(ch.proficiency_bonus(), 4)
	_hp(ch, 57, "8 + 8 × 5 + 1 × 9")
	assert_eq(ch.spell_slots(), _slots([4, 3, 3, 3, 1]), "a 5th-level slot at 9")
	assert_eq(ch.choice("bard.prepared").count, 14)
	assert_eq(ch.choice("bard.9.expertise").count, 2, "Expertise in two more skills")
	var prep9 := ch.choice("bard.prepared")
	ChoiceOptions.populate(prep9, ch)
	assert_true(prep9.option("fireball") == null, "no Wizard spells before Magical Secrets")
	_level_to(ch, "bard", 10)
	_hp(ch, 63, "8 + 9 × 5 + 1 × 10")
	assert_eq(str(ch.class_column("bard", "bardic_die")), "d10", "Bardic die d10 at 10")
	assert_eq(ch.choice("bard.cantrips").count, 4)
	assert_eq(ch.choice("bard.prepared").count, 15)
	var prep := ch.choice("bard.prepared")
	ChoiceOptions.populate(prep, ch)
	for s: String in ["fireball", "spiritual_weapon", "call_lightning"]:
		assert_true(prep.option(s) != null and prep.option(s).legal, "Magical Secrets opens %s" % s)
	var secret := ""
	for s: String in ["fireball", "call_lightning", "spiritual_weapon"]:
		if not s in prep.picks:
			secret = s
			break
	var more: Array = ch.picks_for("bard.prepared")
	more.append(secret)
	_level_to(ch, "bard", 11, {11: {"bard.prepared": more}})
	_hp(ch, 69, "8 + 10 × 5 + 1 × 11")
	assert_eq(ch.spell_slots(), _slots([4, 3, 3, 3, 2, 1]), "a 6th-level slot at 11")
	assert_eq(ch.choice("bard.prepared").count, 16)
	var k := _known(ch, secret)
	assert_eq(str(k.get("class_id", "")), "bard", "a Magical Secret is a Bard spell")
	assert_eq(str(k.get("kind", "")), "prepared")
	assert_eq(ch.spell_save_dc("bard").total(), 17, "8 + Cha 5 + PB 4")
	assert_eq(ch.spell_attack_bonus("bard").total(), 9)
	assert_eq(_cantrip(ch, "vicious_mockery"), "3d6", "cantrips gain their third die at 11")
	assert_eq(ch.ac_value(), 14, "Leather 11 + Dex 3")
	assert_eq(ch.initiative_bonus().total(), 7, "Dex 3 + Alert 4")
	var jack := 0
	for skill: StringName in Abilities.SKILLS:
		if ch.skill_rank(skill) == 0:
			for p in ch.skill_bonus(skill).parts:
				if str(p["label"]) == "Jack of All Trades":
					jack = int(p["value"])
			break
	assert_eq(jack, 2, "Jack of All Trades: half of PB 4")


# --- Cleric --------------------------------------------------------------------------------------

## Wis 15 Con 13 Cha 12 + Acolyte (Wis +2, Cha +1) = Wis 17; ASI 4: Wis +1, Con +1 = 18, 14; ASI 8: Wis +2 = 20.
func test_cleric_life_levels_8_to_11() -> void:
	var ch := _create("cleric", "acolyte", {"str": 14, "dex": 8, "con": 13, "int": 10, "wis": 15, "cha": 12},
		["wis", "wis", "cha"], {"cleric.1.divine_order": ["protector"],
			"cleric.cantrips": ["sacred_flame", "guidance", "thaumaturgy"]})
	_level_to(ch, "cleric", 8, {3: {"cleric.3.cleric_subclass": ["life_domain"]}, 4: _asi("cleric", 4, ["wis", "con"]),
		7: {"cleric.7.blessed_strikes": ["potent_spellcasting"]}, 8: _asi("cleric", 8, ["wis", "wis"])})
	_hp(ch, 59, "d8: 8 + 7 × 5, Con +2 × 8")
	assert_eq(ch.resource_max("channel_divinity"), 3)
	assert_eq(ch.spell_slots(), _slots([4, 3, 3, 2]))
	_level_to(ch, "cleric", 9)
	_hp(ch, 66, "8 + 8 × 5 + 2 × 9")
	assert_eq(ch.spell_slots(), _slots([4, 3, 3, 3, 1]))
	for s: String in ["greater_restoration", "mass_cure_wounds"]:
		assert_eq(str(_known(ch, s).get("kind", "")), "always", "Life Domain spell at 9: %s" % s)
	_level_to(ch, "cleric", 10)
	_hp(ch, 73, "8 + 9 × 5 + 2 × 10")
	assert_eq(ch.choice("cleric.cantrips").count, 5)
	assert_eq(ch.resource_max("divine_intervention"), 1, "Divine Intervention at 10")
	_level_to(ch, "cleric", 11)
	_hp(ch, 80, "8 + 10 × 5 + 2 × 11")
	assert_eq(ch.spell_slots(), _slots([4, 3, 3, 3, 2, 1]))
	assert_eq(ch.choice("cleric.prepared").count, 16)
	assert_eq(ch.spell_save_dc("cleric").total(), 17, "8 + Wis 5 + PB 4")
	assert_eq(_cantrip(ch, "sacred_flame"), "3d8")
	assert_eq(_bonus(ch, "sacred_flame"), 5, "Potent Spellcasting adds Wisdom 20")
	assert_eq(str(ch.class_column("cleric", "divine_spark")), "2d8")
	var cure := ch.spell_preview("cure_wounds", 6)
	assert_eq(str(cure["heal_dice"]), "12d8", "2d8 + 2d8 for each of five levels above 1st")
	assert_eq((cure["heal_bonus"] as Breakdown).total(), 13, "Wis 5 + Disciple of Life 2 + 6")
	assert_eq(ch.save_bonus(&"wis").total(), 9)
	assert_eq(ch.ac_value(), 14, "Chain Shirt 13 + Dex -1 + Shield 2")


# --- Druid ---------------------------------------------------------------------------------------

## Wis 15 Con 14 + Sage (Wis +2, Con +1) = Wis 17, Con 15; ASI 4: Con +1, Wis +1 = 16, 18; ASI 8: Wis +2 = 20.
func test_druid_land_levels_8_to_11_with_natures_ward() -> void:
	var ch := _create("druid", "sage", {"str": 8, "dex": 12, "con": 14, "int": 13, "wis": 15, "cha": 10},
		["wis", "wis", "con"], {"druid.cantrips": ["thorn_whip", "guidance"]})
	_level_to(ch, "druid", 8, {3: {"druid.3.druid_subclass": ["circle_of_the_land"],
			"circle_of_the_land.3.circle_of_the_land_spells": ["arid"]},
		4: _asi("druid", 4, ["con", "wis"]), 7: {"druid.7.elemental_fury": ["potent_spellcasting"]},
		8: _asi("druid", 8, ["wis", "wis"])})
	_hp(ch, 67, "d8: 8 + 7 × 5, Con +3 × 8")
	var forms := ch.choice("druid.2.wild_shape")
	assert_eq(forms.count, mini(8, ch.beast_forms_for(forms).size()), "eight known forms at 8, capped by the bestiary")
	for f in ch.beast_forms_for(forms):
		assert_true(float(f["cr"]) <= 1.0, "%s: CR 1 at most" % f["id"])
	assert_true(bool(ch.class_column("druid", "forms_fly")), "forms with a Fly Speed from 8")
	_level_to(ch, "druid", 9)
	_hp(ch, 75, "8 + 8 × 5 + 3 × 9")
	assert_eq(ch.spell_slots(), _slots([4, 3, 3, 3, 1]))
	assert_eq(str(_known(ch, "wall_of_stone").get("class_id", "")), "druid", "arid land: Wall of Stone at 9")
	assert_eq(ch.resistance_source(&"fire"), "", "no Nature's Ward before 10")
	_level_to(ch, "druid", 10)
	_hp(ch, 83, "8 + 9 × 5 + 3 × 10")
	assert_eq(ch.choice("druid.cantrips").count, 4)
	assert_ne(ch.resistance_source(&"fire"), "", "Nature's Ward: arid gives Fire Resistance")
	assert_ne(ch.condition_immunity_source(&"poisoned"), "", "Nature's Ward: immune to Poisoned")
	_level_to(ch, "druid", 11)
	_hp(ch, 91, "8 + 10 × 5 + 3 × 11")
	assert_eq(ch.spell_slots(), _slots([4, 3, 3, 3, 2, 1]))
	assert_eq(ch.resource_max("wild_shape"), 3)
	assert_eq(ch.spell_save_dc("druid").total(), 17)
	assert_eq(_cantrip(ch, "thorn_whip"), "3d6")
	assert_eq(_bonus(ch, "thorn_whip"), 5, "Potent Spellcasting")
	# A Long Rest's new land changes the ward.
	ch.build["choices"]["circle_of_the_land.3.circle_of_the_land_spells"] = ["polar"]
	ch.refresh()
	assert_eq(ch.resistance_source(&"fire"), "")
	assert_ne(ch.resistance_source(&"cold"), "", "polar land: Cold Resistance")
	assert_eq(str(_known(ch, "cone_of_cold").get("class_id", "")), "druid")


# --- Fighter -------------------------------------------------------------------------------------

## Str 15 Con 14 Int 13 + Soldier (Str +2, Con +1) = Str 17, Con 15; ASI 4: Str +1, Con +1 = 18, 16; ASI 6: Str +2 =
## 20; ASI 8: Int +2 = 15.
func test_fighter_eldritch_knight_levels_8_to_11_with_two_extra_attacks() -> void:
	var ch := _create("fighter", "soldier", {"str": 15, "dex": 10, "con": 14, "int": 13, "wis": 12, "cha": 8},
		["str", "str", "con"], {"fighter.1.fighting_style": ["defense"]})
	_level_to(ch, "fighter", 8, {3: {"fighter.3.fighter_subclass": ["eldritch_knight"]},
		4: _asi("fighter", 4, ["str", "con"]), 6: _asi("fighter", 6, ["str", "str"]), 8: _asi("fighter", 8, ["int", "int"])})
	_hp(ch, 76, "d10: 10 + 7 × 6, Con +3 × 8")
	assert_eq(ch.spell_slots(), _slots([4, 2]), "Eldritch Knight 8: a third of 8, rounded up = 3")
	assert_eq(ch.resource_max("indomitable"), 0)
	_level_to(ch, "fighter", 9)
	_hp(ch, 85, "10 + 8 × 6 + 3 × 9")
	assert_eq(ch.resource_max("indomitable"), 1, "Indomitable at 9")
	assert_true(_has_feature(ch, "tactical_master"))
	_level_to(ch, "fighter", 10)
	_hp(ch, 94, "10 + 9 × 6 + 3 × 10")
	assert_eq(ch.resource_max("second_wind"), 4)
	assert_eq(ch.choice("fighter.1.weapon_mastery").count, 5)
	assert_eq(ch.choice("fighter.cantrips").count, 3, "Eldritch Knight cantrips at 10")
	assert_true(_has_feature(ch, "eldritch_strike"))
	assert_eq(_attacks_per_action(ch), 2)
	_level_to(ch, "fighter", 11)
	_hp(ch, 103, "10 + 10 × 6 + 3 × 11")
	assert_eq(_attacks_per_action(ch), 3, "Two Extra Attacks at 11")
	assert_eq(ch.spell_slots(), _slots([4, 3]), "a third of 11, rounded up = 4")
	assert_eq(ch.choice("fighter.prepared").count, 8)
	assert_eq(ch.ac_value(), 17, "Chain Mail 16 + Defense 1")
	assert_eq(_weapon(ch, "greatsword"), "+9, 2d6+5", "Str 5 + PB 4")
	assert_eq(ch.save_bonus(&"str").total(), 9)
	assert_eq(ch.spell_save_dc("fighter").total(), 14, "8 + Int 2 + PB 4")
	assert_eq(ch.resource_max("action_surge"), 1)


# --- Monk ----------------------------------------------------------------------------------------

## Dex 15 Wis 14 + Guide (Dex +2, Wis +1) = Dex 17, Wis 15; ASI 4: Dex +1, Wis +1 = 18, 16; ASI 8: Dex +2 = 20.
func test_monk_open_hand_levels_8_to_11() -> void:
	var ch := _create("monk", "guide", {"str": 12, "dex": 15, "con": 13, "int": 10, "wis": 14, "cha": 8},
		["dex", "dex", "wis"])
	_level_to(ch, "monk", 8, {3: {"monk.3.monk_subclass": ["warrior_of_the_open_hand"]},
		4: _asi("monk", 4, ["dex", "wis"]), 8: _asi("monk", 8, ["dex", "dex"])})
	_hp(ch, 51, "d8: 8 + 7 × 5, Con +1 × 8")
	assert_eq(ch.resource_max("focus_points"), 8)
	assert_eq(ch.speed().total(), 45)
	_level_to(ch, "monk", 9)
	_hp(ch, 57, "8 + 8 × 5 + 1 × 9")
	assert_true(_has_feature(ch, "acrobatic_movement"))
	assert_eq(WeaponProfile.unarmed(ch).damage_dice, "1d8")
	_level_to(ch, "monk", 10)
	_hp(ch, 63, "8 + 9 × 5 + 1 × 10")
	assert_eq(ch.speed().total(), 50, "Unarmored Movement +20 at 10 (%s)" % ch.speed().describe())
	assert_true(_has_feature(ch, "heightened_focus") and _has_feature(ch, "self_restoration"))
	_level_to(ch, "monk", 11)
	_hp(ch, 69, "8 + 10 × 5 + 1 × 11")
	assert_eq(ch.resource_max("focus_points"), 11)
	var fist := WeaponProfile.unarmed(ch)
	assert_eq(fist.damage_dice, "1d10", "Martial Arts die d10 at 11")
	assert_eq(fist.attack.total(), 9, "Dex 5 + PB 4")
	assert_eq(fist.damage_bonus.total(), 5)
	assert_eq(ch.ac_value(), 18, "10 + Dex 5 + Wis 3")
	assert_eq(ch.resource_max("wholeness_of_body"), 3)
	assert_true(_has_feature(ch, "fleet_step"), "Open Hand 11")
	assert_eq(_attacks_per_action(ch), 2)
	assert_eq(ch.initiative_bonus().total(), 9)
	assert_eq(ch.save_bonus(&"dex").total(), 9)


# --- Paladin -------------------------------------------------------------------------------------

## Str 15 Cha 14 + Noble (Str +1, Cha +2) = Str 16, Cha 16; ASI 4: Cha +2 = 18; ASI 8: Str +2 = 18.
func test_paladin_devotion_levels_8_to_11() -> void:
	var ch := _create("paladin", "noble", {"str": 15, "dex": 10, "con": 13, "int": 8, "wis": 12, "cha": 14},
		["str", "cha", "cha"])
	_level_to(ch, "paladin", 8, {2: {"paladin.2.fighting_style": ["blessed_warrior"],
			"paladin.2.fighting_style/blessed_warrior": ["guidance", "sacred_flame"]},
		3: {"paladin.3.paladin_subclass": ["oath_of_devotion"]}, 4: _asi("paladin", 4, ["cha", "cha"]),
		8: _asi("paladin", 8, ["str", "str"])})
	_hp(ch, 60, "d10: 10 + 7 × 6, Con +1 × 8")
	assert_eq(ch.spell_slots(), _slots([4, 3]), "half of 8 = 4")
	_level_to(ch, "paladin", 9)
	_hp(ch, 67, "10 + 8 × 6 + 1 × 9")
	assert_eq(ch.spell_slots(), _slots([4, 3, 2]), "3rd-level slots at 9: half of 9 rounded up = 5")
	assert_eq(ch.choice("paladin.prepared").count, 9)
	for s: String in ["beacon_of_hope", "dispel_magic"]:
		assert_eq(str(_known(ch, s).get("kind", "")), "always", "Oath of Devotion at 9: %s" % s)
	assert_true(_has_feature(ch, "abjure_foes"))
	_level_to(ch, "paladin", 10)
	_hp(ch, 74, "10 + 9 × 6 + 1 × 10")
	assert_ne(ch.condition_immunity_source(&"frightened"), "", "Aura of Courage")
	_level_to(ch, "paladin", 11)
	_hp(ch, 81, "10 + 10 × 6 + 1 × 11")
	assert_eq(ch.spell_slots(), _slots([4, 3, 3]))
	assert_eq(ch.choice("paladin.prepared").count, 10)
	assert_eq(ch.resource_max("paladin_channel_divinity"), 3, "a third Channel Divinity at 11")
	assert_eq(ch.resource_max("lay_on_hands"), 55)
	assert_true(_has_feature(ch, "radiant_strikes"))
	assert_eq(_weapon(ch, "longsword"), "+8, 1d8+4")
	assert_eq(ch.save_bonus(&"cha").total(), 12, "Cha 4 + PB 4 + Aura of Protection 4")
	assert_eq(ch.save_bonus(&"str").total(), 8, "Str 4 + Aura of Protection 4 (no proficiency)")
	assert_eq(ch.spell_save_dc("paladin").total(), 16, "8 + Cha 4 + PB 4")
	assert_eq(_cantrip(ch, "sacred_flame"), "3d8", "Blessed Warrior's cantrip at character level 11")
	assert_eq(ch.ac_value(), 18)
	assert_eq(_attacks_per_action(ch), 2)


# --- Ranger --------------------------------------------------------------------------------------

## Dex 15 Wis 14 + Guide (Dex +2, Wis +1) = Dex 17, Wis 15; ASI 4: Dex +1, Wis +1 = 18, 16; ASI 8: Dex +2 = 20.
func test_ranger_hunter_levels_8_to_11_with_tireless() -> void:
	var ch := _create("ranger", "guide", {"str": 12, "dex": 15, "con": 13, "int": 8, "wis": 14, "cha": 10},
		["dex", "dex", "wis"])
	_level_to(ch, "ranger", 8, {2: {"ranger.2.fighting_style": ["archery"]},
		3: {"ranger.3.ranger_subclass": ["hunter"], "hunter.3.hunters_prey": ["colossus_slayer"]},
		4: _asi("ranger", 4, ["dex", "wis"]), 8: _asi("ranger", 8, ["dex", "dex"])})
	_hp(ch, 60, "d10: 10 + 7 × 6, Con +1 × 8")
	assert_eq(ch.resource_max("spell:hunters_mark"), 3)
	_level_to(ch, "ranger", 9)
	_hp(ch, 67, "10 + 8 × 6 + 1 × 9")
	assert_eq(ch.spell_slots(), _slots([4, 3, 2]))
	assert_eq(ch.resource_max("spell:hunters_mark"), 4, "Favored Enemy 4 at 9")
	assert_eq(ch.choice("ranger.9.expertise").count, 2)
	_level_to(ch, "ranger", 10)
	_hp(ch, 74, "10 + 9 × 6 + 1 × 10")
	assert_eq(ch.resource_max("tireless"), 3, "Tireless: Wisdom 16")
	ch.add_exhaustion(2)
	ch.finish_short_rest()
	assert_eq(ch.exhaustion, 1, "Tireless: a Short Rest removes a level of Exhaustion")
	ch.finish_long_rest()
	_level_to(ch, "ranger", 11)
	_hp(ch, 81, "10 + 10 × 6 + 1 × 11")
	assert_eq(ch.spell_slots(), _slots([4, 3, 3]))
	assert_eq(ch.choice("ranger.prepared").count, 10)
	assert_eq(_weapon(ch, "longbow"), "+11, 1d8+5", "Dex 5 + PB 4 + Archery 2")
	assert_eq(ch.ac_value(), 17, "Studded Leather 12 + Dex 5")
	assert_eq(ch.speed().total(), 40)
	assert_eq(ch.spell_save_dc("ranger").total(), 15)
	assert_true(_has_feature(ch, "superior_hunters_prey"))
	assert_eq(_attacks_per_action(ch), 2)


# --- Rogue ---------------------------------------------------------------------------------------

## Dex 15 Con 13 + Charlatan (Dex +2, Con +1) = Dex 17, Con 14; ASI 4: Dex +2 = 19; ASI 8: Dex +1, Con +1 = 20, 15;
## ASI 10: Con +1, Wis +1 = 16, 13 (Con +3 from level 10, for every level).
func test_rogue_soulknife_levels_8_to_11() -> void:
	var ch := _create("rogue", "charlatan", {"str": 10, "dex": 15, "con": 13, "int": 14, "wis": 12, "cha": 8},
		["dex", "dex", "con"])
	_level_to(ch, "rogue", 8, {3: {"rogue.3.rogue_subclass": ["soulknife"]}, 4: _asi("rogue", 4, ["dex", "dex"]),
		8: _asi("rogue", 8, ["dex", "con"])})
	_hp(ch, 59, "d8: 8 + 7 × 5, Con +2 × 8")
	assert_eq(str(ch.class_column("rogue", "sneak_attack")), "4d6")
	_level_to(ch, "rogue", 9)
	_hp(ch, 66, "8 + 8 × 5 + 2 × 9")
	assert_eq(str(ch.class_column("rogue", "sneak_attack")), "5d6")
	assert_eq(ch.resource_max("psionic_energy"), 8, "eight Psionic Energy Dice at 9")
	assert_eq(str(ch.class_column("rogue", "psionic_energy_die")), "d8")
	assert_true(_has_feature(ch, "soul_blades"))
	_level_to(ch, "rogue", 10, {10: _asi("rogue", 10, ["con", "wis"])})
	_hp(ch, 83, "8 + 9 × 5 + 3 × 10 (Con 16)")
	_level_to(ch, "rogue", 11)
	_hp(ch, 91, "8 + 10 × 5 + 3 × 11")
	assert_eq(str(ch.class_column("rogue", "sneak_attack")), "6d6")
	assert_eq(str(ch.class_column("rogue", "psionic_energy_die")), "d10", "d10 Psionic dice at 11")
	assert_true(_has_feature(ch, "improved_cunning_strike"))
	assert_true(ch.has_flag("evasion"))
	assert_eq(ch.ac_value(), 16, "Leather 11 + Dex 5")
	assert_eq(_weapon(ch, "shortsword"), "+9, 1d6+5")
	assert_eq(ch.initiative_bonus().total(), 9)
	assert_eq(ch.save_bonus(&"int").total(), 6, "Int 2 + PB 4")
	assert_eq(_attacks_per_action(ch), 1, "Rogues never gain Extra Attack")


# --- Sorcerer ------------------------------------------------------------------------------------

## Cha 15 Con 14 + Noble (Cha +2, Str +1) = Cha 17; ASI 4: Cha +2 = 19; ASI 8: Cha +1, Dex +1 = 20, 14.
func test_sorcerer_draconic_levels_8_to_11() -> void:
	var ch := _create("sorcerer", "noble", {"str": 10, "dex": 13, "con": 14, "int": 8, "wis": 12, "cha": 15},
		["cha", "cha", "str"])
	_level_to(ch, "sorcerer", 8, {3: {"sorcerer.3.sorcerer_subclass": ["draconic_sorcery"]},
		4: _asi("sorcerer", 4, ["cha", "cha"]), 6: {"draconic_sorcery.6.elemental_affinity": ["fire"]},
		8: _asi("sorcerer", 8, ["cha", "dex"])})
	_hp(ch, 58, "d6: 6 + 7 × 4, Con +2 × 8, Draconic Resilience +8")
	assert_eq(ch.ac_value(), 17, "Draconic Resilience 10 + Dex 2 + Cha 5")
	_level_to(ch, "sorcerer", 9)
	_hp(ch, 65, "6 + 8 × 4 + 2 × 9 + 9")
	assert_eq(ch.spell_slots(), _slots([4, 3, 3, 3, 1]))
	for s: String in ["legend_lore", "summon_dragon"]:
		assert_eq(str(_known(ch, s).get("kind", "")), "always", "Draconic spell at 9: %s" % s)
	_level_to(ch, "sorcerer", 10)
	_hp(ch, 72, "6 + 9 × 4 + 2 × 10 + 10")
	assert_eq(ch.choice("sorcerer.2.metamagic").count, 4, "two more Metamagic options at 10")
	assert_eq(ch.metamagic.size(), 4)
	assert_eq(ch.choice("sorcerer.cantrips").count, 6)
	_level_to(ch, "sorcerer", 11)
	_hp(ch, 79, "6 + 10 × 4 + 2 × 11 + 11")
	assert_eq(ch.spell_slots(), _slots([4, 3, 3, 3, 2, 1]))
	assert_eq(ch.resource_max("sorcery_points"), 11)
	assert_eq(ch.choice("sorcerer.prepared").count, 16)
	assert_eq(_cantrip(ch, "fire_bolt"), "3d10")
	assert_eq(_bonus(ch, "fire_bolt"), 5, "Elemental Affinity adds Charisma 20")
	assert_eq(ch.spell_save_dc("sorcerer").total(), 17)
	assert_eq(ch.save_bonus(&"con").total(), 6)


# --- Warlock -------------------------------------------------------------------------------------

## Cha 15 Con 13 + Charlatan (Cha +2, Con +1) = Cha 17, Con 14; ASI 4: Cha +2 = 19; ASI 8: Cha +1, Dex +1 = 20, 15.
## A level 6 Warlock spell is added for the test so Mystic Arcanum has one to take whatever data/spells holds.
func test_warlock_fiend_levels_8_to_11_with_mystic_arcanum() -> void:
	var c := Compendium.shared()
	c.tables["spells"]["test_arcanum"] = {"id": "test_arcanum", "name": "Test Arcanum", "level": 6,
		"school": "evocation", "classes": ["warlock"], "summary": "A level 6 spell for the test."}
	var ch := _create("warlock", "charlatan", {"str": 8, "dex": 14, "con": 13, "int": 12, "wis": 10, "cha": 15},
		["cha", "cha", "con"], {"warlock.1.eldritch_invocations": ["pact_of_the_blade"],
			"warlock.cantrips": ["chill_touch", "mind_sliver"]})
	var six := ["pact_of_the_blade", "agonizing_blast", "eldritch_mind", "thirsting_blade", "devils_sight",
		"whispers_of_the_grave"]
	_level_to(ch, "warlock", 8, {
		2: {"warlock.1.eldritch_invocations": ["pact_of_the_blade", "agonizing_blast", "eldritch_mind"],
			"warlock.1.eldritch_invocations/agonizing_blast": ["chill_touch"]},
		3: {"warlock.3.warlock_subclass": ["fiend_patron"]}, 4: _asi("warlock", 4, ["cha", "cha"]),
		5: {"warlock.1.eldritch_invocations": six.slice(0, 5)},
		7: {"warlock.1.eldritch_invocations": six}, 8: _asi("warlock", 8, ["cha", "dex"])})
	_hp(ch, 59, "d8: 8 + 7 × 5, Con +2 × 8")
	assert_eq(ch.pact_magic()["count"], 2)
	assert_eq(ch.pact_magic()["level"], 4)
	var inv := ch.choice("warlock.1.eldritch_invocations")
	ChoiceOptions.populate(inv, ch)
	assert_eq(inv.option("lifedrinker").reason, "Requires Warlock level 9")
	var with_lifedrinker: Array = six.duplicate()
	with_lifedrinker.append("lifedrinker")
	_level_to(ch, "warlock", 9, {9: {"warlock.1.eldritch_invocations": with_lifedrinker}})
	_hp(ch, 66, "8 + 8 × 5 + 2 × 9")
	assert_eq(ch.pact_magic()["level"], 5, "Pact Magic slots become level 5 at 9")
	assert_eq(ch.spell_slots(), _slots([0, 0, 0, 0, 2]))
	assert_eq(ch.choice("warlock.1.eldritch_invocations").count, 7)
	assert_eq(ch.resource_max("spell:contact_other_plane"), 1, "Contact Patron")
	assert_eq(str(_known(ch, "contact_other_plane", "granted").get("class_id", "")), "warlock")
	for s: String in ["geas", "insect_plague"]:
		assert_eq(str(_known(ch, s).get("kind", "")), "always", "Fiend spell at 9: %s" % s)
	_level_to(ch, "warlock", 10, {10: {"fiend_patron.10.fiendish_resilience": ["necrotic"]}})
	_hp(ch, 73, "8 + 9 × 5 + 2 × 10")
	assert_ne(ch.resistance_source(&"necrotic"), "", "Fiendish Resilience: Necrotic")
	assert_eq(ch.choice("warlock.cantrips").count, 4)
	var fr := ch.choice("fiend_patron.10.fiendish_resilience")
	ChoiceOptions.populate(fr, ch)
	assert_true(fr.option("force") == null, "anything but Force")
	_level_to(ch, "warlock", 11, {11: {"warlock.11.mystic_arcanum": ["test_arcanum"]}})
	_hp(ch, 80, "8 + 10 × 5 + 2 × 11")
	assert_eq(ch.pact_magic()["count"], 3, "a third Pact Magic slot at 11")
	assert_eq(ch.spell_slots(), _slots([0, 0, 0, 0, 3]), "no 6th-level slots: Mystic Arcanum instead")
	assert_eq(ch.choice("warlock.prepared").count, 11)
	var arc := _known(ch, "test_arcanum")
	assert_eq(str(arc.get("kind", "")), "granted", "the arcanum is cast without a slot")
	assert_eq(str(arc.get("class_id", "")), "warlock")
	assert_eq(int(arc.get("uses", 0)), 1)
	assert_eq(ch.resource_max("spell:test_arcanum"), 1)
	assert_eq(str((ch.resources["spell:test_arcanum"] as Dictionary)["recharge"]), "long")
	assert_true(_known(ch, "test_arcanum", "prepared").is_empty() and _known(ch, "test_arcanum", "bonus").is_empty())
	var prepared := ch.choice("warlock.prepared")
	ChoiceOptions.populate(prepared, ch)
	assert_false(prepared.option("test_arcanum").legal, "level 6 spells don't fit a level 5 Pact slot")
	assert_eq(ch.spell_save_dc("warlock").total(), 17)
	assert_eq(_cantrip(ch, "chill_touch"), "3d10")
	assert_eq(_bonus(ch, "chill_touch"), 5, "Agonizing Blast")
	assert_eq(ch.resource_max("dark_ones_own_luck"), 5)
	c.tables["spells"].erase("test_arcanum")
	ch.refresh()
	assert_eq(ch.choice("warlock.11.mystic_arcanum").count, mini(1, c.spells_for("warlock", 6).size()),
		"Mystic Arcanum waits for level 6 Warlock spells")


func test_warlock_patrons_at_level_10() -> void:
	var celestial := TestChars.custom("warlock", "human", 10, {"warlock_subclass": ["celestial_patron"]}, "noble")
	var cha := celestial.ability_mod(&"cha")
	assert_eq(celestial.temp_hp, 10 + cha, "Celestial Resilience after the Long Rest: Warlock 10 + Cha")
	celestial.temp_hp = 0
	celestial.finish_short_rest()
	assert_eq(celestial.temp_hp, 10 + cha, "and after a Short Rest")
	var archfey := TestChars.custom("warlock", "human", 10, {"warlock_subclass": ["archfey_patron"]}, "noble")
	assert_ne(archfey.condition_immunity_source(&"charmed"), "", "Beguiling Defenses")
	assert_eq(archfey.resource_max("beguiling_defenses"), 1)
	var goo := TestChars.custom("warlock", "human", 10, {"warlock_subclass": ["great_old_one_patron"]}, "noble")
	assert_ne(goo.resistance_source(&"psychic"), "", "Thought Shield")
	assert_eq(str(_known(goo, "hex").get("kind", "")), "always", "Eldritch Hex")


# --- Wizard --------------------------------------------------------------------------------------

## Int 15 Con 14 + Sage (Int +2, Con +1) = Int 17, Con 15; ASI 4: Int +2 = 19; ASI 8: Int +1, Con +1 = 20, 16 (Con +3
## from level 8, for every level).
func test_wizard_evoker_levels_8_to_11() -> void:
	var ch := _create("wizard", "sage", {"str": 8, "dex": 13, "con": 14, "int": 15, "wis": 12, "cha": 10},
		["int", "int", "con"], {"wizard.cantrips": ["fire_bolt", "light", "mage_hand"]})
	_level_to(ch, "wizard", 8, {3: {"wizard.3.wizard_subclass": ["evoker"]}, 4: _asi("wizard", 4, ["int", "int"]),
		5: {"evoker.5.evocation_savant": ["fireball"]}, 8: _asi("wizard", 8, ["int", "con"])})
	_hp(ch, 58, "d6: 6 + 7 × 4, Con +3 × 8")
	assert_eq(ch.choice("wizard.spellbook").count, 20, "6 + 2 per level after the first")
	_level_to(ch, "wizard", 9)
	_hp(ch, 65, "6 + 8 × 4 + 3 × 9")
	assert_eq(ch.spell_slots(), _slots([4, 3, 3, 3, 1]))
	assert_eq(_bonus(ch, "fireball", 3), 0, "no Empowered Evocation before 10")
	_level_to(ch, "wizard", 10)
	_hp(ch, 72, "6 + 9 × 4 + 3 × 10")
	assert_eq(ch.choice("wizard.cantrips").count, 5)
	assert_eq(_bonus(ch, "fireball", 3), 5, "Empowered Evocation adds Intelligence 20")
	_level_to(ch, "wizard", 11)
	_hp(ch, 79, "6 + 10 × 4 + 3 × 11")
	assert_eq(ch.spell_slots(), _slots([4, 3, 3, 3, 2, 1]))
	assert_eq(ch.choice("wizard.prepared").count, 16)
	assert_eq(ch.choice("wizard.spellbook").count, 26)
	var book := ch.spellcasting_entry("wizard")["spellbook"] as Array
	assert_eq(book.size(), 32, "26 picks + Evocation Savant's 2 + one at 5, 7, 9 and 11")
	assert_true("fireball" in book)
	assert_eq(str(ch.spell_preview("fireball", 6)["damage_dice"]), "11d6", "8d6 + 1d6 per level above 3rd")
	assert_eq(_cantrip(ch, "fire_bolt"), "3d10")
	assert_eq(ch.spell_save_dc("wizard").total(), 17)
	assert_eq(ch.save_bonus(&"int").total(), 9)
	assert_eq(ch.ac_value(), 11)


# --- Multiclass ----------------------------------------------------------------------------------

## Sorcerer 6 / Warlock 5: Sorcerer slots alone (caster level 6), Pact Magic apart, cantrips by character level.
func test_sorcerer_6_warlock_5_at_level_11() -> void:
	var ch := _create("sorcerer", "noble", {"str": 10, "dex": 13, "con": 14, "int": 8, "wis": 12, "cha": 15},
		["cha", "cha", "str"], {"sorcerer.cantrips": ["fire_bolt", "light", "mage_hand", "prestidigitation"]})
	_level_to(ch, "sorcerer", 6, {3: {"sorcerer.3.sorcerer_subclass": ["draconic_sorcery"]},
		4: _asi("sorcerer", 4, ["cha", "cha"])})
	_level_to(ch, "warlock", 5, {3: {"warlock.3.warlock_subclass": ["fiend_patron"]}, 4: _asi("warlock", 4, ["con", "con"])})
	assert_eq(ch.class_summary(), "Sorcerer (Draconic Sorcery) 6 / Warlock (Fiend Patron) 5")
	assert_eq(ch.proficiency_bonus(), 4)
	_hp(ch, 90, "d6 6 + 5 × 4 + d8 5 × 5, Con +3 × 11, Draconic Resilience +6")
	assert_eq(ch.spellcasting_slots(), _slots([4, 3, 3]), "Sorcerer 6 alone")
	assert_eq(ch.pact_magic()["count"], 2)
	assert_eq(ch.pact_magic()["level"], 3)
	assert_eq(ch.spell_slots(), _slots([4, 3, 5]))
	assert_eq(_cantrip(ch, "fire_bolt"), "3d10", "cantrips follow character level 11")
	assert_eq(Spellcasting.slots_for([{"progression": "full", "level": 9}, {"progression": "full", "level": 2}]),
		_slots([4, 3, 3, 3, 2, 1]), "Wizard 9 / Cleric 2 = caster level 11")
	assert_eq(Spellcasting.slots_for([{"progression": "half", "level": 9}, {"progression": "full", "level": 2}]),
		_slots([4, 3, 3, 1]), "Paladin 9 / Sorcerer 2: 5 + 2 = 7")
	assert_eq(Spellcasting.slots_for([{"progression": "third", "level": 11}, {"progression": "full", "level": 1}]),
		_slots([4, 3]), "Eldritch Knight 11 / Wizard 1: 3 + 1 = 4")
