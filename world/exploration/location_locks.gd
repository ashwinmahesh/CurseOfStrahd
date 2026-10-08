class_name LocationLocks
extends RefCounted
## Doors and locks in a location (LocationView): opening a door, and the ways into a lock: its key, thieves' tools,
## force, the Knock spell, a Chime of Opening and the Mystery Key.


static func _door_state(view: LocationView, id: String) -> String:
	return str((view.st.loc_state(view.loc_id)["doors"] as Dictionary).get(id, ""))


## Closed, unlocked, known doors whose conditions hold: {cell: door spec}.
static func _openable_doors(view: LocationView) -> Dictionary:
	var out := {}
	for d: Variant in view.loc.get("doors", []):
		var door := d as Dictionary
		var id := str(door["id"])
		if _door_state(view, id) == LocationView.DOOR_OPEN or _locked(view, door):
			continue
		if int(door.get("secret_dc", 0)) > 0 and not bool((view.st.loc_state(view.loc_id)["found"] as Dictionary).get(id, false)):
			continue
		if not StoryConditions.check(str(door.get("when", "")), view.st):
			continue
		out[LocationView._cell(door["cell"])] = door
	return out


static func _locked(view: LocationView, spec: Dictionary) -> bool:
	if not bool(spec.get("locked", false)) and int(spec.get("lock_dc", 0)) <= 0:
		return false
	# A lock the story takes off (`unlocked_when`: the undercroft door once Father Donavich lifts its bar).
	if spec.has("unlocked_when") and StoryConditions.check(str(spec["unlocked_when"]), view.st):
		return false
	var state := str((view.st.loc_state(view.loc_id)["doors"] as Dictionary).get(str(spec["id"]), ""))
	return state != "unlocked" and state != LocationView.DOOR_OPEN


static func _use_door(view: LocationView, door: Dictionary, method: String = "auto") -> void:
	var id := str(door["id"])
	if not StoryConditions.check(str(door.get("when", "")), view.st):
		Audio.sfx("locked")
		view.narration.emit("It won't budge.")
		return
	if _locked(view, door):
		if not _unlock(view, door, method):
			return
	(view.st.loc_state(view.loc_id)["doors"] as Dictionary)[id] = LocationView.DOOR_OPEN
	Audio.sfx("door")
	view.grid.set_flag(LocationView._cell(door["cell"]), CombatGrid.WALL, false)
	(view.door_nodes[id] as Node3D).visible = false
	if door.has("flag"):
		view.st.set_flag(str(door["flag"]))
	view._say("open:" + id)
	view._trigger_encounter("open:" + id)


## Tries a key, thieves' tools (2024: Dexterity check, + Proficiency Bonus with the tools, Advantage with Sleight of
## Hand too), force (Strength (Athletics)) or the Knock spell, with the best party member for the job. Returns true
## if it opens. `method`: "auto" (a left click: the key if the party carries it, else the lock rattles and says so;
## nothing is tried), or "key", "pick", "force" or "knock" (the right-click menu).
static func _unlock(view: LocationView, spec: Dictionary, method: String = "auto") -> bool:
	var id := str(spec["id"])
	var key := str(spec.get("key", ""))
	if key != "" and view.st.party_has_item(key) and method in ["auto", "key"]:
		(view.st.loc_state(view.loc_id)["doors"] as Dictionary)[id] = "unlocked"
		Audio.sfx("unlock")
		view.toast.emit("Unlocked with the %s" % Compendium.shared().display_name("items", key))
		return true
	if method == "auto":
		Audio.sfx("locked")
		var can_try := actions_to_unlock(view, spec).any(func(a: Dictionary) -> bool: return bool(a.get("enabled", true)))
		view.toast.emit("Locked. Right-click it to try the lock." if can_try else "Locked. It needs its key.")
		return false
	if method == "key":
		view.narration.emit("None of you has the key.")
		return false
	if method == "knock":
		return _knock(view, spec)
	if method == "chime":
		return _chime(view, spec)
	if method == "mystery_key":
		return _mystery_key(view, spec)
	var dc := int(spec.get("lock_dc", 15))
	if dc <= 0:
		view.narration.emit("Locked, and no lock to pick: you'll need the key.")
		return false
	var picker := _lock_picker(view) if method == "pick" else null
	if method == "pick" and picker == null:
		view.narration.emit("Nobody has thieves' tools.")
		return false
	var t: D20Test
	var who: Character
	if picker != null:
		who = picker
		var adv: Array[String] = []
		var bonus := _pick_bonus(picker, adv)
		t = picker.roll_d20(view.dice, D20Test.Kind.ABILITY_CHECK, bonus, dc, picker.check_keys(&"dex"), adv, [], "%s picks the lock" % picker.name)
	else:
		who = LocationParty._best(view, &"athletics")
		t = who.roll_check(view.dice, &"athletics", dc + 2, CheckAids.before_check(who, &"athletics"), [], "%s forces it" % who.name)
	view.check_rolled.emit(t.describe())
	view.st.last_check = t.success
	if t.success:
		(view.st.loc_state(view.loc_id)["doors"] as Dictionary)[id] = "unlocked"
		Audio.sfx("unlock")
		view._say("check:unlock:success", who)
		return true
	view._say("check:unlock:failure", who, "It holds.")
	view.st.advance_minutes(1)
	return false


## Knock (2024): the lock opens, with a knock heard 300 feet away. Spends the caster's lowest slot that works.
static func _knock(view: LocationView, spec: Dictionary) -> bool:
	var caster := _knock_caster(view)
	if caster == null:
		view.narration.emit("Nobody can cast Knock.")
		return false
	var res := FieldCasting.cast_utility(view.st, caster, "knock", false)
	if not bool(res["ok"]):
		view.toast.emit(str(res["text"]))
		return false
	(view.st.loc_state(view.loc_id)["doors"] as Dictionary)[str(spec["id"])] = "unlocked"
	Audio.sfx("unlock")
	view.toast.emit("%s casts Knock. A loud knock, and the lock gives." % caster.name.get_slice(" ", 0))
	return true


## Chime of Opening (2024 DMG): struck as a Magic action, its clear note opens one lock or latch. Ten uses, then it
## cracks and is useless.
static func _chime(view: LocationView, spec: Dictionary) -> bool:
	var ch := _item_holder(view, "chime_of_opening")
	if ch == null or ch.charges_left("chime_of_opening") <= 0:
		view.narration.emit("Nobody has a Chime of Opening that still rings.")
		return false
	ch.spend_charges("chime_of_opening", 1)
	(view.st.loc_state(view.loc_id)["doors"] as Dictionary)[str(spec["id"])] = "unlocked"
	Audio.sfx("unlock")
	var text := "%s strikes the chime. A clear note rings out, and the lock springs open." % ch.name.get_slice(" ", 0)
	if ch.charges_left("chime_of_opening") <= 0:
		ch.remove_one("chime_of_opening")
		text += " The chime cracks; it won't ring again."
	view.toast.emit(text)
	return true


## Mystery Key (2024 DMG): a 5 percent chance to open any lock it's tried in, and once it does, the key is gone. Each
## lock gets one try (docs/rules/deviations.md).
static func _mystery_key(view: LocationView, spec: Dictionary) -> bool:
	var ch := _item_holder(view, "mystery_key")
	if ch == null:
		view.narration.emit("Nobody carries the Mystery Key.")
		return false
	var ls := view.st.loc_state(view.loc_id)
	if not ls.has("mystery_key_tried"):
		ls["mystery_key_tried"] = {}
	(ls["mystery_key_tried"] as Dictionary)[str(spec["id"])] = true
	var roll := view.dice.roll_one(100, "Mystery Key")
	if roll > 5:
		view.toast.emit("%s tries the Mystery Key, but it won't turn (d100 %d; it needs 5 or less)." % [ch.name.get_slice(" ", 0), roll])
		return false
	(ls["doors"] as Dictionary)[str(spec["id"])] = "unlocked"
	ch.remove_one("mystery_key")
	Audio.sfx("unlock")
	view.toast.emit("%s tries the Mystery Key and it turns (d100 %d)! The lock opens, and the key vanishes." % [ch.name.get_slice(" ", 0), roll])
	return true


## The living party member carrying `item_id` (not packed in a bag), or null.
static func _item_holder(view: LocationView, item_id: String) -> Character:
	for ch in view.st.party:
		if ch.hp > 0 and not ch.dead and not ch.entry_of(item_id).is_empty():
			return ch
	return null


## The living party member who has Knock ready and a 2nd-level or higher slot to cast it with, or null.
static func _knock_caster(view: LocationView) -> Character:
	for ch in view.st.party:
		if ch.hp <= 0 or ch.dead or not ch.known_spells().any(func(k: Dictionary) -> bool: return str(k["id"]) == "knock"):
			continue
		for l in range(2, 10):
			if ch.slots_left(l) > 0:
				return ch
	return null


## The right-click menu's ways to open a lock: the key, Pick the lock, Force it, Cast Knock (each greyed out with the
## reason when it can't be tried). [] when none apply, so it needs its key and nobody has it.
static func actions_to_unlock(view: LocationView, spec: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var key := str(spec.get("key", ""))
	if key != "":
		var has := view.st.party_has_item(key)
		out.append({"id": "key", "label": "Unlock with the %s" % Compendium.shared().display_name("items", key),
			"enabled": has, "why": "" if has else "Nobody carries the key"})
	if int(spec.get("lock_dc", 15)) > 0:
		var picker := _lock_picker(view)
		if picker != null:
			var adv: Array[String] = []
			var b := _pick_bonus(picker, adv)
			out.append({"id": "pick", "label": "Pick the lock (%s, %s%s)" % [picker.name.get_slice(" ", 0), b.signed(),
				", Advantage" if not adv.is_empty() else ""]})
		else:
			out.append({"id": "pick", "label": "Pick the lock", "enabled": false, "why": "Nobody has thieves' tools"})
		var strong := LocationParty._best(view, &"athletics")
		out.append({"id": "force", "label": "Force it (%s, Athletics %s, harder than picking)" % [strong.name.get_slice(" ", 0),
			strong.skill_bonus(&"athletics").signed()]})
	var caster := _knock_caster(view)
	if caster != null:
		out.append({"id": "knock", "label": "Cast Knock (%s)" % caster.name.get_slice(" ", 0)})
	# Magic items that open locks (ADR 0012): a Chime of Opening's note, a Mystery Key's long odds.
	var chime := _item_holder(view, "chime_of_opening")
	if chime != null:
		var left := chime.charges_left("chime_of_opening")
		out.append({"id": "chime", "label": "Strike the Chime of Opening (%s, %d %s left)" % [chime.name.get_slice(" ", 0), left,
			"use" if left == 1 else "uses"], "enabled": left > 0, "why": "" if left > 0 else "The chime is spent"})
	var mkey := _item_holder(view, "mystery_key")
	if mkey != null:
		var tried := bool((view.st.loc_state(view.loc_id).get("mystery_key_tried", {}) as Dictionary).get(str(spec["id"]), false))
		out.append({"id": "mystery_key", "label": "Try the Mystery Key (%s, 1 in 20)" % mkey.name.get_slice(" ", 0),
			"enabled": not tried, "why": "" if not tried else "It wouldn't turn in this lock"})
	return out


## The living party member best at picking locks (thieves' tools in hand, the best bonus), or null.
static func _lock_picker(view: LocationView) -> Character:
	var picker: Character = null
	var best := -99
	for ch in view.st.party:
		if ch.hp > 0 and view.st.member_matches(ch, "item:thieves_tools"):
			var adv: Array[String] = []
			var total := _pick_bonus(ch, adv).total()
			if picker == null or total > best:
				picker = ch
				best = total
	return picker


## 2024 Thieves' Tools: Dexterity check + Proficiency Bonus with the tools, Advantage with Sleight of Hand too.
static func _pick_bonus(picker: Character, adv: Array[String]) -> Breakdown:
	var bonus := picker.ability_check_bonus(&"dex")
	if picker.has_proficiency("tools", "thieves_tools"):
		bonus.add("Thieves' Tools proficiency", picker.proficiency_bonus())
		if picker.skill_rank(&"sleight_of_hand") > 0:
			adv.append("Sleight of Hand proficiency")
	# Gloves of Thievery: +5 to Dexterity checks to pick locks.
	if picker.has_flag("lockpick_plus_5"):
		bonus.add("Gloves of Thievery", 5)
	return bonus
