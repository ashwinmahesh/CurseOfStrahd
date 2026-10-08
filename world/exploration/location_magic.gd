class_name LocationMagic
extends RefCounted
## Spells and magic items used while exploring a location (LocationView; FieldCasting.cast_utility casts them):
## Light, Knock, Detect Magic, Find Traps and the Wand of Secrets.


## What an exploring spell does here and now (FieldCasting.cast_utility): Light lights the lantern, Detect Magic
## names the magic within 30 ft, Find Traps reveals the traps in sight within 120 ft, Knock opens the nearest lock
## within 60 ft.
static func apply_spell_effect(view: LocationView, spell_id: String) -> void:
	match spell_id:
		"light":
			view.update_daylight()
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
