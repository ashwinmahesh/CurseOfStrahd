extends TestCase
## One prompt for a hero with more than one Reaction to pick from (owner report 2026-10-12: Godrick, with the
## Protection fighting style and Sentinel, was only ever asked about one of them). Protection comes before the attack
## roll; Sentinel (2024) only once the attack hits, so it's listed as "if the attack hits": picking it keeps the
## Reaction for that moment. Skipping keeps the Reaction, and a later trigger still asks.


## Godrick's build: a paladin with Protection and Sentinel and a shield, beside an ally a zombie is about to attack.
func _guard(picks: Dictionary = {"fighting_style": ["protection"], "ability_score_improvement": ["sentinel"]}) -> Dictionary:
	var e := TestCombat.open_field(3)
	var ch := TestChars.custom("paladin", "human", 4, picks)
	ch.heroic_inspiration = false
	var g := e.add(ch, &"party", Vector2i(3, 3))
	var ally := e.add(TestChars.custom("wizard", "human", 4), &"party", Vector2i(3, 4))
	(ally.creature as Character).heroic_inspiration = false
	var z := TestCombat.foe(e, "zombie", Vector2i(4, 4))
	z.creature.hp = 200
	TestCombat.start_with(e, z)
	return {"e": e, "g": g, "ally": ally, "z": z}


func _ids(e: Encounter) -> Array:
	return e.pending.target_choices.map(func(x: Dictionary) -> String: return str(x["id"]))


func _slam(f: Dictionary) -> CombatResult:
	var e := f["e"] as Encounter
	return e.attack(f["z"] as Combatant, f["ally"] as Combatant, "monster:slam")


## Declines whatever else is asked (a smite on the Opportunity Attack's hit) and returns the kinds asked.
func _decline_rest(e: Encounter) -> Array[String]:
	var kinds: Array[String] = []
	var guard := 0
	while e.pending != null and guard < 10:
		kinds.append(e.pending.kind)
		e.answer_reaction(false)
		guard += 1
	return kinds


func test_protection_and_sentinel_are_on_one_prompt() -> void:
	var f := _guard()
	var e := f["e"] as Encounter
	var g := f["g"] as Combatant
	assert_true(e.features.has_feat(g, "protection") and e.features.has_feat(g, "sentinel") and e.features.wields_shield(g), "built like Godrick")
	_slam(f)
	assert_true(e.pending != null and e.pending.kind == Reactions.CHOICE, "one prompt: %s" % (e.pending.kind if e.pending != null else "none"))
	assert_eq(e.pending.reactor_id, g.id)
	assert_eq(e.pending.title, "%s has a Reaction" % g.name())
	assert_eq(_ids(e), ["now:0", "later:sentinel"], "Protection now, Sentinel if the attack hits")
	assert_eq(str(e.pending.target_choices[0]["label"]), "Protection")
	assert_eq(str(e.pending.target_choices[1]["label"]), "Sentinel, if the attack hits")
	assert_eq(e.pending.selected_ids, ["now:0"] as Array[String], "the first is picked to start")
	assert_eq(e.pending.selection_error(), "")
	_decline_rest(e)


func test_picking_protection_uses_it_and_sentinel_isnt_asked() -> void:
	var f := _guard()
	var e := f["e"] as Encounter
	var g := f["g"] as Combatant
	_slam(f)
	TestCombat.next_d20(e, 18)
	e.answer_reaction(true)
	var kinds := _decline_rest(e)
	assert_false(g.reaction_available, "the Reaction is spent")
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("interposes a shield")), "Protection was used")
	assert_false("sentinel" in kinds or Reactions.CHOICE in kinds, "nothing else asked of it: %s" % str(kinds))


func test_keeping_it_for_sentinel_strikes_once_the_attack_hits() -> void:
	var f := _guard()
	var e := f["e"] as Encounter
	var g := f["g"] as Combatant
	_slam(f)
	e.pending.selected_ids.assign(["later:sentinel"])
	TestCombat.next_d20(e, 19)
	e.answer_reaction(true)
	var kinds := _decline_rest(e)
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("keeps its Reaction for Sentinel")), "logged as kept: %s" % str(e.log.texts()))
	assert_false(e.log.texts().any(func(t: String) -> bool: return t.contains("interposes a shield")), "no Protection")
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("Zombie hits")), "the slam hit")
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("%s makes an Opportunity Attack against Zombie" % g.name())), "Sentinel struck without asking again")
	assert_false("sentinel" in kinds, "not asked twice: %s" % str(kinds))
	assert_false(g.reaction_available)


func test_kept_for_sentinel_and_missed_keeps_the_reaction() -> void:
	var f := _guard()
	var e := f["e"] as Encounter
	var g := f["g"] as Combatant
	_slam(f)
	e.pending.selected_ids.assign(["later:sentinel"])
	TestCombat.next_d20(e, 1)
	e.answer_reaction(true)
	_decline_rest(e)
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("Zombie misses")), "the slam missed")
	assert_true(g.reaction_available, "the Reaction is still there")
	assert_false(e.log.texts().any(func(t: String) -> bool: return t.contains("Opportunity Attack")))


func test_skipping_keeps_it_and_sentinel_still_asks_on_the_hit() -> void:
	var f := _guard()
	var e := f["e"] as Encounter
	var g := f["g"] as Combatant
	_slam(f)
	TestCombat.next_d20(e, 19)
	e.answer_reaction(false)
	assert_true(e.pending != null and e.pending.kind == "sentinel", "asked at its own trigger: %s" % (e.pending.kind if e.pending != null else "none"))
	assert_true(e.pending.text.contains("hits someone else"), e.pending.text)
	e.answer_reaction(true)
	_decline_rest(e)
	assert_false(g.reaction_available)
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("makes an Opportunity Attack")))


func test_one_reaction_keeps_its_own_prompt() -> void:
	var f := _guard({"fighting_style": ["protection"], "ability_score_improvement": ["ability_score_improvement"]})
	var e := f["e"] as Encounter
	_slam(f)
	assert_true(e.pending != null and e.pending.kind == "protection", "Protection alone: %s" % (e.pending.kind if e.pending != null else "none"))
	_decline_rest(e)


func test_a_reaction_set_to_off_is_left_out() -> void:
	var f := _guard()
	var e := f["e"] as Encounter
	(f["g"] as Combatant).reaction_rules["sentinel"] = "never"
	_slam(f)
	assert_true(e.pending != null and e.pending.kind == "protection", "Sentinel is Off: %s" % (e.pending.kind if e.pending != null else "none"))
	_decline_rest(e)


func test_reactions_on_automatic_still_happen_by_themselves() -> void:
	var f := _guard()
	var e := f["e"] as Encounter
	var g := f["g"] as Combatant
	g.reaction_rules["protection"] = "auto"
	_slam(f)
	var kinds := _decline_rest(e)
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("interposes a shield")), "Protection on Automatic")
	assert_false(Reactions.CHOICE in kinds, str(kinds))


## Interception (2024: "when a creature you can see hits another creature within 5 feet of you") and Sentinel: asked
## against the damage, with Sentinel still to come.
func test_interception_lists_sentinel_after_it() -> void:
	var e := TestCombat.open_field(3)
	var ch := TestChars.custom("fighter", "human", 4, {"fighting_style": ["interception"], "ability_score_improvement": ["sentinel"]})
	ch.heroic_inspiration = false
	var g := e.add(ch, &"party", Vector2i(3, 3))
	var ally := e.add(TestChars.custom("wizard", "human", 4), &"party", Vector2i(3, 4))
	(ally.creature as Character).heroic_inspiration = false
	var z := TestCombat.foe(e, "zombie", Vector2i(4, 4))
	z.creature.hp = 200
	TestCombat.start_with(e, z)
	assert_true(e.features.has_feat(g, "interception") and e.features.has_feat(g, "sentinel"))
	TestCombat.next_d20(e, 19)
	e.attack(z, ally, "monster:slam")
	assert_true(e.pending != null and e.pending.kind == Reactions.CHOICE, "one prompt: %s" % (e.pending.kind if e.pending != null else "none"))
	assert_eq(_ids(e), ["now:0", "later:sentinel"])
	assert_eq(str(e.pending.target_choices[0]["label"]), "Interception")
	e.pending.selected_ids.assign(["later:sentinel"])
	e.answer_reaction(true)
	_decline_rest(e)
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("makes an Opportunity Attack")), "Sentinel once the hit is done")
	assert_false(e.log.texts().any(func(t: String) -> bool: return t.contains("Interception")), "no Interception")


## A readied attack and Sentinel, both waiting for the zombie's attack to be done: one prompt.
func test_queued_reactions_share_a_prompt() -> void:
	var f := _guard({"fighting_style": ["defense"], "ability_score_improvement": ["sentinel"]})
	var e := f["e"] as Encounter
	var g := f["g"] as Combatant
	g.readied = {"option": str(e.best_melee_option(g, f["z"] as Combatant)["id"]), "trigger": "attack"}
	TestCombat.next_d20(e, 19)
	_slam(f)
	assert_true(e.pending != null and e.pending.kind == Reactions.CHOICE, "one prompt: %s" % (e.pending.kind if e.pending != null else "none"))
	var labels: Array = e.pending.target_choices.map(func(x: Dictionary) -> String: return str(x["label"]))
	assert_true("Readied attack" in labels and "Sentinel" in labels, str(labels))
	e.pending.selected_ids.assign([str(e.pending.target_choices[labels.find("Sentinel")]["id"])])
	e.answer_reaction(true)
	var kinds := _decline_rest(e)
	assert_false("readied_attack" in kinds or "sentinel" in kinds, "the other isn't asked after: %s" % str(kinds))
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("makes an Opportunity Attack")))


## The same moment, any Reactions: one prompt, and the ones that aren't Reactions (a Luck Point) asked on their own.
func test_offers_at_one_moment_share_a_prompt() -> void:
	var f := _guard()
	var e := f["e"] as Encounter
	var g := f["g"] as Combatant
	var used: Array[String] = []
	var mk := func(kind: String, title: String, cost: String) -> Dictionary:
		return {"kind": kind, "reactor": g, "title": title, "text": "%s text" % kind, "cost": cost,
			"use": func() -> void: used.append(kind)}
	var chain: Array = [mk.call("one", "Reaction: One?", "Reaction"), mk.call("luck", "Lucky?", "A Luck Point"),
		mk.call("two", "Reaction: Two?", "Reaction and a spell slot")]
	var done := func() -> CombatResult: return CombatResult.new()
	var r := e.reactions.offer(chain, done, CombatResult.new())
	assert_true(r.is_paused() and e.pending.kind == Reactions.CHOICE)
	assert_eq(e.pending.target_choices.map(func(x: Dictionary) -> String: return str(x["label"])), ["One", "Two"])
	assert_eq(str(e.pending.choice("now:1")["cost"]), "Reaction and a spell slot", "each keeps its cost")
	e.pending.selected_ids.assign(["now:1"])
	e.answer_reaction(true)
	assert_eq(used, ["two"] as Array[String])
	assert_true(e.pending != null and e.pending.kind == "luck", "the Luck Point is asked on its own")
	e.answer_reaction(false)
	assert_eq(e.pending, null)
	assert_eq(used, ["two"] as Array[String], "One isn't asked again")


## Polearm Master's Reactive Strike and an attack readied for a foe coming close: the same step sets off both.
func test_reactive_strike_and_a_readied_attack_share_a_prompt() -> void:
	var e := TestCombat.open_field(3)
	var ch := TestChars.custom("fighter", "human", 4, {"ability_score_improvement": ["polearm_master"]})
	ch.heroic_inspiration = false
	ch.add_item("quarterstaff")
	assert_true(ch.equip("quarterstaff", "main_hand"), "a quarterstaff in hand")
	var g := e.add(ch, &"party", Vector2i(3, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(8, 3))
	z.creature.hp = 200
	TestCombat.start_with(e, z)
	assert_false(e.weapons._polearm_option(g).is_empty(), "the quarterstaff counts for Polearm Master")
	g.readied = {"option": str(e.weapons._polearm_option(g)["id"]), "trigger": "approach"}
	z.movement_left = 30
	e.move(z, Vector2i(4, 3))
	assert_true(e.pending != null and e.pending.kind == Reactions.CHOICE, "one prompt: %s" % (e.pending.kind if e.pending != null else "none"))
	assert_eq(e.pending.target_choices.map(func(x: Dictionary) -> String: return str(x["label"])), ["Reactive Strike", "Readied attack"])
	e.pending.selected_ids.assign(["now:1"])
	e.answer_reaction(true)
	var kinds := _decline_rest(e)
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("readied attack goes off")), "the readied attack")
	assert_false("reactive_strike" in kinds or "readied_attack" in kinds, str(kinds))
	assert_false(g.reaction_available)
