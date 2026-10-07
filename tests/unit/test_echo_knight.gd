extends TestCase
## The Echo Knight (Explorer's Guide to Wildemount, fitted to the 2024 Fighter), built through the real level-up path
## and used in a fight: the echo, attacks and Opportunity Attacks from its space, Unleash Incarnation, Echo Avatar,
## Shadow Martyr, Reclaim Potential and Legion of One.


func _knight(e: Encounter, level: int, cell: Vector2i) -> Combatant:
	var ch := TestChars.custom("fighter", "human", level, {"fighter_subclass": ["echo_knight"],
		"weapon_mastery": ["warhammer", "longsword", "greataxe"]})
	ch.name = "Knight"
	ch.add_item("warhammer")
	ch.equip("warhammer", "main_hand")
	ch.refresh()
	return e.add(ch, &"party", cell)


func _ch(c: Combatant) -> Character:
	return c.creature as Character


func _do(e: Encounter, c: Combatant, id: String, targets: Array = [], point: Vector2 = Vector2.INF) -> CombatResult:
	var cat := ActionCatalog.new(e)
	var a := cat.find(c, id)
	if a.is_empty():
		return CombatResult.fail("no action " + id)
	return cat.perform(c, a, targets, point)


func _at(cell: Vector2i) -> Vector2:
	return Vector2(cell.x + 0.5, cell.y + 0.5)


func _echo(e: Encounter, c: Combatant) -> Combatant:
	var mine := e.echo_knight.echoes(c)
	return mine[0] if not mine.is_empty() else null


func test_the_echo_knight_is_offered_and_levels() -> void:
	var ids := Compendium.shared().subclasses_of("fighter").map(func(s: Dictionary) -> String: return str(s["id"]))
	assert_true("echo_knight" in ids, "offered: %s" % str(ids))
	var ch := TestChars.custom("fighter", "human", 18, {"fighter_subclass": ["echo_knight"]})
	for f: String in ["manifest_echo", "unleash_incarnation", "echo_avatar", "shadow_martyr", "reclaim_potential", "legion_of_one"]:
		assert_true(ch.features.any(func(x: Dictionary) -> bool: return str(x["id"]) == f), f)
	assert_eq(ch.resource_max("unleash_incarnation"), maxi(1, ch.ability_mod(&"con")), "Constitution modifier uses")
	assert_eq(ch.resource_max("shadow_martyr"), 1)
	assert_eq(ch.resource_max("reclaim_potential"), maxi(1, ch.ability_mod(&"con")))
	var e := TestCombat.open_field()
	var c := e.add(ch, &"party", Vector2i(2, 2))
	TestCombat.start_with(e, c)
	var hotbar := ActionCatalog.new(e).actions_for(c).map(func(a: Dictionary) -> String: return str(a["id"]))
	for mode: String in ["ask", "auto", "never"]:
		assert_true("feat:reaction_policy:shadow_martyr:%s" % mode in hotbar, "Shadow Martyr: %s in the class tab" % mode)
	assert_true(_do(e, c, "feat:reaction_policy:shadow_martyr:never").ok)
	assert_eq(str(c.reaction_rules["shadow_martyr"]), "never")


func test_manifest_echo_puts_a_ghost_of_the_knight_on_the_board() -> void:
	var e := TestCombat.open_field(2)
	var c := _knight(e, 3, Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	assert_false(_do(e, c, "feat:ek:manifest_echo", [], _at(Vector2i(6, 3))).ok, "20 ft is too far")
	e.drain_events()
	assert_true(_do(e, c, "feat:ek:manifest_echo", [], _at(Vector2i(5, 3))).ok)
	var echo := _echo(e, c)
	assert_true(echo != null, "an echo")
	assert_eq(echo.cell, Vector2i(5, 3))
	assert_false(c.bonus_available, "a Bonus Action")
	assert_eq(echo.creature.ac_value(), 14 + c.creature.proficiency_bonus())
	assert_eq(echo.creature.max_hp(), 1)
	assert_true(echo.creature.is_condition_immune(&"prone") and echo.creature.is_condition_immune(&"frightened"))
	assert_eq(echo.creature.save_bonus(&"con").total(), c.creature.save_bonus(&"con").total(), "the knight's saves")
	assert_false(echo in e.order, "no turns of its own")
	assert_false(echo in e.allies_of(c), "an image, not an ally")
	assert_eq(str((echo.creature as Monster).data["look_of"]), c.id, "drawn as the knight")
	var keys := e.drain_events().filter(func(x: Dictionary) -> bool: return str(x["type"]) == "ability").map(func(x: Dictionary) -> String: return str(x["key"]))
	assert_true("manifest_echo" in keys, "the effect plays: %s" % str(keys))
	# A second Manifest Echo (next turn) replaces the first.
	c.bonus_available = true
	assert_true(_do(e, c, "feat:ek:manifest_echo", [], _at(Vector2i(2, 5))).ok)
	assert_eq(e.echo_knight.echoes(c).size(), 1)
	assert_false(echo.is_alive(), "the first echo faded")


func test_attacks_come_from_the_echo_when_only_it_reaches() -> void:
	var e := TestCombat.open_field(3)
	var c := _knight(e, 3, Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 200)
	TestCombat.start_with(e, c)
	var opt := "weapon:warhammer"
	assert_ne(e.attack_legal(c, foe, e.option_by_id(c, opt)), "", "out of the knight's own reach")
	assert_true(_do(e, c, "feat:ek:manifest_echo", [], _at(Vector2i(5, 3))).ok)
	var cat := ActionCatalog.new(e)
	assert_eq(cat.target_why(c, cat.find(c, "attack:" + opt), foe), "", "the hotbar lets the knight aim at it")
	assert_true(cat.attack_preview(c, cat.find(c, "attack:" + opt), foe)["lines"].any(func(x: Variant) -> bool: return str(x).contains("Echo's space")))
	e.drain_events()
	TestCombat.next_d20(e, 15)
	var r := e.attack(c, foe, opt)
	assert_true(r.ok, r.reason)
	assert_true(foe.creature.hp < 200, "it hit from the echo's space")
	var atk := e.drain_events().filter(func(x: Dictionary) -> bool: return str(x["type"]) == "attack")
	assert_eq(str((atk[0] as Dictionary)["from"]), _echo(e, c).id, "the echo strikes in the view")
	assert_eq(c.cell, Vector2i(2, 3), "the knight never left its square")
	assert_eq(_echo(e, c).cell, Vector2i(5, 3))
	assert_false(c.has_meta("strike_from"))


func test_push_from_the_echo_shoves_away_from_the_echo() -> void:
	var e := TestCombat.open_field(4)
	var c := _knight(e, 3, Vector2i(5, 2))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 200)
	TestCombat.start_with(e, c)
	assert_true("warhammer" in _ch(c).weapon_masteries, "Push mastery: %s" % str(_ch(c).weapon_masteries))
	assert_true(_do(e, c, "feat:ek:manifest_echo", [], _at(Vector2i(7, 3))).ok)
	assert_true(e.features.toggle_rider(c, EchoKnight.RIDER).ok, "Strike from the Echo")
	TestCombat.next_d20(e, 15)
	assert_true(e.attack(c, foe, "weapon:warhammer").ok)
	assert_eq(foe.cell, Vector2i(4, 3), "pushed 10 ft west, away from the echo (from the knight it would go south-east)")


func test_swap_and_move_the_echo() -> void:
	var e := TestCombat.open_field(5)
	var c := _knight(e, 3, Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(11, 7))
	TestCombat.start_with(e, c)
	assert_true(_do(e, c, "feat:ek:manifest_echo", [], _at(Vector2i(4, 3))).ok)
	var echo := _echo(e, c)
	assert_true(_do(e, c, "feat:ek:echo_move:" + echo.id, [], _at(Vector2i(8, 3))).ok, "20 ft, no action")
	assert_eq(echo.cell, Vector2i(8, 3))
	assert_false(_do(e, c, "feat:ek:echo_move:" + echo.id, [], _at(Vector2i(8, 7))).ok, "only 10 ft left this turn")
	assert_true(_do(e, c, "feat:ek:echo_move:" + echo.id, [], _at(Vector2i(8, 5))).ok)
	var before := c.movement_left
	c.bonus_available = true
	assert_true(_do(e, c, "feat:ek:echo_swap:" + echo.id).ok)
	assert_eq(c.cell, Vector2i(8, 5))
	assert_eq(echo.cell, Vector2i(2, 3))
	assert_eq(c.movement_left, before - 15, "15 ft of movement")
	assert_false(c.bonus_available)


func test_the_echo_fades_far_away_or_when_its_knight_is_incapacitated() -> void:
	var e := TestCombat.open_field(6)
	var c := _knight(e, 3, Vector2i(1, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(11, 7))
	TestCombat.start_with(e, c)
	assert_true(_do(e, c, "feat:ek:manifest_echo", [], _at(Vector2i(4, 3))).ok)
	var echo := _echo(e, c)
	assert_true(_do(e, c, "feat:ek:echo_move:" + echo.id, [], _at(Vector2i(10, 3))).ok)
	e.end_turn()
	assert_false(echo.is_alive(), "more than 30 ft away at the end of the turn")
	# Next round: a new echo, then the knight is Stunned.
	while e.current() != c:
		e.end_turn()
	assert_true(_do(e, c, "feat:ek:manifest_echo", [], _at(Vector2i(2, 3))).ok)
	var echo2 := _echo(e, c)
	c.creature.add_effect(Effect.new("Stun", &"spell", "test").with_condition(&"stunned"))
	assert_false(echo2.is_alive(), "Incapacitated: the echo fades")
	var _unused := foe


func test_an_opportunity_attack_from_the_echo() -> void:
	var e := TestCombat.open_field(7)
	var c := _knight(e, 3, Vector2i(1, 1))
	var z := TestCombat.foe(e, "zombie", Vector2i(6, 3))
	TestCombat.start_with(e, c)
	assert_true(_do(e, c, "feat:ek:manifest_echo", [], _at(Vector2i(4, 1))).ok)
	var echo := _echo(e, c)
	assert_true(_do(e, c, "feat:ek:echo_move:" + echo.id, [], _at(Vector2i(5, 3))).ok)
	e.end_turn()
	while e.current() != z:
		e.end_turn()
	var r := e.move(z, Vector2i(9, 3))
	assert_true(r.is_paused(), "the knight is asked")
	assert_eq(r.pending.kind, "opportunity_attack")
	assert_eq(r.pending.reactor_id, c.id)
	assert_true(r.pending.text.contains(echo.name()), r.pending.text)
	e.drain_events()
	TestCombat.next_d20(e, 18)
	e.answer_reaction(true)
	assert_false(c.reaction_available)
	var atk := e.drain_events().filter(func(x: Dictionary) -> bool: return str(x["type"]) == "attack")
	assert_false(atk.is_empty(), "an attack was made")
	assert_eq(str((atk[0] as Dictionary)["from"]), echo.id, "from the echo's space")
	assert_eq(c.cell, Vector2i(1, 1))


func test_unleash_incarnation_once_per_attack_action() -> void:
	var e := TestCombat.open_field(8)
	var c := _knight(e, 3, Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 300)
	TestCombat.start_with(e, c)
	_ch(c).finish_long_rest()
	var uses := _ch(c).resource_left("unleash_incarnation")
	assert_true(_do(e, c, "feat:ek:manifest_echo", [], _at(Vector2i(5, 3))).ok)
	assert_false(_do(e, c, "feat:ek:unleash_incarnation", [foe]).ok, "the Attack action first")
	assert_true(e.features.toggle_rider(c, "skip:push").ok, "keep the foe beside the echo")
	TestCombat.next_d20(e, 15)
	assert_true(e.attack(c, foe, "weapon:warhammer").ok)
	var hp := foe.creature.hp
	e.drain_events()
	TestCombat.next_d20(e, 15)
	var r := _do(e, c, "feat:ek:unleash_incarnation", [foe])
	assert_true(r.ok, r.reason)
	assert_true(foe.creature.hp < hp, "the extra swing landed")
	assert_eq(_ch(c).resource_left("unleash_incarnation"), uses - 1)
	var keys := e.drain_events().filter(func(x: Dictionary) -> bool: return str(x["type"]) == "ability").map(func(x: Dictionary) -> String: return str(x["key"]))
	assert_true("unleash_incarnation" in keys)
	assert_eq(foe.cell, Vector2i(6, 3), "Hold back Push kept the foe beside the echo")
	assert_false(_do(e, c, "feat:ek:unleash_incarnation", [foe]).ok, "once per Attack action")
	# Action Surge: a second Attack action, and a second extra swing.
	assert_true(_do(e, c, "action_surge").ok)
	TestCombat.next_d20(e, 15)
	assert_true(e.attack(c, foe, "weapon:warhammer").ok)
	if _ch(c).resource_left("unleash_incarnation") > 0:
		TestCombat.next_d20(e, 15)
		assert_true(_do(e, c, "feat:ek:unleash_incarnation", [foe]).ok, "again with the second Attack action")


func test_dismiss_the_echo() -> void:
	var e := TestCombat.open_field(15)
	var c := _knight(e, 3, Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	assert_true(_do(e, c, "feat:ek:manifest_echo", [], _at(Vector2i(4, 3))).ok)
	var echo := _echo(e, c)
	assert_false(_do(e, c, "feat:ek:echo_dismiss:" + echo.id).ok, "the Bonus Action is spent")
	c.bonus_available = true
	e.drain_events()
	assert_true(_do(e, c, "feat:ek:echo_dismiss:" + echo.id).ok)
	assert_false(echo.is_alive())
	assert_true(e.drain_events().any(func(x: Dictionary) -> bool: return str(x["type"]) == "vanish"), "it fades in the view")


func test_shadow_martyr_takes_the_hit_and_reclaim_potential_pays_back() -> void:
	var e := TestCombat.open_field(9)
	var c := _knight(e, 15, Vector2i(1, 1))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(5, 4))
	var z := TestCombat.foe(e, "zombie", Vector2i(6, 4))
	TestCombat.start_with(e, c)
	assert_true(_do(e, c, "feat:ek:manifest_echo", [], _at(Vector2i(3, 1))).ok)
	var echo := _echo(e, c)
	e.end_turn()
	while e.current() != z:
		e.end_turn()
	ally.reaction_rules["opportunity_attack"] = "never"
	var hp := ally.creature.hp
	TestCombat.next_d20(e, 19)
	var r := e.monster_attack(z, ally, "slam")
	assert_true(r.is_paused() and r.pending.kind == "shadow_martyr", "the knight is asked")
	if not r.is_paused():
		return
	e.answer_reaction(true)
	assert_eq(ally.creature.hp, hp, "the ally is spared")
	assert_false(echo.is_alive(), "the echo took the slam")
	assert_true(e.grid.distance_ft(echo.cell, 1, ally.cell, 1) <= 5, "it leapt beside the ally")
	assert_eq(_ch(c).resource_left("shadow_martyr"), 0)
	assert_true(c.creature.temp_hp > 0, "Reclaim Potential")
	assert_false(c.reaction_available)


func test_shadow_martyr_again_with_unleash_incarnation() -> void:
	var e := TestCombat.open_field(10)
	var c := _knight(e, 10, Vector2i(1, 1))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(5, 4))
	var z := TestCombat.foe(e, "zombie", Vector2i(6, 4))
	TestCombat.start_with(e, c)
	_ch(c).spend_resource("shadow_martyr")
	var uses := _ch(c).resource_left("unleash_incarnation")
	assert_true(_do(e, c, "feat:ek:manifest_echo", [], _at(Vector2i(3, 1))).ok)
	e.end_turn()
	while e.current() != z:
		e.end_turn()
	TestCombat.next_d20(e, 19)
	var r := e.monster_attack(z, ally, "slam")
	assert_true(r.is_paused() and r.pending.kind == "shadow_martyr")
	if not r.is_paused():
		return
	assert_true(r.pending.cost.contains("Unleash Incarnation"), r.pending.cost)
	e.answer_reaction(true)
	assert_eq(_ch(c).resource_left("unleash_incarnation"), uses - 1)


func test_shadow_martyr_pauses_an_enemy_spell_attack() -> void:
	var e := TestCombat.open_field(11)
	var c := _knight(e, 10, Vector2i(1, 1))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(5, 4))
	var mage := TestCombat.caster_with(e, ["fire_bolt"], Vector2i(9, 4))
	mage.side = &"enemy"
	mage.controller = &"ai"
	TestCombat.start_with(e, c)
	assert_true(_do(e, c, "feat:ek:manifest_echo", [], _at(Vector2i(3, 1))).ok)
	var echo := _echo(e, c)
	e.end_turn()
	while e.current() != mage:
		e.end_turn()
	var hp := ally.creature.hp
	TestCombat.next_d20(e, 19)
	var r := e.spells.cast(mage, "fire_bolt", 0, [ally])
	assert_true(r.is_paused() and r.pending.kind == "shadow_martyr", "the knight is asked before the spell's roll")
	if not r.is_paused():
		return
	e.answer_reaction(true)
	assert_eq(ally.creature.hp, hp, "the Fire Bolt went to the echo")
	assert_false(echo.is_alive(), "and broke it")
	assert_eq(_ch(c).resource_left("shadow_martyr"), 0)


func test_a_roll_that_cant_pause_takes_the_echo_only_on_automatic() -> void:
	var e := TestCombat.open_field(11)
	var c := _knight(e, 10, Vector2i(1, 1))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(5, 4))
	var mage := TestCombat.caster_with(e, ["chromatic_orb"], Vector2i(9, 4))
	mage.side = &"enemy"
	TestCombat.start_with(e, c)
	assert_true(_do(e, c, "feat:ek:manifest_echo", [], _at(Vector2i(3, 1))).ok)
	var echo := _echo(e, c)
	c.reaction_rules["shadow_martyr"] = "ask"
	assert_eq(e.echo_knight.spell_redirect(mage, ally), ally, "Ask can't pause a Chromatic Orb's leap")
	c.reaction_rules["shadow_martyr"] = "auto"
	assert_eq(e.echo_knight.spell_redirect(mage, ally), echo, "Automatic sends the echo")
	assert_true(e.grid.distance_ft(echo.cell, 1, ally.cell, 1) <= 5)


func test_echo_avatar_sees_through_the_echo_and_lets_it_roam() -> void:
	var e := TestCombat.encounter(["............", "............", ".....#......", ".....#......", ".....#......",
		"............", "............", "............"], 12)
	var c := _knight(e, 7, Vector2i(1, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	foe.hidden = false
	assert_true(_do(e, c, "feat:ek:manifest_echo", [], _at(Vector2i(4, 1))).ok)
	var echo := _echo(e, c)
	assert_true(_do(e, c, "feat:ek:echo_move:" + echo.id, [], _at(Vector2i(8, 1))).ok)
	var behind_wall := e.can_see(c, foe)
	assert_true(_do(e, c, "feat:ek:echo_avatar").ok)
	assert_true(c.creature.has_condition(&"blinded") and c.creature.has_condition(&"deafened"))
	assert_false(c.action_available, "a Magic action")
	assert_true(e.can_see(c, foe), "through the echo's eyes (own sight: %s)" % behind_wall)
	e.end_turn()
	assert_true(echo.is_alive(), "it may roam far while the knight looks through it")
	while e.current() != c:
		e.end_turn()
	assert_true(_do(e, c, "feat:ek:echo_avatar_end").ok)
	assert_false(c.creature.has_condition(&"blinded"))


func test_legion_of_one_keeps_two_echoes_and_refills_unleash() -> void:
	var e := TestCombat.open_field(13)
	var c := _knight(e, 18, Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(9, 3), 300)
	var ch := _ch(c)
	while ch.resource_left("unleash_incarnation") > 0:
		ch.spend_resource("unleash_incarnation")
	TestCombat.start_with(e, c)
	assert_eq(ch.resource_left("unleash_incarnation"), 1, "Initiative with none left gives one back")
	assert_true(_do(e, c, "feat:ek:manifest_echo", [], _at(Vector2i(4, 3))).ok)
	c.bonus_available = true
	assert_true(_do(e, c, "feat:ek:manifest_echo", [], _at(Vector2i(4, 5))).ok)
	var two := e.echo_knight.echoes(c)
	assert_eq(two.size(), 2, "two echoes at once")
	assert_eq(int(two[1].get_meta("echo_n")), 2)
	# Either echo can strike: the second one is nearer the foe once moved there.
	assert_true(_do(e, c, "feat:ek:echo_move:" + two[1].id, [], _at(Vector2i(8, 4))).ok)
	TestCombat.next_d20(e, 15)
	assert_true(e.attack(c, foe, "weapon:warhammer").ok, "from the second echo")
	c.bonus_available = true
	assert_true(_do(e, c, "feat:ek:manifest_echo", [], _at(Vector2i(2, 5))).ok)
	assert_eq(e.echo_knight.echoes(c).size(), 1, "a third destroys the other two")


func test_a_fight_with_an_echo_saves_and_loads() -> void:
	var e := TestCombat.open_field(14)
	var c := _knight(e, 3, Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	assert_true(_do(e, c, "feat:ek:manifest_echo", [], _at(Vector2i(4, 3))).ok)
	var snap := EncounterSnapshot.capture(e)
	var e2 := EncounterSnapshot.restore(snap, DiceRoller.new(1))
	var c2 := e2.get_c(c.id)
	var echo2 := e2.echo_knight.echoes(c2)
	assert_eq(echo2.size(), 1, "the echo comes back")
	assert_eq(echo2[0].cell, Vector2i(4, 3))
	assert_false(echo2[0] in e2.order, "still no turns")


func test_every_echo_knight_effect_has_a_look() -> void:
	var feats := (JSON.parse_string(FileAccess.get_file_as_string("res://art/vfx/effects.json")) as Dictionary)["features"] as Dictionary
	for key: String in ["manifest_echo", "echo_move", "echo_swap", "echo_dismiss", "unleash_incarnation", "echo_avatar",
			"echo_avatar_end", "shadow_martyr", "reclaim_potential", "legion_of_one"]:
		assert_true(feats.has(key), "art/vfx/effects.json features.%s" % key)
