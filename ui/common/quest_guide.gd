class_name QuestGuide
extends RefCounted
## Who to talk to for the tracked quest (owner ask 2026-10-12, docs/ui/travel_map.md "Who to talk to"): the people
## whose conversation, as things stand now, moves the quest on from its current stage. The minimap and the travel map
## mark them in green and the journal shows their portrait. Read-only: it walks the dialogue files the way
## DialogueRunner would play them (its `if` blocks and option conditions checked against the story as it is), from each
## person's own entry point, looking for a `quest <id> <stage>` that sets a later stage. Conversations that only the
## party has among themselves (the camp) don't count: only people standing somewhere in a location.

## How many dialogue nodes one person's conversation may visit before the search gives up.
const NODE_LIMIT := 300

## The stages after `quest_id`'s current one: stage id -> true. Empty when the quest isn't open.
static func later_stages(st: StoryState, quest_id: String) -> Dictionary:
	var out := {}
	if not st.quests.has(quest_id):
		return out
	var current := str((st.quests[quest_id] as Dictionary).get("stage", ""))
	var past := false
	for s: Variant in Compendium.shared().get_entry("quests", quest_id).get("stages", []):
		var id := str((s as Dictionary)["id"])
		if past:
			out[id] = true
		elif id == current:
			if str((s as Dictionary).get("ends", "")) != "":
				return {}   # over
			past = true
	return out


## Does the conversation starting at `ref` ("file:node") reach a step that moves `quest_id` to one of `later`?
static func moves_on(st: StoryState, ref: String, quest_id: String, later: Dictionary) -> bool:
	if ref == "" or later.is_empty():
		return false
	var seen := {}
	var todo: Array[String] = [ref]
	var found := false
	while not todo.is_empty() and seen.size() < NODE_LIMIT and not found:
		var at: String = todo.pop_front()
		if seen.has(at) or at == "END":
			continue
		seen[at] = true
		var f := DialogueFile.load_key(at.substr(0, at.rfind(":")))
		var node := at.substr(at.rfind(":") + 1)
		if f == null or not f.nodes.has(node):
			continue
		found = _scan(st, f, f.nodes[node] as Array[Dictionary], quest_id, later, todo)
	return found


## One node, as the runner would play it now: branches whose condition fails are skipped; options whose condition
## fails or whose speaker isn't in the party are left out; a check leads both ways. Queues where it goes on to.
static func _scan(st: StoryState, f: DialogueFile, stmts: Array[Dictionary], quest_id: String, later: Dictionary,
		todo: Array[String]) -> bool:
	# Each open `if`: [taking now, a branch already taken, the enclosing block taking].
	var blocks: Array[Array] = []
	for s in stmts:
		var t := str(s["t"])
		var outer := blocks.is_empty() or bool(blocks.back()[0])
		match t:
			"if":
				var take := outer and StoryConditions.check(str(s["cond"]), st)
				blocks.append([take, take, outer])
				continue
			"elif":
				if not blocks.is_empty():
					var b: Array = blocks.back()
					var take := bool(b[2]) and not bool(b[1]) and StoryConditions.check(str(s["cond"]), st)
					b[0] = take
					b[1] = bool(b[1]) or take
				continue
			"else":
				if not blocks.is_empty():
					var b: Array = blocks.back()
					b[0] = bool(b[2]) and not bool(b[1])
					b[1] = true
				continue
			"endif":
				if not blocks.is_empty():
					blocks.pop_back()
				continue
		if not outer:
			continue
		match t:
			"quest":
				if str(s["id"]) == quest_id and later.has(str(s["stage"])):
					return true
			"jump":
				todo.append(_resolve(f, str(s["to"])))
				return false   # the conversation goes on there
			"option":
				if not StoryConditions.check(str(s["cond"]), st):
					continue
				if str(s["selector"]) != "" and st.find_member(str(s["selector"])) == null:
					continue
				todo.append(_resolve(f, str(s["ok"])))
				if str(s["fail"]) != "":
					todo.append(_resolve(f, str(s["fail"])))
			"check":
				todo.append(_resolve(f, str(s["ok"])))
				if str(s.get("fail", "")) != "":
					todo.append(_resolve(f, str(s["fail"])))
				return false
	return false


## A jump's target as "file:node" (a bare node is in the same file), the way DialogueRunner reads it.
static func _resolve(f: DialogueFile, ref: String) -> String:
	if ref == "END" or ref == "":
		return "END"
	if ref.contains("/") and ref.contains(":"):
		return ref
	return "%s:%s" % [f.key, ref]


## The people to talk to for the tracked quest, anywhere: [{npc, location, ref}], each person once (their first
## placement whose `when` holds). Empty when no quest is tracked or nobody's conversation moves it on now.
static func targets(st: StoryState) -> Array[Dictionary]:
	return targets_for(st, QuestLog.tracked(st))


## The same for any open quest (the journal names them for whichever quest it shows).
static func targets_for(st: StoryState, qid: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var later := later_stages(st, qid)
	if later.is_empty():
		return out
	var c := Compendium.shared()
	var done := {}
	var ids: Array = c.table("locations").keys()
	ids.sort()
	# Where the party is comes first, so a person standing here is named with this place.
	if st.location in ids:
		ids.erase(st.location)
		ids.push_front(st.location)
	for lid: Variant in ids:
		for n: Variant in c.get_entry("locations", str(lid)).get("npcs", []):
			var spec := n as Dictionary
			var npc := str(spec.get("npc", ""))
			if npc == "" or done.has(npc) or not StoryConditions.check(str(spec.get("when", "")), st):
				continue
			if moves_on(st, str(spec.get("dialogue", "")), qid, later):
				done[npc] = true
				out.append({"npc": npc, "location": str(lid), "ref": str(spec["dialogue"])})
	return out


## The people standing in `view` now whose conversation moves the tracked quest on: npc id -> true.
static func targets_here(view: LocationView) -> Dictionary:
	var out := {}
	if view == null or not is_instance_valid(view):
		return out
	var qid := QuestLog.tracked(view.st)
	var later := later_stages(view.st, qid)
	if later.is_empty():
		return out
	for shown: Dictionary in view.get("_npc_shown"):
		var spec := shown["spec"] as Dictionary
		if moves_on(view.st, str(spec.get("dialogue", "")), qid, later):
			out[str(spec["npc"])] = true
	return out
