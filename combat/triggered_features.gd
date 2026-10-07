class_name TriggeredFeatures
extends RefCounted
## Data-defined feature triggers compose ordinary effects, casting, movement and attack rules.

var _enc: WeakRef

func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)

func enc() -> Encounter:
	return _enc.get_ref() as Encounter

func recipes(c: Combatant, key: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c.creature is Character:
		for feature in (c.creature as Character).features:
			if feature.has(key):
				out.append(feature)
	return out

func casting_forms(c: Combatant, spell: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# This recipe links the form's lifetime to the concentration created by this casting.
	if not bool((spell.get("duration", {}) as Dictionary).get("concentration", false)):
		return out
	for feature in recipes(c, "cast_form"):
		var rule := feature["cast_form"] as Dictionary
		if str(rule["spell"]) == str(spell["id"]) and c.creature.resource_left(str(rule["resource"])) > 0:
			out.append(feature)
	return out

func after_cast(ctx: Dictionary) -> void:
	var c := ctx["c"] as Combatant
	var spell := ctx["s"] as Dictionary
	for feature in recipes(c, "after_cast_attack"):
		var rule := feature["after_cast_attack"] as Dictionary
		if str((spell.get("casting_time", {}) as Dictionary).get("unit", "")) == str(rule["casting_time"]):
			c.bonus_attack = str(feature["name"])
			var attack_rule := rule.duplicate(true)
			attack_rule["label"] = c.bonus_attack
			c.set_meta("bonus_attack_rule", attack_rule)
	var selected := str((ctx.get("opts", {}) as Dictionary).get("cast_form", ""))
	if selected == "":
		return
	var conc := ctx["conc"] as Concentration
	if conc == null or conc.ended:
		return
	for feature in casting_forms(c, spell):
		if str(feature["id"]) != selected:
			continue
		var rule := feature["cast_form"] as Dictionary
		if not c.creature.spend_resource(str(rule["resource"])):
			return
		var fx := Effect.new(str(feature["name"]), &"feature", selected)
		fx.caster_id = c.id
		fx.lasting(spell["duration"] as Dictionary)
		fx.data["triggered_form"] = rule.duplicate(true)
		fx.data["class_id"] = str(feature.get("class_id", ""))
		for modifier: Dictionary in rule.get("modifiers", []):
			fx.modifiers.append(Modifier.make(modifier.duplicate(true), fx.name, &"feature", selected, str(fx.data["class_id"])))
		conc.attach(c.creature, fx)
		rehook(c, fx)
		enc().log.add("info", "%s adopts %s" % [c.name(), fx.name], c.id)
		if rule.has("pulse"):
			pulse(c, fx)
		return

func rehook(c: Combatant, fx: Effect) -> void:
	if not bool((fx.data.get("triggered_form", {}) as Dictionary).get("shunt_on_end", false)):
		return
	var owner: WeakRef = weakref(c)
	var label := fx.name
	fx.on_end = func() -> void:
		var who := owner.get_ref() as Combatant
		if who != null:
			shunt(who, label)

func embedded(c: Combatant) -> bool:
	for cell in c.footprint():
		if enc().grid.is_solid(cell):
			return true
		for other in enc().living():
			if other != c and cell in other.footprint():
				return true
	return false

## Search the whole battlefield, by grid distance, rather than stopping at an arbitrary radius.
func shunt(c: Combatant, label: String) -> void:
	if not embedded(c):
		return
	var best := Vector2i(-1, -1)
	var feet := 1000000
	for x in enc().grid.width:
		for y in enc().grid.depth:
			var cell := Vector2i(x, y)
			if cell == c.cell or not enc().space_available(cell, c.size_cells, [c]):
				continue
			var distance := enc().grid.distance_ft(c.cell, c.size_cells, cell, c.size_cells)
			if distance < feet:
				best = cell
				feet = distance
	if best.x >= 0:
		enc().spells._teleport(c, best, CombatResult.new())
		enc().log.add("info", "%s is moved to the nearest empty space as %s ends" % [c.name(), label], c.id)

func turn_start(c: Combatant) -> void:
	for fx: Effect in c.creature.effects.duplicate():
		if (fx.data.get("triggered_form", {}) as Dictionary).has("pulse"):
			pulse(c, fx)

func turn_end(c: Combatant) -> void:
	for fx: Effect in c.creature.effects.duplicate():
		var rule := fx.data.get("triggered_form", {}) as Dictionary
		if fx not in c.creature.effects or not rule.has("embedded_damage") or not embedded(c):
			continue
		var damage := rule["embedded_damage"] as Dictionary
		var rolled := enc()._roll_damage_dice(str(damage["dice"]), false, 0, fx.name)
		enc().deal_damage(null, c, [{"amount": int(rolled["total"]), "type": str(damage["type"])}], false,
			"%s: ending a turn inside a creature or object" % fx.name, [str(rolled["text"])])

func pulse_candidates(c: Combatant, fx: Effect) -> Array[Combatant]:
	var out: Array[Combatant] = []
	var rule := (fx.data["triggered_form"] as Dictionary)["pulse"] as Dictionary
	for t in enc().living():
		if enc().distance(c, t) <= int(rule["radius"]) and int(enc().cover(c, t)["cover"]) != CombatGrid.Cover.TOTAL:
			out.append(t)
	return out

## The player chooses every affected creature, including allies or self, before play continues.
func pulse(c: Combatant, fx: Effect) -> void:
	var e := enc()
	if fx not in c.creature.effects:
		return
	if e.pending != null:
		e.then(CombatResult.new(), func() -> CombatResult:
			pulse(c, fx)
			var r := CombatResult.new()
			r.pending = e.pending
			return r)
		return
	var candidates := pulse_candidates(c, fx)
	var selected: Array[String] = []
	for t in candidates:
		if c.hostile_to(t):
			selected.append(t.id)
	var key := fx.source_id + "_pulse"
	var decision := e._reaction_decision(c, key)
	if decision == "never":
		return
	if decision == "auto":
		apply_pulse(c, fx, selected)
		return
	var rule := (fx.data["triggered_form"] as Dictionary)["pulse"] as Dictionary
	var req := ReactionRequest.new(key, c.id, "")
	req.title = "%s: choose creatures" % fx.name
	req.text = "Selected creatures in your %d-foot Emanation take %s %s damage. Clear a creature to spare it." % [int(rule["radius"]), str(rule["dice"]), str(rule["type"]).capitalize()]
	req.cost = "No action or Reaction"
	req.spends_reaction = false
	req.selected_ids = selected
	for t in candidates:
		req.target_choices.append({"id": t.id, "label": "%s · %d ft" % [t.name(), e.distance(c, t)]})
	# Weakly hold the prompt: the continuation lives on it until the player responds.
	var request_ref: WeakRef = weakref(req)
	req.continuation = func(use: bool) -> CombatResult:
		var request := request_ref.get_ref() as ReactionRequest
		if use and request != null:
			apply_pulse(c, fx, request.selected_ids)
		return CombatResult.new()
	e.pending = req

func apply_pulse(c: Combatant, fx: Effect, selected: Array[String]) -> void:
	if fx not in c.creature.effects:
		return
	var victims: Array[Combatant] = []
	for t in pulse_candidates(c, fx):
		if t.id in selected:
			victims.append(t)
	if victims.is_empty():
		return
	var rule := (fx.data["triggered_form"] as Dictionary)["pulse"] as Dictionary
	var rolled := enc()._roll_damage_dice(str(rule["dice"]), false, 0, fx.name)
	for t in victims:
		enc().deal_damage(c, t, [{"amount": int(rolled["total"]), "type": str(rule["type"]), "feature_class": str(fx.data.get("class_id", "")), "magical": true}],
			false, fx.name, [str(rolled["text"])])


## A subclass can increase a spell's effective level while paying the selected slot's actual level.
func casting_boosts(c: Combatant, spell: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not c.creature is Character or int(spell.get("level", 0)) <= 0:
		return out
	for f in (c.creature as Character).features:
		var def := f.get("cast_level_boost", {}) as Dictionary
		if def.is_empty() or c.creature.resource_left(str(def["resource"])) <= 0:
			continue
		if str(def["school"]) != str(spell.get("school", "")):
			continue
		if bool(def.get("adds_target", false)) and int((spell.get("upcast", {}) as Dictionary).get("targets", 0)) <= 0:
			continue
		if bool(def.get("no_attack_or_save", false)) and _has_attack_or_save(spell):
			continue
		out.append(f)
	return out

func _has_attack_or_save(value: Variant) -> bool:
	if value is Dictionary:
		var d := value as Dictionary
		for key: Variant in d:
			if str(key) in ["attack", "save", "repeat_save"]:
				return true
			if _has_attack_or_save(d[key]):
				return true
	elif value is Array:
		for item: Variant in value:
			if _has_attack_or_save(item):
				return true
	return false


func cantrip_attack(c: Combatant, spell: Dictionary, entry: Dictionary) -> bool:
	return not attack_cantrip_entry(c, spell, entry).is_empty()

func attack_cantrip_entry(c: Combatant, spell: Dictionary, entry: Dictionary) -> Dictionary:
	if int(spell.get("level", 0)) != 0 or str((spell.get("casting_time", {}) as Dictionary).get("unit", "")) != "action":
		return {}
	if c.attacks_left > 0 and bool(c.get_meta("attack_cantrip_used", false)):
		return {}
	for feature in recipes(c, "attack_cantrip"):
		var matched := casting_entry(c, spell, entry, feature["attack_cantrip"] as Dictionary)
		if not matched.is_empty():
			return matched
	return entry if CombatFeatures.has_feature(c, "war_magic") else {}

## A spell known from multiple classes must use an eligible source and that source's casting ability.
func casting_entry(c: Combatant, spell: Dictionary, entry: Dictionary, rule: Dictionary) -> Dictionary:
	var allowed: Array = rule.get("classes", [rule["class"]] if rule.has("class") else [])
	if allowed.is_empty() or str(entry.get("class_id", "")) in allowed:
		return entry
	var ch := enc().spells.caster_char(c)
	if ch == null:
		return {}
	for known in ch.known_spells():
		if str(known["id"]) != str(spell["id"]) or not str(known["class_id"]) in allowed:
			continue
		var matched := entry.duplicate()
		matched["class_id"] = str(known["class_id"])
		matched["ability"] = str(known["ability"])
		return matched
	return {}


func spell_sequences(c: Combatant, spell: Dictionary, entry: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if str((spell.get("casting_time", {}) as Dictionary).get("unit", "")) != "action":
		return out
	for feature in recipes(c, "spell_sequence"):
		var rule := feature["spell_sequence"] as Dictionary
		if int(spell.get("level", 0)) < int(rule["min_level"]) or int(spell.get("level", 0)) > int(rule["max_level"]):
			continue
		if not casting_entry(c, spell, entry, rule).is_empty():
			out.append(feature)
	return out

func sequence_why(c: Combatant, spell: Dictionary, entry: Dictionary, feature: Dictionary) -> String:
	var rule := feature["spell_sequence"] as Dictionary
	var why := enc()._bonus_check(c)
	if why != "":
		return why
	if c.creature.resource_left(str(rule["resource"])) < int(rule["resource_cost"]):
		return "Not enough %s" % str(rule["resource"]).replace("_", " ")
	if not bool(entry.get("free", false)):
		var has_slot := false
		for level in range(int(spell["level"]), int(rule["max_level"]) + 1):
			if enc().spells.caster_char(c).slots_left(level) > 0:
				has_slot = true
		if not has_slot:
			return "No spell slots within this feature's level limit"
	var casting := entry.duplicate()
	casting["casting"] = "bonus_action"
	return enc().spells._why_not(c, spell, casting)

func begin_sequence(c: Combatant, feature: Dictionary) -> void:
	var rule := feature["spell_sequence"] as Dictionary
	c.creature.spend_resource(str(rule["resource"]), int(rule["resource_cost"]))
	c.bonus_available = false
	var attacks := rule.duplicate(true)
	attacks["remaining"] = int(rule["followup_attacks"])
	attacks["label"] = str(feature["name"])
	c.set_meta("sequence_attacks", attacks)

func sequence_attack_options(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rule := c.get_meta("sequence_attacks", {}) as Dictionary
	if not c.can_act() or int(rule.get("remaining", 0)) <= 0:
		return out
	for option in enc().attack_options(c):
		var profile := option["profile"] as WeaponProfile
		if str(rule.get("attack_kind", "")) == "unarmed" and profile.item_id != "unarmed_strike":
			continue
		out.append(option)
	return out

func sequence_attack(c: Combatant, target: Combatant, option_id: String) -> CombatResult:
	var e := enc()
	var why := e._turn_check(c)
	if why != "":
		return CombatResult.fail(why)
	var option: Dictionary = {}
	for candidate in sequence_attack_options(c):
		if str(candidate["id"]) == option_id:
			option = candidate
	if option.is_empty():
		return CombatResult.fail("No attacks left in that sequence")
	why = e.attack_legal(c, target, option)
	if why != "":
		return CombatResult.fail(why)
	var rule := c.get_meta("sequence_attacks") as Dictionary
	rule["remaining"] = int(rule["remaining"]) - 1
	var tag := str(rule.get("attack_tag", ""))
	if tag != "":
		c.set_meta(tag + "_turn", e.class_features._turn_key())
	var result := e._resolve_attack(c, target, option, {})
	return e.then(result, func() -> CombatResult:
		if tag != "":
			c.remove_meta(tag + "_turn")
		return result)
