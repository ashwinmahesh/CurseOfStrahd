class_name SpellEffects
extends RefCounted
## A spell's effects from its data recipe (SpellCaster): conditions, modifiers and their durations, Enlarge/Reduce,
## Haste's lethargy, ending conditions, light, and the custom effects, each landing on the right target with the right
## save or escape.

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func sp() -> SpellCaster:
	return enc().spells


func _comp() -> Compendium:
	return Compendium.shared()


## The `on` an effect entry fires on when it doesn't say: hit for attack spells, fail for save spells, cast for
## everything else.
static func default_on(s: Dictionary) -> String:
	if s.has("attack"):
		return "hit"
	if s.has("save"):
		return "fail"
	return "cast"


## Applies the spell's effect entries that fire on `when` (hit, miss, fail, success, cast) to `t`. Each entry may
## set its own duration (`until`), what uses it up (`consume`), what ends it (`ends_on`), a repeated save, an
## escape check, and who it lands on (`target`: self for the caster). Entries that share those settings become one
## Effect; pushes and pulls queue up when a save spell is resolving several creatures.
func apply_effect_entries(ctx: Dictionary, t: Combatant, entries: Array, when: String, r: CombatResult) -> void:
	var spells := sp()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var e := enc()
	var groups := {}
	var order: Array[String] = []
	var choice := str(ctx.get("choice", ""))
	for raw: Variant in entries:
		var fx := raw as Dictionary
		var params := fx.get("params", {}) as Dictionary
		var on := str(params.get("on", default_on(s)))
		if on != when and not (on == "always" and when in ["hit", "miss", "fail", "success", "cast"]):
			continue
		var only_choice := str(params.get("only_choice", ""))
		if only_choice != "" and only_choice != choice:
			continue
		var who := t
		if str(params.get("target", "")) == "self":
			who = c
		# A mark the caster carries against the target (Hunter's Mark, Hex): the effect sits on the caster with
		# `vs: "target"` meaning this target.
		if str(params.get("target", "")) == "caster_vs":
			who = c
			ctx["vs_target"] = t.id
			if not ctx.has("mark_badge"):
				ctx["mark_badge"] = true
				mark_badge(c, t, str(s["id"]), str(s["name"]), ctx["conc"] as Concentration)
		var kind := str(fx.get("effect", ""))
		match kind:
			"push", "pull":
				var max_size := str(params.get("max_size", "huge"))
				if Creature.SIZES.find(who.creature.size) > Creature.SIZES.find(StringName(max_size)):
					continue
				var p := {"target": who, "feet": int(params.get("feet", 10)), "toward": kind == "pull"}
				if ctx.has("push_queue"):
					(ctx["push_queue"] as Array[Dictionary]).append(p)
				else:
					var pq: Array[Dictionary] = [p]
					spells.saves._run_pushes(ctx, pq)
				continue
			"temp_hp":
				var sub := ctx.duplicate()
				var s2 := s.duplicate()
				s2["temp_hp"] = params
				sub["s"] = s2
				spells.damage._temp_hp(sub, who, r)
				continue
			"heal":
				var amount := int(params.get("flat", 0))
				var roll_text := ""
				if params.has("dice"):
					var hr := e.heal_roll(str(params["dice"]), who, str(s["name"]))
					amount += int(hr["total"])
					roll_text = "%s %s" % [params["dice"], hr["text"]]
				var healed := who.creature.heal(amount, str(s["name"]))
				if healed > 0:
					var capped := " (rolled %d, now at full)" % amount if healed < amount and who.creature.hp >= who.creature.max_hp() else ""
					r.lines.append(e.log.add("heal", "%s regains %d Hit Points (%s)%s" % [who.name(), healed, s["name"], capped], who.id,
						[roll_text] if roll_text != "" else []))
					e.events.append({"type": "heal", "id": who.id, "amount": healed})
				continue
			"temporary_exhaustion":
				var ceiling := int(params.get("maximum", 4))
				if who.creature.exhaustion >= ceiling or who.creature.is_condition_immune(&"exhaustion"):
					continue
				var fatigue := Effect.new(str(s["name"]), &"spell", str(s["id"]))
				fatigue.caster_id = c.id
				fatigue.spell_level = int(ctx["slot"])
				fatigue.data["temporary_exhaustion"] = 1
				_set_duration(fatigue, ctx, who, "spell")
				who.creature.add_exhaustion()
				var fatigue_conc := ctx["conc"] as Concentration
				if fatigue_conc != null:
					fatigue_conc.attach(who.creature, fatigue)
				else:
					who.creature.add_effect(fatigue)
				e.log.add("condition", "%s gains 1 Exhaustion (%s)" % [who.name(), s["name"]], who.id)
				continue
			"end_concentration":
				if who.creature.concentration != null:
					who.creature.concentration.end(str(s["name"]))
				continue
			"end_condition":
				_end_condition(ctx, who, params, r)
				continue
			"light":
				_light(ctx, who, params)
				continue
			"damage":
				spells.damage._delayed_damage(ctx, who, params)
				continue
			"summon":
				continue
			"custom":
				_custom(ctx, who, params, r)
				continue
		var key := JSON.stringify([who.id, params.get("until", "spell"), params.get("consume", ""), params.get("ends_on", []),
			params.get("repeat_save", ""), params.get("escape", ""), params.get("plain", false), params.get("ends_on_damage", false)])
		if not groups.has(key):
			groups[key] = {"who": who, "params": params, "entries": []}
			order.append(key)
		((groups[key] as Dictionary)["entries"] as Array).append(fx)
	var gi := 0
	for key in order:
		var g := groups[key] as Dictionary
		_apply_group(ctx, g["who"] as Combatant, g["params"] as Dictionary, g["entries"] as Array, gi, r)
		gi += 1


func _apply_group(ctx: Dictionary, t: Combatant, params: Dictionary, entries: Array, index: int, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var conc := ctx["conc"] as Concentration
	var slot := int(ctx["slot"])
	var choice := str(ctx.get("choice", ""))
	var e := enc()
	# Plain conditions (Grease's Prone) stay until the usual way of ending them (standing up).
	if bool(params.get("plain", false)):
		for fx: Variant in entries:
			var p := (fx as Dictionary).get("params", {}) as Dictionary
			var cond := str(p.get("condition", ""))
			if cond == "choice":
				cond = choice
			if cond != "" and t.creature.add_condition(StringName(cond), str(s["name"])):
				r.lines.append(e.log.add("condition", "%s is %s (%s)" % [t.name(), cond.capitalize(), s["name"]], t.id))
				e.events.append({"type": "condition", "id": t.id})
				if cond == "prone" and bool(p.get("breaks_concentration", false)) and t.creature.concentration != null:
					t.creature.concentration.end("knocked Prone by %s" % s["name"])
		return
	var source_kind := StringName(str(s.get("effect_source", "spell")))
	var fxo := Effect.new(str(s["name"]), source_kind, str(s["id"]))
	fxo.caster_id = c.id
	fxo.spell_level = slot
	fxo.stack_key = "%s:%s:%d" % [source_kind, s["id"], index]
	_set_duration(fxo, ctx, t, str(params.get("until", "spell")))
	var ctx2 := c.creature.formula_context(slot)
	for raw: Variant in entries:
		var f := raw as Dictionary
		var p := f.get("params", {}) as Dictionary
		match str(f.get("effect", "")):
			"modifiers":
				for md: Variant in p.get("modifiers", []):
					var d := (md as Dictionary).duplicate(true)
					_substitute_choice(d, choice)
					_substitute_casting(d, ctx)
					if str(d.get("vs", "")) == "target":
						d["vs"] = str(ctx.get("vs_target", ""))
					# Extra dice per slot level above the spell's (Conjure Minor Elementals).
					if d.has("upcast_dice") and slot > int(s.get("level", 0)):
						var bd := DiceRoller.parse_expr(str(d.get("dice", "1d4")))
						var ud := DiceRoller.parse_expr(str(d["upcast_dice"]))
						d["dice"] = "%dd%d" % [int(bd["count"]) + int(ud["count"]) * (slot - int(s.get("level", 0))), int(bd["sides"])]
					var v: Variant = d.get("value", 0)
					if v is String and (str(v).contains("slot_level") or str(v).contains("mod:")):
						d["value"] = Formula.evaluate(v, ctx2)
					if str(d.get("value", "")) == "choice":
						continue
					fxo.modifiers.append(Modifier.make(d, str(s["name"]), source_kind, str(s["id"])))
			"condition":
				if str(s["id"]) == "sleep":
					continue
				var cond := str(p.get("condition", ""))
				if cond == "choice" or (p.has("condition_choice") and choice != ""):
					cond = choice if choice != "" else str((p.get("condition_choice", [cond]) as Array)[0])
				fxo.conditions.append(StringName(cond))
	var rs := str(params.get("repeat_save", ""))
	if rs != "":
		fxo.repeat_save = {"ability": str(params.get("repeat_ability", s.get("save", "wis"))), "dc": (ctx["nums"]["dc"] as Breakdown).total(),
			"when": "start" if rs == "start_of_turn" else ("manual" if rs in ["manual", "action"] else "end"), "by_action": rs == "action", "on_damage": bool(params.get("repeat_on_damage", false)),
			"damage_advantage": bool(params.get("damage_advantage", false))}
		if params.has("repeat_if"):
			fxo.repeat_save["if"] = str(params["repeat_if"])
		if params.has("repeat_fail_damage"):
			var rfd := (params["repeat_fail_damage"] as Dictionary).duplicate()
			if str(rfd.get("type", "")) == "choice":
				rfd["type"] = choice
			fxo.repeat_save["fail_damage"] = rfd
		if params.has("repeat_fail_exhaustion"):
			fxo.repeat_save["fail_exhaustion"] = int(params["repeat_fail_exhaustion"])
		if params.has("three_saves"):
			fxo.repeat_save["three"] = str(params["three_saves"])
	var esc := str(params.get("escape", ""))
	if esc.begins_with("check:"):
		fxo.escape = {"skill": esc.substr(6), "dc": (ctx["nums"]["dc"] as Breakdown).total()}
	for w: Variant in params.get("ends_on", []):
		var word := str(w)
		if word == "damage":
			fxo.ends_on_damage = true
		else:
			fxo.ends_on.append(word)
	if bool(params.get("ends_on_damage", false)):
		fxo.ends_on_damage = true
	match str(params.get("consume", "")):
		"next_save":
			fxo.consume_on = ["save:all"]
		"next_attack":
			fxo.consume_on = ["attack"]
		"next_check":
			fxo.consume_on = ["check:all"]
		"next_attacked":
			fxo.consume_when_attacked = true
	fxo.ends_when_incapacitated = bool(params.get("ends_when_incapacitated", false))
	for trigger: String in ["ends_when_armored", "ends_on_two_handed_attack"]:
		if bool(params.get(trigger, false)):
			fxo.data[trigger] = true
	if bool(params.get("starts_next_turn", false)):
		fxo.data["await_owner_start"] = true
	if bool(params.get("short_rest_on_expiry", false)):
		fxo.data["short_rest_on_expiry"] = true
	if params.has("casting_save"):
		fxo.data["casting_save"] = {"ability": str(params["casting_save"]), "dc": (ctx["nums"]["dc"] as Breakdown).total()}
	if params.has("tether"):
		fxo.data["tether"] = (params["tether"] as Dictionary).duplicate(true)
	if params.has("primary_condition"):
		fxo.data["primary_condition"] = str(params["primary_condition"])
	if bool(params.get("wakeable", false)):
		fxo.data["wakeable"] = true
	# Damage at the start of each of the target's turns (Searing Smite, Ensnaring Strike), with the slot's extra dice.
	if params.has("turn_damage"):
		var td := (params["turn_damage"] as Dictionary).duplicate()
		var tb := DiceRoller.parse_expr(str(td.get("dice", "1d6")))
		var tn := int(tb["count"])
		var tup := str((s.get("upcast", {}) as Dictionary).get("damage", ""))
		if bool(td.get("upcast", true)) and tup != "" and slot > int(s.get("level", 0)):
			tn += int(DiceRoller.parse_expr(tup)["count"]) * (slot - int(s.get("level", 0)))
		td["dice"] = "%dd%d" % [tn, int(tb["sides"])]
		fxo.data["turn_damage"] = td
	if params.has("turn_heal"):
		fxo.data["turn_heal"] = int(params["turn_heal"])
	# Temporary Hit Points at the start of each of its turns (Heroism: the spellcasting modifier).
	if params.has("turn_temp_hp"):
		var th: Variant = params["turn_temp_hp"]
		fxo.data["turn_temp_hp"] = int((ctx["nums"] as Dictionary).get("mod", 0)) if str(th) == "mod" else int(th)
	# Ends once its Temporary Hit Points are gone (Armor of Agathys).
	if bool(params.get("ends_without_temp_hp", false)):
		fxo.data["ends_without_temp_hp"] = true
	# Protection from Evil and Good: no Charmed or Frightened from the warded-against creature types.
	var caster_type := str(c.creature.creature_type)
	for m in t.creature.modifiers_for(&"condition_immunity_by_type"):
		if caster_type in (m.data.get("types", []) as Array):
			for blocked: Variant in m.data.get("conditions", []):
				fxo.conditions.erase(StringName(str(blocked)))
	# Ring of Free Action: magic can't paralyze or restrain the wearer, or reduce its speed.
	enc().items.filter_magic_effect(t, fxo)
	if fxo.modifiers.is_empty() and fxo.conditions.is_empty():
		return
	for m in fxo.modifiers:
		if m.stat == &"size_step":
			_resize(t, m.number("value"), fxo)
		if m.stat == &"flag" and m.text("value") == "hasted":
			_haste_lethargy(t, fxo)
		if m.stat == &"flag" and m.text("value") == "crowned":
			t.set_meta("crowned_by", c.id)
			# The creature its caster picked for it to attack, or no one (SpellTargeting.crown_attack).
			sp().targeting.set_crown_victim(t, str((ctx.get("opts", {}) as Dictionary).get("crown_victim", "")))
	if str(s["id"]) == "aid":
		var gain := 5 * (slot - 1) if slot >= 2 else 5
		t.creature.add_effect(fxo)
		t.creature.heal(gain, "Aid")
		r.lines.append(e.log.add("info", "%s's Hit Point maximum rises by %d (Aid)" % [t.name(), gain], t.id))
		return
	var ok := conc.attach(t.creature, fxo) if conc != null else t.creature.add_effect(fxo)
	if ok:
		if fxo.conditions.is_empty():
			r.lines.append(e.log.add("condition", "%s gains %s" % [t.name(), s["name"]], t.id))
		else:
			var what := ", ".join(fxo.conditions.map(func(x: StringName) -> String: return str(x).capitalize()))
			r.lines.append(e.log.add("condition", "%s is %s (%s)" % [t.name(), what, s["name"]], t.id))
		e.events.append({"type": "condition", "id": t.id})
		if StringName("invisible") in fxo.conditions or StringName("incapacitated") in fxo.conditions:
			e.features.end_turning_from(t)


## Casting-time values in a modifier: "spell" as an ability is the caster's spellcasting ability, "tier:a,b,c,d" is
## a die by cantrip tier (Shillelagh), and ":caster" in a flag names the caster (Mind Spike, Bestow Curse).
func _substitute_casting(d: Dictionary, ctx: Dictionary) -> void:
	var c := ctx["c"] as Combatant
	if str(d.get("ability", "")) == "spell":
		d["ability"] = str((ctx["nums"] as Dictionary).get("ability", "int"))
	var die := str(d.get("die", ""))
	if die.begins_with("tier:"):
		var opts := die.substr(5).split(",")
		d["die"] = opts[clampi(Spellcasting.cantrip_tier(c.creature.character_level()), 0, opts.size() - 1)]
	for key: String in ["value", "on"]:
		if d.has(key) and d[key] is String and str(d[key]).ends_with(":caster"):
			d[key] = str(d[key]).trim_suffix(":caster") + ":" + c.id
	if str(d.get("damage_type", "")) == "weapon":
		d.erase("damage_type")


## Enlarge/Reduce: one size category up or down while the effect lasts (no growth into a space that's taken).
func _resize(t: Combatant, step: int, fxo: Effect) -> void:
	var e := enc()
	var i := Creature.SIZES.find(t.creature.size)
	var to := clampi(i + step, 0, Creature.SIZES.size() - 1)
	if to == i:
		return
	var new_size := Creature.SIZES[to]
	var cells := CombatGrid.size_cells_for(new_size)
	if cells > t.size_cells:
		for cell in CombatGrid.footprint(t.cell, cells):
			var o := e.occupant_at(cell)
			if e.grid.is_solid(cell) or (o != null and o != t):
				e.log.add("info", "%s has no room to grow" % t.name(), t.id)
				return
	var old := t.creature.size
	t.creature.size = new_size
	t.size_cells = cells
	e.events.append({"type": "resize", "id": t.id})
	fxo.data["on_end"] = {"kind": "resize", "target": t.id, "size": str(old)}
	var weak: WeakRef = weakref(t)
	fxo.on_end = func() -> void:
		var tt := weak.get_ref() as Combatant
		if tt != null:
			tt.creature.size = old
			tt.size_cells = CombatGrid.size_cells_for(old)
			var ee := enc()
			if ee != null:
				ee.events.append({"type": "resize", "id": tt.id})


## Haste ending: the target is Incapacitated with Speed 0 until the end of its next turn.
func _haste_lethargy(t: Combatant, fxo: Effect) -> void:
	fxo.data["on_end"] = {"kind": "lethargy", "target": t.id}
	var weak: WeakRef = weakref(t)
	fxo.on_end = func() -> void:
		var tt := weak.get_ref() as Combatant
		var ee := enc()
		if tt == null or ee == null or tt.creature.dead:
			return
		var lag := Effect.new("Lethargy (Haste ended)", &"spell", "haste_lethargy").with_condition(&"incapacitated").with_modifier("speed_set", {"value": 0})
		lag.ends = Effect.Ends.END_OF_TURN
		lag.turn_owner_id = tt.id
		lag.skip_turn_ends = ee.own_turn_skip(tt)
		tt.creature.add_effect(lag)
		ee.log.add("condition", "%s is overcome by lethargy as Haste ends" % tt.name(), tt.id)
		ee.events.append({"type": "condition", "id": tt.id})


## "choice" placeholders in a modifier become the cast-time pick (Protection from Energy's damage type, Guidance's
## skill as `check:choice`, Enhance Ability's ability).
static func _substitute_choice(d: Dictionary, choice: String) -> void:
	if choice == "":
		return
	for k: String in d.keys():
		var v: Variant = d[k]
		if v is String:
			d[k] = str(v).replace("choice", choice)
		elif v is Array:
			var arr: Array = []
			for x: Variant in v:
				arr.append(str(x).replace("choice", choice) if x is String else x)
			d[k] = arr


## How long an effect lasts: the spell's duration (and Concentration), or its own: caster_turn_start / caster_turn_end
## ("until the start / end of your next turn"), target_turn_start / target_turn_end, this_turn_end (Stinking Cloud's
## "until the end of that turn"), rounds:N.
func _set_duration(fxo: Effect, ctx: Dictionary, t: Combatant, until: String) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var e := enc()
	match until:
		"caster_turn_start":
			fxo.ends = Effect.Ends.START_OF_TURN
			fxo.turn_owner_id = c.id
		"caster_turn_end":
			fxo.ends = Effect.Ends.END_OF_TURN
			fxo.turn_owner_id = c.id
			fxo.skip_turn_ends = e.own_turn_skip(c)
		"target_turn_start":
			fxo.ends = Effect.Ends.START_OF_TURN
			fxo.turn_owner_id = t.id
		"target_turn_end":
			fxo.ends = Effect.Ends.END_OF_TURN
			fxo.turn_owner_id = t.id
			fxo.skip_turn_ends = e.own_turn_skip(t)
		"this_turn_end":
			fxo.ends = Effect.Ends.END_OF_TURN
			fxo.turn_owner_id = t.id
		"permanent":
			fxo.ends = Effect.Ends.NEVER
		_:
			if until.begins_with("minutes:"):
				fxo.lasting({"kind": "minutes", "amount": int(until.substr(8))})
				fxo.turn_owner_id = c.id
			elif until.begins_with("rounds:"):
				fxo.lasting_rounds(int(until.substr(7)), c.id)
			else:
				fxo.lasting(s.get("duration", {}) as Dictionary)
				fxo.turn_owner_id = c.id


## A visible tag on a creature the caster has marked (Hex, Hunter's Mark): "Hexed by Silvain". It carries no rules
## (the caster's own effect does the work), ends with the spell, and moves when the mark moves.
func mark_badge(c: Combatant, t: Combatant, spell_id: String, spell_name: String, conc: Concentration) -> void:
	for o in enc().combatants:
		for fx: Effect in o.creature.effects.duplicate():
			if fx.source_id == spell_id + ":mark" and fx.caster_id == c.id:
				o.creature.remove_effect(fx)
	var label := ("Hexed by %s" if spell_id == "hex" else ("Marked by %s (%s)" % ["%s", spell_name])) % c.name()
	var badge := Effect.new(label, &"spell", spell_id + ":mark")
	badge.caster_id = c.id
	badge.ends = Effect.Ends.NEVER
	badge.data["mark_by"] = c.id
	badge.data["mark_of"] = spell_id
	if conc != null and not conc.ended:
		conc.attach(t.creature, badge)
	else:
		t.creature.add_effect(badge)
	enc().events.append({"type": "condition", "id": t.id})


## Lesser Restoration, Protection from Poison: ends one of the listed conditions on the target (the cast-time
## choice, or the first it has).
func _end_condition(ctx: Dictionary, t: Combatant, params: Dictionary, r: CombatResult) -> void:
	var e := enc()
	var listed := (params.get("conditions", []) as Array).map(func(x: Variant) -> String: return str(x))
	var pick := str(ctx.get("choice", ""))
	var order: Array[String] = []
	if pick in listed:
		order.append(pick)
	for x: String in listed:
		if not x in order:
			order.append(x)
	for cond in order:
		if t.creature.has_condition(StringName(cond)):
			cure(t, StringName(cond))
			r.lines.append(e.log.add("heal", "%s is no longer %s (%s)" % [t.name(), cond.capitalize(), (ctx["s"] as Dictionary)["name"]], t.id))
			e.events.append({"type": "condition", "id": t.id})
			return
	r.lines.append(e.log.add("info", "%s has nothing for %s to end" % [t.name(), (ctx["s"] as Dictionary)["name"]], t.id))


## Ends a condition however it was given: as a plain condition or by effects.
func cure(t: Combatant, cond: StringName) -> void:
	t.creature.remove_condition(cond)
	for fx: Effect in t.creature.effects.duplicate():
		if cond in fx.conditions:
			if str(fx.data.get("primary_condition", "")) == str(cond) or (fx.modifiers.is_empty() and fx.conditions.size() == 1):
				t.creature.remove_effect(fx)
			else:
				fx.conditions.erase(cond)
	t.creature._after_conditions_changed()


## Light from a spell on a creature or the caster (Light, Produce Flame, Starry Wisp, Continual Flame, Daylight):
## a FieldObject that carries the light with it for the duration.
func _light(ctx: Dictionary, t: Combatant, params: Dictionary) -> void:
	var spells := sp()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var o := FieldObject.new(FieldObject.Kind.ZONE, str(s["id"]), str(s["name"]))
	o.caster_id = c.id
	o.cell = t.cell
	o.rules = {"light": params.duplicate(), "light_on": "target", "light_target": t.id}
	var d := s.get("duration", {}) as Dictionary
	match str(params.get("until", "")):
		"caster_turn_end", "target_turn_end":
			o.rounds_left = 2
		_:
			match str(d.get("kind", "")):
				"rounds":
					o.rounds_left = int(d.get("amount", 1))
				"minutes":
					o.rounds_left = int(d.get("amount", 1)) * 10
				"instantaneous":
					o.rounds_left = 2
				_:
					o.rounds_left = 100000
	o.keep_with(ctx["conc"] as Concentration)
	spells.zones.add(o, CombatResult.new())


## Effects that need code of their own.
func _custom(ctx: Dictionary, t: Combatant, params: Dictionary, r: CombatResult) -> void:
	var spells := sp()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var e := enc()
	match str(params.get("id", "")):
		"mirror_image":
			var fx := Effect.new("Mirror Image", &"spell", "mirror_image").lasting(s.get("duration", {}) as Dictionary)
			fx.turn_owner_id = c.id
			fx.caster_id = c.id
			fx.data = {"duplicates": int(params.get("duplicates", 3))}
			fx.modifiers.append(Modifier.of("flag", {"value": "mirror_image"}, "Mirror Image", &"spell"))
			t.creature.add_effect(fx)
			r.lines.append(e.log.add("condition", "Three illusory duplicates surround %s" % t.name(), t.id))
		"dominate":
			spells.specials.dominate(ctx, t)
		"flee_reaction":
			spells.specials.flee_with_reaction(ctx, t, r)
		"revert_shape":
			# Moonbeam: a shape-shifted creature reverts to its true form.
			if e.shapes.is_shaped(t):
				e.shapes.revert(t, s["name"])
			elif t.has_meta("form") and str(t.get_meta("form")) != "humanoid":
				t.set_meta("form", "humanoid")
				r.lines.append(e.log.add("info", "%s is forced back into its true form (%s)" % [t.name(), s["name"]], t.id))
		"goodberry":
			if spells.caster_char(c) != null:
				spells.caster_char(c).add_item("goodberry", int(params.get("count", 10)))
				r.lines.append(e.log.add("info", "%s holds %d Goodberries" % [c.name(), int(params.get("count", 10))], c.id))
		"warding_bond":
			var fx2 := Effect.new("Warding Bond (link)", &"spell", "warding_bond").lasting(s.get("duration", {}) as Dictionary)
			fx2.turn_owner_id = c.id
			fx2.caster_id = c.id
			fx2.stack_key = "spell:warding_bond:link"
			fx2.data = {"caster": c.id, "max_distance": int(params.get("max_distance", 60))}
			fx2.modifiers.append(Modifier.of("flag", {"value": "warding_bond"}, "Warding Bond", &"spell"))
			t.creature.add_effect(fx2)
