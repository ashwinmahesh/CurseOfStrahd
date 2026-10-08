class_name SpellDamage
extends RefCounted
## A spell's damage and healing in a fight (SpellCaster): its dice, type and bonuses, rolling them (Critical Hits,
## minimums), dealing it, damage that comes later, healing (Life Bond) and Temporary Hit Points.

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func sp() -> SpellCaster:
	return enc().spells


func _comp() -> Compendium:
	return Compendium.shared()


func _damage_dice(ctx: Dictionary, target: Combatant = null) -> String:
	var s := ctx["s"] as Dictionary
	var c := ctx["c"] as Combatant
	var dice := Spellcasting.damage_dice(s, c.creature.character_level(), int(ctx["slot"]))
	if str(s["id"]) == "toll_the_dead" and target != null and target.creature.hp < target.creature.max_hp():
		dice = dice.replace("d8", "d12")
	# Call Lightning out in a storm (2024): the caster takes control of the storm, and each bolt deals 1d10 more.
	if str(s["id"]) == "call_lightning" and enc().stormy():
		var pm := DiceRoller.parse_expr(dice)
		dice = "%dd%d%s" % [int(pm["count"]) + 1, int(pm["sides"]), ("%+d" % int(pm["modifier"])) if int(pm["modifier"]) != 0 else ""]
	return dice


func _damage_type(ctx: Dictionary, part: Dictionary = {}) -> String:
	if ctx.has("transmute_to"):
		return str(ctx["transmute_to"])
	if "psychic_spells" in (ctx.get("metamagic", []) as Array):
		return "psychic"
	var s := ctx["s"] as Dictionary
	var d := part if not part.is_empty() else (s.get("damage", []) as Array)[0] as Dictionary
	if d.has("type"):
		return str(d["type"])
	var types := (d.get("type_choice", []) as Array).map(func(x: Variant) -> String: return str(x))
	var pick := str(ctx.get("choice", ""))
	if pick == "":
		pick = str((ctx["opts"] as Dictionary).get("damage_type", ""))
	return pick if pick in types else str(types[0])


func _damage_bonus(ctx: Dictionary) -> Breakdown:
	var spells := sp()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	if spells.caster_char(c) == null:
		return Breakdown.new("Damage bonus")
	var ch := spells.caster_char(c)
	var preview := ch.spell_preview(str(s["id"]), int(ctx["slot"]))
	return preview.get("damage_bonus", Breakdown.new("Damage bonus")) as Breakdown


## The spell's first damage entry for one target: {total, text, dice}, with the spell's damage bonuses (Potent
## Spellcasting, Empowered Evocation).
func _roll_spell_damage(ctx: Dictionary, t: Combatant, critical: bool) -> Dictionary:
	var spells := sp()
	var e := enc()
	var dice := _damage_dice(ctx, t)
	# Erupting Spellpower: 1s and 2s count as 3s.
	var rolled := e._roll_damage_dice(dice, critical, 3 if bool(ctx.get("erupting", false)) else 0, "%s damage" % (ctx["s"] as Dictionary)["name"],
		{"count": maxi(1, (ctx["c"] as Combatant).creature.ability_mod(&"cha")), "at_most": int(DiceRoller.parse_expr(dice)["sides"]) / 2, "source": "Empowered Spell"} \
		if "empowered" in (ctx.get("metamagic", []) as Array) else {})
	var sp := ctx["s"] as Dictionary
	if bool(ctx.get("overchannel", false)):
		var pm := DiceRoller.parse_expr(dice)
		var mx := int(pm["count"]) * int(pm["sides"]) * (2 if critical else 1) + int(pm["modifier"])
		rolled = {"total": mx, "text": "maximum (Overchannel) = %d" % mx}
	# Boon of Exquisite Radiance, Boon of Poison Mastery: every die at its maximum.
	elif int(DiceRoller.parse_expr(dice)["count"]) > 0 and e.faerun.maximized(ctx["c"] as Combatant, _damage_type_safe(ctx)):
		rolled = e._max_damage_dice(dice, critical)
	var bonus := _damage_bonus(ctx)
	var total := int(rolled["total"]) + bonus.total()
	total += enc().ravenloft.spell_damage_bonus(ctx, bonus)
	total += enc().faerun.spell_damage_bonus(ctx, bonus)
	# Elemental Affinity (Draconic 6), Radiant Soul (Celestial 6): Charisma to one damage roll of the type.
	var cc := ctx["c"] as Combatant
	var dty := _damage_type_safe(ctx)
	if (ClassFeatures.has(cc, "elemental_affinity") and dty in ClassFeatures.picks(cc, "elemental_affinity")) \
			or (ClassFeatures.has(cc, "radiant_soul") and dty in ["radiant", "fire"] and enc().class_features._once(cc, "radiant_soul")):
		bonus.add("Charisma (%s)" % ("Elemental Affinity" if ClassFeatures.has(cc, "elemental_affinity") else "Radiant Soul"), maxi(0, cc.creature.ability_mod(&"cha")))
		total += maxi(0, cc.creature.ability_mod(&"cha"))
	var text := "%s %s%s: %s" % [(ctx["s"] as Dictionary)["name"], dice, " ×2 (Critical Hit)" if critical else "", rolled["text"]]
	if str(sp["id"]) == "sorcerous_burst":
		var burst := spells.specials.sorcerous_burst_extra(ctx, str(rolled["text"]))
		total += int(burst["total"])
		if str(burst["text"]) != "":
			text += " · " + str(burst["text"])
	if not bonus.parts.is_empty():
		text += " · " + bonus.describe()
	return {"total": maxi(0, total), "text": text, "dice": dice, "rolls": rolled.get("rolls", [])}


## Damage from a list of parts outside the spell's main entry (a zone's damage, Ice Knife's burst, Witch Bolt's
## later bolts), with upcast dice (`upcast` on the part, else the spell's `upcast.damage`) and the caster's
## modifier when `add_mod`. {total, text, type}
func roll_damage_parts(ctx: Dictionary, parts: Array, critical: bool, _t: Combatant, min_die: int = 0) -> Dictionary:
	var e := enc()
	var s := ctx["s"] as Dictionary
	var c := ctx["c"] as Combatant
	var slot := int(ctx["slot"])
	var total := 0
	var texts: Array[String] = []
	var ty := ""
	for p: Variant in parts:
		var part := p as Dictionary
		var base := DiceRoller.parse_expr(str(part.get("dice", "0")))
		var count := int(base["count"])
		var up := str(part.get("upcast", (s.get("upcast", {}) as Dictionary).get("damage", "")))
		if int(s.get("level", 0)) > 0 and slot > int(s.get("level", 0)) and up != "" and bool(part.get("scales", true)):
			count += int(DiceRoller.parse_expr(up)["count"]) * (slot - int(s.get("level", 0)))
		if int(s.get("level", 0)) == 0:
			var sc := s.get("cantrip_scaling", {}) as Dictionary
			if sc.has("damage"):
				count += int(DiceRoller.parse_expr(str(sc["damage"]))["count"]) * Spellcasting.cantrip_tier(c.creature.character_level())
		var dice := Spellcasting._format(count, int(base["sides"]), int(base["modifier"]))
		# Erupting Spellpower: 1s and 2s count as 3s.
		var rolled := e._roll_damage_dice(dice, critical, maxi(min_die, 3 if bool(ctx.get("erupting", false)) else 0), "%s damage" % s["name"])
		# Boon of Exquisite Radiance, Boon of Poison Mastery: every die at its maximum.
		if count > 0 and e.faerun.maximized(c, str(part["type"]) if part.has("type") else _damage_type(ctx, part)):
			rolled = e._max_damage_dice(dice, critical)
		var sub := int(rolled["total"])
		if bool(part.get("add_mod", false)):
			sub += int((ctx["nums"] as Dictionary).get("mod", 0))
		total += sub
		texts.append("%s %s: %s" % [s["name"], dice, rolled["text"]])
		if ty == "":
			ty = str(part["type"]) if part.has("type") else _damage_type(ctx, part)
	return {"total": maxi(0, total), "text": " · ".join(texts), "type": ty}


## The damage type of an `extra_damage` modifier against `t`, or "" if it doesn't apply: `in_zone` limits it to
## targets inside the caster's area of that spell, and `types` lets the attacker pick the best of several each time
## (Conjure Minor Elementals: whichever the target doesn't resist).
func extra_damage_type(c: Combatant, t: Combatant, m: Modifier, fallback: String) -> String:
	var spells := sp()
	if m.data.has("in_zone"):
		var o := spells.zones.object_of(c.id, str(m.data["in_zone"]))
		if o == null or not o.covers(t):
			return ""
	var options := m.data.get("types", []) as Array
	if not options.is_empty():
		var best := str(options[0])
		var best_score := -9
		for ty: Variant in options:
			var tn := StringName(str(ty))
			var score := 0
			if t.creature.immunity_source(tn) != "":
				score = -2
			elif t.creature.resistance_source(tn) != "":
				score = -1
			elif t.creature.vulnerability_source(tn) != "":
				score = 1
			if score > best_score:
				best_score = score
				best = str(ty)
		return best
	return m.text("type", fallback)


func _damage_type_safe(ctx: Dictionary) -> String:
	var s := ctx["s"] as Dictionary
	if (s.get("damage", []) as Array).is_empty():
		return ""
	return _damage_type(ctx)


func _heal(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var spells := sp()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var e := enc()
	if t.creature.has_flag("cant_regain_hp"):
		r.lines.append(e.log.add("info", "%s can't regain Hit Points right now" % t.name(), t.id))
		return
	if t.creature.creature_type in [&"undead", &"construct"] and bool(s.get("living_only", false)):
		r.lines.append(e.log.add("info", "%s has no effect on %s" % [s["name"], t.name()], t.id))
		return
	var dice := Spellcasting.heal_dice(s, int(ctx["slot"]))
	var bonus := Breakdown.new("Healing bonus")
	if spells.caster_char(c) != null:
		var preview := spells.caster_char(c).spell_preview(str(s["id"]), int(ctx["slot"]))
		dice = str(preview.get("heal_dice", ""))
		bonus = preview.get("heal_bonus", Breakdown.new("")) as Breakdown
	elif bool((s.get("heal", {}) as Dictionary).get("add_mod", false)):
		bonus.add("Spellcasting modifier", int((ctx["nums"] as Dictionary).get("mod", 0)))
	var heal_reroll := {"count": 99, "at_most": 1, "source": "Healer"} if e.features.has_feat(c, "healer") else {}
	var rolled := e.heal_roll(dice, t, "%s healing" % s["name"], heal_reroll) if dice != "" else {"total": 0, "text": ""}
	var total := int(rolled["total"])
	if t.creature.has_flag("max_healing_received") and dice != "":
		var p := DiceRoller.parse_expr(dice)
		total = int(p["count"]) * int(p["sides"]) + int(p["modifier"])
		rolled["text"] = "maximum (Beacon of Hope) = %d" % total
	if CombatFeatures.has_feature(c, "supreme_healing") and dice != "":
		var pmax := DiceRoller.parse_expr(dice)
		total = int(pmax["count"]) * int(pmax["sides"]) + int(pmax["modifier"])
	total = e.ravenloft.spell_healing(ctx, t, dice, total)
	total += e.faerun.spell_healing(ctx, t)
	var amount := total + bonus.total() + int((s.get("heal", {}) as Dictionary).get("flat", 0)) \
		+ int((s.get("upcast", {}) as Dictionary).get("heal_flat", 0)) * maxi(0, int(ctx["slot"]) - int(s.get("level", 0)))
	# Moon Sickle: healing spells cast while holding it heal 1d4 more.
	amount += e.items.healing_bonus(c, ctx)
	var healed := t.creature.heal(amount, str(s["name"]))
	# Blessed Healer (Life Domain 6): healing another creature with a slot heals you 2 + the slot level.
	if t != c and int(ctx["slot"]) > 0 and CombatFeatures.has_feature(c, "blessed_healer") and not ctx.has("blessed"):
		ctx["blessed"] = true
		var self_heal := c.creature.heal(2 + int(ctx["slot"]), "Blessed Healer")
		if self_heal > 0:
			e.log.add("heal", "%s regains %d Hit Points (Blessed Healer)" % [c.name(), self_heal], c.id)
	r.lines.append(e.log.add("heal", "%s heals %s for %d" % [c.name(), t.name(), healed], c.id,
		["%s %s: %s" % [s["name"], dice, rolled["text"]], bonus.describe()]))
	e.events.append({"type": "heal", "id": t.id, "amount": healed})
	_life_bond(t, healed, int(s.get("level", 0)))


## Life Bond (Find Steed): when the rider regains Hit Points from a spell of level 1+, a steed within 5 ft regains as
## many.
func _life_bond(t: Combatant, healed: int, level: int) -> void:
	var spells := sp()
	if healed <= 0 or level < 1:
		return
	var e := enc()
	for sid: Variant in spells.summoned.get(t.id, []):
		var steed := e.get_c(str(sid))
		if steed == null or not steed.is_alive() or not steed.creature is Monster or not bool((steed.creature as Monster).data.get("steed", false)):
			continue
		if e.distance(t, steed) <= 5:
			var got := steed.creature.heal(healed, "Life Bond")
			if got > 0:
				e.log.add("heal", "%s regains %d Hit Points (Life Bond)" % [steed.name(), got], steed.id)
				e.events.append({"type": "heal", "id": steed.id, "amount": got})


## Temporary Hit Points from the spell's `temp_hp` ({dice, flat, add_mod}) plus `upcast.temp_hp` per slot level.
func _temp_hp(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var s := ctx["s"] as Dictionary
	var e := enc()
	var th := s["temp_hp"] as Dictionary
	var total := int(th.get("flat", 0))
	var text := ""
	if th.has("dice"):
		var rolled := e._roll_damage_dice(str(th["dice"]), false, 0, "%s Temporary Hit Points" % s["name"])
		total += int(rolled["total"])
		text = str(rolled["text"])
		# Fiendish Vigor: False Life at its highest number.
		if str(s["id"]) == "false_life" and ClassFeatures.knows_invocation(ctx["c"] as Combatant, "fiendish_vigor"):
			var pm := DiceRoller.parse_expr(str(th["dice"]))
			total += int(pm["count"]) * int(pm["sides"]) + int(pm["modifier"]) - int(rolled["total"])
			text = "maximum (Fiendish Vigor)"
	if bool(th.get("add_mod", false)):
		total += int((ctx["nums"] as Dictionary)["mod"])
	total += int((s.get("upcast", {}) as Dictionary).get("temp_hp", 0)) * maxi(0, int(ctx["slot"]) - int(s.get("level", 0)))
	if t.creature.add_temp_hp(total, str(s["name"])):
		r.lines.append(e.log.add("heal", "%s gains %d Temporary Hit Points (%s)" % [t.name(), total, s["name"]], t.id, [text]))
	else:
		r.lines.append(e.log.add("info", "%s keeps its %d Temporary Hit Points (they don't stack)" % [t.name(), t.creature.temp_hp], t.id))


## Damage later (Melf's Acid Arrow: at the end of the target's next turn), with its own upcast dice.
func _delayed_damage(ctx: Dictionary, t: Combatant, params: Dictionary) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var e := enc()
	var fx := Effect.new("%s (lingering)" % s["name"], &"spell", str(s["id"]))
	fx.caster_id = c.id
	fx.stack_key = "spell:%s:later" % s["id"]
	fx.ends = Effect.Ends.END_OF_TURN
	fx.turn_owner_id = t.id
	fx.skip_turn_ends = e.own_turn_skip(t)
	fx.modifiers.append(Modifier.of("flag", {"value": "lingering_damage"}, str(s["name"]), &"spell"))
	var part := {"dice": str(params.get("dice", "2d4")), "type": str(params.get("type", "acid")), "upcast": str(params.get("upcast", ""))}
	fx.data["on_end"] = {"kind": "delayed_damage", "target": t.id, "caster": c.id, "spell": str(s["id"]), "slot": int(ctx["slot"]), "part": part}
	# Only what the later roll needs, and the creatures by id: a copy of the whole context could hold the target
	# (a queued push) and keep it alive through this very effect.
	var caster_id := c.id
	var slot := int(ctx["slot"])
	var spell_id := str(s["id"])
	var weak_t: WeakRef = weakref(t)
	fx.on_end = func() -> void:
		var tt := weak_t.get_ref() as Combatant
		var ee := enc()
		if tt == null or ee == null or not tt.is_alive() or ee.state != Encounter.State.ACTIVE:
			return
		var cc := ee.get_c(caster_id)
		if cc == null:
			return
		var later := {"c": cc, "s": _comp().spell_data(spell_id), "slot": slot, "nums": {}, "opts": {}}
		var rolled := roll_damage_parts(later, [part], false, tt)
		ee.deal_damage(cc, tt, [{"amount": int(rolled["total"]), "type": str(rolled["type"]), "spell": true}], false,
			str(s["name"]), [str(rolled["text"])])
	t.creature.add_effect(fx)


## Preserve the casting class on damage from both immediate and sustained spell recipes.
func deal_spell_damage(ctx: Dictionary, target: Combatant, parts: Array, critical: bool, label: String,
		details: Array = [], log_it: bool = true) -> DamageResult:
	var typed := parts.duplicate(true)
	for raw: Variant in typed:
		var p := raw as Dictionary
		p["spell_class"] = str((ctx.get("nums", {}) as Dictionary).get("class_id", ""))
		p["spell"] = true
	var caster := ctx["c"] as Combatant
	var dr := enc().deal_damage(caster, target, typed, critical, label, details, log_it)
	if bool((ctx.get("s", {}) as Dictionary).get("drain", false)) and dr.final > 0:
		var healed := caster.creature.heal(dr.final / 2, label)
		if healed > 0:
			enc().log.add("heal", "%s drains %d Hit Points" % [caster.name(), healed], caster.id)
			enc().events.append({"type": "heal", "id": caster.id, "amount": healed})
	return dr
