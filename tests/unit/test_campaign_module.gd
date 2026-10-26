extends TestCase
## The campaign hook (story/campaign.gd, story/campaign_module.gd, docs/plans/engine_split.md): the story engine asks the
## module data/campaign.json names; a game with no module gets the base one's neutral answers.


func after_each() -> void:
	Campaign.use(null)


func test_the_configured_module_is_strahds() -> void:
	Campaign.use(null)
	assert_true(Campaign.module() is StrahdCampaign, "data/campaign.json names the Strahd module")


func test_the_base_module_answers_for_a_game_with_no_campaign() -> void:
	var m := CampaignModule.new()
	var st := StoryState.new()
	assert_eq(m.fill("Seek {tarokka.sword.hint}.", st), "Seek {tarokka.sword.hint}.", "text is left as written")
	assert_eq(m.field(st, "ally.npc"), "")
	assert_eq(m.final_room(st), "")
	assert_true(m.treasures_at("anywhere", st).is_empty())
	assert_true(m.take_from("anywhere", st).is_empty())
	assert_eq(m.treasure_name("sunsword"), "")
	assert_true(m.reading("sword", st).is_empty())
	assert_true(m.presence_tier(st).is_empty())
	assert_eq(m.presence_tier_min("marked"), -1)
	assert_eq(m.presence_attention(st), 0)
	assert_false(m.night_between(0, 600))
	assert_false(m.visit_may_fight(st, "rest", {}))
	assert_false(m.handles_spell("augury"))
	assert_eq(m.parley_ref(), "")
	assert_true(m.parley_allows_fight(st), "no parley: the final battle goes ahead")
	assert_true(m.treasure_spots({}).is_empty())
	assert_true(m.take_treasure({}, "container", "chest", st).is_empty())
	assert_true(m.fight_start_keys().is_empty() and m.fight_victory_keys().is_empty())
	assert_eq(m.guard_monster(), "guard")
	assert_true(m.spring_trap(st, "somewhere", Vector2i.ZERO).is_empty() and m.open_way(st, "somewhere", Vector2i.ZERO).is_empty())
	assert_true(m.endings().is_empty() and m.ending("x").is_empty() and m.extra_achievements().is_empty())
	assert_true(m.skirmish_achievements(["wolf"] as Array[String]).is_empty())
	var enc := {"monsters": []}
	assert_eq(m.place_visitors(enc, [], [] as Array[Vector2i], Vector2i.ZERO), enc, "visitors are left where they are")


func test_the_engine_asks_the_module_in_place() -> void:
	Campaign.use(CampaignModule.new())
	var st := StoryState.new()
	assert_eq(Campaign.module().fill("{x}", st), "{x}")
	assert_false(Campaign.module().handles_spell("augury"), "no campaign, no field oracles: the spell is an ordinary one")
	Campaign.use(null)
	assert_true(Campaign.module().handles_spell("augury"), "Strahd's valley reads the place")


func test_the_strahd_module_hands_over_to_the_tarokka() -> void:
	var st := StoryState.new()
	st.playthrough_seed = 11
	var m := StrahdCampaign.new()
	m.ensure_drawn(st)
	assert_false(st.tarokka.is_empty(), "the reading is drawn")
	assert_eq(m.fill("Seek {tarokka.sword.hint}.", st), Tarokka.fill("Seek {tarokka.sword.hint}.", st))
	assert_eq(m.treasure_name("sunsword"), "The Sunsword")
	assert_eq(m.treasure_name("longsword"), "")
	var r := m.reading("sword", st)
	assert_eq(str(r["slot"]), "sword")
	assert_true(str(r["title"]).begins_with("The Sunsword: "), "the notice names the slot, then the card")


func test_the_strahd_module_answers_the_fight_and_ending_hooks() -> void:
	var m := StrahdCampaign.new()
	var st := StoryState.new()
	assert_eq(m.parley_ref(), "strahd/final:parley")
	assert_true(m.parley_allows_fight(st), "unanswered: the battle goes ahead")
	st.set_flag("strahd_parley", "yield")
	assert_false(m.parley_allows_fight(st), "yielding leaves it to the ending")
	assert_eq(m.guard_monster(), "vallaki_guard")
	assert_true(m.extra_achievements().has("skirmish_strahd"))
	assert_eq(m.skirmish_achievements(["strahd_von_zarovich"] as Array[String]), ["skirmish_strahd"] as Array[String])
	assert_true(m.skirmish_achievements(["wolf"] as Array[String]).is_empty())
	assert_false(m.endings().is_empty(), "the five endings")
