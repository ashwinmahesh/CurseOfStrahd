class_name LocationInteraction
extends RefCounted
## Using things in a location (LocationView): what the mouse points at, a click (walk there, or walk up to the
## thing and use it), the right-click menu and its choices, Look, containers and their loot, and props (books, levers,
## things to examine).


## The right-click menu for a square (plan §5.6): {title, actions: [{id, label, enabled, why}]}. Party members get
## Lead / Character / Inventory (the game root opens those screens); things get their verbs (Talk, Open, Pick the
## lock, Force it, Use the key, Disarm, Read, Pull, Go ...) plus Look; bare floor gets Walk here and Search here.
static func actions_at(view: LocationView, cell: Vector2i) -> Dictionary:
	var out: Array[Dictionary] = []
	for i in view.members.size():
		if view.members[i].cell == cell:
			var ch := view.members[i].creature as Character
			# Party members share squares outside a fight, so the leader can walk onto anyone's.
			if i != 0:
				out.append({"id": "walk", "label": "Walk here"})
			out.append({"id": "lead:%d" % i, "label": "Lead the party", "enabled": i != 0 and ch.hp > 0,
				"why": "Already leading" if i == 0 else ("Can't lead while down" if ch.hp <= 0 else "")})
			out.append({"id": "sheet:%d" % i, "label": "Character sheet"})
			out.append({"id": "inventory:%d" % i, "label": "Inventory"})
			out.append({"id": "spells:%d" % i, "label": "Cast a spell...", "enabled": not ch.known_spells().is_empty(),
				"why": "" if not ch.known_spells().is_empty() else "No spells"})
			if ch.hp <= 0 and not ch.dead:
				out.append_array(LocationCare._tend_actions(view, ch))
			out.append_array(LocationCare._lay_on_hands_actions(view, ch))
			out.append_array(PitFall.actions_for(view, view.members[i]))
			return {"title": ch.name, "actions": out}
	var thing := thing_at(view, cell)
	if thing.is_empty():
		if view.grid.in_bounds(cell) and not view.grid.is_solid(cell):
			out.append({"id": "walk", "label": "Walk here"})
			out.append({"id": "search_here", "label": "Search here (Perception)"})
		return {"title": "", "actions": out}
	var spec := thing["spec"] as Dictionary
	var title := str(thing["label"]).get_slice(" ", 0)
	match str(thing["kind"]):
		"npc":
			var npc := Compendium.shared().get_entry("npcs", str(spec["npc"]))
			title = str(npc.get("name", spec["npc"]))
			out.append({"id": "talk", "label": "Talk", "enabled": str(spec.get("dialogue", "")) != "",
				"why": "" if str(spec.get("dialogue", "")) != "" else "Nothing to say"})
			if npc.has("shop"):
				var closed := str((npc["shop"] as Dictionary).get("closed", ""))
				var open := closed == "" or not StoryConditions.check(closed, view.st)
				out.append({"id": "trade", "label": "Trade", "enabled": open, "why": "" if open else "Closed for now"})
			out.append({"id": "walk", "label": "Walk over"})
		"door", "container":
			title = str(spec.get("label", "the door" if str(thing["kind"]) == "door" else "the chest")).capitalize()
			var verb := "Open" if str(thing["kind"]) == "door" else "Open and look inside"
			if str(thing["kind"]) == "door" and not StoryConditions.check(str(spec.get("when", "")), view.st):
				out.append({"id": "open", "label": verb, "enabled": false, "why": "It won't budge"})
			elif view._locked(spec):
				var ways := LocationLocks.actions_to_unlock(view, spec)
				out.append_array(ways)
				if ways.is_empty():
					out.append({"id": "open", "label": verb, "enabled": false, "why": "Locked; it needs its key"})
			else:
				out.append({"id": "open", "label": verb})
		"prop":
			title = str(spec.get("label", "it")).capitalize()
			out.append({"id": "use", "label": str(thing["label"]).get_slice(" ", 0)})
		"trap":
			title = str(spec.get("label", "a trap")).capitalize()
			var who := LocationLocks._lock_picker(view)
			if who != null:
				var adv2: Array[String] = []
				out.append({"id": "disarm", "label": "Disarm (%s, %s)" % [who.name.get_slice(" ", 0), LocationView._pick_bonus(who, adv2).signed()]})
			else:
				out.append({"id": "disarm", "label": "Disarm", "enabled": false, "why": "Nobody has thieves' tools"})
			out.append({"id": "avoid", "label": "Walk around it (the party already does)", "enabled": false})
		"foe":
			# A foe waiting in plain view (LocationStealth): the party can open the fight from where it stands.
			title = str(thing["name"])
			out.append({"id": "strike", "label": "Attack: start the fight%s" % (" (sneaking: Surprise)" if view.sneaking else "")})
		"exit":
			title = str(spec.get("label", "The way on"))
			var open := StoryConditions.check(str(spec.get("when", "")), view.st)
			out.append({"id": "go", "label": "Go: %s" % Compendium.shared().get_entry("locations", str(spec["to"])).get("name", spec["to"]),
				"enabled": open, "why": "" if open else str(spec.get("locked_text", "The way is barred."))})
	out.append({"id": "look", "label": "Look"})
	return {"title": title, "actions": out}


## Does a right-click menu choice for `cell` (party-member ids are the game root's). Walks next to things first.
static func act(view: LocationView, cell: Vector2i, action_id: String) -> void:
	if view.busy or view.in_combat or view.members.is_empty():
		return
	if action_id in ["stabilize", "kit"] or action_id.begins_with("potion:"):
		LocationCare._tend(view, cell, action_id)
		return
	if action_id.begins_with("loh:"):
		LocationCare._lay_on_hands_out(view, cell, action_id.substr(4))
		return
	var thing := thing_at(view, cell)
	match action_id:
		"walk":
			# Up to someone in the world (an NPC): stop beside them rather than on them.
			if not thing.is_empty() and str(thing["kind"]) == "npc":
				var beside := _adjacent_free(view, cell)
				if beside != Vector2i(-1, -1):
					view.walk_to(beside)
				return
			view.walk_to(cell)
			return
		"search_here":
			view.walk_to(cell, view.search)
			return
		"look":
			_look(view, cell, thing)
			return
		"go":
			view.walk_to(cell)
			return
		"climb":
			PitFall.climb_out(view, cell)
			return
		"strike":
			if not thing.is_empty() and str(thing["kind"]) == "foe":
				view.strike(str(thing["id"]))
			return
	if thing.is_empty():
		return
	var spec := thing["spec"] as Dictionary
	var then := Callable()
	match action_id:
		"talk", "use", "open":
			then = func() -> void: interact(view, thing)
		"key", "pick", "force", "knock", "chime", "mystery_key":
			if str(thing["kind"]) == "door":
				then = func() -> void: LocationLocks._use_door(view, spec, action_id)
			else:
				then = func() -> void: _use_container(view, spec, action_id)
		"disarm":
			then = func() -> void: LocationTraps._disarm(view, spec)
	if not then.is_valid():
		return
	var stand := _adjacent_free(view, cell)
	if stand == Vector2i(-1, -1):
		view.toast.emit("Can't reach it")
	elif stand == view.leader().cell:
		then.call()
	else:
		view.walk_to(stand, then)


## "Look": what the party can tell at a glance, without walking over.
static func _look(view: LocationView, cell: Vector2i, thing: Dictionary) -> void:
	if thing.is_empty():
		view.narration.emit("Nothing there but %s." % ("floor" if not view.grid.is_solid(cell) else "wall"))
		return
	var spec := thing["spec"] as Dictionary
	match str(thing["kind"]):
		"npc":
			var npc := Compendium.shared().get_entry("npcs", str(spec["npc"]))
			var att := view.st.attitude(str(spec["npc"]))
			view.narration.emit("%s%s. %s%s" % [npc.get("name", spec["npc"]), (", " + str(npc["title"])) if str(npc.get("title", "")) != "" else "",
				str(npc.get("summary", "")), (" (%s)" % att) if att != "" else ""])
		"door", "container":
			var state := "locked" if view._locked(spec) else "unlocked"
			if str(thing["kind"]) == "container" and bool((view.st.loc_state(view.loc_id)["looted"] as Dictionary).get(str(spec["id"]), false)):
				state = "empty"
			view.narration.emit("%s: %s." % [str(spec.get("label", "It")).capitalize(), state])
		"trap":
			var save := spec.get("save", {}) as Dictionary
			view.narration.emit("%s. Springing it means a %s saving throw%s." % [str(spec.get("label", "A trap")).capitalize(),
				Creature.ABILITY_NAMES.get(StringName(str(save.get("ability", "dex"))), "Dexterity"),
				(" and %s damage" % spec["damage"]) if spec.has("damage") else ""])
		"exit":
			view.narration.emit("%s, to %s." % [spec.get("label", "A way on"), Compendium.shared().get_entry("locations", str(spec["to"])).get("name", spec["to"])])
		"foe":
			view.narration.emit("%s. It hasn't seen you yet." % str(thing["name"]))
		_:
			if not view._say("look:" + str(spec.get("id", "")), view.leader().creature as Character):
				view.narration.emit(str(spec.get("label", "Something")).capitalize() + ".")


## The square the mouse points at (owner report 2026-10-06): a person, prop, chest, door or way out drawn there
## first, nearest the camera, since the top of a tall piece lies over the squares behind it; else the floor.
static func pick_cell(view: LocationView, camera: Camera3D, screen: Vector2) -> Vector2i:
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	var best := INF
	var cell := Vector2i(-1, -1)
	for entry: Array in _pickables(view):
		var t := SpritePick.hit(entry[0] as Node3D, camera, origin, dir)
		if t < best:
			best = t
			cell = entry[1] as Vector2i
	return cell if cell.x >= 0 else GridPick.cell_under(camera, view.grid, screen)


## [node, cell] for everything drawn that the mouse can point at.
static func _pickables(view: LocationView) -> Array:
	var out: Array = []
	for m: Combatant in view.members + view.guest_members:
		if view.tokens.has(m.id):
			out.append([view.tokens[m.id], m.cell])
	for w in view.waiting:
		if LocationStealth.is_shown(w):
			out.append([w["token"], (w["foe"] as Combatant).cell])
	# Nothing in an area the party hasn't found yet can be hovered or clicked (HiddenAreas).
	for shown in view._npc_shown:
		if not HiddenAreas.hides(view, shown["cell"] as Vector2i):
			out.append([shown["token"], shown["cell"]])
	for key: String in ["props", "containers", "doors", "exits"]:
		var nodes := {"props": view.prop_nodes, "containers": view.container_nodes, "doors": view.door_nodes, "exits": view.exit_nodes}[key] as Dictionary
		for t: Variant in view.loc.get(key, []):
			var spec := t as Dictionary
			var node := nodes.get(str(spec.get("id", "")), null) as Node3D
			if node != null and is_instance_valid(node) and not HiddenAreas.hides(view, LocationView._cell(spec["cell"])):
				out.append([node, LocationView._cell(spec["cell"])])
	return out


## What's at a square for the hover hint and clicks: {kind, id, label} or {}.
static func thing_at(view: LocationView, cell: Vector2i) -> Dictionary:
	if HiddenAreas.hides(view, cell):
		return {}
	var w := LocationStealth.foe_at(view, cell)
	if not w.is_empty():
		var foe := w["foe"] as Combatant
		return {"kind": "foe", "id": str(w["encounter"]), "name": foe.name(), "label": "Attack %s" % foe.name(), "spec": {"cell": [foe.cell.x, foe.cell.y]}}
	for shown in view._npc_shown:
		var spec := shown["spec"] as Dictionary
		if shown["cell"] == cell:
			var npc := Compendium.shared().get_entry("npcs", str(spec["npc"]))
			return {"kind": "npc", "id": str(spec["npc"]), "label": "Talk to %s" % npc.get("name", spec["npc"]), "spec": spec}
	for d: Variant in view.loc.get("doors", []):
		var door := d as Dictionary
		if LocationView._cell(door["cell"]) == cell and (view.door_nodes[str(door["id"])] as Node3D).visible:
			var secret := int(door.get("secret_dc", 0)) > 0 and not bool((view.st.loc_state(view.loc_id)["found"] as Dictionary).get(str(door["id"]), false))
			if secret:
				return {}
			return {"kind": "door", "id": str(door["id"]), "label": "Open %s%s" % [door.get("label", "the door"), " (locked)" if view._locked(door) else ""], "spec": door}
	for c: Variant in view.loc.get("containers", []):
		var ct := c as Dictionary
		if LocationView._cell(ct["cell"]) == cell and view.container_nodes.has(str(ct["id"])):
			return {"kind": "container", "id": str(ct["id"]), "label": "Open %s%s" % [ct.get("label", "the chest"), " (locked)" if view._locked(ct) else ""], "spec": ct}
	for p: Variant in view.loc.get("props", []):
		var prop := p as Dictionary
		if LocationView._cell(prop["cell"]) == cell and view.prop_nodes.has(str(prop["id"])):
			var verb := {"examine": "Examine", "book": "Read", "search": "Search", "lever": "Pull", "decor": "Look at"}.get(str(prop["kind"]), "Examine") as String
			return {"kind": "prop", "id": str(prop["id"]), "label": "%s %s" % [verb, prop.get("label", "it")], "spec": prop}
	for t: Variant in view.loc.get("traps", []):
		var trap := t as Dictionary
		if str((view.st.loc_state(view.loc_id)["traps"] as Dictionary).get(str(trap["id"]), "")) == "found":
			for tc: Variant in trap["cells"]:
				if LocationView._cell(tc) == cell:
					return {"kind": "trap", "id": str(trap["id"]), "label": "Disarm %s" % trap.get("label", "the trap"), "spec": trap}
	for ex: Variant in view.loc.get("exits", []):
		var exit := ex as Dictionary
		if LocationView._cell(exit["cell"]) == cell:
			return {"kind": "exit", "id": str(exit["id"]), "label": str(exit.get("label", "Leave")), "spec": exit}
	return {}


## Clicking a square: walk there, or walk next to the thing there and use it.
static func click(view: LocationView, cell: Vector2i) -> void:
	if view.busy or view.in_combat or view.members.is_empty():
		return
	var thing := thing_at(view, cell)
	if thing.is_empty() or str(thing["kind"]) == "exit":
		view.walk_to(cell)
		return
	if str(thing["kind"]) == "foe" and view.planning:
		view.strike(str(thing["id"]))   # turn-based: the party is placed, and a click on a foe opens the fight
		return
	var stand := _adjacent_free(view, cell)
	if stand == Vector2i(-1, -1):
		view.toast.emit("Can't reach it")
		return
	if stand == view.leader().cell:
		interact(view, thing)
	else:
		view.walk_to(stand, func() -> void: interact(view, thing))


static func _adjacent_free(view: LocationView, cell: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_len := 1 << 30
	for d in CombatGrid.DIRS:
		var c := cell + d
		if not view.grid.in_bounds(c) or view.grid.is_solid(c):
			continue
		if c == view.leader().cell:
			return c
		var p := view._path(view.leader().cell, c)
		if not p.is_empty() and p.size() < best_len:
			best_len = p.size()
			best = c
	return best


static func interact(view: LocationView, thing: Dictionary) -> void:
	var spec := thing["spec"] as Dictionary
	var who := view.leader()
	(view.tokens[who.id] as CombatToken).face(Vector2(LocationView._cell(spec.get("cell", [who.cell.x, who.cell.y])) - who.cell), false)
	match str(thing["kind"]):
		"npc":
			view.dialogue_requested.emit(str(spec.get("dialogue", "")), str(spec["npc"]))
		"door":
			LocationLocks._use_door(view, spec)
		"container":
			_use_container(view, spec)
		"prop":
			_use_prop(view, spec)
		"trap":
			LocationTraps._disarm(view, spec)
		"foe":
			view.strike(str(thing["id"]))


static func _use_container(view: LocationView, ct: Dictionary, method: String = "auto") -> void:
	var id := str(ct["id"])
	if view._locked(ct) and not LocationLocks._unlock(view, ct, method):
		return
	view._say("open:" + id)
	if view._trigger_encounter("open:" + id):
		return
	var looted := view.st.loc_state(view.loc_id)["looted"] as Dictionary
	if bool(looted.get(id, false)):
		view.toast.emit("Empty")
		return
	if ct.has("flag"):
		view.st.set_flag(str(ct["flag"]))
	var left := (view.st.loc_state(view.loc_id).get("contents", {}) as Dictionary).get(id, {}) as Dictionary
	var items := (left["items"] as Array).duplicate(true) if not left.is_empty() else (ct.get("items", []) as Array).duplicate(true)
	if left.is_empty():
		# Scrolls name their spell, and this playthrough's random magic items are in here too (story/treasure.gd).
		items = Treasure.specify_scrolls(items, view.st, "%s:%s" % [view.loc_id, id])
		items.append_array(((Treasure.placed(view.st, view.loc_id).get(id, []) as Array)).duplicate(true))
	# A Tarokka treasure spot (ADR 0011): whatever the reading hid here is in the chest too.
	for treasure in Tarokka.take_from(Tarokka.place_for(view.loc, "container", id), view.st):
		items.append({"id": treasure, "qty": 1})
	view.loot_opened.emit(id, items, float(left["gold"]) if not left.is_empty() else float(ct.get("gold", 0)))


## Called by the loot window when everything's been taken.
static func mark_looted(view: LocationView, container_id: String) -> void:
	(view.st.loc_state(view.loc_id)["looted"] as Dictionary)[container_id] = true
	if view.container_nodes.has(container_id):
		SetDressing.mark_looted(view.container_nodes[container_id] as Node3D)


static func _use_prop(view: LocationView, prop: Dictionary) -> void:
	var id := str(prop["id"])
	var kind := str(prop["kind"])
	var used := view.st.loc_state(view.loc_id)["props"] as Dictionary
	match kind:
		"book":
			var codex := str(prop.get("codex", id))
			if not codex in view.st.codex:
				view.st.codex.append(codex)
				view.toast.emit("Added to the codex: %s" % prop.get("label", id))
		"lever":
			if prop.has("flag"):
				view.st.set_flag(str(prop["flag"]), not bool(view.st.get_flag(str(prop["flag"]))))
		_:
			pass
	if prop.has("flag") and kind != "lever":
		view.st.set_flag(str(prop["flag"]))
	if prop.has("item") and not bool(used.get(id, false)):
		view.st.give_item(str(prop["item"]), 1, view.leader().creature as Character)
		view.toast.emit("%s takes %s" % [view.leader().name(), Compendium.shared().display_name("items", str(prop["item"]))])
	used[id] = true
	if str(prop.get("dialogue", "")) != "":
		view.dialogue_requested.emit(str(prop["dialogue"]), "")
		return
	var said := view._say("%s:%s" % ["search" if kind == "search" else "examine", id], view.leader().creature as Character)
	if not said and str(prop.get("text", "")) != "":
		view.narration.emit(str(prop["text"]))
	view._trigger_encounter("examine:" + id)
