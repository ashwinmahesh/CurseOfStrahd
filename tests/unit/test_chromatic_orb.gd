extends TestCase
## Chromatic Orb's leap (2024; SpellAttacks): two or more matching d8s on a hit send the orb on to a different creature
## within 30 ft of the one it hit, with a new attack roll and new damage, up to the slot level in leaps and never twice
## at one creature. On the caster's own turn a prompt asks where, the foe nearest the caster already picked; the AI and
## the prompt's Auto rule send it to that foe.


## The caster at (0, 4), the orb's first target at (4, 0); within 30 ft of that target a foe at (5, 2) and an ally at
## (3, 1); a foe at (11, 7) is 35 ft away.
func _scene(seed_value: int) -> Dictionary:
	var e := TestCombat.open_field(seed_value)
	var c := TestCombat.high_caster(e, ["chromatic_orb"], Vector2i(0, 4))
	TestCombat.give_components(c.creature as Character, ["chromatic_orb"])
	var first := TestCombat.punching_bag(e, Vector2i(4, 0), 300)
	var near := TestCombat.punching_bag(e, Vector2i(5, 2), 300)
	var far := TestCombat.punching_bag(e, Vector2i(11, 7), 300)
	var ally := e.add(TestChars.dummy(300, false, {"type": "humanoid", "ac": 1,
		"abilities": {"str": 1, "dex": 1, "con": 1, "int": 1, "wis": 1, "cha": 1}}), &"party", Vector2i(3, 1))
	TestCombat.start_with(e, c)
	return {"e": e, "c": c, "first": first, "near": near, "far": far, "ally": ally}


## The first seed whose level 3 orb hits with matching dice, cast with `rule` as the caster's Ask / Auto / Never rule.
func _leaping(rule: String = "") -> Dictionary:
	for seed_value in range(1, 120):
		var s := _scene(seed_value)
		var e := s["e"] as Encounter
		var c := s["c"] as Combatant
		if rule != "":
			c.reaction_rules[SpellAttacks.ORB_LEAP] = rule
		var r := e.spells.cast(c, "chromatic_orb", 3, [s["first"]], Vector2.INF, Vector2.ZERO, {"choice": "fire"})
		if not r.ok:
			continue
		var leapt := e.log.texts().any(func(t: String) -> bool: return t.contains("The orb leaps to"))
		if (e.pending != null and e.pending.kind == SpellAttacks.ORB_LEAP) or leapt:
			s["r"] = r
			return s
	return {}


func _ids(req: ReactionRequest) -> Array:
	return req.target_choices.map(func(t: Dictionary) -> String: return str(t["id"]))


func test_the_caster_chooses_where_the_orb_leaps() -> void:
	var s := _leaping()
	assert_false(s.is_empty(), "a seed with matching dice")
	var e := s["e"] as Encounter
	var req := e.pending
	assert_true(req != null and req.kind == SpellAttacks.ORB_LEAP, "a prompt on the caster's own turn")
	assert_false(req.spends_reaction)
	var ids := _ids(req)
	assert_true((s["near"] as Combatant).id in ids and (s["ally"] as Combatant).id in ids, "anyone within 30 ft: %s" % str(ids))
	for k: String in ["c", "first", "far"]:
		assert_false((s[k] as Combatant).id in ids, "%s can't be leapt to" % k)
	assert_eq(req.selected_ids.size(), 1)
	assert_eq(str(req.selected_ids[0]), (s["near"] as Combatant).id, "the foe nearest the caster, picked")
	var ally := s["ally"] as Combatant
	req.selected_ids.assign([ally.id])
	e.answer_reaction(true)
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("The orb leaps to %s" % ally.name())))


func test_declining_lets_the_leap_go() -> void:
	var s := _leaping()
	var e := s["e"] as Encounter
	var near := s["near"] as Combatant
	var hp := near.creature.hp
	e.answer_reaction(false)
	assert_false(e.log.texts().any(func(t: String) -> bool: return t.contains("The orb leaps to")))
	assert_eq(near.creature.hp, hp)


func test_on_auto_the_orb_goes_to_the_nearest_foe_without_asking() -> void:
	var s := _leaping("auto")
	assert_false(s.is_empty())
	var e := s["e"] as Encounter
	assert_true(e.pending == null, "no prompt")
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("The orb leaps to %s" % (s["near"] as Combatant).name())))
