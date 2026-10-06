class_name ItemPowers
extends RefCounted
## Bespoke powers of wondrous items and artifacts in a fight (ADR 0012): Cube of Force's barriers, the Iron Flask and
## Mirror of Life Trapping, an Efreeti Bottle, Deck of Illusions, Bag of Tricks, Feather Token whip, Pearl of Power and
## the rest. ItemSpecials hands over the custom powers it doesn't know; outside a fight story/field_items.gd does the rest.

var _specials: WeakRef


func _init(specials: ItemSpecials) -> void:
	_specials = weakref(specials)


func sp() -> ItemSpecials:
	return _specials.get_ref() as ItemSpecials


func items() -> CombatItems:
	return sp().items()


func enc() -> Encounter:
	return sp().enc()


func _pay(c: Combatant, p: Dictionary) -> void:
	items()._pay(c, CombatItems.power_cost(p["power"] as Dictionary, {}))


## Spell numbers for an item's own fixed DC.
static func fixed(dc: int, label: String) -> Dictionary:
	return {"dc": Breakdown.new("Spell save DC").add(label, dc), "attack": Breakdown.new("Spell attack").add(label, dc - 8), "mod": 0, "ability": &"int"}


func why(c: Combatant, p: Dictionary) -> String:
	var power := p["power"] as Dictionary
	var entry := p["entry"] as Dictionary
	match str(power.get("custom", "")):
		"iron_flask_release":
			if (entry.get("trapped", []) as Array).is_empty():
				return "Nothing trapped inside"
		"iron_flask_capture":
			if not (entry.get("trapped", []) as Array).is_empty() and str((p["data"] as Dictionary).get("id", "")) == "iron_flask":
				return "The flask already holds a creature"
		"mirror_trap":
			if (entry.get("trapped", []) as Array).size() >= 12:
				return "All twelve cells are full"
		"pearl_of_power":
			if _spent_slot(CombatItems.ch_of(c), 3) <= 0:
				return "No spent spell slot of level 3 or lower"
		"efreeti_bottle":
			if bool(entry.get("efreeti_gone", false)):
				return "The bottle is empty"
		"eversmoking_close":
			if enc().spells.zones.object_of(c.id, "eversmoking_bottle__smoke") == null:
				return "The bottle isn't open"
	return ""


func use(c: Combatant, p: Dictionary, targets: Array, point: Vector2, opts: Dictionary) -> CombatResult:
	var e := enc()
	var power := p["power"] as Dictionary
	var params := power.get("params", {}) as Dictionary
	var data := p["data"] as Dictionary
	var entry := p["entry"] as Dictionary
	var label := str(data.get("name", ""))
	var t: Combatant = targets[0] as Combatant if not targets.is_empty() and targets[0] is Combatant else null
	match str(power.get("custom", "")):
		"restore_resource":
			_pay(c, p)
			return _restore(c, params, label)
		"pearl_of_power":
			_pay(c, p)
			var ch := CombatItems.ch_of(c)
			var lvl := _spent_slot(ch, 3)
			ch.slots_used[lvl - 1] -= 1
			e.log.add("info", "%s regains a level %d spell slot (%s)" % [c.name(), lvl, label], c.id)
			return CombatResult.new()
		"stilled_tongue":
			c.set_meta("free_wizard_spell", 9)
			e.log.add("info", "%s's next Wizard spell from the tome needs no slot" % c.name(), c.id)
			return CombatResult.new()
		"perfume":
			_pay(c, p)
			var fx := Effect.new(label, &"item", str(p["item_id"]))
			fx.lasting({"kind": "hours", "amount": 1})
			fx.modifiers.append(Modifier.of("advantage", {"on": "check:cha"}, label, &"item"))
			c.creature.add_effect(fx)
			e.log.add("info", "%s smells irresistible" % c.name(), c.id)
			return CombatResult.new()
		"summon_random":
			_pay(c, p)
			var table := params.get("table", []) as Array
			var mid := str(table[e.dice.roll_one(table.size(), label) - 1])
			return sp().summon(c, mid, 1, point, {"hours": 24}, label)
		"cube_of_force":
			_pay(c, p)
			return _cube(c, p, str(opts.get("choice", "5_everything")))
		"scintillating_colors":
			_pay(c, p)
			return _scintillate(c, label)
		"scroll_of_protection":
			_pay(c, p)
			var fp := Effect.new(label, &"item", str(p["item_id"]))
			fp.lasting({"kind": "minutes", "amount": 5})
			fp.turn_owner_id = c.id
			fp.modifiers.append(Modifier.of("flag", {"value": "protection_from:%s" % params.get("type", "")}, label, &"item"))
			c.creature.add_effect(fp)
			e.log.add("spell", "%s reads the scroll: %ss can't reach %s for 5 minutes" % [c.name(), str(params.get("type", "")).capitalize(), c.name()], c.id)
			e.events.append({"type": "condition", "id": c.id})
			return CombatResult.new()
		"talisman_fissure":
			if t == null:
				return CombatResult.fail("Choose a creature")
			_pay(c, p)
			var types := params.get("types", []) as Array
			if not str(t.creature.creature_type) in types:
				e.log.add("info", "Nothing happens: %s isn't the talisman's prey" % t.name(), c.id)
				return CombatResult.new()
			var sv := t.creature.roll_save(e.dice, &"dex", 20, [], [], "Dex save (%s)" % label, ["save_vs:spell"])
			if not sv.success:
				sp()._destroy(t, label, CombatResult.new(), "A fissure opens under %s and swallows it" % t.name())
			else:
				e.log.add("info", "%s leaps clear of the fissure" % t.name(), t.id, [sv.describe()])
			return CombatResult.new()
		"dimensional_shackles":
			if t == null or e.distance(c, t) > 5 or not t.creature.has_condition(&"incapacitated"):
				return CombatResult.fail("Choose an Incapacitated creature within 5 ft")
			_pay(c, p)
			var fs := Effect.new(label, &"item", str(p["item_id"]))
			fs.caster_id = c.id
			fs.conditions.append(&"restrained")
			fs.modifiers.append(Modifier.of("flag", {"value": "no_teleport"}, label, &"item"))
			fs.escape = {"skill": "athletics", "dc": 30}
			t.creature.add_effect(fs)
			e.log.add("condition", "%s is bound in Dimensional Shackles" % t.name(), t.id)
			e.events.append({"type": "condition", "id": t.id})
			return CombatResult.new()
		"iron_bands":
			if t == null:
				return CombatResult.fail("Choose a creature")
			_pay(c, p)
			return _iron_bands(c, t, label)
		"iron_flask_capture", "mirror_trap":
			if t == null:
				return CombatResult.fail("Choose a creature")
			_pay(c, p)
			return _trap(c, p, t, str(power["custom"]) == "mirror_trap")
		"iron_flask_release":
			_pay(c, p)
			var held := entry.get("trapped", []) as Array
			var who := held.pop_back() as Dictionary
			return sp().summon(c, str(who.get("monster", "")), 1, point, {"hours": 1, "name": str(who.get("name", ""))}, label)
		"efreeti_bottle":
			_pay(c, p)
			return _efreeti(c, p, point)
		"eversmoking_close":
			_pay(c, p)
			var o := e.spells.zones.object_of(c.id, "eversmoking_bottle__smoke")
			if o != null:
				o.ended = true
				e.spells.zones.prune()
			e.log.add("info", "%s stoppers the bottle; the smoke thins" % c.name(), c.id)
			return CombatResult.new()
		"deck_of_illusions":
			_pay(c, p)
			return _illusion(c, point)
		"feather_token":
			_pay(c, p)
			return _feather(c, p, t)
		"feather_whip":
			if t == null:
				return CombatResult.fail("Choose a creature")
			_pay(c, p)
			return _whip(c, t)
		"hat_of_wizardry":
			_pay(c, p)
			return _hat(c, p, targets, point, opts)
		"amulet_of_the_planes":
			_pay(c, p)
			return _planes(c, label)
		"sphere_of_annihilation":
			_pay(c, p)
			return _sphere(c, point, label)
	return CombatResult.fail("%s: only outside a fight" % power.get("name", "That power"))


## Restores a class resource (Amulet of the Devout's Channel Divinity, Dragonhide Belt's Focus, Bloodwell Vial's Sorcery
## Points, Rhythm-Maker's Drum's Bardic Inspiration).
func _restore(c: Combatant, params: Dictionary, label: String) -> CombatResult:
	var e := enc()
	var ch := CombatItems.ch_of(c)
	for rid: Variant in params.get("resources", []):
		var res := str(rid)
		if ch.resource_max(res) <= 0:
			continue
		var n := int(params.get("amount", 1))
		if params.has("dice"):
			n = int(e.dice.roll_expr(str(params["dice"]), label)["total"])
		ch.restore_resource(res, n)
		e.log.add("info", "%s regains %d %s (%s)" % [c.name(), n, str(ch.resources[res].get("name", res)), label], c.id)
		return CombatResult.new()
	return CombatResult.fail("Nothing to restore")


static func _spent_slot(ch: Character, top: int) -> int:
	if ch == null:
		return 0
	for l in range(top, 0, -1):
		if ch.slots_used[l - 1] > 0:
			return l
	return 0


## Cube of Force: a barrier of the chosen face for 1 minute (charges by face; face 6 ends it).
func _cube(c: Combatant, p: Dictionary, face: String) -> CombatResult:
	var e := enc()
	var entry := p["entry"] as Dictionary
	for fx: Effect in c.creature.effects.duplicate():
		if fx.stack_key == "cube_of_force":
			c.creature.remove_effect(fx)
	if face.begins_with("6"):
		e.log.add("info", "%s lowers the Cube of Force's barrier" % c.name(), c.id)
		return CombatResult.new()
	var cost := clampi(int(face.left(1)), 1, 5)
	var is_wave := str((p["data"] as Dictionary).get("template_id", "")) == "wave"
	if not is_wave:
		if int(entry.get("charges", 0)) < cost:
			return CombatResult.fail("Not enough charges (needs %d)" % cost)
		entry["charges"] = int(entry["charges"]) - cost
	var flag := {"1": "cube_gas", "2": "cube_objects", "3": "cube_living", "4": "cube_spells", "5": "cube_everything"}[face.left(1)] as String
	var fx2 := Effect.new("Cube of Force", &"item", str(p["item_id"]))
	fx2.stack_key = "cube_of_force"
	fx2.lasting_rounds(10, c.id)
	fx2.modifiers.append(Modifier.of("flag", {"value": flag}, "Cube of Force", &"item"))
	if flag == "cube_everything":
		fx2.modifiers.append(Modifier.of("flag", {"value": "sphered"}, "Cube of Force", &"item"))
	c.creature.add_effect(fx2)
	e.log.add("spell", "%s raises a barrier of force (%s)" % [c.name(), face.substr(2).replace("_", " ")], c.id)
	e.events.append({"type": "condition", "id": c.id})
	return CombatResult.new()


## Robe of Scintillating Colors: dazzling until the end of your next turn (attackers have Disadvantage), and creatures
## within 30 ft that can see you save or are Stunned for as long.
func _scintillate(c: Combatant, label: String) -> CombatResult:
	var e := enc()
	var fx := Effect.new(label, &"item", "robe_of_scintillating_colors")
	fx.ends = Effect.Ends.END_OF_TURN
	fx.turn_owner_id = c.id
	fx.skip_turn_ends = e.own_turn_skip(c)
	fx.modifiers.append(Modifier.of("attacked_with", {"value": "disadvantage", "if_seen": true}, label, &"item"))
	c.creature.add_effect(fx)
	items().attach_light(c, "scintillating", 30, 30)
	var cid := c.id
	fx.on_end = func() -> void: items().detach_light_of(cid, "scintillating")
	for o in e.living():
		if o == c or e.distance(o, c) > 30 or not e.can_see(o, c):
			continue
		var sv := o.creature.roll_save(e.dice, &"wis", 15, [], [], "Wis save (%s)" % label, ["save_vs:spell"])
		if not sv.success:
			var fs := Effect.new(label, &"item", "robe_of_scintillating_colors")
			fs.caster_id = c.id
			fs.conditions.append(&"stunned")
			fs.ends = Effect.Ends.END_OF_TURN
			fs.turn_owner_id = c.id
			fs.skip_turn_ends = e.own_turn_skip(c)
			o.creature.add_effect(fs)
			e.log.add("condition", "%s is Stunned by the shifting colors" % o.name(), o.id, [sv.describe()])
	e.events.append({"type": "condition", "id": c.id})
	return CombatResult.new()


## Iron Bands: a ranged attack (Dex + Proficiency); a hit leaves the target Restrained (DC 20 Strength to break).
func _iron_bands(c: Combatant, t: Combatant, label: String) -> CombatResult:
	var e := enc()
	if e.distance(c, t) > 60:
		return CombatResult.fail("Out of range (60 ft)")
	var atk := Breakdown.new("Iron Bands").add("Dex modifier", c.creature.ability_mod(&"dex")).add("Proficiency", c.creature.proficiency_bonus())
	var test := c.creature.roll_d20(e.dice, D20Test.Kind.ATTACK_ROLL, atk, t.creature.ac_value(), ["attack", "attack:ranged"], [], [],
		"%s → %s (%s)" % [c.name(), t.name(), label])
	if not test.success:
		e.log.add("miss", "The bands miss %s and snap shut again" % t.name(), c.id, [test.describe()])
		return CombatResult.new()
	var fx := Effect.new(label, &"item", "iron_bands_of_bilarro")
	fx.caster_id = c.id
	fx.conditions.append(&"restrained")
	fx.escape = {"skill": "athletics", "dc": 20}
	t.creature.add_effect(fx)
	e.log.add("condition", "%s is bound fast by iron bands" % t.name(), t.id, [test.describe()])
	e.events.append({"type": "condition", "id": t.id})
	return CombatResult.new()


## Iron Flask (one creature not native to this plane) and Mirror of Life Trapping (twelve cells, Constructs immune):
## a save, and the creature is gone from the fight into the item.
func _trap(c: Combatant, p: Dictionary, t: Combatant, mirror: bool) -> CombatResult:
	var e := enc()
	var label := str((p["data"] as Dictionary).get("name", ""))
	if e.distance(c, t) > (30 if mirror else 60):
		return CombatResult.fail("Out of range")
	var native := str(t.creature.creature_type) in ["humanoid", "beast", "plant", "dragon", "giant", "monstrosity", "ooze", "undead", "construct"]
	if (not mirror and native) or (mirror and str(t.creature.creature_type) == "construct"):
		e.log.add("info", "%s doesn't answer the %s's pull" % [t.name(), label], c.id)
		return CombatResult.new()
	if mirror and not e.can_see(t, c):
		return CombatResult.fail("%s can't see its reflection" % t.name())
	var sv := t.creature.roll_save(e.dice, &"cha" if mirror else &"wis", 15 if mirror else 17, [], [], "Save (%s)" % label, ["save_vs:spell"])
	if sv.success:
		e.log.add("info", "%s resists the %s" % [t.name(), label], t.id, [sv.describe()])
		return CombatResult.new()
	var entry := p["entry"] as Dictionary
	if not entry.has("trapped"):
		entry["trapped"] = []
	var mid := str((t.creature as Monster).data.get("id", "")) if t.creature is Monster else ""
	(entry["trapped"] as Array).append({"monster": mid, "name": t.name()})
	t.creature.dead = true
	e.events.append({"type": "vanish", "id": t.id})
	e.log.add("spell", "%s is drawn into the %s" % [t.name(), label], c.id, [sv.describe()])
	e._check_over()
	return CombatResult.new()


## Efreeti Bottle: the first opening decides (d100): 1-10 it attacks for 5 rounds, 11-90 it serves for an hour (three
## times), 91-100 it grants three wishes.
func _efreeti(c: Combatant, p: Dictionary, point: Vector2) -> CombatResult:
	var e := enc()
	var entry := p["entry"] as Dictionary
	var label := str((p["data"] as Dictionary).get("name", ""))
	if not entry.has("efreeti"):
		var roll := e.dice.roll_one(100, label)
		entry["efreeti"] = "hostile" if roll <= 10 else ("serves" if roll <= 90 else "wishes")
		entry["opened"] = 0
	entry["opened"] = int(entry["opened"]) + 1
	match str(entry["efreeti"]):
		"hostile":
			entry["efreeti_gone"] = true
			if items().comp().monster_data("efreeti").is_empty():
				e.log.add("info", "An efreeti bursts out, rages, and vanishes", c.id)
				return CombatResult.new()
			var m := Monster.from_data(items().comp().monster_data("efreeti"), e.dice)
			var cell := e.spells._free_cell_near(c.cell, CombatGrid.size_cells_for(m.size))
			var foe := e.add(m, &"enemy", cell)
			foe.set_meta("vanish_round", e.round_no + 5)
			foe.set_meta("summoner", c.id)
			if e.state == Encounter.State.ACTIVE:
				e.insert_after(c, foe)
			e.events.append({"type": "summon_creature", "id": foe.id, "cell": cell, "caster": c.id})
			e.log.add("spell", "An efreeti bursts from the bottle and attacks %s!" % c.name(), c.id)
			return CombatResult.new()
		"wishes":
			entry["efreeti_gone"] = true
			var fx := Effect.new(label, &"item", str(p["item_id"]))
			fx.lasting({"kind": "hours", "amount": 1})
			fx.data["powers"] = [{"id": "wish", "name": "Ask the efreeti for a wish", "spell": "wish", "cost": "magic", "uses": {"count": 3, "per": "never"}, "ends_effect": true}]
			c.creature.add_effect(fx)
			e.log.add("spell", "An efreeti bows: it will grant %s three wishes" % c.name(), c.id)
			return CombatResult.new()
	if int(entry["opened"]) >= 4:
		entry["efreeti_gone"] = true
		e.log.add("info", "The efreeti escapes for good; the bottle is empty", c.id)
		return CombatResult.new()
	return sp().summon(c, "efreeti", 1, point, {"hours": 1}, label)


## Deck of Illusions: an illusory creature that looks real but can do no harm; anything that strikes it sees through it.
func _illusion(c: Combatant, point: Vector2) -> CombatResult:
	var e := enc()
	var cards := ["Red Dragon", "Knight", "Ogre", "Lich", "Priest", "Guard", "Gnoll", "Owlbear", "Bugbear", "Medusa", "Assassin",
		"Werewolf", "Mage", "Hill Giant", "Ettin", "Vampire", "Beholder", "Succubus"]
	var nm := str(cards[e.dice.roll_one(cards.size(), "Deck of Illusions") - 1])
	var block := {"id": "illusion", "name": "%s (illusion)" % nm, "size": "medium", "type": "humanoid", "ac": 10,
		"hp": {"average": 1, "dice": "1"}, "speed": {"walk": 30}, "abilities": {"str": 10, "dex": 10, "con": 10, "int": 1, "wis": 1, "cha": 1},
		"cr": 0, "actions": [], "traits": [{"id": "illusion", "name": "Illusion", "modifiers": [{"stat": "flag", "value": "illusion"}, {"stat": "flag", "value": "cant_attack"}]}]}
	var m := Monster.from_data(block, null)
	var cell := Vector2i(floori(point.x), floori(point.y)) if point != Vector2.INF else c.cell
	if not e.spells._room_for(cell, 1):
		cell = e.spells._free_cell_near(cell, 1)
	var ic := e.add(m, &"guest" if c.side == &"party" else c.side, cell)
	ic.controller = c.controller
	ic.set_meta("summoner", c.id)
	ic.set_meta("vanishes", true)
	if e.state == Encounter.State.ACTIVE:
		e.insert_after(c, ic)
	e.events.append({"type": "summon_creature", "id": ic.id, "cell": cell, "caster": c.id})
	e.log.add("spell", "%s throws a card: an illusory %s appears" % [c.name(), nm], c.id)
	return CombatResult.new()


## Feather Token: the whip floats out and attacks (+9, 1d6 + 5 Force), then a Bonus Action each turn for an hour.
func _feather(c: Combatant, p: Dictionary, t: Combatant) -> CombatResult:
	var kind := str(((p["power"] as Dictionary).get("params", {}) as Dictionary).get("kind", ""))
	if kind != "whip":
		return CombatResult.fail("Only outside a fight")
	var fx := Effect.new("Feather Token whip", &"item", str(p["item_id"]))
	fx.stack_key = "item_grant:feather_whip"
	fx.lasting({"kind": "hours", "amount": 1})
	fx.data["powers"] = [{"id": "whip", "name": "Whip strike", "cost": "bonus", "custom": "feather_whip", "targeting": "enemy", "range": 30}]
	c.creature.add_effect(fx)
	enc().log.add("spell", "A whip of force flicks out of the feather and hovers beside %s" % c.name(), c.id)
	if t != null:
		return _whip(c, t)
	return CombatResult.new()


func _whip(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	if e.distance(c, t) > 30:
		return CombatResult.fail("The whip can't reach that far")
	var atk := Breakdown.new("Whip of force").add("Feather Token", 9)
	var test := c.creature.roll_d20(e.dice, D20Test.Kind.ATTACK_ROLL, atk, t.creature.ac_value(), ["attack", "attack:melee", "attack:spell"], [], [],
		"Whip of force → %s" % t.name())
	if test.success:
		var rolled := e._roll_damage_dice("1d6+5", test.critical, 0, "Whip of force")
		e.deal_damage(c, t, [{"amount": int(rolled["total"]), "type": "force"}], test.critical, "Whip of force", [test.describe(), str(rolled["text"])])
	else:
		e.log.add("miss", "The whip of force misses %s" % t.name(), c.id, [test.describe()])
	return CombatResult.new()


## Hat of Wizardry: a Wizard cantrip you don't know, if a DC 10 Arcana check succeeds.
func _hat(c: Combatant, p: Dictionary, targets: Array, point: Vector2, opts: Dictionary) -> CombatResult:
	var e := enc()
	var ch := CombatItems.ch_of(c)
	var sid := str(opts.get("choice", ""))
	var spell := items().comp().spell_data(sid)
	if spell.is_empty() or int(spell.get("level", 1)) != 0:
		var pool: Array[Dictionary] = []
		for s in items().comp().spells_for("wizard", 0):
			if not ch.knows_spell(str(s["id"])) and e.spells.has_combat_rules(s):
				pool.append(s)
		if pool.is_empty():
			return CombatResult.fail("No cantrip to try")
		spell = pool[e.dice.roll_one(pool.size(), "Hat of Wizardry") - 1]
	var t := ch.roll_check(e.dice, &"arcana", 10)
	if not t.success:
		e.log.add("info", "%s fumbles the unfamiliar cantrip (Arcana %d)" % [c.name(), t.total], c.id, [t.describe()])
		return CombatResult.new()
	return items().cast(c, spell, 0, targets, point, Vector2.ZERO, items()._wielder_numbers(c), "free", opts, "%s (Hat of Wizardry)" % spell.get("name", ""))


## Amulet of the Planes: in Barovia the Mists hold everyone in; a failed check scatters you and those near you.
func _planes(c: Combatant, label: String) -> CombatResult:
	var e := enc()
	var t := c.creature.roll_check(e.dice, &"arcana", 15, [], [], "Arcana (%s)" % label)
	if t.success:
		e.log.add("info", "The amulet reaches for another plane, but the Mists of Barovia close around it", c.id, [t.describe()])
		return CombatResult.new()
	e.log.add("info", "The amulet's magic goes astray, flinging those near %s across the field" % c.name(), c.id, [t.describe()])
	for o in e.living():
		if e.distance(o, c) <= 15:
			var cell := Vector2i(e.dice.roll_one(e.grid.width, "Scatter") - 1, e.dice.roll_one(e.grid.depth, "Scatter") - 1)
			if e.spells._room_for(cell, o.size_cells):
				var from := o.cell
				o.cell = cell
				e.events.append({"type": "teleport", "id": o.id, "from": from, "to": cell})
	return CombatResult.new()


## Sphere of Annihilation: a DC 25 Arcana check steers it to the point; whoever it passes over makes a DC 13 Dex save or
## takes 4d10 Force. A failed check pulls it 10 ft toward you instead.
func _sphere(c: Combatant, point: Vector2, label: String) -> CombatResult:
	var e := enc()
	var adv: Array[String] = []
	if c.creature.has_flag("talisman_of_the_sphere"):
		adv.append("Talisman of the Sphere")
	var t := c.creature.roll_check(e.dice, &"arcana", 25, adv, [], "Arcana (%s)" % label)
	var victims: Array[Combatant] = []
	if t.success and point != Vector2.INF:
		var cell := Vector2i(floori(point.x), floori(point.y))
		for o in e.living():
			if e.grid.distance_ft(o.cell, o.size_cells, cell, 1) <= 5 and o != c:
				victims.append(o)
		e.log.add("spell", "%s steers the Sphere of Annihilation" % c.name(), c.id, [t.describe()])
	else:
		victims.append(c)
		e.log.add("spell", "The Sphere of Annihilation lurches toward %s" % c.name(), c.id, [t.describe()])
	for v in victims:
		var sv := v.creature.roll_save(e.dice, &"dex", 13, [], [], "Dex save (Sphere of Annihilation)")
		if not sv.success:
			var rolled := e._roll_damage_dice("4d10", false, 0, label)
			e.deal_damage(c, v, [{"amount": int(rolled["total"]), "type": "force"}], false, label, [sv.describe(), str(rolled["text"])])
	return CombatResult.new()


## "After" hooks: Horn of Blasting may explode; a Wind Fan may tear.
func after_power(c: Combatant, p: Dictionary) -> void:
	var e := enc()
	var power := p["power"] as Dictionary
	var ch := CombatItems.ch_of(c)
	var iid := str(p["item_id"])
	match str(power.get("after", "")):
		"horn_explodes":
			if e.dice.roll_one(100, "Horn of Blasting") <= 20:
				var rolled := e._roll_damage_dice("10d6", false, 0, "Horn of Blasting")
				e.deal_damage(null, c, [{"amount": int(rolled["total"]), "type": "fire"}], false, "The Horn of Blasting explodes", [str(rolled["text"])])
				ch.remove_one(iid)
		"wind_fan_tear":
			var entry := p["entry"] as Dictionary
			var n := int(entry.get("fan_uses", 0))
			entry["fan_uses"] = n + 1
			if n > 0 and e.dice.roll_one(100, "Wind Fan") <= 20 * n:
				e.log.add("info", "The Wind Fan tears into useless tatters", c.id)
				ch.remove_one(iid)
