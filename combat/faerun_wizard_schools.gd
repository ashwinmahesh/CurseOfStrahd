class_name FaerunWizardSchools
extends FaerunCommon
## The Enchanter, Necromancer and Transmuter wizards in a fight (FaerunFeatures).


## Instinctive Charm: a hit on the Enchanter can be turned on someone else beside the attacker.
func after_hit_target(st: Dictionary, miss: Callable, out: Array) -> void:
	var e := enc()
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var tc := _ch(target)
	if tc == null or not CombatFeatures.has_feature(target, "instinctive_charm") or tc.resource_left("instinctive_charm") <= 0:
		return
	if not e.spells.can_react(target) or e.distance(target, c) > 30 or not e.can_see(target, c) or c == target:
		return
	var reach := c.reach_ft()
	var other: Combatant = null
	for x in e.living():
		if x == c or x == target or e.distance(c, x) > maxi(reach, 5) or x.is_down():
			continue
		if other == null or e.distance(c, x) < e.distance(c, other):
			other = x
	if other == null:
		return
	var t := st["t"] as D20Test
	var redirect := other
	out.append({"kind": "instinctive_charm", "reactor": target, "trigger": c.id, "title": "Reaction: Instinctive Charm?",
		"text": "%s hits %s. %s makes a Wisdom save; on a failure the attack turns on %s instead." % [c.name(), target.name(), c.name(), redirect.name()],
		"cost": "Reaction and a use of Instinctive Charm",
		"still": func() -> bool: return tc.resource_left("instinctive_charm") > 0 and e.spells.can_react(target),
		"use": func() -> void:
			tc.spend_resource("instinctive_charm")
			target.reaction_available = false
			var dc := e.class_features._spell_dc(target, "wizard")
			if not e.class_features._save(c, &"wis", dc, "Instinctive Charm", "charmed"):
				st["charm_redirect"] = redirect.id
				c.set_meta("portent_next", t.kept)
				e.cleave_queue.append({"c": c, "target": redirect, "option": st["option"], "opts": {"redirected": true}, "redirected": true})
				_log("reaction", "%s's charm turns the blow toward %s" % [target.name(), redirect.name()], target),
		"stop_if": func() -> bool: return st.has("charm_redirect"),
		"stop": miss})


func _undead_vitality(c: Combatant, ch: Character, slot: int) -> void:
	var e := enc()
	var best: Combatant = null
	for u in e.living():
		if u.creature.creature_type != &"undead" or not (u == c or c.allied_with(u)) or u.creature.hp >= u.creature.max_hp():
			continue
		if e.distance(c, u) > 60 or not e.can_see(c, u):
			continue
		if best == null or u.creature.hp * best.creature.max_hp() < best.creature.hp * u.creature.max_hp():
			best = u
	if best == null:
		return
	var got := best.creature.heal(slot + ch.class_level_of("wizard"), "Undead Vitality")
	_log("heal", "Necrotic energy knits %s: +%d Hit Points (Undead Vitality)" % [best.name(), got], c)
	e.events.append({"type": "heal", "id": best.id, "amount": got})


## A summoned creature: a Necromancy Familiar's form, and Undead Thralls' extra Hit Points.
func after_summon(ctx: Dictionary, m: Creature) -> void:
	var fr := faerun()
	var c := ctx["c"] as Combatant
	var ch := _ch(c)
	if ch == null:
		return
	var s := ctx["s"] as Dictionary
	if str(s.get("id", "")) == "find_familiar":
		fr.familiars._familiar_feats(c, ch, m)
		ch.familiar = "here"
	if str(s.get("id", "")) == "find_familiar" and CombatFeatures.has_feature(c, "necromancy_familiar") and m is Monster:
		m.creature_type = &"undead"
		(m as Monster).data["chain"] = true
		(m as Monster).data["familiar"] = true
	if CombatFeatures.has_feature(c, "undead_thralls") and m.creature_type == &"undead" \
			and (str(s.get("school", "")) == "necromancy" or str(s.get("id", "")) == "find_familiar"):
		var bonus := maxi(0, c.creature.ability_mod(&"int")) + ch.class_level_of("wizard") / 2
		if bonus > 0:
			var fx := Effect.new("Undead Thralls", &"feature", "undead_thralls").with_modifier("hp_max", {"value": bonus})
			fx.ends = Effect.Ends.NEVER
			m.add_effect(fx)
			m.hp += bonus


func _deaths_master(c: Combatant) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	var why := e._bonus_check(c)
	if why != "":
		return CombatResult.fail(why)
	if ch.resource_left("deaths_master") <= 0:
		return CombatResult.fail("None left")
	ch.spend_resource("deaths_master")
	c.bonus_available = false
	var lvl := ch.class_level_of("wizard")
	for sid: Variant in e.spells.summoned.get(c.id, []):
		var u := e.get_c(str(sid))
		if u != null and u.is_alive() and u.creature.creature_type == &"undead" and e.distance(c, u) <= 60:
			u.creature.add_temp_hp(lvl, "Death's Master")
	_log("heal", "%s pours death's power into its servants (Death's Master)" % c.name(), c)
	return CombatResult.new()


## Death's Master: an Undead dropping to 0 can explode (its own on its own; another's only on Automatic, for a
## Reaction and a level 5+ slot). Harvest Undead is handled when the necromancer is hurt.
func on_death(source: Combatant, dead: Combatant) -> void:
	var fr := faerun()
	var e := enc()
	fr.familiars._familiar_lost(dead)
	fr.boons._boons_on_death(source, dead)
	for h in e.combatants:
		var sun := fr.boons._sun_of(h)
		if sun != null and h == dead:
			sun.ended = true
			e.spells.zones.prune()
	if dead.creature.creature_type != &"undead":
		return
	for h in e.combatants:
		var hc := _ch(h)
		if hc == null or not CombatFeatures.has_feature(h, "deaths_master") or not h.is_alive() or not e.can_see_space(h, dead.cell):
			continue
		var mine := str(dead.get_meta("summoner", "")) == h.id
		if mine:
			if not allowed(h, "deaths_master"):
				continue
		else:
			if not CombatFeatures.has_feature(h, "deaths_master_explode") or str(h.reaction_rules.get("deaths_master_explode", "never")) != "auto" \
					or not e.spells.can_react(h) or e.spells._lowest_slot(hc, 5) == 0:
				continue
			h.reaction_available = false
			hc.expend_slot(e.spells._lowest_slot(hc, 5))
		_explode_undead(h, dead)
		return


func _explode_undead(h: Combatant, dead: Combatant) -> void:
	var e := enc()
	var hd := 1
	if dead.creature is Monster:
		hd = int(DiceRoller.parse_expr(str((((dead.creature as Monster).data.get("hp", {}) as Dictionary).get("dice", "1d8"))))["count"])
	var n := maxi(1, int(ceil(hd / 2.0)))
	var rolled := e._roll_damage_dice("%dd6" % n, false, 0, "Death's Master")
	var dc := e.class_features._spell_dc(h, "wizard")
	_log("spell", "%s bursts in a wave of necrotic force (Death's Master)" % dead.name(), h)
	for t in e.living():
		if t == dead or e.distance(dead, t) > 10:
			continue
		var ok := e.class_features._save(t, &"dex", dc, "Death's Master")
		var amt := int(rolled["total"]) / 2 if ok else int(rolled["total"])
		e.deal_damage(h, t, [{"amount": amt, "type": "necrotic", "feature_class": "wizard"}], false, "Death's Master", [str(rolled["text"])])
		if not ok:
			var fx := Effect.new("Shaken by death", &"feature", "deaths_master").with_modifier("flag", {"value": "no_reactions"})
			fx.ends = Effect.Ends.START_OF_TURN
			fx.turn_owner_id = t.id
			t.creature.add_effect(fx)


func _wondrous_alteration(c: Combatant) -> void:
	for fx: Effect in c.creature.effects:
		if fx.source_id != "alter_self":
			continue
		for m in fx.modifiers:
			if m.stat == &"weapon_override":
				m.data["die"] = "2d6"
		fx.modifiers.append(Modifier.of("advantage", {"on": "concentration"}, "Wondrous Alteration", &"feature"))
		_log("info", "%s's natural weapons swell (Wondrous Alteration: 2d6)" % c.name(), c)
		return


func shape_shifter_keeps_mind(c: Combatant) -> bool:
	var ch := _ch(c)
	if ch == null or not CombatFeatures.has_feature(c, "shape_shifter") or ch.resource_left("shape_shifter") <= 0:
		return false
	ch.spend_resource("shape_shifter")
	_log("info", "%s keeps its mind through the change (Shape Shifter)" % c.name(), c)
	return true


func _master_transmuter(c: Combatant, mode: String, t: Combatant) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	if t == null or e.distance(c, t) > 5:
		return CombatResult.fail("Touch a creature within 5 ft")
	var why := e._action_check(c)
	if why != "":
		return CombatResult.fail(why)
	if ch.resource_left("master_transmuter") <= 0:
		return CombatResult.fail("None left")
	ch.spend_resource("master_transmuter")
	e.spend_action(c)
	c.magic_action_used = true
	if mode == "panacea":
		var got := t.creature.heal(t.creature.max_hp() / 2, "Panacea")
		for cond: StringName in [&"poisoned", &"petrified"]:
			if t.creature.has_condition(cond):
				e.spells.cure(t, cond)
		for fx: Effect in t.creature.effects.duplicate():
			if fx.source_id in ["bestow_curse", "hex"] or fx.name.to_lower().contains("curse"):
				t.creature.remove_effect(fx)
		_log("heal", "%s's stone remakes %s: +%d Hit Points (Panacea)" % [c.name(), t.name(), got], c)
		e.events.append({"type": "heal", "id": t.id, "amount": got})
	else:
		t.creature.exhaustion = 0
		_log("heal", "%s's stone washes the weariness from %s (Restore Youth)" % [c.name(), t.name()], c)
	return CombatResult.new()


## The Undead the necromancer controls and can see with the fewest Hit Points (Harvest Undead's fuel).
func _harvestable(c: Combatant) -> Combatant:
	var e := enc()
	var best: Combatant = null
	for sid: Variant in e.spells.summoned.get(c.id, []):
		var u := e.get_c(str(sid))
		if u == null or not u.is_alive() or u.creature.hp <= 0 or u.creature.creature_type != &"undead" or not e.can_see(c, u):
			continue
		if best == null or u.creature.hp < best.creature.hp:
			best = u
	return best


func _harvest_undead(c: Combatant) -> CombatResult:
	var e := enc()
	var u := _harvestable(c)
	if u == null or not e.spells.can_react(c):
		return CombatResult.new()
	c.reaction_available = false
	e.deal_damage(c, u, [{"amount": u.creature.hp + u.creature.temp_hp, "type": "necrotic", "ignore_resistance": true}], false, "Harvest Undead")
	var got := c.creature.heal(_ch(c).class_level_of("wizard"), "Harvest Undead")
	_log("heal", "%s drains %s to mend itself: +%d Hit Points (Harvest Undead)" % [c.name(), u.name(), got], c)
	e.events.append({"type": "heal", "id": c.id, "amount": got})
	return CombatResult.new()
