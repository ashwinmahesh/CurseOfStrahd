class_name LocationTraps
extends RefCounted
## Traps and searching in a location (LocationView): found traps shown on the board, a member stepping on a trap
## springs it, a Search (a Wisdom (Perception) check) finds traps, hidden props and secret doors nearby, and thieves'
## tools disarm. Noticing a trap by passive Perception is TrapSight's; pits are PitFall's.


static func _mark_found_traps(view: LocationView) -> void:
	for t: Variant in view.loc.get("traps", []):
		var trap := t as Dictionary
		var state := str((view.st.loc_state(view.loc_id)["traps"] as Dictionary).get(str(trap["id"]), ""))
		if state == "found":
			_show_trap(view, trap)


static func _show_trap(view: LocationView, trap: Dictionary) -> void:
	if view.trap_marks.has(str(trap["id"])):
		return
	view.trap_marks[str(trap["id"])] = TrapSight.dress(view, trap)   # its own piece and a red border that doesn't cover it


## Passive Perception notices traps in sight (TrapSight); a member stepping on an unnoticed trap springs it.
static func _check_traps(view: LocationView) -> bool:
	var states := view.st.loc_state(view.loc_id)["traps"] as Dictionary
	for t: Variant in view.loc.get("traps", []):
		var trap := t as Dictionary
		var id := str(trap["id"])
		if not StoryConditions.check(str(trap.get("when", "")), view.st):
			continue
		var state := str(states.get(id, ""))
		if state in ["disarmed", "triggered"]:
			continue
		var cells: Array[Vector2i] = []
		for c: Variant in trap["cells"]:
			cells.append(LocationView._cell(c))
		if state == "" and TrapSight.notice(view, trap):
			return true
		if str(states.get(id, "")) == "":
			for m in view.members:
				if m.cell in cells:
					_spring_trap(view, trap, m)
					return true
	return false


static func _spring_trap(view: LocationView, trap: Dictionary, victim: Combatant) -> void:
	if PitFall.is_pit(trap):
		PitFall.spring(view, trap, victim)   # a real drop: catch the edge or fall in (and climb out later)
		return
	var id := str(trap["id"])
	(view.st.loc_state(view.loc_id)["traps"] as Dictionary)[id] = "triggered"
	BattleScenery.trap_sprung(view, id)   # a chandelier that is this trap comes down
	var lines: Array[String] = []
	var save := trap.get("save", {}) as Dictionary
	var success := false
	if not save.is_empty():
		var t := victim.creature.roll_save(view.dice, StringName(str(save["ability"])), int(save["dc"]))
		success = t.success
		lines.append(t.describe())
	if str(trap.get("damage", "")) != "":
		var rolled := view.dice.roll_expr(str(trap["damage"]), "Trap: %s" % trap.get("label", id))
		var amount := int(rolled["total"])
		if success:
			amount /= 2
		# Thief's Thimble: its wearer's trap damage soaks into it first.
		var dr := victim.creature.take_damage(FaerunItems.thimble(victim.creature, amount), StringName(str(trap.get("damage_type", "bludgeoning"))), false, view.dice, str(trap.get("label", "a trap")))
		lines.append(dr.describe(victim.name()))
		(view.tokens[victim.id] as CombatToken).flash(Look.color("vampire_red"))
	if str(trap.get("condition", "")) != "" and not success:
		victim.creature.add_condition(StringName(str(trap["condition"])), str(trap.get("label", "a trap")))
	(view.tokens[victim.id] as CombatToken).refresh()
	if trap.has("flag"):
		view.st.set_flag(str(trap["flag"]))
	view.check_rolled.emit(" · ".join(lines))
	view._say("trap:%s:triggered" % id, victim.creature as Character, str(trap.get("text", "A trap springs!")))


## Searching (out of combat): a Wisdom (Perception) check by the leader finds traps and hidden things within 15 ft
## (search props, secret doors) whose DC it meets. Takes a minute.
static func search(view: LocationView) -> void:
	if view.busy or view.in_combat:
		return
	var who := view.leader().creature as Character
	# Sharp Eye (Ravenloft: The Horrors Within): Advantage on a Search, Proficiency Bonus times per Long Rest.
	var adv: Array[String] = []
	if who.feats_taken.any(func(f: Dictionary) -> bool: return str(f["id"]) == "sharp_eye") and who.resource_left("sharp_eye") > 0:
		who.spend_resource("sharp_eye")
		adv.append("Sharp Eye")
	var sharp_eye := not adv.is_empty()
	adv.append_array(CheckAids.before_check(who, &"perception"))
	var t := who.roll_check(view.dice, &"perception", 0, adv, [], "%s searches" % who.name, ["search"])
	view.check_rolled.emit(t.describe())
	view.st.advance_minutes(1)
	var found: Array[String] = []
	var found_ids: Array[String] = []
	var c := view.leader().cell
	var states := view.st.loc_state(view.loc_id)
	for tr: Variant in view.loc.get("traps", []):
		var trap := tr as Dictionary
		if str((states["traps"] as Dictionary).get(str(trap["id"]), "")) != "":
			continue
		for tc: Variant in trap["cells"]:
			if view.grid.distance_ft(c, 1, LocationView._cell(tc), 1) <= 15 and t.total >= int(trap["detect_dc"]):
				(states["traps"] as Dictionary)[str(trap["id"])] = "found"
				_show_trap(view, trap)
				found.append(str(trap.get("label", "a trap")))
				break
	for p: Variant in view.loc.get("props", []):
		var prop := p as Dictionary
		if str(prop["kind"]) != "search" or bool((states["found"] as Dictionary).get(str(prop["id"]), false)):
			continue
		if view.grid.distance_ft(c, 1, LocationView._cell(prop["cell"]), 1) <= 15 and t.total >= int(prop.get("search_dc", 10)):
			(states["found"] as Dictionary)[str(prop["id"])] = true
			view.prop_nodes[str(prop["id"])] = LocationBuilder._prop_node(view, prop)
			found.append(str(prop.get("label", "something")))
			found_ids.append(str(prop["id"]))
	for d: Variant in view.loc.get("doors", []):
		var door := d as Dictionary
		if int(door.get("secret_dc", 0)) <= 0 or bool((states["found"] as Dictionary).get(str(door["id"]), false)):
			continue
		if view.grid.distance_ft(c, 1, LocationView._cell(door["cell"]), 1) <= 15 and t.total >= int(door["secret_dc"]):
			(states["found"] as Dictionary)[str(door["id"])] = true
			SetDressing.reveal_door(view.door_nodes[str(door["id"])] as Node3D)
			found.append(str(door.get("label", "a hidden door")))
	view.st.last_check = not found.is_empty()
	if found.is_empty() and sharp_eye:
		who.restore_resource("sharp_eye")
	if found.is_empty():
		view._say("check:perception:failure", who, "Nothing you can find.")
	else:
		# A found thing's own line (search:<prop> or check:perception:<prop>:success) before the generic one.
		var said := false
		for id in found_ids:
			if not said:
				said = view._say("search:" + id, who) or view._say("check:perception:%s:success" % id, who)
		if not said:
			view._say("check:perception:success", who, "")
		view.toast.emit("Found: " + ", ".join(found))


static func _disarm(view: LocationView, trap: Dictionary) -> void:
	var who := LocationLocks._lock_picker(view)
	if who == null:
		view.narration.emit("Without thieves' tools you can only walk around it.")
		return
	var bonus := who.ability_check_bonus(&"dex")
	if who.has_proficiency("tools", "thieves_tools"):
		bonus.add("Thieves' Tools proficiency", who.proficiency_bonus())
	var t := who.roll_d20(view.dice, D20Test.Kind.ABILITY_CHECK, bonus, int(trap.get("disarm_dc", 15)), who.check_keys(&"dex"), [], [], "%s disarms %s" % [who.name, trap.get("label", "the trap")])
	view.check_rolled.emit(t.describe())
	if t.success:
		(view.st.loc_state(view.loc_id)["traps"] as Dictionary)[str(trap["id"])] = "disarmed"
		for n: Node3D in view.trap_marks.get(str(trap["id"]), []):
			n.queue_free()
		view.trap_marks.erase(str(trap["id"]))
		view._say("trap:%s:disarmed" % trap["id"], who, "Disarmed.")
	elif t.total <= int(trap.get("disarm_dc", 15)) - 5:
		var m: Combatant = null
		for mm in view.members:
			if mm.creature == who:
				m = mm
		_spring_trap(view, trap, m if m != null else view.leader())
	else:
		view._say("trap:%s:failed" % trap["id"], who, "Not yet. Careful.")
