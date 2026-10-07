class_name FaerunGeneralFeats
extends FaerunCommon
## Heroes of Faerûn's general feats in a fight (FaerunFeatures): Fairy Trickster, Spell Subterfuge, Purple Dragon
## Commandant, Lordly Resolve, Order's Resilience, Street Justice, Zhentarim Tactics and the like, with their turn,
## d20 and queued-reaction hooks.


func _flustering_strike(c: Combatant, t: Combatant) -> void:
	var fr := faerun()
	var e := enc()
	_ch(c).spend_resource("flustering_strike")
	c.remove_meta("flustering_armed")
	var sv := t.creature.roll_save(e.dice, &"wis", fr.origin._feat_dc(c, "fairy_trickster"), [], [], "Wisdom save vs Flustering Strike (%s)" % t.name())
	if sv.success:
		_log("info", "%s keeps its composure (Flustering Strike)" % t.name(), t, [sv.describe()])
		return
	var fx := Effect.new("Flustered", &"feature", "flustering_strike").with_modifier("disadvantage", {"on": "save:all"})
	fx.caster_id = c.id
	fx.ends = Effect.Ends.END_OF_TURN
	fx.turn_owner_id = c.id
	fx.skip_turn_ends = e.own_turn_skip(c)
	if t.creature.add_effect(fx):
		_log("condition", "%s is flustered: Disadvantage on saves (Flustering Strike)" % t.name(), t, [sv.describe()])


func _shrouding_spells(c: Combatant) -> CombatResult:
	var e := enc()
	if str(c.get_meta("shrouding_window", "")) != _turn_key() or _ch(c).resource_left("shrouding_spells") <= 0:
		return CombatResult.fail("Cast a spell with an action and a slot first")
	var why := e._bonus_check(c)
	if why != "":
		return CombatResult.fail(why)
	_ch(c).spend_resource("shrouding_spells")
	c.remove_meta("shrouding_window")
	c.bonus_available = false
	c.movement_left += c.speed()
	_log("info", "%s wraps itself in its spell's afterglow: Dash (Shrouding Spells)" % c.name(), c)
	var spotter := e.hide_blocker(c)
	if spotter != "":
		_log("info", "%s can't hide here (%s)" % [c.name(), spotter], c)
		return CombatResult.new()
	var t := c.creature.roll_check(e.dice, &"stealth", 15)
	if t.success:
		c.hidden = true
		c.stealth_total = t.total
		c.creature.add_condition(&"invisible", "Hidden")
		_log("info", "%s hides (Stealth %d)" % [c.name(), t.total], c, [t.describe()])
	else:
		_log("info", "%s fails to hide (Stealth %d vs DC 15)" % [c.name(), t.total], c, [t.describe()])
	return CombatResult.new()


## Sneaky Casting: a hidden caster stays hidden through a Verbal spell this turn; the end of its turn checks cover.
func sneaky_casting(c: Combatant) -> bool:
	if not feat(c, "spell_subterfuge"):
		return false
	c.set_meta("sneaky_cast_turn", _turn_key())
	return true


func turn_end(c: Combatant) -> void:
	var fr := faerun()
	if c.hidden and str(c.get_meta("sneaky_cast_turn", "")) == _turn_key():
		enc()._check_still_hidden(c)
	fr.spell_code._transfix_turn_end(c)
	fr.familiars._otherworldly_return(c)


func _commandant_rally(c: Combatant, t: Combatant) -> CombatResult:
	var fr := faerun()
	var e := enc()
	if t == null or not c.allied_with(t) or e.distance(c, t) > 30 or not e.can_see(c, t):
		return CombatResult.fail("Choose an ally you can see within 30 ft")
	var why := e._bonus_check(c)
	if why != "":
		return CombatResult.fail(why)
	if _ch(c).resource_left("commandant_rally") <= 0:
		return CombatResult.fail("None left")
	_ch(c).spend_resource("commandant_rally")
	c.bonus_available = false
	var amount := int(e.dice.roll_expr("2d6", "Rallying Command")["total"]) + fr.origin._increased_mod(c, "purple_dragon_commandant")
	if t.creature.add_temp_hp(maxi(1, amount), "Rallying Command"):
		_log("heal", "%s rallies %s: %d Temporary Hit Points" % [c.name(), t.name(), maxi(1, amount)], c)
	else:
		_log("info", "%s rallies %s, who already has as many Temporary Hit Points" % [c.name(), t.name()], c)
	return CombatResult.new()


func _lordly_resolve(c: Combatant, picked: Array[Combatant]) -> CombatResult:
	var e := enc()
	if picked.is_empty() or picked.size() > 3:
		return CombatResult.fail("Choose up to three creatures within 60 ft who can see you")
	for t in picked:
		if e.distance(c, t) > 60 or not e.can_see(t, c):
			return CombatResult.fail("%s must be within 60 ft and see you" % t.name())
	var why := e._bonus_check(c)
	if why != "":
		return CombatResult.fail(why)
	if _ch(c).resource_left("lordly_resolve") <= 0:
		return CombatResult.fail("None left")
	_ch(c).spend_resource("lordly_resolve")
	c.bonus_available = false
	_log("info", "%s steadies the line (Lordly Resolve)" % c.name(), c)
	for t in picked:
		if t.creature.has_condition(&"prone") and e.spells.can_react(t) and t.speed() > 0:
			t.reaction_available = false
			t.creature.remove_condition(&"prone")
			_log("move", "%s gets back on its feet (Lordly Resolve)" % t.name(), t)
		var fx := Effect.new("Lordly Resolve", &"feature", "lordly_resolve").with_modifier("condition_immunity", {"value": "charmed"}) \
			.with_modifier("condition_immunity", {"value": "frightened"}).with_modifier("flag", {"value": "no_possession"}) \
			.with_modifier("advantage", {"on": ["save_vs:charmed", "save_vs:frightened"]})
		fx.caster_id = c.id
		fx.lasting({"kind": "minutes", "amount": 1})
		fx.turn_owner_id = c.id
		fx.data["ends_if_caster_incapacitated"] = true
		t.creature.add_effect(fx)
	return CombatResult.new()


## Lordly Resolve ends when its giver is Incapacitated; checked as each turn starts. Negative Energy Flood's dead rise
## as their killer's turn starts.
func turn_start(c: Combatant) -> void:
	var fr := faerun()
	var e := enc()
	fr.boons._sun_turn(c)
	fr.boons._terror_turn(c)
	for z: Dictionary in fr._rising.duplicate():
		if str(z["caster"]) == c.id:
			fr._rising.erase(z)
			fr.spell_code._raise_zombie(c, z)
	for t in e.combatants:
		for fx: Effect in t.creature.effects.duplicate():
			if not bool(fx.data.get("ends_if_caster_incapacitated", false)):
				continue
			var giver := e.get_c(fx.caster_id)
			if giver == null or not giver.can_act():
				t.creature.remove_effect(fx)


## Harper Teamwork: a holder's successful save ends its Frightened or Paralyzed; the same ends on an ally.
func after_save_ended(c: Combatant, fx: Effect) -> void:
	var e := enc()
	if not feat(c, "harper_teamwork"):
		return
	for cond: StringName in [&"frightened", &"paralyzed"]:
		if not cond in fx.conditions:
			continue
		for a in e.allies_of(c):
			if a == c or e.distance(c, a) > 30 or not e.can_see(c, a) or not a.creature.has_condition(cond):
				continue
			e.spells.cure(a, cond)
			_log("heal", "%s's courage frees %s: no longer %s (Harper Teamwork)" % [c.name(), a.name(), String(cond).capitalize()], c)
			e.events.append({"type": "condition", "id": a.id})
			return


## Faerie Trod Trotter: after Disengage on its own turn, no extra cost for Difficult Terrain until the turn ends.
func after_disengage(c: Combatant) -> void:
	if not feat(c, "fairy_trickster"):
		return
	var fx := Effect.new("Faerie Trod Trotter", &"feature", "faerie_trod_trotter").with_modifier("flag", {"value": "ignore_difficult_terrain"})
	fx.ends = Effect.Ends.END_OF_TURN
	fx.turn_owner_id = c.id
	c.creature.add_effect(fx)


## Divination Adept (Automatic only: a roll can't wait for a choice): Disadvantage on an enemy's save against the
## holder's own spell. Order's Resilience: Advantage on Strength saves beside an ally.
func before_d20(c: Combatant, kind: D20Test.Kind, keys: Array[String]) -> Dictionary:
	var fr := faerun()
	var e := enc()
	var out := {}
	# Mage Breaker: the Concentration save after its hit has Disadvantage.
	if kind == D20Test.Kind.SAVING_THROW and "concentration" in keys and c.has_meta("mage_broken"):
		out["disadvantage"] = ["Mage Breaker"]
	if kind == D20Test.Kind.ABILITY_CHECK and fr.familiars._helpful_friend(c, keys):
		out["advantage"] = ["Helpful Friend"]
	if kind != D20Test.Kind.SAVING_THROW:
		return out
	for h in e.combatants:
		var hc := _ch(h)
		if hc == null or not feat(h, "divination_adept") or not ("save_vs:spell:" + h.id) in keys or not h.hostile_to(c):
			continue
		if str(h.reaction_rules.get("divination_adept_benefit", "never")) != "auto" or hc.resource_left("divination_adept") <= 0:
			continue
		if not e.spells.can_react(h) or e.distance(h, c) > 60 or not e.can_see(h, c):
			continue
		hc.spend_resource("divination_adept")
		h.reaction_available = false
		_log("reaction", "%s foresees %s faltering (Divination Adept)" % [h.name(), c.name()], h)
		out["disadvantage"] = ["Divination Adept"]
		break
	if "save:str" in keys and c.can_act():
		for h2 in e.combatants:
			if not feat(h2, "orders_resilience") or not h2.can_act() or not h2.allied_with(c):
				continue
			var partner := h2 != c and e.distance(h2, c) <= 5
			if h2 == c:
				partner = e.allies_of(c).any(func(a: Combatant) -> bool: return a != c and a.can_act() and e.distance(a, c) <= 5)
			if partner:
				out["advantage"] = ["Order's Resilience"]
				break
	return out


## Undead Thralls (Necromancer 6): Undead a necromancer controls add its Intelligence modifier Necrotic damage
## to their hits while within 60 ft of it.
func hit_dice(c: Combatant, _target: Combatant, option: Dictionary = {}) -> Array[Dictionary]:
	var fr := faerun()
	var out: Array[Dictionary] = []
	if option.has("profile"):
		out.append_array(fr.boons._bloodshed_dice(c, str((option["profile"] as WeaponProfile).damage_type)))
	if c.creature.creature_type != &"undead" or not c.has_meta("summoner"):
		return out
	var e := enc()
	var master := e.get_c(str(c.get_meta("summoner")))
	if master == null or not CombatFeatures.has_feature(master, "undead_thralls") or e.distance(master, c) > 60:
		return out
	out.append({"dice": str(maxi(1, master.creature.ability_mod(&"int"))), "type": "necrotic", "label": "Undead Thralls"})
	return out


## Street Justice's Headlock: allies have Advantage against a creature the holder is grappling.
func attack_advantage(c: Combatant, target: Combatant) -> Array[String]:
	var out: Array[String] = []
	var e := enc()
	# Strike Fear (Scion of the Three): Advantage against a creature it Terrified.
	if target != null and target.creature.has_flag("terrified_by:%s" % c.id) and target.creature.has_condition(&"frightened"):
		out.append("Terrified")
	if c.creature.has_flag("bloodshed_advantage"):
		out.append("Boon of Bloodshed")
	# `grapples` maps a grappled creature to its grappler.
	if target == null or not e.grapples.has(target.id):
		return out
	var grappler := e.get_c(str(e.grapples[target.id]))
	if grappler != null and grappler != c and feat(grappler, "street_justice") and grappler.allied_with(c):
		out.append("Headlock (%s)" % grappler.name())
	return out


## Zhentarim Tactics: a melee hit from a creature within 5 ft earns an Opportunity Attack back. Bloodthirst (Scion
## of the Three): an enemy left Bloodied draws the Scion to it.
func queue_damage_reactions(source: Combatant, target: Combatant) -> void:
	var fr := faerun()
	var e := enc()
	# Harvest Undead (Necromancer 10): left Bloodied, the necromancer can burn one of its Undead to heal.
	if target != null and CombatFeatures.has_feature(target, "harvest_undead") and target.creature.hp > 0 and target.creature.is_bloodied() \
			and e.spells.can_react(target) and fr.schools._harvestable(target) != null:
		e.reaction_queue.append({"kind": "fr_harvest_undead", "reactor": target.id, "trigger": source.id})
	if target != null and target.is_alive() and target.creature.hp > 0 and target.creature.is_bloodied():
		for h in e.combatants:
			var hc := _ch(h)
			if hc == null or not CombatFeatures.has_feature(h, "scion_bloodthirst") or not h.hostile_to(target) or hc.resource_left("scion_bloodthirst") <= 0:
				continue
			if not e.spells.can_react(h) or e.distance(h, target) > 30 or not e.can_see(h, target):
				continue
			e.reaction_queue.append({"kind": "fr_bloodthirst", "reactor": h.id, "trigger": target.id})
	if source == null or target == null or not feat(target, "zhentarim_tactics") or not bool(e.hit_context.get("melee", false)):
		return
	if str(e.hit_context.get("attacker", "")) != source.id or e.distance(target, source) > 5 or not e.spells.can_react(target):
		return
	if e.best_melee_option(target, source).is_empty():
		return
	e.reaction_queue.append({"kind": "fr_zhentarim_tactics", "reactor": target.id, "trigger": source.id})


func queued_ok(q: Dictionary, reactor: Combatant) -> bool:
	var fr := faerun()
	var e := enc()
	if str(q["kind"]) == "fr_harvest_undead":
		return e.spells.can_react(reactor) and reactor.creature.hp > 0 and fr.schools._harvestable(reactor) != null
	if str(q["kind"]) == "fr_bloodthirst":
		var bt := e.get_c(str(q["trigger"]))
		return e.spells.can_react(reactor) and bt != null and bt.is_alive() and bt.creature.hp > 0 and _ch(reactor).resource_left("scion_bloodthirst") > 0
	if str(q["kind"]) == "fr_zhentarim_tactics":
		var t := e.get_c(str(q["trigger"]))
		return e.spells.can_react(reactor) and t != null and t.is_alive() and e.distance(reactor, t) <= 5
	return false


func fire_queued(q: Dictionary, reactor: Combatant, trigger: Combatant) -> CombatResult:
	var fr := faerun()
	if str(q["kind"]) == "fr_bloodthirst":
		return fr.subclasses._bloodthirst(reactor, trigger)
	if str(q["kind"]) == "fr_harvest_undead":
		return fr.schools._harvest_undead(reactor)
	if str(q["kind"]) == "fr_zhentarim_tactics":
		return enc()._opportunity_attack(reactor, trigger)
	return CombatResult.new()


func queued_text(kind: String) -> Array:
	if kind == "fr_harvest_undead":
		return ["Reaction: Harvest Undead?", "%s left %s Bloodied. Drain one of your Undead to heal?", "Reaction"]
	if kind == "fr_bloodthirst":
		return ["Reaction: Bloodthirst?", "%s is Bloodied. %s can teleport beside it and strike?", "Reaction and a use of Bloodthirst"]
	if kind == "fr_zhentarim_tactics":
		return ["Reaction: Zhentarim Tactics?", "%s hit %s in melee. Answer with an Opportunity Attack?", "Reaction"]
	return ["Reaction?", "%s / %s", "Reaction"]
