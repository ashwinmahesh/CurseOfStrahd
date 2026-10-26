extends TestCase
## The book's artifacts (Dungeon Expansion Plan I1, docs/story/castle_artifacts.md): the Icon of Ravenloft, Saint
## Markovia's Thighbone and the Gulthias Staff. Their data, what each does in a fight and outside one, where the story
## puts them, and their prices.

const ICON := "icon_of_ravenloft"
const THIGHBONE := "saint_markovias_thighbone"
const STAFF := "gulthias_staff"


func _comp() -> Compendium:
	return Compendium.shared()


func _armed(e: Encounter, item_id: String, cell: Vector2i = Vector2i(2, 2)) -> Combatant:
	var c := TestCombat.hero(e, "ilse_varga", cell, 5)
	var ch := c.creature as Character
	ch.add_item(item_id)
	assert_true(ch.attune(item_id), "attuned to %s" % item_id)
	ch.equip(item_id, "main_hand")
	return c


func _hit(e: Encounter, c: Combatant, target: Combatant, item_id: String, damage: int) -> void:
	var opt := e.option_by_id(c, "weapon:%s" % item_id)
	var dr := DamageResult.new()
	dr.final = damage
	var st := {"t": D20Test.from_natural(D20Test.Kind.ATTACK_ROLL, 12, 5, 10), "option": opt, "critical": false}
	e.items.after_hit(c, target, opt, dr, st, CombatResult.new())


func _has_effect(c: Combatant, source: String) -> bool:
	return c.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == source)


# --- The data ------------------------------------------------------------------------------------------------

func test_the_three_items_are_book_items_checked_twice() -> void:
	var rarities := {ICON: "legendary", "saint_markovias_thighbone": "rare", "gulthias_staff": "rare"}
	for id: String in rarities:
		var d := _comp().item_data(id)
		assert_false(d.is_empty(), "%s is an item" % id)
		assert_eq(str(MagicItems.rarity(d)), str(rarities[id]), "%s's rarity" % id)
		assert_eq(str((d["source"] as Dictionary)["book"]), "CoS")
		var note := str((d["source"] as Dictionary).get("note", ""))
		assert_true(note.contains("dnd5e.wikidot.com") and note.contains("5e.tools"), "%s names both sources it was checked against" % id)
		assert_true(MagicItems.needs_attunement(d), "%s needs attunement" % id)
		assert_false(bool((d.get("treasure", {}) as Dictionary).get("random", true)), "%s stays off the random tables" % id)
		assert_true(FileAccess.file_exists("res://addons/dnd_core/art/icons/items/%s.png" % str(d.get("icon", id))), "%s has its icon" % id)
	assert_eq(str(_comp().item_data(ICON)["magic"]["attunement"]), "by a creature of good alignment")
	assert_eq(float(_comp().item_data(ICON)["weight_lb"]), 10.0, "ten pounds of silver")
	assert_eq(str((_comp().item_data(THIGHBONE)["weapon"] as Dictionary)["damage"]), "1d6", "a mace's damage")
	var staff := _comp().item_data(STAFF)
	assert_eq(int(MagicItems.charges(staff)["max"]), 10)
	assert_eq(str(MagicItems.charges(staff)["when"]), "dusk")


func test_the_three_are_unsellable_story_items_like_the_sunsword() -> void:
	var t: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/treasure/magic_prices.json"))
	var st := StoryState.new()
	for id: String in [ICON, THIGHBONE, STAFF]:
		var d := _comp().item_data(id)
		assert_eq(str((t["excluded"] as Dictionary).get(id, "")), "story", "%s is a story item, off the shelves" % id)
		assert_false((t["items"] as Dictionary).has(id), "%s has no price in the table, as the Sunsword has none" % id)
		assert_eq(float(d["cost_gp"]), 0.0, "%s is worth no coin" % id)
		assert_true(bool(d.get("quest_locked", false)), "%s can't be sold, dropped or stashed" % id)
	# No merchant who buys magic items takes one off the party.
	var buyers := 0
	for npc: Dictionary in _comp().all("npcs"):
		var nid := str(npc["id"])
		if not Trade.buys_magic(st, nid):
			continue
		buyers += 1
		for id: String in [ICON, THIGHBONE, STAFF]:
			assert_eq(st.shop_offer(nid, id), -1.0, "%s doesn't buy %s" % [nid, id])
	assert_true(buyers > 5, "merchants who buy magic items were checked: %d" % buyers)


# --- Saint Markovia's Thighbone ----------------------------------------------------------------------------

func test_the_thighbone_is_a_mace_of_disruption_that_crumbles_after_a_vampire() -> void:
	var e := TestCombat.open_field()
	var c := _armed(e, THIGHBONE)
	var ch := c.creature as Character
	var wolf := TestCombat.foe(e, "wolf", Vector2i(3, 3))
	var zombie := TestCombat.foe(e, "zombie", Vector2i(3, 2))
	var spawn := TestCombat.foe(e, "vampire_spawn", Vector2i(2, 3))
	TestCombat.start_with(e, c)
	var opt := e.option_by_id(c, "weapon:%s" % THIGHBONE)
	var st := {"t": D20Test.from_natural(D20Test.Kind.ATTACK_ROLL, 12, 5, 10), "option": opt, "critical": false}
	assert_eq(e.items.hit_damage_dice(c, wolf, opt, st).size(), 0, "nothing extra against a beast")
	var dice := e.items.hit_damage_dice(c, spawn, opt, st)
	assert_eq(dice.size(), 1, "the Mace of Disruption's extra dice against the undead")
	assert_eq(str(dice[0]["dice"]), "2d6")
	assert_eq(str(dice[0]["type"]), "radiant")
	_hit(e, c, wolf, THIGHBONE, 5)
	_hit(e, c, zombie, THIGHBONE, 5)
	assert_false(bool(ch.entry_of(THIGHBONE).get("crumbles", false)), "a zombie isn't a vampire")
	_hit(e, c, spawn, THIGHBONE, 5)
	assert_true(bool(ch.entry_of(THIGHBONE).get("crumbles", false)), "it has struck a vampire spawn")
	assert_true(ch.carries(THIGHBONE), "but it holds until the battle ends")
	for foe: Combatant in [wolf, zombie]:
		foe.creature.hp = 0
		foe.creature.dead = true
	assert_eq(e.state, Encounter.State.ACTIVE, "the spawn still fights")
	spawn.creature.hp = 0
	spawn.creature.dead = true
	e._check_over()
	assert_eq(e.state, Encounter.State.OVER)
	assert_false(ch.carries(THIGHBONE), "the thighbone crumbles to dust once the battle concludes")


func test_a_killing_blow_on_a_vampire_still_spends_the_thighbone() -> void:
	var e := TestCombat.open_field()
	var c := _armed(e, THIGHBONE)
	var spawn := TestCombat.foe(e, "vampire_spawn", Vector2i(3, 2))
	TestCombat.start_with(e, c)
	spawn.creature.hp = 0
	spawn.creature.dead = true
	_hit(e, c, spawn, THIGHBONE, 30)
	e._check_over()
	assert_false((c.creature as Character).carries(THIGHBONE), "the blow that destroyed it spent the bone")


func test_the_thighbone_keeps_whole_when_no_vampire_was_hit() -> void:
	var e := TestCombat.open_field()
	var c := _armed(e, THIGHBONE)
	var zombie := TestCombat.foe(e, "zombie", Vector2i(3, 2))
	TestCombat.start_with(e, c)
	_hit(e, c, zombie, THIGHBONE, 5)
	zombie.creature.hp = 0
	zombie.creature.dead = true
	e._check_over()
	assert_eq(e.state, Encounter.State.OVER)
	assert_true((c.creature as Character).carries(THIGHBONE), "it only crumbles for a vampire")


# --- The Gulthias Staff --------------------------------------------------------------------------------------

func test_vampiric_strike_heals_by_the_damage_and_the_blood_can_madden() -> void:
	var e := TestCombat.open_field()
	var c := _armed(e, STAFF)
	var ch := c.creature as Character
	var bag := TestCombat.punching_bag(e, Vector2i(3, 2), 100)
	TestCombat.start_with(e, c)
	c.creature.hp = 5
	_hit(e, c, bag, STAFF, 6)
	assert_eq(c.creature.hp, 5, "not armed: no healing")
	assert_eq(ch.charges_left(STAFF), 10, "and no charge spent")
	var r := e.items.use(c, STAFF, "vampiric")
	assert_true(r.ok, r.reason)
	TestCombat.next_d20(e, 20)
	_hit(e, c, bag, STAFF, 6)
	assert_eq(c.creature.hp, 11, "it heals what the blow dealt")
	assert_eq(ch.charges_left(STAFF), 9, "for one charge")
	assert_false(e.items.toggled(c, STAFF, "vampiric"), "one hit only")
	assert_false(_has_effect(c, STAFF), "a steady mind keeps its senses")
	# A second try, and a failed save: short-term madness.
	assert_true(e.items.use(c, STAFF, "vampiric").ok)
	TestCombat.next_d20(e, 1)
	_hit(e, c, bag, STAFF, 4)
	assert_eq(ch.charges_left(STAFF), 8)
	assert_true(c.creature.effects.any(func(fx: Effect) -> bool: return fx.stack_key == "short_term_madness"), "DC 12 Wisdom save failed")
	assert_eq(c.creature.modifiers_for(&"disadvantage").filter(func(m: Modifier) -> bool: return m.source_name == "Short-term madness").size(), 1)


func test_breaking_the_staff_kills_blights_in_earshot_but_not_a_boss_tree() -> void:
	var e := TestCombat.open_field()
	var c := _armed(e, STAFF, Vector2i(1, 1))
	var twig := TestCombat.foe(e, "twig_blight", Vector2i(4, 1))
	var needle := TestCombat.foe(e, "needle_blight", Vector2i(8, 6))
	var vine := TestCombat.foe(e, "vine_blight", Vector2i(10, 2))
	var tree := TestCombat.foe(e, "tree_blight", Vector2i(9, 4))
	var wolf := TestCombat.foe(e, "wolf", Vector2i(6, 3))
	TestCombat.start_with(e, c)
	var r := e.items.use(c, STAFF, "break")
	assert_true(r.ok, r.reason)
	for blight: Combatant in [twig, needle, vine]:
		assert_true(blight.creature.dead, "%s withers and dies" % blight.name())
	assert_false(tree.creature.dead, "a boss blight shrugs the scream off: the climax stands")
	assert_false(wolf.creature.dead, "only blights hear it")
	assert_false((c.creature as Character).carries(STAFF), "the staff is destroyed")
	assert_eq(e.state, Encounter.State.ACTIVE, "the tree and the wolf still fight")


func test_the_staff_cannot_be_broken_with_no_blight_to_hear_it() -> void:
	var e := TestCombat.open_field()
	var c := _armed(e, STAFF)
	TestCombat.foe(e, "wolf", Vector2i(6, 3))
	TestCombat.start_with(e, c)
	var r := e.items.use(c, STAFF, "break")
	assert_false(r.ok, "nothing to wither")
	assert_true((c.creature as Character).carries(STAFF), "so the staff is kept")


func test_blight_bane_calms_lesser_blights_until_the_bearer_harms_one() -> void:
	var e := TestCombat.open_field()
	var c := _armed(e, STAFF)
	var other := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(2, 4), 5)
	var twig := TestCombat.foe(e, "twig_blight", Vector2i(5, 2))
	var tree := TestCombat.foe(e, "tree_blight", Vector2i(9, 4))
	var wolf := TestCombat.foe(e, "wolf", Vector2i(6, 6))
	TestCombat.start_with(e, c)
	assert_ne(e.items.attack_blocked(twig, c, {}), "", "a twig blight leaves the attuned bearer alone")
	assert_eq(e.items.attack_blocked(twig, other, {}), "", "but not the rest of the party")
	assert_eq(e.items.attack_blocked(tree, c, {}), "", "a boss blight isn't calmed")
	assert_eq(e.items.attack_blocked(wolf, c, {}), "", "nor is a wolf")
	assert_ne(e.items.spell_blocked(twig, c), "", "nor do its spells reach the bearer")
	e.items.after_attack(c, twig, {}, false)
	assert_eq(e.items.attack_blocked(twig, c, {}), "", "an attack on a blight ends the peace")


func test_blight_bane_needs_attunement() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	(c.creature as Character).add_item(STAFF)
	var twig := TestCombat.foe(e, "twig_blight", Vector2i(5, 2))
	TestCombat.start_with(e, c)
	assert_eq(e.items.attack_blocked(twig, c, {}), "", "carried but not attuned")


# --- The Icon of Ravenloft -----------------------------------------------------------------------------------

func test_the_icon_guards_everyone_within_30_ft_against_fiends_and_undead() -> void:
	var e := TestCombat.open_field()
	var bearer := TestCombat.hero(e, "ilse_varga", Vector2i(1, 0), 5)
	var near := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(4, 0), 5)
	var far := TestCombat.hero(e, "silvain_aster", Vector2i(11, 7), 5)
	(bearer.creature as Character).add_item(ICON)
	TestCombat.foe(e, "zombie", Vector2i(6, 4))
	TestCombat.start_with(e, bearer)
	e.spells.zones.refresh_auras()
	assert_true(_has_effect(bearer, ICON), "the bearer, attuned or not")
	assert_true(_has_effect(near, ICON), "15 ft away")
	assert_false(_has_effect(far, ICON), "50 ft away")
	var types := {}
	for m in near.creature.modifiers_for(&"attacked_with_by_type"):
		types = m.data
	assert_eq(str(types.get("value", "")), "disadvantage", "attacks by fiends and undead have Disadvantage")
	assert_true((types.get("types", []) as Array).has("undead") and (types.get("types", []) as Array).has("fiend"))
	assert_eq(near.creature.modifiers_for(&"condition_immunity_by_type").size(), 1, "and can't charm or frighten")
	# It follows the creatures: step out of range and it goes, step back and it returns.
	far.cell = Vector2i(2, 1)
	e.spells.zones.refresh_auras()
	assert_true(_has_effect(far, ICON), "in range now")
	near.cell = Vector2i(11, 0)
	e.spells.zones.refresh_auras()
	assert_false(_has_effect(near, ICON), "out of range")


func test_the_icon_adds_two_to_the_save_dc_of_turn_undead_for_its_attuned_bearer() -> void:
	var e := TestCombat.open_field(6)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 3))
	TestCombat.foe(e, "zombie", Vector2i(5, 3))
	TestCombat.start_with(e, h)
	var plain := e.features._turn_dc(h)
	assert_eq(plain, e.features._cleric_dc(h), "no icon: the Cleric's own DC")
	var ch := h.creature as Character
	ch.add_item(ICON)
	assert_eq(e.features._turn_dc(h), plain, "carried but not attuned")
	assert_true(ch.attune(ICON))
	assert_eq(e.features._turn_dc(h), plain + 2, "Bane of the Undead")
	assert_eq(e.features._cleric_dc(h), plain, "Divine Spark and spells stay as they were")
	var r := e.features.turn_undead(h)
	assert_true(r.ok, r.reason)
	assert_true(e.log.entries.any(func(en: Variant) -> bool: return str((en as Dictionary)["text"]).contains("Turn Undead (DC %d)" % (plain + 2))), "and Turn Undead rolls against it")


func _fresh_turn(c: Combatant) -> void:
	c.action_available = true
	c.magic_action_used = false


func test_the_icons_cure_wounds_heals_3d8_plus_3_once_a_day_and_not_the_undead() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 2), 5)
	var ally := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(6, 2), 5)
	var ch := c.creature as Character
	ch.add_item(ICON)
	assert_true(ch.attune(ICON))
	var ghoul := TestCombat.punching_bag(e, Vector2i(2, 6), 80, "undead")
	var fiend := TestCombat.punching_bag(e, Vector2i(3, 6), 80, "fiend")
	TestCombat.start_with(e, c)
	ally.creature.hp = 1
	var r := e.items.use(c, ICON, "cure", [ally])
	assert_true(r.ok, r.reason)
	assert_true(ally.creature.hp >= 1 + 6 and ally.creature.hp <= 1 + 27, "3d8 + 3, from 6 to 27: %d" % ally.creature.hp)
	_fresh_turn(c)
	assert_false(e.items.use(c, ICON, "cure", [ally]).ok, "once until dawn")
	ch.on_dawn(DiceRoller.new(3))
	ghoul.creature.hp = 10
	var r2 := e.items.use(c, ICON, "cure", [ghoul])
	assert_true(r2.ok, "the power is used: %s" % r2.reason)
	assert_eq(ghoul.creature.hp, 10, "an undead gains nothing")
	ch.on_dawn(DiceRoller.new(3))
	_fresh_turn(c)
	fiend.creature.hp = 10
	var r3 := e.items.use(c, ICON, "cure", [fiend])
	assert_true(r3.ok, "the power is used: %s" % r3.reason)
	assert_eq(fiend.creature.hp, 10, "nor a fiend")


func test_the_icons_augury_is_read_outside_a_fight_once_a_day() -> void:
	var st := StoryState.new()
	var ch := TestChars.pregen("hedda_ironvow", 5)
	st.party.append(ch)
	ch.add_item(ICON)
	assert_true(ch.attune(ICON))
	var opts := {}
	for o in FieldItems.options(st.party, ch, ICON, DiceRoller.new(1)):
		opts[str(o["power_id"])] = o
	assert_true(bool(opts["augury"]["legal"]), str(opts["augury"]["reason"]))
	assert_true(bool(opts["cure"]["legal"]), str(opts["cure"]["reason"]))
	var res := FieldItems.use(st, ch, ICON, "augury", ch, DiceRoller.new(2))
	assert_true(bool(res["ok"]), str(res.get("text", "")))
	assert_true(str(res["text"]).contains("Augury"), str(res["text"]))
	assert_eq(str(res.get("effect", "")), "augury", "the world reads the omen")
	assert_false(bool(FieldItems.use(st, ch, ICON, "augury", ch, DiceRoller.new(2))["ok"]), "once until dawn")


# --- Where the story puts them -------------------------------------------------------------------------------

func _item_ids(v: Variant, out: Array) -> void:
	if v is Dictionary:
		var d := v as Dictionary
		if d.get("item", null) is String:
			out.append(str(d["item"]))
		for k: Variant in d:
			if str(k) == "items" and d[k] is Array:
				for it: Variant in d[k]:
					if it is Dictionary:
						out.append(str((it as Dictionary).get("id", "")))
			elif d[k] is Dictionary or d[k] is Array:
				_item_ids(d[k], out)
	elif v is Array:
		for x: Variant in v:
			_item_ids(x, out)


## How many times the story's locations place `item` (a find, a container, a fight's loot).
func _placed(item: String) -> int:
	var n := 0
	for loc: Dictionary in _comp().all("locations"):
		if str(loc["id"]).begins_with("test_"):
			continue
		var ids: Array = []
		_item_ids(loc, ids)
		n += ids.count(item)
	return n


func test_the_icon_lies_in_its_own_container_on_the_chapel_altar() -> void:
	var chapel := _comp().get_entry("locations", "castle_ravenloft_chapel")
	var spot := str(((chapel["treasure_spots"] as Dictionary)["castle_ravenloft_chapel"] as Dictionary)["container"])
	var holder := {}
	for ct: Variant in chapel["containers"]:
		for it: Variant in (ct as Dictionary).get("items", []):
			if str((it as Dictionary)["id"]) == ICON:
				holder = ct as Dictionary
	assert_false(holder.is_empty(), "a chapel container holds the Icon")
	assert_ne(str(holder["id"]), spot, "not the Tarokka spot")
	var altar := Vector2i(9, 2)
	for ct2: Variant in chapel["containers"]:
		if str((ct2 as Dictionary)["id"]) == spot:
			altar = Vector2i(int(((ct2 as Dictionary)["cell"] as Array)[0]), int(((ct2 as Dictionary)["cell"] as Array)[1]))
	var cell := Vector2i(int((holder["cell"] as Array)[0]), int((holder["cell"] as Array)[1]))
	assert_true(absi(cell.x - altar.x) <= 1 and absi(cell.y - altar.y) <= 1, "on the altar's dais, beside the altar")
	var rows := ((chapel["map"] as Dictionary)["rows"] as Array)
	assert_ne(str(rows[cell.y])[cell.x], "=", "on open floor, so no walkable square changed")
	assert_ne(str(rows[cell.y])[cell.x], "#")
	assert_eq(_placed(ICON), 1, "the Icon turns up once")


func test_the_staff_is_a_druids_loot_in_the_winery_once_the_hall_is_won() -> void:
	var winery := _comp().get_entry("locations", "wizard_of_wines_winery")
	var holder := {}
	for ct: Variant in winery["containers"]:
		for it: Variant in (ct as Dictionary).get("items", []):
			if str((it as Dictionary)["id"]) == "gulthias_staff":
				holder = ct as Dictionary
	assert_false(holder.is_empty(), "a winery container holds the staff")
	assert_eq(str(holder["when"]), "flag.winery_hall_cleared", "it lies there once the druids in the fermenting hall have fallen")
	var area_ok := false
	for a: Variant in winery["areas"]:
		var ar := a as Dictionary
		if str(ar["id"]) == "ferment_hall":
			var c0 := ar["cells"][0] as Array
			var c1 := ar["cells"][1] as Array
			var cell := holder["cell"] as Array
			area_ok = int(cell[0]) >= int(c0[0]) and int(cell[0]) <= int(c1[0]) and int(cell[1]) >= int(c0[1]) and int(cell[1]) <= int(c1[1])
	assert_true(area_ok, "in the fermenting hall")
	assert_eq(_placed("gulthias_staff"), 1, "the staff turns up once")


func test_the_thighbone_is_lifted_from_saint_markovias_lid_in_crypt_six() -> void:
	assert_eq(_placed(THIGHBONE), 0, "no container holds it: the saint's bone is lifted from her sarcophagus's lid")
	var lines := FileAccess.get_file_as_string("res://narrative/castle_ravenloft/catacombs_crypts.dialogue").split("\n")
	var gives := 0
	var after_lift := false
	var lifted_first := false
	for line: String in lines:
		var l := line.strip_edges()
		if l == "~ lift":
			after_lift = true
		elif l.begins_with("~ "):
			after_lift = false
		if l == "give %s" % THIGHBONE:
			gives += 1
			lifted_first = after_lift
	assert_eq(gives, 1, "the crypts' dialogue gives it once")
	assert_true(lifted_first, "in the lift scene")
