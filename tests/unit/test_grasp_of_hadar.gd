extends TestCase
## Grasp of Hadar (Ashwin, 2026-10-13): Xanathar's invocation, which the 2024 book dropped, kept as a house rule
## (deviations.md) and built as the mirror of the 2024 Repelling Blast: a hit with a damaging Warlock cantrip's attack
## pulls a Large or smaller creature up to 10 ft straight toward the warlock, beam by beam, unless its switch on the
## Warlock tab is Off (not a reaction: Ashwin, 2026-10-13). The pull is forced movement like the push: no Opportunity
## Attacks, and the traps and areas it crosses still act. A warlock with both moves a creature one way: turning one on
## turns the other off.

const INV := "warlock.1.eldritch_invocations"


## Kip Smudgewick (Warlock 5: two beams of Eldritch Blast) with Grasp of Hadar in place of Repelling Blast, or beside
## it with `both`.
func _kip(e: Encounter, cell: Vector2i = Vector2i(2, 3), both: bool = false, side: StringName = &"party") -> Combatant:
	var ch := TestChars.pregen("kip_smudgewick", 5)
	for cd in ch.choice_defs:
		if cd.kind == "invocation":
			var i := cd.picks.find("repelling_blast")
			assert_true(i >= 0, "Kip knows Repelling Blast: %s" % [cd.picks])
			if both:
				cd.picks.append("grasp_of_hadar")
			else:
				cd.picks[i] = "grasp_of_hadar"
	return e.add(ch, side, cell)


## How many of the last spell's attack rolls hit.
func _hits(e: Encounter) -> int:
	return e.events.filter(func(ev: Dictionary) -> bool: return str(ev.get("type", "")) == "attack" and bool(ev.get("hit", false))).size()


## The On / Off switch `label` on the Warlock tab.
func _rule(cat: ActionCatalog, c: Combatant, label: String) -> Dictionary:
	for s in cat.slots(c, cat.class_tab(c)):
		if str(s["label"]) == label:
			return s
	return {}


# --- Picking it --------------------------------------------------------------------------------------------

## A level 1 Warlock (Charisma 17) knowing `cantrips`, with Armor of Shadows; a human with Alert.
func _create(cantrips: Array) -> Character:
	var b := CharacterBuilder.new()
	b.set_class("warlock")
	b.set_background("charlatan")
	b.set_species("human")
	b.set_name("Test Warlock")
	b.set_base_scores({"str": 8, "dex": 14, "con": 13, "int": 12, "wis": 10, "cha": 15})
	b.choose("background.abilities", ["cha", "cha", "con"])
	b.choose("species.versatile", ["alert"])
	assert_eq(b.choose(INV, ["armor_of_shadows"]), [] as Array[String])
	assert_eq(b.choose("warlock.cantrips", cantrips), [] as Array[String])
	assert_eq(TestChars.auto_pick(b.pending_choices, b.choose), [] as Array[String])
	var ch := b.build_character()
	assert_true(ch != null, "builds: %s" % [b.errors()])
	return ch


func test_a_level_2_warlock_with_an_attack_cantrip_can_take_it() -> void:
	var ch := _create(["eldritch_blast", "toll_the_dead"])
	var inv := ch.choice(INV)
	ChoiceOptions.populate(inv, ch)
	assert_eq(inv.option("grasp_of_hadar").reason, "Requires Warlock level 2", "Repelling Blast's level")
	var up := LevelUpController.new(ch)
	assert_true(up.choose_class("warlock"))
	up.take_fixed_hit_points()
	assert_eq(up.choose(INV, ["armor_of_shadows", "grasp_of_hadar", "eldritch_mind"]), [] as Array[String], "picked on level-up")
	assert_eq(TestChars.auto_pick(up.pending_choices, up.choose), [] as Array[String])
	assert_true(up.confirm(), str(up.errors()))
	assert_true("grasp_of_hadar" in ch.invocations, str(ch.invocations))
	var saved := Character.from_dict(ch.to_dict())
	assert_true("grasp_of_hadar" in saved.invocations, "kept in a save")


func test_it_needs_a_cantrip_with_an_attack_roll_like_repelling_blast() -> void:
	var ch := _create(["toll_the_dead", "mind_sliver"])
	var up := LevelUpController.new(ch)
	assert_true(up.choose_class("warlock"))
	up.take_fixed_hit_points()
	assert_eq(up.choose(INV, ["armor_of_shadows", "eldritch_mind", "devils_sight"]), [] as Array[String])
	assert_eq(TestChars.auto_pick(up.pending_choices, up.choose), [] as Array[String])
	assert_true(up.confirm(), str(up.errors()))
	var inv := ch.choice(INV)
	ChoiceOptions.populate(inv, ch)
	var why := "Requires a Warlock cantrip that deals damage with an attack roll"
	assert_eq(inv.option("grasp_of_hadar").reason, why)
	assert_eq(inv.option("repelling_blast").reason, why, "the same prerequisite")


# --- The pull ----------------------------------------------------------------------------------------------

func test_each_beam_that_hits_pulls_10_ft_toward_the_warlock() -> void:
	var e := TestCombat.open_field(3)
	var kip := _kip(e)
	var bag := TestCombat.punching_bag(e, Vector2i(9, 3), 300)
	TestCombat.start_with(e, kip)
	var cat := ActionCatalog.new(e)
	var rule := _rule(cat, kip, "Grasp of Hadar")
	assert_eq(cat.class_tab(kip), "Warlock")
	assert_true(bool(rule.get("toggle", false)), "a Grasp of Hadar toggle on the Warlock tab")
	assert_eq(str(rule["sub"]), "On", "pulling to start with")
	assert_false(cat.slots(kip, ActionCatalog.REACTIONS).any(func(s: Dictionary) -> bool: return str(s["label"]) == "Grasp of Hadar"),
		"not a reaction")
	assert_true(_rule(cat, kip, "Repelling Blast").is_empty(), "Kip traded Repelling Blast for it")
	TestCombat.next_d20(e, 19)
	e.events.clear()
	assert_true(e.spells.cast(kip, "eldritch_blast", 0, [bag]).ok)
	var hits := _hits(e)
	assert_true(hits >= 1, "the first beam hits")
	assert_eq(bag.cell, Vector2i(9 - 2 * hits, 3), "10 ft closer for each of %d hits" % hits)
	assert_true(e.events.any(func(ev: Dictionary) -> bool: return str(ev.get("type", "")) == "move" and bool(ev.get("forced", false))),
		"a forced move the board animates")


func test_off_leaves_the_target_where_it_stands() -> void:
	var e := TestCombat.open_field(3)
	var kip := _kip(e)
	var bag := TestCombat.punching_bag(e, Vector2i(8, 3), 300)
	TestCombat.start_with(e, kip)
	var cat := ActionCatalog.new(e)
	assert_true(cat.set_rule(kip, cat.find(kip, "feat:reaction_policy:grasp_of_hadar:never")).ok, "set Off")
	TestCombat.next_d20(e, 19)
	var hp := bag.creature.hp
	assert_true(e.spells.cast(kip, "eldritch_blast", 0, [bag]).ok)
	assert_true(bag.creature.hp < hp, "the blast still hits")
	assert_eq(bag.cell, Vector2i(8, 3), "but doesn't pull")


func test_it_stops_beside_the_warlock() -> void:
	var e := TestCombat.open_field(3)
	var kip := _kip(e)
	var bag := TestCombat.punching_bag(e, Vector2i(5, 3), 300)
	TestCombat.start_with(e, kip)
	TestCombat.next_d20(e, 19)
	assert_true(e.spells.cast(kip, "eldritch_blast", 0, [bag]).ok)
	assert_eq(bag.cell, Vector2i(3, 3), "next to Kip, never into his square")
	assert_eq(kip.cell, Vector2i(2, 3))


func test_a_diagonal_pull_comes_straight_toward_the_warlock() -> void:
	var e := TestCombat.open_field(3)
	var kip := _kip(e)
	var bag := TestCombat.punching_bag(e, Vector2i(8, 7), 300)
	TestCombat.start_with(e, kip)
	var before := e.distance(kip, bag)
	TestCombat.next_d20(e, 19)
	e.events.clear()
	assert_true(e.spells.cast(kip, "eldritch_blast", 0, [bag]).ok)
	assert_eq(e.distance(kip, bag), before - 10 * _hits(e), "10 ft closer a hit")


func test_a_huge_creature_isnt_pulled() -> void:
	var e := TestCombat.open_field(3)
	var kip := _kip(e)
	var blight := TestCombat.foe(e, "tree_blight", Vector2i(7, 2))
	assert_eq(blight.creature.size, &"huge")
	TestCombat.start_with(e, kip)
	TestCombat.next_d20(e, 19)
	var hp := blight.creature.hp
	assert_true(e.spells.cast(kip, "eldritch_blast", 0, [blight]).ok)
	assert_true(blight.creature.hp < hp, "hit")
	assert_eq(blight.cell, Vector2i(7, 2), "too big to pull, as Repelling Blast is too big to push")


func test_a_foe_with_it_pulls_a_hero() -> void:
	var e := TestCombat.open_field(3)
	var warlock := _kip(e, Vector2i(10, 3), false, &"enemy")
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(4, 3))
	TestCombat.start_with(e, warlock)
	TestCombat.next_d20(e, 19)
	e.events.clear()
	assert_true(e.spells.cast(warlock, "eldritch_blast", 0, [ilse]).ok)
	var hits := _hits(e)
	assert_true(hits >= 1)
	assert_eq(ilse.cell, Vector2i(4 + 2 * hits, 3), "pulled toward the foe")


# --- Forced movement's rules, as for the push ----------------------------------------------------------------

func test_the_pull_provokes_no_opportunity_attack() -> void:
	var e := TestCombat.open_field(3)
	var kip := _kip(e)
	var bag := TestCombat.punching_bag(e, Vector2i(8, 3), 300)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(9, 3))
	ilse.reaction_rules["opportunity_attack"] = "auto"
	TestCombat.start_with(e, kip)
	TestCombat.next_d20(e, 19)
	assert_true(e.spells.cast(kip, "eldritch_blast", 0, [bag]).ok)
	assert_true(bag.cell.x < 8, "pulled out of Ilse's reach: %s" % bag.cell)
	assert_true(e.pending == null, "nobody is asked about an Opportunity Attack")
	assert_true(ilse.reaction_available, "Ilse's Reaction is unspent")
	assert_false(e.log.entries.any(func(x: Dictionary) -> bool: return str(x["text"]).contains("Opportunity")), "no Opportunity Attack")


func test_a_pull_across_spike_growth_hurts_as_a_push_would() -> void:
	var e := TestCombat.open_field(3)
	var kip := _kip(e, Vector2i(1, 3))
	var druid := TestCombat.caster_with(e, ["spike_growth"], Vector2i(0, 7))
	var bag := TestCombat.punching_bag(e, Vector2i(9, 3), 300)
	TestCombat.start_with(e, druid)
	assert_true(e.spells.cast(druid, "spike_growth", 2, [], Vector2(7.0, 3.5)).ok)
	e.turn_index = e.order.find(kip)
	e._begin_turn()
	e.log.entries.clear()
	TestCombat.next_d20(e, 19)
	assert_true(e.spells.cast(kip, "eldritch_blast", 0, [bag]).ok)
	assert_true(bag.cell.x < 9, "pulled: %s" % bag.cell)
	var spikes := e.log.entries.filter(func(x: Dictionary) -> bool: return str(x["text"]).contains("Piercing"))
	assert_eq(spikes.size(), 9 - bag.cell.x, "the spikes tear at it for every 5 ft it's dragged")


func test_a_creature_pulled_onto_a_trap_springs_it() -> void:
	var e := TestCombat.open_field(3)
	var kip := _kip(e)
	var bag := TestCombat.punching_bag(e, Vector2i(6, 3), 300)
	e.traps.add({"id": "snare", "label": "a test trap", "cells": [[5, 3]], "detect_dc": 15, "disarm_dc": 15,
		"save": {"ability": "dex", "dc": 30}, "damage": "2d6", "damage_type": "piercing", "condition": "poisoned"})
	TestCombat.start_with(e, kip)
	TestCombat.next_d20(e, 19)
	assert_true(e.spells.cast(kip, "eldritch_blast", 0, [bag]).ok)
	assert_true(bag.cell.x < 6, "pulled across the trap: %s" % bag.cell)
	assert_eq(",".join(e.traps.sprung_ids()), "snare", "it goes off under the bag")
	assert_true(bag.creature.has_condition(&"poisoned"), "a failed DC 30 save")


# --- Beside Repelling Blast ----------------------------------------------------------------------------------

func test_with_repelling_blast_too_one_rule_at_a_time_moves_the_creature() -> void:
	var e := TestCombat.open_field(3)
	var kip := _kip(e, Vector2i(2, 3), true)
	var bag := TestCombat.punching_bag(e, Vector2i(6, 3), 300)
	TestCombat.start_with(e, kip)
	var cat := ActionCatalog.new(e)
	assert_eq(str(_rule(cat, kip, "Repelling Blast")["sub"]), "On", "the push, as before")
	assert_eq(str(_rule(cat, kip, "Grasp of Hadar")["sub"]), "Off", "the pull waits beside it")
	TestCombat.next_d20(e, 19)
	assert_true(e.spells.cast(kip, "eldritch_blast", 0, [bag]).ok)
	assert_true(bag.cell.x > 6, "pushed: %s" % bag.cell)
	assert_true(cat.set_rule(kip, cat.find(kip, "feat:reaction_policy:grasp_of_hadar:auto")).ok, "pull instead")
	assert_eq(str(_rule(cat, kip, "Repelling Blast")["sub"]), "Off", "turning the pull on turns the push off")
	var at := bag.cell.x
	e.end_turn()
	while e.current() != kip:
		e.end_turn()
	TestCombat.next_d20(e, 19)
	assert_true(e.spells.cast(kip, "eldritch_blast", 0, [bag]).ok)
	assert_true(bag.cell.x < at, "pulled: %s" % bag.cell)
	assert_true(cat.set_rule(kip, cat.find(kip, "feat:reaction_policy:repelling_blast:auto")).ok)
	assert_eq(str(_rule(cat, kip, "Grasp of Hadar")["sub"]), "Off", "and the other way round")
	assert_true(cat.set_rule(kip, cat.find(kip, "feat:reaction_policy:repelling_blast:never")).ok)
	assert_eq(str(_rule(cat, kip, "Grasp of Hadar")["sub"]), "Off", "turning one off leaves the other as it was")
