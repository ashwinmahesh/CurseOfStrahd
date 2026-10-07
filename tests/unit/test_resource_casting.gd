extends TestCase

var _book_content: BookContentFixture

func before_each() -> void:
	_book_content = BookContentFixture.new()

func after_each() -> void:
	_book_content.restore()

func knowledge(level: int = 9) -> Character:
	return TestChars.custom("cleric", "human", level, {"cleric_subclass": ["knowledge_domain"]})

func test_prepared_domain_filter_and_level_gates() -> void:
	var ch := knowledge(3)
	for id: String in ["comprehend_languages", "detect_magic", "detect_thoughts", "identify", "mind_spike"]:
		assert_eq(ch.resource_casts(id).size(), 1, id)
	for id: String in ["command", "tongues", "arcane_eye", "legend_lore", "scrying", "guidance"]:
		assert_true(ch.resource_casts(id).is_empty(), id)
	assert_eq(knowledge(9).resource_casts("legend_lore").size(), 1)
	assert_true(TestChars.custom("cleric", "human", 9).resource_casts("mind_spike").is_empty())

func test_mind_magic_pays_channel_divinity_and_preserves_slot_cast_limit() -> void:
	var e := TestCombat.open_field()
	var ch := knowledge(3)
	var c := e.add(ch, &"party", Vector2i(2, 3))
	var target := TestCombat.punching_bag(e, Vector2i(3, 3), 500)
	TestCombat.start_with(e, c)
	c.cast_slot_spell_this_turn = true
	for level in range(1, 10):
		while ch.slots_left(level) > 0:
			ch.expend_slot(level)
	var catalog := ActionCatalog.new(e)
	var action := catalog.find(c, "spell:mind_spike:knowledge_mind_magic")
	assert_false(action.is_empty())
	assert_true(bool(action["legal"]))
	assert_eq(catalog.level_choices(c, action), [2])
	var uses := ch.resource_left("channel_divinity")
	TestCombat.next_d20(e, 1)
	assert_true(catalog.perform(c, action, [target]).ok)
	assert_true(target.creature.hp < 500)
	assert_true(target.creature.has_flag("tracked_by:" + c.id))
	assert_eq(ch.resource_left("channel_divinity"), uses - 1)
	assert_true(c.cast_slot_spell_this_turn, "does not erase a previous slot cast")
	assert_false(c.action_available)
	assert_true(c.magic_action_used)
	assert_true(c.bonus_available)
	assert_true(ch.concentration != null)
	c.reset_turn()
	assert_true(catalog.perform(c, catalog.find(c, "spell:mind_spike:knowledge_mind_magic"), [target]).ok)
	assert_false(c.cast_slot_spell_this_turn, "does not count as spending a slot")

func test_invalid_targets_feature_combinations_and_exhaustion_cost_nothing() -> void:
	var e := TestCombat.open_field()
	var ch := knowledge()
	var c := e.add(ch, &"party", Vector2i(2, 3))
	var target := TestCombat.punching_bag(e, Vector2i(3, 3), 500)
	TestCombat.start_with(e, c)
	var uses := ch.resource_left("channel_divinity")
	var opts := {"resource_cast": "knowledge_mind_magic"}
	assert_false(e.spells.cast(c, "mind_spike", 2, [], Vector2.INF, Vector2.ZERO, opts).ok)
	assert_false(e.spells.cast(c, "command", 1, [target], Vector2.INF, Vector2.ZERO, opts).ok)
	assert_false(e.spells.cast(c, "mind_spike", 3, [target], Vector2.INF, Vector2.ZERO, opts).ok)
	for key: String in ["slot_boost", "spell_sequence", "war_magic", "splintered"]:
		var mixed := opts.duplicate()
		mixed[key] = true if key in ["war_magic", "splintered"] else "another_feature"
		assert_false(e.spells.cast(c, "mind_spike", 2, [target], Vector2.INF, Vector2.ZERO, mixed).ok)
	assert_eq(ch.resource_left("channel_divinity"), uses)
	assert_true(c.action_available)
	ch.spend_resource("channel_divinity", uses)
	assert_false(e.spells.cast(c, "mind_spike", 2, [target], Vector2.INF, Vector2.ZERO, opts).ok)
	assert_true(c.action_available)
	ch.finish_long_rest()
	ch.add_condition(&"stunned", "test")
	assert_false(e.spells.cast(c, "mind_spike", 2, [target], Vector2.INF, Vector2.ZERO, opts).ok)
	assert_eq(ch.resource_left("channel_divinity"), ch.resource_max("channel_divinity"))

func test_resource_cast_uses_own_class_even_with_another_spell_source() -> void:
	var e := TestCombat.open_field()
	var ch := knowledge()
	var wizard := ch.spellcasting[0].duplicate(true)
	wizard["class_id"] = "wizard"
	wizard["ability"] = "int"
	ch.spellcasting.push_front(wizard)
	var c := e.add(ch, &"party", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(3, 3))
	TestCombat.start_with(e, c)
	var entry := e.spells.resource_cast_entry(c, Compendium.shared().spell_data("mind_spike"), "knowledge_mind_magic")
	assert_eq(entry["class_id"], "cleric")
	assert_eq((e.spells.numbers(c, entry)["dc"] as Breakdown).total(), ch.spell_save_dc("cleric").total())

func test_exploration_casts_with_resource_and_rejects_forged_requests() -> void:
	var st := StoryState.new()
	var ch := knowledge()
	st.party.assign([ch])
	for level in range(1, 10):
		while ch.slots_left(level) > 0:
			ch.expend_slot(level)
	var options := FieldCasting.utility_options(st.party, ch, DiceRoller.new(1))
	var option := options.filter(func(o: Dictionary) -> bool: return str(o["id"]) == "legend_lore")[0] as Dictionary
	assert_eq((option["resource_casts"] as Array).size(), 1)
	assert_false(bool(option["legal"]), "ordinary casting still requires a slot")
	var uses := ch.resource_left("channel_divinity")
	var before := st.total_minutes()
	assert_true(bool(FieldCasting.cast_utility(st, ch, "legend_lore", false, 0, "knowledge_mind_magic")["ok"]))
	assert_eq(ch.resource_left("channel_divinity"), uses - 1)
	assert_eq(st.total_minutes(), before + 1, "feature uses its Magic action, not the spell's longer casting time")
	assert_true(bool(FieldCasting.cast_utility(st, ch, "detect_magic", false, 0, "knowledge_mind_magic")["ok"]))
	assert_true(st.spell_active("detect_magic"))
	uses = ch.resource_left("channel_divinity")
	for id: String in ["command", "mind_spike", "fireball", "unknown"]:
		assert_false(bool(FieldCasting.cast_utility(st, ch, id, false, 0, "knowledge_mind_magic")["ok"]))
	assert_false(bool(FieldCasting.cast_utility(st, ch, "identify", true, 0, "knowledge_mind_magic")["ok"]))
	assert_false(bool(FieldCasting.cast_utility(st, ch, "identify", false, 2, "knowledge_mind_magic")["ok"]))
	assert_eq(ch.resource_left("channel_divinity"), uses)
	ch.spend_resource("channel_divinity", uses)
	assert_false(bool(FieldCasting.cast_utility(st, ch, "identify", false, 0, "knowledge_mind_magic")["ok"]))

func test_resource_cast_recipe_is_reusable_without_feature_id_checks() -> void:
	var ch := knowledge()
	for feature in ch.features:
		if feature.has("resource_cast"):
			feature["id"] = "other_divination"
			(feature["resource_cast"] as Dictionary)["cost"] = 2
	var e := TestCombat.open_field()
	var c := e.add(ch, &"party", Vector2i(2, 3))
	var target := TestCombat.punching_bag(e, Vector2i(3, 3), 500)
	TestCombat.start_with(e, c)
	var uses := ch.resource_left("channel_divinity")
	assert_true(e.spells.cast(c, "mind_spike", 2, [target], Vector2.INF, Vector2.ZERO, {"resource_cast": "other_divination"}).ok)
	assert_eq(ch.resource_left("channel_divinity"), uses - 2)
