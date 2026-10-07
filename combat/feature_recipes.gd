class_name FeatureRecipes
extends RefCounted
## Data-defined feature activations reuse the same targeting, effect, and duration primitives as spells.
## Validation is read-only and complete before an action, resource, or spell slot is spent.

var _enc: WeakRef

func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)

func enc() -> Encounter:
	return _enc.get_ref() as Encounter

func context(c: Combatant, f: Dictionary) -> Dictionary:
	var ctx := c.creature.formula_context()
	ctx["class_level"] = (c.creature as Character).class_level_of(str(f["class_id"]))
	return ctx

func activation(c: Combatant, f: Dictionary) -> Dictionary:
	var result := (f["activation"] as Dictionary).duplicate(true)
	for raw: Variant in result.get("upgrades", []):
		var upgrade := raw as Dictionary
		if int(context(c, f)["class_level"]) >= int(upgrade["at_level"]):
			result.merge(upgrade, true)
	return result


func count(c: Combatant, f: Dictionary) -> int:
	return maxi(1, Formula.evaluate((f["activation"] as Dictionary).get("count", 1), context(c, f)))

func why(c: Combatant, f: Dictionary) -> String:
	var e := enc()
	var a := activation(c, f)
	var cost := str(a.get("cost", "magic"))
	var situation := c.creature.armor_situation()
	if bool(a.get("unarmored", false)) and (str(situation["armor"]) != "none" or bool(situation["shield"])):
		return "Requires no armor or Shield"
	var reason := e._bonus_check(c) if cost == "bonus" else e._action_check(c)
	if cost == "free":
		reason = e._turn_check(c)
	if reason == "" and cost == "magic" and c.magic_action_used:
		reason = "Only one Magic action this turn"
	if reason == "" and str(a.get("resource", "")) != "" and (c.creature as Character).resource_left(str(a["resource"])) <= 0:
		reason = "None left"
	return reason

func list(c: Combatant, out: Array[Dictionary]) -> void:
	if not c.creature is Character:
		return
	enc().reactions.list_policies(c, out)
	enc().damage_responses.list(c, out)
	for option in enc().triggered_features.sequence_attack_options(c):
		var rule := c.get_meta("sequence_attacks") as Dictionary
		var profile := option["profile"] as WeaponProfile
		out.append({"id": "feat:sequence_attack:" + str(option["id"]), "label": "%s: %s" % [rule["label"], profile.name],
			"sub": "%d attack left" % rule["remaining"], "cost": "free", "why": e_turn(c), "targeting": "enemy", "range": profile.reach,
			"help": "Complete the attacks granted by the Bonus Action already spent."})
	for option in (c.creature as Character).slot_conversion_options():
		out.append({"id": "feat:slot_exchange:%s:%d" % [option["feature"], option["slot"]],
			"label": "%s: recover %d %s" % [option["label"], option["slot"], str(option["resource"]).replace("_", " ")],
			"sub": "level %d slot" % option["slot"], "cost": "free", "why": e_turn(c), "targeting": "none", "range": 0,
			"help": "Expend a spell slot to restore the same number of resource points, up to your maximum."})
	for f in (c.creature as Character).features:
		if not f.has("activation"):
			continue
		var a := activation(c, f)
		if not bool(a.get("restore_only", false)):
			out.append({"id": "feat:recipe:" + str(f["id"]), "label": str(f["name"]), "sub": str(a.get("sub", "")),
			"cost": "action" if str(a.get("cost", "magic")) == "magic" else str(a.get("cost", "magic")),
			"why": why(c, f), "targeting": str(a.get("targeting", "none")), "count": count(c, f),
			"range": int(a.get("range", 9999)), "help": str(f["summary"])})
		if bool(a.get("dismissible", false)) and c.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == str(f["id"])):
			out.append({"id": "feat:recipe:" + str(f["id"]) + ":dismiss", "label": "End " + str(f["name"]),
				"sub": "No action", "cost": "free", "why": "", "targeting": "none", "count": 1, "range": 0, "help": "End this effect voluntarily."})
		var restore := int(a.get("restore_slot", 0))
		if restore > 0:
			var ch := c.creature as Character
			for slot in range(restore, 10):
				if ch.slots_left(slot) <= 0:
					continue
				var reason := e_turn(c)
				if ch.resource_left(str(a["resource"])) >= ch.resource_max(str(a["resource"])):
					reason = "Already available"
				out.append({"id": "feat:recipe_restore:%s:%d" % [f["id"], slot], "label": "Restore %s" % f["name"],
					"sub": "level %d slot" % slot, "cost": "free", "why": reason, "targeting": "none", "range": 0,
					"help": "Spend this spell slot to restore a use without an action."})

func e_turn(c: Combatant) -> String:
	return enc()._turn_check(c)

func perform(c: Combatant, id: String, targets: Array, restore_slot: int = 0, cell: Vector2i = Vector2i(-1, -1)) -> CombatResult:
	var e := enc()
	var ch := c.creature as Character
	if ch == null:
		return CombatResult.fail("Not available")
	var dismiss := id.ends_with(":dismiss")
	if dismiss:
		id = id.trim_suffix(":dismiss")
	var f: Dictionary = {}
	for candidate in ch.features:
		if str(candidate["id"]) == id and candidate.has("activation"):
			f = candidate
	if f.is_empty():
		return CombatResult.fail("Not available")
	var a := activation(c, f)
	var resource := str(a.get("resource", ""))
	if dismiss:
		if not bool(a.get("dismissible", false)):
			return CombatResult.fail("Cannot dismiss that feature")
		for fx: Effect in c.creature.effects.duplicate():
			if fx.source_id == id:
				c.creature.remove_effect(fx)
		return CombatResult.new()
	if restore_slot > 0:
		var minimum := int(a.get("restore_slot", 0))
		if e_turn(c) != "" or minimum <= 0 or restore_slot < minimum or restore_slot > 9 or ch.slots_left(restore_slot) <= 0 or ch.resource_left(resource) >= ch.resource_max(resource):
			return CombatResult.fail("Cannot restore that use")
		ch.expend_slot(restore_slot)
		ch.restore_resource(resource, 1)
		e.log.add("info", "%s restores %s with a level %d slot" % [c.name(), f["name"], restore_slot], c.id)
		return CombatResult.new()
	if bool(a.get("restore_only", false)):
		return CombatResult.fail("Choose a spell to modify")
	var reason := why(c, f)
	if reason != "":
		return CombatResult.fail(reason)
	var teleport := str(a.get("do", "")) == "teleport"
	var swap: Combatant = null
	if teleport:
		var range_limit := int(a.get("range", 30))
		if not e.grid.in_bounds(cell) or e.grid.distance_ft(c.cell, c.size_cells, cell, 1) > range_limit or not e.can_see_space(c, cell):
			return CombatResult.fail("Choose a visible space within %d feet" % range_limit)
		swap = e.occupant_at(cell)
		if swap != null and (not bool(a.get("swap", false)) or swap == c or not c.allied_with(swap) or Creature.SIZES.find(swap.creature.size) > Creature.SIZES.find(&"medium")):
			return CombatResult.fail("Choose an empty space or a willing Medium or smaller ally")
		if swap != null:
			cell = swap.cell
		if not e.space_available(cell, c.size_cells, [c, swap]) or (swap != null and not e.space_available(c.cell, swap.size_cells, [c, swap])):
			return CombatResult.fail("There must be room at both destinations")
	var selected := targets.duplicate()
	if teleport or str(a.get("targeting", "none")) == "none":
		selected = [c]
	if selected.is_empty() or selected.size() > count(c, f):
		return CombatResult.fail("Choose 1 to %d creatures" % count(c, f))
	var seen: Array[String] = []
	for raw: Variant in selected:
		var t := raw as Combatant
		if t == null or not t in e.combatants or t.creature.dead or t.id in seen:
			return CombatResult.fail("Choose distinct creatures on the battlefield")
		if not teleport and e.distance(c, t) > int(a.get("range", 9999)) or (not teleport and str(a.get("targeting", "none")) != "none" and (not e.can_see(c, t) or int(e.cover(c, t)["cover"]) == CombatGrid.Cover.TOTAL)):
			return CombatResult.fail("Target must be visible and within range")
		if str(a.get("targeting", "")) == "ally" and not c.allied_with(t):
			return CombatResult.fail("Choose an ally")
		if str(a.get("targeting", "")) == "enemy" and not c.hostile_to(t):
			return CombatResult.fail("Choose an enemy")
		if bool(a.get("target_perceives_caster", false)) and not e.spells.can_see_or_hear(t, c):
			return CombatResult.fail("The target must be able to see or hear you")
		seen.append(t.id)
	var cost := str(a.get("cost", "magic"))
	if resource != "":
		ch.spend_resource(resource)
	if cost == "bonus":
		c.bonus_available = false
	elif cost != "free":
		e.spend_action(c)
		if cost == "magic":
			c.magic_action_used = true
	var r := CombatResult.new()
	if teleport:
		var from := c.cell
		if swap != null:
			# Both positions change before either arrival is resolved.
			swap.cell = from
			swap.clear_run()
			e.events.append({"type": "teleport", "id": swap.id, "from": cell, "to": from})
		e.spells._teleport(c, cell, r)
		if swap != null:
			e.spells.zones.on_moved(swap, cell)
		return r
	if str(a.get("do", "")) == "dodge":
		e.apply_dodge(c)
		return r
	var recipe := {"id": id, "name": str(f["name"]), "level": 0, "effect_source": "feature",
		"duration": a.get("duration", {"kind": "instantaneous"})}
	var ctx := {"c": c, "s": recipe, "slot": 0, "conc": null, "opts": {}, "nums": {"dc": Breakdown.new("DC"), "mod": 0}}
	var entries := (a.get("effects", []) as Array).duplicate(true)
	var formula := context(c, f)
	for raw: Variant in entries:
		var p := (raw as Dictionary).get("params", {}) as Dictionary
		if p.has("flat"):
			p["flat"] = Formula.evaluate(p["flat"], formula)
		for md: Variant in p.get("modifiers", []):
			var m := md as Dictionary
			if str(m.get("value", "")).contains("class_level"):
				m["value"] = Formula.evaluate(m["value"], formula)
	for raw: Variant in selected:
		var target := raw as Combatant
		if a.has("save"):
			var dc := ch.spell_save_dc(str(f["class_id"]))
			(ctx["nums"] as Dictionary)["dc"] = dc
			var keys: Array[String] = ["save_vs:magic"]
			for condition in e.spells._conditions_in(entries, ""):
				keys.append("save_vs:" + condition)
			var test := target.creature.roll_save(e.dice, StringName(str(a["save"])), dc.total(), [], [], str(f["name"]), keys)
			e.log.add("info", "%s %s against %s" % [target.name(), "saves" if test.success else "fails", f["name"]], target.id, [test.describe()])
			if test.success:
				continue
		e.spells.apply_effect_entries(ctx, target, entries, "cast", r)
	e.log.add("info", "%s uses %s" % [c.name(), f["name"]], c.id)
	return r


## Saving throws resolve synchronously: Reaction costs require explicit Auto; free responses default to Auto.
## The feature declares its trigger, range, cost, and adjustment instead of requiring an id-specific branch.
func after_d20(roller: Combatant, test: D20Test, keys: Array[String]) -> void:
	if test.success or test.target <= 0 or test.auto_failed:
		return
	var e := enc()
	for c in e.combatants:
		if not c.creature is Character or not c.is_alive():
			continue
		var ch := c.creature as Character
		for f in ch.features:
			if test.success:
				return
			if not f.has("roll_response"):
				continue
			var def := f["roll_response"] as Dictionary
			var kind := str(def.get("kind", "save"))
			if kind == "save" and test.kind != D20Test.Kind.SAVING_THROW:
				continue
			var required := def.get("keys_any", []) as Array
			if not required.is_empty() and not required.any(func(k: Variant) -> bool: return str(k) in keys):
				continue
			if c != roller and (str(def.get("scope", "self")) == "self" or not c.allied_with(roller)):
				continue
			if c != roller and (e.distance(c, roller) > int(def.get("range", 0)) or not e.can_see(c, roller)):
				continue
			var resource := str(def["resource"])
			var reaction := str(def.get("cost", "free")) == "reaction"
			var permitted := e._reaction_decision(c, str(f["id"])) == "auto" if reaction else str(c.reaction_rules.get(str(f["id"]), "auto")) != "never"
			if ch.resource_left(resource) <= 0 or (reaction and not e.spells.can_react(c)) or not permitted:
				continue
			ch.spend_resource(resource)
			if reaction:
				c.reaction_available = false
			if str(def.get("do", "add_die")) == "reroll":
				var again := D20Test.roll(e.dice, test.kind, test.modifier, test.target, 1 if test.advantage else 0, 1 if test.disadvantage else 0, str(f["name"]), test.crit_range)
				test.set_natural(again.kept, str(f["name"]))
			else:
				test.add_bonus(int(e.dice.roll_expr(str(def.get("dice", "1d4")), str(f["name"]))["total"]), str(f["name"]))
			e.log.add("reaction" if reaction else "info", "%s uses %s for %s" % [c.name(), f["name"], roller.name()], c.id, [test.describe()])


## Benefits attached to a newly summoned creature can depend on the school and actual slot expenditure.
func after_summon(ctx: Dictionary, creature: Creature) -> void:
	var c := ctx["c"] as Combatant
	if not c.creature is Character:
		return
	var s := ctx["s"] as Dictionary
	for f in (c.creature as Character).features:
		var recipe := f.get("summon_effect", {}) as Dictionary
		if recipe.is_empty() or (bool(recipe.get("requires_slot", false)) and not bool(ctx.get("spent_slot", false))):
			continue
		if recipe.has("school") and str(recipe["school"]) != str(s.get("school", "")):
			continue
		var amount := Formula.evaluate(recipe.get("temp_hp", 0), context(c, f))
		if not creature.add_temp_hp(amount, str(f["name"])):
			continue
		var fx := Effect.new(str(f["name"]), &"feature", str(f["id"]))
		fx.data["ends_without_temp_hp"] = true
		fx.data["temp_hp_bound"] = true
		for kind: Variant in recipe.get("resistance", []):
			fx.with_modifier("resistance", {"value": str(kind), "when": {"temporary_hp": true}})
		creature.add_effect(fx)


## Slot-paid casting triggers. Temporary speed bonuses share ordinary effect expiry and stacking.
func after_cast(c: Combatant, spell: Dictionary, slot: int) -> void:
	if slot <= 0:
		return
	for m in c.creature.modifiers_for(&"after_cast_speed"):
		if m.text("school", str(spell.get("school", ""))) != str(spell.get("school", "")):
			continue
		if enc().current() != c:
			continue
		var fx := Effect.new(m.source_name, &"feature", m.source_id)
		fx.caster_id = c.id
		fx.ends = Effect.Ends.END_OF_TURN
		fx.with_modifier("speed", {"value": c.creature.mod_value(m, c.creature.formula_context(slot))})
		c.creature.add_effect(fx)


## Reactions to an actual attack hit, after defensive responses have had a chance to turn it aside.
## No distance or sight restriction is implied: each feature declares those restrictions if it has them.
func hit_responses(attacker: Combatant, target: Combatant) -> Array:
	var out: Array = []
	if not target.creature is Character:
		return out
	for f in (target.creature as Character).features:
		if not f.has("hit_response"):
			continue
		var def := f["hit_response"] as Dictionary
		if not _hit_response_available(attacker, target, def):
			continue
		var feature := f
		out.append({"kind": str(f["id"]), "reactor": target, "trigger": attacker.id,
			"title": "Reaction: %s?" % f["name"], "text": str(f["summary"]),
			"cost": "Reaction and one use of %s" % f["name"],
			"still": func() -> bool: return _hit_response_available(attacker, target, feature["hit_response"] as Dictionary),
			"use": func() -> void: _use_hit_response(attacker, target, feature)})
	return out

func _hit_response_available(attacker: Combatant, target: Combatant, def: Dictionary) -> bool:
	return attacker != null and attacker.is_alive() and enc().spells.can_react(target) \
		and target.creature.resource_left(str(def["resource"])) > 0 \
		and (not def.has("range") or enc().distance(attacker, target) <= int(def["range"])) \
		and (not bool(def.get("requires_sight", false)) or enc().can_see(target, attacker))

func _use_hit_response(attacker: Combatant, target: Combatant, f: Dictionary) -> void:
	var def := f["hit_response"] as Dictionary
	if not _hit_response_available(attacker, target, def):
		return
	target.reaction_available = false
	target.creature.spend_resource(str(def["resource"]))
	var dc := (target.creature as Character).spell_save_dc(str(f["class_id"]))
	var keys: Array[String] = ["save_vs:magic"]
	keys.append_array(enc().spells._conditions_in(def["effects"] as Array, "").map(func(x: String) -> String: return "save_vs:" + x))
	var save := attacker.creature.roll_save(enc().dice, StringName(str(def["save"])), dc.total(), [], [], str(f["name"]), keys)
	enc().log.add("reaction", "%s uses %s against %s" % [target.name(), f["name"], attacker.name()], target.id, [save.describe()])
	if save.success:
		return
	var ctx := {"c": target, "s": {"id": str(f["id"]), "name": str(f["name"]), "level": 0, "effect_source": "feature", "duration": {"kind": "instantaneous"}},
		"slot": 0, "conc": null, "opts": {}, "nums": {"dc": dc, "mod": 0}}
	enc().spells.apply_effect_entries(ctx, attacker, def["effects"] as Array, "cast", CombatResult.new())

## Spell attacks currently resolve their rays synchronously, like saving-throw responses.
func synchronous_hit_responses(attacker: Combatant, target: Combatant) -> void:
	for raw: Variant in hit_responses(attacker, target):
		var offer := raw as Dictionary
		if enc()._reaction_decision(target, str(offer["kind"])) == "auto" and (offer["still"] as Callable).call():
			(offer["use"] as Callable).call()


## A recovery choice interrupts the triggering event; it never spends a Reaction or an action.
func offer_slot_recovery(c: Combatant, trigger: String) -> void:
	if not c.creature is Character:
		return
	var e := enc()
	var ch := c.creature as Character
	ch.open_slot_recovery(trigger)
	if e.pending != null:
		e.then(CombatResult.new(), func() -> CombatResult:
			offer_slot_recovery(c, trigger)
			var result := CombatResult.new()
			result.pending = e.pending
			return result)
		return
	var done := func() -> CombatResult:
		ch.close_slot_recovery()
		return CombatResult.new()
	var offers: Array = []
	for option in ch.slot_recovery_options():
		var pick := option
		offers.append({"kind": str(pick["feature"]), "reactor": c, "trigger": c.id,
			"title": "%s: recover a level %d slot?" % [pick["label"], pick["slot"]],
			"text": "Spend %d %s to recover one expended level %d spell slot." % [pick["cost"], str(pick["resource"]).replace("_", " "), pick["slot"]],
			"cost": "No action or Reaction", "spends_reaction": false,
			"still": func() -> bool: return ch.slot_recovery_options().any(func(o: Dictionary) -> bool: return o == pick),
			"use": func() -> void: ch.recover_slot_with_resource(str(pick["feature"]), int(pick["slot"])), "stop": done})
	e.reactions.offer(offers, done, CombatResult.new())


## Features can add ordinary effects when another feature has selected/affected a target.
func on_feature_target(c: Combatant, target: Combatant, trigger: String) -> void:
	if not c.creature is Character:
		return
	for feature in (c.creature as Character).features:
		var rule := feature.get("on_feature_target", {}) as Dictionary
		if str(rule.get("trigger", "")) != trigger:
			continue
		var recipe := {"id": str(feature["id"]), "name": str(feature["name"]), "level": 0, "effect_source": "feature"}
		var ctx := {"c": c, "s": recipe, "slot": 0, "conc": null, "opts": {}, "nums": {"dc": Breakdown.new("DC"), "mod": 0}}
		enc().spells.apply_effect_entries(ctx, target, rule["effects"] as Array, "cast", CombatResult.new())
