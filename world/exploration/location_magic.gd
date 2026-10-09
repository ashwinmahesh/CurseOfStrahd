class_name LocationMagic
extends RefCounted
## Spells and magic items used while exploring a location (LocationView; FieldCasting.cast_utility casts them):
## Light, Knock, Detect Magic, Detect Evil and Good, Detect Poison and Disease, Find Traps and the Wand of Secrets.


## What an exploring spell does here and now (FieldCasting.cast_utility): Light lights the lantern, Detect Magic
## names the magic within 30 ft, Find Traps reveals the traps in sight within 120 ft, Knock opens the nearest lock
## within 60 ft.
static func apply_spell_effect(view: LocationView, spell_id: String) -> void:
	match spell_id:
		"light":
			view.update_daylight()
		"find_familiar":
			LocationParty.refresh_familiars(view)   # it appears beside the party and follows from now on
		"knock":
			var nearest := {}
			var nearest_ft := 61
			for list: String in ["doors", "containers"]:
				for d: Variant in view.loc.get(list, []):
					var spec := d as Dictionary
					var c := LocationView._cell(spec["cell"])
					var ft := view.grid.distance_ft(view.leader().cell, 1, c, 1)
					if ft < nearest_ft and view._locked(spec) and not view.thing_at(c).is_empty():
						nearest = spec
						nearest_ft = ft
			if nearest.is_empty():
				view.narration.emit("A loud knock echoes, but there's no lock within 60 feet.")
				return
			(view.st.loc_state(view.loc_id)["doors"] as Dictionary)[str(nearest["id"])] = "unlocked"
			Audio.sfx("unlock")
			view.toast.emit("A loud knock. Unlocked: %s." % str(nearest.get("label", "the lock")))
		"detect_magic":
			var found: Array[String] = []
			var placed := Treasure.placed(view.st, view.loc_id)
			for c: Variant in view.loc.get("containers", []):
				var ct := c as Dictionary
				if not view.container_nodes.has(str(ct["id"])) or view.grid.distance_ft(view.leader().cell, 1, LocationView._cell(ct["cell"]), 1) > 30:
					continue
				if bool((view.st.loc_state(view.loc_id)["looted"] as Dictionary).get(str(ct["id"]), false)):
					continue
				# The chest's own items and the random treasure rolled into it (story/treasure.gd).
				for it: Variant in (ct.get("items", []) as Array) + (placed.get(str(ct["id"]), []) as Array):
					if MagicItems.is_magic(Compendium.shared().item_data(str((it as Dictionary)["id"]))):
						found.append(str(ct.get("label", "a chest")))
						break
			for p: Variant in view.loc.get("props", []):
				var pr := p as Dictionary
				if bool(pr.get("magic", false)) and view.prop_nodes.has(str(pr["id"])) and view.grid.distance_ft(view.leader().cell, 1, LocationView._cell(pr["cell"]), 1) <= 30:
					found.append(str(pr.get("label", "something")))
			# A hidden find holding a magic item: the spell senses it through the plaster, but not where to look.
			var hidden := LocationTraps.hidden_within(view, view.leader().cell, 30).any(func(pr2: Dictionary) -> bool:
				return pr2.has("item") and MagicItems.is_magic(Compendium.shared().item_data(str(pr2["item"]))))
			if hidden:
				found.append("something hidden from sight")
			if not view._say("detect_magic:%s" % view.loc_id, view.leader().creature as Character):
				view.narration.emit("Magic within 30 ft: %s." % (", ".join(found) if not found.is_empty() else "nothing you can sense"))
			elif hidden:
				view.toast.emit("Detect Magic: something magical is hidden within 30 ft")
		"detect_evil_and_good":
			_detect_evil_and_good(view)
		"detect_poison_and_disease":
			_detect_poison(view)
		"secrets":
			_wand_of_secrets(view)
		"find_traps":
			var n := 0
			for t: Variant in view.loc.get("traps", []):
				var trap := t as Dictionary
				if not StoryConditions.check(str(trap.get("when", "")), view.st):
					continue
				var state := str((view.st.loc_state(view.loc_id)["traps"] as Dictionary).get(str(trap["id"]), ""))
				if state != "":
					continue
				for tc: Variant in trap["cells"]:
					if view.grid.distance_ft(view.leader().cell, 1, LocationView._cell(tc), 1) <= 120 and view.grid.can_see(view.leader().cell, 1, LocationView._cell(tc), 1):
						(view.st.loc_state(view.loc_id)["traps"] as Dictionary)[str(trap["id"])] = "found"
						view._show_trap(trap)
						n += 1
						break
			view.narration.emit("You sense %s." % ("no traps in sight" if n == 0 else "%d trap%s" % [n, "" if n == 1 else "s"]))


## Wand of Secrets (2024 DMG): it pulses and points at the nearest secret door or trap within 30 ft, which the party
## then knows about (HiddenAreas brings a room behind a found door into view).
static func _wand_of_secrets(view: LocationView) -> void:
	var c := view.leader().cell
	var states := view.st.loc_state(view.loc_id)
	var best := {}
	var best_kind := ""
	var best_ft := 31
	for d: Variant in view.loc.get("doors", []):
		var door := d as Dictionary
		if int(door.get("secret_dc", 0)) <= 0 or bool((states["found"] as Dictionary).get(str(door["id"]), false)):
			continue
		var ft := view.grid.distance_ft(c, 1, LocationView._cell(door["cell"]), 1)
		if ft < best_ft:
			best = door
			best_kind = "door"
			best_ft = ft
	for t: Variant in view.loc.get("traps", []):
		var trap := t as Dictionary
		if str((states["traps"] as Dictionary).get(str(trap["id"]), "")) != "" or not StoryConditions.check(str(trap.get("when", "")), view.st):
			continue
		for tc: Variant in trap["cells"]:
			var ft2 := view.grid.distance_ft(c, 1, LocationView._cell(tc), 1)
			if ft2 < best_ft:
				best = trap
				best_kind = "trap"
				best_ft = ft2
	if best.is_empty():
		view.narration.emit("The wand stays still: no secret door or trap within 30 feet.")
		return
	if best_kind == "door":
		(states["found"] as Dictionary)[str(best["id"])] = true
		if view.door_nodes.has(str(best["id"])):
			SetDressing.reveal_door(view.door_nodes[str(best["id"])] as Node3D)
	else:
		(states["traps"] as Dictionary)[str(best["id"])] = "found"
		view._show_trap(best)
		if best.has("flag"):
			view.st.set_flag(str(best["flag"]))
	var label := str(best.get("label", "a hidden door" if best_kind == "door" else "a trap"))
	view.narration.emit("The wand pulses and points %d feet away: %s." % [best_ft, label])
	view.toast.emit("Found: " + label)


# --- Detect Evil and Good, Detect Poison and Disease ---------------------------------------------------------------

const SENSED_TYPES := {"aberration": ["an Aberration", "Aberrations"], "celestial": ["a Celestial", "Celestials"],
	"elemental": ["an Elemental", "Elementals"], "fey": ["a Fey", "Fey"], "fiend": ["a Fiend", "Fiends"],
	"undead": ["an Undead", "Undead"]}
## Poisons a container or a pack can hold (a Potion of Poison passes for a Potion of Healing until it's found out).
const POISONS := ["basic_poison", "potion_of_poison"]


## The creatures here within 30 ft of the party's leader: the people standing about, and the foes of fights still to
## come that are already in place (stepping into an area or opening something starts them: waiting, lurking, buried or
## shut in a coffin; a fight a flag or a conversation starts may be an arrival, so it isn't sensed yet).
## [{creature, cell, seen}]
static func _creatures_near(view: LocationView) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var at := view.leader().cell
	for npc_id: String in view.npc_tokens:
		var cb := (view.npc_tokens[npc_id] as CombatToken).combatant
		if cb != null and view.grid.distance_ft(at, 1, cb.cell, 1) <= 30:
			out.append({"creature": cb.creature, "cell": cb.cell, "seen": view.grid.can_see(at, 1, cb.cell, 1)})
	var done := view.st.loc_state(view.loc_id)["encounters"] as Dictionary
	var ids := {}
	for en: Variant in view.loc.get("encounters", []):
		ids[str((en as Dictionary)["id"])] = true
	for id: String in ids:
		var spec := LocationFights.spec_for(view, id)
		var trigger := str(spec["trigger"])
		if done.has(id) or not (trigger.begins_with("enter_area:") or trigger.begins_with("open:")) \
				or not StoryConditions.check(StoryConditions.encounter_when(spec), view.st):
			continue
		for m: Dictionary in LocationFights.monsters_for(view, spec):
			var cell := m["cell"] as Vector2i
			if view.grid.distance_ft(at, 1, cell, 1) <= 30:
				out.append({"creature": m["creature"], "cell": cell, "seen": view.grid.can_see(at, 1, cell, 1)})
	return out


## Detect Evil and Good (2024): where each Aberration, Celestial, Elemental, Fey, Fiend and Undead within 30 ft is, at
## the moment of casting: one in sight by name (a disguised Night Hag shows what she is), the rest counted by kind.
static func _detect_evil_and_good(view: LocationView) -> void:
	var found: Array[String] = []
	var unseen := {}
	for near in _creatures_near(view):
		var cr := near["creature"] as Creature
		var kind := str(cr.creature_type)
		if not SENSED_TYPES.has(kind):
			continue
		if bool(near["seen"]):
			found.append("%s (%s)" % [cr.name, kind.capitalize()])
		else:
			unseen[kind] = int(unseen.get(kind, 0)) + 1
	for kind: String in unseen:
		var n := int(unseen[kind])
		found.append("%s out of sight" % (SENSED_TYPES[kind][0] if n == 1 else "%d %s" % [n, SENSED_TYPES[kind][1]]))
	if found.is_empty():
		view.narration.emit("Within 30 ft you sense no Aberration, Celestial, Elemental, Fey, Fiend or Undead.")
	else:
		view.narration.emit("Within 30 ft you sense: %s." % ", ".join(found))


static func _is_poison(item_id: String) -> bool:
	return item_id in POISONS


## A creature whose attacks carry poison or leave a target Poisoned (a Giant Spider's bite).
static func _venomous(cr: Creature) -> bool:
	if not cr is Monster:
		return false
	var d := (cr as Monster).data
	var acts := JSON.stringify([d.get("actions", []), d.get("bonus_actions", []), d.get("reactions", [])])
	return "\"type\":\"poison\"" in acts or "\"condition\":\"poisoned\"" in acts


## Detect Poison and Disease (2024): the poisons and venomous creatures within 30 ft, and what each is, at the moment
## of casting. A poison in a chest or on someone in the party is named (a Potion of Poison is found out: it's
## identified), one hidden from sight isn't placed, and a poison trap is found as Find Traps finds one.
static func _detect_poison(view: LocationView) -> void:
	var found: Array[String] = []
	var at := view.leader().cell
	var comp := Compendium.shared()
	var placed := Treasure.placed(view.st, view.loc_id)
	for c: Variant in view.loc.get("containers", []):
		var ct := c as Dictionary
		if not view.container_nodes.has(str(ct["id"])) or view.grid.distance_ft(at, 1, LocationView._cell(ct["cell"]), 1) > 30:
			continue
		if bool((view.st.loc_state(view.loc_id)["looted"] as Dictionary).get(str(ct["id"]), false)):
			continue
		for it: Variant in (ct.get("items", []) as Array) + (placed.get(str(ct["id"]), []) as Array):
			var iid := str((it as Dictionary)["id"])
			if _is_poison(iid):
				found.append("%s in %s" % [str(comp.item_data(iid).get("name", iid)), str(ct.get("label", "a chest"))])
	if LocationTraps.hidden_within(view, at, 30).any(func(pr: Dictionary) -> bool: return _is_poison(str(pr.get("item", "")))):
		found.append("poison hidden from sight")
	for ch: Character in view.st.party:
		if ch.dead:
			continue
		for e: Dictionary in ch.inventory:
			var iid := str(e["id"])
			var data := comp.item_data(iid)
			if _is_poison(iid) and int(e.get("qty", 0)) > 0 and MagicItems.is_disguised(data, e):
				var looked := MagicItems.display_name(data, e)
				e["identified"] = true
				found.append("%s's %s: a %s" % [ch.name.get_slice(" ", 0), looked, str(data.get("name", iid))])
	for near in _creatures_near(view):
		var cr := near["creature"] as Creature
		if _venomous(cr):
			var kind := str(((cr as Monster).data).get("name", cr.name))
			found.append("%s (venomous)" % cr.name if bool(near["seen"]) else "a venomous %s out of sight" % kind)
	var states := view.st.loc_state(view.loc_id)
	for t: Variant in view.loc.get("traps", []):
		var trap := t as Dictionary
		if str(trap.get("damage_type", "")) != "poison" and str(trap.get("condition", "")) != "poisoned":
			continue
		if str((states["traps"] as Dictionary).get(str(trap["id"]), "")) != "" or not StoryConditions.check(str(trap.get("when", "")), view.st):
			continue
		if (trap["cells"] as Array).any(func(tc: Variant) -> bool: return view.grid.distance_ft(at, 1, LocationView._cell(tc), 1) <= 30):
			(states["traps"] as Dictionary)[str(trap["id"])] = "found"
			view._show_trap(trap)
			if trap.has("flag"):
				view.st.set_flag(str(trap["flag"]))
			found.append("a poison trap: %s" % str(trap.get("label", "a trap")))
	if found.is_empty():
		view.narration.emit("Within 30 ft you sense no poison and nothing venomous.")
	else:
		view.narration.emit("Within 30 ft you sense: %s." % ", ".join(found))
