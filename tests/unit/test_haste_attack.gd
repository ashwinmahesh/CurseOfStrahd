extends TestCase
## Haste (2024 PHB): a hasted creature gets one additional action on each of its turns, for one attack (whatever Extra
## Attack says), Dash, Disengage, Hide or Utilize. Once the Attack action and its attacks are used, the weapon slots
## and a click on a foe make that attack themselves: nobody has to find the separate "Haste:" slots.


## A hasted fighter beside a punching bag, on its turn: {e, f, bag, cat}.
func _hasted() -> Dictionary:
	var e := TestCombat.open_field(4)
	var wizard := TestCombat.caster_with(e, ["haste"], Vector2i(1, 1))
	var f := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(4, 3), 900)
	TestCombat.start_with(e, wizard)
	assert_true(e.spells.cast(wizard, "haste", 3, [f]).ok)
	while e.current() != f:
		e.end_turn()
	return {"e": e, "f": f, "bag": bag, "cat": ActionCatalog.new(e)}


## The first usable weapon attack on the hotbar.
func _weapon(cat: ActionCatalog, c: Combatant) -> Dictionary:
	for a in cat.actions_for(c):
		if str(a["kind"]) == "attack":
			return a
	return {}


## Makes every attack of the Attack action.
func _spend_attack_action(e: Encounter, f: Combatant, bag: Combatant, option_id: String) -> void:
	var n := e.attacks_per_action(f)
	for i in n:
		var r := e.attack(f, bag, option_id)
		assert_true(r.ok, "attack %d of %d: %s" % [i + 1, n, r.reason])


func test_the_attack_action_comes_first_and_haste_waits() -> void:
	var h := _hasted()
	var f := h["f"] as Combatant
	assert_true(f.haste_action, "Haste's action is there at the start of the turn")
	assert_false(f.haste_attack_ready(), "but the Attack action is still unused")
	var a := _weapon(h["cat"] as ActionCatalog, f)
	assert_eq(str(a["cost"]), "action", "the first attack costs the Action")
	assert_true(bool(a["legal"]))


func test_the_weapon_slot_makes_the_extra_attack_once_the_action_is_spent() -> void:
	var h := _hasted()
	var e := h["e"] as Encounter
	var f := h["f"] as Combatant
	var bag := h["bag"] as Combatant
	var cat := h["cat"] as ActionCatalog
	var option_id := str(_weapon(cat, f)["option_id"])
	_spend_attack_action(e, f, bag, option_id)
	assert_true(f.haste_attack_ready(), "the Attack action is used up")
	var a := _weapon(cat, f)
	assert_true(bool(a["legal"]), "the weapon slot is still usable: %s" % a["reason"])
	assert_eq(str(a["cost"]), "free", "it spends no Action")
	assert_true(str(a["sub"]).contains("Haste"), "the slot says whose action it is: %s" % a["sub"])
	assert_eq(cat.attack_blocker(f, bag), "", "so a click on the foe attacks")
	var hp := bag.creature.hp
	var r := cat.perform(f, a, [bag])
	assert_true(r.ok, r.reason)
	assert_false(f.haste_action, "Haste's action is spent")
	assert_true(bag.creature.hp <= hp, "the blow was struck")
	assert_eq(f.attacks_left, 0, "one attack only, whatever Extra Attack says")
	var after := _weapon(cat, f)
	assert_false(bool(after["legal"]), "and then no more")
	assert_eq(str(after["reason"]), "Action already used")
	assert_false(e.attack(f, bag, option_id).ok)


func test_the_extra_attack_is_logged_as_hastes() -> void:
	var h := _hasted()
	var e := h["e"] as Encounter
	var f := h["f"] as Combatant
	var bag := h["bag"] as Combatant
	var option_id := str(_weapon(h["cat"] as ActionCatalog, f)["option_id"])
	_spend_attack_action(e, f, bag, option_id)
	var before := e.log.entries.size()
	assert_true(e.attack(f, bag, option_id).ok)
	var said := false
	for i in range(before, e.log.entries.size()):
		said = said or str(e.log.entries[i]["text"]).contains("Haste")
	assert_true(said, "the log says it was Haste's action")


func test_a_spent_haste_action_gives_no_extra_attack() -> void:
	var h := _hasted()
	var e := h["e"] as Encounter
	var f := h["f"] as Combatant
	var bag := h["bag"] as Combatant
	var option_id := str(_weapon(h["cat"] as ActionCatalog, f)["option_id"])
	assert_true(e.haste_action_use(f, "dash", null, "").ok, "Haste's action went on a Dash")
	_spend_attack_action(e, f, bag, option_id)
	var a := _weapon(h["cat"] as ActionCatalog, f)
	assert_false(bool(a["legal"]), "nothing left to make an attack with")
	assert_false(e.attack(f, bag, option_id).ok)


func test_without_haste_a_spent_action_ends_the_attacks() -> void:
	var e := TestCombat.open_field(4)
	var f := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(4, 3), 900)
	TestCombat.start_with(e, f)
	var cat := ActionCatalog.new(e)
	var option_id := str(_weapon(cat, f)["option_id"])
	_spend_attack_action(e, f, bag, option_id)
	assert_false(f.haste_attack_ready())
	assert_false(bool(_weapon(cat, f)["legal"]))
	assert_false(e.attack(f, bag, option_id).ok)


func test_the_action_spent_on_something_else_still_leaves_hastes_attack() -> void:
	var h := _hasted()
	var e := h["e"] as Encounter
	var f := h["f"] as Combatant
	var bag := h["bag"] as Combatant
	var cat := h["cat"] as ActionCatalog
	assert_true(e.dodge(f).ok, "the Action goes on Dodge")
	var a := _weapon(cat, f)
	assert_true(bool(a["legal"]), str(a["reason"]))
	assert_true(cat.perform(f, a, [bag]).ok)
	assert_false(f.haste_action)


func test_grapple_and_shove_do_not_ride_on_hastes_action() -> void:
	var h := _hasted()
	var e := h["e"] as Encounter
	var f := h["f"] as Combatant
	var bag := h["bag"] as Combatant
	var cat := h["cat"] as ActionCatalog
	_spend_attack_action(e, f, bag, str(_weapon(cat, f)["option_id"]))
	var g := cat.find(f, "grapple")
	assert_false(bool(g["legal"]), "Haste's Attack is a weapon attack: the Unarmed Strike options stay greyed")
