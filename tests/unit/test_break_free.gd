extends TestCase
## Getting out of holds (owner reports 2026-10-12): a hero caught in a Giant Spider's webbing has a "Break free" action
## that strikes it; any teleport leaves a place's or a holder's hold behind (a web, a net, a grapple), not a
## condition of the body or mind; and a fight's holds come off once it's over.


func _webbed(e: Encounter, hero: Combatant, spider: Combatant) -> void:
	e.monster_actions._timed_condition(spider, hero, "restrained", "permanent", "Web", [], {"object": "spider_web"})


func test_a_hero_in_spider_webbing_can_break_free() -> void:
	var e := TestCombat.open_field(3)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	var spider := TestCombat.foe(e, "giant_spider", Vector2i(8, 2))
	TestCombat.start_with(e, ilse)
	_webbed(e, ilse, spider)
	assert_true(ilse.creature.has_condition(&"restrained"), "caught")
	var cat := ActionCatalog.new(e)
	var free: Dictionary = {}
	for a in cat.actions_for(ilse):
		if str(a["id"]).begins_with("escape_object:"):
			free = a
	assert_false(free.is_empty(), "a Break free action")
	if free.is_empty():
		return
	assert_true(str(free["label"]).begins_with("Break free"), str(free["label"]))
	assert_true(str(free["sub"]).contains("AC 10"), str(free["sub"]))
	assert_true(bool(free["legal"]), str(free.get("reason", "")))
	for i in 6:
		if not ilse.creature.has_condition(&"restrained"):
			break
		TestCombat.next_d20(e, 18)
		ilse.attacks_left = 1
		var r := cat.perform(ilse, cat.find(ilse, str(free["id"])))
		assert_true(r.ok, r.reason)
	assert_false(ilse.creature.has_condition(&"restrained"), "the webbing broke and she's free")


func test_misty_step_leaves_a_web_and_a_grapple_behind_but_not_hold_person() -> void:
	var e := TestCombat.open_field(3)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	var spider := TestCombat.foe(e, "giant_spider", Vector2i(3, 2))
	TestCombat.start_with(e, ilse)
	_webbed(e, ilse, spider)
	e.grapples[ilse.id] = spider.id
	ilse.creature.add_condition(&"grappled", spider.name())
	var held := Effect.new("Hold Person", &"spell", "hold_person").with_condition(&"paralyzed")
	ilse.creature.add_effect(held)
	e.spells._teleport(ilse, Vector2i(8, 6), CombatResult.new())
	assert_false(ilse.creature.has_condition(&"restrained"), "out of the web")
	assert_false(ilse.creature.has_condition(&"grappled") or e.grapples.has(ilse.id), "out of the spider's grip")
	assert_true(ilse.creature.has_condition(&"paralyzed"), "Hold Person holds the body, wherever it is")


func test_a_fight_leaves_no_holds_behind() -> void:
	var ch := TestChars.pregen("ilse_varga", 5)
	var web := Effect.new("Web", &"spell", "web").with_condition(&"restrained")
	web.escape = {"skill": "athletics", "dc": 13}
	ch.add_effect(web)
	ch.add_condition(&"grappled", "Wolf")
	var dodge := Effect.new("Dodge", &"action", "dodge")
	dodge.ends = Effect.Ends.START_OF_TURN
	ch.add_effect(dodge)
	var aid := Effect.new("Aid", &"spell", "aid").with_modifier("hp_max", {"value": 5})
	aid.ends = Effect.Ends.LONG_REST
	ch.add_effect(aid)
	EncounterSetup.clear_fight_effects(ch)
	assert_false(ch.has_condition(&"restrained") or ch.has_condition(&"grappled"), "no holds")
	assert_false(ch.effects.has(dodge), "nothing that lasts until a turn")
	assert_true(ch.effects.has(aid), "Aid lasts its 8 hours")
