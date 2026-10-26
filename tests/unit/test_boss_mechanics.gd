extends TestCase
## Bosses (ADR 0014, combat/legendary.gd, combat/ai/boss_brain.gd): legendary actions between turns, lair actions on
## initiative 20, Regeneration and what stops it, shapes that keep Hit Points, Misty Escape and the resting place,
## Legendary Resistance, Children of the Night, foes that withdraw, the final battle's condition and the Tarokka's
## roaming enemy. Fixture monsters are built here; the last tests run Strahd's own stat block.


## A test monster: a claw that always hits (+30), 100 Hit Points, plus `extra` stat-block fields.
static func _boss(extra: Dictionary = {}) -> Dictionary:
	var d := {"id": "test_boss", "name": "Test Boss", "size": "medium", "type": "undead", "ac": 15,
		"hp": {"average": 100, "dice": "10d10+45"}, "speed": {"walk": 30},
		"abilities": {"str": 18, "dex": 14, "con": 16, "int": 12, "wis": 12, "cha": 16}, "cr": 10, "proficiency_bonus": 4,
		"actions": [{"id": "claw", "name": "Claw", "kind": "melee", "attack": {"bonus": 30, "reach": 5},
			"damage": [{"average": 5, "dice": "1d4+3", "type": "slashing"}], "summary": "A claw."},
			{"id": "bite", "name": "Bite", "kind": "melee", "attack": {"bonus": 30, "reach": 5},
			"damage": [{"average": 5, "dice": "1d4+3", "type": "piercing"}], "summary": "A bite."}],
		"ai_profile": "brute"}
	d.merge(extra, true)
	return d


static func _shapes() -> Dictionary:
	return {"forms": {"base": "true_form", "change": "action", "blocked_in": ["sunlight", "running_water"], "shapes": [
		{"id": "bat", "name": "Bat", "size": "tiny", "speed": {"walk": 5, "fly": 30}, "actions": ["bite"]},
		{"id": "mist", "name": "Mist", "size": "medium", "speed": {"walk": 0, "fly": 20, "hover": true}, "actions": [],
			"save_advantage": ["con"], "resistances": ["slashing"], "flags": ["enters_spaces"]}]}}


func _field() -> Encounter:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	return e


func _add_boss(e: Encounter, data: Dictionary, cell: Vector2i) -> Combatant:
	return e.add(Monster.from_data(data), &"enemy", cell)


## Starts the fight with these initiatives (the first acts first); `lair` turns lair actions on once it's ordered.
func _order(e: Encounter, list: Array[Combatant], inits: Array[int], lair: bool = false) -> void:
	e.lair = false
	e.start()
	for i in list.size():
		list[i].initiative = inits[i]
	e.order.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.initiative > b.initiative)
	e.lair = lair
	e.legendary.lair_round = 0
	e.turn_index = 0
	e._lair_then_begin()


func _kinds(events: Array[Dictionary], kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ev in events:
		if str(ev["type"]) == kind:
			out.append(ev)
	return out


# --- Legendary actions -------------------------------------------------------------------------------------------

func test_a_legendary_action_comes_at_the_end_of_another_creatures_turn_and_refreshes_on_its_own() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss({"legendary_actions": {"per_round": 3, "options": [
		{"id": "claw", "name": "Claw", "cost": 1, "action": "claw", "summary": "x"},
		{"id": "move", "name": "Move", "cost": 1, "move": true, "summary": "x"}]}}), Vector2i(3, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 5)
	var b := TestCombat.hero(e, "silvain_aster", Vector2i(9, 6), 5)
	_order(e, [a, b, boss], [30, 25, 10])
	assert_eq(e.legendary.left(boss), 3, "full at the start of the fight")
	assert_eq(e.legendary.pips(boss), "◆◆◆")
	var hp := a.creature.hp
	e.drain_events()
	e.end_turn()
	assert_eq(e.current(), b)
	assert_eq(e.legendary.left(boss), 2, "one spent at the end of the first hero's turn")
	assert_true(a.creature.hp < hp, "the legendary claw struck the hero beside it")
	assert_eq(_kinds(e.drain_events(), "legendary").size(), 1)
	e.end_turn()
	assert_eq(e.current(), boss)
	assert_eq(e.legendary.left(boss), 3, "back to three at the start of its own turn")
	var own := e.legendary.use_why(boss, e.legendary.option(boss, "claw"), a, Vector2i(-1, -1))
	assert_eq(own, "Only at the end of another creature's turn")


## House rule (owner, 2026-10-24): legendary actions come only at the end of a hero's turn, never after an NPC's: a guest,
## another foe or a summon (Legendary.opens_window).
func test_legendary_actions_come_only_after_a_heroes_turn() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss({"legendary_actions": {"per_round": 3, "options": [
		{"id": "claw", "name": "Claw", "cost": 1, "action": "claw", "summary": "x"}]}}), Vector2i(3, 3))
	var ally := e.add(Monster.from_data(_boss({"id": "test_ally", "name": "Test Ally"})), &"guest", Vector2i(4, 3))
	var minion := e.add(Monster.from_data(_boss({"id": "test_minion", "name": "Test Minion"})), &"enemy", Vector2i(2, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 4), 5)
	_order(e, [ally, minion, a, boss], [30, 25, 20, 10])
	assert_false(Legendary.opens_window(ally), "a guest's turn opens no window")
	assert_false(Legendary.opens_window(minion), "nor a foe's")
	assert_true(Legendary.opens_window(a), "a hero's does")
	e.end_turn()
	assert_eq(e.current(), minion)
	assert_eq(e.legendary.left(boss), 3, "nothing after the guest's turn")
	e.end_turn()
	assert_eq(e.current(), a)
	assert_eq(e.legendary.left(boss), 3, "nor after another foe's")
	e.end_turn()
	assert_eq(e.current(), boss)
	assert_eq(e.legendary.left(boss), 3, "back to three at its own turn")
	assert_true(_kinds(e.drain_events(), "legendary").size() == 1, "one use at the end of the hero's turn")


func test_a_legendary_move_provokes_no_opportunity_attack() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss({"legendary_actions": {"per_round": 2, "options": [
		{"id": "move", "name": "Move", "cost": 1, "move": true, "summary": "x"}]}}), Vector2i(3, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 5)
	_order(e, [a, boss], [30, 10])
	e.default_player_reaction = "auto"
	var r := e.legendary.use(boss, "move", null, Vector2i(0, 3))
	assert_true(r.ok, r.reason)
	assert_eq(boss.cell, Vector2i(0, 3))
	assert_true(a.reaction_available, "no Opportunity Attack against a legendary move")
	assert_eq(e.legendary.left(boss), 1)


## Three uses, a strike that costs two and a move that costs one (the Vine Mother's shape): the strike lands at the end
## of the first hero's turn, and the last use isn't wasted: at the end of the last turn before its own, it moves to
## stand beside both heroes.
func test_a_use_no_strike_can_take_goes_on_a_move_before_its_own_turn() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss({"legendary_actions": {"per_round": 3, "options": [
		{"id": "claw", "name": "Claw", "cost": 2, "action": "claw", "summary": "x"},
		{"id": "move", "name": "Move", "cost": 1, "move": true, "summary": "x"}]}}), Vector2i(3, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 5)
	var b := TestCombat.hero(e, "silvain_aster", Vector2i(6, 3), 5)
	_order(e, [a, b, boss], [30, 25, 10])
	var hp := a.creature.hp
	e.end_turn()
	assert_eq(e.legendary.left(boss), 1, "the claw took two uses at the end of the first hero's turn")
	assert_true(a.creature.hp < hp, "and struck the hero beside it")
	assert_eq(boss.cell, Vector2i(3, 3), "the last use waits while another turn is still to come")
	e.end_turn()
	assert_eq(e.current(), boss)
	assert_eq(e.legendary.left(boss), 3, "back to three at the start of its own turn")
	assert_eq(e.distance(boss, a), 5, "it moved with its last use...")
	assert_eq(e.distance(boss, b), 5, "...to stand beside both heroes")


## A boss with a long reach steps back out of a hero's reach with a use no strike can take, keeping the hero in its own.
func test_a_reach_boss_steps_back_out_of_reach_with_a_spare_use() -> void:
	var e := _field()
	var data := _boss({"legendary_actions": {"per_round": 3, "options": [
		{"id": "lash", "name": "Lash", "cost": 2, "action": "claw", "summary": "x"},
		{"id": "creep", "name": "Creep", "cost": 1, "move": true, "summary": "x"}]}})
	((data["actions"] as Array)[0] as Dictionary)["attack"] = {"bonus": 30, "reach": 15}
	var boss := _add_boss(e, data, Vector2i(3, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 5)
	var b := TestCombat.hero(e, "silvain_aster", Vector2i(11, 7), 5)
	_order(e, [a, b, boss], [30, 25, 10])
	e.end_turn()
	assert_eq(e.legendary.left(boss), 1, "a lash at the end of the first hero's turn")
	e.end_turn()
	assert_eq(e.current(), boss)
	var gap := e.distance(boss, a)
	assert_true(gap > a.reach_ft() and gap <= 15, "out of the hero's reach, the hero still in its own (%d ft)" % gap)


## 2025 Monster Manual: "Legendary Action Uses: 3 (4 in Lair)".
func test_a_boss_in_its_lair_has_its_lair_uses() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss({"legendary_actions": {"per_round": 3, "in_lair": 4, "options": [
		{"id": "claw", "name": "Claw", "cost": 1, "action": "claw", "summary": "x"}]}}), Vector2i(3, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(9, 6), 5)
	assert_eq(e.legendary.per_round(boss), 3, "three out of its lair")
	_order(e, [boss, a], [30, 10], true)
	assert_eq(e.current(), boss)
	assert_eq(e.legendary.left(boss), 4, "four in its lair, from the start of its turn")
	assert_eq(e.legendary.pips(boss), "◆◆◆◆")


## 2025 Monster Manual dragons: Pounce moves up to half its Speed and makes one Rend. Out of reach at the end of a
## hero's turn, it closes in no farther than half its Speed and strikes.
func test_pounce_closes_in_up_to_half_its_speed_and_strikes() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss({"legendary_actions": {"per_round": 1, "options": [
		{"id": "pounce", "name": "Pounce", "move": true, "half": true, "action": "claw", "summary": "x"}]}}), Vector2i(3, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(6, 3), 5)
	var b := TestCombat.hero(e, "silvain_aster", Vector2i(11, 8), 5)
	_order(e, [b, a, boss], [30, 25, 10])
	assert_eq(e.legendary.move_ft(boss, e.legendary.option(boss, "pounce")), 15, "half of its 30 ft")
	var hp := a.creature.hp
	e.end_turn()
	assert_eq(e.legendary.left(boss), 0, "it pounced at the end of the first hero's turn")
	assert_eq(e.distance(boss, a), 5, "beside the hero it could reach")
	assert_true(absi(boss.cell.x - 3) <= 3 and absi(boss.cell.y - 3) <= 3, "no farther than 15 ft (%s)" % boss.cell)
	assert_true(a.creature.hp < hp, "and struck")


## 2025 Monster Manual: "can't take this action again until the start of its next turn".
func test_an_option_it_cant_take_again_until_its_next_turn_waits() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss({"legendary_actions": {"per_round": 3, "options": [
		{"id": "claw", "name": "Claw", "action": "claw", "once": true, "summary": "x"}]}}), Vector2i(3, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 5)
	var b := TestCombat.hero(e, "silvain_aster", Vector2i(9, 6), 5)
	_order(e, [a, b, boss], [30, 25, 10])
	var opt := e.legendary.option(boss, "claw")
	e.end_turn()
	assert_eq(e.legendary.left(boss), 2, "one claw at the end of the first hero's turn")
	assert_eq(e.legendary.use_why(boss, opt, a, Vector2i(-1, -1)), "Not again until its next turn")
	e.end_turn()
	assert_eq(e.current(), boss)
	assert_eq(e.legendary.left(boss), 3, "the uses come back")
	assert_false(e.legendary.spent_once(boss, opt), "and so does the claw")


## An ancient dragon's Fiery Rays: a legendary action casts a spell of its Spellcasting block, spending no action.
func test_a_legendary_spell_is_cast_from_its_block() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss({"spellcasting": {"ability": "cha", "dc": 15, "attack": 30, "at_will": ["scorching_ray"],
		"levels": {"scorching_ray": 3}}, "legendary_actions": {"per_round": 1, "options": [
		{"id": "rays", "name": "Fiery Rays", "spell": "scorching_ray", "once": true, "summary": "x"}]}}), Vector2i(3, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(9, 3), 5)
	_order(e, [a, boss], [30, 10])
	var hp := a.creature.hp
	e.end_turn()
	assert_eq(e.current(), boss)
	assert_true(a.creature.hp < hp, "the rays struck the hero out of its reach")
	assert_true(e.log.texts().has("Test Boss casts Scorching Ray (level 3)"), "at the level its block gives")
	assert_true(boss.action_available, "its own turn's action is still there")


## A save against something that would hold it (Hold Monster's Paralyzed), the kind Legendary Resistance answers.
const HELD: Array[String] = ["save_vs:paralyzed", "save_vs:spell", "save_vs:magic", "save_vs:spell_level:5"]


## 2025 Monster Manual: "Legendary Resistance (4/Day, or 5/Day in Lair)".
func test_legendary_resistance_has_its_lair_count() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss({"legendary_resistance": 1, "legendary_resistance_in_lair": 2}), Vector2i(3, 3))
	assert_eq(e.legendary.resistances(boss), 1, "one out of its lair")
	_order(e, [boss], [10], true)
	assert_eq(e.legendary.resistances(boss), 2, "two in it")
	assert_true(boss.creature.roll_save(e.dice, &"wis", 99, [], [], "test", HELD).success)
	assert_true(boss.creature.roll_save(e.dice, &"wis", 99, [], [], "test", HELD).success, "the lair's second use")
	assert_false(boss.creature.roll_save(e.dice, &"wis", 99, [], [], "test", HELD).success)


func test_legendary_resistance_turns_failures_into_successes_while_uses_last() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss({"legendary_resistance": 1}), Vector2i(3, 3))
	_order(e, [boss], [10])
	var first := boss.creature.roll_save(e.dice, &"wis", 99, [], [], "test", HELD)
	assert_true(first.success, "the first failed save succeeds instead")
	var second := boss.creature.roll_save(e.dice, &"wis", 99, [], [], "test", HELD)
	assert_false(second.success, "no uses left")


## House rule (owner, 2026-10-21; docs/rules/deviations.md): Legendary Resistance only turns a failed save that would put a
## condition on the boss, or one against a spell of 5th level or higher (as cast) that does no damage on a success.
func test_legendary_resistance_is_kept_for_what_matters() -> void:
	var cases := [
		[[], false, "a save with nothing riding on it"],
		[["save_vs:spell", "save_vs:magic", "save_vs:spell_level:3", "save_vs:damage_on_success"], false, "a Fireball"],
		[["save_vs:spell", "save_vs:magic", "save_vs:spell_level:5", "save_vs:damage_on_success"], false, "a Cone of Cold"],
		[["save_vs:spell", "save_vs:magic", "save_vs:spell_level:6"], true, "a Disintegrate: nothing on a success, all on a failure"],
		[["save_vs:spell", "save_vs:magic", "save_vs:spell_level:4"], false, "a 4th-level spell with no condition"],
		[["save_vs:stunned"], true, "a Stunning Strike"],
		[["save_vs:prone", "save_vs:spell", "save_vs:magic", "save_vs:spell_level:1", "save_vs:damage_on_success"], true,
			"a spell that knocks it down, damage or not"],
	]
	for case: Array in cases:
		var keys: Array[String] = []
		keys.assign(case[0] as Array)
		var e := _field()
		var boss := _add_boss(e, _boss({"legendary_resistance": 3}), Vector2i(3, 3))
		_order(e, [boss], [10])
		var sv := boss.creature.roll_save(e.dice, &"wis", 99, [], [], "test", keys)
		assert_eq(sv.success, bool(case[1]), str(case[2]))
		assert_eq(int(boss.get_meta("legendary_resistance_used", 0)), 1 if bool(case[1]) else 0, "%s: uses spent" % case[2])


## The boss can't pass a Dexterity or Wisdom save (both scores 1, against a level 9 caster's DC) unless it resists.
func _mage_and_boss() -> Dictionary:
	var e := _field()
	var boss := _add_boss(e, _boss({"legendary_resistance": 3, "abilities": {"str": 18, "dex": 1, "con": 16, "int": 12, "wis": 1, "cha": 16}}),
		Vector2i(6, 3))
	var mage := TestCombat.caster_with(e, ["fireball", "hold_monster"], Vector2i(0, 3), 9)
	_order(e, [mage, boss], [20, 10])
	return {"e": e, "mage": mage, "boss": boss}


func test_a_fireball_burns_no_legendary_resistance_and_hold_monster_does() -> void:
	var f := _mage_and_boss()
	var boss := f["boss"] as Combatant
	var before := boss.creature.hp
	assert_true((f["e"] as Encounter).spells.cast(f["mage"] as Combatant, "fireball", 3, [], Vector2(6.5, 3.5)).ok)
	assert_eq(int(boss.get_meta("legendary_resistance_used", 0)), 0, "it takes the Fireball's full damage instead")
	assert_true(boss.creature.hp < before, "and the fire lands")
	var g := _mage_and_boss()
	var held := g["boss"] as Combatant
	assert_true((g["e"] as Encounter).spells.cast(g["mage"] as Combatant, "hold_monster", 5, [held]).ok)
	assert_eq(int(held.get_meta("legendary_resistance_used", 0)), 1, "Hold Monster is worth one")
	assert_false(held.creature.has_condition(&"paralyzed"), "so it isn't held")


# --- Lair actions ------------------------------------------------------------------------------------------------

func test_the_lair_acts_on_initiative_20_losing_ties_and_never_twice_the_same() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss({"lair_actions": [
		{"id": "veil", "name": "Veil", "kind": "self", "modifiers": [{"stat": "flag", "value": "lair_veil"}], "summary": "x"},
		{"id": "ward", "name": "Ward", "kind": "self", "modifiers": [{"stat": "flag", "value": "lair_ward"}], "summary": "x"}]}), Vector2i(3, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(8, 3), 5)
	var b := TestCombat.hero(e, "silvain_aster", Vector2i(9, 6), 5)
	_order(e, [a, boss, b], [20, 12, 5], true)
	assert_eq(e.current(), a, "a creature on 20 goes before the lair")
	assert_eq(e.legendary.lair_round, 0, "the lair hasn't acted yet")
	assert_eq(e.legendary.lair_slot(), 1, "the tracker shows the lair between 20 and 12")
	e.drain_events()
	e.end_turn()
	assert_eq(e.legendary.lair_round, 1, "the lair acted before the creature on 12")
	assert_eq(_kinds(e.drain_events(), "lair").size(), 1)
	var first := e.legendary.last_lair
	assert_true(boss.creature.has_flag("lair_" + first))
	e.end_turn()
	e.end_turn()
	assert_eq(e.legendary.lair_round, 1, "once a round")
	e.end_turn()   # the hero on 20 ends round 2's first turn: the lair again
	assert_eq(e.legendary.lair_round, 2)
	assert_ne(e.legendary.last_lair, first, "not the same one twice in a row")
	assert_false(boss.creature.has_flag("lair_" + first), "the last lair action's effect ended")
	assert_true(boss.creature.has_flag("lair_" + e.legendary.last_lair))


func test_a_lair_without_lair_true_stays_quiet() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss({"lair_actions": [{"id": "veil", "name": "Veil", "kind": "self",
		"modifiers": [{"stat": "flag", "value": "lair_veil"}], "summary": "x"}]}), Vector2i(3, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(8, 3), 5)
	_order(e, [a, boss], [25, 12], false)
	e.end_turn()
	assert_eq(e.legendary.lair_round, 0)
	assert_eq(e.legendary.lair_slot(), -1)


func test_a_lair_attack_and_a_lair_save_that_summons() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss({"lair_actions": [
		{"id": "spirit", "name": "Spirit", "kind": "attack", "attack": {"bonus": 40, "range": 120},
			"damage": [{"average": 7, "dice": "2d6", "type": "necrotic"}], "summary": "x"},
		{"id": "shadow", "name": "Shadow", "kind": "save", "save": {"ability": "cha", "dc": 40},
			"targets": {"range": 60, "max_size": "medium"}, "summon": {"monster": "shadow", "count": 1}, "summary": "x"}]}), Vector2i(3, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(8, 3), 5)
	_order(e, [boss, a], [10, 5], true)
	assert_eq(e.legendary.lair_round, 1, "the lair opened round 1 (nobody rolled 20)")
	assert_eq(e.legendary.last_lair, "spirit", "a strike first")
	assert_true(a.creature.hp < a.creature.max_hp(), "the spirit struck the hero")
	e.legendary.lair_round = 0
	var before := e.combatants.size()
	e.legendary.last_lair = "spirit"
	e.legendary.lair_turn()
	assert_eq(e.legendary.last_lair, "shadow")
	assert_eq(e.combatants.size(), before + 1, "the target's shadow joins the fight")
	var shade := e.combatants[e.combatants.size() - 1]
	assert_eq(shade.side, &"enemy")
	assert_eq(shade.initiative, 20, "it acts on initiative count 20")


# --- Regeneration ------------------------------------------------------------------------------------------------

func test_regeneration_stops_after_radiant_damage_and_in_sunlight_or_running_water() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss({"regenerates": {"hp": 10, "stopped_by": ["radiant"], "running_water": true, "sunlight": true}}), Vector2i(3, 3))
	_order(e, [boss], [10])
	boss.creature.hp = 50
	e.legendary.turn_start(boss)
	assert_eq(boss.creature.hp, 60, "10 back at the start of its turn")
	e.deal_damage(null, boss, [{"amount": 5, "type": "radiant"}], false, "test")
	assert_eq(boss.creature.hp, 55)
	e.legendary.turn_start(boss)
	assert_eq(boss.creature.hp, 55, "no Regeneration after Radiant damage")
	e.legendary.turn_start(boss)
	assert_eq(boss.creature.hp, 65, "it works again the turn after")
	e.deal_damage(null, boss, [{"amount": 5, "type": "fire"}], false, "test")
	e.legendary.turn_start(boss)
	assert_eq(boss.creature.hp, 70, "other damage doesn't stop it")
	e.sunlit = true
	e.legendary.turn_start(boss)
	assert_eq(boss.creature.hp, 70, "not in sunlight")
	e.sunlit = false
	boss.creature.hp = 0
	e.legendary.turn_start(boss)
	assert_eq(boss.creature.hp, 0, "not at 0 Hit Points")


func test_running_water_is_a_water_square_not_flown_over() -> void:
	var e := TestCombat.encounter(["....", ".w..", "...."], 2)
	var boss := e.add(Monster.from_data(_boss({"regenerates": {"hp": 10, "running_water": true}})), &"enemy", Vector2i(1, 1))
	assert_true(e.in_running_water(boss))
	boss.creature.hp = 50
	_order(e, [boss], [10])
	e.legendary.turn_start(boss)
	assert_eq(boss.creature.hp, 50, "no Regeneration in running water")


# --- Shapes ------------------------------------------------------------------------------------------------------

func test_a_shape_swaps_size_speed_actions_and_defenses_and_keeps_hit_points() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss(_shapes()), Vector2i(3, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 5)
	_order(e, [boss, a], [30, 10])
	boss.creature.hp = 70
	var claw := (boss.creature as Monster).action("claw")
	var bite := (boss.creature as Monster).action("bite")
	assert_eq(e.legendary.form(boss), "true_form")
	var r := e.legendary.change_form(boss, "bat")
	assert_true(r.ok, r.reason)
	assert_false(boss.action_available, "changing shape costs the action")
	assert_eq(boss.creature.hp, 70, "Hit Points stay")
	assert_eq(boss.creature.size, &"tiny")
	assert_eq(boss.creature.speed("fly").total(), 30)
	assert_eq(boss.creature.speed().total(), 5)
	assert_eq(e.monster_actions.why_not(boss, claw), "Not in this form")
	assert_eq(e.monster_actions.why_not(boss, bite), "")
	e.end_turn()
	e.end_turn()
	assert_true(e.legendary.change_form(boss, "mist").ok)
	assert_eq(boss.creature.size, &"medium")
	assert_eq(boss.creature.hp, 70)
	assert_ne(e.monster_actions.why_not(boss, bite), "", "no actions as mist")
	assert_true(boss.creature.has_flag("cant_attack") and boss.creature.has_flag("enters_spaces"))
	assert_ne(boss.creature.resistance_source(&"slashing"), "", "the shape's defenses")
	e.end_turn()
	e.end_turn()
	e.sunlit = true
	assert_eq(e.legendary.change_why(boss, "true_form"), "Not in sunlight")
	e.sunlit = false
	assert_true(e.legendary.change_form(boss, "true_form").ok)
	assert_eq(boss.creature.speed().total(), 30)
	assert_eq(boss.creature.resistance_source(&"slashing"), "")
	assert_eq(e.monster_actions.why_not(boss, claw), "")
	assert_eq(boss.creature.hp, 70)


# --- Misty Escape and withdrawing --------------------------------------------------------------------------------

static func _misty() -> Dictionary:
	var d := _shapes()
	d["misty_escape"] = {"resting_place": "test_crypt", "flag": "boss_in_coffin", "form": "mist", "destroyed_flag": "boss_destroyed",
		"quest": {"id": "strahds_lair", "stage": "destroyed"}}
	return d


func test_zero_hit_points_outside_the_resting_place_is_mist_and_flight() -> void:
	var e := _field()
	e.location_id = "test_hall"
	var boss := _add_boss(e, _boss(_misty()), Vector2i(3, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 5)
	_order(e, [a, boss], [30, 10])
	e.drain_events()
	e.deal_damage(a, boss, [{"amount": 500, "type": "force"}], false, "test")
	assert_eq(str(e.legendary.departed.get(boss.id, "")), "mist")
	assert_eq(e.legendary.form(boss), "mist")
	assert_true(bool(e.legendary.story_flags.get("boss_in_coffin", false)), "the coffin flag")
	assert_false(e.legendary.story_flags.has("boss_destroyed"), "not destroyed")
	assert_false(boss in e.living(), "gone from the fight")
	var evs := e.drain_events()
	assert_eq(_kinds(evs, "death").size(), 0, "no death")
	assert_eq(_kinds(evs, "vanish").size(), 1)
	assert_true(e.is_over() and e.outcome == "victory")
	assert_true(e.legendary.no_loot())
	assert_eq(e.legendary.end_title(), "Test Boss escapes as mist")


func test_at_the_resting_place_or_in_sunlight_it_is_destroyed() -> void:
	var e := _field()
	e.location_id = "test_crypt"
	var boss := _add_boss(e, _boss(_misty()), Vector2i(3, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 5)
	_order(e, [a, boss], [30, 10])
	e.deal_damage(a, boss, [{"amount": 500, "type": "force"}], false, "test")
	assert_true(boss.creature.dead and not e.legendary.departed.has(boss.id), "destroyed in its coffin")
	assert_true(bool(e.legendary.story_flags.get("boss_destroyed", false)))
	assert_eq(str(e.legendary.story_quests.get("strahds_lair", "")), "destroyed")
	assert_false(e.legendary.no_loot())
	var e2 := _field()
	e2.location_id = "test_hall"
	e2.sunlit = true
	var boss2 := _add_boss(e2, _boss(_misty()), Vector2i(3, 3))
	TestCombat.hero(e2, "hedda_ironvow", Vector2i(4, 3), 5)
	e2.deal_damage(null, boss2, [{"amount": 500, "type": "force"}], false, "test")
	assert_true(boss2.creature.dead and not e2.legendary.departed.has(boss2.id), "sunlight stops the mist: destroyed")


func test_a_foe_withdraws_at_its_threshold_without_dying_or_loot() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss(), Vector2i(3, 3))
	var wolf := TestCombat.foe(e, "wolf", Vector2i(2, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 5)
	e.legendary.set_withdraw({"who": "test_boss", "at_hp_below": 40, "flag": "boss_tested_us"})
	_order(e, [a, boss, wolf], [30, 10, 5])
	e.deal_damage(a, boss, [{"amount": 50, "type": "force"}], false, "test")
	assert_false(e.legendary.departed.has(boss.id), "50 Hit Points left: it fights on")
	e.deal_damage(a, boss, [{"amount": 500, "type": "force"}], false, "test")
	assert_eq(str(e.legendary.departed.get(boss.id, "")), "withdraw", "it leaves rather than dies")
	assert_true(boss.creature.hp >= 1)
	assert_true(bool(e.legendary.story_flags.get("boss_tested_us", false)))
	assert_false(e.is_over(), "the wolf fights on")
	wolf.creature.hp = 1
	e.deal_damage(a, wolf, [{"amount": 50, "type": "force"}], false, "test")
	assert_true(e.is_over())
	assert_false(e.legendary.no_loot(), "the wolf died, so there is something to find")


## A foe that withdraws with a parting line (Strahd leaving his visits, owner 2026-10-13: "when he leaves, his sound bite
## should play as the combat ends"): the line is logged and rides on its vanish event with whose voice speaks it.
func test_a_foe_that_withdraws_says_its_parting_line() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss(), Vector2i(3, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 5)
	e.legendary.set_withdraw({"who": "test_boss", "at_hp_below": 1, "flag": "boss_tested_us", "say": "Until the next time.",
		"speaker": "strahd"})
	_order(e, [a, boss], [30, 10])
	e.deal_damage(a, boss, [{"amount": 99, "type": "force"}], false, "test")
	assert_false(e.legendary.departed.has(boss.id), "1 Hit Point left: it fights on to the end")
	e.deal_damage(a, boss, [{"amount": 5, "type": "force"}], false, "test")
	assert_eq(str(e.legendary.departed.get(boss.id, "")), "withdraw", "at 0 it goes")
	var vanish := _kinds(e.events, "vanish")
	assert_eq(vanish.size(), 1)
	assert_eq(str(vanish[0]["say"]), "Until the next time.")
	assert_eq(str(vanish[0]["speaker"]), "strahd")
	assert_true(e.log.entries.any(func(en: Variant) -> bool: return str((en as Dictionary).get("text", "")).contains("Until the next time.")), "and in the log")


func test_a_foe_withdraws_after_its_rounds() -> void:
	var e := _field()
	var boss := _add_boss(e, _boss(_shapes()), Vector2i(3, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(9, 3), 5)
	e.legendary.set_withdraw({"who": "test_boss", "after_rounds": 1, "flag": "boss_left"})
	_order(e, [a, boss], [30, 10])
	e.end_turn()
	assert_eq(e.current(), boss)
	assert_false(e.legendary.departed.has(boss.id), "it fights in round 1")
	e.end_turn()
	e.end_turn()
	assert_eq(str(e.legendary.departed.get(boss.id, "")), "withdraw", "gone at the start of its round 2 turn")
	assert_eq(e.legendary.form(boss), "mist", "it leaves as mist")
	assert_true(e.is_over())
	assert_eq(e.legendary.end_title(), "Test Boss withdraws")


# --- Children of the Night ---------------------------------------------------------------------------------------

func test_children_of_the_night_arrive_after_their_rounds() -> void:
	var e := _field()
	var call := {"id": "children_of_the_night", "name": "Children of the Night", "kind": "special", "uses": {"count": 1, "per": "day"},
		"summary": "x", "summon": {"choices": [{"monster": "wolf", "count": 5, "max": 3, "where": "outdoors"},
			{"monster": "swarm_of_bats", "count": 2, "where": "any"}], "arrive": 1, "not_in": ["sunlight"]}}
	var data := _boss()
	(data["actions"] as Array).append(call)
	var boss := _add_boss(e, data, Vector2i(3, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(9, 3), 5)
	_order(e, [boss, a], [30, 10])
	var r := e.legendary.call_children(boss, call)
	assert_true(r.ok, r.reason)
	assert_eq(e.legendary.incoming.size(), 1, "on their way")
	assert_ne(e.legendary.summon_why(boss, call), "", "once a day")
	var n := e.combatants.size()
	e.end_turn()
	e.end_turn()
	assert_eq(e.round_no, 2)
	assert_eq(e.combatants.size(), n + 2, "two swarms of bats indoors")
	assert_eq(e.combatants[n].side, &"enemy")
	assert_true(e.order[e.order.find(boss) + 1] in [e.combatants[n], e.combatants[n + 1]], "they act after their summoner")
	var e2 := _field()
	e2.outdoors = true
	var boss2 := _add_boss(e2, data, Vector2i(3, 3))
	_order(e2, [boss2], [30])
	assert_eq(str(e2.legendary.summon_choice(call)["monster"]), "wolf", "wolves outdoors")
	assert_eq(e2.legendary._count(e2.legendary.summon_choice(call)), 3, "capped at max")


# --- The final battle and the Tarokka ----------------------------------------------------------------------------

func test_final_room_and_the_final_battles_extra_when() -> void:
	var st := StoryState.new()
	assert_false(StoryConditions.check("final_room:castle_ravenloft_study", st), "no reading yet")
	st.tarokka = {"tome": "", "symbol": "", "sword": "", "ally": "", "enemy": "seer"}
	assert_true(StoryConditions.check("final_room:castle_ravenloft_study", st))
	assert_false(StoryConditions.check("final_room:castle_ravenloft_treasury", st))
	assert_eq(Tarokka.field(st, "enemy.roam"), "", "only the mists roam")
	var spec := {"id": "final", "trigger": "enter_area:x", "final_battle": "castle_ravenloft_study", "when": "flag.lamps_out", "monsters": []}
	var when := StoryConditions.encounter_when(spec)
	assert_false(StoryConditions.check(when, st), "the quest isn't given yet")
	st.set_quest_stage("strahds_lair", "foretold")
	assert_false(StoryConditions.check(when, st), "its own when still holds it back")
	st.set_flag("lamps_out")
	assert_true(StoryConditions.check(when, st))
	st.set_quest_stage("strahds_lair", "confronted")
	assert_true(StoryConditions.check(when, st), "foretold or later")
	st.set_flag("strahd_destroyed")
	assert_false(StoryConditions.check(when, st), "not once he is destroyed")
	assert_eq(StoryConditions.encounter_when({"when": "flag.a"}), "flag.a", "other fights keep their own when")
	var other := {"final_battle": "castle_ravenloft_treasury"}
	st.set_flag("strahd_destroyed", false)
	assert_false(StoryConditions.check(StoryConditions.encounter_when(other), st), "only the room he waits in")


func test_the_mists_roam_to_an_enemy_room_picked_from_the_seed() -> void:
	var seed_value := -1
	for s in range(1, 3000):
		if str(Tarokka.draw(s).get("enemy", "")) == "mists":
			seed_value = s
			break
	assert_true(seed_value > 0, "some seed draws the mists")
	var reading := Tarokka.draw(seed_value)
	var roam := str(reading.get("enemy_roam", ""))
	assert_true(roam in Tarokka.enemy_rooms() and roam != Tarokka.ROAM_ROOM, "one of the enemy rooms: %s" % roam)
	assert_eq(roam, Tarokka.roam_pick(seed_value))
	assert_eq(str(Tarokka.draw(seed_value).get("enemy_roam", "")), roam, "the same every time")
	var st := StoryState.new()
	st.playthrough_seed = seed_value
	Tarokka.ensure_drawn(st)
	assert_eq(Tarokka.field(st, "enemy.roam"), roam)
	assert_eq(Tarokka.final_room(st), roam)
	assert_true(StoryConditions.check("final_room:%s" % roam, st))
	assert_true(StoryConditions.check("tarokka.enemy.roam == %s" % roam, st))
	st.tarokka.erase("enemy_roam")
	assert_eq(Tarokka.final_room(st), roam, "a reading saved before the pick still finds him")
	var copy := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	Tarokka.ensure_drawn(copy)
	assert_eq(Tarokka.final_room(copy), roam)


# --- Saving a fight ----------------------------------------------------------------------------------------------

func test_a_saved_fight_keeps_shapes_lair_and_what_the_story_learns() -> void:
	var e := _field()
	var data := _boss(_shapes())
	data["lair_actions"] = [{"id": "veil", "name": "Veil", "kind": "text", "summary": "x"}]
	var boss := _add_boss(e, data, Vector2i(3, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(9, 3), 5)
	_order(e, [boss, a], [30, 10], true)
	e.location_id = "test_hall"
	assert_true(e.legendary.change_form(boss, "bat").ok)
	e.legendary.story_flags["boss_seen"] = true
	var snap := EncounterSnapshot.capture(e)
	var r := EncounterSnapshot.restore(JSON.parse_string(JSON.stringify(snap)) as Dictionary, DiceRoller.new(4))
	var b2: Combatant = null
	for c in r.combatants:
		if c.creature is Monster and str((c.creature as Monster).data.get("id", "")) == "test_boss":
			b2 = c
	assert_true(b2 != null)
	assert_eq(r.legendary.form(b2), "bat")
	assert_eq(b2.creature.size, &"tiny")
	assert_eq(b2.creature.speed("fly").total(), 30)
	assert_true(r.lair)
	assert_eq(r.location_id, "test_hall")
	assert_true(bool(r.legendary.story_flags.get("boss_seen", false)))


## The round-start save is the round as it begins, before its first turn starts (QA FN-11): taken after it, a reload
## played that start again, so a regenerating foe first in the order healed twice (and a lair acted twice). The kept
## round, restored, heals the revenant once, as the fight did.
func test_a_round_start_save_plays_the_first_turns_start_once() -> void:
	var e := _field()
	e.keep_round_snapshots = true
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 1), 5)
	var rev := TestCombat.foe(e, "revenant", Vector2i(9, 6))
	TestCombat.start_with(e, rev)
	rev.creature.hp = rev.creature.max_hp() - 40
	for i in 6:
		if e.round_no >= 2:
			break
		e.end_turn()
		while e.pending != null:
			e.answer_reaction(false)
	assert_eq(e.round_no, 2)
	assert_eq(e.current(), rev, "the revenant starts round 2")
	assert_eq(int(e.round_snapshot.get("round", 0)), 2, "round 2 kept as it began")
	var live := rev.creature.hp
	var r := EncounterSnapshot.restore(JSON.parse_string(JSON.stringify(e.round_snapshot)) as Dictionary, DiceRoller.new(4))
	assert_eq(r.get_c(rev.id).creature.hp, live, "Regeneration once, not twice")
	assert_eq(r.get_c(a.id).creature.hp, a.creature.hp)


# --- Strahd's own block ------------------------------------------------------------------------------------------

func _strahd(e: Encounter, cell: Vector2i) -> Combatant:
	var data := Compendium.shared().monster_data("strahd_von_zarovich")
	assert_false(data.is_empty(), "Strahd's stat block")
	return e.add(Monster.from_data(data), &"enemy", cell)


func test_strahds_block_runs_on_these_rules() -> void:
	var e := _field()
	var s := _strahd(e, Vector2i(3, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 9)
	_order(e, [s, a], [30, 10])
	assert_eq(e.legendary.base_form(s), "vampire")
	assert_eq(e.legendary.left(s), 3)
	var bite := (s.creature as Monster).action("bite")
	var strike := (s.creature as Monster).action("unarmed_strike")
	assert_eq(e.monster_actions.why_not(s, strike), "", "his true form fights")
	var o := e.option_by_id(s, "monster:bite")
	assert_ne(e.attack_legal(s, a, o), "", "the Bite needs a held, charmed or helpless victim")
	e.monster_actions.grapple(s, a, 18, 2, "Unarmed Strike")
	assert_eq(e.attack_legal(s, a, o), "", "held: he can bite")
	assert_true(e.legendary.change_form(s, "mist").ok)
	assert_ne(e.monster_actions.why_not(s, bite), "", "mist can't bite")
	assert_true(s.creature.speed("fly").total() > 0)
	var hp := s.creature.hp
	s.creature.hp = hp - 30
	e.legendary.turn_start(s)
	assert_eq(s.creature.hp, hp - 10, "Regeneration 20")


func test_a_charmed_victim_counts_as_willing_for_strahds_bite() -> void:
	var e := _field()
	var s := _strahd(e, Vector2i(3, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 9)
	_order(e, [s, a], [30, 10])
	var fx := Effect.new("Charmed (Charm)", &"monster", "%s:Charm" % s.id).with_condition(&"charmed")
	fx.caster_id = s.id
	a.creature.add_effect(fx)
	assert_eq(e.attack_legal(s, a, e.option_by_id(s, "monster:bite")), "")
	assert_true(Legendary.charmed_by(a, s))


func test_strahd_bites_with_a_legendary_action_and_charms_on_his_turn() -> void:
	var e := _field()
	var s := _strahd(e, Vector2i(3, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 9)
	var b := TestCombat.hero(e, "ilse_varga", Vector2i(3, 5), 9)
	_order(e, [a, b, s], [30, 20, 10])
	e.monster_actions.grapple(s, a, 18, 2, "Unarmed Strike")
	var plan := e.ai.boss.legendary_plan(s)
	assert_eq(str(plan.get("option", "")), "bite", "he drinks from the one he holds")
	assert_eq(plan.get("target") as Combatant, a)
	e.end_turn()
	assert_eq(e.legendary.left(s), 1, "the Bite costs two")
	e.end_turn()
	assert_eq(e.current(), s)
	var charm := e.ai.boss.charm_plan(s)
	assert_false(charm.is_empty(), "a Humanoid in 30 ft to charm")


func test_strahd_takes_mist_form_to_regenerate_when_badly_hurt() -> void:
	var e := _field()
	var s := _strahd(e, Vector2i(3, 3))
	TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 9)
	_order(e, [s], [30])
	s.creature.hp = 20
	e.run_ai_turn()
	assert_eq(e.legendary.form(s), "mist", "below a quarter of his Hit Points")
	assert_eq(str(e.ai.last_plan.get("kind", "")), "mist")


## The Sunsword's sunlight (owner, 2026-10-13: Strahd's finale is tuned for a party carrying it): he keeps a legendary
## move back while he stands in it, and at the end of the last turn before his own he slips out of it, so his turn
## starts unburnt.
func test_strahd_slips_out_of_the_sunswords_light_before_his_turn() -> void:
	var e := _field()
	var s := _strahd(e, Vector2i(3, 3))
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(4, 3), 9)
	var b := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 5), 9)
	e.items.attach_light(a, "light:sunsword", 15, 15, true)
	_order(e, [a, b, s], [30, 20, 10])
	assert_true(e.in_sunlight(s), "beside the bearer, in the light")
	assert_true(e.ai.boss.in_burning_sun(s))
	e.end_turn()
	assert_true(e.legendary.left(s) >= 1, "a move's use kept back from his strikes")
	e.end_turn()
	assert_eq(e.current(), s)
	assert_false(e.in_sunlight(s), "out of the light before his turn")
	assert_eq(s.creature.hp, s.creature.max_hp(), "so it didn't burn him")


## On his own turn, after his action, he walks out of the light when no foe stands beside him to strike as he goes.
func test_strahd_walks_out_of_the_light_after_acting() -> void:
	var e := _field()
	var s := _strahd(e, Vector2i(3, 3))
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(5, 3), 9)
	e.items.attach_light(a, "light:sunsword", 15, 15, true)
	_order(e, [s, a], [30, 10])
	assert_true(e.in_sunlight(s))
	assert_true(e.ai.boss.leave_sun(s) != null, "nobody beside him: he goes")
	assert_false(e.in_sunlight(s), "out of the light")
	var e2 := _field()
	var s2 := _strahd(e2, Vector2i(3, 3))
	var a2 := TestCombat.hero(e2, "ilse_varga", Vector2i(4, 3), 9)
	e2.items.attach_light(a2, "light:sunsword", 15, 15, true)
	_order(e2, [s2, a2], [30, 10])
	assert_true(e2.ai.boss.leave_sun(s2) == null, "the bearer beside him would strike as he goes: a legendary move takes him out")


## Sleep can't take an elf's trance: a caster doesn't spend its spell on one.
func test_sleep_is_worth_nothing_on_an_elf() -> void:
	var e := _field()
	var s := _strahd(e, Vector2i(3, 3))
	var elf := TestCombat.hero(e, "liriel_dawnsong", Vector2i(6, 3), 9)
	var human := TestCombat.hero(e, "ilse_varga", Vector2i(6, 5), 9)
	var sleep := Compendium.shared().spell_data("sleep")
	assert_false(AiSpells.sleeps(elf))
	assert_true(AiSpells.sleeps(human))
	assert_eq(e.ai.spells.worth(s, sleep, elf), 0.0, "the elf won't sleep")
	assert_true(e.ai.spells.worth(s, sleep, human) > 0.0)


func test_strahd_drops_to_mist_and_the_story_learns_he_is_in_his_coffin() -> void:
	var e := _field()
	e.location_id = "castle_ravenloft_audience_hall"
	var s := _strahd(e, Vector2i(3, 3))
	TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 9)
	_order(e, [s], [30])
	e.deal_damage(null, s, [{"amount": 999, "type": "force"}], false, "test")
	assert_true(bool(e.legendary.story_flags.get("strahd_in_coffin", false)))
	var e2 := _field()
	e2.location_id = "castle_ravenloft_strahds_tomb"
	var s2 := _strahd(e2, Vector2i(3, 3))
	TestCombat.hero(e2, "hedda_ironvow", Vector2i(4, 3), 9)
	_order(e2, [s2], [30])
	e2.deal_damage(null, s2, [{"amount": 999, "type": "force"}], false, "test")
	assert_true(bool(e2.legendary.story_flags.get("strahd_destroyed", false)))
	assert_eq(str(e2.legendary.story_quests.get("strahds_lair", "")), "destroyed")


## A few rounds of Strahd in his lair against two heroes (the heroes only end their turns): he acts, takes legendary
## and lair actions, and nothing breaks.
func test_a_lair_fight_with_strahd_plays_out() -> void:
	var e := _field()
	var s := _strahd(e, Vector2i(3, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(6, 3), 9)
	var b := TestCombat.hero(e, "ilse_varga", Vector2i(7, 5), 9)
	_order(e, [a, s, b], [22, 15, 8], true)
	var legendary := 0
	var lair := 0
	var guard := 0
	while not e.is_over() and e.round_no <= 4 and guard < 200:
		guard += 1
		if e.pending != null:
			e.answer_reaction(false)
		elif e.current().is_player_controlled():
			e.end_turn()
		else:
			e.run_ai_turn()
		for ev in e.drain_events():
			legendary += 1 if str(ev["type"]) == "legendary" else 0
			lair += 1 if str(ev["type"]) == "lair" else 0
	assert_true(guard < 200, "the fight moves on")
	assert_true(legendary > 0, "legendary actions were taken")
	assert_true(lair > 0, "the lair acted")


func test_the_resting_place_can_be_a_place_inside_the_location() -> void:
	var e := _field()
	e.location_id = "test_catacombs_lower"
	e.places = ["test_crypt"]
	assert_true(e.at_place("test_crypt") and e.at_place("test_catacombs_lower"))
	assert_false(e.at_place("") or e.at_place("test_hall"))
	var boss := _add_boss(e, _boss(_misty()), Vector2i(3, 3))
	TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 5)
	e.deal_damage(null, boss, [{"amount": 500, "type": "force"}], false, "test")
	assert_true(bool(e.legendary.story_flags.get("boss_destroyed", false)), "destroyed in the coffin's room")


func test_the_heart_of_sorrow_wards_strahd_in_his_castle_until_it_breaks() -> void:
	var data := Compendium.shared().monster_data("strahd_von_zarovich")
	var st := StoryState.new()
	assert_eq(LocationView.ward_for(data, {"region": "castle_ravenloft"}, st), 50)
	assert_eq(LocationView.ward_for(data, {"region": "vallaki"}, st), 0, "only in the castle")
	st.set_flag("heart_of_sorrow_shattered")
	assert_eq(LocationView.ward_for(data, {"region": "castle_ravenloft"}, st), 0, "the heart is broken")
	var e := _field()
	var s := _strahd(e, Vector2i(3, 3))
	s.creature.ward_hp = 50
	e.deal_damage(null, s, [{"amount": 30, "type": "force"}], false, "test")
	assert_eq(s.creature.hp, s.creature.max_hp(), "the ward takes it first")
	assert_eq(s.creature.ward_hp, 20)


## Strahd's shapes wear their own sprites when he changes (combat_view swaps the token's art): the bat's and the
## wolf's, and his own drifting mist (strahd_mist).
func test_strahds_shapes_wear_their_sprites() -> void:
	var data := Compendium.shared().monster_data("strahd_von_zarovich")
	var art := {}
	for shape: Variant in (data["forms"] as Dictionary)["shapes"] as Array:
		art[str((shape as Dictionary)["id"])] = str((shape as Dictionary).get("art", ""))
	assert_eq(art.get("bat"), "bat")
	assert_eq(art.get("wolf"), "wolf")
	assert_eq(art.get("mist"), "strahd_mist")
	for id: String in ["bat", "wolf", "mist"]:
		assert_true(DirectionalSprite.has_attack(DirectionalSprite.frames_for(str(art[id]))), "%s has a sheet" % id)


## Strahd takes mist form below a quarter of his Hit Points to regenerate out of reach, but not from a party he can
## finish: with every hero left standing under a third of their Hit Points the mist only let the last blades chase him
## round the room while he mended, and a boss-HP retune of his fights ended in the round limit (2026-10-14).
func test_strahd_does_not_run_to_mist_from_a_party_he_can_finish() -> void:
	for beaten: bool in [false, true]:
		var e := _field()
		var s := _strahd(e, Vector2i(3, 3))
		var godrick := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(4, 3), 7)
		s.creature.hp = 10   # he regenerates 20 as his turn starts and is still under a quarter
		if beaten:
			godrick.creature.hp = godrick.creature.max_hp() / 4
		TestCombat.start_with(e, s)
		e.ai.play_turn(s)
		assert_eq(e.legendary.form(s) == "mist", not beaten, "mist form only against a party that can still hurt him (beaten %s)" % beaten)
