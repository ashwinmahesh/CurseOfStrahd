class_name CombatFeatures
extends RefCounted
## Class features used in combat (plan §5.3): Sneak Attack, Second Wind, Action Surge, Cunning Action (through
## the encounter's Dash, Disengage and Hide), Steady Aim, and Channel Divinity (Divine Spark, Turn Undead with Sear
## Undead, Preserve Life). Each returns a CombatResult like the encounter's own actions.

var _enc: WeakRef
## Sneak Attack is once per turn, any creature's turn: creature id -> the turn it was used on.
var _sneak_turn: Dictionary = {}


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


static func has_feature(c: Combatant, feature_id: String) -> bool:
	if not c.creature is Character:
		return false
	for f in (c.creature as Character).features:
		if str(f["id"]) == feature_id:
			return true
	return false


## A feat the creature took (by feat id; benefit ids can repeat across feats, e.g. "parry").
func has_feat(c: Combatant, feat_id: String) -> bool:
	if not c.creature is Character:
		return false
	for f in (c.creature as Character).feats_taken:
		if str(f["id"]) == feat_id:
			return true
	return false


func knows_maneuver(c: Combatant, maneuver_id: String) -> bool:
	return c.creature is Character and maneuver_id in (c.creature as Character).maneuvers


## The Battle Master's Superiority Die size (8, 10, 12), or 0.
func superiority_die(c: Combatant) -> int:
	return _die_from(c, "fighter", "superiority_die")


## The Psi Warrior's or Soulknife's Psionic Energy Die size, or 0.
func psionic_die(c: Combatant) -> int:
	var d := _die_from(c, "fighter", "psionic_energy_die")
	return d if d > 0 else _die_from(c, "rogue", "psionic_energy_die")


func _die_from(c: Combatant, class_id: String, column: String) -> int:
	if not c.creature is Character:
		return 0
	var v: Variant = (c.creature as Character).class_column(class_id, column)
	var text := str(v) if v != null else ""
	return int(text.substr(1)) if text.begins_with("d") else 0


func wields_shield(c: Combatant) -> bool:
	if not c.creature is Character:
		return false
	var off := (c.creature as Character).equipped("off_hand")
	return not off.is_empty() and str(off.get("category", "")) == "shield"


func holds_weapon(c: Combatant) -> bool:
	if not c.creature is Character:
		return false
	return not (c.creature as Character).equipped("main_hand").is_empty()


func holds_finesse(c: Combatant) -> bool:
	if not c.creature is Character:
		return false
	for slot: String in ["main_hand", "off_hand"]:
		if "finesse" in Gear.weapon_props((c.creature as Character).equipped(slot)):
			return true
	return false


## The DC for Battle Master maneuvers, Cunning Strike and similar: 8 + the better of Str/Dex (or `ability`) + PB.
func maneuver_dc(c: Combatant, ability: StringName = &"") -> int:
	var mod := c.creature.ability_mod(ability) if ability != &"" else maxi(c.creature.ability_mod(&"str"), c.creature.ability_mod(&"dex"))
	return 8 + mod + c.creature.proficiency_bonus()


func _turn_key() -> String:
	return "%d:%d" % [enc().round_no, enc().turn_index]


# --- Rogue ----------------------------------------------------------------------------------------

## Sneak Attack dice for this hit, or "" (2024): once per turn, a Finesse or Ranged weapon, and Advantage on the
## roll, or an ally of yours within 5 ft of the target who isn't Incapacitated and no Disadvantage.
func sneak_attack_dice(c: Combatant, target: Combatant, option: Dictionary, t: D20Test) -> String:
	if not c.creature is Character or not has_feature(c, "sneak_attack"):
		return ""
	if str(_sneak_turn.get(c.id, "")) == _turn_key():
		return ""
	var p := option["profile"] as WeaponProfile
	var ranged_weapon := not p.melee and not p.thrown
	if not "finesse" in p.properties and not ranged_weapon:
		return ""
	var ok := t.advantage
	if not ok and not t.disadvantage:
		for a in enc().allies_of(c):
			if a != target and a.can_act() and enc().distance(a, target) <= 5:
				ok = true
				break
	if not ok:
		return ""
	var dice: Variant = (c.creature as Character).class_column("rogue", "sneak_attack")
	if dice == null:
		return ""
	_sneak_turn[c.id] = _turn_key()
	return str(dice)


## Whether Sneak Attack could still apply this turn (for the HUD).
func sneak_attack_ready(c: Combatant) -> bool:
	return has_feature(c, "sneak_attack") and str(_sneak_turn.get(c.id, "")) != _turn_key()


## Steady Aim (Rogue 3): a Bonus Action if you haven't moved this turn; Advantage on your next attack roll this
## turn, and your Speed is 0 until the end of the turn.
func steady_aim(c: Combatant) -> CombatResult:
	var e := enc()
	var why := e._bonus_check(c)
	if why != "":
		return CombatResult.fail(why)
	if not has_feature(c, "steady_aim"):
		return CombatResult.fail("%s doesn't have Steady Aim" % c.name())
	if c.moved:
		return CombatResult.fail("Steady Aim needs you not to have moved this turn")
	c.bonus_available = false
	# Roving Aim (Assassin 9, in Infiltration Expertise): Steady Aim no longer stops you.
	if not has_feature(c, "infiltration_expertise"):
		c.movement_left = 0
		var fx := Effect.new("Steady Aim", &"feature", "steady_aim").with_modifier("speed_set", {"value": 0})
		fx.ends = Effect.Ends.END_OF_TURN
		fx.turn_owner_id = c.id
		c.creature.add_effect(fx)
	e.add_mark({"kind": "advantage_next_attack", "attacker": c.id, "source": "Steady Aim",
		"expires_owner": c.id, "expires_phase": "end", "consume": true})
	e.log.add("info", "%s takes Steady Aim: Advantage on the next attack, Speed 0" % c.name(), c.id)
	return CombatResult.new()


# --- Fighter --------------------------------------------------------------------------------------

## Second Wind (Fighter 1): a Bonus Action to regain 1d10 + Fighter level Hit Points.
func second_wind(c: Combatant) -> CombatResult:
	var e := enc()
	var why := e._bonus_check(c)
	if why != "":
		return CombatResult.fail(why)
	var ch := c.creature as Character if c.creature is Character else null
	if ch == null or ch.resource_left("second_wind") <= 0:
		return CombatResult.fail("No uses of Second Wind left")
	ch.spend_resource("second_wind")
	c.bonus_available = false
	var level := ch.class_level_of("fighter")
	var rolled := e.heal_roll("1d10+%d" % level, c, "Second Wind")
	var healed := ch.heal(int(rolled["total"]), "Second Wind")
	var r := CombatResult.new()
	# Tactical Shift (Fighter 5): move up to half Speed without provoking Opportunity Attacks.
	if has_feature(c, "tactical_shift"):
		c.free_move_ft = maxi(c.free_move_ft, c.speed() / 2)
	r.lines.append(e.log.add("heal", "%s catches a Second Wind and regains %d Hit Points" % [c.name(), healed], c.id,
		["Second Wind 1d10 + Fighter level %d: %s" % [level, rolled["text"]]]))
	e.events.append({"type": "heal", "id": c.id, "amount": healed})
	return r


## Action Surge (Fighter 2): one more action this turn (not the Magic action).
func action_surge(c: Combatant) -> CombatResult:
	var e := enc()
	var why := e._turn_check(c)
	if why != "":
		return CombatResult.fail(why)
	var ch := c.creature as Character if c.creature is Character else null
	if ch == null or ch.resource_left("action_surge") <= 0:
		return CombatResult.fail("No uses of Action Surge left")
	if c.surged:
		return CombatResult.fail("Action Surge already used this turn")
	if not c.can_act():
		return CombatResult.fail("%s can't act" % c.name())
	ch.spend_resource("action_surge")
	c.surged = true
	if c.action_available:
		c.extra_actions += 1
	else:
		c.action_available = true
		c.attacks_left = 0
	e.log.add("info", "%s uses Action Surge: one more action this turn" % c.name(), c.id)
	return CombatResult.new()


# --- Cleric ---------------------------------------------------------------------------------------

func _channel_check(c: Combatant) -> String:
	var why := enc()._action_check(c)
	if why != "":
		return why
	var ch := c.creature as Character if c.creature is Character else null
	if ch == null or ch.resource_left("channel_divinity") <= 0:
		return "No uses of Channel Divinity left"
	if c.magic_action_used:
		return "Only one Magic action this turn (Action Surge's action can't be Magic)"
	return ""


func _spend_channel(c: Combatant) -> void:
	(c.creature as Character).spend_resource("channel_divinity")
	enc().spend_action(c)
	c.magic_action_used = true
	if c.hidden:
		enc().reveal(c, "used Channel Divinity")


func _cleric_dc(c: Combatant) -> int:
	return (c.creature as Character).spell_save_dc("cleric").total()


## Divine Spark (Cleric 2): a creature within 30 ft regains 1d8 + Wisdom modifier Hit Points, or makes a
## Constitution save against Necrotic or Radiant damage of that amount (half on a success).
func divine_spark(c: Combatant, target: Combatant, harm: bool, damage_type: String = "radiant") -> CombatResult:
	var e := enc()
	var why := _channel_check(c)
	if why != "":
		return CombatResult.fail(why)
	if not has_feature(c, "channel_divinity"):
		return CombatResult.fail("%s can't Channel Divinity" % c.name())
	if target == null or e.distance(c, target) > 30 or (target != c and int(e.cover(c, target)["cover"]) == CombatGrid.Cover.TOTAL):
		return CombatResult.fail("Choose a creature within 30 ft that you can see")
	_spend_channel(c)
	var level := c.creature.class_level_of("cleric")
	var count := 1 + (1 if level >= 7 else 0) + (1 if level >= 13 else 0) + (1 if level >= 18 else 0)
	var wis := c.creature.ability_mod(&"wis")
	var rolled := e._roll_damage_dice("%dd8" % count, false, 0 if harm else e.heal_floor(target), "Divine Spark")
	var amount := maxi(0, int(rolled["total"]) + wis)
	var text := "Divine Spark %dd8 + Wis %d: %s" % [count, wis, rolled["text"]]
	var r := CombatResult.new()
	if not harm:
		amount = maxi(amount, e.ravenloft.return_to_life(c, target, "%dd8" % count, int(rolled["total"])) + wis)
		var healed := target.creature.heal(amount, "Divine Spark")
		r.lines.append(e.log.add("heal", "%s's Divine Spark restores %d Hit Points to %s" % [c.name(), healed, target.name()], c.id, [text]))
		e.events.append({"type": "heal", "id": target.id, "amount": healed})
		return r
	var dc := _cleric_dc(c)
	var s := target.creature.roll_save(e.dice, &"con", dc, [], [], "Constitution save vs Divine Spark (%s)" % target.name())
	if s.success:
		amount /= 2
	var ty := damage_type if damage_type in ["radiant", "necrotic"] else "radiant"
	e.events.append({"type": "spell", "caster": c.id, "spell": "divine_spark", "cells": [], "targets": [target.id]})
	e.deal_damage(c, target, [{"amount": amount, "type": ty}], false, "Divine Spark", [s.describe(), text])
	return r


## Turn Undead (Cleric 2): each Undead enemy within 30 ft makes a Wisdom save or is Frightened and Incapacitated for
## 1 minute, fleeing from you; it ends early if the creature takes damage. Sear Undead (Cleric 5) adds Radiant
## damage (Wisdom modifier d8s, minimum one) to each creature that fails.
func turn_undead(c: Combatant) -> CombatResult:
	var e := enc()
	var why := _channel_check(c)
	if why != "":
		return CombatResult.fail(why)
	if not has_feature(c, "channel_divinity"):
		return CombatResult.fail("%s can't Channel Divinity" % c.name())
	var targets: Array[Combatant] = []
	for h in e.hostiles_of(c):
		if str(h.creature.creature_type) == "undead" and not h.is_down() and e.distance(c, h) <= 30:
			targets.append(h)
	if targets.is_empty():
		return CombatResult.fail("No Undead enemies within 30 ft")
	_spend_channel(c)
	var dc := _cleric_dc(c)
	var r := CombatResult.new()
	e.log.add("spell", "%s presents a holy symbol: Turn Undead (DC %d)" % [c.name(), dc], c.id)
	e.events.append({"type": "spell", "caster": c.id, "spell": "turn_undead", "cells": [],
		"targets": targets.map(func(t: Combatant) -> String: return t.id)})
	var sear := has_feature(c, "sear_undead")
	var sear_total := 0
	var sear_text := ""
	if sear:
		var n := maxi(1, c.creature.ability_mod(&"wis"))
		var rolled := e._roll_damage_dice("%dd8" % n, false, 0, "Sear Undead")
		sear_total = int(rolled["total"])
		sear_text = "Sear Undead %dd8: %s" % [n, rolled["text"]]
	for t in targets:
		var s := t.creature.roll_save(e.dice, &"wis", dc, [], [], "Wisdom save vs Turn Undead (%s)" % t.name())
		if s.success:
			r.lines.append(e.log.add("info", "%s resists the turning" % t.name(), t.id, [s.describe()]))
			continue
		var fx := Effect.new("Turned", &"feature", "turn_undead").with_condition(&"frightened").with_condition(&"incapacitated")
		fx.caster_id = c.id
		fx.lasting_rounds(10, c.id)
		fx.ends_on_damage = true
		fx.stack_key = "turn_undead:%s" % t.id
		if t.creature.add_effect(fx):
			r.lines.append(e.log.add("condition", "%s is Turned: Frightened and Incapacitated, fleeing %s" % [t.name(), c.name()], t.id, [s.describe()]))
			e.events.append({"type": "condition", "id": t.id})
		if sear and sear_total > 0:
			# Sear Undead's damage doesn't end the turning: deal it before the effect can see it.
			fx.ends_on_damage = false
			e.deal_damage(c, t, [{"amount": sear_total, "type": "radiant"}], false, "Sear Undead", [sear_text])
			fx.ends_on_damage = true
	return r


## Ends turning from a cleric who is down, Incapacitated or dead (2024: the effect ends early then).
func end_turning_from(cleric: Combatant) -> void:
	for o in enc().combatants:
		for fx: Effect in o.creature.effects.duplicate():
			if fx.source_id == "turn_undead" and fx.caster_id == cleric.id:
				o.creature.remove_effect(fx)
				enc().log.add("info", "%s is no longer Turned" % o.name(), o.id)


## The creature an effect makes `c` flee from (Turn Undead), or null.
func fleeing_from(c: Combatant) -> Combatant:
	for fx: Effect in c.creature.effects:
		if fx.source_id == "turn_undead":
			return enc().get_c(fx.caster_id)
		for m in fx.modifiers:
			if m.stat == &"flag" and m.text("value") == "fear_flee":
				return enc().get_c(fx.caster_id)
	return null


## Preserve Life (Life Domain 3): restore 5 × Cleric level Hit Points, divided among Bloodied creatures within
## 30 ft (you included), none raised above half its Hit Point maximum. `allocation` maps creature id -> HP; empty
## spreads it to the most hurt first.
func preserve_life(c: Combatant, allocation: Dictionary = {}) -> CombatResult:
	var e := enc()
	var why := _channel_check(c)
	if why != "":
		return CombatResult.fail(why)
	if not has_feature(c, "preserve_life"):
		return CombatResult.fail("%s doesn't have Preserve Life" % c.name())
	var pool := 5 * c.creature.class_level_of("cleric")
	var room := preserve_life_room(c)
	if room.is_empty():
		return CombatResult.fail("No Bloodied creatures within 30 ft")
	var plan := {}
	if allocation.is_empty():
		var ids: Array = room.keys()
		ids.sort_custom(func(a: String, b: String) -> bool:
			var ca := e.get_c(a).creature
			var cb := e.get_c(b).creature
			return float(ca.hp) / maxi(1, ca.max_hp()) < float(cb.hp) / maxi(1, cb.max_hp()))
		var left := pool
		for id: String in ids:
			var give := mini(left, int(room[id]))
			if give > 0:
				plan[id] = give
				left -= give
	else:
		var total := 0
		for id: String in allocation:
			if not room.has(id):
				return CombatResult.fail("%s isn't a Bloodied creature within 30 ft" % e.get_c(id).name())
			if int(allocation[id]) > int(room[id]):
				return CombatResult.fail("%s can regain at most %d (half its maximum)" % [e.get_c(id).name(), room[id]])
			total += int(allocation[id])
		if total > pool:
			return CombatResult.fail("Preserve Life has %d Hit Points to share" % pool)
		plan = allocation
	_spend_channel(c)
	var r := CombatResult.new()
	var parts: Array[String] = []
	for id: String in plan:
		var t := e.get_c(id)
		var healed := t.creature.heal(int(plan[id]), "Preserve Life")
		parts.append("%s +%d" % [t.name(), healed])
		e.events.append({"type": "heal", "id": t.id, "amount": healed})
	r.lines.append(e.log.add("heal", "%s uses Preserve Life: %s" % [c.name(), ", ".join(parts)], c.id,
		["Pool 5 × Cleric level = %d; nobody above half their Hit Point maximum" % pool]))
	return r


## Bloodied creatures within 30 ft and how much each can regain from Preserve Life: id -> HP.
func preserve_life_room(c: Combatant) -> Dictionary:
	var out := {}
	for o in enc().combatants:
		if o.creature.dead or not (o == c or c.allied_with(o)) or enc().distance(c, o) > 30:
			continue
		if not o.creature.is_bloodied():
			continue
		var room := o.creature.max_hp() / 2 - o.creature.hp
		if room > 0:
			out[o.id] = room
	return out


# --- Riders on a hit (armed by the player before the attack) ----------------------------------------

## Riders a creature can arm for its next hit: {id, label, sub, cost, group, help}. Battle Master maneuvers that
## trigger on a hit (one per hit, a Superiority Die each), Cunning Strike effects (paid with Sneak Attack dice),
## the Goliath's Giant Ancestry boons, the Psi Warrior's Psionic Strike, Tactical Master's mastery swap, and toggles
## for optional masteries (Push, Topple).
const HIT_MANEUVERS := {
	"disarming_attack": ["Disarming Attack", "Str save or drop what it holds"],
	"distracting_strike": ["Distracting Strike", "next ally attack has Advantage"],
	"goading_attack": ["Goading Attack", "Wis save or Disadvantage against others"],
	"menacing_attack": ["Menacing Attack", "Wis save or Frightened"],
	"pushing_attack": ["Pushing Attack", "Str save or pushed 15 ft"],
	"trip_attack": ["Trip Attack", "Str save or Prone"],
	"sweeping_attack": ["Sweeping Attack", "the die hits a second foe"],
	"maneuvering_attack": ["Maneuvering Attack", "an ally moves clear of the target"],
	"lunging_attack": ["Lunging Attack", "after moving 5 ft: +die"],
	"feinting_attack": ["Feinting Attack", "+die (after a feint)"],
}
const CUNNING := {
	"poison": ["Poison", 1, "Con save or Poisoned 1 min", 5],
	"trip": ["Trip", 1, "Dex save or Prone", 5],
	"withdraw": ["Withdraw", 1, "move half Speed, no Opportunity Attacks", 5],
	"stealth_attack": ["Stealth Attack", 1, "stay hidden behind cover", 9],
	"daze": ["Daze", 2, "Con save or Dazed", 14],
	"knock_out": ["Knock Out", 6, "Con save or Unconscious 1 min", 14],
	"obscure": ["Obscure", 3, "Dex save or Blinded", 14],
	"terrify": ["Terrify", 1, "Wis save or Frightened 1 min", 9],
}


func rider_options(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not c.creature is Character:
		return out
	var ch := c.creature as Character
	var die := superiority_die(c)
	if die > 0:
		for id: String in HIT_MANEUVERS:
			if knows_maneuver(c, id):
				var why := "" if ch.resource_left("superiority_dice") > 0 else "No Superiority Dice left"
				out.append({"id": "maneuver:" + id, "label": HIT_MANEUVERS[id][0], "sub": "d%d · %s" % [die, HIT_MANEUVERS[id][1]], "why": why})
	if has_feature(c, "cunning_strike"):
		var lvl := ch.class_level_of("rogue")
		for id: String in CUNNING:
			var row := CUNNING[id] as Array
			if lvl < int(row[3]):
				continue
			if id == "stealth_attack" and not has_feature(c, "supreme_sneak"):
				continue
			if int(row[3]) == 14 and not has_feature(c, "devious_strikes"):
				continue
			# Scion of the Three's Strike Fear adds Terrify.
			if id == "terrify" and not has_feature(c, "scion_strike_fear"):
				continue
			var why2 := ""
			if id == "poison" and enc().item_count(c, "poisoners_kit") <= 0:
				why2 = "Needs a Poisoner's Kit"
			out.append({"id": "cunning:" + id, "label": "Cunning Strike: %s" % row[0], "sub": "−%dd6 Sneak Attack · %s" % [row[1], row[2]], "why": why2})
	for id: String in ["fires_burn", "frosts_chill", "hills_tumble"]:
		if has_feature(c, id):
			var why3 := "" if ch.resource_left("giant_ancestry") > 0 else "No Giant Ancestry uses left"
			var sub := {"fires_burn": "+1d10 Fire", "frosts_chill": "+1d6 Cold, −10 ft Speed", "hills_tumble": "knock Prone"}[id] as String
			out.append({"id": "giant:" + id, "label": id.replace("_", " ").capitalize().replace("s ", "'s "), "sub": sub, "why": why3})
	var pdie := psionic_die(c)
	if pdie > 0 and ch.subclasses.get("fighter", "") == "psi_warrior":
		var why4 := "" if ch.resource_left("psionic_energy") > 0 else "No Psionic Energy Dice left"
		out.append({"id": "psionic_strike", "label": "Psionic Strike", "sub": "+d%d + Int Force" % pdie, "why": why4})
		if has_feature(c, "telekinetic_adept"):
			out.append({"id": "telekinetic_thrust", "label": "Telekinetic Thrust", "sub": "with Psionic Strike: Str save, Prone or pushed 10 ft", "why": why4})
	if has_feature(c, "rend_mind"):
		var rw := "" if ch.resource_left("rend_mind") > 0 or ch.resource_left("psionic_energy") >= 3 else "No uses left"
		out.append({"id": "rend_mind", "label": "Rend Mind", "sub": "Sneak Attack with a blade: Wis save or Stunned", "why": rw})
	# Smite spells (Divine Smite, Searing Smite...): cast as a Bonus Action right after a hit.
	for sp in enc().spells.castable(c):
		var sd := Compendium.shared().spell_data(str(sp["id"]))
		if not bool(sd.get("on_hit_spell", false)):
			continue
		var sw := ""
		if not c.bonus_available:
			sw = "Bonus Action already used"
		elif c.cast_slot_spell_this_turn and int(sd.get("level", 0)) > 0 and not bool(sp["free"]):
			sw = "Already cast a spell with a slot this turn"
		elif int(sd.get("level", 0)) > 0 and not bool(sp["free"]) and enc().spells._lowest_slot(ch, int(sd.get("level", 1))) == 0:
			sw = "No spell slots left"
		out.append({"id": "smite:" + str(sp["id"]), "label": str(sd["name"]), "sub": "on your next hit", "why": sw})
	if has_feature(c, "overchannel"):
		var uses := int(c.get_meta("overchannel_uses", 0))
		out.append({"id": "overchannel", "label": "Overchannel", "sub": "max damage on the next level 1-5 spell%s" % ("" if uses == 0 else " · costs Necrotic damage"), "why": ""})
	if has_feature(c, "tactical_master"):
		for m: String in ["push", "sap", "slow"]:
			out.append({"id": "mastery:" + m, "label": "Tactical Master: %s" % m.capitalize(), "sub": "use %s this hit" % m.capitalize(), "why": ""})
	for o in enc().attack_options(c):
		var mastery := (o["profile"] as WeaponProfile).mastery
		if mastery in ["push", "topple"] and not out.any(func(x: Dictionary) -> bool: return str(x["id"]) == "skip:" + mastery):
			out.append({"id": "skip:" + mastery, "label": "Hold back %s" % mastery.capitalize(), "sub": "don't use the mastery this turn", "why": ""})
	out.append_array(enc().class_features.rider_options(c))
	out.append_array(enc().echo_knight.rider_options(c))
	return out


## Arms or disarms a rider for this turn's hits.
func toggle_rider(c: Combatant, rider_id: String) -> CombatResult:
	var why := enc()._turn_check(c)
	if why != "":
		return CombatResult.fail(why)
	if rider_id in c.armed:
		c.armed.erase(rider_id)
		enc().log.add("info", "%s won't use %s" % [c.name(), rider_id.get_slice(":", 1).replace("_", " ").capitalize()], c.id)
	else:
		if rider_id.begins_with("maneuver:"):
			for a: String in c.armed.duplicate():
				if a.begins_with("maneuver:"):
					c.armed.erase(a)
		if rider_id.begins_with("cunning:"):
			var limit := 2 if has_feature(c, "improved_cunning_strike") else 1
			var mine := c.armed.filter(func(x: String) -> bool: return x.begins_with("cunning:"))
			while mine.size() >= limit:
				c.armed.erase(mine.pop_front())
		c.armed.append(rider_id)
		enc().log.add("info", "%s readies %s for the next hit" % [c.name(), rider_id.get_slice(":", rider_id.get_slice_count(":") - 1).replace("_", " ").capitalize()], c.id)
	return CombatResult.new()


## Cunning Strike: the armed effects' Sneak Attack dice come off the roll ("5d6" → "4d6"). Returns the dice left
## (or "" if none) and records the chosen effects in st["cunning"].
func cunning_strike_cost(c: Combatant, sneak: String, st: Dictionary) -> String:
	var chosen: Array[String] = []
	var p := DiceRoller.parse_expr(sneak)
	var dice := int(p["count"])
	for a in c.armed:
		if not a.begins_with("cunning:"):
			continue
		var id := a.substr(8)
		var cost := int((CUNNING.get(id, ["", 1]) as Array)[1])
		if dice >= cost:
			dice -= cost
			chosen.append(id)
	st["cunning"] = chosen
	for id in chosen:
		c.armed.erase("cunning:" + id)
	return "%dd%d" % [dice, int(p["sides"])] if dice > 0 else ""


func _once(c: Combatant, key: String) -> bool:
	var k := "once_%s" % key
	var turn := _turn_key()
	if str(c.get_meta(k, "")) == turn:
		return false
	c.set_meta(k, turn)
	return true


func _first_round() -> bool:
	return enc().round_no == 1


## Damage dice features add to a hit: the armed maneuver's Superiority Die, Giant Ancestry, Psionic Strike, Divine
## Strike, Celestial Revelation, Assassinate in the first round, Charger, Poisoner's dose.
func hit_damage_dice(c: Combatant, target: Combatant, option: Dictionary, st: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var e := enc()
	var p := option["profile"] as WeaponProfile
	var melee := bool(option["melee"])
	out.append_array(e.class_features.hit_dice(c, target, option, st))
	out.append_array(e.ravenloft.hit_dice(c, target, option, st))
	out.append_array(e.faerun.hit_dice(c, target, option))
	if not c.creature is Character:
		return out
	var ch := c.creature as Character
	# Battle Master: one maneuver per hit, a Superiority Die added to the damage.
	var die := superiority_die(c)
	for a: String in c.armed.duplicate():
		if a.begins_with("maneuver:") and die > 0 and ch.resource_left("superiority_dice") > 0:
			var id := a.substr(9)
			if id == "lunging_attack" and not c.moved:
				continue
			if id in ["lunging_attack", "sweeping_attack"] and not melee:
				continue
			ch.spend_resource("superiority_dice")
			c.armed.erase(a)
			st["maneuver"] = id
			st["sup_die"] = die
			if id != "sweeping_attack":
				out.append({"dice": "1d%d" % die, "type": str(p.damage_type), "label": HIT_MANEUVERS[id][0]})
			break
	for a: String in c.armed.duplicate():
		if a.begins_with("giant:") and ch.resource_left("giant_ancestry") > 0:
			var gid := a.substr(6)
			ch.spend_resource("giant_ancestry")
			c.armed.erase(a)
			st["giant"] = gid
			if gid == "fires_burn":
				out.append({"dice": "1d10", "type": "fire", "label": "Fire's Burn"})
			elif gid == "frosts_chill":
				out.append({"dice": "1d6", "type": "cold", "label": "Frost's Chill"})
			break
	var pdie := psionic_die(c)
	if "psionic_strike" in c.armed and pdie > 0 and ch.resource_left("psionic_energy") > 0 and e.distance(c, target) <= 30 and _once(c, "psionic_strike"):
		ch.spend_resource("psionic_energy")
		c.armed.erase("psionic_strike")
		out.append({"dice": "1d%d+%d" % [pdie, maxi(0, c.creature.ability_mod(&"int"))], "type": "force", "label": "Psionic Strike"})
		st["psionic_strike"] = true
	if has_feature(c, "blessed_strikes") and ch.picks_for("blessed_strikes").has("divine_strike") or has_feature(c, "divine_strike"):
		if e.current() == c and _once(c, "divine_strike"):
			var n := 2 if has_feature(c, "improved_blessed_strikes") else 1
			out.append({"dice": "%dd8" % n, "type": "radiant", "label": "Divine Strike"})
	if c.creature.has_flag("celestial_revelation") and _once(c, "celestial_revelation"):
		var cr_type := "necrotic" if c.creature.has_flag("necrotic_shroud") else "radiant"
		out.append({"dice": str(c.creature.proficiency_bonus()), "type": cr_type, "label": "Celestial Revelation"})
	if has_feature(c, "assassinate") and _first_round() and st.has("sneak"):
		out.append({"dice": str(ch.class_level_of("rogue")), "type": str(p.damage_type), "label": "Assassinate"})
	if has_feat(c, "charger") and melee and c.moved and e.current() == c and _once(c, "charger"):
		out.append({"dice": "1d8", "type": str(p.damage_type), "label": "Charge"})
	# An armed smite spell: cast now (a Bonus Action and a slot); its dice join the hit's.
	var sctx := cast_armed_smite(c, melee, false)
	if not sctx.is_empty():
		e.events.append({"type": "smite", "caster": c.id, "spell": str((sctx["s"] as Dictionary)["id"]), "target": target.id})
		st["smite_ctx"] = sctx
		var sd := sctx["s"] as Dictionary
		# Lightning Arrow: the bolt replaces the attack's own damage.
		if bool(sd.get("replaces_weapon_damage", false)):
			st["replace_weapon_damage"] = true
		out.append_array(smite_dice(sctx, target))
	if c.has_meta("poisoned_weapon") and _once(c, "poison_dose"):
		c.remove_meta("poisoned_weapon")
		st["poison_dose"] = true
	return out


## Casts the smite spell `c` armed, if this hit (or miss, for spells with `on_miss_too`) qualifies: a melee or
## ranged weapon as the spell needs, a Bonus Action and a slot left, no other slot spell this turn. Returns its
## casting context, or {}.
func cast_armed_smite(c: Combatant, melee: bool, missed: bool) -> Dictionary:
	var e := enc()
	if not c.creature is Character:
		return {}
	var ch := c.creature as Character
	for a: String in c.armed.duplicate():
		if not a.begins_with("smite:"):
			continue
		var sid := a.substr(6)
		var sd := Compendium.shared().spell_data(sid)
		if bool(sd.get("on_hit_melee_only", true)) and not melee:
			continue
		if bool(sd.get("on_hit_ranged_only", false)) and melee:
			continue
		if missed and not bool(sd.get("on_miss_too", false)):
			continue
		if not c.bonus_available:
			return {}
		var lvl := int(sd.get("level", 1))
		var free := false
		for k in e.spells.castable(c):
			if str(k["id"]) == sid and bool(k["free"]):
				free = true
		var slot := lvl if free else e.spells._lowest_slot(ch, lvl)
		if slot == 0 or (c.cast_slot_spell_this_turn and not free):
			return {}
		c.armed.erase(a)
		c.bonus_available = false
		if free:
			ch.spend_resource("spell:%s" % sid)
		else:
			ch.expend_slot(slot)
			c.cast_slot_spell_this_turn = true
		var conc: Concentration = null
		if bool((sd.get("duration", {}) as Dictionary).get("concentration", false)):
			conc = c.creature.begin_concentration(sid, str(sd["name"]))
		e.spells.trigger_ends(c, "cast_spell")
		e.log.add("spell", "%s casts %s on the %s (level %d)" % [c.name(), sd["name"], "miss" if missed else "hit", slot], c.id)
		return {"c": c, "s": sd, "slot": slot, "nums": e.spells.numbers(c, e.spells._entry_any(c, sid)), "conc": conc, "opts": {},
			"choice": SpellCaster.choice_of(sd, {})}
	return {}


## The extra dice a smite spell adds to the hit: its damage with the slot's extra dice, plus Divine Smite's die
## against Fiends and Undead.
func smite_dice(sctx: Dictionary, target: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var sd := sctx["s"] as Dictionary
	var slot := int(sctx["slot"])
	var lvl := int(sd.get("level", 1))
	for part: Variant in sd.get("damage", []):
		var pd := part as Dictionary
		var base := DiceRoller.parse_expr(str(pd.get("dice", "0")))
		var n := int(base["count"])
		var up := str((sd.get("upcast", {}) as Dictionary).get("damage", ""))
		if up != "" and slot > lvl:
			n += int(DiceRoller.parse_expr(up)["count"]) * (slot - lvl)
		out.append({"dice": "%dd%d" % [n, int(base["sides"])], "type": str(pd.get("type", enc().spells._damage_type(sctx, pd))), "label": str(sd["name"])})
	var vs := sd.get("damage_bonus_vs", {}) as Dictionary
	if not vs.is_empty() and str(target.creature.creature_type) in (vs.get("types", []) as Array):
		out.append({"dice": str(vs.get("dice", "1d8")), "type": str((sd.get("damage", [{}]) as Array)[0].get("type", "radiant")), "label": "%s (%s)" % [sd["name"], target.creature.creature_type]})
	return out


## What a smite spell does after its hit (or miss) lands: a burst around the target (Hail of Thorns, Lightning
## Arrow), a saving throw against its effects (Thunderous, Wrathful, Staggering Smite, Ensnaring Strike), or effects
## that simply land (Searing, Shining, Blinding Smite).
func smite_follow_up(sctx: Dictionary, target: Combatant, alive: bool, r: CombatResult) -> void:
	var e := enc()
	var sd := sctx["s"] as Dictionary
	# Banishing Smite: a target left at 50 Hit Points or fewer makes a Charisma save or is banished.
	if sd.has("banish_at_hp"):
		if alive and target.creature.hp <= int(sd["banish_at_hp"]):
			e.spells.specials.banish(sctx, target, r)
		e.spells._finish_concentration(sctx)
		return
	if sd.has("secondary"):
		e.spells._secondary(sctx, target, r)
	elif alive and sd.has("save"):
		var sub := sctx.duplicate()
		var s2 := sd.duplicate()
		s2.erase("damage")
		sub["s"] = s2
		var one: Array[Combatant] = [target]
		e.spells._save_spell(sub, one, r)
	elif alive:
		e.spells.apply_effect_entries(sctx, target, sd.get("effects", []) as Array, "hit", r)
	e.spells._finish_concentration(sctx)


## Flat damage bonuses: Great Weapon Master's Heavy Weapon Mastery (+PB on a Heavy weapon hit in the Attack
## action), Rage-like bonuses later.
func flat_damage_bonus(c: Combatant, _target: Combatant, option: Dictionary, st: Dictionary, notes: Array[String]) -> int:
	var p := option["profile"] as WeaponProfile
	var bonus := 0
	if has_feat(c, "great_weapon_master") and "heavy" in p.properties and c.took_attack_action and not bool((st["opts"] as Dictionary).get("reaction", false)):
		bonus += c.creature.proficiency_bonus()
		notes.append("Great Weapon Master +%d" % c.creature.proficiency_bonus())
	bonus += enc().class_features.flat_bonus(c, _target, option, notes)
	bonus += enc().ravenloft.flat_bonus(c, _target, option, notes)
	return bonus


## Rerolls on damage dice: Tavern Brawler (Unarmed Strike 1s), Piercer (one Piercing die once per turn).
func damage_reroll_rule(c: Combatant, p: WeaponProfile, entry: Dictionary) -> Dictionary:
	if not bool(entry.get("weapon", false)):
		return {}
	if has_feat(c, "tavern_brawler") and p.item_id == "unarmed_strike":
		return {"count": 99, "at_most": 1, "source": "Tavern Brawler"}
	if has_feat(c, "piercer") and str(p.damage_type) == "piercing" and _once(c, "piercer"):
		var sides := int(DiceRoller.parse_expr(str(entry["dice"]))["sides"])
		return {"count": 1, "at_most": sides / 2, "source": "Piercer"}
	return {}


## After a miss: Studied Attacks (Fighter 13).
func after_miss(c: Combatant, target: Combatant, option: Dictionary, r: CombatResult) -> void:
	var e := enc()
	# Lightning Arrow on a miss: half the bolt's damage to the target, then the burst.
	if str(option.get("kind", "")) in ["weapon", "thrown"] and not bool(option.get("melee", true)):
		var sctx := cast_armed_smite(c, false, true)
		if not sctx.is_empty():
			e.events.append({"type": "smite", "caster": c.id, "spell": str((sctx["s"] as Dictionary)["id"]), "target": target.id})
			var total := 0
			var texts: Array[String] = []
			var ty := "lightning"
			for d in smite_dice(sctx, target):
				var rolled := e._roll_damage_dice(str(d["dice"]), false, 0, str(d["label"]))
				total += int(rolled["total"])
				texts.append("%s %s: %s" % [d["label"], d["dice"], rolled["text"]])
				ty = str(d["type"])
			texts.append("Half damage on a miss")
			e.deal_damage(c, target, [{"amount": total / 2, "type": ty, "spell": true}], false, str((sctx["s"] as Dictionary)["name"]), texts)
			smite_follow_up(sctx, target, target.is_alive(), r)
	if has_feature(c, "studied_attacks"):
		e.add_mark({"kind": "advantage_against", "target": target.id, "attacker": c.id, "source": "Studied Attacks",
			"expires_owner": c.id, "expires_phase": "end", "skip": e.own_turn_skip(c), "consume": true})


## After a hit: the armed maneuver's effect, Cunning Strike effects, Giant Ancestry riders, Telekinetic Thrust,
## Eldritch Strike, Crusher, Slasher, Piercer criticals, Sentinel's Halt, Tavern Brawler's push, Shield Master's
## bash, Cleave, Remarkable Athlete, Great Weapon Master's Hew, Poisoner's dose.
func after_hit(c: Combatant, target: Combatant, option: Dictionary, dr: DamageResult, st: Dictionary, r: CombatResult) -> void:
	var e := enc()
	var p := option["profile"] as WeaponProfile
	var melee := bool(option["melee"])
	var critical := bool(st.get("critical", false))
	var opts := st["opts"] as Dictionary
	var alive := target.is_alive() and not target.is_down()
	var size_ok := Creature.SIZES.find(target.creature.size) <= Creature.SIZES.find(&"large")
	e.class_features.after_hit(c, target, option, st, r)
	e.ravenloft.after_hit(c, target, option, st, r)
	e.faerun.after_hit(c, target, critical, st)
	# Battle Master maneuvers.
	if st.has("maneuver"):
		var id := str(st["maneuver"])
		var die := int(st["sup_die"])
		var dc := maneuver_dc(c)
		match id:
			"disarming_attack":
				if alive and not _save(target, &"str", dc, "Disarming Attack"):
					e.ground.disarm(target, c, "Disarming Attack")
			"distracting_strike":
				e.add_mark({"kind": "advantage_against", "target": target.id, "not_attacker": c.id, "source": "Distracting Strike",
					"expires_owner": c.id, "expires_phase": "start", "consume": true})
			"goading_attack":
				if alive and not _save(target, &"wis", dc, "Goading Attack"):
					var fx := Effect.new("Goaded", &"feature", "goading_attack").with_modifier("flag", {"value": "goaded_by:%s" % c.id})
					fx.ends = Effect.Ends.END_OF_TURN
					fx.turn_owner_id = c.id
					fx.skip_turn_ends = e.own_turn_skip(c)
					target.creature.add_effect(fx)
			"menacing_attack":
				if alive and not _save(target, &"wis", dc, "Menacing Attack", "frightened"):
					var fx2 := Effect.new("Menaced", &"feature", "menacing_attack").with_condition(&"frightened")
					fx2.caster_id = c.id
					fx2.ends = Effect.Ends.END_OF_TURN
					fx2.turn_owner_id = c.id
					fx2.skip_turn_ends = e.own_turn_skip(c)
					target.creature.add_effect(fx2)
			"pushing_attack":
				if alive and size_ok and not _save(target, &"str", dc, "Pushing Attack"):
					e.forced_move(target, e.center_of(c), 15)
			"trip_attack":
				if alive and size_ok and not _save(target, &"str", dc, "Trip Attack"):
					target.creature.add_condition(&"prone", "Trip Attack")
					e.log.add("condition", "%s is tripped Prone" % target.name(), target.id)
			"sweeping_attack":
				var t := st["t"] as D20Test
				for o in e.hostiles_of(c):
					if o != target and not o.is_down() and e.distance(o, target) <= 5 and e.distance(c, o) <= p.reach and t.total >= o.creature.ac_value():
						var rolled := e._roll_damage_dice("1d%d" % die, false, 0, "Sweeping Attack")
						e.deal_damage(c, o, [{"amount": int(rolled["total"]), "type": str(p.damage_type)}], false, "Sweeping Attack", [str(rolled["text"])])
						break
			"maneuvering_attack":
				# An ally who can see or hear you may use its Reaction to move half its Speed, the target getting no
				# Opportunity Attack: the player picks the ally and its square (EncounterMovement.reaction_move).
				e.movement.offer_reaction_move(c, target, "Maneuvering Attack")
		e.events.append({"type": "condition", "id": target.id})
	# Cunning Strike.
	var dc_dex := maneuver_dc(c, &"dex")
	for id: String in st.get("cunning", []):
		match id:
			"poison":
				if alive and not _save(target, &"con", dc_dex, "Cunning Strike: Poison", "poisoned"):
					var fx3 := Effect.new("Poisoned (Cunning Strike)", &"feature", "cunning_strike").with_condition(&"poisoned")
					fx3.lasting({"kind": "minutes", "amount": 1})
					fx3.turn_owner_id = target.id
					fx3.repeat_save = {"ability": "con", "dc": dc_dex, "when": "end"}
					target.creature.add_effect(fx3)
			"trip":
				if alive and size_ok and not _save(target, &"dex", dc_dex, "Cunning Strike: Trip"):
					target.creature.add_condition(&"prone", "Cunning Strike")
			"withdraw":
				c.free_move_ft = maxi(c.free_move_ft, c.speed() / 2)
				e.log.add("info", "%s can withdraw %d ft without Opportunity Attacks" % [c.name(), c.free_move_ft], c.id)
			"stealth_attack":
				c.set_meta("stealth_attack_turn", _turn_key())
			"daze":
				if alive and not _save(target, &"con", dc_dex, "Cunning Strike: Daze"):
					var fx4 := Effect.new("Dazed", &"feature", "devious_strikes").with_modifier("flag", {"value": "dazed"})
					fx4.ends = Effect.Ends.END_OF_TURN
					fx4.turn_owner_id = target.id
					fx4.skip_turn_ends = e.own_turn_skip(target)
					target.creature.add_effect(fx4)
			"terrify":
				if alive and not _save(target, &"wis", dc_dex, "Cunning Strike: Terrify", "frightened"):
					var fx6 := Effect.new("Terrified", &"feature", "scion_strike_fear").with_condition(&"frightened") \
						.with_modifier("flag", {"value": "terrified_by:%s" % c.id})
					fx6.caster_id = c.id
					fx6.lasting({"kind": "minutes", "amount": 1})
					fx6.turn_owner_id = target.id
					fx6.repeat_save = {"ability": "wis", "dc": dc_dex, "when": "end"}
					target.creature.add_effect(fx6)
			"knock_out":
				if alive and not _save(target, &"con", dc_dex, "Cunning Strike: Knock Out", "unconscious"):
					var fx5 := Effect.new("Knocked Out", &"feature", "devious_strikes").with_condition(&"unconscious")
					fx5.lasting({"kind": "minutes", "amount": 1})
					fx5.turn_owner_id = target.id
					fx5.ends_on_damage = true
					fx5.repeat_save = {"ability": "con", "dc": dc_dex, "when": "end"}
					target.creature.add_effect(fx5)
			"obscure":
				if alive and not _save(target, &"dex", dc_dex, "Cunning Strike: Obscure", "blinded"):
					var fx6 := Effect.new("Blinded (Cunning Strike)", &"feature", "devious_strikes").with_condition(&"blinded")
					fx6.ends = Effect.Ends.END_OF_TURN
					fx6.turn_owner_id = target.id
					fx6.skip_turn_ends = e.own_turn_skip(target)
					target.creature.add_effect(fx6)
		e.events.append({"type": "condition", "id": target.id})
	# Envenom Weapons (Assassin 13): the Poison Cunning Strike also deals 2d6 Poison that ignores Resistance.
	if "poison" in (st.get("cunning", []) as Array) and has_feature(c, "envenom_weapons") and alive:
		var ev := e._max_damage_dice("2d6", false) if e.faerun.maximized(c, "poison") else e._roll_damage_dice("2d6", false, 0, "Envenom Weapons")
		e.deal_damage(c, target, [{"amount": int(ev["total"]), "type": "poison", "ignore_resistance": true, "ignore_source": "Envenom Weapons"}], false, "Envenom Weapons", [str(ev["text"])])
	# Death Strike (Assassin 17): a first-round Sneak Attack makes the target save (Con, 8 + Dex + PB) or take double.
	if st.has("sneak") and has_feature(c, "death_strike") and _first_round() and alive and dr.final > 0:
		if not _save(target, &"con", maneuver_dc(c, &"dex"), "Death Strike"):
			e.deal_damage(c, target, [{"amount": dr.final, "type": str(p.damage_type)}], false, "Death Strike", ["Damage doubled"])
	# Rend Mind (Soulknife 17): a Sneak Attack with a Psychic Blade can stun (Wis save, repeated each turn).
	if st.has("sneak") and "rend_mind" in c.armed and alive and str(option.get("kind", "")) == "blade":
		c.armed.erase("rend_mind")
		var ch2 := c.creature as Character
		if ch2.resource_left("rend_mind") > 0:
			ch2.spend_resource("rend_mind")
		else:
			ch2.spend_resource("psionic_energy", 3)
		var rdc := maneuver_dc(c, &"dex")
		if not _save(target, &"wis", rdc, "Rend Mind", "stunned"):
			var fx12 := Effect.new("Stunned (Rend Mind)", &"feature", "rend_mind").with_condition(&"stunned")
			fx12.lasting({"kind": "minutes", "amount": 1})
			fx12.turn_owner_id = target.id
			fx12.repeat_save = {"ability": "wis", "dc": rdc, "when": "end"}
			target.creature.add_effect(fx12)
	# A smite spell's effects (Searing Smite's burning, Thunderous Smite's push, Hail of Thorns' burst...).
	if st.has("smite_ctx"):
		smite_follow_up(st["smite_ctx"] as Dictionary, target, alive, r)
	# Giant Ancestry riders.
	match str(st.get("giant", "")):
		"frosts_chill":
			if alive:
				var fx7 := Effect.new("Frost's Chill", &"feature", "frosts_chill").with_modifier("speed", {"value": -10})
				fx7.ends = Effect.Ends.START_OF_TURN
				fx7.turn_owner_id = c.id
				target.creature.add_effect(fx7)
		"hills_tumble":
			if alive and size_ok:
				target.creature.add_condition(&"prone", "Hill's Tumble")
				e.log.add("condition", "%s is knocked Prone (Hill's Tumble)" % target.name(), target.id)
	# Telekinetic Thrust (Psi Warrior 7) with Psionic Strike.
	if bool(st.get("psionic_strike", false)) and "telekinetic_thrust" in c.armed and alive:
		c.armed.erase("telekinetic_thrust")
		if not _save(target, &"str", maneuver_dc(c, &"int"), "Telekinetic Thrust"):
			if size_ok:
				target.creature.add_condition(&"prone", "Telekinetic Thrust")
	# Eldritch Strike (Eldritch Knight 10).
	if has_feature(c, "eldritch_strike") and alive:
		var fx8 := Effect.new("Eldritch Strike", &"feature", "eldritch_strike").with_modifier("flag", {"value": "eldritch_struck:%s" % c.id})
		fx8.ends = Effect.Ends.END_OF_TURN
		fx8.turn_owner_id = c.id
		fx8.skip_turn_ends = e.own_turn_skip(c)
		fx8.consume_on = ["save:all"]
		target.creature.add_effect(fx8)
	# Feats with riders.
	if alive and has_feat(c, "crusher") and str(p.damage_type) == "bludgeoning":
		if size_ok and _once(c, "crusher") and not "skip:push" in c.armed:
			e.forced_move(target, e.center_of(c), 5)
		if critical:
			e.add_mark({"kind": "advantage_against", "target": target.id, "source": "Crusher", "expires_owner": c.id, "expires_phase": "start"})
	if alive and has_feat(c, "slasher") and str(p.damage_type) == "slashing":
		if _once(c, "slasher"):
			var fx9 := Effect.new("Hamstrung", &"feature", "slasher").with_modifier("speed", {"value": -10})
			fx9.ends = Effect.Ends.START_OF_TURN
			fx9.turn_owner_id = c.id
			target.creature.add_effect(fx9)
		if critical:
			e.add_mark({"kind": "disadvantage_next_attack", "attacker": target.id, "source": "Slasher", "expires_owner": c.id, "expires_phase": "start"})
	if alive and bool(opts.get("reaction", false)) and has_feat(c, "sentinel") and melee:
		var fx10 := Effect.new("Halted (Sentinel)", &"feature", "sentinel").with_modifier("speed_set", {"value": 0})
		fx10.ends = Effect.Ends.END_OF_TURN
		fx10.turn_owner_id = target.id
		target.creature.add_effect(fx10)
		target.movement_left = 0
		e.log.add("condition", "%s is stopped in its tracks (Sentinel)" % target.name(), target.id)
	if alive and has_feat(c, "tavern_brawler") and p.item_id == "unarmed_strike" and c.took_attack_action and _once(c, "tavern_push"):
		e.forced_move(target, e.center_of(c), 5)
	if alive and has_feat(c, "shield_master") and melee and wields_shield(c) and c.took_attack_action and e.current() == c and _once(c, "shield_bash"):
		if size_ok and not _save(target, &"str", maneuver_dc(c, &"str"), "Shield Bash"):
			target.creature.add_condition(&"prone", "Shield Bash")
			e.log.add("condition", "%s is bashed Prone (Shield Master)" % target.name(), target.id)
	if bool(st.get("poison_dose", false)) and alive:
		if not _save(target, &"con", 8 + c.creature.ability_mod(&"int") + c.creature.proficiency_bonus(), "Poisoner's dose", "poisoned"):
			var rolled2 := e._max_damage_dice("2d8", false) if e.faerun.maximized(c, "poison") else e._roll_damage_dice("2d8", false, 0, "Poison dose")
			e.deal_damage(c, target, [{"amount": int(rolled2["total"]), "type": "poison", "ignore_resistance": has_feat(c, "poisoner"), "ignore_source": "Potent Poison"}], false, "Poison", [str(rolled2["text"])])
			var fx11 := Effect.new("Poisoned (dose)", &"feature", "poisoner").with_condition(&"poisoned")
			fx11.ends = Effect.Ends.END_OF_TURN
			fx11.turn_owner_id = c.id
			fx11.skip_turn_ends = e.own_turn_skip(c)
			target.creature.add_effect(fx11)
	# Cleave (mastery): once per turn, a melee hit lets you attack a second creature within 5 ft of the first.
	if p.mastery == "cleave" and melee and not bool(opts.get("cleave", false)) and e.current() == c and _once(c, "cleave"):
		for o in e.hostiles_of(c):
			if o != target and not o.is_down() and e.distance(o, target) <= 5 and e.attack_legal(c, o, option) == "":
				e.log.add("info", "Cleave: %s swings on into %s" % [c.name(), o.name()], c.id)
				e.cleave_queue.append({"c": c, "target": o, "option": option})
				break
	# Remarkable Athlete (Champion 3): after a Critical Hit, move half Speed without Opportunity Attacks.
	if critical and has_feature(c, "remarkable_athlete"):
		c.free_move_ft = maxi(c.free_move_ft, c.speed() / 2)
	# Great Weapon Master's Hew: a melee crit or a kill grants a Bonus Action attack.
	if has_feat(c, "great_weapon_master") and melee and (critical or target.is_down()) and e.current() == c:
		c.bonus_attack = "Hew"
	if dr == null or r == null:
		return


func _save(t: Combatant, ab: StringName, dc: int, what: String, condition: String = "") -> bool:
	var e := enc()
	var keys: Array[String] = []
	if condition != "":
		keys.append("save_vs:%s" % condition)
	var test := t.creature.roll_save(e.dice, ab, dc, [], [], "%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], what, t.name()], keys)
	e.log.add("info", "%s %s the %s save" % [t.name(), "succeeds on" if test.success else "fails", what], t.id, [test.describe()])
	return test.success
