extends TestCase
## Owner ask (2026-10-18): monsters with Legendary Actions seemed to go for one hero. Each blow of a Multiattack and each
## Legendary Action goes to a foe the creature hasn't struck since its own turn began, unless it has a reason to go on
## with one: a hero it can finish or that is nearly down, a concentrating caster, Strahd's prize, or only one foe in
## reach (combat/ai/ai_tactics.gd spread_rank, ai_brain.gd _blow_target, boss_brain.gd legendary_plan).


## A test monster: a claw that always hits (+30) for 5, 100 Hit Points, plus `extra` stat-block fields.
static func _boss(extra: Dictionary = {}) -> Dictionary:
	var d := {"id": "test_boss", "name": "Test Boss", "size": "medium", "type": "undead", "ac": 15,
		"hp": {"average": 100, "dice": "10d10+45"}, "speed": {"walk": 30},
		"abilities": {"str": 18, "dex": 14, "con": 16, "int": 12, "wis": 12, "cha": 16}, "cr": 10, "proficiency_bonus": 4,
		"actions": [_claw(5)], "ai_profile": "brute"}
	d.merge(extra, true)
	return d


static func _claw(damage: int) -> Dictionary:
	return {"id": "claw", "name": "Claw", "kind": "melee", "attack": {"bonus": 30, "reach": 5},
		"damage": [{"average": damage, "dice": "1d1+%d" % (damage - 1), "type": "slashing"}], "summary": "A claw."}


## A claw that costs one legendary use, `uses` of them a round.
static func _legendary(uses: int) -> Dictionary:
	return {"per_round": uses, "options": [{"id": "claw", "name": "Claw", "cost": 1, "action": "claw", "summary": "x"}]}


## Three claws in a Multiattack.
static func _triple() -> Dictionary:
	return {"id": "multiattack", "name": "Multiattack", "kind": "multiattack",
		"multiattack": [{"action": "claw", "count": 3}], "summary": "Three claws."}


func _field() -> Encounter:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	return e


func _add_boss(e: Encounter, data: Dictionary, cell: Vector2i) -> Combatant:
	return e.add(Monster.from_data(data), &"enemy", cell)


## Starts the fight with these initiatives (the first acts first).
func _order(e: Encounter, list: Array[Combatant], inits: Array[int]) -> void:
	e.lair = false
	e.start()
	for i in list.size():
		list[i].initiative = inits[i]
	e.order.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.initiative > b.initiative)
	e.turn_index = 0
	e._lair_then_begin()


## Three heroes around a boss at (5, 3), all within its reach, the highest Armor Class first.
func _ring(e: Encounter) -> Array[Combatant]:
	var cells: Array[Vector2i] = [Vector2i(4, 3), Vector2i(6, 3), Vector2i(5, 4)]
	var ids: Array[String] = ["hedda_ironvow", "ilse_varga", "silvain_aster"]
	var heroes: Array[Combatant] = []
	for i in 3:
		heroes.append(TestCombat.hero(e, ids[i], cells[i], 5))
	heroes.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.creature.ac_value() > b.creature.ac_value())
	return heroes


# --- Legendary Actions ------------------------------------------------------------------------------------------------

func test_legendary_actions_are_spread_over_the_heroes_in_reach() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss({"legendary_actions": _legendary(3)}), Vector2i(5, 3))
	var h := _ring(e)
	assert_true(h[0].creature.ac_value() > h[2].creature.ac_value(), "the heroes differ in Armor Class (else this proves nothing)")
	_order(e, [h[0], h[1], h[2], boss], [30, 25, 20, 10])
	e.end_turn()
	e.end_turn()
	e.end_turn()
	for hero in h:
		assert_eq(e.ai.tactics.dealt(boss, hero), 1, "%s was struck once" % hero.name())


func test_a_boss_strikes_the_lowest_armor_class_again_only_with_nothing_else_in_reach() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss({"legendary_actions": _legendary(3)}), Vector2i(5, 3))
	var near := TestCombat.hero(e, "silvain_aster", Vector2i(4, 3), 5)
	var far := TestCombat.hero(e, "hedda_ironvow", Vector2i(10, 6), 5)
	_order(e, [near, far, boss], [30, 25, 10])
	e.end_turn()
	e.end_turn()
	assert_eq(e.ai.tactics.dealt(boss, near), 2, "the only one in reach takes both")
	assert_eq(e.ai.tactics.dealt(boss, far), 0)


func test_what_it_struck_earlier_in_its_turn_counts_for_its_legendary_actions() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss({"legendary_actions": _legendary(3)}), Vector2i(5, 3))
	var h := _ring(e)
	_order(e, [h[0], h[1], h[2], boss], [30, 25, 20, 10])
	e.ai.tactics.begin_turn(boss)
	for blow: Combatant in [h[0], h[0], h[1]]:
		e.ai.tactics.note_strike(blow, boss)   # its Multiattack, before the legendary actions
	assert_eq((e.ai.boss.legendary_plan(boss)["target"] as Combatant), h[2], "the one it hasn't struck")
	e.ai.tactics.note_strike(h[2], boss)
	assert_ne((e.ai.boss.legendary_plan(boss)["target"] as Combatant), h[0], "then not the one struck twice, whatever the odds")


func test_a_new_turn_forgets_the_last_ones_blows() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss({"legendary_actions": _legendary(3)}), Vector2i(5, 3))
	var h := _ring(e)
	_order(e, [boss, h[0], h[1], h[2]], [30, 25, 20, 10])
	e.ai.tactics.note_strike(h[0], boss)
	assert_true(e.ai.tactics.dealt_any(boss))
	e.ai.tactics.begin_turn(boss)
	assert_false(e.ai.tactics.dealt_any(boss))
	assert_eq(e.ai.tactics.dealt(boss, h[0]), 0)


## A claw (20) has struck the second hero once; `hp` is what that hero has left (-1: all of it). Returns [the next
## legendary strike's target, that hero].
func _next_strike_after_one_on_the_second(hp: int) -> Array[Combatant]:
	var e := _field()
	var boss := _add_boss(e, _boss({"actions": [_claw(20)], "legendary_actions": _legendary(1)}), Vector2i(5, 3))
	var h := _ring(e)
	_order(e, [h[0], h[1], h[2], boss], [30, 25, 20, 10])
	e.ai.tactics.note_strike(h[1], boss)
	if hp >= 0:
		h[1].creature.hp = hp
	_encounters.append(e)
	return [e.ai.boss.legendary_plan(boss)["target"] as Combatant, h[1]]


## The tests' encounters, kept alive (an Encounter holds itself only weakly through its helpers).
var _encounters: Array[Encounter] = []


func test_it_goes_for_a_hero_it_can_finish() -> void:
	var healthy := _next_strike_after_one_on_the_second(-1)
	assert_ne(healthy[0], healthy[1], "a healthy hero it has struck waits while others haven't been")
	var dying := _next_strike_after_one_on_the_second(12)
	assert_eq(dying[0], dying[1], "a blow that ends the hero it already struck comes before one more hero")


func test_it_goes_on_striking_a_hero_who_is_nearly_down() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss({"actions": [_claw(2)], "legendary_actions": _legendary(2)}), Vector2i(5, 3))
	var h := _ring(e)
	var weak := h[1]
	weak.creature.hp = weak.creature.max_hp() / 5   # under a quarter, and more than the two claws (2 each) can take
	assert_true(weak.creature.hp > 4, "two claws can't down it")
	_order(e, [h[0], weak, h[2], boss], [30, 25, 20, 10])
	e.end_turn()
	e.end_turn()
	assert_eq(e.ai.tactics.dealt(boss, weak), 2, "both on the one nearly down")
	assert_eq(e.ai.tactics.dealt(boss, h[0]) + e.ai.tactics.dealt(boss, h[2]), 0)


func test_a_concentrating_caster_keeps_its_place_in_the_list() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss({"legendary_actions": _legendary(3)}), Vector2i(5, 3))
	var h := _ring(e)
	_order(e, [boss, h[0], h[1], h[2]], [30, 25, 20, 10])
	e.ai.tactics.note_strike(h[0], boss)
	e.ai.tactics.note_strike(h[0], boss)
	assert_eq(e.ai.tactics.spread_rank(boss, h[0], 5.0), 2, "twice struck: two places down")
	h[0].creature.concentration = Concentration.new(h[0].creature, "bless", "Bless")
	assert_eq(e.ai.tactics.spread_rank(boss, h[0], 5.0), 0, "a concentrating caster is worth going on with")
	assert_eq(e.ai.tactics.spread_rank(boss, h[1], 5.0), 0, "and the others are no worse off")


func test_a_familiar_comes_after_every_hero() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss({"legendary_actions": _legendary(3)}), Vector2i(5, 3))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 5)
	var pet_data := TestCombat.monster("wolf").data.duplicate(true)
	pet_data["familiar"] = true
	var pet := e.add(Monster.from_data(pet_data), &"party", Vector2i(6, 3))
	_order(e, [hero, pet, boss], [30, 25, 20])
	e.ai.tactics.note_strike(hero, boss)
	e.ai.tactics.note_strike(hero, boss)
	assert_true(e.ai.tactics.spread_rank(boss, pet, 5.0) > e.ai.tactics.spread_rank(boss, hero, 5.0), "a hero twice struck still before the familiar")
	assert_eq((e.ai.boss.legendary_plan(boss)["target"] as Combatant), hero)


func test_tactician_and_honour_foes_focus() -> void:
	for mode: String in ["tactician", "honour"]:
		var e := _field()
		var boss := _add_boss(e, _boss({"legendary_actions": _legendary(3)}), Vector2i(5, 3))
		var h := _ring(e)
		Difficulty.named(mode).arm(e)
		_order(e, [boss, h[0], h[1], h[2]], [30, 25, 20, 10])
		e.ai.tactics.note_strike(h[0], boss)
		e.ai.tactics.note_strike(h[0], boss)
		assert_false(e.ai.tactics.spreads(boss), mode)
		assert_eq(e.ai.tactics.spread_rank(boss, h[0], 5.0), 0, "%s: no place down for a hero it struck twice" % mode)


# --- A Multiattack ----------------------------------------------------------------------------------------------------

func test_a_multiattack_turns_its_blows_on_the_heroes_in_reach() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss({"actions": [_triple(), _claw(5)]}), Vector2i(5, 3))
	var h := _ring(e)
	_order(e, [boss, h[0], h[1], h[2]], [30, 25, 20, 10])
	e.run_ai_turn()
	for hero in h:
		assert_eq(e.ai.tactics.dealt(boss, hero), 1, "%s took one of the three claws" % hero.name())


func test_a_multiattack_with_one_hero_in_reach_strikes_it_every_time() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss({"actions": [_triple(), _claw(5)]}), Vector2i(5, 3))
	var near := TestCombat.hero(e, "silvain_aster", Vector2i(4, 3), 5)
	var far := TestCombat.hero(e, "hedda_ironvow", Vector2i(11, 7), 5)
	_order(e, [boss, near, far], [30, 25, 20])
	e.run_ai_turn()
	assert_eq(e.ai.tactics.dealt(boss, near), 3, "nobody else to turn to")
	assert_eq(e.ai.tactics.dealt(boss, far), 0)


func test_a_multiattack_finishes_the_hero_it_can_before_turning_to_another() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss({"actions": [_triple(), _claw(20)]}), Vector2i(5, 3))
	var h := _ring(e)
	h[0].creature.hp = 10   # one claw (20) ends the hero with the highest Armor Class
	_order(e, [boss, h[1], h[2], h[0]], [30, 25, 20, 10])
	e.run_ai_turn()
	assert_true(h[0].is_down(), "it fell")
	assert_eq(e.ai.tactics.dealt(boss, h[0]), 1, "one claw ended it; none after")
	assert_eq(e.ai.tactics.dealt(boss, h[1]) + e.ai.tactics.dealt(boss, h[2]), 2, "the other two went to the others")
