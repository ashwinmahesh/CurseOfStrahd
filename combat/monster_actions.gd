class_name MonsterActions
extends RefCounted
## What monsters do beyond weapon attacks (2024 Monster Manual, docs/contracts/monsters.md): riders on a hit
## (timed conditions with creature-type exceptions, real grapples with the printed escape DC, pulls, Hit Point
## maximum drain, Strength drain, the lycanthropy curse), saving-throw actions (the Vampire Spawn's Bite, the
## Shambling Mound's Engulf, the ravens' Cacophony), Recharge and per-day uses, monster spellcasting through
## SpellCaster (the Night Hag's Magic Missile and Phantasmal Killer, the priest's Divine Aid), Bonus Actions
## (Deathless Agility, Shadow Stealth, Shape-Shift), Parry, and traits that act on their own: auras (Stench,
## Festering Aura), Sunlight Sensitivity, Weakness and Hypersensitivity, Lightning Absorption, Incorporeal Movement,
## the swarm rules and the Strahd zombie's Loathsome Limbs.

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


static func data_of(c: Combatant) -> Dictionary:
	return (c.creature as Monster).data if c.creature is Monster else {}


func traits(c: Combatant) -> Array:
	return data_of(c).get("traits", []) as Array


# --- Availability: recharge, uses, forms ----------------------------------------------------------

## "" if the monster can use `act` now (recharged, uses left, the right form), otherwise why not.
func why_not(c: Combatant, act: Dictionary) -> String:
	if act.has("recharge") and not bool(c.get_meta("charged_%s" % act["id"], true)):
		return "Recharging"
	if act.has("uses"):
		var used := int(c.get_meta("used_%s" % act["id"], 0))
		if used >= int((act["uses"] as Dictionary).get("count", 1)):
			return "No uses left"
	# A Shapechanger's shape limits its actions (Strahd's mist form has none), as do the action's own `forms`.
	var shape_acts: Variant = enc().legendary.shape_actions(c)
	if shape_acts != null and not str(act.get("id", "")) in (shape_acts as Array):
		return "Not in this form"
	if act.has("forms") and not enc().legendary.form(c) in (act["forms"] as Array):
		return "Not in this form"
	var gone := enc().ground.weapon_gone(c, act)
	if gone != "":
		return gone
	# A vine blight can't lash out again while its vine holds someone.
	if bool(act.get("not_while_grappling", false)) and enc().grapples.values().has(c.id):
		return "Its vine is holding someone"
	return ""


func spend(c: Combatant, act: Dictionary) -> void:
	if act.has("recharge"):
		c.set_meta("charged_%s" % act["id"], false)
	if act.has("uses"):
		c.set_meta("used_%s" % act["id"], int(c.get_meta("used_%s" % act["id"], 0)) + 1)


## Recharge X-6 is rolled at the start of the monster's turn.
func roll_recharges(c: Combatant) -> void:
	for a: Variant in (data_of(c).get("actions", []) as Array) + (data_of(c).get("bonus_actions", []) as Array):
		var act := a as Dictionary
		if not act.has("recharge") or bool(c.get_meta("charged_%s" % act["id"], true)):
			continue
		var low := int(str(act["recharge"]).get_slice("-", 0))
		var roll := enc().dice.roll_one(6, "Recharge %s" % act.get("name", ""))
		if roll >= low:
			c.set_meta("charged_%s" % act["id"], true)
			enc().log.add("info", "%s's %s recharges (d6: %d)" % [c.name(), act.get("name", ""), roll], c.id)


# --- Riders on a hit or a failed save -------------------------------------------------------------

## The action's charge when the trailing voluntary steps each closed distance to this target.
## Grid approximations of an angled approach may change direction; sideways/retreating steps break it.
func charge_of(c: Combatant, target: Combatant, option: Dictionary) -> Dictionary:
	if c.has_meta("charged_vs"):
		c.remove_meta("charged_vs")
	if not c.creature is Monster or not c.moved:
		return {}
	var act := (c.creature as Monster).action(str(option.get("action_id", "")))
	if not act.has("charge"):
		return {}
	var ch := act["charge"] as Dictionary
	var e := enc()
	if c.approach_path.size() < 2 or c.approach_path[-1] != c.cell:
		return {}
	var feet := 0
	for i in range(c.approach_path.size() - 1, 0, -1):
		var to := c.approach_path[i]
		var from := c.approach_path[i - 1]
		var before := e.grid.distance_ft(from, c.size_cells, target.cell, target.size_cells)
		var after := e.grid.distance_ft(to, c.size_cells, target.cell, target.size_cells)
		if after >= before:
			break
		feet += e.grid.distance_ft(from, 1, to, 1)
		if feet >= int(ch.get("feet", 20)):
			return ch
	return {}


## Applies `riders` from `src` to `t` after damage `by_type` ({type: amount taken}). `pausable`: the caller carries on
## after a prompt (Encounter.then), so a rider's save stops for the choices after its roll (Indomitable, Heroic
## Inspiration...); otherwise they follow their rules at once.
func apply_riders(src: Combatant, t: Combatant, riders: Array, by_type: Dictionary, act_name: String, pausable: bool = false) -> CombatResult:
	var e := enc()
	var r := CombatResult.new()
	var one := func(raw: Variant) -> CombatResult:
		var rd := raw as Dictionary
		if not t.is_alive():
			return r
		if rd.has("unless_condition") and t.creature.has_condition(StringName(str(rd["unless_condition"]))):
			return r
		if rd.has("not_types") and str(t.creature.creature_type) in (rd["not_types"] as Array):
			return r
		if rd.has("only_types") and not str(t.creature.creature_type) in (rd["only_types"] as Array):
			return r
		if rd.has("not_species") and t.creature is Character and str((t.creature as Character).build.get("species", "")) in (rd["not_species"] as Array):
			e.log.add("info", "%s is unaffected (%s)" % [t.name(), str((t.creature as Character).build.get("species", "")).capitalize()], t.id)
			return r
		if rd.has("max_size") and Creature.SIZES.find(t.creature.size) > Creature.SIZES.find(StringName(str(rd["max_size"]))):
			return r
		if bool(rd.get("immune_on_success", false)) and t.has_meta(ClassFeatures.meta_key("immune_%s_%s" % [src.id, act_name])):
			return r
		if not rd.has("save"):
			_rider(src, t, rd, by_type, act_name)
			return r
		var sv := rd["save"] as Dictionary
		var cond := str(rd.get("condition", ""))
		var keys: Array[String] = []
		if cond != "":
			keys.append("save_vs:%s" % cond)
		var ab := StringName(str(sv["ability"]))
		var roll := func() -> D20Test:
			return t.creature.roll_save(e.dice, ab, int(sv["dc"]), [], [], "%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], act_name, t.name()], keys)
		var after := func(test: D20Test) -> CombatResult:
			if test.success:
				e.log.add("info", "%s resists %s" % [t.name(), act_name], t.id, [test.describe()])
				if bool(rd.get("immune_on_success", false)):
					t.set_meta(ClassFeatures.meta_key("immune_%s_%s" % [src.id, act_name]), true)
				return r
			_rider(src, t, rd, by_type, act_name)
			return r
		if pausable:
			return e.d20.then_after(t, roll, after, r)
		return after.call(roll.call() as D20Test) as CombatResult
	if not pausable:
		for raw: Variant in riders:
			one.call(raw)
		return r
	return e.each(riders, one, func() -> CombatResult: return r)


## What one rider does once it lands: a condition for a while, a grapple, burning, possession, a push or pull, drained
## Hit Points or abilities, a curse, being engulfed.
func _rider(src: Combatant, t: Combatant, rd: Dictionary, by_type: Dictionary, act_name: String) -> void:
	var e := enc()
	match str(rd["do"]):
		"condition":
			_timed_condition(src, t, str(rd["condition"]), str(rd.get("until", "permanent")), act_name, rd.get("modifiers", []) as Array, rd)
		"grapple":
			grapple(src, t, int(rd.get("escape_dc", 10)), int(rd.get("limit", 1)), act_name, bool(rd.get("restrain", false)))
			if e.grapples.has(t.id) and rd.has("hold_damage"):
				t.set_meta("hold_damage", rd["hold_damage"])
			if e.grapples.has(t.id) and rd.has("grip_damage"):
				t.set_meta("grip_damage", rd["grip_damage"])
		"burning":
			set_burning(src, t)
		"possess":
			possess(src, t, act_name)
		"pull", "push":
			var moved := e.forced_move(t, e.center_of(src), int(rd.get("feet", 5)), str(rd["do"]) == "pull")
			if moved > 0:
				e.log.add("info", "%s is %s %d ft" % [t.name(), "pulled" if str(rd["do"]) == "pull" else "pushed", moved * 5], t.id)
		"drain_max_hp":
			var amount := int(by_type.get(str(rd.get("type", "necrotic")), 0))
			if amount > 0:
				drain_max_hp(t, amount, act_name)
		"heal_self":
			var amount2 := int(by_type.get(str(rd.get("type", "necrotic")), 0))
			if amount2 > 0:
				var healed := src.creature.heal(amount2, act_name)
				if healed > 0:
					e.log.add("heal", "%s drinks %d Hit Points" % [src.name(), healed], src.id)
					e.events.append({"type": "heal", "id": src.id, "amount": healed})
		"ability_drain":
			ability_drain(t, StringName(str(rd["ability"])), int(e._roll_damage_dice(str(rd.get("dice", "1d4")), false, 0, act_name)["total"]), act_name)
		"curse":
			var fx := Effect.new("Cursed: %s" % str(rd["curse"]).capitalize(), &"monster", str(rd["curse"])).with_modifier("flag", {"value": "curse:%s" % rd["curse"]})
			fx.ends = Effect.Ends.NEVER
			t.creature.add_effect(fx)
			e.log.add("condition", "%s is cursed with %s" % [t.name(), rd["curse"]], t.id)
		"engulf":
			engulf(src, t, rd, act_name)
	e.events.append({"type": "condition", "id": t.id})


## A condition that lasts as the stat block says: until the end or start of the target's (or the source's) next
## turn, a minute, or until something ends it.
func _timed_condition(src: Combatant, t: Combatant, cond: String, until: String, label: String, mods: Array, rd: Dictionary = {}) -> void:
	var e := enc()
	var fx := Effect.new("%s (%s)" % [cond.capitalize(), label] if cond != "" else label, &"monster", "%s:%s" % [src.id, label])
	fx.caster_id = src.id
	# Webbing and the like: an action and an ability check frees the target.
	if rd.has("escape"):
		fx.escape = (rd["escape"] as Dictionary).duplicate()
	# A save to shake it off: at the end or start of the target's turns, or each time it takes damage (Strahd's Charm,
	# a revenant's glare, a soul tome's prison).
	if rd.has("repeat_save"):
		fx.repeat_save = (rd["repeat_save"] as Dictionary).duplicate()
	# Worse for the creature the monster has sworn vengeance on (a revenant's glare paralyzes its quarry).
	if rd.has("also_if_vowed") and str(t.get_meta("vowed_by", "")) == src.id:
		fx.conditions.append(StringName(str(rd["also_if_vowed"])))
	for extra: Variant in rd.get("conditions", []):
		fx.conditions.append(StringName(str(extra)))
	if cond != "":
		fx.conditions.append(StringName(cond))
	# "Until the end of your next turn" for a summon's rider means its summoner's turn (Fell Glare).
	if until == "summoner_turn_end":
		var owner := e.get_c(str(src.get_meta("summoner", src.id)))
		if owner != null:
			src = owner
		until = "source_turn_end"
	for md: Variant in mods:
		fx.modifiers.append(Modifier.make((md as Dictionary).duplicate(true), label, &"monster"))
	match until:
		"target_turn_end":
			fx.ends = Effect.Ends.END_OF_TURN
			fx.turn_owner_id = t.id
			fx.skip_turn_ends = e.own_turn_skip(t)
		"target_turn_start":
			fx.ends = Effect.Ends.START_OF_TURN
			fx.turn_owner_id = t.id
		"source_turn_start":
			fx.ends = Effect.Ends.START_OF_TURN
			fx.turn_owner_id = src.id
		"source_turn_end":
			fx.ends = Effect.Ends.END_OF_TURN
			fx.turn_owner_id = src.id
			fx.skip_turn_ends = e.own_turn_skip(src)
		"minute":
			fx.lasting({"kind": "minutes", "amount": 1})
			fx.turn_owner_id = t.id
		_:
			fx.ends = Effect.Ends.NEVER
	if t.creature.add_effect(fx):
		e.log.add("condition", ("%s is %s (%s)" % [t.name(), cond.capitalize(), label]) if cond != "" else "%s is hindered (%s)" % [t.name(), label], t.id)
		if cond in ["incapacitated", "paralyzed", "stunned", "unconscious"]:
			e.features.end_turning_from(t)


## Burning (2024 rules glossary): 1d4 Fire at the start of each of the creature's turns until it uses an action to
## drop Prone and put the flames out.
func set_burning(src: Combatant, t: Combatant) -> void:
	var e := enc()
	if t.creature.effects.any(func(x: Effect) -> bool: return bool(x.data.get("douse", false))):
		return
	var fx := Effect.new("Burning", &"monster", "burning")
	fx.caster_id = src.id if src != null else ""
	fx.ends = Effect.Ends.NEVER
	fx.data["turn_damage"] = {"dice": "1d4", "type": "fire"}
	fx.data["douse"] = true
	t.creature.add_effect(fx)
	e.log.add("condition", "%s catches fire" % t.name(), t.id)


## Fire Form (fire elemental): the first time on a turn it moves into a creature's space, that creature takes 1d10
## Fire damage and starts burning.
func entered_space(c: Combatant) -> void:
	var e := enc()
	if not c.creature.has_flag("fire_form"):
		return
	var turn_key := "%d:%d" % [e.round_no, e.turn_index]
	for o in e.living():
		if o == c or o.is_down() or not c.cell in o.footprint():
			continue
		var key := ClassFeatures.meta_key("fire_form_%s" % c.id)
		if str(o.get_meta(key, "")) == turn_key:
			continue
		o.set_meta(key, turn_key)
		var rolled := e._roll_damage_dice("1d10", false, 0, "Fire Form")
		e.deal_damage(c, o, [{"amount": int(rolled["total"]), "type": "fire"}], false, "Fire Form", [str(rolled["text"])])
		if o.is_alive():
			set_burning(c, o)


## A grapple from a stat block: registered like an Unarmed Strike grapple, with the printed escape DC; a creature
## can hold only `limit` creatures at once (the Vampire Spawn's two claws).
func grapple(src: Combatant, t: Combatant, escape_dc: int, limit: int, label: String, restrain: bool = false) -> void:
	var e := enc()
	var held := 0
	for k: String in e.grapples:
		if str(e.grapples[k]) == src.id:
			held += 1
	if held >= limit or e.grapples.has(t.id):
		return
	t.creature.add_condition(&"grappled", src.name())
	e.grapples[t.id] = src.id
	t.set_meta("escape_dc", escape_dc)
	if restrain:
		t.creature.add_condition(&"restrained", Creature.GRAPPLE_RESTRAINT)
	e.log.add("condition", "%s grabs %s (%s, escape DC %d%s)" % [src.name(), t.name(), label, escape_dc, ", Restrained while held" if restrain else ""], src.id)


## Engulf (Shambling Mound): the target is pulled into the mound's space, Grappled (escape DC), Blinded and
## Restrained, and takes damage at the start of each of its turns; it moves with the mound. One at a time.
func engulf(src: Combatant, t: Combatant, rd: Dictionary, label: String) -> void:
	var e := enc()
	for o in e.combatants:
		if str(o.get_meta("engulfed_by", "")) == src.id and o.is_alive():
			return
	var from := t.cell
	t.cell = src.cell
	e.events.append({"type": "teleport", "id": t.id, "from": from, "to": t.cell})
	t.set_meta("engulfed_by", src.id)
	t.set_meta("engulf_damage", rd.get("damage", {}))
	grapple(src, t, int(rd.get("escape_dc", 14)), 99, label)
	var fx := Effect.new("Engulfed", &"monster", "engulf:%s" % src.id)
	fx.caster_id = src.id
	for cnd: Variant in rd.get("conditions", []):
		fx.conditions.append(StringName(str(cnd)))
	t.creature.add_effect(fx)
	e.log.add("condition", "%s is engulfed by %s" % [t.name(), src.name()], t.id)


func release_engulf(t: Combatant) -> void:
	if not t.has_meta("engulfed_by"):
		return
	var e := enc()
	t.remove_meta("engulfed_by")
	for fx: Effect in t.creature.effects.duplicate():
		if fx.name == "Engulfed":
			t.creature.remove_effect(fx)
	t.cell = e.spells._free_cell_near(t.cell)
	e.events.append({"type": "teleport", "id": t.id, "from": t.cell, "to": t.cell})


## Hit Point maximum reduction (Life Drain, the Spawn's Bite): lasts until a Long Rest; 0 means death.
func drain_max_hp(t: Combatant, amount: int, label: String) -> void:
	var e := enc()
	# Aura of Life: Hit Point maximums can't be reduced inside it.
	if t.creature.has_flag("no_max_hp_reduction"):
		e.log.add("info", "%s's Hit Point maximum holds (%s)" % [t.name(), label], t.id)
		return
	var fx := Effect.new("%s (drained)" % label, &"monster", "drain_max_hp")
	fx.stack_key = "drain_max_hp:%d" % fx.id
	fx.ends = Effect.Ends.LONG_REST
	fx.modifiers.append(Modifier.of("hp_max", {"value": -amount}, label, &"monster"))
	t.creature.add_effect(fx)
	t.creature.hp = mini(t.creature.hp, t.creature.max_hp())
	e.log.add("condition", "%s's Hit Point maximum drops by %d" % [t.name(), amount], t.id)
	if t.creature.max_hp() <= 0:
		t.creature._die("Hit Point maximum drained to 0")
		e.events.append({"type": "death", "id": t.id})


## Ability drain (the Shadow's Draining Swipe): the score drops until a Long Rest; at 0 the creature dies.
func ability_drain(t: Combatant, ab: StringName, amount: int, label: String) -> void:
	var e := enc()
	var fx := Effect.new("%s (%s drained)" % [label, Creature.ABILITY_SHORT[ab]], &"monster", "ability_drain")
	fx.stack_key = "ability_drain:%d" % fx.id
	fx.ends = Effect.Ends.LONG_REST
	fx.modifiers.append(Modifier.of("ability", {"ability": str(ab), "value": -amount, "max": 30}, label, &"monster"))
	t.creature.add_effect(fx)
	e.log.add("condition", "%s's %s drops by %d (now %d)" % [t.name(), Creature.ABILITY_NAMES[ab], amount, t.creature.ability_score(ab)], t.id)
	if t.creature.ability_score(ab) <= 0:
		t.creature._die("%s drained to 0" % Creature.ABILITY_NAMES[ab])
		e.events.append({"type": "death", "id": t.id})


# --- Saving-throw actions -------------------------------------------------------------------------

## Creatures a save action could target from where the monster stands.
func save_targets(c: Combatant, act: Dictionary) -> Array[Combatant]:
	var e := enc()
	var out: Array[Combatant] = []
	var tg := act.get("targets", {}) as Dictionary
	for t in e.hostiles_of(c):
		if t.is_down() and not "incapacitated" in (tg.get("requires", []) as Array):
			continue
		if bool(tg.get("in_space", false)):
			var shares := false
			for cell in t.footprint():
				if cell in c.footprint():
					shares = true
			if not shares and e.distance(c, t) > 0:
				continue
		elif e.distance(c, t) > int(tg.get("range", 5)):
			continue
		if tg.has("max_size") and Creature.SIZES.find(t.creature.size) > Creature.SIZES.find(StringName(str(tg["max_size"]))):
			continue
		if tg.has("types") and not str(t.creature.creature_type) in (tg["types"] as Array):
			continue
		if tg.has("not_types") and str(t.creature.creature_type) in (tg["not_types"] as Array):
			continue
		if t.has_meta(ClassFeatures.meta_key("immune_%s_%s" % [c.id, str(act.get("name", ""))])):
			continue
		if _nothing_new(act, t):
			continue
		if tg.has("requires"):
			var ok := false
			for need: Variant in tg["requires"]:
				# A creature the monster has Charmed counts as willing (Strahd's Bite).
				if str(need) in ["willing", "charmed"] and Legendary.charmed_by(t, c):
					ok = true
				if str(need) == "willing":
					continue
				if t.creature.has_condition(StringName(str(need))):
					ok = true
			if not ok:
				continue
		out.append(t)
	return out


## Everyone an area save action catches when aimed at `t` (a ghost's 60-ft cone of Horrific Visage, an air elemental's
## space): [t] for a single-target action.
func save_victims(c: Combatant, act: Dictionary, t: Combatant) -> Array[Combatant]:
	var e := enc()
	var area := act.get("area", {}) as Dictionary
	var out: Array[Combatant] = []
	if not area.has("shape"):
		out.append(t)
		return out
	var tg := act.get("targets", {}) as Dictionary
	var cells: Array[Vector2i] = []
	if str(area["shape"]) == "space":
		cells = c.footprint()
	else:
		var origin := e.center_of(c)
		if str(area["shape"]) == "cone":
			cells = e.grid.cone_from(c.cell, c.size_cells, e.center_of(t), int(area.get("size", 15)))
		else:
			cells = e.grid.area_cells(str(area["shape"]), int(area.get("size", 15)), origin, e.center_of(t) - origin, 5, c.cell, c.size_cells)
	for o in e.living():
		if o == c or o.is_down() or not o.footprint().any(func(x: Vector2i) -> bool: return x in cells):
			continue
		if tg.has("not_types") and str(o.creature.creature_type) in (tg["not_types"] as Array):
			continue
		if tg.has("max_size") and Creature.SIZES.find(o.creature.size) > Creature.SIZES.find(StringName(str(tg["max_size"]))):
			continue
		if bool(tg.get("sees_source", false)) and not e.can_see(o, c):
			continue
		if bool(tg.get("enemies_only", false)) and not c.hostile_to(o):
			continue
		out.append(o)
	return out


## True when a save action would only give `t` conditions it already has (a lion roaring at a creature that's
## already Frightened).
func _nothing_new(act: Dictionary, t: Combatant) -> bool:
	var fails := act.get("on_fail", []) as Array
	if fails.is_empty() or not (act.get("damage", []) as Array).is_empty():
		return false
	for rd: Variant in fails:
		if str((rd as Dictionary).get("do", "")) != "condition" or not t.creature.has_condition(StringName(str((rd as Dictionary).get("condition", "")))):
			return false
	return true


## A save action (Bite, Engulf, Cacophony): the target saves; on a failure damage and the riders. An area action
## (`area.shape`) rolls its damage once for everyone it catches. Each save stops for the choices after its roll
## (Indomitable, Heroic Inspiration, an ally's Bend Luck: D20Responses), so `r` may come back paused: callers carry on
## with Encounter.then. `pausable` false settles those choices by rule instead, for a caller that can't wait.
func save_action(c: Combatant, act: Dictionary, t: Combatant, r: CombatResult, pausable: bool = true) -> CombatResult:
	var e := enc()
	spend(c, act)
	var victims := save_victims(c, act, t)
	e.log.add("info", "%s uses %s%s" % [c.name(), act.get("name", ""), (" on %s" % t.name()) if victims.size() == 1 and victims[0] == t else ""], c.id)
	# For the view's effect (emit-only): which action, on whom.
	e.events.append({"type": "ability", "source": "monster", "by": c.id, "key": action_key(c, act),
		"targets": victims.map(func(v: Combatant) -> String: return v.id), "cells": []})
	var rolled_once := {}
	if not pausable:
		for v in victims:
			_save_one(c, act, v, r, rolled_once, false)
		return r
	return e.each(victims, func(v: Variant) -> CombatResult: return _save_one(c, act, v as Combatant, r, rolled_once, true), func() -> CombatResult: return r)


## What's added to the DCs a monster's own actions set: its `spell_dc` modifiers (Tactician's +2, combat/difficulty.gd).
func dc_bonus(c: Combatant) -> int:
	var total := 0
	var ctx := c.creature.formula_context()
	for m in c.creature.modifiers_for(&"spell_dc"):
		total += c.creature.mod_value(m, ctx)
	return total


## A stat-block action's key for the view's effects: "<monster id>.<action id>" (art/vfx/effects.json).
static func action_key(c: Combatant, act: Dictionary) -> String:
	var mid := str((c.creature as Monster).data.get("id", "")) if c.creature is Monster else ""
	return "%s.%s" % [mid, str(act.get("id", ""))]


func _save_one(c: Combatant, act: Dictionary, t: Combatant, r: CombatResult, rolled_once: Dictionary, pausable: bool = false) -> CombatResult:
	var e := enc()
	var sv := act["save"] as Dictionary
	var ab := StringName(str(sv["ability"]))
	var pre_hp := t.creature.hp
	var immune_key := ClassFeatures.meta_key("immune_%s_%s" % [c.id, str(act.get("name", ""))])
	if t.has_meta(immune_key):
		e.log.add("info", "%s is unmoved by %s" % [t.name(), act.get("name", "")], t.id)
		return r
	var keys: Array[String] = []
	if bool(act.get("magical", false)):
		keys.append("save_vs:magic")
	var roll := func() -> D20Test:
		return t.creature.roll_save(e.dice, ab, int(sv["dc"]) + dc_bonus(c), [], [], "%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], act.get("name", ""), t.name()], keys)
	if not pausable:
		return _after_save_one(c, act, t, roll.call() as D20Test, pre_hp, r, rolled_once, false)
	return e.d20.then_after(t, roll, func(test: D20Test) -> CombatResult: return _after_save_one(c, act, t, test, pre_hp, r, rolled_once, true), r)


## What a save action does to `t` once its save is settled: damage (rolled once for the whole area), the riders on a
## failure, a banshee's wail dropping the weak.
func _after_save_one(c: Combatant, act: Dictionary, t: Combatant, test: D20Test, pre_hp: int, r: CombatResult, rolled_once: Dictionary, pausable: bool) -> CombatResult:
	var e := enc()
	var sv := act["save"] as Dictionary
	var ab := StringName(str(sv["ability"]))
	var immune_key := ClassFeatures.meta_key("immune_%s_%s" % [c.id, str(act.get("name", ""))])
	var by_type := {}
	var parts: Array = []
	var texts: Array[String] = [test.describe()]
	var i := 0
	for d: Variant in act.get("damage", []):
		var dd := d as Dictionary
		i += 1
		if dd.has("when"):
			continue
		if not rolled_once.has(i):
			rolled_once[i] = e._roll_damage_dice(str(dd["dice"]), false, 0, str(act.get("name", "")))
		var rolled := rolled_once[i] as Dictionary
		var amount := int(rolled["total"])
		amount = t.creature.damage_after_save(amount, ab, test.success, str(sv.get("success", "none")) == "half", bool(act.get("magical", false)))
		parts.append({"amount": amount, "type": str(dd["type"]), "magic": bool(act.get("magical", false))})
		texts.append(str(rolled["text"]))
	if not parts.is_empty() and parts.any(func(p: Dictionary) -> bool: return int(p["amount"]) > 0):
		var dr := e.deal_damage(c, t, parts, false, str(act.get("name", "")), texts)
		r.damage += dr.final
		by_type = taken_by_type(t, parts)
	elif test.success:
		e.log.add("info", "%s resists %s" % [t.name(), act.get("name", "")], t.id, texts)
	if test.success and bool(act.get("immune_on_success", false)):
		t.set_meta(immune_key, true)
	# A banshee's Deathly Wail: a failed save at that many Hit Points or fewer drops the creature to 0.
	if not test.success and act.has("drop_at_hp") and t.is_alive() and t.creature.hp > 0 and pre_hp <= int(act["drop_at_hp"]):
		e.log.add("condition", "%s collapses (%s)" % [t.name(), act.get("name", "")], t.id)
		e.deal_damage(c, t, [{"amount": t.creature.hp + t.creature.temp_hp, "type": "psychic"}], false, str(act.get("name", "")))
	if not test.success and t.is_alive():
		apply_riders(c, t, act.get("on_fail", []) as Array, by_type, str(act.get("name", "")), pausable)
	return r


## How much of each damage type a creature actually took (after Resistance, Immunity, Vulnerability).
static func taken_by_type(t: Combatant, parts: Array) -> Dictionary:
	var out := {}
	for p: Variant in parts:
		var d := p as Dictionary
		var ty := StringName(str(d["type"]))
		var amount := int(d["amount"])
		if t.creature.immunity_source(ty) != "":
			amount = 0
		elif t.creature.resistance_source(ty) != "":
			amount = amount / 2
		if t.creature.vulnerability_source(ty) != "":
			amount *= 2
		out[str(ty)] = int(out.get(str(ty), 0)) + amount
	return out


# --- Spellcasting -------------------------------------------------------------------------------

## Spells the monster can cast now: [{id, level, per_day_left}] from its `spellcasting` block (at will, N/day).
func spells_now(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# No spellcasting inside an Antimagic Field (or with Befuddlement, Feeblemind...).
	if c.creature.has_flag("cant_cast") or enc().spells.specials.high.in_antimagic(c):
		return out
	var sc := data_of(c).get("spellcasting", {}) as Dictionary
	for sid: Variant in sc.get("at_will", []):
		out.append({"id": str(sid), "left": 99})
	var per_day := sc.get("per_day", {}) as Dictionary
	for n: String in per_day:
		for sid2: Variant in per_day[n]:
			var used := int(c.get_meta("cast_%s" % sid2, 0))
			if used < int(n):
				out.append({"id": str(sid2), "left": int(n) - used})
	return out


## Casts a stat-block spell with the monster's DC and attack bonus, at the level the block gives (Magic Missile
## at level 4 for the Night Hag) or the spell's own level.
func cast(c: Combatant, spell_id: String, targets: Array, point: Vector2 = Vector2.INF, slot: int = 0, opts: Dictionary = {}) -> CombatResult:
	var e := enc()
	var sc := data_of(c).get("spellcasting", {}) as Dictionary
	var s := Compendium.shared().spell_data(spell_id)
	if s.is_empty():
		return CombatResult.fail("Unknown spell")
	var levels := sc.get("levels", {}) as Dictionary
	var level := int(levels.get(spell_id, maxi(slot, int(s.get("level", 0)))))
	var ab := StringName(str(sc.get("ability", "int")))
	var dc := Breakdown.new("Spell save DC").add("Stat block", int(sc.get("dc", 8 + c.creature.ability_mod(ab) + c.creature.proficiency_bonus())))
	var atk := Breakdown.new("Spell attack").add("Stat block", int(sc.get("attack", c.creature.ability_mod(ab) + c.creature.proficiency_bonus())))
	# Bonuses to the monster's own DCs and spell attacks (Tactician's +2, combat/difficulty.gd).
	var ctx := c.creature.formula_context()
	for m in c.creature.modifiers_for(&"spell_dc"):
		dc.add_nonzero(m.source_name, c.creature.mod_value(m, ctx))
	for m2 in c.creature.modifiers_for(&"spell_attack"):
		atk.add_nonzero(m2.source_name, c.creature.mod_value(m2, ctx))
	var r := e.spells.cast_with_numbers(c, spell_id, level, targets, point, {"dc": dc, "attack": atk, "mod": c.creature.ability_mod(ab), "ability": ab}, opts)
	# A per-day spell is used up once it's cast, not when the cast was refused (no target in range, no action left).
	if r.ok:
		var per_day := sc.get("per_day", {}) as Dictionary
		for n: String in per_day:
			if spell_id in (per_day[n] as Array):
				c.set_meta("cast_%s" % spell_id, int(c.get_meta("cast_%s" % spell_id, 0)) + 1)
	return r


# --- Turn hooks -----------------------------------------------------------------------------------

## Start of `c`'s turn: Recharge, auras of nearby monsters (Stench, Festering Aura), Engulf damage, Sunlight
## Hypersensitivity.
## Start of `c`'s turn: Recharge, Berserk, the auras of nearby monsters reaching it (Stench, Festering Aura) and its own
## (Whispering Aura), Regeneration, grips, Engulf and Sunlight Hypersensitivity. An aura's save stops for the choices
## after its roll, so the rest waits on Encounter.then.
func turn_start(c: Combatant) -> CombatResult:
	var e := enc()
	if c.creature is Monster:
		roll_recharges(c)
	# Berserk (flesh golem): starting a turn Bloodied, a 6 on a d6 sends it into a rage until it's no longer Bloodied.
	if has_trait(c, "berserk"):
		if not c.creature.is_bloodied():
			c.remove_meta("berserk")
		elif not c.has_meta("berserk"):
			var roll := e.dice.roll_one(6, "Berserk")
			if roll == 6:
				c.set_meta("berserk", true)
				e.log.add("condition", "%s goes berserk (d6: 6)" % c.name(), c.id)
	var auras: Array = []
	for o in e.living():
		if o == c or o.is_down():
			continue
		for tr: Variant in traits(o):
			var aura := (tr as Dictionary).get("aura", {}) as Dictionary
			if aura.is_empty() or str(aura.get("trigger", "start_turn")) != "start_turn":
				continue
			auras.append([o, c, tr])
	# Auras that act at the start of their owner's turn (the Aberrant Spirit's Whispering Aura).
	if c.can_act():
		for tr2: Variant in traits(c):
			var aura2 := (tr2 as Dictionary).get("aura", {}) as Dictionary
			if aura2.is_empty() or str(aura2.get("trigger", "")) != "own_turn_start":
				continue
			for o2 in e.living():
				if o2 != c and not o2.is_down():
					auras.append([c, o2, tr2])
	var rest := func() -> CombatResult:
		# Regeneration (the Slaad spirit): Hit Points back at the start of its turn while it has at least 1.
		for tr3: Variant in traits(c):
			var regen := int((tr3 as Dictionary).get("regenerate", 0))
			if regen > 0 and c.creature.hp >= 1 and not c.creature.has_flag("cant_regain_hp"):
				var healed := c.creature.heal(regen, str((tr3 as Dictionary).get("name", "Regeneration")))
				if healed > 0:
					e.log.add("heal", "%s regenerates %d Hit Points" % [c.name(), healed], c.id)
					e.events.append({"type": "heal", "id": c.id, "amount": healed})
		# A vine blight's or tree blight's grip: the held creature takes damage at the start of its own turn.
		if c.has_meta("grip_damage"):
			var by := e.get_c(str(e.grapples.get(c.id, "")))
			if by == null or not by.is_alive():
				c.remove_meta("grip_damage")
			else:
				var gd := c.get_meta("grip_damage") as Dictionary
				var gr := e._roll_damage_dice(str(gd["dice"]), false, 0, "Grip")
				e.deal_damage(by, c, [{"amount": int(gr["total"]), "type": str(gd["type"])}], false, "%s's grip" % by.name(), [str(gr["text"])])
		# Whelm (water elemental): each creature it holds takes damage at the start of its turn.
		for k: String in e.grapples.keys():
			var held := e.get_c(k)
			if str(e.grapples[k]) == c.id and held != null and held.is_alive() and held.has_meta("hold_damage"):
				var hd := held.get_meta("hold_damage") as Dictionary
				var hr := e._roll_damage_dice(str(hd["dice"]), false, 0, "Held")
				e.deal_damage(c, held, [{"amount": int(hr["total"]), "type": str(hd["type"])}], false, "%s's grip" % c.name(), [str(hr["text"])])
		if c.has_meta("engulfed_by"):
			var by := e.get_c(str(c.get_meta("engulfed_by")))
			if by == null or by.is_down() or not e.grapples.has(c.id):
				release_engulf(c)
			else:
				var dmg := c.get_meta("engulf_damage", {}) as Dictionary
				if not dmg.is_empty():
					var rolled := e._roll_damage_dice(str(dmg["dice"]), false, 0, "Engulf")
					e.deal_damage(by, c, [{"amount": int(rolled["total"]), "type": str(dmg["type"])}], false, "Engulf", [str(rolled["text"])])
		if sunlight(c) == "hypersensitivity" and e.in_sunlight(c):
			e.deal_damage(null, c, [{"amount": 20, "type": "radiant"}], false, "Sunlight", ["Sunlight Hypersensitivity"])
		return CombatResult.new()
	return e.each(auras, func(a: Variant) -> CombatResult:
		var at := a as Array
		var src := at[0] as Combatant
		if src.is_down() or not src.is_alive():
			return CombatResult.new()
		return _aura_on(src, at[1] as Combatant, at[2] as Dictionary, true), rest)


## One aura from `o` reaching `c`: a save, then a timed condition or hindrance (Stench, Festering Aura, Stony Lethargy)
## or damage (Whispering Aura).
func _aura_on(o: Combatant, c: Combatant, tr: Dictionary, pausable: bool = false) -> CombatResult:
	var e := enc()
	var r := CombatResult.new()
	var aura := tr.get("aura", {}) as Dictionary
	if str(aura.get("affects", "others")) == "enemies" and not o.hostile_to(c):
		return r
	if e.distance(o, c) > int(aura.get("radius", 5)):
		return r
	var label := str(tr.get("name", "Aura"))
	if c.has_meta(ClassFeatures.meta_key("immune_%s_%s" % [o.id, label])):
		return r
	if not aura.has("damage"):
		return apply_riders(o, c, [{"do": "condition", "condition": str(aura.get("condition", "")), "save": aura["save"], "until": str(aura.get("until", "target_turn_start")),
			"immune_on_success": bool(aura.get("immune_on_success", false)), "modifiers": aura.get("modifiers", [])}], {}, label, pausable)
	var hurt := func(details: Array[String]) -> CombatResult:
		var dmg := aura["damage"] as Dictionary
		var rolled := e._roll_damage_dice(str(dmg["dice"]), false, 0, label)
		details.append(str(rolled["text"]))
		e.deal_damage(o, c, [{"amount": int(rolled["total"]), "type": str(dmg["type"])}], false, label, details)
		if c.is_alive():
			return apply_riders(o, c, aura.get("riders", []) as Array, {}, label, pausable)
		return r
	if not aura.has("save"):
		var plain: Array[String] = []
		return hurt.call(plain) as CombatResult
	var sv := aura["save"] as Dictionary
	var ab := StringName(str(sv["ability"]))
	var roll := func() -> D20Test:
		return c.creature.roll_save(e.dice, ab, int(sv["dc"]), [], [], "%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], label, c.name()])
	var after := func(test: D20Test) -> CombatResult:
		if test.success:
			e.log.add("info", "%s resists %s" % [c.name(), label], c.id, [test.describe()])
			return r
		var details: Array[String] = [test.describe()]
		return hurt.call(details) as CombatResult
	if pausable:
		return e.d20.then_after(c, roll, after, r)
	return after.call(roll.call() as D20Test) as CombatResult


## End of `c`'s turn: Incorporeal Movement inside an object (a wall square) costs 1d10 Force.
func turn_end(c: Combatant) -> void:
	var e := enc()
	# Auras that act at the end of their owner's turn (a fire elemental's Fire Aura).
	if c.is_alive() and not c.is_down():
		for tr: Variant in traits(c):
			var aura := (tr as Dictionary).get("aura", {}) as Dictionary
			if aura.is_empty() or str(aura.get("trigger", "")) != "own_turn_end":
				continue
			for o in e.living():
				if o != c and not o.is_down():
					_aura_on(c, o, tr as Dictionary)
	if has_trait(c, "incorporeal_movement"):
		for cell in c.footprint():
			if e.grid.is_solid(cell):
				var rolled := e._roll_damage_dice("1d10", false, 0, "Incorporeal Movement")
				e.deal_damage(null, c, [{"amount": int(rolled["total"]), "type": "force"}], false, "ending its turn inside an object")
				break


func has_trait(c: Combatant, trait_id: String) -> bool:
	for tr: Variant in traits(c):
		if str((tr as Dictionary).get("id", "")) == trait_id:
			return true
	return false


## "sensitivity", "weakness", "hypersensitivity" or "" from the stat block's sunlight trait.
func sunlight(c: Combatant) -> String:
	for tr: Variant in traits(c):
		var s := str((tr as Dictionary).get("sunlight", ""))
		if s != "":
			return s
	return ""


## Damage about to be dealt to a monster: Lightning Absorption turns Lightning into healing.
func absorb(target: Combatant, parts: Array) -> Array:
	var absorb_type := ""
	for tr: Variant in traits(target):
		absorb_type = str((tr as Dictionary).get("absorb", absorb_type))
	if absorb_type == "":
		return parts
	var out: Array = []
	for p: Variant in parts:
		var d := p as Dictionary
		if str(d["type"]) == absorb_type and int(d["amount"]) > 0:
			var healed := target.creature.heal(int(d["amount"]), "absorption")
			enc().log.add("heal", "%s absorbs the %s: +%d Hit Points" % [target.name(), absorb_type, healed], target.id)
			enc().events.append({"type": "heal", "id": target.id, "amount": healed})
			continue
		out.append(d)
	return out


## Loathsome Limbs (Strahd zombie): 5+ Bludgeoning or Slashing damage from one source may sever a leg, an arm or the
## head; arms and the head fight on as their own creatures, sharing the body's Hit Points.
func loathsome_limbs(target: Combatant, parts: Array) -> void:
	var e := enc()
	if not has_trait(target, "loathsome_limbs") or target.is_down():
		return
	var bs := 0
	for p: Variant in parts:
		if str((p as Dictionary)["type"]) in ["bludgeoning", "slashing"]:
			bs += int((p as Dictionary)["amount"])
	if bs < 5:
		return
	var roll := e.dice.roll_one(20, "Loathsome Limbs")
	var lost := target.get_meta("limbs_lost", {"leg": 0, "arm": 0, "head": 0}) as Dictionary
	var part := "leg" if roll <= 8 else ("arm" if roll <= 16 else "head")
	var max_of := {"leg": 2, "arm": 2, "head": 1}
	if int(lost[part]) >= int(max_of[part]):
		return
	lost[part] = int(lost[part]) + 1
	target.set_meta("limbs_lost", lost)
	e.log.add("info", "%s's %s is severed (d20: %d)" % [target.name(), part, roll], target.id)
	var fx := Effect.new("Severed limbs", &"monster", "loathsome_limbs")
	fx.stack_key = "loathsome_limbs"
	if int(lost["leg"]) == 1:
		fx.modifiers.append(Modifier.of("speed_percent", {"value": 50}, "Missing a leg", &"monster"))
	elif int(lost["leg"]) >= 2:
		fx.conditions.append(&"prone")
		fx.modifiers.append(Modifier.of("speed_set", {"value": 5}, "Missing both legs", &"monster"))
	if int(lost["head"]) >= 1:
		fx.conditions.append(&"blinded")
	target.creature.remove_effects_named("Severed limbs")
	target.creature.add_effect(fx)
	if part in ["arm", "head"]:
		var block := {"id": "severed_%s" % part, "name": "Severed %s" % part.capitalize(), "size": "tiny", "type": "undead", "ac": 8,
			"hp": {"average": 1, "dice": "1"}, "speed": {"walk": 0 if part == "head" else 5},
			"abilities": {"str": 13, "dex": 6, "con": 16, "int": 3, "wis": 6, "cha": 5}, "cr": 0, "xp": 0, "proficiency_bonus": 2,
			"condition_immunities": ["poisoned"], "immunities": ["poison"], "ai_profile": "mindless",
			"actions": [{"id": "claw" if part == "arm" else "bite", "name": "Claw" if part == "arm" else "Bite", "kind": "melee",
				"attack": {"bonus": 3, "reach": 5 if part == "arm" else 0}, "damage": [{"average": 4, "dice": "1d6+1" if part == "arm" else "1d4+1", "type": "slashing" if part == "arm" else "piercing"}],
				"summary": "A severed part attacks."}]}
		var m := Monster.from_data(block, null)
		var pc := e.add(m, target.side, e.spells._free_cell_near(target.cell))
		pc.set_meta("shares_hp_with", target.id)
		pc.set_meta("vanishes", true)
		if part == "arm":
			pc.set_meta("attack_disadvantage", true)
		e.insert_after(target, pc)
		e.events.append({"type": "summon_creature", "id": pc.id, "cell": pc.cell, "caster": target.id})


## Damage dealt to a severed part goes to the body; when the body drops, every part dies.
func redirect_shared(target: Combatant) -> Combatant:
	if target.has_meta("shares_hp_with"):
		var body := enc().get_c(str(target.get_meta("shares_hp_with")))
		if body != null and body.is_alive():
			return body
	return target


func body_dropped(body: Combatant) -> void:
	var e := enc()
	if body.has_meta("possessed_by"):
		end_possession(body)
	for o in e.combatants:
		if str(o.get_meta("shares_hp_with", "")) == body.id and o.is_alive():
			o.creature.dead = true
			e.events.append({"type": "death", "id": o.id})


## Possession (ghost): the ghost vanishes into a Humanoid's body, which fights for the ghost's side (the target is
## Incapacitated inside, aware but not in control) until the body drops to 0 Hit Points or the ghost leaves.
func possess(src: Combatant, t: Combatant, label: String) -> void:
	var e := enc()
	# Lordly Resolve: a creature it steadies can't be possessed.
	if t.has_meta("possessed_by") or src.has_meta("possessing") or t.creature.has_flag("no_possession"):
		return
	t.set_meta("possessed_by", src.id)
	t.set_meta("possessed_from", [str(t.side), str(t.controller)])
	t.side = src.side
	t.controller = src.controller
	var fx := Effect.new("Possessed by %s" % src.name(), &"monster", "possession:%s" % src.id)
	fx.caster_id = src.id
	fx.ends = Effect.Ends.NEVER
	t.creature.add_effect(fx)
	src.set_meta("possessing", t.id)
	var hide := Effect.new("Inside %s" % t.name(), &"monster", "possessing").with_modifier("flag", {"value": "ethereal"})
	hide.ends = Effect.Ends.NEVER
	src.creature.add_effect(hide)
	e.log.add("condition", "%s possesses %s (%s)" % [src.name(), t.name(), label], src.id)
	e.events.append({"type": "condition", "id": t.id})


## The ghost leaves the body: it reappears beside it, the body's owner takes control again and can't be possessed
## by this ghost for a day.
func end_possession(body: Combatant) -> void:
	var e := enc()
	var ghost := e.get_c(str(body.get_meta("possessed_by", "")))
	var was := body.get_meta("possessed_from", []) as Array
	body.remove_meta("possessed_by")
	body.remove_meta("possessed_from")
	if was.size() == 2:
		body.side = StringName(str(was[0]))
		body.controller = StringName(str(was[1]))
	for fx: Effect in body.creature.effects.duplicate():
		if fx.source_id.begins_with("possession:"):
			body.creature.remove_effect(fx)
	if ghost == null:
		return
	body.set_meta(ClassFeatures.meta_key("immune_%s_Possession" % ghost.id), true)
	ghost.remove_meta("possessing")
	for fx2: Effect in ghost.creature.effects.duplicate():
		if fx2.source_id == "possessing":
			ghost.creature.remove_effect(fx2)
	var from := ghost.cell
	ghost.cell = e.spells._beside(ghost, body)
	e.events.append({"type": "teleport", "id": ghost.id, "from": from, "to": ghost.cell})
	e.log.add("info", "%s slips out of %s" % [ghost.name(), body.name()], ghost.id)


## The lycanthropy curse: a cursed creature that drops to 0 Hit Points turns into a Werewolf under the DM's control
## with 10 Hit Points. True if it did.
func lycanthrope(t: Combatant) -> bool:
	var e := enc()
	# "lycanthropy" is the werewolf's curse; "<kind>_lycanthropy" another lycanthrope's (a wereraven's beak).
	var kind := ""
	for m0 in t.creature.modifiers_for(&"flag"):
		var v := m0.text("value")
		if v == "curse:lycanthropy":
			kind = "werewolf"
		elif v.begins_with("curse:") and v.ends_with("_lycanthropy"):
			kind = v.trim_prefix("curse:").trim_suffix("_lycanthropy")
	if kind == "":
		return false
	var wolf := Compendium.shared().monster_data(kind)
	if wolf.is_empty():
		return false
	var m := Monster.from_data(wolf)
	m.name = "%s (%s)" % [t.name(), kind]
	m.hp = 10
	t.creature.dead = true
	e.events.append({"type": "vanish", "id": t.id})
	var w := e.add(m, &"enemy", t.cell)
	e.insert_after(t, w)
	e.events.append({"type": "summon_creature", "id": w.id, "cell": w.cell, "caster": t.id})
	e.log.add("death", "%s changes into a %s!" % [t.name(), kind], w.id)
	return true


# --- Bonus Actions and Reactions ------------------------------------------------------------------

## The monster's Bonus Action this turn, chosen by the AI: Deathless Agility, Shadow Stealth, Shape-Shift, Divine
## Aid, a summoned Fey Spirit's Fey Step. Returns a result (or one that did nothing).
func bonus_action(c: Combatant, plan: String = "") -> CombatResult:
	var e := enc()
	if not c.bonus_available or not c.can_act():
		return CombatResult.new()
	for raw: Variant in data_of(c).get("bonus_actions", []):
		var act := raw as Dictionary
		if why_not(c, act) != "":
			continue
		match str(act.get("do", act.get("id", ""))):
			"dash_or_disengage":
				if not plan in ["dash", "retreat"]:
					continue
				if (plan == "dash" and c.creature.has_flag("cannot_dash")) or (plan == "retreat" and not e.can_disengage(c)):
					continue
				c.bonus_available = false
				if plan == "retreat":
					c.disengaged = true
					e.log.add("info", "%s Disengages (%s)" % [c.name(), act.get("name", "")], c.id)
				else:
					c.movement_left += c.speed()
					e.log.add("info", "%s Dashes (%s)" % [c.name(), act.get("name", "")], c.id)
				return CombatResult.new()
			"hide_in_dim":
				if plan == "hide" and e.light_at(c.cell) in ["dim", "dark", "magic_dark"]:
					var keep := c.action_available
					c.action_available = true
					c.bonus_available = true
					var cunning_free := e.hide_blocker(c)
					c.action_available = keep
					if cunning_free == "":
						c.bonus_available = false
						var t := c.creature.roll_check(e.dice, &"stealth", 15)
						if t.success:
							c.hidden = true
							c.stealth_total = t.total
							c.creature.add_condition(&"invisible", "Hidden")
						e.log.add("info", "%s melts into the shadows (Stealth %d)" % [c.name(), t.total], c.id)
				return CombatResult.new()
			"shape_shift":
				if plan == "shift" and str(c.get_meta("form", "humanoid")) == "humanoid":
					c.bonus_available = false
					c.set_meta("form", "hybrid")
					e.log.add("info", "%s twists into a snarling hybrid form" % c.name(), c.id)
				return CombatResult.new()
			"cast":
				if plan == "support":
					return _divine_aid(c, act)
			"cast_control":
				if plan == "control":
					return _control_spell(c, act)
			"fey_step":
				if plan == "fey_step":
					return _fey_step(c, act)
			"swoop":
				if plan == "swoop":
					return _swoop(c, act)
			"consume_life":
				if plan == "consume_life":
					return _consume_life(c, act)
			"vow":
				if plan == "vow" and why_not(c, act) == "":
					var foe: Combatant = null
					for h in e.hostiles_of(c):
						if not h.is_down() and e.distance(c, h) <= int((act.get("targets", {}) as Dictionary).get("range", 30)) and e.can_see(c, h) and (foe == null or h.creature.hp > foe.creature.hp):
							foe = h
					if foe != null:
						c.bonus_available = false
						spend(c, act)
						for o in e.combatants:
							if str(o.get_meta("vowed_by", "")) == c.id:
								o.remove_meta("vowed_by")
						foe.set_meta("vowed_by", c.id)
						e.log.add("condition", "%s swears vengeance on %s" % [c.name(), foe.name()], c.id)
					return CombatResult.new()
			"trample", "bonus_save":
				if plan in ["trample", "bonus_save"] and act.has("save"):
					var st := save_targets(c, act)
					if not st.is_empty():
						c.bonus_available = false
						# The saves can pause for a hero's choice: the result says so, and the AI's next step waits.
						return save_action(c, act, st[0], CombatResult.new())
			"rampage":
				if plan == "rampage":
					return _rampage(c, act)
			"vanish":
				if plan == "vanish" and not c.creature.has_condition(&"invisible"):
					c.bonus_available = false
					var fx := Effect.new("Vanished", &"monster", "vanish")
					fx.conditions.append(&"invisible")
					fx.ends = Effect.Ends.NEVER
					c.creature.add_effect(fx)
					e.log.add("info", "%s winks out of sight" % c.name(), c.id)
					return CombatResult.new()
	return CombatResult.new()


func _divine_aid(c: Combatant, act: Dictionary) -> CombatResult:
	var e := enc()
	var hurt: Combatant = null
	for a in e.allies_of(c):
		if a.creature.hp <= 0 or (a.creature.is_bloodied() and e.distance(c, a) <= 60):
			hurt = a
			break
	if hurt != null and "healing_word" in (act.get("cast", []) as Array):
		c.bonus_available = false
		spend(c, act)
		return cast(c, "healing_word", [hurt])
	return CombatResult.new()


## A control spell cast as a Bonus Action (a stone golem's Slow): aimed at the nearest foe it can see and up to five
## more foes within 20 ft of it (the spell's 40-ft cube), when at least two would be caught.
func _control_spell(c: Combatant, act: Dictionary) -> CombatResult:
	var e := enc()
	var spell_id := str((act.get("cast", []) as Array)[0]) if not (act.get("cast", []) as Array).is_empty() else ""
	var anchor: Combatant = null
	for h in e.hostiles_of(c):
		if not h.is_down() and e.can_see(c, h) and e.distance(c, h) <= 120 and (anchor == null or e.distance(c, h) < e.distance(c, anchor)):
			anchor = h
	if spell_id == "" or anchor == null:
		return CombatResult.new()
	var group: Array = []
	for h2 in e.hostiles_of(c):
		if not h2.is_down() and e.distance(anchor, h2) <= 20 and group.size() < 6:
			group.append(h2)
	if group.size() < 2:
		return CombatResult.new()
	c.bonus_available = false
	spend(c, act)
	return cast(c, spell_id, group)


## Rampage (giant hyena): right after it damages a creature that was already Bloodied, it moves up to half its
## Speed and bites again.
func _rampage(c: Combatant, act: Dictionary) -> CombatResult:
	var e := enc()
	if str(c.get_meta("hit_bloodied", "")) != "%d:%d" % [e.round_no, e.turn_index]:
		return CombatResult.new()
	var bite := str(act.get("attack", "bite"))
	var target: Combatant = null
	for h in e.hostiles_of(c):
		if not h.is_down() and (target == null or e.distance(c, h) < e.distance(c, target)):
			target = h
	if target == null:
		return CombatResult.new()
	c.bonus_available = false
	spend(c, act)
	c.remove_meta("hit_bloodied")
	c.movement_left += c.speed() / 2
	e.log.add("info", "%s goes on a rampage" % c.name(), c.id)
	var dest := e.spells._beside(c, target)
	var go := e.move(c, dest) if e.distance(c, target) > 5 and dest != target.cell else CombatResult.new()
	return e.then(go, func() -> CombatResult:
		if not c.can_act() or target.is_down() or e.distance(c, target) > 5:
			return CombatResult.new()
		c.attacks_left += 1
		return e.monster_attack(c, target, bite))


## Consume Life (will-o'-wisp): a living creature at 0 Hit Points within 5 ft makes a DC 10 Constitution save or
## dies, and the wisp regains 3d6 Hit Points.
func _consume_life(c: Combatant, act: Dictionary) -> CombatResult:
	var e := enc()
	for t in e.living():
		if t == c or not t.is_down() or str(t.creature.creature_type) in ["undead", "construct"] or e.distance(c, t) > 5 or not e.can_see(c, t):
			continue
		c.bonus_available = false
		end_vanish(c)
		var test := t.creature.roll_save(e.dice, &"con", int(act.get("dc", 10)), [], [], "Con save vs Consume Life (%s)" % t.name())
		if test.success:
			e.log.add("info", "%s clings to life" % t.name(), t.id, [test.describe()])
			return CombatResult.new()
		t.creature.dead = true
		e.events.append({"type": "death", "id": t.id})
		var rolled := e._roll_damage_dice("3d6", false, 0, "Consume Life")
		var healed := c.creature.heal(int(rolled["total"]), "Consume Life")
		e.log.add("heal", "%s drinks the last of %s's life and regains %d Hit Points" % [c.name(), t.name(), healed], c.id, [test.describe(), str(rolled["text"])])
		return CombatResult.new()
	return CombatResult.new()


## Vanish ends when the wisp attacks or uses Consume Life.
func end_vanish(c: Combatant) -> void:
	for fx: Effect in c.creature.effects.duplicate():
		if fx.source_id == "vanish":
			c.creature.remove_effect(fx)


## Traits that react to a damage type: Aversion to Fire (flesh golem: Disadvantage on attacks and checks until the end
## of its next turn) and Freeze (water elemental: 20 ft slower until the end of its next turn).
func damage_traits(target: Combatant, parts: Array) -> void:
	var e := enc()
	var types := {}
	for p: Variant in parts:
		if int((p as Dictionary).get("amount", 0)) > 0:
			types[str((p as Dictionary)["type"])] = true
	if types.has("fire") and has_trait(target, "aversion_to_fire"):
		var fx := Effect.new("Aversion to Fire", &"monster", "aversion_to_fire") \
			.with_modifier("disadvantage", {"on": "attack"}).with_modifier("disadvantage", {"on": "check:all"})
		_until_own_turn_end(target, fx)
		e.log.add("condition", "%s recoils from the flames" % target.name(), target.id)
	if types.has("cold") and has_trait(target, "freeze"):
		var fx2 := Effect.new("Freeze", &"monster", "freeze").with_modifier("speed", {"value": -20})
		_until_own_turn_end(target, fx2)
		e.log.add("condition", "%s partly freezes (-20 ft Speed)" % target.name(), target.id)


func _until_own_turn_end(t: Combatant, fx: Effect) -> void:
	for old: Effect in t.creature.effects.duplicate():
		if old.source_id == fx.source_id:
			t.creature.remove_effect(old)
	fx.ends = Effect.Ends.END_OF_TURN
	fx.turn_owner_id = t.id
	fx.skip_turn_ends = enc().own_turn_skip(t)
	t.creature.add_effect(fx)


## Swoop (roc): with a creature in its talons it climbs half its Fly Speed, out of reach without Opportunity Attacks,
## and lets go; the victim falls that far (1d6 per 10 ft) and lands Prone.
func _swoop(c: Combatant, act: Dictionary) -> CombatResult:
	var e := enc()
	var held: Combatant = null
	for k: String in e.grapples:
		if str(e.grapples[k]) == c.id:
			held = e.get_c(k)
	if held == null:
		return CombatResult.new()
	c.bonus_available = false
	spend(c, act)
	var feet := c.creature.speed("fly").total() / 2
	e._release_grapples_by(c)
	e.log.add("info", "%s soars %d ft up and drops %s" % [c.name(), feet, held.name()], c.id)
	e.spells.specials.high.fall(held.id, feet)
	c.disengaged = true
	return CombatResult.new()


## A summoned Fey Spirit's Fey Step: teleport up to 30 ft next to an enemy, then the mood's rider.
func _fey_step(c: Combatant, act: Dictionary) -> CombatResult:
	var e := enc()
	var target := e.ai._nearest_enemy(c)
	if target == null:
		return CombatResult.new()
	var cell := e.spells._beside(c, target)
	if e.grid.distance_ft(c.cell, c.size_cells, cell, 1) > 30 or e.occupant_at(cell) != null:
		return CombatResult.new()
	c.bonus_available = false
	var r := CombatResult.new()
	e.spells._teleport(c, cell, r)
	_fey_step_rider(c, act, r)
	return r


## What Fey Step does after the teleport, by the spirit's mood.
func _fey_step_rider(c: Combatant, act: Dictionary, r: CombatResult) -> void:
	var e := enc()
	match str(act.get("mood", "")):
		"fuming":
			e.add_mark({"kind": "advantage_next_attack", "attacker": c.id, "source": "Fey Step (Fuming)", "expires_owner": c.id, "expires_phase": "end", "consume": true})
		"mirthful":
			for o in e.hostiles_of(c):
				if e.distance(c, o) <= 10:
					apply_riders(c, o, [{"do": "condition", "condition": "charmed", "save": {"ability": "wis", "dc": int(act.get("save_dc", 13))}, "until": "minute"}], {}, "Fey Step")
					break
		"tricksy":
			var o2 := FieldObject.new(FieldObject.Kind.ZONE, "fey_darkness", "Tricksy darkness")
			o2.caster_id = c.id
			o2.cells = [c.cell + Vector2i(1, 0)]
			o2.rules = {"darkness": true, "obscured": "heavy", "triggers": []}
			o2.rounds_left = 1
			e.spells.zones.add(o2, r)


## Parry (bandit captain, noble, veteran): +AC against one melee hit while holding a weapon. Offered like Shield.
func parry_offer(st: Dictionary, miss: Callable) -> Array:
	var e := enc()
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var out: Array = []
	if not target.creature is Monster or not bool((st["option"] as Dictionary)["melee"]) or e.ground.empty_handed(target):
		return out
	var t := st["t"] as D20Test
	for raw: Variant in data_of(target).get("reactions", []):
		var act := raw as Dictionary
		var bonus := int(act.get("ac_bonus", 0))
		if bonus <= 0 or bool(st.get("critical", false)) or not e.spells.can_react(target) or t.total >= int(st["ac"]) + bonus:
			continue
		out.append({"kind": "parry", "reactor": target, "trigger": c.id, "title": "Parry", "text": "%s parries" % target.name(),
			"use": func() -> void:
				target.reaction_available = false
				e.log.add("reaction", "%s parries (+%d AC)" % [target.name(), bonus], target.id),
			"stop": func() -> CombatResult:
				st["ac"] = int(st["ac"]) + bonus
				return miss.call() as CombatResult})
	return out


## Death Throes (a demon Fiendish Spirit): it explodes as it dies; creatures nearby make a Dexterity save.
func death_burst(c: Combatant) -> void:
	var e := enc()
	for tr: Variant in traits(c):
		var b := (tr as Dictionary).get("death_burst", {}) as Dictionary
		if b.is_empty():
			continue
		var dmg := b["damage"] as Dictionary
		var rolled := e._roll_damage_dice(str(dmg["dice"]), false, 0, str((tr as Dictionary).get("name", "Death Throes")))
		e.log.add("spell", "%s bursts apart in flame" % c.name(), c.id)
		for o in e.living():
			if o == c or e.distance(c, o) > int(b.get("radius", 10)):
				continue
			var sv := o.creature.roll_save(e.dice, &"dex", int((b["save"] as Dictionary)["dc"]), [], [], "Dexterity save vs Death Throes (%s)" % o.name())
			var amt := int(rolled["total"]) / 2 if sv.success else int(rolled["total"])
			e.deal_damage(c, o, [{"amount": amt, "type": str(dmg["type"])}], false, "Death Throes", [sv.describe(), str(rolled["text"])])
