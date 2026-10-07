class_name EncounterSnapshot
extends RefCounted
## Saving a fight at the start of a round (plan §10 Phase 3: "save and load ... at the start of each combat round"):
## every combatant (characters in full, monsters by stat block plus their state), positions, Initiative order, the
## round, marks, grapples and what the party has studied, and the map as it stood. Restored, the round begins again
## from its first turn.


static func capture(e: Encounter) -> Dictionary:
	var cbs: Array = []
	for c in e.combatants:
		var cd := {"id": c.id, "side": str(c.side), "cell": [c.cell.x, c.cell.y], "initiative": c.initiative,
			"group": c.initiative_group, "surprised": c.surprised, "reaction_rules": c.reaction_rules.duplicate(),
			"reaction_available": c.reaction_available, "hidden": c.hidden, "stealth_total": c.stealth_total}
		if c.creature is Character:
			cd["character"] = (c.creature as Character).to_dict()
		else:
			var m := c.creature as Monster
			cd["monster"] = str(m.data.get("id", ""))
			cd["name"] = m.name
			cd["state"] = m.state_to_dict()
			# A fight can set a monster's Hit Point maximum apart from its stat block (a tougher spawn).
			cd["hp_max_base"] = m.hp_max_base
			# Summoned creatures' stat blocks are built when they're cast (Summon Fey), so they travel with the save.
			if Compendium.shared().monster_data(str(m.data.get("id", ""))).is_empty() or m.data.has("shape_of"):
				cd["monster_data"] = m.data.duplicate(true)
		# Feature and monster state kept on the combatant (Portent's dice, a werewolf's form, Recharge, a severed part).
		var metas := {}
		for k: StringName in c.get_meta_list():
			var v: Variant = c.get_meta(k)
			if v is int or v is float or v is String or v is bool or v is Array or v is Dictionary:
				metas[str(k)] = v
		cd["meta"] = metas
		cd["size_cells"] = c.size_cells
		cd["controller"] = str(c.controller)
		cd["has_acted"] = c.has_acted
		cbs.append(cd)
	var order: Array = []
	for c in e.order:
		order.append(c.id)
	var rows: Array = []
	for z in e.grid.depth:
		var row := ""
		for x in e.grid.width:
			var cell := Vector2i(x, z)
			if e.grid.has_flag(cell, CombatGrid.VOID):
				row += " "
			elif e.grid.has_flag(cell, CombatGrid.WALL):
				row += "#"
			elif e.grid.has_flag(cell, CombatGrid.LOW):
				row += "="
			elif e.grid.has_flag(cell, CombatGrid.DIFFICULT):
				row += "~"
			elif e.grid.height(cell) > 0:
				row += str(mini(4, e.grid.height(cell) / CombatGrid.FEET))
			else:
				row += "."
		rows.append(row)
	var log: Array = []
	for en in e.log.last(40):
		log.append(en.duplicate(true))
	return {"version": 1, "rows": rows, "combatants": cbs, "order": order, "round": e.round_no, "marks": e.marks.duplicate(true),
		"grapples": e.grapples.duplicate(), "studied": e.studied.duplicate(), "title": e.title, "log": log,
		"spells": e.spells.to_dict(), "shapes": e.shapes.to_dict(), "light": e.ambient_light, "sunlit": e.sunlit,
		"location_id": e.location_id, "places": e.places.duplicate(), "lair": e.lair, "outdoors": e.outdoors, "boss": e.legendary.to_dict()}


## Rebuilds the fight; `party` supplies the party's Character objects (from the loaded story) by id when present.
static func restore(d: Dictionary, dice: DiceRoller, party: Array[Character] = []) -> Encounter:
	var e := Encounter.new(CombatGrid.from_rows(d["rows"] as Array), dice)
	e.title = str(d.get("title", ""))
	var by_id := {}
	for ch in party:
		by_id[ch.id] = ch
	var saved := {}
	var loaded: Array[Creature] = []
	for cdv: Variant in d["combatants"]:
		var cd := cdv as Dictionary
		var creature: Creature
		if cd.has("character"):
			var cid := str((cd["character"] as Dictionary).get("id", ""))
			creature = by_id[cid] as Character if by_id.has(cid) else Character.from_dict(cd["character"] as Dictionary)
			if by_id.has(cid):
				creature.state_from_dict((cd["character"] as Dictionary)["state"] as Dictionary)
			saved[cid] = (cd["character"] as Dictionary)["state"]
		else:
			var mdata := cd["monster_data"] as Dictionary if cd.has("monster_data") else Compendium.shared().monster_data(str(cd["monster"]))
			var m := Monster.from_data(mdata)
			m.name = str(cd["name"])
			m.hp_max_base = int(cd.get("hp_max_base", m.hp_max_base))
			m.state_from_dict(cd["state"] as Dictionary)
			creature = m
		var a := cd["cell"] as Array
		var c := e.add(creature, StringName(str(cd["side"])), Vector2i(int(a[0]), int(a[1])))
		c.id = str(cd["id"])
		creature.id = c.id
		if not cd.has("character"):
			saved[c.id] = cd["state"]
		c.initiative = int(cd["initiative"])
		c.initiative_group = str(cd["group"])
		c.surprised = bool(cd["surprised"])
		c.reaction_rules = (cd.get("reaction_rules", {}) as Dictionary).duplicate()
		c.reaction_available = bool(cd.get("reaction_available", true))
		c.hidden = bool(cd.get("hidden", false))
		c.stealth_total = int(cd.get("stealth_total", 0))
		var metas := cd.get("meta", {}) as Dictionary
		for k: String in metas:
			c.set_meta(k, metas[k])
		c.size_cells = int(cd.get("size_cells", c.size_cells))
		c.controller = StringName(str(cd.get("controller", str(c.controller))))
		c.has_acted = bool(cd.get("has_acted", false))
		loaded.append(creature)
	e.shapes.from_dict(d.get("shapes", {}) as Dictionary, by_id)
	Creature.relink_concentration(loaded, saved)
	e.order.clear()
	for id: Variant in d["order"]:
		var c2 := e.get_c(str(id))
		if c2 != null:
			e.order.append(c2)
	for m2: Variant in d.get("marks", []):
		e.marks.append((m2 as Dictionary).duplicate(true))
	e.grapples = (d.get("grapples", {}) as Dictionary).duplicate()
	e.studied = (d.get("studied", {}) as Dictionary).duplicate()
	for en: Variant in d.get("log", []):
		var entry := en as Dictionary
		e.log.entries.append(entry.duplicate(true))
	e.ambient_light = str(d.get("light", "bright"))
	e.sunlit = bool(d.get("sunlit", false))
	e.spells.from_dict(d.get("spells", {}) as Dictionary)
	e.location_id = str(d.get("location_id", ""))
	for pl: Variant in d.get("places", []):
		e.places.append(str(pl))
	e.lair = bool(d.get("lair", false))
	e.outdoors = bool(d.get("outdoors", false))
	e.legendary.from_dict(d.get("boss", {}) as Dictionary)
	e.legendary.after_restore()
	e.state = Encounter.State.ACTIVE
	e.round_no = int(d["round"])
	e.log.round_no = e.round_no
	e.turn_index = 0
	while e.turn_index < e.order.size() and not e.order[e.turn_index].is_alive():
		e.turn_index += 1
	e._lair_then_begin()
	return e
