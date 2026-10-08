class_name LocationNpcs
extends RefCounted
## The people in a location (LocationView): who stands here now (each NPC entry's `when` and `hours`, re-checked as the
## clock moves by LocationClock), who walks a route (`path`, NpcRoutes), figures a conversation brings on and takes
## off again (the dialogue statements `appear` and `vanish`), people who step aside when their talk ends in a fight,
## and those who speak first when the party comes near.


## An entry's `facing` as a ground direction (x, z): north is up the map.
const FACINGS := {"north": Vector2(0, -1), "south": Vector2(0, 1), "east": Vector2(1, 0), "west": Vector2(-1, 0),
	"northeast": Vector2(1, -1), "northwest": Vector2(-1, -1), "southeast": Vector2(1, 1), "southwest": Vector2(-1, 1)}


## Re-reads which NPCs, props and containers are here (their `when` conditions) after a conversation or a fight
## changes the story.
static func refresh_npcs(view: LocationView) -> void:
	view.set_meta(&"npcs_built", Engine.get_process_frames())   # LocationClock never rebuilds twice in one frame
	for id: String in view.prop_nodes:
		(view.prop_nodes[id] as Node).queue_free()
	view.prop_nodes.clear()
	for id: String in view.container_nodes:
		(view.container_nodes[id] as Node).queue_free()
	view.container_nodes.clear()
	LocationBuilder._build_props(view)
	for shown in view._npc_shown:
		(shown["token"] as Node).queue_free()
		if not bool(shown["low_before"]):
			view.grid.set_flag(shown["cell"] as Vector2i, CombatGrid.LOW, false)
	view._npc_shown.clear()
	view.npc_tokens.clear()
	_build_npcs(view)
	# Rebuilt pieces in rooms nobody has found yet stay hidden (HiddenAreas only looks again when a secret door is found).
	var hidden_areas := HiddenAreas.of(view)
	if hidden_areas != null:
		hidden_areas.call("_hide_nodes")


static func _build_npcs(view: LocationView) -> void:
	for n: Variant in view.loc.get("npcs", []):
		var spec := n as Dictionary
		if not StoryConditions.check(str(spec.get("when", "")), view.st) or not Schedule.in_hours(spec, view.st):
			continue
		if view.npc_tokens.has(str(spec["npc"])):
			continue   # one entry per NPC at a time: the first whose condition holds
		var npc := Compendium.shared().get_entry("npcs", str(spec["npc"]))
		var mon_id := str(npc.get("monster", "commoner"))
		var data := Compendium.shared().monster_data(mon_id)
		if data.is_empty():
			data = Compendium.shared().monster_data("commoner")
		var m := Monster.from_data(data)
		m.name = str(npc.get("name", spec["npc"]))
		if bool(spec.get("asleep", false)):
			put_to_sleep(m)
		var cb := Combatant.new(m, &"neutral", LocationView._cell(spec["cell"]))
		cb.id = "npc_" + str(spec["npc"])
		var tok := _npc_token(cb, str(npc.get("sprite", spec["npc"])))
		tok.position = view.board.cell_center(cb.cell)
		view.add_child(tok)
		if FACINGS.has(str(spec.get("facing", ""))):
			tok.face(FACINGS[str(spec["facing"])] as Vector2, false)   # where they look (and lane 25's sight cones)
		view.npc_tokens[str(spec["npc"])] = tok
		view._npc_shown.append({"spec": spec, "token": tok, "cell": cb.cell, "low_before": view.grid.has_flag(cb.cell, CombatGrid.LOW)})
		view.grid.set_flag(cb.cell, CombatGrid.LOW, true)   # an NPC blocks the square while standing there
	LocationClock.of(view)   # people keep their hours, and the day's events happen, as the clock moves
	# People with a `path` walk it (NpcRoutes), round everyone standing still; each starts after its first pause.
	for shown in view._npc_shown:
		var spec := shown["spec"] as Dictionary
		if not spec.has("path"):
			continue
		var own := shown["cell"] as Vector2i
		view.grid.set_flag(own, CombatGrid.LOW, bool(shown["low_before"]))
		shown["route"] = NpcRoutes.route_for(view, spec)
		view.grid.set_flag(own, CombatGrid.LOW, true)
		shown["wait"] = float(spec.get("pause", NpcRoutes.PAUSE))
		if not (shown["route"] as Array).is_empty():
			NpcRoutes.of(view)


## Owner report (2026-10-07): Offalia ate her mother's pastry and stood on at the oven. An entry with `asleep: true`
## lies asleep: Unconscious, as the 2024 rules have a sleeper (Incapacitated and Prone, unaware), so the token draws
## the figure lying down and lists the conditions. A blow or a shake (the Wake action) ends the sleep, still Prone.
static func put_to_sleep(cr: Creature) -> void:
	var nap := Effect.new("Asleep", &"npc", "asleep").with_condition(&"unconscious")
	nap.ends_on_damage = true
	nap.data["wakeable"] = true
	cr.add_effect(nap)
	cr.add_condition(&"prone", "Asleep")


## Whether an NPC shown here is asleep (its entry's `asleep`, while nothing has woken it).
static func is_asleep(view: LocationView, npc_id: String) -> bool:
	var tok := view.npc_tokens.get(npc_id, null) as CombatToken
	return tok != null and tok.combatant.creature.effects.any(func(fx: Effect) -> bool: return bool(fx.data.get("wakeable", false)))


## How a shown NPC is, for the hover hint, Look and the Alt plates: "asleep, prone", or "" when nothing is the matter.
static func state_words(view: LocationView, npc_id: String) -> String:
	var tok := view.npc_tokens.get(npc_id, null) as CombatToken
	if tok == null:
		return ""
	var words: Array[String] = []
	if is_asleep(view, npc_id):
		words.append("asleep")
	if tok.combatant.creature.has_condition(&"prone"):
		words.append("prone")
	return ", ".join(words)


## The hover hint over a person: "Talk to Ismark", or a sleeper's name and state ("Offalia Wormwiggle (asleep, prone)").
static func hover_label(view: LocationView, npc_id: String, who: String) -> String:
	var state := state_words(view, npc_id)
	if is_asleep(view, npc_id):
		return "%s (%s)" % [who, state]
	return "Talk to %s%s" % [who, " (%s)" % state if state != "" else ""]


## What Look adds about a shown person's state: " Asleep: Unconscious and Prone." or "".
static func look_words(view: LocationView, npc_id: String) -> String:
	if is_asleep(view, npc_id):
		return " Asleep: Unconscious and Prone."
	return " Prone." if state_words(view, npc_id) == "prone" else ""


## Owner report (2026-10-07): Strahd spoke at the funeral but wasn't there. A scene puts a speaker on the map for as
## long as it lasts: beside a door, prop, container or exit named `at`, or a few squares from the party.
static func stage_npc(view: LocationView, npc_id: String, at: String = "") -> void:
	if view.npc_tokens.has(npc_id) or view._staged.has(npc_id) or view.members.is_empty():
		return
	var near := view.leader().cell
	var found := false
	if at != "":
		for list: String in ["doors", "props", "containers", "exits"]:
			for t: Variant in view.loc.get(list, []):
				var spec := t as Dictionary
				if str(spec.get("id", "")) == at and spec.has("cell"):
					near = LocationView._cell(spec["cell"])
					found = true
	var taken := {}
	for m in view.members + view.guest_members:
		taken[m.cell] = true
	var cell := Vector2i(-1, -1)
	for c in LocationParty._cells_around(view, near, 16 if found else 24):
		if taken.has(c) or view.grid.is_solid(c) or view.npc_tokens.values().any(func(t: Node) -> bool: return view.grid.cell_at((t as Node3D).position) == c):
			continue
		if not found and c.distance_to(near) < 3.0:
			continue   # beside the party, not on top of it
		cell = c
		break
	if cell == Vector2i(-1, -1):
		return
	var npc := Compendium.shared().get_entry("npcs", npc_id)
	var data := Compendium.shared().monster_data(str(npc.get("monster", "commoner")))
	if data.is_empty():
		data = Compendium.shared().monster_data("commoner")
	var m := Monster.from_data(data)
	m.name = str(npc.get("name", npc_id))
	var cb := Combatant.new(m, &"neutral", cell)
	cb.id = "npc_" + npc_id
	var tok := _npc_token(cb, str(npc.get("sprite", npc_id)))
	tok.position = view.board.cell_center(cell)
	view.add_child(tok)
	if view.leader() != null:
		var to_party := Vector2(view.leader().cell - cell)
		tok.face(to_party, false)
	view._staged[npc_id] = tok


static func unstage_npc(view: LocationView, npc_id: String) -> void:
	if view._staged.has(npc_id):
		(view._staged[npc_id] as Node).queue_free()
		view._staged.erase(npc_id)


static func clear_staged(view: LocationView) -> void:
	for id: String in view._staged.keys():
		unstage_npc(view, id)


static func _npc_token(cb: Combatant, art: String) -> CombatToken:
	return CombatToken.create(cb, art)


## When a conversation ends in a fight, the people in it step aside: the encounter places its own monsters (a
## talking wolf pack, the Dursts as ghouls). Their entries' `when` decides whether they come back afterwards.
static func hide_npcs_of(view: LocationView, dialogue_ref: String) -> void:
	var file_key := dialogue_ref.substr(0, dialogue_ref.rfind(":"))
	for shown in view._npc_shown:
		var ref := str((shown["spec"] as Dictionary).get("dialogue", ""))
		if ref.substr(0, ref.rfind(":")) != file_key:
			continue
		(shown["token"] as Node3D).visible = false
		if not bool(shown["low_before"]):
			view.grid.set_flag(shown["cell"] as Vector2i, CombatGrid.LOW, false)


## An NPC entry with `approach: n` speaks first, once, when the leader comes within n squares and can see them.
static func _check_approach(view: LocationView) -> bool:
	for shown in view._npc_shown:
		var spec := shown["spec"] as Dictionary
		var reach := int(spec.get("approach", 0))
		if reach <= 0 or str(spec.get("dialogue", "")) == "":
			continue
		var key := "approach:%s:%s" % [spec["npc"], spec["dialogue"]]
		var props := view.st.loc_state(view.loc_id)["props"] as Dictionary
		if bool(props.get(key, false)):
			continue
		var at := shown["cell"] as Vector2i
		if view.grid.distance_ft(view.leader().cell, 1, at, 1) > reach * 5 or not view.grid.can_see(view.leader().cell, 1, at, 1):
			continue
		props[key] = true
		view._queue.clear()
		view.dialogue_requested.emit(str(spec["dialogue"]), str(spec["npc"]))
		return true
	return false
