class_name LocationTraps
extends RefCounted
## Traps and searching in a location (LocationView): found traps shown on the board, a member stepping on a trap
## springs it (found or not), a Search (a Wisdom (Perception) check) finds traps, hidden props and secret doors nearby
## and shows how far it reached, a found trap can be set off on purpose from within 5 ft, and thieves' tools disarm
## one when the player chooses to. Nothing notices a trap passively and nothing disarms one on its own (owner,
## 2026-10-08). How a found trap looks is TrapSight's; pits are PitFall's.

## How far a Search reaches (feet), and how long its reach shows on the ground (seconds).
const SEARCH_FT := 15
const REACH_SHOWN := 1.6
## How strong the Search's tint is on the ground (owner, 2026-10-08: 15%, so the ground shows through).
const REACH_ALPHA := 0.15


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


## A member stepping on a trap springs it, whether or not the party found it (a found one isn't walked round).
static func _check_traps(view: LocationView) -> bool:
	var states := view.st.loc_state(view.loc_id)["traps"] as Dictionary
	for t: Variant in view.loc.get("traps", []):
		var trap := t as Dictionary
		var id := str(trap["id"])
		if not StoryConditions.check(str(trap.get("when", "")), view.st):
			continue
		if str(states.get(id, "")) in ["disarmed", "triggered"]:
			continue
		var cells := _cells(trap)
		for m in view.members:
			if m.cell in cells:
				_spring_trap(view, trap, m)
				return true
	return false


static func _cells(trap: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for c: Variant in trap["cells"]:
		cells.append(LocationView._cell(c))
	return cells


## Why the leader can't set off the found trap `trap` on purpose ("" if they can): from within 5 ft of one of its
## squares, or standing in one.
static func activate_why(view: LocationView, trap: Dictionary) -> String:
	var at := view.leader().cell
	for c in _cells(trap):
		if view.grid.distance_ft(at, 1, c, 1) <= 5:
			return ""
	return "Get within 5 ft of it first"


## Sets a found trap off on purpose (owner, 2026-10-08): whoever stands in its squares takes it; with nobody there it
## goes off harmlessly (a pit opens).
static func activate(view: LocationView, trap: Dictionary) -> void:
	var why := activate_why(view, trap)
	if why != "":
		view.toast.emit(why)
		return
	var cells := _cells(trap)
	var victim: Combatant = null
	for m in view.members:
		if m.cell in cells:
			victim = m
			break
	_spring_trap(view, trap, victim)


## Springs `trap` on `victim` (null: set off with nobody in it). Its marks go: a sprung trap is spent.
static func _spring_trap(view: LocationView, trap: Dictionary, victim: Combatant) -> void:
	Audio.sfx("trap")
	if PitFall.is_pit(trap):
		PitFall.spring(view, trap, victim)   # a real drop: catch the edge or fall in (and climb out later)
		return
	var id := str(trap["id"])
	(view.st.loc_state(view.loc_id)["traps"] as Dictionary)[id] = "triggered"
	BattleScenery.trap_sprung(view, id)   # a chandelier that is this trap comes down
	_clear_marks(view, id)
	if victim == null:
		if trap.has("flag"):
			view.st.set_flag(str(trap["flag"]))
		view.narration.emit("%s goes off with nobody in it." % str(trap.get("label", "The trap")).capitalize())
		return
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
## (search props, secret doors) whose DC it meets. A hidden compartment (a search prop with `skill: investigation`)
## takes an Intelligence (Investigation) check instead, rolled as well when one is near. A hidden find that holds an
## item gets one look from each character: whoever misses it has missed it for good (the owner's rule that failed
## checks are final), though someone else in the party can still try. Takes a minute.
static func search(view: LocationView) -> void:
	if view.busy or view.in_combat:
		return
	var who := view.leader().creature as Character
	var c := view.leader().cell
	var states := view.st.loc_state(view.loc_id)
	# Sharp Eye (Ravenloft: The Horrors Within): Advantage on a Search, Proficiency Bonus times per Long Rest.
	var adv: Array[String] = []
	if who.feats_taken.any(func(f: Dictionary) -> bool: return str(f["id"]) == "sharp_eye") and who.resource_left("sharp_eye") > 0:
		who.spend_resource("sharp_eye")
		adv.append("Sharp Eye")
	var sharp_eye := not adv.is_empty()
	adv.append_array(CheckAids.before_check(who, &"perception"))
	var t := who.roll_check(view.dice, &"perception", 0, adv, Weather.sight_penalty(view.st, view.loc_id), "%s searches" % who.name, ["search"])
	view.check_rolled.emit(t.describe())
	var study: D20Test = null
	if hidden_within(view, c, SEARCH_FT, who).any(func(p: Dictionary) -> bool: return search_skill(p) == &"investigation"):
		study = who.roll_check(view.dice, &"investigation", 0, CheckAids.before_check(who, &"investigation"), [], "%s looks for hidden compartments" % who.name, ["search"])
		view.check_rolled.emit(study.describe())
	view.st.advance_minutes(1)
	var found: Array[String] = []
	var found_ids: Array[String] = []
	var missed_ids: Array[String] = []   # their own failure lines' keys
	show_reach(view, c, SEARCH_FT)
	for tr: Variant in view.loc.get("traps", []):
		var trap := tr as Dictionary
		# Not one that isn't set yet (its `when` doesn't hold: Death House's blades before the party refuses).
		if str((states["traps"] as Dictionary).get(str(trap["id"]), "")) != "" or not StoryConditions.check(str(trap.get("when", "")), view.st):
			continue
		for tc: Variant in trap["cells"]:
			if view.grid.distance_ft(c, 1, LocationView._cell(tc), 1) <= SEARCH_FT and t.total >= int(trap["detect_dc"]):
				(states["traps"] as Dictionary)[str(trap["id"])] = "found"
				_show_trap(view, trap)
				found.append(str(trap.get("label", "a trap")))
				break
	for prop in hidden_within(view, c, SEARCH_FT, who):
		var roll := study if search_skill(prop) == &"investigation" else t
		if roll.total >= int(prop.get("search_dc", 10)):
			(states["found"] as Dictionary)[str(prop["id"])] = true
			view.prop_nodes[str(prop["id"])] = LocationBuilder._prop_node(view, prop)
			found.append(str(prop.get("label", "something")))
			found_ids.append(str(prop["id"]))
		elif prop.has("item"):
			(states["found"] as Dictionary)[_missed_key(prop, who)] = true
			missed_ids.append("check:%s:%s:failure" % [search_skill(prop), prop["id"]])
	for d: Variant in view.loc.get("doors", []):
		var door := d as Dictionary
		if int(door.get("secret_dc", 0)) <= 0 or bool((states["found"] as Dictionary).get(str(door["id"]), false)):
			continue
		if view.grid.distance_ft(c, 1, LocationView._cell(door["cell"]), 1) <= SEARCH_FT and t.total >= int(door["secret_dc"]):
			(states["found"] as Dictionary)[str(door["id"])] = true
			SetDressing.reveal_door(view.door_nodes[str(door["id"])] as Node3D)
			found.append(str(door.get("label", "a hidden door")))
	view.st.last_check = not found.is_empty()
	if found.is_empty() and sharp_eye:
		who.restore_resource("sharp_eye")
	if found.is_empty():
		# A missed find's own line, if it has one (a hint that someone else might do better), before the generic one.
		var said_miss := false
		for key in missed_ids:
			if not said_miss:
				said_miss = view._say(key, who)
		if not said_miss:
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


## The hidden things (search props) within `ft` of `cell` that a search could still turn up: not found yet, their
## `when` holds, and, for a find holding an item, `who` hasn't already missed it (null: anyone).
static func hidden_within(view: LocationView, cell: Vector2i, ft: int, who: Character = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var found := view.st.loc_state(view.loc_id)["found"] as Dictionary
	for p: Variant in view.loc.get("props", []):
		var prop := p as Dictionary
		if str(prop["kind"]) != "search" or bool(found.get(str(prop["id"]), false)):
			continue
		if not StoryConditions.check(str(prop.get("when", "")), view.st):
			continue
		if who != null and prop.has("item") and bool(found.get(_missed_key(prop, who), false)):
			continue
		if view.grid.distance_ft(cell, 1, LocationView._cell(prop["cell"]), 1) <= ft:
			out.append(prop)
	return out


## The skill that finds a hidden thing: Perception, or Investigation for a compartment you have to work out.
static func search_skill(prop: Dictionary) -> StringName:
	return &"investigation" if str(prop.get("skill", "")) == "investigation" else &"perception"


## Kept in the location's `found` states: this character looked for this find and missed it.
static func _missed_key(prop: Dictionary, who: Character) -> String:
	return "missed:%s:%s" % [prop["id"], who.id if who.id != "" else who.name]


static func _disarm(view: LocationView, trap: Dictionary) -> void:
	var who := LocationLocks._lock_picker(view)
	if who == null:
		view.narration.emit("Without thieves' tools you can't disarm it. Walk around it, or set it off from a safe distance.")
		return
	var bonus := who.ability_check_bonus(&"dex")
	if who.has_proficiency("tools", "thieves_tools"):
		bonus.add("Thieves' Tools proficiency", who.proficiency_bonus())
	var t := who.roll_d20(view.dice, D20Test.Kind.ABILITY_CHECK, bonus, int(trap.get("disarm_dc", 15)), who.check_keys(&"dex"), [], [], "%s disarms %s" % [who.name, trap.get("label", "the trap")])
	view.check_rolled.emit(t.describe())
	if t.success:
		(view.st.loc_state(view.loc_id)["traps"] as Dictionary)[str(trap["id"])] = "disarmed"
		_clear_marks(view, str(trap["id"]))
		view._say("trap:%s:disarmed" % trap["id"], who, "Disarmed.")
	elif t.total <= int(trap.get("disarm_dc", 15)) - 5:
		var m: Combatant = null
		for mm in view.members:
			if mm.creature == who:
				m = mm
		_spring_trap(view, trap, m if m != null else view.leader())
	else:
		view._say("trap:%s:failed" % trap["id"], who, "Not yet. Careful.")


static func _clear_marks(view: LocationView, id: String) -> void:
	for n: Node3D in view.trap_marks.get(id, []):
		n.queue_free()
	view.trap_marks.erase(id)


## Shows for a moment, on the ground, how far a Search from `center` reached (owner, 2026-10-08): the open squares within
## `feet`, tinted, fading after REACH_SHOWN seconds. What it found is marked as usual.
static func show_reach(view: LocationView, center: Vector2i, feet: int) -> void:
	if view.board == null:
		return
	var cells: Array = []
	for x in range(center.x - feet / CombatGrid.FEET, center.x + feet / CombatGrid.FEET + 1):
		for y in range(center.y - feet / CombatGrid.FEET, center.y + feet / CombatGrid.FEET + 1):
			var cell := Vector2i(x, y)
			if view.grid.in_bounds(cell) and not view.grid.has_flag(cell, CombatGrid.WALL) \
					and view.grid.distance_ft(center, 1, cell, 1) <= feet:
				cells.append(cell)
	var reach := GridOverlay.create(view.board)
	reach.name = "SearchReach"
	view.add_child(reach)
	reach.show_cells("area", cells)
	var layer := reach.get_node("Layer_area") as MultiMeshInstance3D
	var mat := layer.material_override as StandardMaterial3D
	mat.albedo_color.a = REACH_ALPHA
	var tw := reach.create_tween()
	tw.tween_interval(REACH_SHOWN * 0.4)
	tw.tween_property(mat, "albedo_color:a", 0.0, REACH_SHOWN * 0.6)
	tw.tween_callback(reach.queue_free)


# --- Traps in a fight (EncounterTraps) ---------------------------------------------------------------

## A fight here (LocationFights): every trap that hasn't gone off is armed in it, found or not.
static func into_fight(view: LocationView, e: Encounter) -> void:
	var states := view.st.loc_state(view.loc_id)["traps"] as Dictionary
	for t: Variant in view.loc.get("traps", []):
		var trap := t as Dictionary
		var state := str(states.get(str(trap["id"]), ""))
		if state in ["disarmed", "triggered"] or not StoryConditions.check(str(trap.get("when", "")), view.st):
			continue
		if _hangs(view, str(trap["id"])):
			continue   # a chandelier that is a trap is a thing in the fight (BattleScenery): break its chain to drop it
		e.traps.add(trap, state == "found")


## Whether a hanging prop (a chandelier) is this trap.
static func _hangs(view: LocationView, id: String) -> bool:
	for p: Variant in view.loc.get("props", []):
		if str(((p as Dictionary).get("hangs", {}) as Dictionary).get("trap", "")) == id:
			return true
	return false


## After a fight here: the traps that went off in it are spent, as if sprung outside one (a pit stays open).
static func after_fight(view: LocationView, e: Encounter) -> void:
	var states := view.st.loc_state(view.loc_id)["traps"] as Dictionary
	for id in e.traps.sprung_ids():
		states[id] = "triggered"
		BattleScenery.trap_sprung(view, id)
		_clear_marks(view, id)
		for t: Variant in view.loc.get("traps", []):
			var trap := t as Dictionary
			if str(trap["id"]) != id:
				continue
			if trap.has("flag"):
				view.st.set_flag(str(trap["flag"]))
			if PitFall.is_pit(trap):
				PitFall._redress(view, trap)
