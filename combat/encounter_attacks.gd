class_name EncounterAttacks
extends RefCounted
## Attacks in a fight (Encounter): the Attack action and the Light weapon's extra attack, every Advantage and
## Disadvantage source with cover and marks, the roll and its stages that pause for reactions, hits and misses with their
## riders and mastery properties, monster attacks and Multiattack, Opportunity Attacks and readied attacks, Mirror
## Image, and retaliation damage (Armor of Agathys, Fire Shield).

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


## Mirror Image: when an attack hits a creature with duplicates (and the attacker relies on sight), roll a d6 per
## duplicate; any 3 or higher means a duplicate is hit instead and destroyed. True if a duplicate took the hit.
func mirror_image_takes(t: Combatant, attacker: Combatant, _total: int) -> bool:
	var e := enc()
	if not t.creature.has_flag("mirror_image"):
		return false
	if attacker.creature.has_flag("cant_see") or attacker.creature.sense_range("blindsight") >= e.distance(attacker, t) \
			or attacker.creature.sense_range("truesight") >= e.distance(attacker, t):
		return false
	for fx: Effect in t.creature.effects:
		if fx.source_id != "mirror_image":
			continue
		var n := int(fx.data.get("duplicates", 0))
		if n <= 0:
			return false
		var rolls := e.dice.roll(6, n, "Mirror Image")
		var redirected := false
		for v in rolls:
			if v >= 3:
				redirected = true
		if redirected:
			fx.data["duplicates"] = n - 1
			e.log.add("miss", "The attack strikes one of %s's duplicates (%d left)" % [t.name(), n - 1], t.id, ["Mirror Image d6: %s" % str(rolls)])
			if n - 1 <= 0:
				t.creature.remove_effect(fx)
		return redirected
	return false


func _readied_attack(p: Combatant, target: Combatant) -> CombatResult:
	var e := enc()
	if p.readied.has("spell"):
		var held := p.readied.duplicate()
		p.readied = {}
		return e.spells.release_readied(p, held, target)
	var option := e.option_by_id(p, str(p.readied.get("option", "")))
	p.readied = {}
	if option.is_empty() or e.attack_legal(p, target, option) != "":
		return CombatResult.new()
	p.reaction_available = false
	e.log.add("reaction", "%s's readied attack goes off against %s" % [p.name(), target.name()], p.id)
	return _resolve_attack(p, target, option, {"reaction": true})


func _opportunity_attack(p: Combatant, target: Combatant) -> CombatResult:
	var e := enc()
	var option := e.best_melee_option(p, target)
	# War Caster's Reactive Spell: a one-action spell at the creature instead (when it has no melee attack, or the
	# player's rule for it is "auto").
	if e.features.has_feat(p, "war_caster") and (option.is_empty() or str(p.reaction_rules.get("reactive_spell", "never")) == "auto"):
		for sp in e.spells.castable(p):
			var data := Compendium.shared().spell_data(str(sp["id"]))
			if int(sp["level"]) == 0 and str(sp["casting"]) == "action" and (data.has("attack") or data.has("save")) and not data.has("area") \
					and e.spells.range_ft(data, p) >= e.distance(p, target):
				p.reaction_available = false
				e.log.add("reaction", "%s answers with %s (War Caster)" % [p.name(), data["name"]], p.id)
				return e.spells.cast_free(p, str(sp["id"]), [target], Vector2.INF, {})
	if option.is_empty():
		return CombatResult.new()
	var echo := e.echo_knight.oa_origin(p, target)
	p.reaction_available = false
	e.log.add("reaction", "%s makes an Opportunity Attack against %s%s" % [p.name(), target.name(), " from its echo's space" if echo != null else ""], p.id)
	var oa := option.duplicate()
	oa["opportunity"] = true
	return e.echo_knight.strike(p, echo, func() -> CombatResult: return _resolve_attack(p, target, oa, {"reaction": true, "opportunity": true}))


## Makes one attack as part of the Attack action (starting it if needed). Characters use weapon options; monsters
## use their stat-block attacks (monster_action handles Multiattack).
func attack(c: Combatant, target: Combatant, option_id: String, opts: Dictionary = {}) -> CombatResult:
	var e := enc()
	var why := e._turn_check(c)
	if why != "":
		return CombatResult.fail(why)
	if not c.can_act():
		return CombatResult.fail("%s can't act" % c.name())
	var option := e.option_by_id(c, option_id)
	if option.is_empty():
		return CombatResult.fail("No such attack")
	# An Echo Knight's attack can come from its echo's space.
	var check := e.echo_knight.attack_why(c, target, option, true)
	if check != "":
		return CombatResult.fail(check)
	if c.attacks_left <= 0 and not c.action_available:
		return CombatResult.fail("No attacks left this turn")
	if e.rider_of(c) != null and c.allied_with(e.rider_of(c)):
		return CombatResult.fail("A controlled mount can only Dash, Disengage or Dodge")
	var beast_why := e.class_features.companion_why(c)
	if beast_why != "":
		return CombatResult.fail(beast_why)
	if c.creature is Monster and bool((c.creature as Monster).data.get("familiar", false)) and not bool(opts.get("chain", false)):
		return CombatResult.fail("A familiar doesn't attack on its own (Pact of the Chain: its warlock gives up an attack for it)")
	var lp := option["profile"] as WeaponProfile
	if "loading" in lp.properties and not e.features.has_feat(c, "crossbow_expert") and c.attacks_left > 0 \
			and str(c.get_meta("loading_fired", "")) == "%d:%d" % [e.round_no, e.turn_index]:
		return CombatResult.fail("Loading: one shot with it per action")
	var sanct := e.spells.sanctuary_blocks(c, target)
	if sanct != "":
		return CombatResult.fail(sanct)
	if c.attacks_left > 0:
		c.attacks_left -= 1
	elif c.action_available:
		e.spend_action(c)
		c.took_attack_action = true
		c.attacks_left = e.attacks_per_action(c) - 1
		if c.creature is Monster:
			c.attacks_left = 0
		e.echo_knight.attack_action_taken(c)
	else:
		return CombatResult.fail("No attacks left this turn")
	var p := option["profile"] as WeaponProfile
	if "light" in p.properties and c.light_attack_weapon == "":
		c.light_attack_weapon = p.item_id
	# Loading: one shot per action, whatever the number of attacks (Crossbow Expert ignores it).
	if "loading" in p.properties and not e.features.has_feat(c, "crossbow_expert"):
		c.set_meta("loading_fired", "%d:%d" % [e.round_no, e.turn_index])
	var echo := e.echo_knight.attack_origin(c, target, option)
	return e.echo_knight.strike(c, echo, func() -> CombatResult: return _resolve_attack(c, target, option, opts))


## The Light property's extra attack (a Bonus Action, or part of the Attack action with Nick), with a different
## Light weapon, without the ability modifier to damage unless it's negative.
func offhand_attack(c: Combatant, target: Combatant, option_id: String) -> CombatResult:
	var e := enc()
	var why := e._turn_check(c)
	if why != "":
		return CombatResult.fail(why)
	var option := e.option_by_id(c, option_id)
	if option.is_empty():
		return CombatResult.fail("No such attack")
	var p := option["profile"] as WeaponProfile
	if c.light_attack_weapon == "" or not c.took_attack_action:
		return CombatResult.fail("First attack with a Light weapon in the Attack action")
	# Dual Wielder: the extra attack can use any melee weapon that isn't Two-Handed. Psychic Blades: a second blade.
	var dual := e.features.has_feat(c, "dual_wielder") and bool(option["melee"]) and not "two_handed" in p.properties
	var blade := c.light_attack_weapon == "psychic_blade" and p.item_id == "psychic_blade"
	if not blade and ((not "light" in p.properties and not dual) or p.item_id == c.light_attack_weapon):
		return CombatResult.fail("Needs a different Light weapon")
	var nick := false
	var first_mastery := ""
	for o in e.attack_options(c):
		var op := o["profile"] as WeaponProfile
		if op.item_id == c.light_attack_weapon:
			first_mastery = op.mastery
	if c.nick_used:
		return CombatResult.fail("Already made the Light property's extra attack this turn")
	if p.mastery == "nick" or first_mastery == "nick":
		nick = true
	if not nick and not c.bonus_available:
		return CombatResult.fail("Bonus Action already used")
	# With Nick the extra attack is part of the Attack action, so an Echo Knight can make it from its echo.
	var check := e.echo_knight.attack_why(c, target, option, nick)
	if check != "":
		return CombatResult.fail(check)
	var sanct := e.spells.sanctuary_blocks(c, target)
	if sanct != "":
		return CombatResult.fail(sanct)
	c.nick_used = true
	if not nick:
		c.bonus_available = false
	var echo := e.echo_knight.attack_origin(c, target, option) if nick else null
	return e.echo_knight.strike(c, echo, func() -> CombatResult: return _resolve_attack(c, target, option, {"offhand": true}))


## Every Advantage and Disadvantage source for this attack, plus cover:
## {advantage: [...], disadvantage: [...], cover: int, cover_bonus: int, cover_by: String}
func attack_situation(c: Combatant, target: Combatant, option: Dictionary) -> Dictionary:
	var e := enc()
	var adv: Array[String] = []
	var dis: Array[String] = []
	var p := option["profile"] as WeaponProfile
	var origin_cell: Vector2i = option.get("origin_cell", c.cell)
	var origin_size := 1 if option.has("origin_cell") else c.size_cells
	var dist := e.grid.distance_ft(origin_cell, origin_size, target.cell, target.size_cells, 0 if option.has("origin_cell") else c.altitude, target.altitude)
	var melee := bool(option["melee"])
	var duel := e.spells.specials.duel_disadvantage(c, target)
	if duel != "":
		dis.append(duel)
	e.class_features.attack_situation(c, target, option, adv, dis)
	for m in target.creature.modifiers_for(&"attacked_with"):
		if m.source_name == "Dodging" and (not e.can_see(target, c) or target.speed() <= 0):
			continue
		if m.text("attack_kind") == "ranged" and melee:
			continue
		if m.text("attack_kind") == "melee" and not melee:
			continue
		# Spellguard Shield: only spell attacks.
		if bool(m.data.get("spell_only", false)) and str(option.get("kind", "")) != "spell":
			continue
		if bool(m.data.get("if_seen", false)) and not e.can_see(c, target):
			continue
		var skip := false
		for sense: Variant in m.data.get("unless_sense", []):
			if c.creature.sense_range(str(sense)) >= dist:
				skip = true
		if skip:
			continue
		if m.text("value") == "advantage":
			adv.append("%s (target)" % m.source_name)
		elif m.text("value") == "disadvantage":
			dis.append("%s (target)" % m.source_name)
	if target.creature.has_condition(&"prone"):
		if dist <= 5:
			adv.append("target Prone within 5 ft")
		else:
			dis.append("target Prone beyond 5 ft")
	if not melee:
		var sharp := e.features.has_feat(c, "sharpshooter") and not str(option.get("kind", "")) in ["spell", "thrown"]
		if p.normal_range > 0 and dist > p.normal_range and not sharp:
			dis.append("long range")
		var melee_ok := sharp or (e.features.has_feat(c, "crossbow_expert") and p.item_id.contains("crossbow")) \
			or (str(option.get("kind", "")) == "spell" and e.features.has_feat(c, "spell_sniper"))
		for h in e.hostiles_of(c):
			if melee_ok:
				break
			if h.can_act() and e.distance(c, h) <= 5 and e.can_see(h, c):
				dis.append("ranged attack with %s within 5 ft" % h.name())
				break
	if "heavy" in p.properties:
		var need := &"str" if melee else &"dex"
		if c.creature.ability_score(need) < 13:
			dis.append("Heavy weapon with %s under 13" % Creature.ABILITY_NAMES[need])
	if c.creature.has_flag("pack_tactics"):
		for a in e.allies_of(c):
			if a.can_act() and e.distance(a, target) <= 5:
				adv.append("Pack Tactics")
				break
	for m in target.creature.modifiers_for(&"attacked_with_by_type"):
		if str(c.creature.creature_type) in (m.data.get("types", []) as Array):
			dis.append("%s (target)" % m.source_name)
	if c.creature.has_flag("cursed_attacks:%s" % target.id):
		dis.append("Bestow Curse")
	if CombatFeatures.has_feature(c, "assassinate") and e.round_no == 1 and not target.has_acted:
		adv.append("Assassinate (it hasn't acted yet)")
	if e.features.has_feat(c, "grappler") and str(e.grapples.get(target.id, "")) == c.id:
		adv.append("Grappler")
	var dup := e.spells.zones.object_of(c.id, "invoke_duplicity")
	if dup != null and e.distance(c, target) <= 5 and e.grid.distance_ft(dup.cell, 1, target.cell, target.size_cells) <= 5:
		adv.append("Invoke Duplicity")
	for ally in e.allies_of(c):
		var dup2 := e.spells.zones.object_of(ally.id, "invoke_duplicity")
		if dup2 != null and CombatFeatures.has_feature(ally, "improved_duplicity") and e.grid.distance_ft(dup2.cell, 1, target.cell, target.size_cells) <= 5:
			adv.append("Improved Duplicity")
	if e.grapples.has(c.id) and str(e.grapples[c.id]) != target.id:
		dis.append("Grappled (attacking someone other than the grappler)")
	adv.append_array(e.faerun.attack_advantage(c, target))
	if c.hidden or not e.can_see(target, c):
		adv.append("target can't see you")
	if not e.can_see(c, target):
		dis.append("you can't see the target")
	if e.in_sunlight(c) and e.monster_actions.sunlight(c) != "":
		dis.append("Sunlight")
	if c.has_meta("attack_disadvantage"):
		dis.append("a severed part")
	for m in e.marks:
		if not _mark_applies(m, c, target):
			continue
		if str(m["kind"]) in ["advantage_against", "advantage_next_attack"]:
			adv.append(str(m["source"]))
		elif str(m["kind"]) in ["disadvantage_next_attack", "disadvantage_against"]:
			dis.append(str(m["source"]))
	# Goading Attack: Disadvantage on attacks against anyone but the Battle Master who goaded it.
	for m2 in c.creature.modifiers_for(&"flag"):
		var v := m2.text("value")
		if v.begins_with("goaded_by:") and v.substr(10) != target.id:
			dis.append("Goaded")
	# Elusive (Rogue 18): no Advantage against it while it isn't Incapacitated.
	if target.creature.has_flag("elusive") and target.can_act():
		adv.clear()
	var cov := e.grid.cover_between(origin_cell, origin_size, target.cell, target.size_cells, e.creature_cells([c, target])) if option.has("origin_cell") else e.cover(c, target)
	var degree := int(cov["cover"])
	var by := str(cov["by"])
	# Bulwark of Force: at least Half Cover.
	if target.creature.has_flag("half_cover") and degree < CombatGrid.Cover.HALF:
		degree = CombatGrid.Cover.HALF
		by = "Bulwark of Force"
	# Holy Star of Mystra: at least Three-Quarters Cover.
	if target.creature.has_flag("three_quarters_cover") and degree < CombatGrid.Cover.THREE_QUARTERS:
		degree = CombatGrid.Cover.THREE_QUARTERS
		by = "Holy Star of Mystra"
	# Sharpshooter (weapons) and Spell Sniper (spell attacks) ignore Half and Three-Quarters Cover.
	var ranged_kind := str(option.get("kind", ""))
	if degree in [CombatGrid.Cover.HALF, CombatGrid.Cover.THREE_QUARTERS] and not melee and \
			((e.features.has_feat(c, "sharpshooter") and ranged_kind != "spell") or (e.features.has_feat(c, "spell_sniper") and ranged_kind == "spell")):
		degree = CombatGrid.Cover.NONE
		by = ""
	return {"advantage": adv, "disadvantage": dis, "cover": degree, "cover_bonus": CombatGrid.COVER_BONUS[degree],
		"cover_by": by, "height_bonus": e.sight.height_edge(c, target, option)}


## The tooltip and log line for the high-ground house rule's bonus (EncounterSight.height_edge).
static func height_line(bonus: int) -> String:
	return "High ground: +%d to hit" % bonus if bonus > 0 else "Low ground: %d to hit" % bonus


## Dice the target's effects add to attack rolls against it (Blade Ward: −1d4).
func attacked_dice(target: Combatant) -> Array:
	var out: Array = []
	for m in target.creature.modifiers_for(&"attacked_penalty_die"):
		out.append({"dice": m.text("dice", "1d4"), "sign": -1, "source": m.source_name})
	return out


## Whether a mark changes `c`'s attack on `target`: Vex (only its attacker), Help (an ally of the helper, not the
## helper), Guiding Bolt (anyone), Steady Aim and Sap (the marked attacker's next attack).
func _mark_applies(m: Dictionary, c: Combatant, target: Combatant) -> bool:
	var e := enc()
	match str(m["kind"]):
		"disadvantage_against":
			var guard := e.get_c(str(m.get("guard", "")))
			return str(m["target"]) == target.id and guard != null and e.distance(guard, target) <= 5
		"advantage_against":
			if str(m["target"]) != target.id:
				return false
			if m.has("not_attacker") and str(m["not_attacker"]) == c.id:
				return false
			if m.has("attacker"):
				return str(m["attacker"]) == c.id
			if m.has("helper"):
				var helper := e.get_c(str(m["helper"]))
				return helper != null and helper != c and c.allied_with(helper)
			return true
		"advantage_next_attack", "disadvantage_next_attack":
			return str(m["attacker"]) == c.id
	return false


func _consume_marks(c: Combatant, target: Combatant) -> void:
	var e := enc()
	var keep: Array[Dictionary] = []
	for m in e.marks:
		if bool(m.get("consume", false)) and _mark_applies(m, c, target):
			continue
		keep.append(m)
	e.marks = keep


## Chance to hit with the d20 needed, for tooltips and the AI: {chance, needs, advantage, disadvantage}.
func hit_chance(c: Combatant, target: Combatant, option: Dictionary) -> Dictionary:
	var p := option["profile"] as WeaponProfile
	var sit := attack_situation(c, target, option)
	var ac := target.creature.ac_value() + int(sit["cover_bonus"])
	var bonus := p.attack.total() + int(sit.get("height_bonus", 0))
	var needs := clampi(ac - bonus, 2, 20)
	var crit := mini(p.crit_range, 20)
	needs = mini(needs, crit)
	var single := (21 - needs) / 20.0
	var adv := (sit["advantage"] as Array).size() > 0
	var dis := (sit["disadvantage"] as Array).size() > 0
	var chance := single
	if adv and not dis:
		chance = 1.0 - pow(1.0 - single, 2)
	elif dis and not adv:
		chance = single * single
	return {"chance": chance, "needs": needs, "advantage": adv and not dis, "disadvantage": dis and not adv,
		"situation": sit, "ac": ac}


## The attack itself, in stages that can pause for reactions (combat/reactions.gd): offers before the roll
## (Warding Flare, Protection, Lucky), the roll, ways to turn the attacker's miss into a hit (Heroic Inspiration,
## Precision Attack, Guided Strike), reactions that turn a hit into a miss (Shield, Defensive Duelist, Illusory
## Self), damage (Critical Hits, Sneak Attack and Cunning Strike, Great Weapon Fighting, Savage Attacker, riders the
## attacker armed), reactions against the damage (Uncanny Dodge, Parry, Interception...), defenses, Undead
## Fortitude, mastery properties and on-hit effects, then reactions to the damage (Hellish Rebuke) and Riposte.
func _resolve_attack(c: Combatant, target: Combatant, option: Dictionary, opts: Dictionary) -> CombatResult:
	var e := enc()
	if (option["profile"] as WeaponProfile).two_hands:
		for fx: Effect in c.creature.effects.duplicate():
			if bool(fx.data.get("ends_on_two_handed_attack", false)):
				c.creature.remove_effect(fx)
	var r := CombatResult.new()
	# Wind Wall: ordinary missiles shot across it are deflected upward and miss.
	if not bool(option["melee"]) and str(option.get("kind", "")) in ["weapon", "thrown", "monster"] and e.spells.zones.deflects_between(c, target):
		if c.creature is Character and str(option.get("kind", "")) == "weapon":
			e.weapons._spend_ammo(c, option["profile"] as WeaponProfile)
		e.events.append({"type": "attack", "attacker": c.id, "from": EchoKnight.striking_from(c), "target": target.id, "hit": false, "critical": false, "action": str(option.get("id", ""))})
		r.lines.append(e.log.add("miss", "The Wind Wall deflects %s's shot at %s" % [c.name(), target.name()], c.id))
		return r
	var sit := attack_situation(c, target, option)
	_consume_marks(c, target)
	e.spells.specials.duel_check_attack(c, target)
	if c.hostile_to(target):
		e.class_features.kept_rage(c)
	e.spells.end_sanctuary(c, "attacked")
	e.spells.trigger_ends(c, "attack_roll")
	e.monster_actions.end_vanish(c)
	if c.hidden and not e.features.has_feat(c, "skulker"):
		e.reveal(c, "attacked")
	if bool(opts.get("reaction", false)) and e.features.has_feat(target, "speedy") and not bool(opts.get("readied", false)):
		(sit["disadvantage"] as Array[String]).append("Agile Movement")
	var st := {"c": c, "target": target, "option": option, "opts": opts, "sit": sit, "r": r,
		"ac": target.creature.ac_value() + int(sit["cover_bonus"])}
	var before := e.echo_knight.before_roll(st)
	before.append_array(e.reactions.before_roll(st))
	before.append_array(e.items.before_roll(st))
	return e.reactions.offer(before, func() -> CombatResult: return _roll_attack(st), r)


func _roll_attack(st: Dictionary) -> CombatResult:
	var e := enc()
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var option := st["option"] as Dictionary
	var sit := st["sit"] as Dictionary
	var r := st["r"] as CombatResult
	var p := option["profile"] as WeaponProfile
	var ac := int(st["ac"])
	var keys: Array[String] = ["attack", "attack:melee" if bool(option["melee"]) else "attack:ranged", "attack:%s" % p.ability]
	st["charge"] = e.monster_actions.charge_of(c, target, option)
	c.clear_run()
	var label := "%s → %s (%s)" % [c.name(), target.name(), p.name]
	# What can change the roll once it's made (Bend Luck, a Bardic Inspiration die, a Luck Blade...): asked below.
	var col := e.d20.collect(c)
	var t := c.creature.roll_d20(e.dice, D20Test.Kind.ATTACK_ROLL, p.attack, ac, keys, sit["advantage"] as Array[String],
		sit["disadvantage"] as Array[String], label, p.crit_range, attacked_dice(target))
	if int(sit.get("height_bonus", 0)) != 0:
		t.add_bonus(int(sit.get("height_bonus", 0)), "High ground" if int(sit.get("height_bonus", 0)) > 0 else "Low ground")
	var responses := e.d20.collected(col)
	target.creature.consume_attacked()
	# Sundering Blow: the next attack by someone else against the creature gets +5.
	for m: Dictionary in e.marks.duplicate():
		if str(m["kind"]) == "attack_bonus_against" and str(m.get("target", "")) == target.id and str(m.get("not_by", "")) != c.id:
			t.add_bonus(int(m.get("bonus", 5)), str(m.get("source", "")))
			e.marks.erase(m)
			break
	if not option.get("melee", true) and c.creature is Character and not bool((st["opts"] as Dictionary).get("free_ammo", false)):
		if option.has("improvised"):
			e.objects.actions.thrown(c, option, target)   # picked up and thrown (ObjectActions)
		elif str(option.get("kind", "")) == "thrown":
			e.weapons.throw_item(c, p.item_id, target)
		elif str(option.get("kind", "")) != "blade":
			e.weapons._spend_ammo(c, p)
	st["t"] = t
	return e.reactions.offer(responses, func() -> CombatResult:
		if t.success:
			return _attack_outcome(st)
		return e.reactions.offer(_miss_offers(st), func() -> CombatResult: return _attack_outcome(st), r), r)


## The attacker's ways to turn its own miss into a hit: Heroic Inspiration (2024: reroll the d20 and use the new roll),
## then Precision Attack, Guided Strike and the rest (Reactions.after_miss_attacker).
func _miss_offers(st: Dictionary) -> Array:
	var e := enc()
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var t := st["t"] as D20Test
	var chain: Array = []
	if c.creature is Character and (c.creature as Character).heroic_inspiration and c.is_player_controlled():
		chain.append({"kind": "heroic_inspiration", "reactor": c, "trigger": target.id, "title": "Heroic Inspiration?",
			"text": func() -> String: return "%s misses %s: %d vs AC %d. Spend Heroic Inspiration to reroll the d20 and use the new roll?" % [c.name(), target.name(), t.total, t.target],
			"cost": "Heroic Inspiration (regained on a Long Rest)", "spends_reaction": false,
			"still": func() -> bool: return not t.success and (c.creature as Character).heroic_inspiration,
			"use": func() -> void:
				(c.creature as Character).heroic_inspiration = false
				var before := t.describe()
				t.reroll_one(e.dice.d20("Heroic Inspiration"), "Heroic Inspiration")
				e.log.add("roll", "%s spends Heroic Inspiration to reroll: %d" % [c.name(), t.total], c.id, [before, t.describe()])})
	chain.append_array(e.reactions.after_miss_attacker(st))
	return chain


func _attack_outcome(st: Dictionary) -> CombatResult:
	var e := enc()
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var option := st["option"] as Dictionary
	var sit := st["sit"] as Dictionary
	var r := st["r"] as CombatResult
	var t := st["t"] as D20Test
	var ac := int(st["ac"])
	var p := option["profile"] as WeaponProfile
	var details: Array[String] = [t.describe(), p.attack.describe()]
	if int(sit["cover"]) > 0:
		details.append("%s: target AC +%d (%s)" % [CombatGrid.COVER_NAMES[int(sit["cover"])], int(sit["cover_bonus"]), sit["cover_by"]])
	for s: String in t.advantage_sources:
		details.append("Advantage: " + s)
	for s: String in t.disadvantage_sources:
		details.append("Disadvantage: " + s)
	var critical := t.critical
	if t.success and not critical and e.distance(c, target) <= 5 and target.creature.has_flag("auto_crit_within_5ft"):
		critical = true
		details.append("Automatic Critical Hit: the target can't defend itself within 5 ft")
	if t.success and not critical and e.items.makes_crit(c, target, option, details):
		critical = true
	critical = e.items.crit_allowed(c, target, critical, details)
	var success := t.success
	if success and mirror_image_takes(target, c, t.total):
		success = false
		critical = false
	st["critical"] = critical
	st["details"] = details
	if not success:
		return _attack_missed(st)
	var miss := func() -> CombatResult:
		r.lines.append(e.log.add("miss", "%s's attack on %s is turned aside (%d vs AC %d)" % [c.name(), target.name(), t.total, int(st["ac"])], target.id, details))
		e.events.append({"type": "attack", "attacker": c.id, "from": EchoKnight.striking_from(c), "target": target.id, "hit": false, "critical": false, "edge": attack_edge(st["t"] as D20Test), "action": str(option.get("id", ""))})
		e.features.after_miss(c, target, option, r)
		return r
	var hit_offers := e.reactions.after_hit_target(st, miss)
	hit_offers.append_array(e.monster_actions.parry_offer(st, miss))
	return e.reactions.offer(hit_offers, func() -> CombatResult:
		e.events.append({"type": "attack", "attacker": c.id, "from": EchoKnight.striking_from(c), "target": target.id, "hit": true, "critical": critical, "edge": attack_edge(st["t"] as D20Test), "action": str(option.get("id", ""))})
		return _after_hit(st), r)


## "advantage", "disadvantage" or "" for an attack roll, with the reasons (the view shows it over the attacker).
static func attack_edge(t: D20Test) -> Dictionary:
	if t == null:
		return {}
	if t.advantage:
		return {"kind": "advantage", "why": t.advantage_sources.duplicate()}
	if t.disadvantage:
		return {"kind": "disadvantage", "why": t.disadvantage_sources.duplicate()}
	return {}


func _attack_missed(st: Dictionary) -> CombatResult:
	var e := enc()
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var option := st["option"] as Dictionary
	var r := st["r"] as CombatResult
	var t := st["t"] as D20Test
	e.events.append({"type": "attack", "attacker": c.id, "from": EchoKnight.striking_from(c), "target": target.id, "hit": false, "critical": false, "edge": attack_edge(st["t"] as D20Test), "action": str(option.get("id", ""))})
	r.lines.append(e.log.add("miss", "%s misses %s (%d vs AC %d)" % [c.name(), target.name(), t.total, int(st["ac"])], c.id, st["details"] as Array))
	_on_miss(c, target, option, r)
	e.features.after_miss(c, target, option, r)
	e.items.after_miss(c, target, option, r)
	return e.reactions.offer(e.reactions.after_miss_target(st), func() -> CombatResult:
		if st.has("riposte"):
			var rp := st["riposte"] as Dictionary
			var by := rp["by"] as Combatant
			return _resolve_attack(by, c, rp["option"] as Dictionary, {"reaction": true,
				"extra_dice": [{"dice": "1d%d" % int(rp["die"]), "type": str(((rp["option"] as Dictionary)["profile"] as WeaponProfile).damage_type), "label": "Riposte"}]})
		return r, r)


func _after_hit(st: Dictionary) -> CombatResult:
	var e := enc()
	if not bool(st.get("hit_responses_offered", false)):
		st["hit_responses_offered"] = true
		return e.reactions.offer(e.feature_recipes.hit_responses(st["c"] as Combatant, st["target"] as Combatant),
			func() -> CombatResult: return _after_hit(st), st["r"] as CombatResult)
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var option := st["option"] as Dictionary
	var opts := st["opts"] as Dictionary
	var r := st["r"] as CombatResult
	var t := st["t"] as D20Test
	var critical := bool(st["critical"])
	var p := option["profile"] as WeaponProfile
	r.hit = true
	r.critical = critical
	if c.hidden and e.features.has_feat(c, "skulker"):
		e.reveal(c, "hit with an attack")
	var parts := {}
	var dmg_text: Array[String] = []
	var dice_list: Array[Dictionary] = [{"dice": p.damage_dice, "type": str(p.damage_type), "label": p.name, "weapon": true}]
	if c.creature is Monster:
		dice_list.append_array((c.creature as Monster).extra_damage_dice(str(option.get("action_id", "")), target.creature))
	var sneak := e.features.sneak_attack_dice(c, target, option, t)
	if sneak != "":
		sneak = e.features.cunning_strike_cost(c, sneak, st)
		if sneak != "":
			dice_list.append({"dice": sneak, "type": str(p.damage_type), "label": "Sneak Attack"})
		st["sneak"] = true
	for extra: Variant in opts.get("extra_dice", []):
		dice_list.append(extra as Dictionary)
	dice_list.append_array(e.features.hit_damage_dice(c, target, option, st))
	dice_list.append_array(e.items.hit_damage_dice(c, target, option, st))
	# A charge (giant elk, goat, boars, rhinoceros): extra or bigger damage after a straight run at the target.
	var charge := st.get("charge", {}) as Dictionary
	if not charge.is_empty():
		c.set_meta("charged_vs", target.id)
		if bool(charge.get("replace", false)):
			st["replace_weapon_damage"] = true
		for cd: Variant in charge.get("damage", []):
			dice_list.append({"dice": str((cd as Dictionary)["dice"]), "type": str((cd as Dictionary)["type"]), "label": "Charge"})
	# Lightning Arrow: the bolt's damage instead of the weapon's.
	var replaced := bool(st.get("replace_weapon_damage", false))
	if replaced:
		dice_list.assign(dice_list.filter(func(x: Dictionary) -> bool: return not bool(x.get("weapon", false)) and str(x.get("label", "")) != "Sneak Attack"))
	# Extra damage on weapon and Unarmed Strike hits from spells (Crusader's Mantle, Enlarge) and features.
	for m in c.creature.modifiers_for(&"damage_penalty_die"):
		dice_list.append({"dice": m.text("dice", "1d8"), "type": str(p.damage_type), "label": m.source_name, "penalty": true})
	for m in c.creature.modifiers_for(&"extra_damage"):
		if m.data.has("vs") and str(m.data["vs"]) != target.id:
			continue
		var xt := e.spells.extra_damage_type(c, target, m, str(p.damage_type))
		if xt == "":
			continue
		dice_list.append({"dice": m.text("dice", "1d4"), "type": xt, "label": m.source_name,
			"penalty": bool(m.data.get("penalty", false))})
	var turn_key := "%d:%d" % [e.round_no, e.turn_index]
	var savage := c.creature.has_flag("savage_attacker") and str(e._savage_turn.get(c.id, "")) != turn_key and c.creature is Character
	var exploit := e.faerun.exploit_opening(c, opts)
	for entry in dice_list:
		var minimum := p.die_minimum if bool(entry.get("weapon", false)) else 0
		# Dread Incarnate (Scion of the Three 17): Sneak Attack dice of 1 or 2 count as 3.
		if str(entry.get("label", "")) == "Sneak Attack" and CombatFeatures.has_feature(c, "dread_incarnate"):
			minimum = maxi(minimum, 3)
		var rolled := e._roll_damage_dice(str(entry["dice"]), critical, minimum,
			"%s damage" % entry["label"], e.features.damage_reroll_rule(c, p, entry))
		# Exploit Opening (Zhentarim Ruffian): an Opportunity Attack's damage dice twice, the better roll kept.
		if exploit and not bool(entry.get("penalty", false)):
			var twice := e._roll_damage_dice(str(entry["dice"]), critical, p.die_minimum if bool(entry.get("weapon", false)) else 0, "Exploit Opening reroll")
			if int(twice["total"]) > int(rolled["total"]):
				rolled = twice
				dmg_text.append("Exploit Opening: rolled twice, kept %d" % int(twice["total"]))
		if savage and bool(entry.get("weapon", false)) and p.item_id != "unarmed_strike":
			e._savage_turn[c.id] = turn_key
			var again := e._roll_damage_dice(str(entry["dice"]), critical, p.die_minimum, "Savage Attacker reroll")
			if int(again["total"]) > int(rolled["total"]):
				rolled = again
				dmg_text.append("Savage Attacker: rerolled and kept %d" % int(again["total"]))
		# Boon of Exquisite Radiance, Boon of Poison Mastery: every die at its maximum.
		if not bool(entry.get("penalty", false)) and int(DiceRoller.parse_expr(str(entry["dice"]))["count"]) > 0 and e.faerun.maximized(c, str(entry["type"])):
			rolled = e._max_damage_dice(str(entry["dice"]), critical)
		var ty := str(entry["type"])
		if bool(entry.get("penalty", false)):
			parts[str(p.damage_type)] = int(parts.get(str(p.damage_type), 0)) - int(rolled["total"])
			dmg_text.append("%s −%s: %s" % [entry["label"], entry["dice"], rolled["text"]])
			continue
		parts[ty] = int(parts.get(ty, 0)) + int(rolled["total"])
		dmg_text.append("%s %s%s: %s" % [entry["label"], entry["dice"], " ×2 (Critical Hit)" if critical else "", rolled["text"]])
	var bonus := 0 if replaced else p.damage_bonus.total() + e.features.flat_damage_bonus(c, target, option, st, dmg_text)
	if bool(opts.get("offhand", false)) and bonus > 0 and not c.creature.has_flag("two_weapon_fighting") \
			and not (e.features.has_feat(c, "crossbow_expert") and p.item_id == "hand_crossbow"):
		bonus = 0
		dmg_text.append("Light extra attack: no ability modifier to damage")
	if bool(opts.get("no_mod", false)) and bonus > 0:
		bonus = maxi(0, bonus - p.damage_bonus.total())
		dmg_text.append("No ability modifier to this damage")
	var primary := str(p.damage_type)
	if not replaced:
		parts[primary] = maxi(0, int(parts.get(primary, 0)) + bonus)
	if bonus != 0:
		dmg_text.append(p.damage_bonus.describe())
	var details := st["details"] as Array[String]
	var r2 := e.reactions.offer(e.reactions.against_damage(st, parts, dmg_text), func() -> CombatResult:
		return _apply_hit(st, parts, details, dmg_text), r)
	return r2


func _apply_hit(st: Dictionary, parts: Dictionary, details: Array[String], dmg_text: Array[String]) -> CombatResult:
	var e := enc()
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var option := st["option"] as Dictionary
	var r := st["r"] as CombatResult
	var critical := bool(st["critical"])
	var arr: Array = []
	for k: String in parts:
		arr.append({"amount": int(parts[k]), "type": k, "weapon": true, "melee": bool(option["melee"]),
			"item": (option["profile"] as WeaponProfile).item_id, "ranged_weapon": str(option.get("kind", "")) in ["weapon", "thrown"] and not bool(option["melee"])})
	var all_details := details.duplicate()
	all_details.append_array(dmg_text)
	# Rampage (giant hyena) answers a hit on a creature that was already Bloodied.
	if c.creature is Monster and target.creature.is_bloodied():
		c.set_meta("hit_bloodied", "%d:%d" % [e.round_no, e.turn_index])
	e.hit_context = {"attacker": c.id, "target": target.id, "melee": bool(option.get("melee", false))}
	var dr := e.deal_damage(c, target, arr, critical, (option["profile"] as WeaponProfile).name, all_details, true, st.get("damage_responses", []))
	e.hit_context = {}
	r.damage = dr.final
	if target.is_down():
		r.killed.append(target.id)
	# The hit's riders can call for saves that stop for the choices after their rolls (a ghoul's paralysis).
	return e.then(_on_hit_effects(c, target, option, dr, r), func() -> CombatResult:
		if bool(option["melee"]):
			retaliate(c, target)
			e.spells.specials.high.holy_aura_hit(c, target)
		e.features.after_hit(c, target, option, dr, st, r)
		e.items.after_hit(c, target, option, dr, st, r)
		e.reaction_flow._queue_sentinels(c, target)
		return e.run_reaction_queue(r))


## A melee hit on a creature wrapped in Armor of Agathys or Fire Shield: the attacker takes the spell's damage
## (`retaliate` modifiers: `value` or `dice`, `type`, `within` feet).
func retaliate(attacker: Combatant, target: Combatant) -> void:
	var e := enc()
	if attacker == null or not attacker.is_alive():
		return
	# A blow struck from an Echo Knight's echo: the knight was never within reach of the shield.
	if attacker.has_meta("strike_from"):
		return
	for m in target.creature.modifiers_for(&"retaliate"):
		if e.distance(attacker, target) > int(m.data.get("within", 5)):
			continue
		if bool(m.data.get("once_per_turn", false)) and not e.class_features._once(target, "retaliate:%s" % m.source_id):
			continue
		var amount := m.number("value") if m.data.has("value") else 0
		var text := "%d" % amount
		if m.data.has("dice"):
			var rolled := e._roll_damage_dice(m.text("dice"), false, 0, m.source_name)
			amount += int(rolled["total"])
			text = str(rolled["text"])
		if amount > 0:
			e.deal_damage(target, attacker, [{"amount": amount, "type": m.text("type", "cold"), "spell": true}], false, m.source_name,
				["%s strikes back: %s" % [m.source_name, text]])


func _on_miss(c: Combatant, target: Combatant, option: Dictionary, r: CombatResult) -> void:
	var e := enc()
	var p := option["profile"] as WeaponProfile
	if p.mastery == "graze":
		var mod := c.creature.ability_mod(p.ability)
		if mod > 0:
			r.lines.append(e.log.add("hit", "Graze: %s still deals %d %s damage" % [c.name(), mod, str(p.damage_type).capitalize()], c.id))
			e.deal_damage(c, target, [{"amount": mod, "type": str(p.damage_type)}], false, "Graze", [], false)


## Mastery properties and stat-block riders after a hit. Their saves (Topple, a ghoul's paralysis) stop for the
## choices after each roll, so the caller carries on with Encounter.then.
func _on_hit_effects(c: Combatant, target: Combatant, option: Dictionary, dr: DamageResult, r: CombatResult) -> CombatResult:
	var e := enc()
	var p := option["profile"] as WeaponProfile
	var steps: Array = [
		func() -> CombatResult: return _mastery_on_hit(c, target, p, dr, r),
		func() -> CombatResult: return _stat_block_on_hit(c, target, option, dr, r),
	]
	return e.each(steps, func(step: Variant) -> CombatResult: return (step as Callable).call() as CombatResult, func() -> CombatResult: return r)


## Vex, Sap, Slow, Topple (a Constitution save or Prone) and Push.
func _mastery_on_hit(c: Combatant, target: Combatant, p: WeaponProfile, dr: DamageResult, r: CombatResult) -> CombatResult:
	var e := enc()
	if not target.is_alive() or target.is_down():
		return r
	match p.mastery:
		"vex":
			if dr.final > 0:
				e.add_mark({"kind": "advantage_against", "target": target.id, "attacker": c.id, "source": "Vex",
					"expires_owner": c.id, "expires_phase": "end", "skip": e.own_turn_skip(c), "consume": true})
		"sap":
			e.add_mark({"kind": "disadvantage_next_attack", "attacker": target.id, "source": "Sapped by %s" % c.name(),
				"expires_owner": c.id, "expires_phase": "start", "consume": true})
		"slow":
			if dr.final > 0 and not target.creature.effects.any(func(x: Effect) -> bool: return x.name == "Slowed (mastery)"):
				var slowed := Effect.new("Slowed (mastery)", &"effect", "slow").with_modifier("speed", {"value": -10})
				slowed.ends = Effect.Ends.START_OF_TURN
				slowed.turn_owner_id = c.id
				target.creature.add_effect(slowed)
		"topple":
			# Hold back Topple or Push (hotbar riders): the mastery is skipped this turn.
			if not "skip:topple" in c.armed:
				var dc := 8 + c.creature.ability_mod(p.ability) + c.creature.proficiency_bonus()
				return e.d20.then_after(target, func() -> D20Test: return target.creature.roll_save(e.dice, &"con", dc, [], [], "Topple (%s)" % target.name()),
					func(sv: D20Test) -> CombatResult:
						if not sv.success:
							target.creature.add_condition(&"prone", "Topple")
							e.log.add("condition", "Topple: %s falls Prone" % target.name(), target.id, [sv.describe()])
						else:
							e.log.add("info", "Topple: %s keeps its feet" % target.name(), target.id, [sv.describe()])
						return r, r)
		"push":
			if Creature.SIZES.find(target.creature.size) <= Creature.SIZES.find(&"large") and not "skip:push" in c.armed:
				var moved := e.forced_move(target, e.center_of(c), 10)
				if moved > 0:
					e.log.add("info", "Push: %s is shoved %d ft" % [target.name(), moved * 5], target.id)
	return r


## Stat-block riders (a wolf's bite knocks Prone; size limits are in the action text): conditions with their saves,
## `on_hit` and a charge's riders, a Celestial Spirit's Temporary Hit Points for an ally.
func _stat_block_on_hit(c: Combatant, target: Combatant, option: Dictionary, dr: DamageResult, r: CombatResult) -> CombatResult:
	var e := enc()
	if not c.creature is Monster or not target.is_alive():
		return r
	var p := option["profile"] as WeaponProfile
	var act := (c.creature as Monster).action(str(option.get("action_id", "")))
	var land := func(cond: String) -> void:
		if cond == "prone" and Creature.SIZES.find(target.creature.size) > Creature.SIZES.find(c.creature.size):
			return
		if target.creature.add_condition(StringName(cond), str(act.get("name", ""))):
			e.log.add("condition", "%s has the %s condition" % [target.name(), cond.capitalize()], target.id)
			e.events.append({"type": "condition", "id": target.id})
	var conditions := func(raw: Variant) -> CombatResult:
		var cond := str(raw)
		if not act.has("save"):
			land.call(cond)
			return r
		var sv := act["save"] as Dictionary
		return e.d20.then_after(target, func() -> D20Test:
			return target.creature.roll_save(e.dice, StringName(str(sv["ability"])), int(sv["dc"]), [], [], "%s (%s)" % [act.get("name", ""), target.name()]),
			func(s2: D20Test) -> CombatResult:
				if not s2.success:
					land.call(cond)
				return r, r)
	var riders := func() -> CombatResult:
		if act.has("on_hit"):
			e.monster_actions.apply_riders(c, target, act["on_hit"] as Array, {str(p.damage_type): dr.final}, str(act.get("name", "")), true)
		return r
	var charge := func() -> CombatResult:
		if str(c.get_meta("charged_vs", "")) == target.id and act.has("charge"):
			e.monster_actions.apply_riders(c, target, (act["charge"] as Dictionary).get("on_hit", []) as Array, {}, "%s (charge)" % act.get("name", ""), true)
		return r
	var temp := func() -> CombatResult:
		# Celestial Spirit (Defender): a creature within 10 ft gains Temporary Hit Points.
		if act.has("ally_temp_hp"):
			var ath := act["ally_temp_hp"] as Dictionary
			var best: Combatant = null
			for a2 in e.allies_of(c):
				if a2 != c and a2.is_alive() and e.distance(c, a2) <= int(ath.get("range", 10)) and (best == null or a2.creature.temp_hp < best.creature.temp_hp):
					best = a2
			if best == null:
				best = c
			var amt := int(e._roll_damage_dice(str(ath.get("dice", "1d10")), false, 0, "Radiant Mace")["total"])
			if best.creature.add_temp_hp(amt, str(act.get("name", ""))):
				e.log.add("heal", "%s gains %d Temporary Hit Points (%s)" % [best.name(), amt, act.get("name", "")], best.id)
		return r
	return e.each(act.get("conditions", []) as Array, conditions, func() -> CombatResult:
		var rest: Array = [riders, charge, temp]
		return e.each(rest, func(step: Variant) -> CombatResult: return (step as Callable).call() as CombatResult, func() -> CombatResult: return r))


## A monster's stat-block action. Multiattack spends the action and queues its attacks; the AI then calls
## monster_attack for each.
func monster_attack(c: Combatant, target: Combatant, action_id: String) -> CombatResult:
	var e := enc()
	var why := e._turn_check(c)
	if why != "":
		return CombatResult.fail(why)
	var option := e.option_by_id(c, "monster:" + action_id)
	if option.is_empty():
		return CombatResult.fail("No such action")
	var check := e.attack_legal(c, target, option)
	if check != "":
		return CombatResult.fail(check)
	if c.attacks_left <= 0 and not c.action_available:
		return CombatResult.fail("No attacks left")
	var sanct := e.spells.sanctuary_blocks(c, target)
	if sanct != "":
		return CombatResult.fail(sanct)
	if c.attacks_left > 0:
		c.attacks_left -= 1
	elif c.action_available:
		e.spend_action(c)
		c.took_attack_action = true
	return _resolve_attack(c, target, option, {})


## Starts a Multiattack: spends the action and allows its listed attacks.
func begin_multiattack(c: Combatant) -> Array[Dictionary]:
	var e := enc()
	var out: Array[Dictionary] = []
	if not c.creature is Monster or not c.action_available:
		return out
	var m := c.creature as Monster
	var multi := m.action("multiattack")
	if multi.is_empty():
		return out
	e.spend_action(c)
	c.took_attack_action = true
	var count := 0
	for entry: Variant in multi.get("multiattack", []):
		var d := entry as Dictionary
		count += int(d["count"])
		out.append(d)
	c.attacks_left = count
	return out
