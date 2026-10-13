extends TestCase
## Skill checks on things in the world (story/world_checks.gd; owner, 2026-10-11: Nature, Arcana, Acrobatics and the
## rest need real uses outside fights and conversations): the best hand who hasn't tried rolls, each character gets one
## try (or the party one, `once`), a proficient ally Helps (Advantage) unless it's done alone, Guidance cast first adds
## 1d4 (the menu's chance counts on someone free to concentrate), the chance the menu shows is the real one, and an
## outcome gives, teaches, inspires, heals or hurts.

const LOC := "test_world_checks"

var st: StoryState
var dice: DiceRoller


func before_each() -> void:
	st = StoryState.new()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	dice = DiceRoller.new(7)


func _check(skill: String, dc: int, extra: Dictionary = {}) -> Dictionary:
	var c := {"id": "test_%s" % skill, "skill": skill, "dc": dc, "label": "Try it", "success": {}}
	c.merge(extra, true)
	return c


func _best_at(skill: StringName) -> Character:
	var best: Character = null
	for ch in st.party:
		if best == null or ch.skill_bonus(skill).total() > best.skill_bonus(skill).total():
			best = ch
	return best


func test_the_best_hand_rolls_then_the_next_best_after_a_failure() -> void:
	var c := _check("perception", 40)
	var first := WorldChecks.roller(st, LOC, c)
	assert_eq(first, _best_at(&"perception"), "the sharpest eyes look first")
	var res := WorldChecks.attempt(st, LOC, c, dice)
	assert_eq(res["who"], first)
	assert_false(bool(res["success"]), "DC 40 is out of reach")
	assert_true(WorldChecks.tried(st, LOC, c, first), "a failed try is that character's last")
	var second := WorldChecks.roller(st, LOC, c)
	assert_true(second != null and second != first, "someone else can still try")
	assert_true(WorldChecks.open(st, LOC, c), "and the check is still offered")
	for i in 3:
		WorldChecks.attempt(st, LOC, c, dice)
	assert_eq(WorldChecks.roller(st, LOC, c), null, "once everyone has tried, nobody's left")
	assert_true(WorldChecks.preview(st, LOC, c).is_empty())


func test_a_once_check_is_spent_by_one_failure() -> void:
	var c := _check("acrobatics", 40, {"once": true})
	WorldChecks.attempt(st, LOC, c, dice)
	assert_true(WorldChecks.spent(st, LOC, c), "a crumbling ledge gives one chance")
	assert_false(WorldChecks.open(st, LOC, c))


func test_a_success_is_done_for_good() -> void:
	var c := _check("history", 1)
	var res := WorldChecks.attempt(st, LOC, c, dice)
	assert_true(bool(res["success"]))
	assert_true(WorldChecks.done(st, LOC, c))
	assert_false(WorldChecks.open(st, LOC, c), "nothing more to learn there")
	assert_true(st.last_check, "check.last follows it")


func test_a_proficient_ally_helps_unless_it_is_done_alone() -> void:
	var c := _check("perception", 15)
	var who := WorldChecks.roller(st, LOC, c)
	var helper := WorldChecks.helper(st, c, who)
	assert_true(helper != null and helper != who and helper.skill_rank(&"perception") > 0, "another trained eye helps")
	var pv := WorldChecks.preview(st, LOC, c)
	assert_true((pv["advantage"] as Array).has("Help (%s)" % helper.name.get_slice(" ", 0)), str(pv["advantage"]))
	var res := WorldChecks.attempt(st, LOC, c, dice)
	assert_true((res["test"] as D20Test).advantage, "the roll has Advantage")
	var alone := _check("perception", 15, {"alone": true, "id": "alone_perception"})
	assert_eq(WorldChecks.helper(st, alone, WorldChecks.roller(st, LOC, alone)), null, "only one can do it")
	assert_eq(WorldChecks.helper(st, _check("str", 15), who), null, "a plain Strength check takes no Help (2024: it names a skill)")


func test_nobody_untrained_helps() -> void:
	for ch in st.party:
		if ch.skill_rank(&"arcana") > 0:
			return   # someone's trained: nothing to show here
	var c := _check("arcana", 15)
	assert_eq(WorldChecks.helper(st, c, WorldChecks.roller(st, LOC, c)), null)


func test_guidance_adds_a_d4_from_someone_free_to_concentrate() -> void:
	var cleric: Character = null
	for ch in st.party:
		if ch.known_spells().any(func(k: Dictionary) -> bool: return str(k["id"]) == "guidance"):
			cleric = ch
	assert_true(cleric != null, "the party has Guidance (Hedda)")
	var c := _check("investigation", 15)
	var who := WorldChecks.roller(st, LOC, c)
	assert_eq(WorldChecks.guide(st, c, who), cleric)
	assert_eq(WorldChecks.preview(st, LOC, c)["guide"], cleric, "the menu's chance counts on it")
	assert_false("Guidance" in (WorldChecks.attempt(st, LOC, _check("investigation", 15, {"id": "unasked"}), dice)["test"] as D20Test).extra_label,
		"nothing is cast unless it's asked for or Automatic")
	# Cast before the roll (the prompt's answer, GuidanceOffer): the d4 rides on the check.
	var offer := GuidanceOffer.offer(st, who, &"investigation", 15)
	var at := (offer["casters"] as Array).map(func(e: Dictionary) -> Creature: return e["caster"]).find(cleric)
	var res := WorldChecks.attempt(st, LOC, c, dice, GuidanceOffer.answer(offer, at))
	var t := res["test"] as D20Test
	assert_true("Guidance" in t.extra_label, "the 1d4 is on the roll: %s" % t.describe())
	assert_between(float(t.extra), 1.0, 4.0)
	assert_false("+ +" in t.describe(), "the log says it once: %s" % t.describe())
	var shown := DiceRoll.parts_text(DiceRoll.from_test(t, cleric.name, "Investigation"))
	assert_true(shown.ends_with("Guidance (%s) +%d" % [cleric.name.get_slice(" ", 0), t.extra]), "the big d20 says it once: %s" % shown)
	assert_eq(WorldChecks.guide(st, _check("wis", 15), cleric), null, "a plain ability check names no skill to guide")
	cleric.concentration = Concentration.new(cleric, "bless", "Bless")
	assert_eq(WorldChecks.guide(st, c, cleric), null, "casting it would end the spell they're keeping")
	cleric.concentration = null


func test_the_chance_shown_is_the_real_one() -> void:
	assert_between(WorldChecks.chance(5, 15, false, false), 0.549, 0.551, "d20 + 5 meets 15 on 10 or more: 55%")
	assert_between(WorldChecks.chance(5, 15, true, false), 0.797, 0.798, "with Advantage: 1 - 0.45^2")
	assert_between(WorldChecks.chance(5, 15, false, true), 0.302, 0.303, "with Disadvantage: 0.55^2")
	assert_between(WorldChecks.chance(5, 15, true, true), 0.549, 0.551, "both cancel")
	assert_between(WorldChecks.chance(5, 15, false, false, true), 0.674, 0.676, "Guidance's d4 averages +2.5")
	assert_eq(WorldChecks.chance(0, 25, false, false), 0.0, "no natural 20 on a check")
	assert_eq(WorldChecks.chance(10, 5, false, false), 1.0, "no natural 1 either")


func test_an_outcome_gives_teaches_inspires_and_heals() -> void:
	var who := st.party[1]
	who.heroic_inspiration = false
	var hurt := st.party[2]
	hurt.hp = 1
	var gold := st.gold
	var gained: Array[String] = []
	st.item_gained.connect(func(item_id: String, qty: int, by: String) -> void: gained.append("%s %d %s" % [item_id, qty, by]))
	var res := WorldChecks.apply(st, {"items": [{"id": "potion_of_healing_greater", "qty": 1}], "gold": 25,
		"codex": {"id": "test_lore", "title": "Old Lore", "text": "Words."}, "inspiration": true, "heal": "1d4"}, who, dice, "Test")
	assert_true(who.carries("potion_of_healing_greater"), "the find goes to whoever found it")
	assert_eq(st.gold, gold + 25.0)
	assert_true("test_lore" in st.codex)
	assert_true(who.heroic_inspiration)
	assert_true(hurt.hp > 1, "the hurt are healed")
	assert_eq(gained, ["potion_of_healing_greater 1 %s" % who.name] as Array[String], "the find is announced (ItemNotices)")
	assert_eq((res["gains"] as Array).size(), 3, "gold, lore and inspiration in the toast: %s" % [res["gains"]])
	WorldChecks.apply(st, {"inspiration": true}, who, dice, "Test")
	assert_true(st.party.filter(func(ch: Character) -> bool: return ch.heroic_inspiration).size() >= 2,
		"someone who has it already passes it on")


func test_a_failure_can_hurt_whoever_tried() -> void:
	var who := st.party[0]
	var hp := who.hp
	var res := WorldChecks.apply(st, {"damage": "2d4", "damage_type": "bludgeoning"}, who, dice, "A fall")
	assert_true(who.hp < hp, "the fall hurts")
	assert_eq((res["lines"] as Array).size(), 1)


func test_a_check_waits_for_its_condition() -> void:
	var c := _check("religion", 10, {"when": "flag.test_world_checks_ready"})
	assert_false(WorldChecks.open(st, LOC, c))
	st.set_flag("test_world_checks_ready")
	assert_true(WorldChecks.open(st, LOC, c))


func test_the_down_and_the_dead_do_not_try() -> void:
	var c := _check("perception", 15)
	var best := WorldChecks.roller(st, LOC, c)
	best.hp = 0
	assert_true(WorldChecks.roller(st, LOC, c) != best, "someone standing tries instead")


func test_a_check_that_would_only_find_what_is_found_is_not_offered() -> void:
	var c := _check("athletics", 12, {"success": {"text": "Up the pine.", "reveal": ["pine_satchel"]}})
	assert_true(WorldChecks.open(st, LOC, c))
	(st.loc_state(LOC)["found"] as Dictionary)["pine_satchel"] = true
	assert_false(WorldChecks.open(st, LOC, c), "a Search found it first: nothing to climb for")
	var more := _check("athletics", 12, {"id": "climb_more", "success": {"reveal": ["pine_satchel"], "gold": 5}})
	assert_true(WorldChecks.open(st, LOC, more), "still worth it for what else it gives")
	var door := _check("arcana", 12, {"id": "ward", "success": {"unlock": ["vault"]}})
	assert_true(WorldChecks.open(st, LOC, door))
	(st.loc_state(LOC)["doors"] as Dictionary)["vault"] = "open"
	assert_false(WorldChecks.open(st, LOC, door), "already open")
