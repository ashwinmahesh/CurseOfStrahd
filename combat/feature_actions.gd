class_name FeatureActions
extends RefCounted
## Class, subclass, feat and species abilities that are actions in a fight (2024 PHB), beyond the ones with code of
## their own in CombatFeatures (Second Wind, Action Surge, Channel Divinity...): Battle Master Bonus Action
## maneuvers, War Priest, Radiance of the Dawn, Invoke Duplicity, Breath Weapon, Healing Hands, Celestial
## Revelation, Large Form, Cloud's Jaunt, Adrenaline Rush, Psychic Blades, Telekinetic Movement, feat Bonus
## Actions (Hew, Pole Strike, Quick Study...), plus the hooks that change D20 Tests, turns and damage (Lucky,
## Portent, Indomitable, Relentless Endurance, Heavy Armor Master...). `list(c)` feeds the hotbar; `perform` runs
## one; every check that would make it illegal is in `list`'s reason.

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func f() -> CombatFeatures:
	return enc().features


static func has(c: Combatant, id: String) -> bool:
	return CombatFeatures.has_feature(c, id)


func _ch(c: Combatant) -> Character:
	return c.creature as Character if c.creature is Character else null


func _entry(id: String, label: String, sub: String, cost: String, why: String, targeting: String, help: String, rng: int = 0) -> Dictionary:
	return {"id": "feat:" + id, "label": label, "sub": sub, "cost": cost, "why": why, "targeting": targeting, "help": help, "range": rng}


func _bonus_why(c: Combatant) -> String:
	return enc()._bonus_check(c)


func _action_why(c: Combatant) -> String:
	var why := enc()._action_check(c)
	if why == "" and c.magic_action_used:
		why = "Only one Magic action this turn"
	return why


func _res_why(c: Combatant, res: String, n: int = 1) -> String:
	var ch := _ch(c)
	if ch == null or ch.resource_left(res) < n:
		return "None left"
	return ""


func _first(a: String, b: String) -> String:
	return a if a != "" else b


# --- The hotbar ---------------------------------------------------------------------------------

## Every ability `c` can use as an action this turn: {id, label, sub, cost, why, targeting, help, range}.
func list(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ch := _ch(c)
	var e := enc()
	var bw := _bonus_why(c)
	var aw := _action_why(c)
	if c.free_move_ft > 0:
		out.append(_entry("free_move", "Move (no Opportunity Attacks)", "%d ft" % c.free_move_ft, "free", e._turn_check(c), "point",
			"Movement from Tactical Shift, Cunning Strike or a maneuver: it doesn't provoke Opportunity Attacks.", c.free_move_ft))
	if c.creature is Monster and c.is_player_controlled():
		_creature_actions(c, out, aw, bw)
	# Saves taken with an action (Otto's Irresistible Dance).
	for i in e.spells.specials.mid.action_saves(c).size():
		var afx := e.spells.specials.mid.action_saves(c)[i]
		out.append(_entry("action_save:%d" % i, "Shake off %s" % afx.name, "%s save" % str(afx.repeat_save.get("ability", "wis")).capitalize(), "action", aw, "none",
			"Use your action to repeat the save against %s." % afx.name))
	# A druid in Wild Shape can leave the form as a Bonus Action.
	if e.shapes.is_shaped(c) and e.shapes.original(c) is Character and c.is_player_controlled():
		out.append(_entry("cf:revert_shape", "Leave Wild Shape", "true form", "bonus", bw, "none", "Bonus Action: return to your true form."))
	if ch == null:
		return out
	e.class_features.list(c, out, aw, bw)
	# Battle Master: Bonus Action maneuvers and Commander's Strike.
	var die := f().superiority_die(c)
	if die > 0:
		var dw := _res_why(c, "superiority_dice")
		if f().knows_maneuver(c, "evasive_footwork"):
			out.append(_entry("evasive_footwork", "Evasive Footwork", "Disengage + d%d AC" % die, "bonus", _first(bw, dw), "none", "Bonus Action: Disengage and add the die to your AC until the start of your next turn."))
		if f().knows_maneuver(c, "feinting_attack"):
			out.append(_entry("feinting_attack", "Feinting Attack", "Advantage + d%d" % die, "bonus", _first(bw, dw), "enemy", "Bonus Action: Advantage on your next attack this turn against a creature within 5 ft; add the die to its damage on a hit.", 5))
		if f().knows_maneuver(c, "lunging_attack"):
			out.append(_entry("lunging_attack", "Lunging Attack", "Dash + d%d" % die, "bonus", _first(bw, dw), "none", "Bonus Action: Dash; a melee hit after moving this turn adds the die to its damage."))
		if f().knows_maneuver(c, "rally"):
			out.append(_entry("rally", "Rally", "Temp HP d%d + %d" % [die, ch.class_level_of("fighter") / 2], "bonus", _first(bw, dw), "ally", "Bonus Action: an ally within 30 ft gains Temporary Hit Points.", 30))
		if f().knows_maneuver(c, "bait_and_switch"):
			var bsw := _first(e._turn_check(c), dw)
			if bsw == "" and c.movement_left < 5:
				bsw = "Needs 5 ft of movement"
			out.append(_entry("bait_and_switch", "Bait and Switch", "swap + d%d AC" % die, "movement", bsw, "ally", "Spend 5 ft of movement to swap places with a willing creature within 5 ft; one of you adds the die to AC until the start of your next turn.", 5))
		if f().knows_maneuver(c, "commanders_strike"):
			var cw := _first(enc().features_attack_why(c), dw)
			out.append(_entry("commanders_strike", "Commander's Strike", "ally attacks + d%d" % die, "attack", cw, "ally", "Give up one attack: an ally who can see or hear you uses its Reaction to make a weapon attack, adding the die to the damage.", 60))
		if has(c, "know_your_enemy"):
			var kw := bw
			if kw == "" and ch.resource_left("know_your_enemy") <= 0 and ch.resource_left("superiority_dice") <= 0:
				kw = "None left"
			out.append(_entry("know_your_enemy", "Know Your Enemy", "learn defenses", "bonus", kw, "enemy", "Bonus Action: learn a creature's Immunities, Resistances and Vulnerabilities (once per Long Rest, or a Superiority Die).", 30))
	# Arcane Charge (Eldritch Knight 15): teleport when you Action Surge.
	if has(c, "arcane_charge") and c.surged and not c.has_meta("arcane_charged"):
		out.append(_entry("arcane_charge", "Arcane Charge", "teleport 30 ft", "free", e._turn_check(c), "point", "When you use Action Surge, you can teleport up to 30 ft.", 30))
	# War Domain: War Priest.
	if has(c, "war_priest"):
		out.append(_entry("war_priest", "War Priest", "%d left" % ch.resource_left("war_priest"), "bonus", _first(bw, _res_why(c, "war_priest")), "enemy", "Bonus Action: one attack with a weapon or an Unarmed Strike.", 5))
	if has(c, "war_gods_blessing"):
		for sid: String in ["shield_of_faith", "spiritual_weapon"]:
			var sw := _first(bw, _res_why(c, "channel_divinity"))
			out.append(_entry("war_gods_blessing:" + sid, "War God's Blessing: %s" % sid.replace("_", " ").capitalize(), "Channel Divinity", "bonus", sw,
				"ally" if sid == "shield_of_faith" else "place", "Cast it without a slot or Concentration; it lasts 1 minute.", 60))
	# Light Domain: Radiance of the Dawn.
	if has(c, "radiance_of_the_dawn"):
		out.append(_entry("radiance_of_the_dawn", "Radiance of the Dawn", "2d10+%d · Con DC %d" % [ch.class_level_of("cleric"), f()._cleric_dc(c)], "action",
			_first(aw, _res_why(c, "channel_divinity")), "none", "Magic action: dispel magical Darkness within 30 ft; chosen creatures there make a Con save, 2d10 + Cleric level Radiant (half on a success)."))
	if has(c, "corona_of_light"):
		out.append(_entry("corona_of_light", "Corona of Light", "sunlight 60 ft", "action", _first(aw, _res_why(c, "corona_of_light")), "none", "Magic action: you shed Bright sunlight 60 ft for 1 minute; enemies there have Disadvantage on saves against your Radiance of the Dawn and Fire or Radiant spells."))
	# Trickery Domain.
	if has(c, "invoke_duplicity"):
		var dup := e.spells.zones.object_of(c.id, "invoke_duplicity")
		if dup == null:
			out.append(_entry("invoke_duplicity", "Invoke Duplicity", "illusion 30 ft", "bonus", _first(bw, _res_why(c, "channel_divinity")), "point", "Bonus Action: a perfect illusion of yourself within 30 ft for 1 minute: cast spells from its space; Advantage on attacks against creatures within 5 ft of both of you.", 30))
		else:
			out.append(_entry("move_duplicate", "Move Duplicate", "30 ft", "bonus", bw, "point", "Bonus Action: move the illusion up to 30 ft%s." % (" and swap places with it" if has(c, "tricksters_transposition") else ""), 30))
	if has(c, "blessing_of_the_trickster"):
		out.append(_entry("blessing_of_the_trickster", "Blessing of the Trickster", "Stealth Advantage", "action", aw, "ally", "Magic action: you or a willing creature within 30 ft has Advantage on Stealth checks until your next Long Rest.", 30))
	# Divine Intervention (Cleric 10).
	if has(c, "divine_intervention"):
		out.append(_entry("divine_intervention", "Divine Intervention", "a free Cleric spell", "action", _first(aw, _res_why(c, "divine_intervention")), "none", "Magic action: cast any Cleric spell of level 5 or lower without a slot (the spell's targeting follows)."))
	# Psi Warrior.
	if ch.subclasses.get("fighter", "") == "psi_warrior":
		var pw := _res_why(c, "psionic_energy")
		out.append(_entry("telekinetic_movement", "Telekinetic Movement", "move an ally 30 ft", "action", _first(aw, "" if ch.resource_left("telekinetic_movement") > 0 else pw), "ally", "Magic action: move a willing creature (not yourself) up to 30 ft to an unoccupied space.", 30))
		if has(c, "telekinetic_adept"):
			out.append(_entry("psi_leap", "Psi-Powered Leap", "fly 2× Speed", "bonus", _first(bw, "" if ch.resource_left("psi_leap") > 0 else pw), "none", "Bonus Action: a Fly Speed of twice your Speed until the end of the turn."))
		if has(c, "bulwark_of_force"):
			out.append(_entry("bulwark_of_force", "Bulwark of Force", "Half Cover", "bonus", _first(bw, "" if ch.resource_left("bulwark_of_force") > 0 else pw), "none", "Bonus Action: you and up to Int modifier creatures within 30 ft have Half Cover for 1 minute."))
	# Soulknife.
	if ch.subclasses.get("rogue", "") == "soulknife":
		if has(c, "soul_blades"):
			out.append(_entry("psychic_teleport", "Psychic Teleportation", "die × 10 ft", "bonus", _first(bw, _res_why(c, "psionic_energy")), "point", "Bonus Action: throw a blade and teleport up to the Psionic Energy Die roll × 10 ft.", f().psionic_die(c) * 10))
		if has(c, "psychic_veil"):
			out.append(_entry("psychic_veil", "Psychic Veil", "Invisible", "action", _first(aw, "" if ch.resource_left("psychic_veil") > 0 else _res_why(c, "psionic_energy")), "none", "Magic action: Invisible for 1 hour or until you deal damage or force a save."))
	# Thief: Fast Hands (Utilize as a Bonus Action: a Healer's Kit).
	if has(c, "fast_hands") and e.has_kit(c):
		out.append(_entry("fast_hands_kit", "Fast Hands: Healer's Kit", "stabilize", "bonus", bw, "dying", "Bonus Action (Utilize): spend a use of a Healer's Kit to stabilize a creature within 5 ft.", 5))
	# Abjurer: restore the Arcane Ward with a slot.
	if has(c, "arcane_ward") and c.has_meta("ward_made"):
		var slot := 0
		for l in range(1, 10):
			if ch.slots_left(l) > 0:
				slot = l
				break
		out.append(_entry("restore_ward", "Restore Arcane Ward", "+%d HP (level %d slot)" % [2 * slot, slot], "bonus", _first(bw, "" if slot > 0 else "No spell slots"), "none", "Bonus Action: expend a spell slot to restore 2 × its level Hit Points to the ward."))
	# Diviner: Portent.
	if has(c, "portent"):
		for v: Variant in c.get_meta("portent_rolls", []):
			out.append(_entry("portent:%d" % int(v), "Portent: %d" % int(v), "replace a d20", "free", e._turn_check(c), "creature", "Before a creature you can see makes its next D20 Test, the d20 shows %d (once per turn)." % int(v), 9999))
	if has(c, "the_third_eye") and not c.has_meta("third_eye"):
		out.append(_entry("the_third_eye", "The Third Eye", "Darkvision 120 or See Invisibility", "bonus", bw, "none", "Bonus Action until your next rest: Darkvision 120 ft (or see the Invisible)."))
	# Species.
	if has(c, "breath_weapon"):
		var bwhy := _first(enc().features_attack_why(c), _res_why(c, "breath_weapon"))
		var dice := "%dd10" % (1 + (1 if c.creature.character_level() >= 5 else 0) + (1 if c.creature.character_level() >= 11 else 0) + (1 if c.creature.character_level() >= 17 else 0))
		out.append(_entry("breath_weapon:cone", "Breath Weapon (Cone)", "15 ft · %s" % dice, "attack", bwhy, "direction", "Replaces one attack: a 15-ft Cone, Dex save (DC 8 + Con + PB), half on a success."))
		out.append(_entry("breath_weapon:line", "Breath Weapon (Line)", "30 ft · %s" % dice, "attack", bwhy, "direction", "Replaces one attack: a 30-ft × 5-ft Line, Dex save, half on a success."))
	if has(c, "healing_hands"):
		out.append(_entry("healing_hands", "Healing Hands", "%dd4" % c.creature.proficiency_bonus(), "action", _first(aw, _res_why(c, "healing_hands")), "ally", "Magic action: touch a creature, it regains PB d4 Hit Points.", 5))
	if has(c, "celestial_revelation") and not c.creature.has_flag("celestial_revelation"):
		for form: String in ["heavenly_wings", "inner_radiance", "necrotic_shroud"]:
			out.append(_entry("celestial_revelation:" + form, "Celestial Revelation: %s" % form.replace("_", " ").capitalize(), "1 min", "bonus",
				_first(bw, _res_why(c, "celestial_revelation")), "none", "Bonus Action: transform for 1 minute; once per turn +%d Radiant (Necrotic for the Shroud) damage." % c.creature.proficiency_bonus()))
	if has(c, "large_form") and c.creature.size == &"medium":
		out.append(_entry("large_form", "Large Form", "10 min", "bonus", _first(bw, _res_why(c, "large_form")), "none", "Bonus Action: become Large for 10 minutes: Advantage on Strength checks, +10 ft Speed."))
	if has(c, "draconic_flight"):
		out.append(_entry("draconic_flight", "Draconic Flight", "Fly = Speed", "bonus", _first(bw, _res_why(c, "draconic_flight")), "none", "Bonus Action: spectral wings give a Fly Speed equal to your Speed for 10 minutes."))
	if has(c, "clouds_jaunt"):
		out.append(_entry("clouds_jaunt", "Cloud's Jaunt", "teleport 30 ft", "bonus", _first(bw, _res_why(c, "giant_ancestry")), "point", "Bonus Action: teleport up to 30 ft to an unoccupied space you can see.", 30))
	if has(c, "adrenaline_rush"):
		out.append(_entry("adrenaline_rush", "Adrenaline Rush", "Dash + %d temp HP" % c.creature.proficiency_bonus(), "bonus", _first(bw, _res_why(c, "adrenaline_rush")), "none", "Bonus Action: Dash and gain Temporary Hit Points equal to your Proficiency Bonus."))
	if has(c, "stonecunning"):
		out.append(_entry("stonecunning", "Stonecunning", "Tremorsense 60 ft", "bonus", _first(bw, _res_why(c, "stonecunning")), "none", "Bonus Action (on stone): Tremorsense 60 ft for 10 minutes."))
	# Feats.
	if f().has_feat(c, "healer") and e.has_kit(c):
		out.append(_entry("battle_medic", "Battle Medic", "Healer's Kit", "action", aw, "ally", "Utilize a Healer's Kit on a creature within 5 ft: it spends a Hit Point Die and regains the roll + your Proficiency Bonus.", 5))
	if f().has_feat(c, "durable"):
		out.append(_entry("speedy_recovery", "Speedy Recovery", "spend a Hit Point Die", "bonus", bw, "none", "Bonus Action: spend one of your Hit Point Dice to regain Hit Points."))
	if f().has_feat(c, "keen_mind"):
		out.append(_entry("quick_study", "Quick Study", "Study", "bonus", bw, "creature", "Take the Study action as a Bonus Action.", 120))
	if f().has_feat(c, "observant"):
		out.append(_entry("quick_search", "Quick Search", "Search", "bonus", bw, "none", "Take the Search action as a Bonus Action."))
	if f().has_feat(c, "telekinetic"):
		out.append(_entry("telekinetic_shove", "Telekinetic Shove", "Str save, 5 ft", "bonus", bw, "creature", "Bonus Action: a creature within 30 ft makes a Strength save or is moved 5 ft toward or away from you.", 30))
	if f().has_feat(c, "poisoner") and e.item_count(c, "poisoners_kit") > 0 and not c.has_meta("poisoned_weapon"):
		out.append(_entry("apply_poison", "Apply Poison", "next hit: 2d8 Poison", "bonus", _first(bw, _res_why(c, "poison_doses")), "none", "Bonus Action: coat a weapon; the next hit forces a Con save or 2d8 Poison and Poisoned."))
	if c.bonus_attack != "" or (f().has_feat(c, "polearm_master") and c.took_attack_action) or (f().has_feat(c, "dual_wielder") and c.light_attack_weapon != ""):
		for o in e.attack_options(c):
			var p := o["profile"] as WeaponProfile
			if not bool(o["melee"]):
				continue
			var label := ""
			if c.bonus_attack != "":
				label = c.bonus_attack
			elif f().has_feat(c, "polearm_master") and (p.item_id in ["quarterstaff", "spear"] or ("heavy" in p.properties and "reach" in p.properties)):
				label = "Pole Strike"
			if label == "":
				continue
			var pa := _entry("bonus_attack:%s:%s" % [label.to_snake_case(), o["id"]], "%s: %s" % [label, p.name], "Bonus Action attack", "bonus", bw, "enemy",
				"A Bonus Action attack (%s)." % label, p.reach)
			out.append(pa)
	if f().has_feat(c, "lucky") and not "lucky" in c.armed:
		out.append(_entry("lucky", "Lucky", "%d Luck Points" % ch.resource_left("luck_points"), "free", _first(e._turn_check(c), _res_why(c, "luck_points")), "none", "Spend a Luck Point: Advantage on your next D20 Test."))
	if f().has_feat(c, "boon_of_speed"):
		out.append(_entry("escape_artist", "Escape Artist", "Disengage", "bonus", bw, "none", "Bonus Action: Disengage, and end the Grappled condition on yourself."))
	if f().has_feat(c, "boon_of_recovery") and ch.resource_left("recover_vitality") > 0:
		out.append(_entry("recover_vitality", "Recover Vitality", "%d d10 left" % ch.resource_left("recover_vitality"), "bonus", bw, "none", "Bonus Action: roll up to five d10s from the pool and regain that many Hit Points."))
	return out


# --- Using them ---------------------------------------------------------------------------------

## A summoned creature the player controls: its stat block's save actions and Bonus Actions (Fey Step, Fell Glare,
## Healing Touch, Venomous Spew).
func _creature_actions(c: Combatant, out: Array[Dictionary], aw: String, bw: String) -> void:
	var ma := enc().monster_actions
	var data := MonsterActions.data_of(c)
	for group: String in ["actions", "bonus_actions"]:
		for raw: Variant in data.get(group, []):
			var act := raw as Dictionary
			var cost := "bonus" if group == "bonus_actions" else "action"
			var why := _first(bw if cost == "bonus" else aw, ma.why_not(c, act))
			var kind := str(act.get("do", act.get("kind", "")))
			if act.has("teleport"):
				kind = "teleport"
			var tg := act.get("targets", {}) as Dictionary
			match kind:
				"save":
					out.append(_entry("creature:" + str(act["id"]), str(act["name"]), "%s DC %d" % [str((act["save"] as Dictionary)["ability"]).capitalize(), int((act["save"] as Dictionary)["dc"])],
						cost, why, "enemy", str(act.get("summary", "")), int(tg.get("range", 5))))
				"teleport":
					out.append(_entry("creature:" + str(act["id"]), str(act["name"]), "teleport %d ft" % int(act["teleport"]), cost, why, "point",
						str(act.get("summary", "")), int(act["teleport"])))
				"heal":
					out.append(_entry("creature:" + str(act["id"]), str(act["name"]), str(act.get("heal", "")), cost, why, "ally",
						str(act.get("summary", "")), int(act.get("range", 5))))


func _perform_creature(c: Combatant, act_id: String, t: Combatant, cell: Vector2i) -> CombatResult:
	var e := enc()
	var ma := e.monster_actions
	var act := {}
	var cost := "action"
	for group: String in ["actions", "bonus_actions"]:
		for raw: Variant in MonsterActions.data_of(c).get(group, []):
			if str((raw as Dictionary).get("id", "")) == act_id:
				act = raw as Dictionary
				cost = "bonus" if group == "bonus_actions" else "action"
	if act.is_empty():
		return CombatResult.fail("Not available")
	var r := CombatResult.new()
	if act.has("teleport"):
		r = _teleport(c, cell, int(act["teleport"]))
		if not r.ok:
			return r
		# Fey Step's mood rider (Summon Fey).
		if act.has("mood"):
			ma._fey_step_rider(c, act, r)
	elif act.has("save"):
		if t == null:
			return CombatResult.fail("Choose a target")
		ma.save_action(c, act, t, r)
	elif act.has("heal"):
		if t == null:
			t = c
		var rolled := e._roll_damage_dice(str(act["heal"]), false, 0, str(act["name"]))
		var healed := t.creature.heal(int(rolled["total"]), str(act["name"]))
		e.log.add("heal", "%s: %s regains %d Hit Points" % [act["name"], t.name(), healed], c.id, [str(rolled["text"])])
		e.events.append({"type": "heal", "id": t.id, "amount": healed})
	ma.spend(c, act)
	if cost == "bonus":
		c.bonus_available = false
	else:
		e.spend_action(c)
	return r


func perform(c: Combatant, id: String, t: Combatant, point: Vector2) -> CombatResult:
	var e := enc()
	var entry := {}
	for x in list(c):
		if str(x["id"]) == "feat:" + id:
			entry = x
	if entry.is_empty():
		return CombatResult.fail("Not available")
	if str(entry["why"]) != "":
		return CombatResult.fail(str(entry["why"]))
	var ch := _ch(c)
	var cell := Vector2i(floori(point.x), floori(point.y)) if point != Vector2.INF else Vector2i(-1, -1)
	var r := CombatResult.new()
	var head := id.get_slice(":", 0)
	var rng := int(entry.get("range", 0))
	if t != null and rng > 0 and t != c and e.distance(c, t) > rng:
		return CombatResult.fail("Out of range (%d ft)" % rng)
	match head:
		"free_move":
			return e.free_move(c, cell)
		"creature":
			return _perform_creature(c, id.substr(9), t, cell)
		"action_save":
			var saves := e.spells.specials.mid.action_saves(c)
			var idx := int(id.get_slice(":", 1))
			if idx >= saves.size():
				return CombatResult.fail("Not available")
			return e.spells.specials.mid.take_action_save(c, saves[idx])
		"cf":
			return e.class_features.perform(c, id.substr(3), t, cell, point)
		"fast_hands_kit":
			var keep := c.action_available
			c.action_available = true
			var res0 := e.stabilize(c, t, true)
			c.action_available = keep
			if res0.ok:
				c.bonus_available = false
			return res0
		"evasive_footwork":
			ch.spend_resource("superiority_dice")
			c.bonus_available = false
			c.disengaged = true
			var v := e.dice.roll_one(f().superiority_die(c), "Evasive Footwork")
			_ac_until_turn(c, c, v, "Evasive Footwork")
			e.log.add("info", "%s Disengages with Evasive Footwork (+%d AC)" % [c.name(), v], c.id)
		"feinting_attack":
			if t == null or e.distance(c, t) > 5:
				return CombatResult.fail("Choose a creature within 5 ft")
			ch.spend_resource("superiority_dice")
			c.bonus_available = false
			e.add_mark({"kind": "advantage_against", "target": t.id, "attacker": c.id, "source": "Feinting Attack", "expires_owner": c.id, "expires_phase": "end", "consume": true})
			c.set_meta("feint_die", f().superiority_die(c))
			c.armed.append("feint_damage")
			e.log.add("info", "%s feints at %s" % [c.name(), t.name()], c.id)
		"lunging_attack":
			ch.restore_resource("superiority_dice", 0)
			c.bonus_available = false
			c.movement_left += c.speed()
			if not "maneuver:lunging_attack" in c.armed:
				c.armed.append("maneuver:lunging_attack")
			e.log.add("info", "%s lunges forward (Dash)" % c.name(), c.id)
		"rally":
			if t == null:
				return CombatResult.fail("Choose an ally")
			ch.spend_resource("superiority_dice")
			c.bonus_available = false
			var amount := e.dice.roll_one(f().superiority_die(c), "Rally") + ch.class_level_of("fighter") / 2
			t.creature.add_temp_hp(amount, "Rally")
			e.log.add("heal", "%s rallies %s: %d Temporary Hit Points" % [c.name(), t.name(), amount], c.id)
		"bait_and_switch":
			if t == null or e.distance(c, t) > 5 or not c.allied_with(t):
				return CombatResult.fail("Choose a willing creature within 5 ft")
			ch.spend_resource("superiority_dice")
			c.movement_left -= 5
			var a := c.cell
			c.cell = t.cell
			t.cell = a
			e.events.append({"type": "teleport", "id": c.id, "from": t.cell, "to": c.cell})
			e.events.append({"type": "teleport", "id": t.id, "from": c.cell, "to": t.cell})
			var v2 := e.dice.roll_one(f().superiority_die(c), "Bait and Switch")
			_ac_until_turn(c, t if t.creature.ac_value() <= c.creature.ac_value() else c, v2, "Bait and Switch")
			e.log.add("move", "%s and %s swap places (Bait and Switch, +%d AC)" % [c.name(), t.name(), v2], c.id)
		"commanders_strike":
			if t == null or not c.allied_with(t) or t == c or not e.spells.can_react(t):
				return CombatResult.fail("Choose an ally who still has its Reaction")
			var best := e.ai._best_in_reach(t)
			if best.is_empty():
				return CombatResult.fail("%s has no enemy in reach" % t.name())
			ch.spend_resource("superiority_dice")
			e.use_one_attack(c)
			t.reaction_available = false
			e.log.add("info", "%s directs %s to strike (Commander's Strike)" % [c.name(), t.name()], c.id)
			var opt := e.option_by_id(t, str(best["option"]))
			return e._resolve_attack(t, best["target"] as Combatant, opt, {"reaction": true,
				"extra_dice": [{"dice": "1d%d" % f().superiority_die(c), "type": str((opt["profile"] as WeaponProfile).damage_type), "label": "Commander's Strike"}]})
		"know_your_enemy":
			c.bonus_available = false
			if ch.resource_left("know_your_enemy") > 0:
				ch.spend_resource("know_your_enemy")
			else:
				ch.spend_resource("superiority_dice")
			if t != null and t.creature is Monster:
				e.studied[str((t.creature as Monster).data.get("id", ""))] = true
				var m := t.creature as Monster
				e.log.add("info", "%s reads %s: resistances %s, immunities %s, vulnerabilities %s" % [c.name(), t.name(),
					", ".join(m.data.get("resistances", ["none"])), ", ".join(m.data.get("immunities", ["none"])), ", ".join(m.data.get("vulnerabilities", ["none"]))], c.id)
		"arcane_charge":
			c.set_meta("arcane_charged", true)
			return _teleport(c, cell, 30)
		"war_priest":
			ch.spend_resource("war_priest")
			return _bonus_attack(c, t, "War Priest")
		"war_gods_blessing":
			ch.spend_resource("channel_divinity")
			c.bonus_available = false
			var sid := id.get_slice(":", 1)
			return e.spells.cast_free(c, sid, [t] if t != null else [], point, {"no_concentration": true, "minutes": 1, "no_economy": true})
		"radiance_of_the_dawn":
			return _radiance(c)
		"corona_of_light":
			ch.spend_resource("corona_of_light")
			e.spend_action(c)
			c.magic_action_used = true
			var o := FieldObject.new(FieldObject.Kind.ZONE, "corona_of_light", "Corona of Light")
			o.caster_id = c.id
			o.follows_caster = true
			o.rules = {"light": {"bright": 60, "dim": 30, "sunlight": true}, "triggers": []}
			o.rounds_left = 10
			e.spells.zones.add(o, r)
			e.log.add("spell", "%s blazes with a corona of sunlight" % c.name(), c.id)
		"invoke_duplicity":
			ch.spend_resource("channel_divinity")
			c.bonus_available = false
			var dup := FieldObject.new(FieldObject.Kind.ILLUSION, "invoke_duplicity", "Duplicate of %s" % c.name())
			dup.caster_id = c.id
			dup.cell = cell
			dup.cells = [cell]
			dup.rounds_left = 10
			e.spells.zones.add(dup, r)
			e.log.add("spell", "%s conjures a perfect double of itself" % c.name(), c.id)
		"move_duplicate":
			var dup2 := e.spells.zones.object_of(c.id, "invoke_duplicity")
			if dup2 == null or e.grid.distance_ft(dup2.cell, 1, cell, 1) > 30:
				return CombatResult.fail("The double moves at most 30 ft")
			c.bonus_available = false
			dup2.cell = cell
			dup2.cells = [cell]
			e.spells.zones.moved_object(dup2, r)
			if has(c, "tricksters_transposition") and e.occupant_at(cell) == null:
				var from := c.cell
				c.cell = dup2.cell
				dup2.cell = from
				dup2.cells = [from]
				e.events.append({"type": "teleport", "id": c.id, "from": from, "to": c.cell})
		"blessing_of_the_trickster":
			e.spend_action(c)
			c.magic_action_used = true
			var who := t if t != null else c
			var fx := Effect.new("Blessing of the Trickster", &"feature", "blessing_of_the_trickster").with_modifier("advantage", {"on": "check:stealth"})
			fx.ends = Effect.Ends.LONG_REST
			who.creature.add_effect(fx)
			e.log.add("info", "%s blesses %s with stealth" % [c.name(), who.name()], c.id)
		"divine_intervention":
			ch.spend_resource("divine_intervention")
			e.log.add("spell", "%s calls on divine intervention: the next Cleric spell (level 5 or lower) costs no slot" % c.name(), c.id)
			c.set_meta("free_cleric_spell", 5)
		"telekinetic_movement":
			if t == null or t == c or not c.allied_with(t):
				return CombatResult.fail("Choose a willing creature")
			if ch.resource_left("telekinetic_movement") > 0:
				ch.spend_resource("telekinetic_movement")
			else:
				ch.spend_resource("psionic_energy")
			e.spend_action(c)
			c.magic_action_used = true
			return _move_to(t, cell, 30)
		"psi_leap":
			c.bonus_available = false
			if ch.resource_left("psi_leap") > 0:
				ch.spend_resource("psi_leap")
			else:
				ch.spend_resource("psionic_energy")
			var leap := Effect.new("Psi-Powered Leap", &"feature", "psi_leap").with_modifier("speed_set", {"kind": "fly", "value": 2 * c.creature.speed().total()})
			leap.ends = Effect.Ends.END_OF_TURN
			leap.turn_owner_id = c.id
			c.creature.add_effect(leap)
			c.movement_left += c.creature.speed().total()
		"bulwark_of_force":
			c.bonus_available = false
			if ch.resource_left("bulwark_of_force") > 0:
				ch.spend_resource("bulwark_of_force")
			else:
				ch.spend_resource("psionic_energy")
			var n := maxi(1, c.creature.ability_mod(&"int"))
			var shielded: Array[Combatant] = [c]
			for a2 in e.allies_of(c):
				if shielded.size() > n:
					break
				if e.distance(c, a2) <= 30:
					shielded.append(a2)
			for s2 in shielded:
				var bf := Effect.new("Bulwark of Force", &"feature", "bulwark_of_force").with_modifier("flag", {"value": "half_cover"})
				bf.lasting({"kind": "minutes", "amount": 1})
				bf.turn_owner_id = c.id
				s2.creature.add_effect(bf)
			e.log.add("info", "%s raises a Bulwark of Force" % c.name(), c.id)
		"psychic_teleport":
			ch.spend_resource("psionic_energy")
			c.bonus_available = false
			var ft := e.dice.roll_one(f().psionic_die(c), "Psychic Teleportation") * 10
			return _teleport(c, cell, ft)
		"psychic_veil":
			e.spend_action(c)
			c.magic_action_used = true
			if ch.resource_left("psychic_veil") > 0:
				ch.spend_resource("psychic_veil")
			else:
				ch.spend_resource("psionic_energy")
			var pv := Effect.new("Psychic Veil", &"feature", "psychic_veil").with_condition(&"invisible")
			pv.lasting({"kind": "hours", "amount": 1})
			pv.ends_on = ["deal_damage", "force_save"]
			c.creature.add_effect(pv)
		"restore_ward":
			c.bonus_available = false
			for l in range(1, 10):
				if ch.slots_left(l) > 0:
					ch.expend_slot(l)
					c.creature.ward_hp = mini(ch.resource_max("arcane_ward"), c.creature.ward_hp + 2 * l)
					e.log.add("info", "%s restores the Arcane Ward to %d" % [c.name(), c.creature.ward_hp], c.id)
					break
		"portent":
			if t == null:
				return CombatResult.fail("Choose a creature")
			var v3 := int(id.get_slice(":", 1))
			var rolls := (c.get_meta("portent_rolls", []) as Array).duplicate()
			rolls.erase(v3)
			c.set_meta("portent_rolls", rolls)
			t.set_meta("portent_next", v3)
			e.log.add("info", "%s foresees %s's next d20: %d (Portent)" % [c.name(), t.name(), v3], c.id)
		"the_third_eye":
			c.bonus_available = false
			c.set_meta("third_eye", true)
			var te := Effect.new("The Third Eye", &"feature", "the_third_eye").with_modifier("darkvision", {"value": 120}).with_modifier("flag", {"value": "see_invisibility"})
			te.ends = Effect.Ends.SHORT_REST
			c.creature.add_effect(te)
		"breath_weapon":
			return _breath(c, id.get_slice(":", 1), point)
		"healing_hands":
			if t == null:
				return CombatResult.fail("Choose a creature")
			ch.spend_resource("healing_hands")
			e.spend_action(c)
			c.magic_action_used = true
			var rolled := e._roll_damage_dice("%dd4" % c.creature.proficiency_bonus(), false, 0, "Healing Hands")
			var healed := t.creature.heal(int(rolled["total"]), "Healing Hands")
			e.log.add("heal", "%s's Healing Hands restore %d Hit Points to %s" % [c.name(), healed, t.name()], c.id, [str(rolled["text"])])
			e.events.append({"type": "heal", "id": t.id, "amount": healed})
		"celestial_revelation":
			ch.spend_resource("celestial_revelation")
			c.bonus_available = false
			var form := id.get_slice(":", 1)
			var cr := Effect.new("Celestial Revelation: %s" % form.replace("_", " ").capitalize(), &"feature", "celestial_revelation").with_modifier("flag", {"value": "celestial_revelation"})
			cr.lasting({"kind": "minutes", "amount": 1})
			cr.turn_owner_id = c.id
			match form:
				"heavenly_wings":
					cr.modifiers.append(Modifier.of("speed_set", {"kind": "fly", "value": c.creature.speed().total()}, cr.name, &"feature"))
				"inner_radiance":
					cr.modifiers.append(Modifier.of("flag", {"value": "inner_radiance"}, cr.name, &"feature"))
					var glow := FieldObject.new(FieldObject.Kind.ZONE, "inner_radiance", "Inner Radiance")
					glow.caster_id = c.id
					glow.follows_caster = true
					glow.rules = {"light": {"bright": 10, "dim": 10}, "triggers": []}
					glow.rounds_left = 10
					e.spells.zones.add(glow, r)
				"necrotic_shroud":
					cr.modifiers.append(Modifier.of("flag", {"value": "necrotic_shroud"}, cr.name, &"feature"))
					var dc := 8 + c.creature.ability_mod(&"cha") + c.creature.proficiency_bonus()
					for o2 in e.hostiles_of(c):
						if e.distance(c, o2) <= 10 and not f()._save(o2, &"cha", dc, "Necrotic Shroud", "frightened"):
							var fr := Effect.new("Frightened (Necrotic Shroud)", &"feature", "necrotic_shroud").with_condition(&"frightened")
							fr.caster_id = c.id
							fr.ends = Effect.Ends.END_OF_TURN
							fr.turn_owner_id = c.id
							fr.skip_turn_ends = 1
							o2.creature.add_effect(fr)
			c.creature.add_effect(cr)
			e.log.add("info", "%s reveals a celestial form" % c.name(), c.id)
		"large_form":
			ch.spend_resource("large_form")
			c.bonus_available = false
			var lf := Effect.new("Large Form", &"feature", "large_form").with_modifier("advantage", {"on": "check:str"}).with_modifier("speed", {"value": 10})
			lf.lasting({"kind": "minutes", "amount": 10})
			lf.turn_owner_id = c.id
			e.spells._resize(c, 1, lf)
			c.creature.add_effect(lf)
		"draconic_flight":
			ch.spend_resource("draconic_flight")
			c.bonus_available = false
			var df := Effect.new("Draconic Flight", &"feature", "draconic_flight").with_modifier("speed_set", {"kind": "fly", "value": c.creature.speed().total()})
			df.lasting({"kind": "minutes", "amount": 10})
			df.turn_owner_id = c.id
			c.creature.add_effect(df)
		"clouds_jaunt":
			ch.spend_resource("giant_ancestry")
			c.bonus_available = false
			return _teleport(c, cell, 30)
		"adrenaline_rush":
			ch.spend_resource("adrenaline_rush")
			c.bonus_available = false
			c.movement_left += c.speed()
			c.creature.add_temp_hp(c.creature.proficiency_bonus(), "Adrenaline Rush")
			e.log.add("info", "%s surges forward (Dash, %d Temporary Hit Points)" % [c.name(), c.creature.proficiency_bonus()], c.id)
		"stonecunning":
			ch.spend_resource("stonecunning")
			c.bonus_available = false
			var sc := Effect.new("Stonecunning", &"feature", "stonecunning").with_modifier("sense", {"kind": "tremorsense", "value": 60})
			sc.lasting({"kind": "minutes", "amount": 10})
			c.creature.add_effect(sc)
		"battle_medic":
			if t == null or e.distance(c, t) > 5:
				return CombatResult.fail("Choose a creature within 5 ft")
			e.spend_action(c)
			var hd := e.dice.roll_one(8, "Battle Medic") + c.creature.proficiency_bonus()
			var healed2 := t.creature.heal(hd, "Battle Medic")
			e.log.add("heal", "%s patches up %s: %d Hit Points (Battle Medic)" % [c.name(), t.name(), healed2], c.id)
			e.events.append({"type": "heal", "id": t.id, "amount": healed2})
		"speedy_recovery":
			c.bonus_available = false
			var got := 0
			for die: Variant in ch.hit_dice().keys():
				got = ch.spend_hit_die(e.dice, int(die))
				if got > 0:
					break
			e.log.add("heal", "%s catches their breath: %d Hit Points (Speedy Recovery)" % [c.name(), got], c.id)
		"quick_study":
			c.bonus_available = false
			c.action_available = true
			var keep := c.action_available
			var res := e.study(c, t)
			c.action_available = keep
			return res
		"quick_search":
			c.bonus_available = false
			var keep2 := c.action_available
			c.action_available = true
			var res2 := e.search(c)
			c.action_available = keep2
			return res2
		"telekinetic_shove":
			if t == null:
				return CombatResult.fail("Choose a creature")
			c.bonus_available = false
			var dc2 := 8 + maxi(maxi(c.creature.ability_mod(&"int"), c.creature.ability_mod(&"wis")), c.creature.ability_mod(&"cha")) + c.creature.proficiency_bonus()
			if c.allied_with(t) or not f()._save(t, &"str", dc2, "Telekinetic Shove"):
				e.forced_move(t, e.center_of(c), 5, c.allied_with(t))
		"apply_poison":
			ch.spend_resource("poison_doses")
			c.bonus_available = false
			c.set_meta("poisoned_weapon", true)
			e.log.add("info", "%s coats a weapon in poison" % c.name(), c.id)
		"bonus_attack":
			var label := id.get_slice(":", 1)
			var opt_id := id.substr(("bonus_attack:%s:" % label).length())
			c.bonus_available = false
			if c.bonus_attack != "":
				c.bonus_attack = ""
			var opt2 := e.option_by_id(c, opt_id)
			var check := e.attack_legal(c, t, opt2)
			if check != "":
				return CombatResult.fail(check)
			var o3 := opt2.duplicate()
			if label == "pole_strike":
				var pp := (opt2["profile"] as WeaponProfile).with_ability((opt2["profile"] as WeaponProfile).ability, c.creature)
				pp.damage_dice = "1d4"
				pp.damage_type = &"bludgeoning"
				o3["profile"] = pp
			return e._resolve_attack(c, t, o3, {})
		"lucky":
			c.armed.append("lucky")
			e.log.add("info", "%s spends Luck on the next roll" % c.name(), c.id)
		"escape_artist":
			c.bonus_available = false
			c.disengaged = true
			if e.grapples.has(c.id):
				e.grapples.erase(c.id)
				c.creature.remove_condition(&"grappled")
		"recover_vitality":
			c.bonus_available = false
			var n2 := mini(5, ch.resource_left("recover_vitality"))
			ch.spend_resource("recover_vitality", n2)
			var roll := int(e._roll_damage_dice("%dd10" % n2, false, 0, "Recover Vitality")["total"])
			c.creature.heal(roll, "Recover Vitality")
	e.events.append({"type": "condition", "id": c.id})
	return r


func _ac_until_turn(owner: Combatant, who: Combatant, amount: int, label: String) -> void:
	var fx := Effect.new(label, &"feature", label.to_snake_case()).with_modifier("ac", {"value": amount})
	fx.ends = Effect.Ends.START_OF_TURN
	fx.turn_owner_id = owner.id
	who.creature.add_effect(fx)


func _teleport(c: Combatant, cell: Vector2i, feet: int) -> CombatResult:
	var e := enc()
	if cell.x < 0 or not e.grid.in_bounds(cell) or e.grid.is_solid(cell) or e.occupant_at(cell) != null:
		return CombatResult.fail("Choose an unoccupied square")
	if e.grid.distance_ft(c.cell, c.size_cells, cell, c.size_cells) > feet:
		return CombatResult.fail("At most %d ft" % feet)
	var r := CombatResult.new()
	e.spells._teleport(c, cell, r)
	return r


func _move_to(t: Combatant, cell: Vector2i, feet: int) -> CombatResult:
	var e := enc()
	if cell.x < 0 or e.occupant_at(cell) != null or e.grid.is_solid(cell):
		return CombatResult.fail("Choose an unoccupied square")
	if e.grid.distance_ft(t.cell, t.size_cells, cell, t.size_cells) > feet:
		return CombatResult.fail("At most %d ft" % feet)
	var from := t.cell
	t.cell = cell
	e.events.append({"type": "teleport", "id": t.id, "from": from, "to": cell})
	e.spells.zones.on_moved(t, from)
	return CombatResult.new()


func _bonus_attack(c: Combatant, t: Combatant, label: String) -> CombatResult:
	var e := enc()
	if t == null:
		return CombatResult.fail("Choose a target")
	var best := {}
	for o in e.attack_options(c):
		if e.attack_legal(c, t, o) == "" and (best.is_empty() or (o["profile"] as WeaponProfile).average_damage() > (best["profile"] as WeaponProfile).average_damage()):
			best = o
	if best.is_empty():
		return CombatResult.fail("No attack reaches %s" % t.name())
	c.bonus_available = false
	e.log.add("info", "%s strikes again (%s)" % [c.name(), label], c.id)
	return e._resolve_attack(c, t, best, {})


## Radiance of the Dawn (Light Domain 3): Channel Divinity as a Magic action: magical Darkness within 30 ft is
## dispelled, and each creature you choose there makes a Con save, 2d10 + Cleric level Radiant, half on a success.
func _radiance(c: Combatant) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	ch.spend_resource("channel_divinity")
	e.spend_action(c)
	c.magic_action_used = true
	var r := CombatResult.new()
	for o in e.spells.zones.live():
		if bool(o.rule("darkness", false)):
			for cell in o.cells:
				if e.grid.distance_ft(c.cell, c.size_cells, cell, 1) <= 30:
					o.ended = true
					break
	e.spells.zones.prune()
	var cells := e.grid.area_cells("emanation", 30, e.center_of(c), Vector2.RIGHT, 5, c.cell, c.size_cells)
	e.events.append({"type": "spell", "caster": c.id, "spell": "radiance_of_the_dawn", "cells": cells, "targets": []})
	var dc := f()._cleric_dc(c)
	var rolled := e._roll_damage_dice("2d10+%d" % ch.class_level_of("cleric"), false, 0, "Radiance of the Dawn")
	e.log.add("spell", "%s unleashes the Radiance of the Dawn" % c.name(), c.id)
	for o2 in e.hostiles_of(c):
		if e.distance(c, o2) > 30:
			continue
		var dis: Array[String] = []
		if e.in_sunlight(o2) and c.creature.has_flag("corona"):
			dis.append("Corona of Light")
		var test := o2.creature.roll_save(e.dice, &"con", dc, [], dis, "Constitution save vs Radiance of the Dawn (%s)" % o2.name())
		var amount := int(rolled["total"]) / (2 if test.success else 1)
		e.deal_damage(c, o2, [{"amount": amount, "type": "radiant"}], false, "Radiance of the Dawn", [test.describe(), str(rolled["text"])])
	return r


## Breath Weapon (Dragonborn): replaces one attack of the Attack action; a 15-ft Cone or a 30-ft Line, Dex save
## (8 + Con + PB), 1d10 of the ancestry's type (2d10 at 5, 3d10 at 11, 4d10 at 17), half on a success.
func _breath(c: Combatant, shape: String, point: Vector2) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	ch.spend_resource("breath_weapon")
	e.use_one_attack(c)
	var dir := (point - e.center_of(c)).normalized() if point != Vector2.INF else Vector2(c.facing)
	var size := 15 if shape == "cone" else 30
	var origin := e.center_of(c) + dir * (c.size_cells / 2.0)
	var cells := e.grid.area_cells("cone" if shape == "cone" else "line", size, origin, dir, 5)
	var lvl := c.creature.character_level()
	var dice := "%dd10" % (1 + (1 if lvl >= 5 else 0) + (1 if lvl >= 11 else 0) + (1 if lvl >= 17 else 0))
	var ty := "fire"
	for m in c.creature.modifiers_for(&"resistance"):
		if m.source_kind == &"species":
			ty = m.text("value")
	var dc := 8 + c.creature.ability_mod(&"con") + c.creature.proficiency_bonus()
	var rolled := e._roll_damage_dice(dice, false, 0, "Breath Weapon")
	e.events.append({"type": "spell", "caster": c.id, "spell": "breath_weapon", "cells": cells, "targets": []})
	e.log.add("spell", "%s breathes %s (%s, Dex DC %d)" % [c.name(), ty, dice, dc], c.id)
	var r := CombatResult.new()
	for o in e.spells.creatures_in(cells):
		if o == c:
			continue
		var test := o.creature.roll_save(e.dice, &"dex", dc, [], [], "Dexterity save vs Breath Weapon (%s)" % o.name())
		var amount := int(rolled["total"]) / (2 if test.success else 1)
		if test.success and o.creature.has_flag("evasion"):
			amount = 0
		elif not test.success and o.creature.has_flag("evasion"):
			amount = int(rolled["total"]) / 2
		e.deal_damage(c, o, [{"amount": amount, "type": ty}], false, "Breath Weapon", [test.describe(), str(rolled["text"])])
	return r


# --- Hooks ----------------------------------------------------------------------------------------

## Before a D20 Test: Lucky (Advantage, armed by the player), Portent (the foreseen roll replaces the d20), Ambush
## (a Superiority Die on Initiative).
func before_d20(cr: Creature, kind: D20Test.Kind, keys: Array[String], _target: int) -> Dictionary:
	var e := enc()
	var c := e.get_c(cr.id) if e != null else null
	var out := {}
	if c == null:
		return out
	if "tides_of_chaos" in c.armed:
		c.armed.erase("tides_of_chaos")
		out["advantage"] = ["Tides of Chaos"]
	if "lucky" in c.armed and cr is Character and (cr as Character).resource_left("luck_points") > 0:
		c.armed.erase("lucky")
		(cr as Character).spend_resource("luck_points")
		out["advantage"] = ["Lucky"]
	# Sunlight Sensitivity (attacks and checks), Weakness and Hypersensitivity (attacks and checks; Weakness: every
	# D20 Test) for creatures standing in sunlight.
	var sun := e.monster_actions.sunlight(c)
	if sun != "" and e.in_sunlight(c):
		if sun == "weakness" or kind != D20Test.Kind.SAVING_THROW:
			out["disadvantage"] = ["Sunlight"]
	if c.has_meta("portent_next"):
		out["natural"] = int(c.get_meta("portent_next"))
		c.remove_meta("portent_next")
	if kind == D20Test.Kind.ABILITY_CHECK and "initiative" in keys.map(func(k: String) -> String: return k.get_slice(":", 0)):
		pass
	return out


## After a D20 Test: Reliable Talent, Indomitable, Stroke of Luck, Mage Slayer's Guarded Mind, Heroic Inspiration on a
## failed save, Psi-Bolstered Knack and Tactical Mind on failed checks. Player-controlled creatures follow their rule
## for each (default: use it), since a save can't pause the fight.
func after_d20(cr: Creature, t: D20Test, keys: Array[String]) -> void:
	var e := enc()
	if e == null:
		return
	var c := e.get_c(cr.id)
	if c == null:
		return
	e.class_features.after_d20(c, t)
	if not cr is Character:
		return
	# A die someone gave this creature (Bardic Inspiration): added to a failed D20 Test, then gone.
	if not t.success and t.target > 0 and t.kind == D20Test.Kind.SAVING_THROW:
		e.class_features.after_failed_save(c, t, keys)
	if not t.success and t.target > 0:
		for fx: Effect in cr.effects.duplicate():
			for m in fx.modifiers:
				if m.stat == &"inspiration_die" and str(c.reaction_rules.get("inspiration", "auto")) != "never":
					var v := e.dice.roll_expr(m.text("dice", "1d6"), m.source_name)
					t.add_bonus(int(v["total"]), m.source_name)
					cr.remove_effect(fx)
					e.log.add("info", "%s adds %s (%d)" % [c.name(), m.source_name, int(v["total"])], c.id)
					break
			if t.success:
				break
	var ch := cr as Character
	var rule := func(kind: String) -> bool: return str(c.reaction_rules.get(kind, "auto")) != "never"
	if t.kind == D20Test.Kind.ABILITY_CHECK:
		if has(c, "reliable_talent"):
			for k in keys:
				if k.begins_with("check:") and Abilities.SKILLS.has(StringName(k.substr(6))) and ch.skill_rank(StringName(k.substr(6))) > 0:
					t.floor_natural(10, "Reliable Talent")
					break
		if not t.success and t.target > 0 and has(c, "tactical_mind") and ch.resource_left("second_wind") > 0 and rule.call("tactical_mind"):
			var v := e.dice.roll_one(10, "Tactical Mind")
			if t.total + v >= t.target:
				ch.spend_resource("second_wind")
				t.add_bonus(v, "Tactical Mind")
		return
	if t.kind != D20Test.Kind.SAVING_THROW or t.success or t.target <= 0:
		return
	if has(c, "indomitable") and ch.resource_left("indomitable") > 0 and rule.call("indomitable"):
		ch.spend_resource("indomitable")
		var again := D20Test.from_natural(D20Test.Kind.SAVING_THROW, e.dice.d20("Indomitable"), t.modifier + ch.class_level_of("fighter"), t.target)
		t.set_natural(again.kept, "Indomitable")
		t.add_bonus(ch.class_level_of("fighter"), "Indomitable")
		e.log.add("info", "%s refuses to fall: Indomitable reroll" % c.name(), c.id, [t.describe()])
		if t.success:
			return
	if f().has_feat(c, "mage_slayer") and ch.resource_left("guarded_mind") > 0 and ("save:int" in keys or "save:wis" in keys or "save:cha" in keys) and rule.call("guarded_mind"):
		ch.spend_resource("guarded_mind")
		t.add_bonus(maxi(0, t.target - t.total), "Guarded Mind")
		e.log.add("info", "%s's Guarded Mind turns the failure into a success" % c.name(), c.id)
		return
	if has(c, "stroke_of_luck") and ch.resource_left("stroke_of_luck") > 0 and rule.call("stroke_of_luck"):
		ch.spend_resource("stroke_of_luck")
		t.set_natural(20, "Stroke of Luck")
		return
	if ch.heroic_inspiration and str(c.reaction_rules.get("heroic_inspiration", "ask")) != "never":
		ch.heroic_inspiration = false
		t.set_natural(e.dice.d20("Heroic Inspiration"), "Heroic Inspiration")
		e.log.add("info", "%s spends Heroic Inspiration on the save" % c.name(), c.id, [t.describe()])


## Start of a creature's turn: Heroic Warrior, Survivor, Unarmed Fighting's grapple damage.
func turn_start(c: Combatant) -> void:
	var e := enc()
	if not c.creature is Character:
		return
	var ch := c.creature as Character
	c.has_acted = true
	if has(c, "heroic_warrior") and not ch.heroic_inspiration:
		ch.heroic_inspiration = true
		e.log.add("info", "%s gains Heroic Inspiration (Heroic Warrior)" % c.name(), c.id)
	if has(c, "survivor") and c.creature.hp > 0 and c.creature.is_bloodied():
		var healed := c.creature.heal(5 + c.creature.ability_mod(&"con"), "Survivor")
		if healed > 0:
			e.log.add("heal", "%s regains %d Hit Points (Survivor)" % [c.name(), healed], c.id)
	if f().has_feat(c, "unarmed_fighting"):
		for k: String in e.grapples.keys():
			if str(e.grapples[k]) == c.id:
				var t := e.get_c(k)
				if t != null and t.is_alive():
					var rolled := e._roll_damage_dice("1d4", false, 0, "Unarmed Fighting")
					e.deal_damage(c, t, [{"amount": int(rolled["total"]), "type": "bludgeoning"}], false, "Unarmed Fighting")


## End of a creature's turn: Celestial Revelation's Inner Radiance.
func turn_end(c: Combatant) -> void:
	var e := enc()
	if c.creature.has_flag("inner_radiance"):
		for o in e.living():
			if o != c and e.distance(c, o) <= 10 and not o.is_down():
				e.deal_damage(c, o, [{"amount": c.creature.proficiency_bonus(), "type": "radiant"}], false, "Inner Radiance")


## A creature would drop to 0 Hit Points without dying outright: Relentless Endurance (Orc), Boon of Recovery's Last
## Stand. True if it stays up.
func on_zero(c: Combatant) -> bool:
	if not c.creature is Character:
		return false
	var ch := c.creature as Character
	var e := enc()
	if c.creature.has_flag("relentless_endurance") and ch.resource_left("relentless_endurance") > 0:
		ch.spend_resource("relentless_endurance")
		_back_up(c, 1)
		e.log.add("info", "%s refuses to fall: Relentless Endurance (1 Hit Point)" % c.name(), c.id)
		return true
	if f().has_feat(c, "boon_of_recovery") and ch.resource_left("last_stand") > 0:
		ch.spend_resource("last_stand")
		_back_up(c, 1)
		c.creature.heal(c.creature.max_hp() / 2, "Last Stand")
		e.log.add("info", "%s makes a Last Stand" % c.name(), c.id)
		return true
	return false


func _back_up(c: Combatant, hp: int) -> void:
	c.creature.hp = hp
	c.creature.remove_condition(&"unconscious", "0 Hit Points")
	c.creature.death_failures = 0
	c.creature.death_successes = 0
	c.creature.stable = false


## Damage about to be dealt: Heavy Armor Master (B/P/S from attacks −PB in Heavy armor), Elemental Adept and Boon of
## Irresistible Offense (ignore Resistance), Abjurer's Spell Resistance. Changes `parts` in place.
func adjust_incoming(source: Combatant, target: Combatant, parts: Array) -> void:
	var t_ch := target.creature as Character if target.creature is Character else null
	if t_ch != null and f().has_feat(target, "heavy_armor_master") and str(t_ch.armor_situation().get("armor", "")) == "heavy":
		for p: Variant in parts:
			var d := p as Dictionary
			if bool(d.get("weapon", false)) and str(d["type"]) in ["bludgeoning", "piercing", "slashing"]:
				d["amount"] = maxi(0, int(d["amount"]) - target.creature.proficiency_bonus())
	if source != null and f().has_feat(source, "boon_of_irresistible_offense"):
		for p2: Variant in parts:
			var d2 := p2 as Dictionary
			if str(d2["type"]) in ["bludgeoning", "piercing", "slashing"]:
				d2["ignore_resistance"] = true
				d2["ignore_source"] = "Overcome Defenses"
	if source != null and f().has_feat(source, "elemental_adept"):
		var chosen := (source.creature as Character).picks_for("elemental_adept.energy_mastery") if source.creature is Character else []
		for p3: Variant in parts:
			var d3 := p3 as Dictionary
			if bool(d3.get("spell", false)) and str(d3["type"]) in chosen:
				d3["ignore_resistance"] = true
				d3["ignore_source"] = "Elemental Adept"
	if has(target, "spell_resistance"):
		for p4: Variant in parts:
			var d4 := p4 as Dictionary
			if bool(d4.get("spell", false)):
				d4["amount"] = int(d4["amount"]) / 2
