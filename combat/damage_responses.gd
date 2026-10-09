class_name DamageResponses
extends RefCounted
## Slot-funded reductions shared by attacks, spells, zones and other encounter damage.
## Attacks can pause for a choice. Synchronous callers act only on an explicit automatic policy.

var _enc: WeakRef

func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)

func enc() -> Encounter:
	return _enc.get_ref() as Encounter

func available(c: Combatant, feature: Dictionary) -> bool:
	if not c.creature is Character or not enc().spells.can_react(c):
		return false
	var rule := feature["damage_response"] as Dictionary
	var flag := str(rule.get("requires_flag", ""))
	return flag == "" or c.creature.has_flag(flag)

func slots(c: Combatant) -> Array[int]:
	var out: Array[int] = []
	for level in range(1, 10):
		if (c.creature as Character).slots_left(level) > 0:
			out.append(level)
	return out

func features(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c.creature is Character:
		for f in (c.creature as Character).features:
			if f.has("damage_response"):
				out.append(f)
	return out

func selection_why(c: Combatant, f: Dictionary, selected: Array[String], total: Callable) -> String:
	if selected.size() != 1 or not selected[0].is_valid_int():
		return "Choose one spell slot"
	var level := int(selected[0])
	if not available(c, f) or int(total.call()) <= 0:
		return "This damage response is no longer available"
	if not level in slots(c):
		return "That spell slot is no longer available"
	return ""

func offers(c: Combatant, total: Callable, cut: Callable, responded: Array) -> Array:
	var out: Array = []
	for f in features(c):
		if not available(c, f) or int(total.call()) <= 0:
			continue
		var levels := slots(c)
		if levels.is_empty():
			continue
		var id := str(f["id"])
		var name := str(f["name"])
		var per_slot := int((f["damage_response"] as Dictionary)["reduction_per_slot"])
		var automatic := int(c.reaction_rules.get(id + ":slot", levels[0]))
		# An explicit automatic policy never silently escalates to a more expensive slot.
		var default_level := automatic if automatic in levels else levels[0]
		var choice := {"level": default_level}
		var options: Array[Dictionary] = []
		for level in levels:
			options.append({"id": str(level), "label": "Level %d slot · reduce by %d (%d left)" % [level, per_slot * level, (c.creature as Character).slots_left(level)]})
		responded.append(id)
		out.append({"kind": id, "reactor": c, "title": "Reaction: %s?" % name,
			"text": "Incoming damage: %d. Choose a spell slot to reduce it before Resistance and Temporary Hit Points. Automatic mode reuses the selected slot level; spells and hazards require Automatic mode." % int(total.call()),
			"cost": "Reaction and the selected spell slot", "target_choices": options,
			"selected_ids": [str(default_level)], "min_targets": 1, "max_targets": 1,
			"still": func() -> bool:
				return available(c, f) and int(total.call()) > 0 and not slots(c).is_empty() \
					and (str(c.reaction_rules.get(id, "ask")) != "auto" or automatic in slots(c)),
			"validate_selected": func(selected: Array[String]) -> String: return selection_why(c, f, selected, total),
			"select": func(selected: Array[String]) -> void: choice["level"] = int(selected[0]),
			"use": func() -> void:
				var level := int(choice["level"])
				if not available(c, f) or not level in slots(c) or int(total.call()) <= 0:
					return
				(c.creature as Character).expend_slot(level)
				c.reaction_available = false
				c.reaction_rules[id + ":slot"] = level
				cut.call(level * per_slot, name)
				enc().log.add("reaction", "%s spends a level %d slot on %s" % [c.name(), level, name], c.id)})
	return out

func synchronous(c: Combatant, parts: Array, details: Array, responded: Array) -> Array:
	if features(c).is_empty():
		return parts
	var out := parts.duplicate(true)
	var total := func() -> int:
		if c.creature.preview_damage_parts(out).final <= 0:
			return 0
		var amount := 0
		for p: Dictionary in out:
			amount += maxi(0, int(p["amount"]))
		return amount
	var cut := func(amount: int, label: String) -> void:
		var left := amount
		for p: Dictionary in out:
			var reduction := mini(left, maxi(0, int(p["amount"])))
			p["amount"] = int(p["amount"]) - reduction
			left -= reduction
		details.append("%s: −%d" % [label, amount - left])
	var handled: Array = []
	for offer: Dictionary in offers(c, total, cut, handled):
		var id := str(offer["kind"])
		if id in responded or str(c.reaction_rules.get(id, "ask")) != "auto":
			continue
		if not (offer["still"] as Callable).call():
			continue
		(offer["use"] as Callable).call()
	return out

func list(c: Combatant, out: Array[Dictionary]) -> void:
	for f in features(c):
		var id := str(f["id"])
		var name := str(f["name"])
		var mode := str(c.reaction_rules.get(id, "ask"))
		var why := ""   # a standing rule changes on any turn (`anytime`): nothing is spent
		var level_now := int(c.reaction_rules.get(id + ":slot", 0))
		# Ask, Auto at each slot level, Off: the order the hotbar's toggle cycles through (ActionCatalog.slots).
		out.append({"id": "feat:damage_policy:%s:ask" % id, "label": "%s: Ask" % name,
			"sub": "Ask" + (" · selected" if mode == "ask" else ""), "cost": "free", "why": why, "targeting": "none", "range": 0,
			"policy": id, "policy_name": name, "mode": "ask", "mode_label": "Ask", "selected": mode == "ask", "anytime": true,
			"help": "Ask before reducing weapon-attack damage; spell and hazard damage currently require Automatic mode. Off never spends a slot."})
		for level in slots(c):
			var on := mode == "auto" and level_now == level
			out.append({"id": "feat:damage_policy:%s:%d" % [id, level], "label": "%s: Auto, level %d" % [name, level],
				"sub": "Auto · level %d%s" % [level, " ✓" if on else ""], "cost": "free", "why": why, "targeting": "none", "range": 0,
				"policy": id, "policy_name": name, "mode": "auto:%d" % level, "mode_label": "Auto, level %d" % level, "selected": on, "anytime": true,
				"help": "Automatically spend your Reaction and one slot of this exact level against the next damage while the feature is active. Applies to weapon attacks, spells and hazards; never substitutes a different slot level."})
		out.append({"id": "feat:damage_policy:%s:never" % id, "label": "%s: Off" % name,
			"sub": "Off" + (" · selected" if mode == "never" else ""), "cost": "free", "why": why, "targeting": "none", "range": 0,
			"policy": id, "policy_name": name, "mode": "never", "mode_label": "Off", "selected": mode == "never", "anytime": true,
			"help": "Ask before reducing weapon-attack damage; spell and hazard damage currently require Automatic mode. Off never spends a slot."})

func set_policy(c: Combatant, id: String, pick: String) -> CombatResult:
	if not features(c).any(func(f: Dictionary) -> bool: return str(f["id"]) == id):
		return CombatResult.fail("Not available")
	if pick in ["ask", "never"]:
		c.reaction_rules[id] = pick
	elif pick.is_valid_int() and int(pick) in slots(c):
		c.reaction_rules[id] = "auto"
		c.reaction_rules[id + ":slot"] = int(pick)
	else:
		return CombatResult.fail("Choose an available spell slot")
	return CombatResult.new()
