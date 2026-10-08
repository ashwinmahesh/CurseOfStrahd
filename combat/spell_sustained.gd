class_name SpellSustained
extends RefCounted
## Actions a spell keeps granting while it lasts (SpellCaster.sustained): Witch Bolt, Spiritual Weapon, Dragon's
## Breath and the like; granting them, what a creature can use now, using one, and ending them with their spell.

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func sp() -> SpellCaster:
	return enc().spells


func _comp() -> Compendium:
	return Compendium.shared()


func _entry_any(c: Combatant, spell_id: String) -> Dictionary:
	var spells := sp()
	if spells.caster_char(c) == null:
		return {}
	for k in spells.caster_char(c).known_spells():
		if str(k["id"]) == spell_id:
			return k
	return {}


## Registers the spell's `sustain` actions: what the caster (or, for Dragon's Breath, the target) can keep doing
## while the spell lasts.
func _grant_sustained(ctx: Dictionary, tgt: Array[Combatant]) -> void:
	var spells := sp()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var conc := ctx["conc"] as Concentration
	for raw: Variant in s.get("sustain", []):
		var d := (raw as Dictionary).duplicate(true)
		var owner := c
		if str(d.get("owner", "caster")) == "target" and not tgt.is_empty():
			owner = tgt[0]
		var a := {"id": "%s:%s:%d" % [s["id"], d.get("do", "act"), spells.sustained.size() + randi() % 1000], "spell_id": str(s["id"]),
			"label": str(d.get("label", s["name"])), "owner_id": owner.id, "caster_id": c.id, "cost": str(d.get("cost", "bonus_action")),
			"do": str(d.get("do", "attack")), "slot": int(ctx["slot"]), "target_id": tgt[0].id if not tgt.is_empty() else "",
			"conc": weakref(conc) if conc != null else null, "def": d, "choice": str(ctx.get("choice", "")),
			"rounds_left": -1 if conc != null else SpellPlacement._duration_rounds(s.get("duration", {}) as Dictionary),
			"used_round": -1 if not bool(d.get("not_this_turn", true)) else enc().round_no, "used_turn": enc().turn_index,
			"maintained_round": enc().round_no, "numbers": SpellCaster._pack_numbers(ctx["nums"] as Dictionary)}
		spells.sustained.append(a)


func _prune_sustained() -> void:
	var spells := sp()
	var keep: Array[Dictionary] = []
	for a in spells.sustained:
		var conc := (a["conc"] as WeakRef).get_ref() as Concentration if a["conc"] != null else null
		if a["conc"] != null and (conc == null or conc.ended):
			continue
		if int(a["rounds_left"]) == 0:
			continue
		if enc().get_c(str(a["owner_id"])) == null or not enc().get_c(str(a["owner_id"])).is_alive():
			continue
		var owner := enc().get_c(str(a["owner_id"]))
		if bool((a["def"] as Dictionary).get("requires_effect", false)) and not owner.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == str(a["spell_id"]) and fx.caster_id == str(a["caster_id"])):
			continue
		keep.append(a)
	spells.sustained = keep


func sustained_for(c: Combatant, spell_id: String = "") -> Dictionary:
	for a in sustained_actions(c):
		if spell_id == "" or str(a["spell_id"]) == spell_id:
			return a
	return {}


## The sustained actions `c` has now, each with {legal, reason}.
func sustained_actions(c: Combatant) -> Array[Dictionary]:
	var spells := sp()
	_prune_sustained()
	var out: Array[Dictionary] = []
	for a in spells.sustained:
		if str(a["owner_id"]) != c.id:
			continue
		var entry := a.duplicate()
		var why := enc()._turn_check(c)
		if why == "" and not c.can_act():
			why = "%s can't act" % c.name()
		if why == "":
			why = spells.economy_block(c, "action" if str(a["cost"]) in ["action", "magic"] else str(a["cost"]))
		if why == "" and str(a["do"]) == "dash" and c.creature.has_flag("cannot_dash"):
			why = "Cannot Dash while affected"
		if why == "" and str(a["do"]) == "disengage" and not enc().can_disengage(c):
			why = "Hunter’s Rime prevents Disengage"
		if why == "" and int(a["used_round"]) == enc().round_no and int(a["used_turn"]) == enc().turn_index:
			why = "Not on the turn you cast it"
		if why == "" and bool((a["def"] as Dictionary).get("once_per_turn", false)) and str(a.get("last_turn", "")) == "%d:%d" % [enc().round_no, enc().turn_index]:
			why = "Already used this turn"
		entry["legal"] = why == ""
		entry["reason"] = why
		out.append(entry)
	return out


## Uses a sustained action: Witch Bolt's arc, Spiritual Weapon's strike, Flaming Sphere's roll, Cloud of Daggers'
## move, Produce Flame's hurl, Vampiric Touch's touch, Dragon's Breath's exhale, Expeditious Retreat's Dash,
## Aura of Vitality's healing, Gust of Wind's new direction, Crown of Madness's upkeep.
func use_sustained(c: Combatant, action_id: String, targets: Array = [], point: Vector2 = Vector2.INF,
		direction: Vector2 = Vector2.ZERO) -> CombatResult:
	var spells := sp()
	var a := {}
	for x in sustained_actions(c):
		if str(x["id"]) == action_id:
			a = x
	if a.is_empty():
		return CombatResult.fail("That spell has ended")
	if not bool(a["legal"]):
		return CombatResult.fail(str(a["reason"]))
	var e := enc()
	var caster := e.get_c(str(a["caster_id"]))
	var s := _comp().spell_data(str(a["spell_id"]))
	var d := a["def"] as Dictionary
	var entry := _entry_any(caster, str(a["spell_id"])) if caster != null else {}
	var conc := (a["conc"] as WeakRef).get_ref() as Concentration if a["conc"] != null else null
	var ctx := {"c": c, "s": s, "slot": int(a["slot"]), "nums": SpellCaster._unpack_numbers(a["numbers"] as Dictionary) if a.has("numbers") else (spells.numbers(caster, entry) if caster != null else {}), "conc": conc,
		"opts": {}, "choice": str(a["choice"]), "point": point}
	var t: Combatant = targets[0] as Combatant if not targets.is_empty() else null
	var r := CombatResult.new()
	var cost := str(a["cost"])
	# Validate every attack target before paying or moving the spell object.
	if str(a["do"]) == "attack":
		if targets.size() > int(d.get("attacks", 1)):
			return CombatResult.fail("Too many targets")
		for picked: Variant in targets:
			var target_why := _sustained_check(c, a, d, picked as Combatant, point)
			if target_why != "":
				return CombatResult.fail(target_why)
	# Attack targets were checked above; other actions still need their own check.
	var why := "" if str(a["do"]) == "attack" and not targets.is_empty() else _sustained_check(c, a, d, t, point)
	if why != "":
		return CombatResult.fail(why)
	if cost == "bonus_action":
		c.bonus_available = false
	elif cost in ["action", "magic"]:
		e.spend_action(c)
		if cost == "magic":
			c.magic_action_used = true
	for x in spells.sustained:
		if str(x["id"]) == action_id:
			x["maintained_round"] = e.round_no
			x["last_turn"] = "%d:%d" % [e.round_no, e.turn_index]
	match str(a["do"]):
		"attack":
			var obj := spells.zones.object_of(str(a["caster_id"]), str(a["spell_id"]))
			if obj != null and point != Vector2.INF:
				var cell := Vector2i(floori(point.x), floori(point.y))
				obj.cell = cell
				obj.cells = [cell]
				spells.zones.moved_object(obj, r)
				e.events.append({"type": "summon", "caster": str(a["caster_id"]), "cell": cell})
			if t != null:
				e.log.add("spell", "%s: %s" % [c.name(), a["label"]], c.id)
				if obj != null:
					ctx["pull_origin"] = Vector2(obj.cell) + Vector2(0.5, 0.5)
					ctx["attack_origin"] = obj.cell
				var sub_s := s.duplicate()
				if d.has("attack"):
					sub_s["attack"] = d["attack"]
				if d.has("damage"):
					sub_s["damage"] = d["damage"]
				if d.has("effects"):
					sub_s["effects"] = d["effects"]
				sub_s.erase("secondary")
				var sub := ctx.duplicate()
				sub["s"] = sub_s
				for i in int(d.get("attacks", 1)):
					var victim := targets[i % targets.size()] as Combatant
					if victim.is_alive():
						spells.spell_attack(sub, victim, r)
		"damage":
			var tt := e.get_c(str(a["target_id"]))
			if tt == null or not tt.is_alive():
				return CombatResult.fail("The target is gone")
			if str(a["spell_id"]) == "heat_metal":
				e.log.add("spell", "%s: %s" % [c.name(), a["label"]], c.id)
				spells.specials.heat_metal(ctx, tt, r)
				spells.zones.prune()
				e._check_over()
				return e.then(r, func() -> CombatResult: return e.run_reaction_queue(r))
			var rolled := spells.roll_damage_parts(ctx, d.get("damage", []) as Array, false, tt)
			e.log.add("spell", "%s: %s" % [c.name(), a["label"]], c.id)
			var dr := spells.deal_spell_damage(ctx, tt, [{"amount": int(rolled["total"]), "type": str(rolled["type"]), "spell": true}], false, str(s["name"]), [str(rolled["text"])])
			r.damage = dr.final
		"area":
			var sub_s2 := s.duplicate()
			for k: String in ["area", "save", "save_success", "damage"]:
				if d.has(k):
					sub_s2[k] = d[k]
			if not bool(d.get("at_point", false)):
				sub_s2["range"] = {"kind": "self"}
			sub_s2.erase("sustain")
			sub_s2.erase("effects")
			if d.has("effects"):
				sub_s2["effects"] = d["effects"]
			sub_s2.erase("zone")
			var sub2 := ctx.duplicate()
			sub2["s"] = sub_s2
			var cells := spells.area_for(c, sub_s2, point, direction, int(a["slot"]))
			e.events.append({"type": "spell", "caster": c.id, "spell": str(s["id"]), "cells": cells, "targets": []})
			e.log.add("spell", "%s: %s" % [c.name(), a["label"]], c.id)
			spells._save_spell(sub2, spells._area_victims(c, sub_s2, cells), r)
		"move_object":
			var obj2 := spells.zones.object_of(str(a["caster_id"]), str(a["spell_id"]))
			if obj2 == null:
				return CombatResult.fail("Nothing to move")
			var to := Vector2i(floori(point.x), floori(point.y))
			if obj2.kind == FieldObject.Kind.ZONE:
				var dv := Vector2(to - obj2.cell)
				var moved: Array[Vector2i] = []
				for cl in obj2.cells:
					moved.append(cl + Vector2i(dv))
				obj2.cells = moved
				obj2.cell = to
				if obj2.rules.has("core_cells"):
					obj2.rules["core_cells"] = (obj2.rules["core_cells"] as Array).map(func(x: Variant) -> Array:
						return [int((x as Array)[0]) + int(dv.x), int((x as Array)[1]) + int(dv.y)])
			else:
				obj2.cell = to
				obj2.cells = [to]
			e.log.add("spell", "%s: %s" % [c.name(), a["label"]], c.id)
			spells.zones.moved_object(obj2, r)
			if obj2.kind == FieldObject.Kind.SPHERE:
				var hitc := e.occupant_at(to)
				if hitc == null:
					for n in e.living():
						if e.grid.distance_ft(to, 1, n.cell, n.size_cells) <= 0:
							hitc = n
				if hitc != null:
					var o2ctx := spells.context_for_object(obj2)
					var victims: Array[Combatant] = [hitc]
					var sub3 := o2ctx.duplicate()
					var s3 := (o2ctx["s"] as Dictionary).duplicate()
					s3["save"] = obj2.rules.get("save", "dex")
					s3["save_success"] = "half"
					s3["damage"] = obj2.rules.get("damage", s.get("damage", []))
					s3.erase("effects")
					sub3["s"] = s3
					spells._save_spell(sub3, victims, r)
		"dash":
			c.movement_left += c.speed()
			e.log.add("info", "%s Dashes (+%d ft, %s)" % [c.name(), c.speed(), s["name"]], c.id)
		"volley":
			return spells.specials.mid.volley(c, t if t != null else spells.specials.mid._nearest_foe(c), r)
		"eyebite":
			if t == null:
				return CombatResult.fail("Choose a creature within 60 ft")
			var ectx := ctx.duplicate()
			ectx["choice"] = str(a["choice"])
			spells.specials.mid.eye(ectx, t, r)
		"repeat":
			if t == null:
				return CombatResult.fail("Choose a creature")
			var rctx := ctx.duplicate()
			rctx["choice"] = str(a["choice"])
			e.log.add("spell", "%s: %s" % [c.name(), a["label"]], c.id)
			var one: Array[Combatant] = [t]
			spells._save_spell(rctx, one, r)
		"bigby":
			var hand := spells.zones.object_of(str(a["caster_id"]), str(a["spell_id"]))
			if hand != null and point != Vector2.INF:
				hand.cell = Vector2i(floori(point.x), floori(point.y))
				hand.cells = [hand.cell]
				spells.zones.moved_object(hand, r)
			spells.specials.mid.bigby(ctx, str(d.get("mode", "push")), t, r)
		"end_spell":
			e.log.add("spell", "%s lets %s go" % [c.name(), s["name"]], c.id)
			_end_spell_of(c, str(a["spell_id"]), "let go")
		"disengage":
			c.disengaged = true
			e.log.add("info", "%s Disengages (%s)" % [c.name(), s["name"]], c.id)
		"compel":
			var dirv := direction if direction.length() > 0.01 else ((point - e.center_of(c)) if point != Vector2.INF else Vector2.ZERO)
			if dirv.length() < 0.01:
				return CombatResult.fail("Choose a direction")
			c.set_meta("compel_dir", [dirv.normalized().x, dirv.normalized().y])
			e.log.add("spell", "%s names a direction: the charmed must go that way (%s)" % [c.name(), s["name"]], c.id)
		"heal_one":
			if t == null:
				t = c
			var rolled2 := e.heal_roll(str((d.get("heal", {}) as Dictionary).get("dice", "2d6")), t, str(s["name"]))
			var amt := int(rolled2["total"])
			# Alustriel's Mooncloak: the dice plus the spellcasting modifier.
			if bool((d.get("heal", {}) as Dictionary).get("add_mod", false)):
				amt += int((ctx["nums"] as Dictionary).get("mod", 0))
			if t.creature.has_flag("max_healing_received"):
				var pp := DiceRoller.parse_expr(str((d.get("heal", {}) as Dictionary).get("dice", "2d6")))
				amt = int(pp["count"]) * int(pp["sides"])
			var healed := t.creature.heal(amt, str(s["name"]))
			e.log.add("heal", "%s: %s regains %d Hit Points" % [s["name"], t.name(), healed], c.id, [str(rolled2["text"])])
			e.events.append({"type": "heal", "id": t.id, "amount": healed})
		"aim":
			var zone := spells.zones.object_of(str(a["caster_id"]), str(a["spell_id"]))
			if zone != null and direction.length() > 0.01:
				zone.cells = spells.area_for(c, s, Vector2.INF, direction, int(a["slot"]))
				spells.zones.moved_object(zone, r)
			e.log.add("spell", "%s turns %s" % [c.name(), s["name"]], c.id)
		"move_mark":
			if t == null:
				return CombatResult.fail("Choose a new target")
			for fx: Effect in c.creature.effects:
				if fx.source_id == str(a["spell_id"]):
					for m in fx.modifiers:
						if m.data.has("vs"):
							m.data["vs"] = t.id
			var sd0 := _comp().spell_data(str(a["spell_id"]))
			spells.mark_badge(c, t, str(a["spell_id"]), str(sd0.get("name", a["spell_id"])), c.creature.concentration)
			for x in spells.sustained:
				if str(x["id"]) == str(a["id"]):
					x["target_id"] = t.id
			e.log.add("spell", "%s moves %s to %s" % [c.name(), s["name"], t.name()], c.id)
		"maintain":
			e.log.add("spell", "%s keeps %s going" % [c.name(), s["name"]], c.id)
			# Crown of Madness: the creature the crowned one must attack next, the one picked or no one.
			var crowned := e.get_c(str(a["target_id"]))
			if crowned != null:
				spells.targeting.set_crown_victim(crowned, t.id if t != null else "")
		"faerun":
			var fr := e.faerun.sustained(c, a, d, ctx, targets, point, direction, r)
			if not fr.ok:
				return fr
	# A last act that spends the spell (Alustriel's Mooncloak's healing).
	if bool(d.get("ends_spell", false)) and caster != null:
		_end_spell_of(caster, str(a["spell_id"]), "its power is spent")
	spells.zones.prune()
	e._check_over()
	return e.then(r, func() -> CombatResult: return e.run_reaction_queue(r))


func _sustained_check(c: Combatant, a: Dictionary, d: Dictionary, t: Combatant, point: Vector2) -> String:
	var spells := sp()
	var e := enc()
	var reach := int(d.get("reach", 5))
	if str(a["do"]) == "faerun":
		return e.faerun.sustained_why(c, a, d, t, point)
	match str(a["do"]):
		"attack":
			if t == null:
				return "Choose a target"
			var obj := spells.zones.object_of(str(a["caster_id"]), str(a["spell_id"]))
			if obj != null:
				var to := obj.cell if point == Vector2.INF else Vector2i(floori(point.x), floori(point.y))
				if not e.grid.in_bounds(to):
					return "Outside the battlefield"
				if e.grid.is_solid(to) and not bool(obj.rule("passes_barriers", false)):
					return "Cannot end inside a solid object"
				if e.grid.distance_ft(obj.cell, 1, to, 1) > int(d.get("move", 0)):
					return "It moves at most %d ft" % int(d.get("move", 0))
				if e.grid.distance_ft(to, 1, t.cell, t.size_cells) > reach:
					return "Target must be within %d ft of it" % reach
			else:
				var rng := int(d.get("range", 5))
				if e.distance(c, t) > rng:
					return "Out of range (%d ft)" % rng
			if int(e.cover(c, t)["cover"]) == CombatGrid.Cover.TOTAL and obj == null:
				return "No line of effect"
			var sb := spells.sanctuary_blocks(c, t)
			if sb != "":
				return sb
		"damage":
			var tt := e.get_c(str(a["target_id"]))
			if tt == null or not tt.is_alive():
				return "The target is gone"
			if e.distance(c, tt) > int(d.get("range", 60)):
				return "The target is out of range"
			if int(e.cover(c, tt)["cover"]) == CombatGrid.Cover.TOTAL:
				return "The target has Total Cover"
		"move_object":
			var obj2 := spells.zones.object_of(str(a["caster_id"]), str(a["spell_id"]))
			if obj2 == null:
				return "Nothing to move"
			if point == Vector2.INF:
				return "Choose a square"
			var to2 := Vector2i(floori(point.x), floori(point.y))
			if not e.grid.in_bounds(to2) or e.grid.is_solid(to2):
				return "Can't go there"
			if e.grid.distance_ft(obj2.cell, 1, to2, 1) > int(d.get("move", 30)):
				return "It moves at most %d ft" % int(d.get("move", 30))
		"heal_one":
			if t != null and e.distance(c, t) > int(d.get("range", 30)):
				return "Out of the aura"
		"area":
			if bool(d.get("at_point", false)):
				if point == Vector2.INF:
					return "Choose a point"
				var storm := spells.zones.object_of(str(a["caster_id"]), str(a["spell_id"]))
				var within := int(d.get("within_object", 0))
				if storm != null and within > 0 and (point - storm.origin).length() * CombatGrid.FEET > within + 0.01:
					return "The point must be under the storm (%d ft)" % within
		"move_mark":
			var old := e.get_c(str(a["target_id"]))
			if old != null and old.is_alive() and old.creature.hp > 0:
				return "The marked creature is still up"
			if t == null or e.distance(c, t) > int(d.get("range", 90)):
				return "Choose a creature within %d ft" % int(d.get("range", 90))
		"maintain":
			return spells.targeting.crown_victim_why(c, e.get_c(str(a["target_id"])), t)
	return ""


## Sustained spells that end on their own (Witch Bolt when its target is out of range or behind Total Cover) and
## upkeep that lapses (Crown of Madness without its Magic action), checked at the end of the caster's turn.
func _sustained_turn_end(c: Combatant) -> void:
	var spells := sp()
	var e := enc()
	for a: Dictionary in spells.sustained.duplicate():
		if str(a["caster_id"]) != c.id:
			continue
		var d := a["def"] as Dictionary
		if str(a["do"]) == "damage":
			var tt := e.get_c(str(a["target_id"]))
			if tt == null or not tt.is_alive() or e.distance(c, tt) > int(d.get("range", 60)) or int(e.cover(c, tt)["cover"]) == CombatGrid.Cover.TOTAL:
				_end_spell_of(c, str(a["spell_id"]), "the target got away")
		if bool(d.get("upkeep", false)) and int(a["maintained_round"]) != e.round_no:
			_end_spell_of(c, str(a["spell_id"]), "no Magic action to keep it")
		if int(a["rounds_left"]) > 0:
			a["rounds_left"] = int(a["rounds_left"]) - 1
	_prune_sustained()


func _end_spell_of(c: Combatant, spell_id: String, why: String) -> void:
	var spells := sp()
	if c.creature.concentration != null and c.creature.concentration.source_id == spell_id:
		c.creature.concentration.end(why)
		enc().log.add("info", "%s ends (%s)" % [_comp().spell_data(spell_id).get("name", spell_id), why], c.id)
	spells.zones.prune()
	_prune_sustained()
