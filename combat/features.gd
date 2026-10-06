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
	var rolled := e._roll_damage_dice("1d10+%d" % level, false, 0, "Second Wind")
	var healed := ch.heal(int(rolled["total"]), "Second Wind")
	var r := CombatResult.new()
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
	var rolled := e._roll_damage_dice("%dd8" % count, false, 0, "Divine Spark")
	var amount := maxi(0, int(rolled["total"]) + wis)
	var text := "Divine Spark %dd8 + Wis %d: %s" % [count, wis, rolled["text"]]
	var r := CombatResult.new()
	if not harm:
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
