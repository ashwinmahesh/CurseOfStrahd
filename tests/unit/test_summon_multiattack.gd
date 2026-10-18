extends TestCase
## A summon the player runs makes its whole Multiattack: in the 2024 spells, attacks equal to half the spell's level,
## rounded down (a Summon Celestial cast with a 5th-level slot makes two). Encounter.attack used to give any stat-block
## creature one attack and leave the rest of its Multiattack to the AI, which a player's summon never has.


func _nums() -> Dictionary:
	return {"dc": Breakdown.new("DC").add("DC", 15), "attack": Breakdown.new("Attack").add("Attack", 7), "mod": 4}


## Every spell that calls up a spirit with a Multiattack: [spell, its own level, a choice]. The dinosaur and the plant
## also have the forms that add an alternative to the Multiattack.
const SPIRITS := [
	["summon_beast", 2, "land"], ["summon_fey", 3, "fuming"], ["summon_undead", 3, "ghostly"], ["summon_undead", 3, "skeletal"],
	["giant_insect", 4, "spider"], ["summon_aberration", 4, "slaad"], ["summon_construct", 4, "stone"],
	["summon_elemental", 4, "fire"], ["summon_celestial", 5, "avenger"], ["summon_celestial", 5, "defender"],
	["summon_dragon", 5, "cold"], ["summon_plant", 5, "tree"], ["summon_plant", 5, "fungus"], ["summon_fiend", 6, "demon"],
	["summon_dinosaur", 6, "ankylosaur"], ["summon_dinosaur", 6, "tyrannosaur"],
]


## The attacks half the spell's level gives (at least one).
static func _want(level: int) -> int:
	return maxi(1, level / 2)


## `spell_id` cast with a `level` slot by a caster whose turn it is; the summon's turn has begun, with a foe beside it.
## {e, c (the caster), s (the summon), foe, cat (the hotbar)}.
func _summon_turn(spell_id: String, level: int, choice: String) -> Dictionary:
	var e := TestCombat.open_field(5)
	var c := TestCombat.hero(e, "silvain_aster", Vector2i(1, 3))
	TestCombat.punching_bag(e, Vector2i(11, 7), 100)
	TestCombat.start_with(e, c)
	c.action_available = true
	c.bonus_available = true
	var r := e.spells.cast_with_numbers(c, spell_id, level, [], Vector2(3.5, 3.5), _nums(), {"choice": choice})
	assert_true(r.ok, "%s cast at %d (%s): %s" % [spell_id, level, choice, r.reason])
	var s: Combatant = null
	for id: Variant in e.spells.summoned.get(c.id, []):
		s = e.get_c(str(id))
	assert_true(s != null, "%s called something up" % spell_id)
	var foe := TestCombat.punching_bag(e, Vector2i(s.cell.x + CombatGrid.size_cells_for(s.creature.size), s.cell.y), 5000)
	var guard := 0
	while e.current() != s and guard < 12:
		e.end_turn()
		guard += 1
	assert_eq(e.current(), s, "its turn comes right after the caster's")
	return {"e": e, "c": c, "s": s, "foe": foe, "cat": ActionCatalog.new(e)}


## The first of the summon's own attacks on the hotbar.
func _first_attack(cat: ActionCatalog, s: Combatant) -> Dictionary:
	for a in cat.actions_for(s):
		if str(a["id"]).begins_with("attack:monster:"):
			return a
	return {}


## How many attacks the hotbar lets the summon make at `foe` this turn.
func _attacks_made(d: Dictionary) -> int:
	var cat := d["cat"] as ActionCatalog
	var s := d["s"] as Combatant
	var made := 0
	while made < 12:
		var action := _first_attack(cat, s)
		if action.is_empty() or not cat.perform(s, action, [d["foe"]]).ok:
			break
		made += 1
	return made


func test_a_fifth_level_summon_celestial_attacks_twice() -> void:
	for choice: String in ["avenger", "defender"]:
		var d := _summon_turn("summon_celestial", 5, choice)
		var s := d["s"] as Combatant
		assert_eq((d["e"] as Encounter).attacks_per_action(s), 2, "%s: the hotbar counts two attacks" % choice)
		assert_eq(_attacks_made(d), 2, "%s: two attacks, then no more" % choice)


func test_a_higher_slot_adds_attacks() -> void:
	for level: int in [5, 6, 7, 8, 9]:
		var d := _summon_turn("summon_celestial", level, "defender")
		assert_eq(_attacks_made(d), _want(level), "level %d" % level)


func test_every_summon_spirit_attacks_half_its_spell_level() -> void:
	for row: Array in SPIRITS:
		for up: int in [0, 1, 2]:
			var level := int(row[1]) + up
			var d := _summon_turn(str(row[0]), level, str(row[2]))
			var want := _want(level)
			assert_eq((d["e"] as Encounter).attacks_per_action(d["s"] as Combatant), want, "%s %s at %d: the hotbar's count" % [row[0], row[2], level])
			assert_eq(_attacks_made(d), want, "%s %s at %d" % [row[0], row[2], level])


## What else grows with the slot, read from the 2024 stat blocks: [spell, choice, its level, Armor Class and Hit Points at
## that level, the Hit Points each higher level adds]. Armor Class and the attacks' damage rise by 1 a level.
const GROWTH := [
	["summon_beast", "land", 2, 13, 30, 5], ["summon_beast", "air", 2, 13, 20, 5], ["summon_fey", "tricksy", 3, 15, 30, 10],
	["summon_undead", "putrid", 3, 14, 30, 10], ["summon_undead", "skeletal", 3, 14, 20, 10], ["giant_insect", "wasp", 4, 15, 30, 10],
	["summon_aberration", "mind_flayer", 4, 15, 40, 10], ["summon_construct", "clay", 4, 17, 40, 15], ["summon_elemental", "water", 4, 15, 50, 10],
	["summon_celestial", "avenger", 5, 16, 40, 10], ["summon_celestial", "defender", 5, 18, 40, 10], ["summon_dragon", "lightning", 5, 19, 50, 10],
	["summon_fiend", "demon", 6, 18, 50, 15], ["summon_fiend", "devil", 6, 18, 40, 15], ["summon_fiend", "yugoloth", 6, 18, 60, 15],
]


## The flat damage of the spirit's first attack ("1d8+7" is 7).
static func _damage_bonus(s: Combatant) -> int:
	for a: Variant in (s.creature as Monster).data.get("actions", []):
		var damage := (a as Dictionary).get("damage", []) as Array
		if not damage.is_empty():
			return int(str((damage[0] as Dictionary)["dice"]).get_slice("+", 1))
	return -1


func test_armor_class_hit_points_and_damage_grow_with_the_slot() -> void:
	for row: Array in GROWTH:
		var base: Dictionary = {}
		for up: int in [0, 1, 2]:
			var level := int(row[2]) + up
			var d := _summon_turn(str(row[0]), level, str(row[1]))
			var s := d["s"] as Combatant
			var what := "%s %s at %d" % [row[0], row[1], level]
			assert_eq(s.creature.ac_value(), int(row[3]) + up, "%s: Armor Class" % what)
			assert_eq(s.creature.max_hp(), int(row[4]) + int(row[5]) * up, "%s: Hit Points" % what)
			if up == 0:
				base["damage"] = _damage_bonus(s)
			assert_eq(_damage_bonus(s), int(base["damage"]) + up, "%s: damage" % what)


## A Draconic Spirit's Breath Weapon replaces one of its Rend attacks (the Multiattack's "or"), so a spirit that breathes
## first still has its other attacks, and one that has made all of them can't breathe.
func test_the_draconic_breath_takes_the_place_of_one_rend() -> void:
	var d := _summon_turn("summon_dragon", 6, "cold")   # three attacks
	var e := d["e"] as Encounter
	var s := d["s"] as Combatant
	var cat := d["cat"] as ActionCatalog
	var foe := d["foe"] as Combatant
	var breath := cat.find(s, "feat:creature:breath")
	assert_true(bool(breath["legal"]), str(breath))
	assert_true(cat.perform(s, breath, [foe]).ok)
	assert_eq(s.attacks_left, 2, "the breath was one of the three")
	assert_false(s.action_available)
	assert_eq(_attacks_made(d), 2, "two Rends after it")
	assert_false(bool(cat.find(s, "feat:creature:breath")["legal"]), "and no more breath")
	assert_eq(e.current(), s)


func test_a_dragon_that_rended_twice_has_one_attack_for_the_breath() -> void:
	var d := _summon_turn("summon_dragon", 6, "fire")
	var s := d["s"] as Combatant
	var cat := d["cat"] as ActionCatalog
	for i in 2:
		assert_true(cat.perform(s, _first_attack(cat, s), [d["foe"]]).ok)
	var breath := cat.find(s, "feat:creature:breath")
	assert_true(bool(breath["legal"]), "one attack left: %s" % str(breath))
	assert_eq(str(breath["cost"]), "attack")
	assert_true(cat.perform(s, breath, [d["foe"]]).ok)
	assert_eq(s.attacks_left, 0)
	assert_false(bool(cat.find(s, "feat:creature:breath")["legal"]))
	assert_false(cat.perform(s, _first_attack(cat, s), [d["foe"]]).ok, "all three spent")


## Only the attacks a Multiattack lists go on to the rest of it: an Ape's Rock is a single attack, its Fist two.
func test_an_attack_outside_the_multiattack_is_a_single_attack() -> void:
	var e := TestCombat.open_field(5)
	var ape := TestCombat.foe(e, "ape", Vector2i(3, 3))
	ape.side = &"guest"
	ape.controller = &"player"
	var bag := TestCombat.punching_bag(e, Vector2i(4, 3), 5000)
	TestCombat.start_with(e, ape)
	assert_eq(e.attacks_per_action(ape), 2, "the Ape's Multiattack is two Fists")
	assert_true(e.attack(ape, bag, "monster:rock").ok)
	assert_eq(ape.attacks_left, 0, "the Rock isn't part of it")
	assert_false(ape.action_available)
	ape.action_available = true
	ape.attacks_left = 0
	var fist := e.attack(ape, bag, "monster:fist")
	assert_true(fist.ok, fist.reason)
	assert_eq(ape.attacks_left, 1, "the Fist is")


func test_a_foe_without_a_player_keeps_one_attack_per_action() -> void:
	var e := TestCombat.open_field(5)
	var b := TestCombat.foe(e, "bandit_captain", Vector2i(3, 3))
	assert_eq(e.attacks_per_action(b), 1, "the AI starts its own Multiattack")
	var z := TestCombat.foe(e, "zombie", Vector2i(6, 6))
	z.side = &"guest"
	z.controller = &"player"
	assert_eq(e.attacks_per_action(z), 1, "a zombie has no Multiattack")


## The slot a character really casts with, not only the level a test names: a Wizard's 5th-level slot, and a Warlock's
## Pact Magic slot (always its pact level) for a 3rd-level spell.
func _real_cast(ch: Character, cell: Vector2i, slot: int) -> Dictionary:
	var spell := ch.spellcasting[0] as Dictionary
	(spell["prepared"] as Array).append("summon_fey")
	var e := TestCombat.open_field(5)
	var c := e.add(ch, &"party", cell)
	TestCombat.punching_bag(e, Vector2i(11, 7), 100)
	TestCombat.start_with(e, c)
	var r := e.spells.cast(c, "summon_fey", slot, [], Vector2(4.5, 3.5), Vector2.ZERO, {"choice": "fuming"})
	assert_true(r.ok, r.reason)
	var s: Combatant = null
	for id: Variant in e.spells.summoned.get(c.id, []):
		s = e.get_c(str(id))
	e.end_turn()
	return {"e": e, "c": c, "s": s}


func test_a_wizards_fifth_level_slot_makes_a_fifth_level_fey_spirit() -> void:
	var d := _real_cast(TestChars.pregen("silvain_aster", 9), Vector2i(2, 3), 5)
	var s := d["s"] as Combatant
	assert_eq(s.creature.max_hp(), 50, "30 + 10 for each level above 3")
	assert_eq(s.creature.ac_value(), 17, "12 + 5")
	assert_eq((d["e"] as Encounter).attacks_per_action(s), 2)


func test_a_warlocks_pact_slot_is_the_level_of_the_fey_spirit() -> void:
	var ch := TestChars.custom("warlock", "human", 9)   # Pact Magic slots of the 5th level
	var d := _real_cast(ch, Vector2i(2, 3), 3)
	var s := d["s"] as Combatant
	assert_eq(s.creature.max_hp(), 50, "cast at the pact level, not the spell's 3rd")
	assert_eq(s.creature.ac_value(), 17)
	assert_eq((d["e"] as Encounter).attacks_per_action(s), 2)
