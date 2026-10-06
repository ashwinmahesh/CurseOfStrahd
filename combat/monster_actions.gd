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
	if act.has("forms") and not str(c.get_meta("form", "humanoid")) in (act["forms"] as Array):
		return "Not in this form"
	if c.has_meta("disarmed") and bool(act.get("weapon", false)):
		return "Disarmed"
	return ""


func spend(c: Combatant, act: Dictionary) -> void:
	if act.has("recharge"):
		c.set_meta("charged_%s" % act["id"], false)
	if act.has("uses"):
		c.set_meta("used_%s" % act["id"], int(c.get_meta("used_%s" % act["id"], 0)) + 1)


## Recharge X-6 is rolled at the start of the monster's turn.
func roll_recharges(c: Combatant) -> void:
	for a: Variant in data_of(c).get("actions", []):
		var act := a as Dictionary
		if not act.has("recharge") or bool(c.get_meta("charged_%s" % act["id"], true)):
			continue
		var low := int(str(act["recharge"]).get_slice("-", 0))
		var roll := enc().dice.roll_one(6, "Recharge %s" % act.get("name", ""))
		if roll >= low:
			c.set_meta("charged_%s" % act["id"], true)
			enc().log.add("info", "%s's %s recharges (d6: %d)" % [c.name(), act.get("name", ""), roll], c.id)


# --- Riders on a hit or a failed save -------------------------------------------------------------

## Applies `riders` from `src` to `t` after damage `by_type` ({type: amount taken}).
func apply_riders(src: Combatant, t: Combatant, riders: Array, by_type: Dictionary, act_name: String) -> void:
	var e := enc()
	for raw: Variant in riders:
		var rd := raw as Dictionary
		if not t.is_alive():
			return
		if rd.has("not_types") and str(t.creature.creature_type) in (rd["not_types"] as Array):
			continue
		if rd.has("only_types") and not str(t.creature.creature_type) in (rd["only_types"] as Array):
			continue
		if rd.has("not_species") and t.creature is Character and str((t.creature as Character).build.get("species", "")) in (rd["not_species"] as Array):
			e.log.add("info", "%s is unaffected (%s)" % [t.name(), str((t.creature as Character).build.get("species", "")).capitalize()], t.id)
			continue
		if rd.has("max_size") and Creature.SIZES.find(t.creature.size) > Creature.SIZES.find(StringName(str(rd["max_size"]))):
			continue
		if bool(rd.get("immune_on_success", false)) and t.has_meta("immune_%s_%s" % [src.id, act_name]):
			continue
		if rd.has("save"):
			var sv := rd["save"] as Dictionary
			var cond := str(rd.get("condition", ""))
			var keys: Array[String] = []
			if cond != "":
				keys.append("save_vs:%s" % cond)
			var ab := StringName(str(sv["ability"]))
			var test := t.creature.roll_save(e.dice, ab, int(sv["dc"]), [], [], "%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], act_name, t.name()], keys)
			if test.success:
				e.log.add("info", "%s resists %s" % [t.name(), act_name], t.id, [test.describe()])
				if bool(rd.get("immune_on_success", false)):
					t.set_meta("immune_%s_%s" % [src.id, act_name], true)
				continue
		match str(rd["do"]):
			"condition":
				_timed_condition(src, t, str(rd["condition"]), str(rd.get("until", "permanent")), act_name, rd.get("modifiers", []) as Array)
			"grapple":
				grapple(src, t, int(rd.get("escape_dc", 10)), int(rd.get("limit", 1)), act_name)
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
func _timed_condition(src: Combatant, t: Combatant, cond: String, until: String, label: String, mods: Array) -> void:
	var e := enc()
	var fx := Effect.new("%s (%s)" % [cond.capitalize(), label] if cond != "" else label, &"monster", "%s:%s" % [src.id, label])
	fx.caster_id = src.id
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


## A grapple from a stat block: registered like an Unarmed Strike grapple, with the printed escape DC; a creature
## can hold only `limit` creatures at once (the Vampire Spawn's two claws).
func grapple(src: Combatant, t: Combatant, escape_dc: int, limit: int, label: String) -> void:
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
	e.log.add("condition", "%s grabs %s (%s, escape DC %d)" % [src.name(), t.name(), label, escape_dc], src.id)


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
		if tg.has("requires"):
			var ok := false
			for need: Variant in tg["requires"]:
				if str(need) == "willing":
					continue
				if t.creature.has_condition(StringName(str(need))):
					ok = true
			if not ok:
				continue
		out.append(t)
	return out


## A save action (Bite, Engulf, Cacophony): the target saves; on a failure damage and the riders.
func save_action(c: Combatant, act: Dictionary, t: Combatant, r: CombatResult) -> void:
	var e := enc()
	var sv := act["save"] as Dictionary
	var ab := StringName(str(sv["ability"]))
	spend(c, act)
	e.log.add("info", "%s uses %s on %s" % [c.name(), act.get("name", ""), t.name()], c.id)
	var test := t.creature.roll_save(e.dice, ab, int(sv["dc"]), [], [], "%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], act.get("name", ""), t.name()])
	var by_type := {}
	var parts: Array = []
	var texts: Array[String] = [test.describe()]
	for d: Variant in act.get("damage", []):
		var dd := d as Dictionary
		if dd.has("when"):
			continue
		var rolled := e._roll_damage_dice(str(dd["dice"]), false, 0, str(act.get("name", "")))
		var amount := int(rolled["total"])
		if test.success:
			amount = amount / 2 if str(sv.get("success", "none")) == "half" else 0
		parts.append({"amount": amount, "type": str(dd["type"])})
		texts.append(str(rolled["text"]))
	if not parts.is_empty() and parts.any(func(p: Dictionary) -> bool: return int(p["amount"]) > 0):
		var dr := e.deal_damage(c, t, parts, false, str(act.get("name", "")), texts)
		r.damage += dr.final
		by_type = taken_by_type(t, parts)
	elif test.success:
		e.log.add("info", "%s resists %s" % [t.name(), act.get("name", "")], t.id, texts)
	if not test.success and t.is_alive():
		apply_riders(c, t, act.get("on_fail", []) as Array, by_type, str(act.get("name", "")))


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
func cast(c: Combatant, spell_id: String, targets: Array, point: Vector2 = Vector2.INF, slot: int = 0) -> CombatResult:
	var e := enc()
	var sc := data_of(c).get("spellcasting", {}) as Dictionary
	var s := Compendium.shared().spell_data(spell_id)
	if s.is_empty():
		return CombatResult.fail("Unknown spell")
	var per_day := sc.get("per_day", {}) as Dictionary
	for n: String in per_day:
		if spell_id in (per_day[n] as Array):
			c.set_meta("cast_%s" % spell_id, int(c.get_meta("cast_%s" % spell_id, 0)) + 1)
	var levels := sc.get("levels", {}) as Dictionary
	var level := int(levels.get(spell_id, maxi(slot, int(s.get("level", 0)))))
	var ab := StringName(str(sc.get("ability", "int")))
	var dc := Breakdown.new("Spell save DC").add("Stat block", int(sc.get("dc", 8 + c.creature.ability_mod(ab) + c.creature.proficiency_bonus())))
	var atk := Breakdown.new("Spell attack").add("Stat block", int(sc.get("attack", c.creature.ability_mod(ab) + c.creature.proficiency_bonus())))
	return e.spells.cast_with_numbers(c, spell_id, level, targets, point, {"dc": dc, "attack": atk, "mod": c.creature.ability_mod(ab), "ability": ab})


# --- Turn hooks -----------------------------------------------------------------------------------

## Start of `c`'s turn: Recharge, auras of nearby monsters (Stench, Festering Aura), Engulf damage, Sunlight
## Hypersensitivity.
func turn_start(c: Combatant) -> void:
	var e := enc()
	if c.creature is Monster:
		roll_recharges(c)
	for o in e.living():
		if o == c or o.is_down():
			continue
		for tr: Variant in traits(o):
			var aura := (tr as Dictionary).get("aura", {}) as Dictionary
			if aura.is_empty() or str(aura.get("trigger", "start_turn")) != "start_turn":
				continue
			_aura_on(o, c, tr as Dictionary)
	# Auras that act at the start of their owner's turn (the Aberrant Spirit's Whispering Aura).
	if c.can_act():
		for tr2: Variant in traits(c):
			var aura2 := (tr2 as Dictionary).get("aura", {}) as Dictionary
			if aura2.is_empty() or str(aura2.get("trigger", "")) != "own_turn_start":
				continue
			for o2 in e.living():
				if o2 != c and not o2.is_down():
					_aura_on(c, o2, tr2 as Dictionary)
	# Regeneration (the Slaad spirit): Hit Points back at the start of its turn while it has at least 1.
	for tr3: Variant in traits(c):
		var regen := int((tr3 as Dictionary).get("regenerate", 0))
		if regen > 0 and c.creature.hp >= 1 and not c.creature.has_flag("cant_regain_hp"):
			var healed := c.creature.heal(regen, str((tr3 as Dictionary).get("name", "Regeneration")))
			if healed > 0:
				e.log.add("heal", "%s regenerates %d Hit Points" % [c.name(), healed], c.id)
				e.events.append({"type": "heal", "id": c.id, "amount": healed})
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


## One aura from `o` reaching `c`: a save, then a timed condition or hindrance (Stench, Festering Aura, Stony Lethargy)
## or damage (Whispering Aura).
func _aura_on(o: Combatant, c: Combatant, tr: Dictionary) -> void:
	var e := enc()
	var aura := tr.get("aura", {}) as Dictionary
	if str(aura.get("affects", "others")) == "enemies" and not o.hostile_to(c):
		return
	if e.distance(o, c) > int(aura.get("radius", 5)):
		return
	var label := str(tr.get("name", "Aura"))
	if c.has_meta("immune_%s_%s" % [o.id, label]):
		return
	if aura.has("damage"):
		var sv := aura["save"] as Dictionary
		var ab := StringName(str(sv["ability"]))
		var test := c.creature.roll_save(e.dice, ab, int(sv["dc"]), [], [], "%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], label, c.name()])
		if test.success:
			e.log.add("info", "%s resists %s" % [c.name(), label], c.id, [test.describe()])
			return
		var dmg := aura["damage"] as Dictionary
		var rolled := e._roll_damage_dice(str(dmg["dice"]), false, 0, label)
		e.deal_damage(o, c, [{"amount": int(rolled["total"]), "type": str(dmg["type"])}], false, label, [test.describe(), str(rolled["text"])])
		return
	apply_riders(o, c, [{"do": "condition", "condition": str(aura.get("condition", "")), "save": aura["save"], "until": str(aura.get("until", "target_turn_start")),
		"immune_on_success": bool(aura.get("immune_on_success", false)), "modifiers": aura.get("modifiers", [])}], {}, label)


## End of `c`'s turn: Incorporeal Movement inside an object (a wall square) costs 1d10 Force.
func turn_end(c: Combatant) -> void:
	var e := enc()
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
	for o in e.combatants:
		if str(o.get_meta("shares_hp_with", "")) == body.id and o.is_alive():
			o.creature.dead = true
			e.events.append({"type": "death", "id": o.id})


## The lycanthropy curse: a cursed creature that drops to 0 Hit Points turns into a Werewolf under the DM's control
## with 10 Hit Points. True if it did.
func lycanthrope(t: Combatant) -> bool:
	var e := enc()
	if not t.creature.has_flag("curse:lycanthropy"):
		return false
	var wolf := Compendium.shared().monster_data("werewolf")
	if wolf.is_empty():
		return false
	var m := Monster.from_data(wolf)
	m.name = "%s (werewolf)" % t.name()
	m.hp = 10
	t.creature.dead = true
	e.events.append({"type": "vanish", "id": t.id})
	var w := e.add(m, &"enemy", t.cell)
	e.insert_after(t, w)
	e.events.append({"type": "summon_creature", "id": w.id, "cell": w.cell, "caster": t.id})
	e.log.add("death", "%s changes into a werewolf!" % t.name(), w.id)
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
			"fey_step":
				if plan == "fey_step":
					return _fey_step(c, act)
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
	if not target.creature is Monster or not bool((st["option"] as Dictionary)["melee"]) or target.has_meta("disarmed"):
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
