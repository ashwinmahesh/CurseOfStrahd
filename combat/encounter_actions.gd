class_name EncounterActions
extends RefCounted
## The standard actions in a fight (Encounter, 2024): Dash, Disengage, Dodge, Help, Hide and staying hidden, Search,
## Study, Ready, and the Utilize uses (Healer's Kits, potions and Goodberries), plus actions effects allow: breaking free,
## putting out flames, waking a sleeper, and Haste's extra action.

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


## The triggers a Ready action can wait for (2024: any circumstance the creature can perceive): an enemy it can see
## coming within the attack's reach or the spell's range ("approach"), or one already within it making an attack
## ("attack") or casting a spell ("spell"). The Reaction comes right after the trigger.
const READY_TRIGGERS := {"approach": "comes within %s", "attack": "attacks within %s", "spell": "casts a spell within %s"}


## Ready (2024) with an attack: choose an attack to make with your Reaction when a hostile creature you can see sets
## off `trigger` (READY_TRIGGERS) before the start of your next turn.
func ready_attack(c: Combatant, option_id: String, trigger: String = "approach") -> CombatResult:
	var e := enc()
	var why := e._action_check(c)
	if why != "":
		return CombatResult.fail(why)
	var option := e.option_by_id(c, option_id)
	if option.is_empty():
		return CombatResult.fail("Choose an attack to ready")
	if not READY_TRIGGERS.has(trigger):
		trigger = "approach"
	e.spend_action(c)
	c.readied = {"option": option_id, "trigger": trigger}
	e.log.add("info", "%s readies an attack (%s) for the first enemy that %s" % [c.name(), option["label"], str(READY_TRIGGERS[trigger]) % "reach"], c.id)
	e.faerun.after_ready(c)
	return CombatResult.new()


## Ready (2024) with a spell: cast it now (the slot is spent), hold its energy with Concentration, and release it
## with your Reaction when an enemy within the spell's range sets off `trigger` (READY_TRIGGERS) before the start of
## your next turn. If Concentration breaks first, the spell is lost.
func ready_spell(c: Combatant, spell_id: String, slot: int, trigger: String = "approach") -> CombatResult:
	var e := enc()
	var why := e._action_check(c)
	if why != "":
		return CombatResult.fail(why)
	var entry := {}
	for x in e.spells.castable(c):
		if str(x["id"]) == spell_id:
			entry = x
	if entry.is_empty():
		return CombatResult.fail("Unknown spell")
	var s := Compendium.shared().spell_data(spell_id)
	if str((s.get("casting_time", {}) as Dictionary).get("unit", "")) != "action":
		return CombatResult.fail("Only a spell with a casting time of an action can be readied")
	if not bool(entry["legal"]) and str(entry["reason"]) != "Action already used":
		return CombatResult.fail(str(entry["reason"]))
	var ch := c.creature as Character
	var level := int(s.get("level", 0))
	if level > 0:
		slot = maxi(slot, level)
		if ch.slots_left(slot) <= 0:
			return CombatResult.fail("No level %d slots left" % slot)
	e.spend_action(c)
	c.magic_action_used = true
	e.faerun.after_ready(c)
	if not e.spells.casting_gate(c):
		return CombatResult.new()
	if level > 0:
		ch.expend_slot(slot)
		c.cast_slot_spell_this_turn = true
	var used := ch.use_component(s)   # a costly component the spell uses up goes as it's cast, held or not
	if used != "":
		e.log.add("info", "%s uses up %s (%s)" % [c.name(), used, s["name"]], c.id)
	var conc := c.creature.begin_concentration("readied:" + spell_id, "a readied %s" % s["name"])
	if not READY_TRIGGERS.has(trigger):
		trigger = "approach"
	c.readied = {"spell": spell_id, "slot": slot, "conc": conc, "trigger": trigger}
	e.log.add("spell", "%s readies %s for the first enemy that %s" % [c.name(), s["name"], str(READY_TRIGGERS[trigger]) % ("%d ft" % e.spells.range_ft(s, c))], c.id)
	return CombatResult.new()


## Drinking a potion or eating a Goodberry (2024: a Bonus Action), or giving it to a creature within 5 ft. Potions are
## item powers now (CombatItems); Goodberries and other heal-only consumables keep this path.
func use_item(c: Combatant, item_id: String, target: Combatant) -> CombatResult:
	var e := enc()
	var item := Compendium.shared().item_data(item_id)
	if str(item.get("category", "")) == "potion" and not e.items.find_power(c, item_id, "drink").is_empty():
		return e.items.use(c, item_id, "drink", [target if target != null else c])
	var why := e._bonus_check(c)
	if why != "":
		return CombatResult.fail(why)
	if e.item_count(c, item_id) <= 0:
		return CombatResult.fail("None left")
	if target == null or e.distance(c, target) > 5:
		return CombatResult.fail("Must be within 5 ft")
	c.bonus_available = false
	e.weapons._spend_item(c, item_id)
	for fx: Variant in item.get("effects", []):
		var d := fx as Dictionary
		if str(d.get("effect", "")) != "heal":
			continue
		var p := d.get("params", {}) as Dictionary
		if target.creature.has_flag("cant_regain_hp"):
			e.log.add("info", "%s can't regain Hit Points right now" % target.name(), target.id)
			continue
		var amount := int(p.get("flat", 0))
		var text := ""
		if p.has("dice"):
			var rolled := e.heal_roll(str(p["dice"]), target, str(item.get("name", "")))
			amount += int(rolled["total"])
			text = str(rolled["text"])
		var healed := target.creature.heal(amount, str(item.get("name", "")))
		e.log.add("heal", "%s uses %s: %s regains %d Hit Points" % [c.name(), item.get("name", item_id), target.name(), healed], c.id, [text])
		e.events.append({"type": "heal", "id": target.id, "amount": healed})
	return CombatResult.new()


func has_kit(c: Combatant) -> bool:
	if not c.creature is Character:
		return false
	for e in (c.creature as Character).inventory:
		if str(e["id"]) == "healers_kit" and int(e["qty"]) > 0:
			return true
	return false


func _check_still_hidden(c: Combatant) -> void:
	var e := enc()
	if e.items.alertness_light_on(c) != "":
		reveal(c, "the Rod of Alertness's light shows where they are")
		return
	for foe in e.hostiles_of(c):
		if not foe.can_act():
			continue
		var cov := e.grid.cover_between(foe.cell, foe.size_cells, c.cell, c.size_cells)
		if int(cov["cover"]) < CombatGrid.Cover.THREE_QUARTERS:
			reveal(c, "%s spots %s" % [foe.name(), c.name()])
			return


func reveal(c: Combatant, why: String) -> void:
	var e := enc()
	if not c.hidden:
		return
	c.hidden = false
	c.creature.remove_condition(&"invisible", "Hidden")
	e.log.add("info", "%s is no longer hidden (%s)" % [c.name(), why], c.id)


## Breaking free of a spell that allows it (Web, Entangle): an action and the named ability check against the
## spell's save DC.
func escape_effect(c: Combatant, effect_id: int) -> CombatResult:
	var e := enc()
	var why := e._action_check(c)
	if why != "":
		return CombatResult.fail(why)
	var fx: Effect = null
	for x: Effect in c.creature.effects:
		if x.id == effect_id:
			fx = x
	if fx == null or fx.escape.is_empty():
		return CombatResult.fail("Nothing to break free of")
	e.spend_action(c)
	var skill := StringName(str(fx.escape["skill"]))
	var t := c.creature.roll_check(e.dice, skill, int(fx.escape["dc"]))
	if t.success:
		c.creature.remove_effect(fx)
		e.log.add("info", "%s breaks free of %s" % [c.name(), fx.name], c.id, [t.describe()])
		e.events.append({"type": "condition", "id": c.id})
	else:
		e.log.add("info", "%s struggles against %s" % [c.name(), fx.name], c.id, [t.describe()])
	return CombatResult.new()


## Putting out the flames on yourself (Burning, 2024 rules glossary): an action, and you fall Prone.
func douse(c: Combatant) -> CombatResult:
	var e := enc()
	var why := e._action_check(c)
	if why != "":
		return CombatResult.fail(why)
	var burning: Array[Effect] = []
	for x: Effect in c.creature.effects:
		if bool(x.data.get("douse", false)):
			burning.append(x)
	if burning.is_empty():
		return CombatResult.fail("Not burning")
	e.spend_action(c)
	for fx in burning:
		c.creature.remove_effect(fx)
	c.creature.add_condition(&"prone", "Rolled on the ground")
	e.log.add("info", "%s drops and rolls, putting out the flames" % c.name(), c.id)
	e.events.append({"type": "condition", "id": c.id})
	return CombatResult.new()


## The effect keeping `c` magically asleep or entranced (Sleep, Hypnotic Pattern), or null.
func sleeper(c: Combatant) -> Effect:
	for fx: Effect in c.creature.effects:
		if bool(fx.data.get("wakeable", false)):
			return fx
	return null


## Shaking a creature within 5 ft out of magical sleep or a trance: an action.
func wake(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	var why := e._action_check(c)
	if why != "":
		return CombatResult.fail(why)
	if t == null or e.distance(c, t) > 5:
		return CombatResult.fail("Choose a creature within 5 ft")
	var fx := sleeper(t)
	if fx == null:
		return CombatResult.fail("%s isn't magically asleep" % t.name())
	e.spend_action(c)
	t.creature.remove_effect(fx)
	e.log.add("info", "%s shakes %s awake" % [c.name(), t.name()], c.id)
	e.events.append({"type": "condition", "id": t.id})
	return CombatResult.new()


## Haste's extra action (2024): one weapon attack (only one, whatever Extra Attack says), Dash, Disengage, Hide or
## Utilize.
func haste_action_use(c: Combatant, what: String, target: Combatant, option_id: String) -> CombatResult:
	var e := enc()
	var why := e._turn_check(c)
	if why != "":
		return CombatResult.fail(why)
	if what == "dash" and c.creature.has_flag("cannot_dash"):
		return CombatResult.fail("Cannot Dash while affected")
	if what == "disengage" and not can_disengage(c):
		return CombatResult.fail("Hunter’s Rime prevents Disengage")
	if not c.haste_action or not c.creature.has_flag("hasted"):
		return CombatResult.fail("No Haste action left")
	if not c.can_act():
		return CombatResult.fail("%s can't act" % c.name())
	match what:
		"dash":
			c.haste_action = false
			c.movement_left += c.speed()
			e.log.add("info", "%s Dashes with Haste (+%d ft)" % [c.name(), c.speed()], c.id)
		"disengage":
			c.haste_action = false
			c.disengaged = true
			e.log.add("info", "%s Disengages with Haste" % c.name(), c.id)
		"hide":
			var spot := hide_blocker(c)
			if spot != "":
				return CombatResult.fail(spot)
			c.haste_action = false
			var t := c.creature.roll_check(e.dice, &"stealth", 15)
			if t.success:
				c.hidden = true
				c.stealth_total = t.total
				c.creature.add_condition(&"invisible", "Hidden")
			e.log.add("info", "%s %s (Haste, Stealth %d)" % [c.name(), "hides" if t.success else "fails to hide", t.total], c.id, [t.describe()])
		"attack":
			var option := e.option_by_id(c, option_id)
			if option.is_empty():
				return CombatResult.fail("No such attack")
			var check := e.echo_knight.attack_why(c, target, option, true)
			if check != "":
				return CombatResult.fail(check)
			var sanct := e.spells.sanctuary_blocks(c, target)
			if sanct != "":
				return CombatResult.fail(sanct)
			c.haste_action = false
			e.echo_knight.attack_action_taken(c)
			e.log.add("info", "%s attacks with Haste's extra action" % c.name(), c.id)
			var hecho := e.echo_knight.attack_origin(c, target, option)
			return e.echo_knight.strike(c, hecho, func() -> CombatResult: return e._resolve_attack(c, target, option, {}))
	return CombatResult.new()


func dash(c: Combatant, use_bonus: bool = false) -> CombatResult:
	var e := enc()
	if c.creature.has_flag("cannot_dash"):
		return CombatResult.fail("Cannot Dash while affected")
	var why := e._bonus_check(c) if use_bonus else e._action_check(c)
	if why == "" and use_bonus and not CombatFeatures.has_feature(c, "cunning_action"):
		why = "Needs Cunning Action"
	if why != "":
		return CombatResult.fail(why)
	if use_bonus:
		c.bonus_available = false
	else:
		e.spend_action(c)
	var extra := c.speed() + (10 if e.features.has_feat(c, "charger") else 0)
	c.movement_left += extra
	e.log.add("info", "%s takes the Dash action (+%d ft)" % [c.name(), extra], c.id)
	return CombatResult.new()


func disengage(c: Combatant, use_bonus: bool = false) -> CombatResult:
	var e := enc()
	if not can_disengage(c):
		return CombatResult.fail("Hunter’s Rime prevents Disengage")
	var why := e._bonus_check(c) if use_bonus else e._action_check(c)
	if why == "" and use_bonus and not CombatFeatures.has_feature(c, "cunning_action"):
		why = "Needs Cunning Action"
	if why != "":
		return CombatResult.fail(why)
	if use_bonus:
		c.bonus_available = false
	else:
		e.spend_action(c)
	c.disengaged = true
	e.log.add("info", "%s takes the Disengage action: no Opportunity Attacks this turn" % c.name(), c.id)
	e.faerun.after_disengage(c)
	return CombatResult.new()


## Dodge (2024): until the start of your next turn, attacks against you have Disadvantage if you can see the
## attacker and you have Advantage on Dexterity saves; lost if Incapacitated or Speed 0.
func dodge(c: Combatant) -> CombatResult:
	var e := enc()
	var why := e._action_check(c)
	if why != "":
		return CombatResult.fail(why)
	e.spend_action(c)
	apply_dodge(c)
	return CombatResult.new()


## The Dodge effect is shared by the normal action and resource-paid alternate activations.
func apply_dodge(c: Combatant) -> void:
	var e := enc()
	var fx := Effect.new("Dodging", &"effect", "dodge").with_modifier("attacked_with", {"value": "disadvantage"}).with_modifier("advantage", {"on": "save:dex"})
	fx.ends = Effect.Ends.START_OF_TURN
	fx.turn_owner_id = c.id
	fx.ends_when_incapacitated = true
	c.creature.add_effect(fx)
	e.log.add("info", "%s takes the Dodge action" % c.name(), c.id)


## Help (2024): distract an enemy within 5 ft; the next attack roll by one of your allies against it has
## Advantage, until the start of your next turn.
func help_attack(c: Combatant, enemy: Combatant) -> CombatResult:
	var e := enc()
	var why := e._action_check(c)
	if why != "":
		return CombatResult.fail(why)
	# Distracting Melody (Harper Agent): an enemy up to 30 ft away that can see or hear you.
	var reach := e.faerun.help_reach(c, enemy)
	if enemy == null or not c.hostile_to(enemy) or e.distance(c, enemy) > reach:
		return CombatResult.fail("Choose an enemy within %d ft" % reach)
	e.spend_action(c)
	e.add_mark({"kind": "advantage_against", "target": enemy.id, "helper": c.id, "source": "Help (%s)" % c.name(),
		"expires_owner": c.id, "expires_phase": "start", "consume": true})
	e.log.add("info", "%s distracts %s: the next ally attack against it has Advantage" % [c.name(), enemy.name()], c.id)
	e.faerun.after_help(c, enemy)
	return CombatResult.new()


## Hide (2024): DC 15 Dexterity (Stealth) while Heavily Obscured or behind Three-Quarters/Total Cover and out of
## every enemy's line of sight; success gives the Invisible condition while hidden.
func hide(c: Combatant, use_bonus: bool = false) -> CombatResult:
	var e := enc()
	var why := e._bonus_check(c) if use_bonus else e._action_check(c)
	if why == "" and use_bonus and not CombatFeatures.has_feature(c, "cunning_action"):
		why = "Needs Cunning Action"
	if why != "":
		return CombatResult.fail(why)
	var spotter := hide_blocker(c)
	if spotter != "":
		return CombatResult.fail(spotter)
	if use_bonus:
		c.bonus_available = false
	else:
		e.spend_action(c)
	var t := c.creature.roll_check(e.dice, &"stealth", 15)
	if t.success:
		c.hidden = true
		c.stealth_total = t.total
		c.creature.add_condition(&"invisible", "Hidden")
		e.log.add("info", "%s hides (Stealth %d)" % [c.name(), t.total], c.id, [t.describe()])
	else:
		e.log.add("info", "%s fails to hide (Stealth %d vs DC 15)" % [c.name(), t.total], c.id, [t.describe()])
	return CombatResult.new()


## Why `c` can't hide here ("" if it can): every enemy that can act must have no clear view of it (Three-Quarters
## or Total Cover). Naturally Stealthy (halfling): a creature at least one size larger is enough cover. Nobody hides in
## the light of a foe's Rod of Alertness.
func hide_blocker(c: Combatant) -> String:
	var e := enc()
	var lit := e.items.alertness_light_on(c)
	if lit != "":
		return "%s's Rod of Alertness lights you up: its light shows where you are" % lit
	var larger := {}
	if c.creature.has_flag("naturally_stealthy"):
		for o in e.living():
			if o != c and not o.is_down() and Creature.SIZES.find(o.creature.size) > Creature.SIZES.find(c.creature.size):
				for cell in o.footprint():
					larger[cell] = o.name()
	for foe in e.hostiles_of(c):
		if not foe.can_act():
			continue
		var cov := e.grid.cover_between(foe.cell, foe.size_cells, c.cell, c.size_cells)
		if int(cov["cover"]) >= CombatGrid.Cover.THREE_QUARTERS:
			continue
		if not larger.is_empty():
			var by_larger := e.grid.cover_between(foe.cell, foe.size_cells, c.cell, c.size_cells, larger)
			if int(by_larger["cover"]) >= CombatGrid.Cover.HALF and str(by_larger["by"]) not in ["", "walls"]:
				continue
		return "%s can see you: you need Three-Quarters or Total Cover from every enemy" % foe.name()
	return ""


## Search (2024): a Wisdom (Perception) check to find hidden creatures (DC = their Stealth total).
func search(c: Combatant) -> CombatResult:
	var e := enc()
	var why := e._action_check(c)
	if why != "":
		return CombatResult.fail(why)
	e.spend_action(c)
	var t := c.creature.roll_check(e.dice, &"perception", 0, [], [], "", ["search"])
	var found: Array[String] = []
	# Disadvantage to find some of them (a second roll, the lower kept, for those): a Cloak of Elvenkind's wearer, or one
	# in a Lightly Obscured spot (dim light the searcher's Darkvision doesn't reach, fog or a storm over the field).
	var t_hard: D20Test = null
	for h0 in e.hostiles_of(c):
		var hard := _hard_to_spot(c, h0)
		if h0.hidden and hard != "" and t_hard == null:
			t_hard = c.creature.roll_check(e.dice, &"perception", 0, [], [hard])
	for h in e.hostiles_of(c):
		var total := t.total if not (_hard_to_spot(c, h) != "" and t_hard != null) else mini(t.total, t_hard.total)
		if h.hidden and total >= h.stealth_total:
			reveal(h, "%s finds them" % c.name())
			found.append(h.name())
	var rolls: Array[String] = [t.describe()]
	if t_hard != null:
		rolls.append(t_hard.describe())
	e.log.add("info", "%s searches (Perception %d)%s" % [c.name(), t.total, ": finds " + ", ".join(found) if not found.is_empty() else ""], c.id, rolls)
	return CombatResult.new()


## Why `searcher` has Disadvantage on Perception to spot `h` by sight, or "": a Cloak of Elvenkind, or `h` in a Lightly
## Obscured spot (2024: dim light, unless the searcher's Darkvision reaches it, or weather that obscures the open field).
func _hard_to_spot(searcher: Combatant, h: Combatant) -> String:
	var e := enc()
	if h.creature.has_flag("hard_to_perceive"):
		return "Cloak of Elvenkind"
	var weather := e.weather_obscures()
	if weather != "":
		return weather
	if e.light_at(h.cell) == "dim" and searcher.creature.darkvision() < e.distance(searcher, h):
		return "Dim light"
	return ""


## Study (2024): an Intelligence check to recall what a creature is (Arcana, History, Nature or Religion by its
## type). DC 10 + its CR (the DM's call made concrete; deviations.md). Success reveals its defenses and traits.
func study(c: Combatant, target: Combatant) -> CombatResult:
	var e := enc()
	var why := e._action_check(c)
	if why != "":
		return CombatResult.fail(why)
	if target == null or not target.creature is Monster:
		return CombatResult.fail("Choose a creature to study")
	e.spend_action(c)
	var m := target.creature as Monster
	var skill := _knowledge_skill(str(m.data.get("type", "")))
	var dc := 10 + floori(m.cr)
	var t := c.creature.roll_check(e.dice, skill, dc, [], [], "", ["study"])
	if t.success:
		e.studied[str(m.data.get("id", ""))] = true
		var info: Array[String] = []
		for k: String in ["resistances", "vulnerabilities", "immunities", "condition_immunities"]:
			var v := m.data.get(k, []) as Array
			if not v.is_empty():
				info.append("%s: %s" % [k.replace("_", " ").capitalize(), ", ".join(v)])
		for tr: Variant in m.data.get("traits", []):
			info.append("%s: %s" % [(tr as Dictionary).get("name", ""), (tr as Dictionary).get("summary", "")])
		e.log.add("info", "%s recalls what a %s is (%s %d)" % [c.name(), m.name, str(skill).capitalize(), t.total], c.id, [t.describe()] + info)
	else:
		e.log.add("info", "%s can't place the %s (%s %d vs DC %d)" % [c.name(), m.name, str(skill).capitalize(), t.total, dc], c.id, [t.describe()])
	return CombatResult.new()


static func _knowledge_skill(creature_type: String) -> StringName:
	match creature_type:
		"beast", "dragon", "ooze", "plant":
			return &"nature"
		"celestial", "fiend", "undead":
			return &"religion"
		"giant", "humanoid":
			return &"history"
	return &"arcana"


func can_disengage(c: Combatant) -> bool:
	var e := enc()
	for hunter in e.combatants:
		if not CombatFeatures.has_feature(hunter, "hunters_rime"):
			continue
		for fx in hunter.creature.effects:
			if fx.source_id == "hunters_mark":
				for m in fx.modifiers:
					if m.text("vs") == c.id:
						return false
	return true
