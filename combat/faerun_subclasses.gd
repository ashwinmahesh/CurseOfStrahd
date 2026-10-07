class_name FaerunSubclasses
extends FaerunCommon
## Heroes of Faerûn's subclasses in a fight (FaerunFeatures): their hotbar actions, the College of the Moon, Banneret,
## Oath of the Noble Genies, Scion of the Three, Spellfire Sorcery and the Arcana Domain, and attacks against their
## members (Elemental Rebuke, Crown of Spellfire).


## The first pick of a feature's choice (the key ends with the feature id).
static func _pick(ch: Character, feature_id: String) -> String:
	for cd in ch.choice_defs:
		if cd.key.ends_with(feature_id) and not cd.picks.is_empty():
			return cd.picks[0]
	return ""


func genie_element(p: Combatant) -> String:
	if p.has_meta("genie_element"):
		return str(p.get_meta("genie_element"))
	var ch := _ch(p)
	var pick := _pick(ch, "aura_of_elemental_shielding") if ch != null else ""
	return pick if pick != "" else "fire"


func before_action(c: Combatant) -> void:
	var ch := _ch(c)
	if ch != null:
		c.set_meta("sp_before", ch.resource_left("sorcery_points"))


func after_action(c: Combatant, action: Dictionary, targets: Array = []) -> void:
	var ch := _ch(c)
	if ch == null:
		return
	var key := ActionCatalog.ability_key(action)
	var t: Combatant = targets[0] as Combatant if not targets.is_empty() and targets[0] is Combatant else null
	match key:
		"bardic_inspiration":
			if CombatFeatures.has_feature(c, "moons_inspiration"):
				c.set_meta("eclipse_window", _turn_key())
				if t != null and CombatFeatures.has_feature(c, "eventides_splendor"):
					c.set_meta("eventide_window", _turn_key())
					c.set_meta("eclipse_ally", t.id)
		"second_wind":
			_group_recovery(c)
		"action_surge":
			_rallying_surge(c)
	# Spellfire Burst: Sorcery Points spent in a Magic action or Bonus Action on its own turn.
	var cost := str(action.get("cost", ""))
	if CombatFeatures.has_feature(c, "spellfire_burst") and cost in ["action", "bonus"] and enc().current() == c \
			and ch.resource_left("sorcery_points") < int(c.get_meta("sp_before", 0)) and str(c.get_meta("burst_used", "")) != _turn_key():
		c.set_meta("burst_window", _turn_key())


func _subclass_list(c: Combatant, ch: Character, out: Array[Dictionary], tw: String) -> void:
	var e := enc()
	if str(c.get_meta("eclipse_window", "")) == _turn_key():
		out.append(_entry("inspired_eclipse", "Inspired Eclipse", "teleport 30 ft · Invisible", "free", tw, "point",
			"You just gave Bardic Inspiration: teleport up to 30 ft to a space you can see and turn Invisible until your next turn.", 30))
	if str(c.get_meta("eventide_window", "")) == _turn_key() and c.has_meta("eclipse_ally"):
		var ally := e.get_c(str(c.get_meta("eclipse_ally")))
		if ally != null:
			out.append(_entry("eventide_step", "Eventide: move %s" % ally.name(), "Reaction · teleport 30 ft", "free",
				_first(tw, "" if e.spells.can_react(ally) else "%s has no Reaction" % ally.name()), "point",
				"The creature you inspired turns Invisible and spends its Reaction to teleport up to 30 ft to the space you pick.", 60))
	if CombatFeatures.has_feature(c, "elemental_smite") and ch.resource_left("paladin_channel_divinity") > 0:
		for g: String in ["dao", "djinni", "efreeti", "marid"]:
			var armed := str(c.get_meta("genie_smite", "")) == g
			out.append(_entry("genie_smite:" + g, "Elemental Smite: %s%s" % [g.capitalize(), " (armed)" if armed else ""],
				{"dao": "grapple and restrain", "djinni": "teleport and resist", "efreeti": "2d4 Fire to two", "marid": "Str save: push and Prone"}[g],
				"free", tw, "none", "Arm it: right after your next Divine Smite, spend Channel Divinity for this genie's gift."))
	if str(c.get_meta("djinni_step", "")) == _turn_key():
		out.append(_entry("djinni_step", "Djinni's Step", "teleport 30 ft", "free", tw, "point", "The djinni's wind carries you up to 30 ft.", 30))
	if CombatFeatures.has_feature(c, "aura_of_elemental_shielding"):
		out.append(_entry("shift_element", "Elemental Shielding: %s" % genie_element(c).capitalize(), "switch element", "free",
			_first(tw, "Only as your turn starts" if c.has_meta("element_shifted") and str(c.get_meta("element_shifted")) == _turn_key() else ""), "none",
			"Switch your aura's element (Acid, Cold, Fire, Lightning, Thunder in turn)."))
	if CombatFeatures.has_feature(c, "noble_scion"):
		if not c.creature.has_flag("noble_scion"):
			out.append(_entry("noble_scion", "Noble Scion", "fly 60 ft · 10 min", "bonus", _first(e._bonus_check(c), _res_why(c, "noble_scion")), "none",
				"Bonus Action: a genie's majesty for 10 minutes: fly 60 ft and turn failed D20 Tests in your aura into successes with your Reaction."))
		if ch.resource_left("noble_scion") <= 0 and ch.slots_left(5) > 0:
			out.append(_entry("noble_scion_restore", "Restore Noble Scion", "level 5 slot", "free", tw, "none", "Spend a level 5 spell slot to restore Noble Scion."))
	if str(c.get_meta("burst_window", "")) == _turn_key():
		var honed := CombatFeatures.has_feature(c, "honed_spellfire")
		out.append(_entry("burst_flames", "Spellfire Burst: Bolstering Flames", "1d4 + %d Temporary HP" % (c.creature.ability_mod(&"cha") + (ch.class_level_of("sorcerer") if honed else 0)), "free", tw, "creature",
			"Temporary Hit Points for you or a creature you can see within 30 ft.", 30))
		out.append(_entry("burst_fire", "Spellfire Burst: Radiant Fire", "%s Radiant" % ("1d8" if honed else "1d4"), "free", tw, "enemy",
			"Radiant damage to a creature you can see within 30 ft.", 30))
	if CombatFeatures.has_feature(c, "crown_of_spellfire"):
		if c.creature.has_flag("innate_sorcery") and not c.creature.has_flag("spellfire_crown"):
			out.append(_entry("crown_of_spellfire", "Crown of Spellfire", "fly 60 ft · spells half or none", "free", _first(tw, _res_why(c, "crown_of_spellfire")), "none",
				"Crown your Innate Sorcery with spellfire until it ends."))
		if ch.resource_left("crown_of_spellfire") <= 0 and ch.resource_left("sorcery_points") >= 5:
			out.append(_entry("crown_restore", "Restore Crown of Spellfire", "5 Sorcery Points", "free", tw, "none", "Spend 5 Sorcery Points to restore Crown of Spellfire."))
	if CombatFeatures.has_feature(c, "modify_magic") and ch.resource_left("channel_divinity") > 0:
		for m: String in ["ward", "unravel"]:
			var on := str(c.get_meta("modify_magic", "")) == m
			out.append(_entry("modify_magic:" + m, "Modify Magic: %s%s" % [m.capitalize(), " (armed)" if on else ""],
				"2d8 + %d Temporary HP" % ch.class_level_of("cleric") if m == "ward" else "−1d6 on the first save made", "free", tw, "none",
				"Arm it for your next spell: spend Channel Divinity when it takes effect."))
	# Necromancy Familiar: give up an attack for the familiar's Reaction strike (as a Pact of the Chain warlock does).
	if CombatFeatures.has_feature(c, "necromancy_familiar") and ch.class_level_of("warlock") <= 0 and e.class_features._familiar(c) != null:
		var fam := e.class_features._familiar(c)
		out.append({"id": "feat:cf:familiar_strike", "label": "Familiar Strike", "sub": "%s attacks" % fam.name(), "cost": "attack",
			"why": _first(e.class_features.e_attack_why(c), "" if e.spells.can_react(fam) else "The familiar's Reaction is used"),
			"targeting": "enemy", "help": "Give up one of your attacks: your familiar makes one attack with its Reaction.", "range": 120})
	if CombatFeatures.has_feature(c, "deaths_master"):
		out.append(_entry("deaths_master", "Death's Master", "%d Temporary HP to your Undead" % ch.class_level_of("wizard"), "bonus",
			_first(e._bonus_check(c), _res_why(c, "deaths_master")), "none",
			"Bonus Action: every Undead you created or summoned within 60 ft gains Temporary Hit Points equal to your Wizard level."))
	if CombatFeatures.has_feature(c, "master_transmuter"):
		for m: String in ["panacea", "restore_youth"]:
			out.append(_entry("master_transmuter:" + m, "Master Transmuter: %s" % ("Panacea" if m == "panacea" else "Restore Youth"),
				"half its Hit Points; cures curses, Poisoned, Petrified" if m == "panacea" else "removes all Exhaustion", "action",
				_first(e._action_check(c), _res_why(c, "master_transmuter")), "ally",
				"Magic action: touch a creature and spend your stone's power.", 5))
	if CombatFeatures.has_feature(c, "dispelling_recovery"):
		if str(c.get_meta("dispel_window", "")) == _turn_key() and ch.resource_left("dispelling_recovery") > 0:
			out.append(_entry("dispelling_recovery", "Dispelling Recovery", "Dispel Magic, no slot", "free", tw, "creature",
				"Your healing spell carries a Dispel Magic: end spells on a creature within 120 ft.", 120))
		if ch.resource_left("dispelling_recovery") <= 0 and ch.resource_left("channel_divinity") > 0:
			out.append(_entry("dispelling_restore", "Restore Dispelling Recovery", "Channel Divinity", "free", tw, "none", "Spend a use of Channel Divinity to restore Dispelling Recovery."))


func _subclass_perform(c: Combatant, id: String, t: Combatant, cell: Vector2i) -> CombatResult:
	var fr := faerun()
	var e := enc()
	var ch := _ch(c)
	if id.begins_with("genie_smite:"):
		var g := id.get_slice(":", 1)
		if str(c.get_meta("genie_smite", "")) == g:
			c.remove_meta("genie_smite")
		else:
			c.set_meta("genie_smite", g)
		return CombatResult.new()
	if id.begins_with("master_transmuter:"):
		return fr.schools._master_transmuter(c, id.get_slice(":", 1), t)
	if id.begins_with("modify_magic:"):
		var m := id.get_slice(":", 1)
		if str(c.get_meta("modify_magic", "")) == m:
			c.remove_meta("modify_magic")
		else:
			c.set_meta("modify_magic", m)
		return CombatResult.new()
	match id:
		"inspired_eclipse":
			if str(c.get_meta("eclipse_window", "")) != _turn_key():
				return CombatResult.fail("Give Bardic Inspiration first")
			if cell.x < 0 or not e.can_see_space(c, cell):
				return CombatResult.fail("Choose a space you can see within 30 ft")
			var r := e.feature_actions._teleport(c, cell, 30)
			if not r.ok:
				return r
			c.remove_meta("eclipse_window")
			_eclipse_veil(c, c)
			return r
		"eventide_step":
			var ally := e.get_c(str(c.get_meta("eclipse_ally", "")))
			if ally == null or not e.spells.can_react(ally):
				return CombatResult.fail("Not available")
			if cell.x < 0 or not e.can_see_space(ally, cell):
				return CombatResult.fail("Choose a space it can see within 30 ft")
			var r2 := e.feature_actions._teleport(ally, cell, 30)
			if not r2.ok:
				return r2
			ally.reaction_available = false
			c.remove_meta("eclipse_ally")
			c.remove_meta("eventide_window")
			_eclipse_veil(c, ally)
			return r2
		"djinni_step":
			if str(c.get_meta("djinni_step", "")) != _turn_key() or cell.x < 0 or not e.can_see_space(c, cell):
				return CombatResult.fail("Choose a space you can see within 30 ft")
			var r3 := e.feature_actions._teleport(c, cell, 30)
			if r3.ok:
				c.remove_meta("djinni_step")
			return r3
		"shift_element":
			var order := ["fire", "cold", "lightning", "thunder", "acid"]
			var next := str(order[(order.find(genie_element(c)) + 1) % order.size()])
			c.set_meta("genie_element", next)
			c.set_meta("element_shifted", _turn_key())
			for x in e.combatants:
				for fx: Effect in x.creature.effects.duplicate():
					if fx.stack_key == "aura:%s" % c.id:
						x.creature.remove_effect(fx)
			e.class_features.refresh_auras()
			_log("info", "%s's aura turns to %s" % [c.name(), next], c)
		"noble_scion":
			var why := e._bonus_check(c)
			if why != "":
				return CombatResult.fail(why)
			if ch.resource_left("noble_scion") <= 0:
				return CombatResult.fail("None left")
			ch.spend_resource("noble_scion")
			c.bonus_available = false
			var fx := Effect.new("Noble Scion", &"feature", "noble_scion").with_modifier("flag", {"value": "noble_scion"}) \
				.with_modifier("speed_set", {"kind": "fly", "value": 60})
			fx.lasting({"kind": "minutes", "amount": 10})
			fx.turn_owner_id = c.id
			c.creature.add_effect(fx)
			_log("info", "%s rises with a genie's majesty (Noble Scion)" % c.name(), c)
		"noble_scion_restore":
			if not ch.expend_slot(5):
				return CombatResult.fail("No level 5 slot")
			ch.restore_resource("noble_scion", 1)
		"burst_flames", "burst_fire":
			return _spellfire_burst(c, id, t)
		"crown_of_spellfire":
			if ch.resource_left("crown_of_spellfire") <= 0 or not c.creature.has_flag("innate_sorcery"):
				return CombatResult.fail("Not now")
			ch.spend_resource("crown_of_spellfire")
			var crown := Effect.new("Crown of Spellfire", &"feature", "crown_of_spellfire").with_modifier("flag", {"value": "spellfire_crown"}) \
				.with_modifier("speed_set", {"kind": "fly", "value": 60})
			for fx2: Effect in c.creature.effects:
				if fx2.source_id == "innate_sorcery":
					crown.ends = fx2.ends
					crown.rounds_left = fx2.rounds_left
					crown.turn_owner_id = fx2.turn_owner_id
			c.creature.add_effect(crown)
			_log("info", "A crown of spellfire blazes over %s" % c.name(), c)
		"crown_restore":
			if not ch.spend_resource("sorcery_points", 5):
				return CombatResult.fail("Not enough Sorcery Points")
			ch.restore_resource("crown_of_spellfire", 1)
		"dispelling_recovery":
			return _dispelling_recovery(c, t)
		"deaths_master":
			return fr.schools._deaths_master(c)
		"dispelling_restore":
			if not ch.spend_resource("channel_divinity"):
				return CombatResult.fail("No Channel Divinity left")
			ch.restore_resource("dispelling_recovery", 1)
		_:
			return CombatResult.fail("Not available")
	return CombatResult.new()


func _eclipse_veil(bard: Combatant, t: Combatant) -> void:
	var fx := Effect.new("Inspired Eclipse", &"feature", "inspired_eclipse").with_condition(&"invisible")
	fx.caster_id = bard.id
	fx.ends = Effect.Ends.START_OF_TURN
	fx.turn_owner_id = t.id
	fx.ends_on = ["attack_roll", "deal_damage", "cast_spell"]
	t.creature.add_effect(fx)
	_log("info", "%s fades into moonshadow (Invisible)" % t.name(), t)


## Lunar Vitality: once per turn, a Bardic Inspiration die (or 1d6 at level 14) more on a spell's healing, and
## +10 ft Speed for the healed creature.
func spell_healing(ctx: Dictionary, t: Combatant) -> int:
	var c := ctx["c"] as Combatant
	var ch := _ch(c)
	if ch == null or not CombatFeatures.has_feature(c, "moons_inspiration") or not allowed(c, "moons_inspiration"):
		return 0
	var free := CombatFeatures.has_feature(c, "eventides_splendor")
	if not free and ch.resource_left("bardic_inspiration") <= 0:
		return 0
	if not _once_per_turn(c, "lunar_vitality_turn"):
		return 0
	var die := 6 if free else ClassFeatures.bardic_die(c)
	if not free:
		ch.spend_resource("bardic_inspiration")
	var roll := enc().dice.roll_one(die, "Lunar Vitality")
	var fx := Effect.new("Lunar Vitality", &"feature", "lunar_vitality").with_modifier("speed", {"value": 10})
	fx.ends = Effect.Ends.END_OF_TURN
	fx.turn_owner_id = t.id
	fx.skip_turn_ends = enc().own_turn_skip(t)
	t.creature.add_effect(fx)
	_log("heal", "Moonlight swells the healing: +%d (Lunar Vitality)" % roll, c)
	return roll


## Blessing of Moonlight: each failed save against the blessed Moonbeam heals the most hurt ally within 60 ft.
func zone_failed_save(o: FieldObject, t: Combatant) -> void:
	var e := enc()
	var bard := e.get_c(o.caster_id)
	if o.spell_id == "moonbeam" and bard != null and bool(bard.get_meta("bless_moonbeam", false)):
		o.rules["blessed"] = true
	if not bool(o.rules.get("blessed", false)):
		return
	if bard == null:
		return
	var best: Combatant = null
	for a: Combatant in e.allies_of(bard) + [bard]:
		if a == t or not a.is_alive() or a.creature.hp >= a.creature.max_hp() or e.distance(bard, a) > 60 or not e.can_see(bard, a):
			continue
		if best == null or a.creature.hp * best.creature.max_hp() < best.creature.hp * a.creature.max_hp():
			best = a
	if best == null:
		return
	var got := best.creature.heal(int(e.heal_roll("2d4", best, "Blessing of Moonlight")["total"]), "Blessing of Moonlight")
	_log("heal", "Moonlight mends %s: +%d Hit Points (Blessing of Moonlight)" % [best.name(), got], bard)
	e.events.append({"type": "heal", "id": best.id, "amount": got})


func _rally_reach(c: Combatant) -> int:
	return 60 if CombatFeatures.has_feature(c, "banneret_bolstered_rally") else 30


func _group_recovery(c: Combatant) -> void:
	var fr := faerun()
	var e := enc()
	var ch := _ch(c)
	if not CombatFeatures.has_feature(c, "banneret_group_recovery") or ch.resource_left("banneret_group_recovery") <= 0 or not allowed(c, "banneret_group_recovery"):
		return
	var hurt: Array[Combatant] = []
	for a in e.allies_of(c):
		if a != c and a.is_alive() and a.creature.hp < a.creature.max_hp() and e.distance(c, a) <= _rally_reach(c):
			hurt.append(a)
	if hurt.is_empty():
		return
	hurt.sort_custom(func(x: Combatant, y: Combatant) -> bool: return x.creature.hp * y.creature.max_hp() < y.creature.hp * x.creature.max_hp())
	ch.spend_resource("banneret_group_recovery")
	var n := maxi(1, c.creature.ability_mod(&"cha"))
	for a: Combatant in hurt.slice(0, n):
		var got := a.creature.heal(maxi(e.dice.roll_one(4, "Group Recovery"), fr.healing_floor(a)) + ch.class_level_of("fighter"), "Group Recovery")
		_log("heal", "%s rallies %s: +%d Hit Points (Group Recovery)" % [c.name(), a.name(), got], c)
		e.events.append({"type": "heal", "id": a.id, "amount": got})
		if CombatFeatures.has_feature(c, "banneret_team_tactics"):
			var fx := Effect.new("Team Tactics", &"feature", "banneret_team_tactics").with_modifier("advantage", {"on": ["attack", "save:all", "check:all"]})
			fx.caster_id = c.id
			fx.ends = Effect.Ends.START_OF_TURN
			fx.turn_owner_id = c.id
			a.creature.add_effect(fx)


func _rallying_surge(c: Combatant) -> void:
	var e := enc()
	if not CombatFeatures.has_feature(c, "banneret_rallying_surge") or not allowed(c, "banneret_rallying_surge"):
		return
	var n := maxi(1, c.creature.ability_mod(&"cha"))
	var done := 0
	for a in e.allies_of(c):
		if done >= n:
			break
		if a == c or not a.is_alive() or not a.can_act() or e.distance(c, a) > _rally_reach(c) or not e.spells.can_react(a):
			continue
		var foe: Combatant = null
		for h in e.hostiles_of(a):
			if h.is_alive() and not h.is_down() and not e.best_melee_option(a, h).is_empty() and (foe == null or e.distance(a, h) < e.distance(a, foe)):
				foe = h
		if foe == null:
			continue
		done += 1
		_log("reaction", "%s answers %s's rallying surge" % [a.name(), c.name()], a)
		e._opportunity_attack(a, foe)


## Shared Resilience (Banneret 15): a Reaction and a use of Indomitable let an ally within 60 ft it can see reroll a
## failed save with the Fighter's level added. It asks where the save can pause (its class-tab rule otherwise).
func shared_resilience_offers(c: Combatant, t: D20Test, out: Array) -> void:
	var e := enc()
	if t.kind != D20Test.Kind.SAVING_THROW or t.target <= 0:
		return
	for h in e.combatants:
		var hc := _ch(h)
		if h == c or hc == null or not h.is_alive() or not CombatFeatures.has_feature(h, "banneret_shared_resilience") or not h.allied_with(c):
			continue
		var banneret := h
		out.append({"kind": "banneret_shared_resilience", "reactor": h, "trigger": c.id, "sync": "explicit",
			"title": "Reaction: Shared Resilience?",
			"text": func() -> String: return "%s. %s can spend Indomitable so it rerolls with +%d." % [D20Responses.line(c, t), banneret.name(), hc.class_level_of("fighter")],
			"cost": "Reaction and a use of Indomitable",
			"still": func() -> bool: return not t.success and hc.resource_left("indomitable") > 0 and e.spells.can_react(banneret) \
				and e.distance(banneret, c) <= 60 and e.can_see(banneret, c),
			"helps": func() -> bool: return D20Responses.could_reach(t, 20, hc.class_level_of("fighter")),
			"use": func() -> void:
				hc.spend_resource("indomitable")
				banneret.reaction_available = false
				t.reroll(e.dice, "Shared Resilience", false, c.creature.has_flag("luck"))
				t.add_bonus(hc.class_level_of("fighter"), "Shared Resilience")
				_log("reaction", "%s lends %s their resolve (Shared Resilience)" % [banneret.name(), c.name()], banneret, [t.describe()])})


func _elemental_smite(c: Combatant, target: Combatant) -> void:
	var e := enc()
	var ch := _ch(c)
	var g := str(c.get_meta("genie_smite", ""))
	if g == "" or ch == null or ch.resource_left("paladin_channel_divinity") <= 0:
		return
	ch.spend_resource("paladin_channel_divinity")
	c.remove_meta("genie_smite")
	var dc := e.class_features._spell_dc(c, "paladin")
	match g:
		"dao":
			if target.is_alive() and not target.creature.is_condition_immune(&"grappled"):
				target.creature.add_condition(&"grappled", c.name())
				e.grapples[target.id] = c.id
				var fx := Effect.new("Dao's Grip", &"feature", "elemental_smite").with_condition(&"restrained")
				fx.caster_id = c.id
				fx.data["while_grappled_by"] = c.id
				target.creature.add_effect(fx)
				_log("condition", "Stone grips %s: Grappled and Restrained (escape DC %d)" % [target.name(), dc], c)
		"djinni":
			var fx2 := Effect.new("Djinni's Wind", &"feature", "elemental_smite")
			for ty: String in ["bludgeoning", "piercing", "slashing"]:
				fx2.with_modifier("resistance", {"value": ty})
			for cond: String in ["grappled", "prone", "restrained"]:
				fx2.with_modifier("condition_immunity", {"value": cond})
			fx2.ends = Effect.Ends.END_OF_TURN
			fx2.turn_owner_id = c.id
			fx2.skip_turn_ends = e.own_turn_skip(c)
			c.creature.add_effect(fx2)
			c.set_meta("djinni_step", _turn_key())
			_log("info", "A djinni's wind lifts %s (resists weapons; teleport from the hotbar)" % c.name(), c)
		"efreeti":
			var hit := [target]
			var other: Combatant = null
			for h in e.hostiles_of(c):
				if h != target and h.is_alive() and e.distance(c, h) <= 30 and e.can_see(c, h) and (other == null or e.distance(c, h) < e.distance(c, other)):
					other = h
			if other != null:
				hit.append(other)
			for x: Combatant in hit:
				var rolled := e._roll_damage_dice("2d4", false, 0, "Efreeti's Fire")
				e.deal_damage(c, x, [{"amount": int(rolled["total"]), "type": "fire"}], false, "Efreeti's Fire", [str(rolled["text"])])
		"marid":
			var pushed := [target]
			for h in e.hostiles_of(c):
				if h != target and h.is_alive() and e.distance(c, h) <= 10:
					pushed.append(h)
			for x: Combatant in pushed:
				if not e.class_features._save(x, &"str", dc, "Marid's Wave"):
					e.forced_move(x, e.center_of(c), 15)
					x.creature.add_condition(&"prone", "Marid's Wave")
					_log("condition", "A wave throws %s back and down" % x.name(), x)


## Noble Scion (Noble Genies 20): while the majesty lasts, a Reaction turns a failed D20 Test of the paladin or an ally
## in its Aura of Protection into a success. It asks where the roll can pause (its class-tab rule otherwise).
func noble_scion_offers(c: Combatant, t: D20Test, out: Array) -> void:
	var e := enc()
	if t.target <= 0:
		return
	for p in e.combatants:
		if not p.is_alive() or not p.creature.has_flag("noble_scion") or not (p == c or p.allied_with(c)):
			continue
		var scion := p
		out.append({"kind": "noble_scion", "reactor": p, "trigger": c.id, "sync": "explicit",
			"title": "Reaction: Noble Scion?",
			"text": func() -> String: return "%s. %s's majesty can turn it into a success." % [D20Responses.line(c, t), scion.name()],
			"cost": "Reaction",
			"still": func() -> bool: return not t.success and e.spells.can_react(scion) \
				and e.distance(scion, c) <= (30 if CombatFeatures.has_feature(scion, "aura_expansion") else 10),
			"use": func() -> void:
				scion.reaction_available = false
				t.add_bonus(maxi(0, t.target - t.total), "Noble Scion")
				_log("reaction", "%s's majesty turns the failure into a success (Noble Scion)" % scion.name(), scion)})


func _bloodthirst(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	if ch.resource_left("scion_bloodthirst") <= 0 or not e.spells.can_react(c):
		return CombatResult.new()
	var dest := Vector2i(-1, -1)
	var best := 1 << 30
	for dx in range(-1, t.size_cells + 1):
		for dy in range(-1, t.size_cells + 1):
			var cell := t.cell + Vector2i(dx, dy)
			if not e.grid.in_bounds(cell) or e.grid.is_solid(cell) or e.occupant_at(cell) != null or not e.can_see_space(c, cell):
				continue
			var d := e.grid.distance_ft(c.cell, 1, cell, 1)
			if d < best:
				best = d
				dest = cell
	if dest.x < 0:
		return CombatResult.new()
	ch.spend_resource("scion_bloodthirst")
	var from := c.cell
	var r := CombatResult.new()
	e.spells._teleport(c, dest, r)
	_log("reaction", "%s scents blood and appears beside %s (Bloodthirst)" % [c.name(), t.name()], c)
	if CombatFeatures.has_feature(c, "aura_of_malevolence"):
		_malevolence(c, from)
	return e._opportunity_attack(c, t)


func _malevolence(c: Combatant, _from: Vector2i) -> void:
	var e := enc()
	var ch := _ch(c)
	var ty := {"bane": "psychic", "bhaal": "poison", "myrkul": "necrotic"}.get(_pick(ch, "dread_allegiance"), "psychic") as String
	var dmg := maxi(1, c.creature.ability_mod(&"int"))
	for h in e.hostiles_of(c):
		if h.is_alive() and e.distance(c, h) <= 10:
			e.deal_damage(c, h, [{"amount": dmg, "type": ty, "ignore_resistance": true, "ignore_source": "Aura of Malevolence"}], false, "Aura of Malevolence")


func _spellfire_burst(c: Combatant, id: String, t: Combatant) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	if str(c.get_meta("burst_window", "")) != _turn_key():
		return CombatResult.fail("Spend Sorcery Points in an action first")
	if t == null or e.distance(c, t) > 30 or not e.can_see(c, t):
		return CombatResult.fail("Choose a creature you can see within 30 ft")
	c.remove_meta("burst_window")
	c.set_meta("burst_used", _turn_key())
	var honed := CombatFeatures.has_feature(c, "honed_spellfire")
	if id == "burst_flames":
		var amount := e.dice.roll_one(4, "Bolstering Flames") + maxi(0, c.creature.ability_mod(&"cha")) + (ch.class_level_of("sorcerer") if honed else 0)
		if t.creature.add_temp_hp(amount, "Bolstering Flames"):
			_log("heal", "Spellfire wraps %s: %d Temporary Hit Points (Bolstering Flames)" % [t.name(), amount], c)
	else:
		var rolled := e._roll_damage_dice("1d8" if honed else "1d4", false, 0, "Radiant Fire")
		e.deal_damage(c, t, [{"amount": int(rolled["total"]), "type": "radiant", "spell": true}], false, "Radiant Fire", [str(rolled["text"])])
	return CombatResult.new()


## Modify Magic, armed: a Ward for an ally the spell targets; Unravel for the first successful save against it.
func before_resolve(ctx: Dictionary) -> void:
	var fr := faerun()
	var c := ctx["c"] as Combatant
	var ch := _ch(c)
	fr.boons._boons_before_resolve(ctx)
	enc().items.specials.fr.prismatic(ctx)
	# Blessing of Moonlight: decided as the Moonbeam is cast, so its first save already counts.
	if ch != null and str((ctx["s"] as Dictionary).get("id", "")) == "moonbeam" and CombatFeatures.has_feature(c, "blessing_of_moonlight") \
			and ch.resource_left("blessing_of_moonlight") > 0 and allowed(c, "blessing_of_moonlight"):
		ch.spend_resource("blessing_of_moonlight")
		c.set_meta("bless_moonbeam", true)
		enc().spells._light(ctx, c, {"bright": 0, "dim": 5})
		_log("info", "%s blesses the Moonbeam" % c.name(), c)
	var m := str(c.get_meta("modify_magic", ""))
	if ch == null or m == "" or ch.resource_left("channel_divinity") <= 0:
		return
	if m == "ward":
		for t: Combatant in ctx.get("targets", []):
			if t == c or c.allied_with(t):
				ch.spend_resource("channel_divinity")
				c.remove_meta("modify_magic")
				var amount := int(enc().dice.roll_expr("2d8", "Modify Magic")["total"]) + ch.class_level_of("cleric")
				t.creature.add_temp_hp(amount, "Modify Magic")
				_log("heal", "%s's spell shields %s: %d Temporary Hit Points (Modify Magic)" % [c.name(), t.name(), amount], c)
				return
	elif m == "unravel" and (ctx["s"] as Dictionary).has("save"):
		c.set_meta("unravel_live", true)


func unravel_offers(c: Combatant, t: D20Test, keys: Array[String], out: Array) -> void:
	var e := enc()
	if t.kind != D20Test.Kind.SAVING_THROW:
		return
	for k in keys:
		if not k.begins_with("save_vs:spell:"):
			continue
		var caster := e.get_c(k.substr(14))
		var cch := _ch(caster)
		if caster == null or cch == null:
			continue
		# Armed on the hotbar ahead of the spell (Modify Magic: Unravel), so it isn't a choice now.
		out.append({"kind": "modify_magic", "reactor": caster, "forced": true,
			"still": func() -> bool: return t.success and bool(caster.get_meta("unravel_live", false)) and cch.resource_left("channel_divinity") > 0 and e.can_see(caster, c),
			"use": func() -> void:
				caster.remove_meta("unravel_live")
				caster.remove_meta("modify_magic")
				cch.spend_resource("channel_divinity")
				t.add_bonus(-e.dice.roll_one(6, "Modify Magic"), "Modify Magic")
				_log("info", "%s unravels %s's resistance (Modify Magic)" % [caster.name(), c.name()], caster, [t.describe()])})
		return


func _subclass_after_cast(c: Combatant, ch: Character, s: Dictionary, slot: int, free: bool, _ctx: Dictionary) -> void:
	var fr := faerun()
	c.remove_meta("unravel_live")
	var school := str(s.get("school", ""))
	if not free and slot > 0 and school == "enchantment" and CombatFeatures.has_feature(c, "instinctive_charm") \
			and ch.resource_left("instinctive_charm") < ch.resource_max("instinctive_charm"):
		ch.restore_resource("instinctive_charm", 1)
	if not free and slot > 0 and school == "necromancy" and CombatFeatures.has_feature(c, "undead_vitality"):
		fr.schools._undead_vitality(c, ch, slot)
	if str(s.get("id", "")) == "alter_self" and CombatFeatures.has_feature(c, "wondrous_alteration"):
		fr.schools._wondrous_alteration(c)
	if str(s.get("id", "")) == "moonbeam" and bool(c.get_meta("bless_moonbeam", false)):
		var o := enc().spells.zones.object_of(c.id, "moonbeam")
		if o != null:
			o.rules["blessed"] = true
		c.remove_meta("bless_moonbeam")
	# Dispelling Recovery: a slotted spell that heals or ends a condition opens a free Dispel Magic.
	if CombatFeatures.has_feature(c, "dispelling_recovery") and not free and slot > 0:
		var heals := s.has("heal") or "healing" in (s.get("tags", []) as Array) \
			or (s.get("effects", []) as Array).any(func(x: Variant) -> bool: return str((x as Dictionary).get("effect", "")) == "end_condition")
		if heals:
			c.set_meta("dispel_window", _turn_key())


func _dispelling_recovery(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	if str(c.get_meta("dispel_window", "")) != _turn_key() or ch.resource_left("dispelling_recovery") <= 0:
		return CombatResult.fail("Not now")
	if t == null or e.distance(c, t) > 120 or not e.can_see(c, t):
		return CombatResult.fail("Choose a creature you can see within 120 ft")
	ch.spend_resource("dispelling_recovery")
	c.remove_meta("dispel_window")
	var s := Compendium.shared().spell_data("dispel_magic")
	var entry := e.spells._entry_any(c, "dispel_magic")
	var ctx := {"c": c, "s": s, "slot": 3, "nums": e.spells.numbers(c, entry if not entry.is_empty() else {"class_id": "cleric"}),
		"conc": null, "opts": {}, "choice": "", "point": Vector2.INF}
	var r := CombatResult.new()
	e.events.append({"type": "spell", "caster": c.id, "spell": "dispel_magic", "cells": [], "targets": [t.id]})
	e.spells._dispel(ctx, t, r)
	return r


func _subclass_against_damage(target: Combatant, source: Combatant, total: Callable, cut: Callable, out: Array) -> void:
	var fr := faerun()
	var e := enc()
	var tc := _ch(target)
	if tc == null:
		return
	if CombatFeatures.has_feature(target, "elemental_rebuke") and tc.resource_left("elemental_rebuke") > 0 and e.spells.can_react(target) and int(total.call()) > 0:
		out.append({"kind": "elemental_rebuke", "reactor": target, "trigger": source.id, "title": "Reaction: Elemental Rebuke?",
			"text": "%s hits %s for %d. Halve it, and %s makes a Dexterity save against your elements?" % [source.name(), target.name(), int(total.call()), source.name()],
			"cost": "Reaction and a use of Elemental Rebuke",
			"still": func() -> bool: return tc.resource_left("elemental_rebuke") > 0 and e.spells.can_react(target) and int(total.call()) > 0,
			"use": func() -> void:
				tc.spend_resource("elemental_rebuke")
				target.reaction_available = false
				cut.call(int(total.call()) - int(total.call()) / 2, "Elemental Rebuke")
				var dc := e.class_features._spell_dc(target, "paladin")
				var rolled := e._roll_damage_dice("2d10+%d" % maxi(0, target.creature.ability_mod(&"cha")), false, 0, "Elemental Rebuke")
				var ok := e.class_features._save(source, &"dex", dc, "Elemental Rebuke")
				var amt := int(rolled["total"]) / 2 if ok else int(rolled["total"])
				e.deal_damage(target, source, [{"amount": amt, "type": genie_element(target)}], false, "Elemental Rebuke", [str(rolled["text"])])})
	if target.creature.has_flag("spellfire_crown") and int(total.call()) > 0 and str(target.get_meta("crown_hd_turn", "")) != _turn_key():
		out.append({"kind": "crown_of_spellfire", "reactor": target, "trigger": source.id, "title": "Crown of Spellfire?",
			"text": "%s hits %s for %d. Spend Hit Point Dice (up to %d) to burn the damage away?" % [source.name(), target.name(), int(total.call()), maxi(1, target.creature.ability_mod(&"cha"))],
			"cost": "Hit Point Dice", "spends_reaction": false,
			"still": func() -> bool: return int(total.call()) > 0,
			"use": func() -> void:
				target.set_meta("crown_hd_turn", _turn_key())
				var left := int(total.call())
				var cutn := 0
				for i in maxi(1, target.creature.ability_mod(&"cha")):
					if cutn >= left:
						break
					var r1 := fr.origin._spend_hit_dice(tc, 1, "Crown of Spellfire")
					if r1 <= 0:
						break
					cutn += r1
				cut.call(mini(cutn, left), "Crown of Spellfire")})
