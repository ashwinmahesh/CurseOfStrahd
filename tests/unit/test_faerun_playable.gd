extends TestCase
## Faerûn and Arcana Unleashed entries that are switched on (`"playable": true`), checked through the real data and
## the real creation, level-up and combat paths, without BookContentFixture: what a player picks is what works.

const BACKGROUNDS := ["chondathan_freebooter", "dead_magic_dweller", "flaming_fist_mercenary", "genie_touched",
	"ice_fisher", "moonwell_pilgrim", "mulhorandi_tomb_raider", "mythalkeeper", "rashemi_wanderer", "shadowmasters_exile",
	"agent_of_the_ninth_quill", "bejeweled_conclave_spy", "seer_apprentice", "cosmic_dawn_experiment"]


func _cast(e: Encounter, c: Combatant, id: String, targets: Array = [], point: Vector2 = Vector2.INF, opts: Dictionary = {}) -> CombatResult:
	var data := Compendium.shared().spell_data(id)
	return e.spells.cast_with_numbers(c, id, int(data["level"]), targets, point,
		{"dc": Breakdown.new("DC").add("test", 40), "attack": Breakdown.new("Attack").add("test", 30), "mod": 5}, opts)


func _has_item(ch: Character, id: String) -> bool:
	return ch.inventory.any(func(x: Dictionary) -> bool: return str(x.get("id", "")) == id)


func test_switched_on_backgrounds_are_offered_and_give_feat_skills_tool_and_gear() -> void:
	var comp := Compendium.shared()
	var offered := comp.all_playable("backgrounds").map(func(b: Dictionary) -> String: return str(b["id"]))
	for id: String in BACKGROUNDS:
		var bg := comp.background_data(id)
		assert_true(id in offered, "%s is offered at creation" % id)
		var ch := TestChars.custom("wizard", "human", 1, {}, id)
		var feats := ch.feats_taken.map(func(f: Dictionary) -> String: return str(f["id"]))
		assert_true(str(bg["feat"]) in feats, "%s grants %s" % [id, bg["feat"]])
		for s: Variant in bg["skills"]:
			assert_true(ch.has_proficiency("skills", str(s)), "%s: %s" % [id, s])
		var tool := bg.get("tool", {}) as Dictionary
		var tool_id := str(tool.get("id", ""))
		if tool.has("choice"):
			# A choice of tools (Cosmic Dawn Experiment: any Artisan's Tools), like the PHB's Artisan.
			assert_eq(ch.picks_for("background.tool").size(), 1, "%s: one tool picked" % id)
			tool_id = ch.picks_for("background.tool")[0]
		assert_true(ch.has_proficiency("tools", tool_id), "%s: %s" % [id, tool_id])
		for it: Variant in ((bg["equipment"] as Array)[0] as Dictionary).get("items", []):
			assert_true(_has_item(ch, str((it as Dictionary)["id"])), "%s's gear: %s" % [id, (it as Dictionary)["id"]])


func test_magic_initiate_backgrounds_name_their_spell_list() -> void:
	var genie := TestChars.custom("fighter", "human", 1, {}, "genie_touched")
	var pilgrim := TestChars.custom("fighter", "human", 1, {}, "moonwell_pilgrim")
	for ch: Character in [genie, pilgrim]:
		var list := str((Compendium.shared().background_data(str(ch.build["background"]))["feat_params"] as Dictionary)["list"])
		var granted := ch.known_spells().filter(func(s: Dictionary) -> bool: return list in (Compendium.shared().spell_data(str(s["id"])).get("classes", []) as Array))
		assert_true(granted.size() >= 3, "two cantrips and a level 1 spell from the %s list: %s" % [list, granted.map(func(s: Dictionary) -> String: return str(s["id"]))])


func test_arcane_eloquence_prepares_vicious_mockery_and_adds_a_d4_to_social_checks() -> void:
	var ch := TestChars.custom("fighter", "human", 1, {"casting_ability": ["cha"]}, "bejeweled_conclave_spy")
	assert_true(ch.knows_spell("vicious_mockery"), "always prepared")
	for skill: String in ["deception", "intimidation", "persuasion"]:
		var keys := ch.check_keys(StringName(skill))
		assert_true(ch.modifiers_for(&"bonus_die").any(func(m: Modifier) -> bool: return m.matches_any(keys)), "1d4 on %s" % skill)
	assert_false(ch.modifiers_for(&"bonus_die").any(func(m: Modifier) -> bool: return m.matches_any(ch.check_keys(&"athletics"))), "not on Athletics")


func test_arcane_warrior_is_a_fighting_style_with_two_wizard_cantrips() -> void:
	var ch := TestChars.custom("fighter", "human", 1, {"fighting_style": ["arcane_warrior"]})
	var feats := ch.feats_taken.map(func(f: Dictionary) -> String: return str(f["id"]))
	assert_true("arcane_warrior" in feats, "offered as a Fighting Style")
	var cantrips := ch.known_spells().filter(func(s: Dictionary) -> bool:
		var d := Compendium.shared().spell_data(str(s["id"]))
		return int(d.get("level", -1)) == 0 and "wizard" in (d.get("classes", []) as Array))
	assert_eq(cantrips.size(), 2, "two Wizard cantrips")


func test_unfettered_mind_gives_intelligence_saves_or_another_one() -> void:
	var plain := TestChars.custom("cleric", "human", 6, {"cleric_subclass": ["knowledge_domain"]})
	assert_true(plain.save_proficiency(&"int") != "", "Intelligence saves by default")
	var other := TestChars.custom("cleric", "human", 6, {"cleric_subclass": ["knowledge_domain"], "unfettered_mind": ["constitution"]})
	assert_true(other.save_proficiency(&"con") != "", "another save when Intelligence is already there")
	assert_eq(TestChars.custom("cleric", "human", 5, {"cleric_subclass": ["knowledge_domain"]}).save_proficiency(&"int"), "", "not before level 6")


func test_switched_on_spells_cast_from_the_hotbar() -> void:
	var comp := Compendium.shared()
	var e := TestCombat.open_field(3)
	var on: Array[String] = []
	for s in comp.all_playable("spells"):
		if str((s.get("source", {}) as Dictionary).get("book", "")) in ["FRHoF", "AU"]:
			on.append(str(s["id"]))
	assert_true(on.size() >= 30, "the batch 1 spells are on: %d" % on.size())
	var c := TestCombat.caster_with(e, on, Vector2i(2, 3), 20)
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	var catalog := ActionCatalog.new(e)
	for id in on:
		assert_false(comp.spell_data(id).get("automation", "") == "reference", "%s has rules, not just text" % id)
		var a := catalog.find(c, "spell:" + id)
		if str(comp.spell_data(id)["casting_time"].get("unit", "")) == "reaction":
			continue
		assert_false(a.is_empty(), "%s on the hotbar" % id)
		assert_ne(str(a.get("reason", "")), "Not automated yet", id)


func test_laerals_silver_lance_knocks_failed_foes_prone_and_spares_allies() -> void:
	var e := TestCombat.encounter(["..............................", "..............................", "..............................",
		"..............................", ".............................."], 1)
	var c := TestCombat.caster_with(e, ["laerals_silver_lance"], Vector2i(1, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(4, 3), 500)
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(6, 3))
	var far := TestCombat.punching_bag(e, Vector2i(24, 3), 500)
	TestCombat.start_with(e, c)
	var before := ally.creature.hp
	assert_true(_cast(e, c, "laerals_silver_lance", [], Vector2.INF, {"direction": Vector2.RIGHT}).ok)
	assert_true(foe.creature.hp < 500, "Force damage")
	assert_true(foe.creature.has_condition(&"prone"), "Prone on a failed save")
	assert_eq(ally.creature.hp, before, "creatures you choose: allies are spared")
	assert_true(far.creature.hp < 500, "the line reaches 120 feet")


func test_inflict_doubt_and_fractured_awareness_give_disadvantage_until_a_save() -> void:
	for id: String in ["inflict_doubt", "fractured_awareness"]:
		var e := TestCombat.open_field(1)
		var c := TestCombat.caster_with(e, [id], Vector2i(2, 3))
		var t := TestCombat.punching_bag(e, Vector2i(5, 3), 500)
		TestCombat.start_with(e, c)
		assert_true(_cast(e, c, id, [t]).ok, id)
		for keys: Array[String] in [["attack"] as Array[String], t.creature.save_keys(&"dex"), t.creature.check_keys(&"athletics")]:
			assert_false((t.creature.d20_sources(keys)["disadvantage"] as Array).is_empty(), "%s: Disadvantage on %s" % [id, keys])
		assert_eq(t.creature.hp < 500, id == "fractured_awareness", "%s's damage" % id)
		var fx := t.creature.effects.filter(func(x: Effect) -> bool: return x.source_id == id)
		assert_eq(fx.size(), 1, "%s: one effect, one repeat save" % id)
		(fx[0] as Effect).repeat_save["dc"] = 1
		e.spells._repeat_save(t, fx[0] as Effect, [])
		assert_true((t.creature.d20_sources(["attack"])["disadvantage"] as Array).is_empty(), "%s ends on a successful save" % id)


func test_entrancing_mirrors_stun_and_slow_end_together() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["entrancing_mirrors"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(5, 3), 500)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "entrancing_mirrors", [t]).ok)
	assert_true(t.creature.has_condition(&"stunned"))
	assert_true(t.creature.hp < 500)
	var fx := t.creature.effects.filter(func(x: Effect) -> bool: return x.source_id == "entrancing_mirrors")
	assert_eq(fx.size(), 1, "Stunned and the halved Speed are one effect with one repeat save")
	(fx[0] as Effect).repeat_save["dc"] = 1
	e.spells._repeat_save(t, fx[0] as Effect, [])
	assert_false(t.creature.has_condition(&"stunned"))
	assert_true(t.creature.modifiers_for(&"speed_percent").is_empty(), "the slow ends with it")


func test_invulnerability_and_iron_body_protect_as_written() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["invulnerability", "iron_body"], Vector2i(2, 3), 20)
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "invulnerability").ok)
	var hp := c.creature.hp
	c.creature.take_damage(30, &"fire")
	c.creature.take_damage(30, &"force")
	assert_eq(c.creature.hp, hp, "immune to every damage type")
	c.creature.concentration.end("test")
	c.action_available = true
	c.magic_action_used = false
	ally.creature.add_condition(&"poisoned", "test")
	assert_true(_cast(e, c, "iron_body", [ally]).ok)
	assert_false(ally.creature.has_condition(&"poisoned"), "Poisoned ends on casting")
	assert_true(ally.creature.is_condition_immune(&"exhaustion"), "no Exhaustion")
	assert_true(ally.creature.is_condition_immune(&"paralyzed"))
	var before := ally.creature.hp
	ally.creature.take_damage(10, &"slashing")
	assert_eq(ally.creature.hp, before - 5, "Slashing resisted")
	ally.creature.take_damage(10, &"poison")
	assert_eq(ally.creature.hp, before - 5, "Poison immune")


func test_cacophonic_shield_resists_thunder_and_hinders_ranged_attacks() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["cacophonic_shield"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 500)
	var last := TestCombat.punching_bag(e, Vector2i(10, 6), 500)
	TestCombat.start_with(e, c)
	t.initiative = 20
	last.initiative = 10
	e.order.sort_custom(func(x: Combatant, y: Combatant) -> bool: return x.initiative > y.initiative)
	assert_true(_cast(e, c, "cacophonic_shield").ok)
	assert_eq(t.creature.hp, 500, "nothing at casting: it triggers on entering, being swept over, or ending a turn inside")
	e.end_turn()
	e.end_turn()
	assert_true(t.creature.hp < 500, "a creature ending its turn inside takes Thunder")
	assert_true(t.creature.has_condition(&"deafened"), "and is Deafened on a failure, until the caster's next turn")
	var before := c.creature.hp
	c.creature.take_damage(10, &"thunder")
	assert_eq(c.creature.hp, before - 5, "the caster resists Thunder")
	assert_true(c.creature.modifiers_for(&"attacked_with").any(func(m: Modifier) -> bool: return m.text("attack_kind") == "ranged" and m.text("value") == "disadvantage"))


func test_elminsters_elusion_turns_half_damage_into_none_against_spells() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["elminsters_elusion"], Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "elminsters_elusion").ok)
	assert_true(c.creature.has_flag("circle_of_power"))
	assert_false((c.creature.d20_sources(["save:wis", "save_vs:spell"])["advantage"] as Array).is_empty(), "Advantage against spells")
	assert_true((c.creature.d20_sources(["save:wis"])["advantage"] as Array).is_empty(), "not against plain saves")


func test_a_data_feature_in_use_shows_its_own_effect() -> void:
	var e := TestCombat.open_field(1)
	var spy := e.add(TestChars.custom("rogue", "human", 1, {}, "agent_of_the_ninth_quill"), &"party", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, spy)
	var catalog := ActionCatalog.new(e)
	var a := catalog.find(spy, "feat:recipe:arcane_infiltrator_benefit")
	assert_false(a.is_empty(), "Cunning Diversion on the hotbar")
	e.drain_events()
	assert_true(catalog.perform(spy, a).ok)
	var ev := e.drain_events().filter(func(x: Dictionary) -> bool: return str(x["type"]) == "ability")
	assert_eq(ev.size(), 1, "an ability event for the view")
	assert_eq(str((ev[0] as Dictionary)["key"]), "arcane_infiltrator_benefit", "keyed by the feature, not the recipe")
	assert_eq(str(SpellFx.ability_cue("feature", "arcane_infiltrator_benefit", spy)["family"]), "buff")
	assert_eq(ActionCatalog.ability_key({"id": "feat:recipe:bladesong:dismiss", "kind": "feat"}), "", "ending one shows nothing")
