class_name LocationCrime
extends RefCounted
## Stealing and crime in a location (F8, and F2's town watch; LocationView, docs/rules/stealth.md): taking from what
## someone owns, picking a pocket, walking into a private room, the people who see it, and the watch that answers. The
## record itself (fines, attitudes, pockets) is Crime's.
##
## Somebody sees a crime when they would notice the thief as a foe would (LocationStealth.notices: within 30 ft, in
## sight without Three-Quarters Cover, and, while the party sneaks, passive Perception against the thief's Stealth).

## Steps a party member may still be seen in a private room after being told to leave, before it's a crime.
const TRESPASS_GRACE := 3


## The npc ids of the people here who see `thief` now (never the party's guests, nor anyone in `skip`).
static func witnesses(view: LocationView, thief: Combatant, skip: Array[String] = []) -> Array[String]:
	var out: Array[String] = []
	if thief == null or view.in_combat:
		return out
	var e := LocationStealth.watch(view)
	var total := LocationStealth.total_for(view, thief.creature) if view.sneaking else 0
	for npc_id: String in _people(view):
		if npc_id in skip or npc_id in view.st.guest_ids:
			continue
		var who := (_token(view, npc_id) as CombatToken).combatant
		if LocationStealth.notices(e, who, thief, view.sneaking, total):
			out.append(npc_id)
	return out


## The people standing here (the location's and any a scene brought on) whose figures show.
static func _people(view: LocationView) -> Array[String]:
	var out: Array[String] = []
	for npc_id: String in view.npc_tokens:
		var tok := view.npc_tokens[npc_id] as CombatToken
		if is_instance_valid(tok) and tok.visible and not HiddenAreas.hides(view, tok.combatant.cell):
			out.append(npc_id)
	for npc_id: String in view._staged:
		if is_instance_valid(view._staged[npc_id] as Node) and not npc_id in out:
			out.append(npc_id)
	return out


static func _token(view: LocationView, npc_id: String) -> CombatToken:
	return (view.npc_tokens.get(npc_id, view._staged.get(npc_id, null))) as CombatToken


static func _name(npc_id: String) -> String:
	return str(Compendium.shared().get_entry("npcs", npc_id).get("name", npc_id))


# --- Taking what someone owns -------------------------------------------------------------------------

## The container's spec by id, or {}.
static func _container(view: LocationView, container_id: String) -> Dictionary:
	for c: Variant in view.loc.get("containers", []):
		if str((c as Dictionary)["id"]) == container_id:
			return c as Dictionary
	return {}


## The hover label's note for something owned: " (Urwin's: taking is stealing)", or "".
static func owned_note(spec: Dictionary) -> String:
	var owner := Crime.owner_of(spec)
	return " (%s's: taking is stealing)" % _name(owner).get_slice(" ", 0) if owner != "" else ""


## Opening something owned: a reminder that taking from it is stealing (looking isn't).
static func opened(view: LocationView, container_id: String) -> void:
	var owner := Crime.owner_of(_container(view, container_id))
	if owner != "":
		view.toast.emit("%s's: taking anything is stealing" % _name(owner))


## The loot window closed on a container after `taken` gp worth was taken: stealing, if it's owned and somebody saw.
static func after_loot(view: LocationView, container_id: String, taken: float) -> void:
	var owner := Crime.owner_of(_container(view, container_id))
	if owner == "" or taken <= 0.0 or view.members.is_empty():
		return
	var seen := witnesses(view, view.leader())
	if seen.is_empty():
		view.toast.emit("Nobody saw")
		return
	caught(view, owner, seen[0], "theft")


# --- Picking a pocket ---------------------------------------------------------------------------------

static func _picked(view: LocationView, npc_id: String) -> bool:
	return bool((view.st.loc_state(view.loc_id)["props"] as Dictionary).get("pocket:" + npc_id, false))


## The right-click entry for picking `npc_id`'s pocket, with the leader's Sleight of Hand bonus.
static func pickpocket_action(view: LocationView, npc_id: String) -> Dictionary:
	var why := Crime.why_no_pocket(view.st, npc_id, _picked(view, npc_id))
	var who := view.leader().creature
	return {"id": "pickpocket", "label": "Pick %s pocket (Sleight of Hand %s)" % [_possessive(npc_id), who.skill_bonus(&"sleight_of_hand").signed()],
		"enabled": why == "", "why": why}


static func _possessive(npc_id: String) -> String:
	var first := _name(npc_id).get_slice(" ", 0)
	return first + ("'" if first.ends_with("s") else "'s")


## The leader tries `npc_id`'s pocket (standing beside them): Dexterity (Sleight of Hand) against their passive
## Perception. Success lifts their coins and anything their data puts in the pocket, and anyone else who sees it makes
## it a crime; failure, and they catch the hand.
static func pickpocket(view: LocationView, npc_id: String) -> void:
	var why := Crime.why_no_pocket(view.st, npc_id, _picked(view, npc_id))
	var tok := _token(view, npc_id)
	if why != "" or tok == null:
		view.toast.emit(why if why != "" else "Nobody there")
		return
	var thief := view.leader()
	var dc := passive(tok.combatant)
	var t := thief.creature.roll_check(view.dice, &"sleight_of_hand", dc, CheckAids.before_check(thief.creature, &"sleight_of_hand"),
		[], "Sleight of Hand (%s) vs %s's passive Perception" % [thief.name(), _name(npc_id)])
	view.check_rolled.emit(t.describe())
	(view.st.loc_state(view.loc_id)["props"] as Dictionary)["pocket:" + npc_id] = true
	if not t.success:
		view.toast.emit("%s catches %s's hand in the pocket!" % [_name(npc_id), thief.name().get_slice(" ", 0)])
		caught(view, npc_id, npc_id, "theft")
		return
	var p := Crime.pocket(npc_id, view.dice)
	view.st.gold += float(p["gold"])
	var got: Array[String] = []
	if int(p["gold"]) > 0:
		got.append("%d gp" % int(p["gold"]))
	for it: Variant in p["items"]:
		var d := it as Dictionary
		view.st.give_item(str(d["id"]), int(d.get("qty", 1)), thief.creature as Character)
		got.append(Compendium.shared().display_name("items", str(d["id"])))
	view.toast.emit("%s lifts %s from %s" % [thief.name().get_slice(" ", 0), ", ".join(got) if not got.is_empty() else "nothing worth having",
		_name(npc_id)])
	var seen := witnesses(view, thief, [npc_id])
	if not seen.is_empty():
		caught(view, npc_id, seen[0], "theft")


## A person's passive Perception (worked out once and kept on them, as LocationStealth keeps a foe's).
static func passive(cb: Combatant) -> int:
	if not cb.has_meta("passive_perception"):
		cb.set_meta("passive_perception", cb.creature.passive_score(&"perception").total())
	return int(cb.get_meta("passive_perception"))


# --- Private rooms --------------------------------------------------------------------------------------

## After a step: the leader in a private room (an area's `private`, unless its `open` condition holds), seen by
## anyone here, is told to leave; seen there again after TRESPASS_GRACE more steps, or after coming back, it's a crime.
## True if it stopped the walk.
static func check_trespass(view: LocationView) -> bool:
	if view.in_combat or view.members.is_empty():
		return false
	var grace := view.get_meta("trespass_grace", {}) as Dictionary
	for a: Variant in view.loc.get("areas", []):
		var area := a as Dictionary
		if str(area.get("private", "")) == "" or not LocationView._in_area(area, view.leader().cell):
			continue
		if str(area.get("open", "")) != "" and StoryConditions.check(str(area["open"]), view.st):
			continue
		var seen := witnesses(view, view.leader())
		if seen.is_empty():
			continue
		var props := view.st.loc_state(view.loc_id)["props"] as Dictionary
		var key := "trespass:" + str(area["id"])
		if not bool(props.get(key, false)):
			props[key] = true
			grace[key] = TRESPASS_GRACE
			view.set_meta("trespass_grace", grace)
			view.toast.emit("%s: You can't be in there. Out, before I call the watch." % _name(seen[0]).get_slice(" ", 0))
			return true
		var left := int(grace.get(key, 0))
		if left > 0:
			grace[key] = left - 1
			view.set_meta("trespass_grace", grace)
			continue
		caught(view, str(area["private"]), seen[0], "trespass")
		return true
	return false


# --- Caught -------------------------------------------------------------------------------------------

## A crime somebody saw: the victim thinks less of the party and, in a town that keeps a watch, a watchman comes for
## the party at once (the town's watch dialogue: a fine, a word, or a fight).
static func caught(view: LocationView, victim: String, witness: String, kind: String) -> void:
	var n := Crime.offence(view.st, view.loc, victim)
	if witness != victim:
		view.toast.emit("%s saw that" % _name(witness))
	var guard := Crime.watch_for(view.loc)
	if guard == "" or n == 0 or view.in_combat:
		return
	_ready_the_arrest(view, guard)
	view._queue.clear()
	view.stage_npc(guard)
	view.dialogue_requested.emit("watch/%s:%s" % [str(view.loc.get("region", "")), kind], guard)


## The fight a refused fine starts (`combat watch_arrest` in the watch's dialogue), here and now: two of the watch a
## few squares from the party. Put first, so it's the entry the fight uses in this place.
static func _ready_the_arrest(view: LocationView, guard: String) -> void:
	var monster := str(Compendium.shared().get_entry("npcs", guard).get("monster", "vallaki_guard"))
	var taken := {}
	for m: Combatant in view.members + view.guest_members:
		taken[m.cell] = true
	var cells: Array[Vector2i] = []
	for c in LocationParty._cells_around(view, view.leader().cell, 40):
		if cells.size() >= 2:
			break
		if not taken.has(c) and not view.grid.has_flag(c, CombatGrid.LOW) and c.distance_to(view.leader().cell) >= 2.0:
			cells.append(c)
	var monsters: Array = []
	for i in cells.size():
		monsters.append({"monster": monster, "cell": [cells[i].x, cells[i].y], "name": "Watchman %d" % (i + 1)})
	if monsters.is_empty():
		return
	if not view.loc.has("encounters"):
		view.loc["encounters"] = []
	var list := view.loc["encounters"] as Array
	for i in range(list.size() - 1, -1, -1):
		if bool((list[i] as Dictionary).get("arrest", false)):
			list.remove_at(i)
	list.insert(0, {"id": "watch_arrest", "trigger": "dialogue", "arrest": true, "monsters": monsters,
		"text": "The watch closes in, spears levelled."})
