extends TestCase
## Divine Smite is asked after every melee hit (owner, 2026-10-18: "after casting Shining Smite, the next attack
## auto-smites"). A smite spell armed for the hit (Shining Smite) goes off on its own; the paladin's choice to also
## spend Divine Smite on that hit is theirs, taken on that hit, and never left waiting to fire on a later hit unasked.


func _field() -> Encounter:
	return TestCombat.open_field(4)


func _melee(e: Encounter, c: Combatant) -> String:
	for o in e.attack_options(c):
		if bool(o["melee"]):
			return str(o["id"])
	return ""


## A level 5 paladin (Extra Attack, the free use of Divine Smite, level 1 and 2 slots) who also has Shining Smite
## prepared, beside a 300 Hit Point dummy; its turn begun.
func _paladin(e: Encounter) -> Array[Combatant]:
	var ch := TestChars.custom("paladin", "human", 5)
	ch.heroic_inspiration = false
	((ch.spellcasting[0] as Dictionary)["prepared"] as Array).append("shining_smite")
	var p := e.add(ch, &"party", Vector2i(2, 3))
	p.reaction_rules["heroic_inspiration"] = "never"
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	TestCombat.start_with(e, p)
	return [p, t]


## One melee swing that lands (a natural 19).
func _swing(e: Encounter, p: Combatant, t: Combatant) -> CombatResult:
	TestCombat.next_d20(e, 19)
	return e.attack(p, t, _melee(e, p))


## Declines what is still asked, so the test leaves no open prompt behind (one would leak and fail the log check).
func _decline(e: Encounter) -> void:
	while e.pending != null:
		e.answer_reaction(false)


## Everything the log has said, with each entry's details, as one text.
func _said(e: Encounter) -> String:
	var out: Array[String] = []
	for x: Dictionary in e.log.entries:
		out.append(str(x["text"]))
		for d: Variant in x.get("details", []):
			out.append(str(d))
	return "\n".join(out)


func test_shining_smite_alone_goes_off_without_a_question() -> void:
	var e := _field()
	var pt := _paladin(e)
	var p := pt[0]
	var ch := p.creature as Character
	p.reaction_rules["divine_smite"] = "never"
	var slots := ch.slots_left(2)
	assert_true(e.features.toggle_rider(p, "smite:shining_smite").ok)
	var r := _swing(e, p, pt[1])
	assert_true(r.hit)
	assert_false(r.is_paused(), "its own damage is automatic")
	assert_eq(ch.slots_left(2), slots - 1, "a level 2 slot")
	assert_false(p.bonus_available, "a Bonus Action")
	assert_true(_said(e).contains("Shining Smite 2d6"), "its 2d6 Radiant is on the hit")
	assert_false("smite:shining_smite" in p.armed, "spent on the hit")


func test_divine_smite_chosen_beside_shining_smite_goes_off_on_that_hit() -> void:
	var e := _field()
	var pt := _paladin(e)
	var p := pt[0]
	var ch := p.creature as Character
	var free := ch.resource_left("spell:divine_smite")
	var slots2 := ch.slots_left(2)
	assert_true(e.features.toggle_rider(p, "smite:shining_smite").ok)
	var r := _swing(e, p, pt[1])
	assert_true(r.is_paused(), "Divine Smite is asked, Shining Smite armed or not")
	assert_eq(e.pending.kind, "divine_smite")
	e.answer_reaction(true)
	assert_eq(ch.resource_left("spell:divine_smite"), free - 1, "Divine Smite was spent on this hit")
	assert_eq(ch.slots_left(2), slots2 - 1, "and Shining Smite's slot")
	var said := _said(e)
	assert_true(said.contains("Shining Smite 2d6"), "both smites on the hit: " + said)
	assert_true(said.contains("Divine Smite 2d8"), "both smites on the hit: " + said)
	assert_false("smite:divine_smite" in p.armed, "none left waiting for the next hit")
	assert_false("smite:shining_smite" in p.armed)


func test_the_next_hit_after_shining_smite_asks_again() -> void:
	var e := _field()
	var pt := _paladin(e)
	var p := pt[0]
	var ch := p.creature as Character
	assert_true(e.features.toggle_rider(p, "smite:shining_smite").ok)
	assert_true(_swing(e, p, pt[1]).is_paused())
	e.answer_reaction(true)
	var left := ch.slots_left(1)
	var free := ch.resource_left("spell:divine_smite")
	var again := _swing(e, p, pt[1])
	assert_true(again.is_paused(), "the second hit asks, it doesn't smite by itself")
	assert_eq(e.pending.kind, "divine_smite")
	assert_eq(ch.slots_left(1), left, "nothing spent before the answer")
	assert_eq(ch.resource_left("spell:divine_smite"), free)
	e.answer_reaction(false)
	assert_eq(ch.slots_left(1), left, "declined: no slot spent")


func test_declining_divine_smite_still_lets_shining_smite_go_off() -> void:
	var e := _field()
	var pt := _paladin(e)
	var p := pt[0]
	var ch := p.creature as Character
	var free := ch.resource_left("spell:divine_smite")
	var slots2 := ch.slots_left(2)
	assert_true(e.features.toggle_rider(p, "smite:shining_smite").ok)
	assert_true(_swing(e, p, pt[1]).is_paused())
	e.answer_reaction(false)
	assert_eq(ch.resource_left("spell:divine_smite"), free, "Divine Smite declined")
	assert_eq(ch.slots_left(2), slots2 - 1, "Shining Smite still cast")
	var said := _said(e)
	assert_true(said.contains("Shining Smite 2d6"), said)
	assert_false(said.contains("Divine Smite 2d8"), said)
	assert_true(_swing(e, p, pt[1]).is_paused(), "and the next hit asks")
	_decline(e)


func test_a_smite_spell_that_cannot_go_off_does_not_swallow_the_divine_smite_chosen() -> void:
	var e := _field()
	var pt := _paladin(e)
	var p := pt[0]
	var ch := p.creature as Character
	var free := ch.resource_left("spell:divine_smite")
	assert_true(e.features.toggle_rider(p, "smite:shining_smite").ok)
	p.bonus_available = false   # the Bonus Action went on something else after arming it
	assert_true(_swing(e, p, pt[1]).is_paused())
	e.answer_reaction(true)
	assert_eq(ch.resource_left("spell:divine_smite"), free - 1, "Divine Smite spent on the hit it was chosen for")
	assert_false("smite:divine_smite" in p.armed, "not kept for a later hit")
	assert_true(_swing(e, p, pt[1]).is_paused(), "the next hit asks")
	_decline(e)


func test_divine_smite_armed_for_the_turn_still_goes_with_shining_smite_then_alone() -> void:
	var e := _field()
	var pt := _paladin(e)
	var p := pt[0]
	var ch := p.creature as Character
	var free := ch.resource_left("spell:divine_smite")
	var slots1 := ch.slots_left(1)
	var slots2 := ch.slots_left(2)
	assert_true(e.features.toggle_rider(p, "smite:shining_smite").ok)
	assert_true(e.features.toggle_rider(p, "smite:divine_smite").ok)
	assert_false(_swing(e, p, pt[1]).is_paused(), "armed for the turn: no question")
	assert_eq(ch.resource_left("spell:divine_smite"), free - 1, "the free use first")
	assert_eq(ch.slots_left(2), slots2 - 1, "Shining Smite's slot")
	assert_false("smite:shining_smite" in p.armed)
	assert_true("smite:divine_smite" in p.armed, "still armed for the turn")
	assert_false(_swing(e, p, pt[1]).is_paused())
	assert_eq(ch.slots_left(1), slots1 - 1, "the second hit smites with a slot")
