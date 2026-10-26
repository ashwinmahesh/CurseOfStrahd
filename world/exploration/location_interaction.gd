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
			# At camp, the others are by the fire: walking up to them is a word with them (LocationCamp).
			var camp := LocationCamp.of(view)
			if i != 0 and camp != null and camp.who_at(cell) == ch.id:
				out.append({"id": "talk", "label": camp.label_for(ch.id)})
			# Party members share squares outside a fight, so the leader can walk onto anyone's.
			if i != 0:
				out.append({"id": "walk", "label": "Walk here"})
			out.append({"id": "lead:%d" % i, "label": "Lead the party", "enabled": i != 0 and ch.hp > 0 and not ch.dead,
				"why": "Already leading" if i == 0 else ("Dead heroes can't lead" if ch.dead else ("Can't lead while down" if ch.hp <= 0 else ""))})
			out.append({"id": "sheet:%d" % i, "label": "Character sheet"})
			out.append({"id": "inventory:%d" % i, "label": "Inventory"})
			out.append({"id": "spells:%d" % i, "label": "Cast a spell...", "enabled": not ch.known_spells().is_empty(),
				"why": "" if not ch.known_spells().is_empty() else "No spells"})
			if ch.hp <= 0 and not ch.dead:
				out.append_array(LocationCare._tend_actions(view, ch))
			out.append_array(LocationCare._lay_on_hands_actions(view, ch))
			out.append_array(PitFall.actions_for(view, view.members[i]))
			for guest_id in LocationGuests.here_with_member(view, cell):   # a guest on the same square (the line closed up)
				for a in LocationGuests.actions(view, guest_id):
					a["label"] = "%s: %s" % [GuestTalk.name_of(guest_id).get_slice(" ", 0), a["label"]]
					out.append(a)
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
		"camper":
			title = str(thing["name"])
			out.append({"id": "talk", "label": str(thing["label"])})
		"guest":
			title = str(thing["name"])
			out.append_array(LocationGuests.actions(view, str(thing["id"])))
		"npc":
			var npc := Compendium.shared().get_entry("npcs", str(spec["npc"]))
			title = str(npc.get("name", spec["npc"]))
			var lies := LocationNpcs.is_asleep(view, str(spec["npc"])) or LocationNpcs.is_lying(view, str(spec["npc"]))
			out.append({"id": "talk", "label": "Approach" if lies else "Talk", "enabled": str(spec.get("dialogue", "")) != "",
				"why": "" if str(spec.get("dialogue", "")) != "" else "Nothing to say"})
			if npc.has("shop"):
				var closed := str((npc["shop"] as Dictionary).get("closed", ""))
				var open := closed == "" or not StoryConditions.check(closed, view.st)
				# A merchant the story hasn't unlocked yet (Van Richten, the Order's armory) shows no Trade at all.
				if open or not bool((npc["shop"] as Dictionary).get("hide_closed", false)):
					out.append({"id": "trade", "label": "Trade", "enabled": open, "why": "" if open else "Closed for now"})
			if npc.has("services"):
				var rooms := (npc["services"] as Array).all(func(s: Variant) -> bool: return str((s as Dictionary)["id"]).begins_with("room_"))
				out.append({"id": "services", "label": "Rooms" if rooms else "Services"})
			out.append(LocationCrime.pickpocket_action(view, str(spec["npc"])))   # F8
			out.append({"id": "walk", "label": "Walk over"})
			out.append_array(LocationNpcs.cast_actions(view, spec))   # Sleep, Charm Person ... at them, outside a fight
		"door", "container":
			title = str(spec.get("label", "the door" if str(thing["kind"]) == "door" else "the chest")).capitalize()
			var verb := "Open" if str(thing["kind"]) == "door" else "Open and look inside" + LocationCrime.owned_note(spec)
			if str(thing["kind"]) == "door" and not StoryConditions.check(str(spec.get("when", "")), view.st):
				out.append({"id": "open", "label": verb, "enabled": false, "why": str(spec.get("locked_text", "It won't budge"))})
			elif view._locked(spec):
				var ways := LocationLocks.actions_to_unlock(view, spec)
				out.append_array(ways)
				if ways.is_empty():
					out.append({"id": "open", "label": verb, "enabled": false, "why": "Locked; it needs its key"})
			else:
				out.append({"id": "open", "label": verb})
			out.append_array(LocationChecks.actions_for(view, spec))   # skill checks on it (WorldChecks)
		"prop":
			title = str(spec.get("label", "it")).capitalize()
			out.append({"id": "use", "label": str(thing["label"]).get_slice(" ", 0)})
			out.append_array(LocationChecks.actions_for(view, spec))
		"trap":
			title = str(spec.get("label", "a trap")).capitalize()
			# Set it off on purpose, from within 5 ft or standing in it (owner, 2026-10-08); disarming is the player's choice.
			var why := LocationTraps.activate_why(view, spec)
			out.append({"id": "activate", "label": "Set it off", "enabled": why == "", "why": why})
			var who := LocationLocks._lock_picker(view)
			if who != null:
				var adv2: Array[String] = []
				out.append({"id": "disarm", "label": "Disarm (%s, %s)" % [who.name.get_slice(" ", 0), LocationView._pick_bonus(who, adv2).signed()]})
			else:
				out.append({"id": "disarm", "label": "Disarm", "enabled": false, "why": "Nobody has thieves' tools"})
		"foe":
			# A foe waiting in plain view (LocationStealth): the party can open the fight from where it stands.
			title = str(thing["name"])
			out.append({"id": "strike", "label": "Attack: start the fight%s" % (" (sneaking: Surprise)" if view.sneaking else "")})
			out.append_array(LocationNpcs.cast_actions_at_foe(view, thing))   # a spell at a foe opens the fight too
		"exit":
			title = str(spec.get("label", "The way on"))
			var open := StoryConditions.check(str(spec.get("when", "")), view.st)
			out.append({"id": "go", "label": "Go: %s" % Compendium.shared().get_entry("locations", str(spec["to"])).get("name", spec["to"]),
				"enabled": open, "why": "" if open else str(spec.get("locked_text", "The way is barred."))})
	# A piece of scenery's own first line is already "Look" (its narration): no second one.
	if not (str(thing["kind"]) == "prop" and str(thing["label"]).begins_with("Look at ")):
		out.append({"id": "look", "label": "Look"})
	return {"title": title, "actions": out}


## Does a right-click menu choice for `cell` (party-member ids are the game root's). Walks next to things first.
static func act(view: LocationView, cell: Vector2i, action_id: String) -> void:
	if view.busy or view.in_combat or view.members.is_empty():
		return
	if action_id in ["stabilize", "kit"] or action_id.begins_with("potion:"):
		LocationCare._tend(view, cell, action_id)
		return
	if action_id.begins_with("cast_at:"):
		LocationNpcs.cast_from_menu(view, cell, action_id)
		return
	if action_id.begins_with("strike_cast:"):
		LocationNpcs.strike_with_spell(view, cell, action_id)
		return
	if action_id.begins_with("loh:"):
		LocationCare._lay_on_hands_out(view, cell, action_id.substr(4))
		return
	if action_id.begins_with("guest_"):
		LocationGuests.act(view, action_id)   # Talk, Give... and Send home, for a story ally travelling with the party
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
		"activate":
			if not thing.is_empty() and str(thing["kind"]) == "trap":
				LocationTraps.activate(view, thing["spec"] as Dictionary)
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
		"pickpocket":
			then = func() -> void: LocationCrime.pickpocket(view, str(spec["npc"]))
	if action_id.begins_with("check_aid:"):
		LocationChecks.act(view, thing, action_id)   # spent on the roll just made: no walking
		return
	if action_id.begins_with("check:"):
		then = func() -> void: LocationChecks.act(view, thing, action_id)
	if not then.is_valid():
		return
	var choice := then
	then = func() -> void:
		FoundGlow.used(view, str(thing["kind"]), str(thing.get("id", "")))   # a lock tried, a trap disarmed: no glow
		choice.call()
	var stand := _adjacent_free(view, cell)
	if stand == Vector2i(-1, -1):
		if (action_id == "use" and _seen_from_afar(thing)) or action_id.begins_with("check:"):
			then.call()
		else:
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
		"npc", "guest":
			var npc := Compendium.shared().get_entry("npcs", str(spec["npc"]))
			var att := view.st.attitude(str(spec["npc"]))
			view.narration.emit("%s%s. %s%s%s" % [npc.get("name", spec["npc"]), (", " + str(npc["title"])) if str(npc.get("title", "")) != "" else "",
				str(npc.get("summary", "")), (" (%s)" % att) if att != "" else "", LocationNpcs.look_words(view, str(spec["npc"]))])
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
	return cell if cell.x >= 0 else GridPick.cell_under(camera, view.grid, screen, view.board)


## [node, cell] for everything drawn that the mouse can point at.
static func _pickables(view: LocationView) -> Array:
	var out: Array = []
	for m: Combatant in view.members + view.guest_members:
		if view.tokens.has(m.id):
			out.append([view.tokens[m.id], m.cell])
	var camp := LocationCamp.of(view)
	if camp != null:
		out.append_array(camp.pickables())   # the companions waiting at camp, by the fire
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
	var guest := LocationGuests.thing(view, cell)
	if not guest.is_empty():
		return guest
	var camp := LocationCamp.of(view)
	if camp != null and not view.in_combat:
		var who := camp.who_at(cell)
		if who != "":
			return {"kind": "camper", "id": who, "name": camp.first_name(who), "label": camp.label_for(who),
				"spec": {"id": "camp:" + who, "cell": [cell.x, cell.y], "label": "%s, by the fire" % camp.first_name(who)}}
	var w := LocationStealth.foe_at(view, cell)
	if not w.is_empty():
		var foe := w["foe"] as Combatant
		var state := LocationNpcs.state_of(foe.creature)   # what's on them shows here too (asleep, Faerie Fire ...)
		return {"kind": "foe", "id": str(w["encounter"]), "name": foe.name(), "label": "Attack %s%s" % [foe.name(), " (%s)" % state if state != "" else ""],
			"spec": {"cell": [foe.cell.x, foe.cell.y]}}
	for shown in view._npc_shown:
		var spec := shown["spec"] as Dictionary
		if shown["cell"] == cell:
			var npc := Compendium.shared().get_entry("npcs", str(spec["npc"]))
			return {"kind": "npc", "id": str(spec["npc"]), "label": LocationNpcs.hover_label(view, str(spec["npc"]), str(npc.get("name", spec["npc"]))), "spec": spec}
	for d: Variant in view.loc.get("doors", []):
		var door := d as Dictionary
		if LocationView._cell(door["cell"]) == cell and (view.door_nodes[str(door["id"])] as Node3D).visible:
			var secret := int(door.get("secret_dc", 0)) > 0 and not bool((view.st.loc_state(view.loc_id)["found"] as Dictionary).get(str(door["id"]), false))
			if secret:
				return {}
			return {"kind": "door", "id": str(door["id"]), "label": "Open %s%s%s" % [door.get("label", "the door"), " (locked)" if view._locked(door) else "",
				LocationChecks.hint(view, door)], "spec": door}
	for c: Variant in view.loc.get("containers", []):
		var ct := c as Dictionary
		if LocationView._cell(ct["cell"]) == cell and view.container_nodes.has(str(ct["id"])):
			return {"kind": "container", "id": str(ct["id"]), "label": "Open %s%s%s%s%s" % [ct.get("label", "the chest"), " (locked)" if view._locked(ct) else "",
				LocationCrime.owned_note(ct), LocationStealth.guarded_note(view, ct), LocationChecks.hint(view, ct)], "spec": ct}
	for p: Variant in view.loc.get("props", []):
		var prop := p as Dictionary
		if LocationView._cell(prop["cell"]) == cell and view.prop_nodes.has(str(prop["id"])):
			var verb := {"examine": "Examine", "book": "Read", "search": "Search", "lever": "Pull", "decor": "Look at"}.get(str(prop["kind"]), "Examine") as String
			return {"kind": "prop", "id": str(prop["id"]), "label": "%s %s%s" % [verb, prop_name(prop), LocationChecks.hint(view, prop)], "spec": prop}
	for t: Variant in view.loc.get("traps", []):
		var trap := t as Dictionary
		if str((view.st.loc_state(view.loc_id)["traps"] as Dictionary).get(str(trap["id"]), "")) == "found":
			for tc: Variant in trap["cells"]:
				if LocationView._cell(tc) == cell:
					return {"kind": "trap", "id": str(trap["id"]), "label": str(trap.get("label", "a trap")).capitalize(), "spec": trap}
	for ex: Variant in view.loc.get("exits", []):
		var exit := ex as Dictionary
		if LocationView._cell(exit["cell"]) == cell:
			return {"kind": "exit", "id": str(exit["id"]), "label": str(exit.get("label", "Leave")), "spec": exit}
	return {}


## Models whose id doesn't read as a name.
const MODEL_NAMES := {"grave_open": "the open grave", "bone_scatter": "the scattered bones", "candle_cluster": "the candles",
	"pine_clawed": "the clawed pine", "tub_wooden": "the wooden tub", "dead_tree": "the dead tree"}


## A prop's name in its menu and name plate: its own label, else what its model is ("the fishing nets"); a decor prop
## with neither said "Look at it" (Storyline QA via UI QA, 2026-10-08: the garden bed, the stacked casks).
static func prop_name(prop: Dictionary) -> String:
	if str(prop.get("label", "")) != "":
		return str(prop["label"])
	var model := str(prop.get("model", ""))
	if model == "":
		return "it"
	if MODEL_NAMES.has(model):
		return str(MODEL_NAMES[model])
	if model.length() > 2 and model[-2] == "_":
		model = model.left(-2)   # a variant: bramble_a, bramble_b
	return "the " + model.replace("_", " ")


## Clicking a square: walk there, or walk next to the thing there and use it.
static func click(view: LocationView, cell: Vector2i) -> void:
	if view.busy or view.in_combat or view.members.is_empty():
		return
	var thing := thing_at(view, cell)
	# A way out, or a trap: walk onto it (a trap isn't walked round or disarmed by a click; owner, 2026-10-08).
	if thing.is_empty() or str(thing["kind"]) in ["exit", "trap"]:
		view.walk_to(cell)
		return
	if str(thing["kind"]) == "foe" and view.planning:
		view.strike(str(thing["id"]))   # turn-based: the party is placed, and a click on a foe opens the fight
		return
	var stand := _adjacent_free(view, cell)
	if stand == Vector2i(-1, -1):
		if _seen_from_afar(thing):
			interact(view, thing)
		else:
			view.toast.emit("Can't reach it")
		return
	if stand == view.leader().cell:
		interact(view, thing)
	else:
		view.walk_to(stand, func() -> void: interact(view, thing))


## A thing the party only looks at (a prop to examine, or decor, with nothing to take, read, pull or talk at: a house
## front, a fire deep in an oven, horses behind a fence) is examined from where the party stands when no square beside
## it can be reached (Storyline QA, 2026-10-08: five such props' narration could never play). tools/data/story_reach.py
## holds everything else to be reachable.
static func _seen_from_afar(thing: Dictionary) -> bool:
	if thing.is_empty() or str(thing["kind"]) != "prop":
		return false
	var spec := thing["spec"] as Dictionary
	return str(spec.get("kind", "")) in ["examine", "decor"] and str(spec.get("dialogue", "")) == "" \
		and not spec.has("item") and not spec.has("flag")


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
	FoundGlow.used(view, str(thing["kind"]), str(thing.get("id", "")))   # used: a find's glow goes
	var who := view.leader()
	(view.tokens[who.id] as CombatToken).face(Vector2(LocationView._cell(spec.get("cell", [who.cell.x, who.cell.y])) - who.cell), false)
	match str(thing["kind"]):
		"camper":
			var camp := LocationCamp.of(view)
			if camp != null:
				camp.talk(str(thing["id"]))
		"guest":
			LocationGuests.talk(view, str(thing["id"]))
		"npc":
			if not LocationNpcs.can_talk(view, spec):
				var npc := Compendium.shared().get_entry("npcs", str(spec["npc"]))
				view.narration.emit("%s can't answer (%s)." % [str(npc.get("name", spec["npc"])), LocationNpcs.state_words(view, str(spec["npc"]))])
				return
			view.dialogue_requested.emit(str(spec.get("dialogue", "")), str(spec["npc"]))
		"door":
			LocationLocks._use_door(view, spec)
		"container":
			_use_container(view, spec)
		"prop":
			_use_prop(view, spec)
			if str(spec.get("dialogue", "")) == "":
				_check_tip(view, spec)
			else:
				_check_tip_after_talk(view, spec)
		"trap":
			LocationTraps.activate(view, spec)   # only from within 5 ft; disarming is a menu choice
		"foe":
			view.strike(str(thing["id"]))


## After using a thing that still has a skill check someone could try: how to try it (the menu's line).
static func _check_tip(view: LocationView, spec: Dictionary) -> void:
	var skills := LocationChecks.skills_offered(view, spec)
	if skills != "":
		view.toast.emit("Right-click it to try %s" % skills)


## A thing with something to say (a Speak with Dead conversation) gives the same tip once the conversation is over and
## the party is back to exploring, since the HUD's toasts are hidden while it's open (Wiki finding 79).
static func _check_tip_after_talk(view: LocationView, spec: Dictionary) -> void:
	while ModeController.mode == ModeController.Mode.DIALOGUE:
		await view.get_tree().process_frame
		if not is_instance_valid(view) or not view.is_inside_tree():
			return
	if ModeController.mode == ModeController.Mode.EXPLORATION and not view.in_combat:
		_check_tip(view, spec)


static func _use_container(view: LocationView, ct: Dictionary, method: String = "auto") -> void:
	if method == "force" and view._locked(ct):
		# Guidance can go on forcing it first (LocationLocks.with_guidance).
		LocationLocks.with_guidance(view, ct, func(extra: Array) -> void: _open_container(view, ct, method, extra))
		return
	_open_container(view, ct, method)


## Undoes the container's lock if it has one (`extra`: Guidance's die on forcing it), then opens it.
static func _open_container(view: LocationView, ct: Dictionary, method: String, extra: Array = []) -> void:
	var id := str(ct["id"])
	if view._locked(ct) and not LocationLocks._unlock(view, ct, method, extra):
		return
	view._say("open:" + id)
	if view._trigger_encounter("open:" + id):
		return
	var looted := view.st.loc_state(view.loc_id)["looted"] as Dictionary
	if bool(looted.get(id, false)):
		view.toast.emit("Empty")
		return
	if LocationStealth.guard_take(view, ct):
		return   # the foes guarding it noticed the taker: their fight starts, and nothing is taken
	if ct.has("flag"):
		view.st.set_flag(str(ct["flag"]))
	var left := (view.st.loc_state(view.loc_id).get("contents", {}) as Dictionary).get(id, {}) as Dictionary
	var items := (left["items"] as Array).duplicate(true) if not left.is_empty() else (ct.get("items", []) as Array).duplicate(true)
	if left.is_empty():
		# Scrolls name their spell, and this playthrough's random magic items are in here too (story/treasure.gd).
		items = Treasure.specify_scrolls(items, view.st, "%s:%s" % [view.loc_id, id])
		items.append_array(((Treasure.placed(view.st, view.loc_id).get(id, []) as Array)).duplicate(true))
	# A treasure spot (ADR 0011): whatever the campaign's reading hid here is in the chest too.
	for treasure in Campaign.module().take_treasure(view.loc, "container", id, view.st):
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
			var lore := view.st.add_codex(str(prop.get("codex", id)))
			if lore >= 0:
				view.toast.emit("Added to the codex: %s%s" % [prop.get("label", id), Xp.tag(lore)])
		"lever":
			Audio.sfx("lever")
			if prop.has("flag"):
				view.st.set_flag(str(prop["flag"]), not bool(view.st.get_flag(str(prop["flag"]))))
		_:
			pass
	if prop.has("flag") and kind != "lever":
		view.st.set_flag(str(prop["flag"]))
	if prop.has("item") and not bool(used.get(id, false)):
		view.st.gain_item(str(prop["item"]), 1, view.leader().creature as Character)   # shown on the side (ItemNotices)
	used[id] = true
	if str(prop.get("dialogue", "")) != "":
		view.dialogue_prop = id   # (the camera leans to it, a vestige's amber flares: GameRoot, TalkCamera, AmberGlow)
		view.dialogue_requested.emit(str(prop["dialogue"]), "")
		return
	# A prop's own `say` first (a camp's fire indoors: examine:camp_fire:indoors), then examine:<id> or search:<id>.
	var lead := view.leader().creature as Character
	var said := str(prop.get("say", "")) != "" and view._say(str(prop["say"]), lead)
	if not said:
		said = view._say("%s:%s" % ["search" if kind == "search" else "examine", id], lead)
	if not said and str(prop.get("text", "")) != "":
		view.narration.emit(str(prop["text"]))
	view._trigger_encounter("examine:" + id)
