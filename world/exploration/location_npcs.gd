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
	# Where each person stands and how far along their route they are, so the rebuild leaves them there (owner report
	# 2026-10-09: people in Vallaki snapped back to their starting square as every conversation ended).
	var places := {}
	for shown in view._npc_shown:
		places[str((shown["spec"] as Dictionary)["npc"])] = shown
	for shown in view._npc_shown:
		(shown["token"] as Node).queue_free()
		if not bool(shown["low_before"]):
			view.grid.set_flag(shown["cell"] as Vector2i, CombatGrid.LOW, false)
	view._npc_shown.clear()
	view.npc_tokens.clear()
	_build_npcs(view, places)
	# Rebuilt pieces in rooms nobody has found yet stay hidden (HiddenAreas only looks again when a secret door is found).
	var hidden_areas := HiddenAreas.of(view)
	if hidden_areas != null:
		hidden_areas.call("_hide_nodes")


## `places`: the people shown before a rebuild (npc id -> its _npc_shown entry); one still under the same entry keeps its
## square and its place on its route.
static func _build_npcs(view: LocationView, places: Dictionary = {}) -> void:
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
		# The same person keeps the same creature while the party is here, so what a spell left on them (Sleep, Charm
		# Person, Bane) stays through the rebuilds after every conversation, and Concentration still finds them.
		var kept := _creatures(view)
		var m := kept.get(str(spec["npc"]), null) as Monster
		if m == null:
			m = Monster.from_data(data)
			kept[str(spec["npc"])] = m
		m.name = str(npc.get("name", spec["npc"]))
		_wake_from_story(m)
		if bool(spec.get("asleep", false)):
			put_to_sleep(m)
		var was := places.get(str(spec["npc"]), {}) as Dictionary
		if not was.is_empty() and not is_same(was["spec"], spec):
			was = {}   # another entry of theirs now (a new hour, a new chapter): they start at its cell
		var cb := Combatant.new(m, &"neutral", was["cell"] as Vector2i if not was.is_empty() else LocationView._cell(spec["cell"]))
		cb.id = "npc_" + str(spec["npc"])
		var tok := _npc_token(cb, str(npc.get("sprite", spec["npc"])))
		tok.position = view.board.cell_center(cb.cell)
		var seat := _seat(view, spec)
		if seat != Vector3.INF:
			tok.position = seat   # standing on a prop (`on`): the Amber Sentinel on its dais
		view.add_child(tok)
		if FACINGS.has(str(spec.get("facing", ""))):
			tok.face(FACINGS[str(spec["facing"])] as Vector2, false)   # where they look (and lane 25's sight cones)
		if spec.has("lying"):
			LyingFigures.lay(view, tok, spec["lying"], cb.cell)   # Vasilka under her sheet, a witch where she fell
		view.npc_tokens[str(spec["npc"])] = tok
		# Outside fights nobody blocks anybody (owner, 2026-10-12: rooms were too cramped): the party walks through
		# people and people through the party, so a person's square stays as open as the floor under them.
		view._npc_shown.append({"spec": spec, "token": tok, "cell": cb.cell, "low_before": view.grid.has_flag(cb.cell, CombatGrid.LOW),
			"was": was})
	LocationClock.of(view)   # people keep their hours, and the day's events happen, as the clock moves
	# People with a `path` walk it (NpcRoutes), round everyone standing still; each starts after its first pause.
	for shown in view._npc_shown:
		var spec := shown["spec"] as Dictionary
		var was := shown.get("was", {}) as Dictionary
		shown.erase("was")
		if not spec.has("path"):
			continue
		if was.has("route"):
			# Back where they were on the same route: the walk goes on from there.
			for k: String in ["route", "at", "wait"]:
				if was.has(k):
					shown[k] = was[k]
			if not (shown["route"] as Array).is_empty():
				NpcRoutes.of(view)
			continue
		shown["route"] = NpcRoutes.route_for(view, spec)
		shown["wait"] = float(spec.get("pause", NpcRoutes.PAUSE))
		if not (shown["route"] as Array).is_empty():
			NpcRoutes.of(view)


## Where an entry that stands `on` a prop of the place stands: the middle of its top (the `seat` its piece was built with),
## or Vector3.INF with no `on` or where that piece has none (the Classic finish builds no dais).
static func _seat(view: LocationView, spec: Dictionary) -> Vector3:
	var node := view.prop_nodes.get(str(spec.get("on", ""))) as Node3D
	if node != null and node.has_meta("seat"):
		return node.get_meta("seat") as Vector3
	return Vector3.INF


## Owner report (2026-10-07): Offalia ate her mother's pastry and stood on at the oven. An entry with `asleep: true`
## lies asleep: Unconscious, as the 2024 rules have a sleeper (Incapacitated and Prone, unaware), so the token draws
## the figure lying down and lists the conditions. A blow or a shake (the Wake action) ends the sleep, still Prone.
static func put_to_sleep(cr: Creature) -> void:
	var nap := Effect.new("Asleep", &"npc", "asleep").with_condition(&"unconscious")
	nap.ends_on_damage = true
	nap.data["wakeable"] = true
	cr.add_effect(nap)
	cr.add_condition(&"prone", "Asleep")


## The story's sleep comes off when an entry without `asleep` takes over (she woke and went out looking for Mother);
## a spell's sleep stays.
static func _wake_from_story(cr: Creature) -> void:
	for fx: Effect in cr.effects.duplicate():
		if fx.source_kind == &"npc" and fx.source_id == "asleep":
			cr.remove_effect(fx)
	cr.remove_condition(&"prone", "Asleep")


## npc id -> the creature on the map, for as long as the party is in this place.
static func _creatures(view: LocationView) -> Dictionary:
	if not view.has_meta(&"npc_creatures"):
		view.set_meta(&"npc_creatures", {})
	return view.get_meta(&"npc_creatures") as Dictionary


## The effect keeping a creature asleep (the story's, Sleep's: a wakeable one that carries Unconscious), or null.
static func sleep_of(cr: Creature) -> Effect:
	for fx in cr.effects:
		if bool(fx.data.get("wakeable", false)) and &"unconscious" in fx.conditions:
			return fx
	return null


## Whether an NPC shown here is asleep (the story's sleep or a spell's, while nothing has woken it).
static func is_asleep(view: LocationView, npc_id: String) -> bool:
	var tok := view.npc_tokens.get(npc_id, null) as CombatToken
	return tok != null and sleep_of(tok.combatant.creature) != null


## Whether an NPC shown here lies down as the story has them (an entry's `lying`: Vasilka on her table, a witch where
## she fell), so they're approached rather than talked to.
static func is_lying(view: LocationView, npc_id: String) -> bool:
	var tok := view.npc_tokens.get(npc_id, null) as CombatToken
	return tok != null and tok.resting


## How a creature on the map is, for the hover hint, Look and the Alt plates: its conditions (a sleeper's "asleep" in
## place of the Unconscious and Incapacitated it carries), then the spells on it that someone else cast, after a dot:
## "asleep, prone", "charmed · Charm Person", "asleep, prone · Sleep", "Bane"; "" when nothing is the matter.
static func state_of(cr: Creature) -> String:
	var words: Array[String] = []
	var nap := sleep_of(cr)
	if nap != null:
		words.append("asleep")
	for cond in cr.active_conditions():
		if nap != null and cond in [&"unconscious", &"incapacitated"]:
			continue
		words.append(str(cond))
	var spells: Array[String] = []
	for fx in cr.effects:
		if fx.caster_id == "" or fx.caster_id == cr.id:
			continue   # the story's sleep, a monster's own traits
		var named := str(Compendium.shared().spell_data(fx.source_id).get("name", fx.name)) if fx.source_kind == &"spell" else fx.name
		if not named in spells:
			spells.append(named)
	var out := ", ".join(words)
	if not spells.is_empty():
		out += (" · " if out != "" else "") + ", ".join(spells)
	return out


## How a shown NPC is (state_of), or "".
static func state_words(view: LocationView, npc_id: String) -> String:
	var tok := view.npc_tokens.get(npc_id, null) as CombatToken
	return state_of(tok.combatant.creature) if tok != null else ""


## The hover hint over a person: "Talk to Ismark", "Talk to Ismark (charmed · Charm Person)", a sleeper's name and
## state ("Offalia Wormwiggle (asleep, prone)"), or the name of someone lying there ("Vasilka").
static func hover_label(view: LocationView, npc_id: String, who: String) -> String:
	var state := state_words(view, npc_id)
	if is_asleep(view, npc_id):
		return "%s (%s)" % [who, state]
	if is_lying(view, npc_id):
		return who + (" (%s)" % state if state != "" else "")
	return "Talk to %s%s" % [who, " (%s)" % state if state != "" else ""]


## What Look adds about a shown person's state: " Asleep: Unconscious and Prone." for the story's sleep, else the
## state as a sentence (" Charmed · Charm Person."), or "".
static func look_words(view: LocationView, npc_id: String) -> String:
	var state := state_words(view, npc_id)
	if state == "asleep, prone":
		return " Asleep: Unconscious and Prone."
	return (" %s%s." % [state[0].to_upper(), state.substr(1)]) if state != "" else ""


## Whether a shown person can talk: a story sleeper's entry has its own conversation (Offalia snoring); anyone else
## asleep, held or otherwise Incapacitated can't answer.
static func can_talk(view: LocationView, spec: Dictionary) -> bool:
	if bool(spec.get("asleep", false)):
		return true
	var tok := view.npc_tokens.get(str(spec["npc"]), null) as CombatToken
	return tok == null or not tok.combatant.creature.has_condition(&"incapacitated")


## As time passes here (LocationClock), the spells on the people run down: Sleep's minute, Bane's.
static func pass_minutes(view: LocationView, minutes: int) -> void:
	for shown in view._npc_shown:
		var tok := shown["token"] as CombatToken
		if not is_instance_valid(tok):
			continue
		var before := state_of(tok.combatant.creature)
		tok.combatant.creature.advance_minutes(minutes)
		if state_of(tok.combatant.creature) != before:
			tok.refresh()


# --- Spells at the people here (FieldCasting.cast_at) ---------------------------------------------------------

## The right-click menu's spells at a person: each party member's at-creature spells (Sleep, Charm Person, Hold
## Person ...), [{id: "cast_at:<member>:<spell>", label, enabled, why}], out of range or sight shown and refused.
static func cast_actions(view: LocationView, spec: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var at := _cell_of(view, str(spec["npc"]))
	for i in view.members.size():
		var m := view.members[i]
		if not (m.creature is Character) or m.creature.hp <= 0:
			continue
		for o in FieldCasting.options_at(view.st.party, m.creature as Character, view.dice):
			var why := str(o["reason"]) if not bool(o["legal"]) else ""
			if why == "" and view.grid.distance_ft(m.cell, 1, at, 1) > int(o["range"]):
				why = "Out of range (%d ft)" % int(o["range"])
			if why == "" and not view.grid.can_see(m.cell, 1, at, 1):
				why = "%s can't see them" % m.name().get_slice(" ", 0)
			out.append({"id": "cast_at:%d:%s" % [i, o["id"]], "label": "Cast %s (%s)" % [o["name"], m.name().get_slice(" ", 0)],
				"enabled": why == "", "why": why})
	return out


## A spell from the right-click menu ("cast_at:<member>:<spell>") at the person on `cell`: cast through the spell
## engine (FieldCasting.cast_at), told in the Narrator's box, and shown on them at once.
static func cast_from_menu(view: LocationView, cell: Vector2i, action_id: String) -> void:
	var parts := action_id.split(":")
	var i := int(parts[1])
	var tok: CombatToken = null
	for shown in view._npc_shown:
		if shown["cell"] == cell:
			tok = shown["token"] as CombatToken
	if tok == null or i < 0 or i >= view.members.size():
		return
	var npc_id := tok.combatant.id.trim_prefix("npc_")
	# Whoever sees the casting (LocationCrime, as for a theft: sight, earshot) remembers it.
	var seen := LocationCrime.witnesses(view, view.members[i])
	var res := FieldCasting.cast_at(view.st.party, view.members[i].creature as Character, parts[2], 0, tok.combatant.creature, view.dice)
	tok.refresh()
	view.refresh_party()
	view.narration.emit(str(res["text"]) if bool(res["ok"]) else "%s: %s" % [Compendium.shared().spell_data(parts[2]).get("name", parts[2]), res["text"]])
	# A spell at someone who didn't ask for it is a crime when anyone sees it (the watch answers in a town).
	if bool(res["ok"]) and not seen.is_empty():
		LocationCrime.caught(view, npc_id, seen[0], "spell")


## The right-click menu's spells at a foe in plain view: casting at a foe opens the fight with the party striking first
## (LocationStealth.strike), and the caster casts it on their turn. [{id: "strike_cast:<member>:<spell>:<fight>", ...}]
static func cast_actions_at_foe(view: LocationView, thing: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var at := LocationView._cell((thing["spec"] as Dictionary)["cell"])
	for i in view.members.size():
		var m := view.members[i]
		if not (m.creature is Character) or m.creature.hp <= 0:
			continue
		for o in FieldCasting.options_at(view.st.party, m.creature as Character, view.dice):
			var why := str(o["reason"]) if not bool(o["legal"]) else ""
			if why == "" and view.grid.distance_ft(m.cell, 1, at, 1) > int(o["range"]):
				why = "Out of range (%d ft)" % int(o["range"])
			if why == "" and not view.grid.can_see(m.cell, 1, at, 1):
				why = "%s can't see them" % m.name().get_slice(" ", 0)
			out.append({"id": "strike_cast:%d:%s:%s" % [i, o["id"], thing["id"]], "enabled": why == "", "why": why,
				"label": "Cast %s (%s): start the fight" % [o["name"], m.name().get_slice(" ", 0)]})
	return out


## A spell at a foe from the menu: the fight opens with the party striking first, and the caster is told to cast it.
static func strike_with_spell(view: LocationView, _cell: Vector2i, action_id: String) -> void:
	var parts := action_id.split(":", true, 3)
	var i := int(parts[1])
	if i < 0 or i >= view.members.size() or not view.strike(parts[3]):
		return
	view.toast.emit("%s readies %s: cast it on their turn" % [view.members[i].name().get_slice(" ", 0),
		Compendium.shared().spell_data(parts[2]).get("name", parts[2])])


static func _cell_of(view: LocationView, npc_id: String) -> Vector2i:
	for shown in view._npc_shown:
		if str((shown["spec"] as Dictionary)["npc"]) == npc_id:
			return shown["cell"] as Vector2i
	return Vector2i(-1, -1)


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
	# Beside the party, not on top of it: three squares off if there's room, else as near as there is (a narrow spawn).
	for apart: float in ([0.0] if found else [3.0, 2.0, 1.0]):
		for c in LocationParty._cells_around(view, near, 16 if found else 24):
			if taken.has(c) or view.grid.is_solid(c) or view.npc_tokens.values().any(func(t: Node) -> bool: return view.grid.cell_at((t as Node3D).position) == c):
				continue
			if not found and c.distance_to(near) < apart:
				continue
			cell = c
			break
		if cell != Vector2i(-1, -1):
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
## talking wolf pack, the Dursts as ghouls). Their entries' `when` decides whether they come back afterwards. Who
## stepped aside is kept for the fight to start with (`_stepped_aside`): a foe of the same name that turns out to be
## something else (a hag, a vampire spawn) changes in front of the party (LocationFights._reveal).
static func hide_npcs_of(view: LocationView, dialogue_ref: String) -> void:
	var file_key := dialogue_ref.substr(0, dialogue_ref.rfind(":"))
	view._stepped_aside.clear()
	for shown in view._npc_shown:
		var ref := str((shown["spec"] as Dictionary).get("dialogue", ""))
		if ref.substr(0, ref.rfind(":")) != file_key:
			continue
		(shown["token"] as Node3D).visible = false
		var npc := Compendium.shared().get_entry("npcs", str((shown["spec"] as Dictionary).get("npc", "")))
		if not npc.is_empty():
			view._stepped_aside.append({"name": str(npc.get("name", "")), "art": str(npc.get("sprite", npc.get("id", "")))})
		if not bool(shown["low_before"]):
			view.grid.set_flag(shown["cell"] as Vector2i, CombatGrid.LOW, false)


## The figure of one person of the place leaves the board for a fight, however it began (the Amber Sentinel stepping down
## into its foe: StepDown); their entries' `when` decides whether they come back afterwards, with the rebuild.
static func hide_npc(view: LocationView, npc_id: String) -> void:
	for shown in view._npc_shown:
		if str((shown["spec"] as Dictionary).get("npc", "")) == npc_id:
			(shown["token"] as Node3D).visible = false


## People whose entry says `steps_aside` keep out of every fight on the map (Castle Ravenloft's household: a ghost
## steward, the dead watch on its rounds, a broom at its sweeping): their figures leave the board as a fight begins, so
## they never stand in its way, and come back with the rebuild after it (refresh_npcs).
static func clear_for_fight(view: LocationView) -> void:
	for shown in view._npc_shown:
		if bool((shown["spec"] as Dictionary).get("steps_aside", false)):
			(shown["token"] as Node3D).visible = false


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


## A prop entry with `approach: n` and a `call` speaks first, once, when the leader comes within n squares and can see it,
## before anyone uses it (a vestige in its amber calling to the party: Amber Temple Look Plan 6b). Its `when` and
## `call_when` say when it still may (not once the temple is sealed or the talk was had). The prop is the one the talk is
## about, so its amber flares and the camera leans to it.
static func _check_calls(view: LocationView) -> bool:
	var seen := view.st.loc_state(view.loc_id)["props"] as Dictionary
	for p: Variant in view.loc.get("props", []):
		var spec := p as Dictionary
		var reach := int(spec.get("approach", 0))
		if reach <= 0 or str(spec.get("call", "")) == "":
			continue
		var key := "call:%s" % spec["id"]
		if bool(seen.get(key, false)):
			continue
		if not StoryConditions.check(str(spec.get("when", "")), view.st) or not StoryConditions.check(str(spec.get("call_when", "")), view.st):
			continue
		var at := LocationView._cell(spec["cell"])
		if view.grid.distance_ft(view.leader().cell, 1, at, 1) > reach * 5 or not view.grid.can_see(view.leader().cell, 1, at, 1):
			continue
		seen[key] = true
		view._queue.clear()
		view.dialogue_prop = str(spec["id"])
		view.dialogue_requested.emit(str(spec["call"]), "")
		return true
	return false
