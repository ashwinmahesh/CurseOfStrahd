class_name LocationChecks
extends RefCounted
## Skill checks on things in a location (LocationView), the board's side of WorldChecks: the right-click menu's lines
## for a thing's checks (who'd roll, the bonus, Advantage, the chance), the try itself on the big d20, the Narrator's
## line for how it went (`check:<skill>:<check id>:success` or `:failure`, else the outcome's `text`), and the parts of
## an outcome that reach into the place: hidden things revealed (here, or `<location>:<id>` somewhere else), traps found
## or disarmed, locks undone, a door opened, the party across to another square, and what a flag just brought into view.
## A hiding place a check reaches here keeps its item until someone takes it from there (owner, 2026-10-14): the check
## only shows where it is, and the hiding place glows orange (FoundGlow) until the party uses it.
## A fight a check sets off is an encounter here whose trigger is `check:<check id>:success` or `:failure`.

## The view's memory of the last failed check, for the aids still to spend on it: {check, spec, test, who}.
const FAILED := "world_check_failed"


## The menu's lines for `spec`'s open checks: `check:<id>` (greyed with the reason when nobody's left to try) and, after
## a failure here, `check_aid:<aid>` for each aid the roller could still spend (Heroic Inspiration ...).
static func actions_for(view: LocationView, spec: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for check in WorldChecks.open_checks(view.st, view.loc_id, spec):
		var pv := WorldChecks.preview(view.st, view.loc_id, check)
		var what := "%s DC %d" % [WorldChecks.skill_name(check), int(check["dc"])]
		if pv.is_empty():
			out.append({"id": "check:" + str(check["id"]), "label": "%s (%s)" % [check["label"], what], "enabled": false,
				"why": "Everyone able has tried" if WorldChecks.roller(view.st, view.loc_id, check) == null else ""})
			continue
		var who := pv["who"] as Character
		var edge := ""
		if not (pv["advantage"] as Array).is_empty() and (pv["disadvantage"] as Array).is_empty():
			edge = " with Advantage"
		elif (pv["advantage"] as Array).is_empty() and not (pv["disadvantage"] as Array).is_empty():
			edge = " with Disadvantage"
		out.append({"id": "check:" + str(check["id"]), "label": "%s (%s: %s %s%s, %d%%)" % [check["label"], what,
			who.name.get_slice(" ", 0), _signed(int(pv["bonus"])), edge, roundi(float(pv["chance"]) * 100.0)], "why": _why(pv)})
	var failed := view.get_meta(FAILED, {}) as Dictionary
	if not failed.is_empty() and failed["spec"] == spec:
		var who := failed["who"] as Character
		for aid in CheckAids.options(who, failed["test"] as D20Test):
			out.append({"id": "check_aid:" + str(aid["id"]), "label": "%s: %s" % [who.name.get_slice(" ", 0), aid["label"]]})
	return out


static func _signed(n: int) -> String:
	return ("+%d" % n) if n >= 0 else str(n)


## The tooltip: who helps, and how.
static func _why(pv: Dictionary) -> String:
	var parts: Array[String] = []
	for s: Variant in pv["advantage"]:
		parts.append("Advantage: %s" % s)
	for s: Variant in pv["disadvantage"]:
		parts.append("Disadvantage: %s" % s)
	if pv["guide"] != null:
		var first := (pv["guide"] as Creature).name.get_slice(" ", 0)
		parts.append(("Guidance (%s): +1d4" % first) if bool(pv["guide_sure"]) else
			("Guidance: %s can cast it first, +1d4 (you're asked before the roll)" % first))
	return ". ".join(parts)


## What a thing's hover name adds while it has a check someone can still try: " (Arcana, History)". "" otherwise.
static func hint(view: LocationView, spec: Dictionary) -> String:
	var names := skills_offered(view, spec)
	return "" if names == "" else " (%s)" % names


## The skills a thing's checks still offer someone: "Arcana, History", or "".
static func skills_offered(view: LocationView, spec: Dictionary) -> String:
	var names: Array[String] = []
	for check in WorldChecks.open_checks(view.st, view.loc_id, spec):
		var n := WorldChecks.skill_name(check)
		if not n in names and WorldChecks.anyone_left(view.st, view.loc_id, check):
			names.append(n)
	return ", ".join(names)


## A menu choice `check:<id>` or `check_aid:<aid>` on `thing` (the party has walked up to it).
static func act(view: LocationView, thing: Dictionary, action_id: String) -> void:
	var spec := thing["spec"] as Dictionary
	if action_id.begins_with("check_aid:"):
		_spend_aid(view, spec, action_id.substr(10))
		return
	var check := WorldChecks.find(spec, action_id.substr(6))
	if check.is_empty() or not WorldChecks.open(view.st, view.loc_id, check):
		return
	if view.has_meta(FAILED):
		view.remove_meta(FAILED)
	var who := WorldChecks.roller(view.st, view.loc_id, check)
	if who == null:
		view.toast.emit("Everyone able has tried that")
		return
	# Guidance first, if someone can cast it (asked, or cast on their Automatic rule), then the roll.
	view.ask_guidance(who, WorldChecks.skill_of(check), int(check["dc"]), func(extra: Array) -> void: _try(view, spec, check, extra))


## The try itself, with Guidance's die if it was cast (`extra`).
static func _try(view: LocationView, spec: Dictionary, check: Dictionary, extra: Array) -> void:
	var res := WorldChecks.attempt(view.st, view.loc_id, check, view.dice, extra)
	if res.is_empty():
		view.toast.emit("Everyone able has tried that")
		return
	var t := res["test"] as D20Test
	var who := res["who"] as Character
	view.check_rolled.emit(t.describe())
	view.big_roll.emit(t, who.name, WorldChecks.skill_name(check))
	if not t.success and not CheckAids.options(who, t).is_empty():
		view.set_meta(FAILED, {"check": check, "spec": spec, "test": t, "who": who})
	_resolve(view, spec, check, who, t.success)


## Spends an aid on the last failed check here; a success turns it round (its success happens, its failure stays done).
static func _spend_aid(view: LocationView, spec: Dictionary, aid: String) -> void:
	var failed := view.get_meta(FAILED, {}) as Dictionary
	if failed.is_empty() or failed["spec"] != spec:
		return
	view.remove_meta(FAILED)
	var who := failed["who"] as Character
	var check := failed["check"] as Dictionary
	var t := CheckAids.apply(aid, who, failed["test"] as D20Test, view.dice)
	view.check_rolled.emit(t.describe())
	view.big_roll.emit(t, who.name, WorldChecks.skill_name(check))
	if not t.success:
		if not CheckAids.options(who, t).is_empty():
			view.set_meta(FAILED, {"check": check, "spec": spec, "test": t, "who": who})
		return
	WorldChecks.record(view.st, view.loc_id, check, who, true)
	_resolve(view, spec, check, who, true, false)


## What happens after the roll: the Narrator's line, the outcome, the toast, and a fight it sets off.
static func _resolve(view: LocationView, spec: Dictionary, check: Dictionary, who: Character, success: bool, say_failure: bool = true) -> void:
	var result := "success" if success else "failure"
	var outcome := check.get(result, {}) as Dictionary
	if success or say_failure:
		view._say("check:%s:%s:%s" % [check["skill"], check["id"], result], who, str(outcome.get("text", "")) if success else
			str(outcome.get("text", "It doesn't give. Someone else might do better.")))
	var res := WorldChecks.apply(view.st, outcome, who, view.dice, str(check.get("label", "")))
	if not (res["lines"] as Array).is_empty():
		view.check_rolled.emit(" · ".join(res["lines"] as Array))
	# A slip, a cold swim or a ritual gone wrong that hurt them: the effect, the damage over their head and the party
	# panel, once the roll has been seen (LocationHurt).
	var hurt := res["hurt"] as Dictionary
	if not hurt.is_empty():
		LocationHurt.show(view, LocationHurt.member(view, hurt["who"] as Creature), int(hurt["amount"]),
			TrapFx.cue("checks", str(check["id"]), hurt["type"] as StringName))
	# XP levelling (story/xp.gd): a check passed is worth a little, and so is each hiding place, secret door or trap it
	# brings to light (_reveal_here). The XP rides on the notice the thing already has.
	var passed := Xp.award(view.st, "check", "%s:%s" % [view.loc_id, check["id"]]) if success else 0
	var xp_before := view.st.xp
	var found := _reach_into(view, outcome)
	var finds_xp := view.st.xp - xp_before
	var gains: Array[String] = []
	gains.assign(res["gains"] as Array)
	if not gains.is_empty():
		view.toast.emit("%s: %s%s" % [who.name.get_slice(" ", 0), ", ".join(gains), Xp.tag(passed)])
		passed = 0
	if not found.is_empty():
		view.toast.emit("Found: " + ", ".join(found) + Xp.tag(finds_xp + passed))
		passed = 0
	if passed > 0:
		view.check_rolled.emit("+%s XP" % Xp.fmt(passed))
	if str(outcome.get("flag", "")) != "":
		_show_new_things(view)
	view.refresh_party()
	view._trigger_encounter("check:%s:%s" % [check["id"], result])


## Reveals, traps, locks, a door and a move. Returns the names of what came to light here, for a toast.
static func _reach_into(view: LocationView, outcome: Dictionary) -> Array[String]:
	var found: Array[String] = []
	var states := view.st.loc_state(view.loc_id)
	for r: Variant in outcome.get("reveal", []):
		var ref := str(r)
		if ref.contains(":"):
			# A place hint: something hidden somewhere else, now known (its hiding place shows when the party gets there).
			(view.st.loc_state(ref.get_slice(":", 0))["found"] as Dictionary)[ref.get_slice(":", 1)] = true
			view.toast.emit(_hint_words(ref))
			continue
		var name := _reveal_here(view, ref)
		if name != "":
			found.append(name)
	for tr: Variant in outcome.get("disarm", []):
		var trap := _spec("traps", view, str(tr))
		if not trap.is_empty() and str((states["traps"] as Dictionary).get(str(tr), "")) not in ["disarmed", "triggered"]:
			(states["traps"] as Dictionary)[str(tr)] = "disarmed"
			LocationTraps._clear_marks(view, str(tr))
	for u: Variant in outcome.get("unlock", []):
		if str((states["doors"] as Dictionary).get(str(u), "")) != LocationView.DOOR_OPEN:
			(states["doors"] as Dictionary)[str(u)] = "unlocked"
	for o: Variant in outcome.get("open", []):
		var door := _spec("doors", view, str(o))
		if not door.is_empty() and LocationLocks._door_state(view, str(o)) != LocationView.DOOR_OPEN:
			(states["doors"] as Dictionary)[str(o)] = "unlocked"
			LocationLocks._use_door(view, door)
	if outcome.has("move"):
		_move_party(view, LocationView._cell(outcome["move"]))
	return found


## Brings hidden thing `id` here to light: a hiding place (a search prop), a secret door or a trap. Its name, or "".
## A hiding place holding an item keeps it: whoever uses it takes it (LocationInteraction._use_prop).
static func _reveal_here(view: LocationView, id: String) -> String:
	var states := view.st.loc_state(view.loc_id)
	var prop := _spec("props", view, id)
	if not prop.is_empty() and not bool((states["found"] as Dictionary).get(id, false)):
		(states["found"] as Dictionary)[id] = true
		if StoryConditions.check(str(prop.get("when", "")), view.st) and not view.prop_nodes.has(id):
			view.prop_nodes[id] = LocationBuilder._prop_node(view, prop)
		Xp.award(view.st, "find", "%s:%s" % [view.loc_id, id])
		return str(prop.get("label", "something"))
	var door := _spec("doors", view, id)
	if not door.is_empty() and int(door.get("secret_dc", 0)) > 0 and not bool((states["found"] as Dictionary).get(id, false)):
		(states["found"] as Dictionary)[id] = true
		SetDressing.reveal_door(view.door_nodes[id] as Node3D)
		Xp.award(view.st, "find", "%s:%s" % [view.loc_id, id])
		return str(door.get("label", "a hidden door"))
	var trap := _spec("traps", view, id)
	if not trap.is_empty() and str((states["traps"] as Dictionary).get(id, "")) == "":
		(states["traps"] as Dictionary)[id] = "found"
		view._show_trap(trap)
		Xp.award(view.st, "trap_noticed", "%s:%s" % [view.loc_id, id])
		return str(trap.get("label", "a trap"))
	return ""


## A place hint's toast: "Now you know where to look: a hunter's boots in the mud (The Hills above Lake Zarovich)".
static func _hint_words(ref: String) -> String:
	var loc := Compendium.shared().get_entry("locations", ref.get_slice(":", 0))
	var label := ref.get_slice(":", 1)
	for p: Variant in loc.get("props", []):
		if str((p as Dictionary)["id"]) == label:
			label = str((p as Dictionary).get("label", label))
	return "Now you know where to look: %s (%s)" % [label, loc.get("name", ref.get_slice(":", 0))]


static func _spec(list: String, view: LocationView, id: String) -> Dictionary:
	for t: Variant in view.loc.get(list, []):
		if str((t as Dictionary)["id"]) == id:
			return t as Dictionary
	return {}


## The party crosses to `cell` (a climb, a leap, a squeeze): the leader there and the rest around them.
static func _move_party(view: LocationView, cell: Vector2i) -> void:
	var cells := LocationParty._cells_around(view, cell, view.members.size())
	for i in view.members.size():
		var m := view.members[i]
		m.cell = cells[i]
		var tok := view.tokens[m.id] as CombatToken
		tok.position = view.board.cell_center(cells[i])
	view._queue.clear()
	LocationParty._save_positions(view)
	view.place_guests()
	view.rig.snap_to_target()
	LocationWalk._check_areas(view)


## Props and chests whose `when` a check's flag just made true come into view without leaving the place.
static func _show_new_things(view: LocationView) -> void:
	var found := view.st.loc_state(view.loc_id)["found"] as Dictionary
	for p: Variant in view.loc.get("props", []):
		var prop := p as Dictionary
		var id := str(prop["id"])
		if view.prop_nodes.has(id) or not StoryConditions.check(str(prop.get("when", "")), view.st):
			continue
		if str(prop["kind"]) == "search" and not bool(found.get(id, false)):
			continue
		view.prop_nodes[id] = LocationBuilder._prop_node(view, prop)
	for c: Variant in view.loc.get("containers", []):
		var ct := c as Dictionary
		if view.container_nodes.has(str(ct["id"])) or not StoryConditions.check(str(ct.get("when", "")), view.st):
			continue
		var node: Node3D = SetDressing.place(view.board, ct, true)
		if node == null:
			node = LocationBuilder._box(view, Vector3(0.8, 0.55, 0.55), view.board.cell_center(LocationView._cell(ct["cell"])) + Vector3(0, 0.28, 0), "umber")
		view.container_nodes[str(ct["id"])] = node
