class_name SideQuestPlay
extends RefCounted
## Test support for the side quests (docs/story/side_quests.md): plays a conversation through the DialogueRunner the
## way a player would, and reads what a location would show for the current story state.


## A party of the given pregens at `level`, in `location` at `hour`.
static func party(ids: Array[String], level: int, location: String, hour: int) -> StoryState:
	var st := StoryState.new()
	for id in ids:
		st.party.append(Pregens.build(id, level))
	st.location = location
	st.minute_of_day = hour * 60
	return st


## Plays `ref`, taking at each menu the first enabled option whose text contains the next of `picks` (in order), and
## the last option once the picks run out. A pick that matches nothing ends the play with a
## {"kind": "missing", "want", "options"} beat (see missing()).
static func play(st: StoryState, ref: String, picks: Array[String] = [], seed: int = 1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r := DialogueRunner.new(st, DiceRoller.new(seed))
	if not r.start(ref):
		out.append({"kind": "missing", "want": ref, "options": []})
		return out
	var b := r.next()
	var left := picks.duplicate()
	for i in 400:
		out.append(b)
		match str(b["kind"]):
			"end":
				break
			"options":
				var opts := b["options"] as Array
				var pick := opts.size() - 1
				if not left.is_empty():
					var want := str(left.pop_front())
					pick = -1
					for j in opts.size():
						if bool((opts[j] as Dictionary)["enabled"]) and str((opts[j] as Dictionary)["text"]).contains(want):
							pick = j
							break
					if pick < 0:
						out.append({"kind": "missing", "want": want,
							"options": opts.map(func(o: Variant) -> String: return str((o as Dictionary)["text"]))})
						break
				b = r.choose(pick)
			_:
				b = r.next()
	return out


## "" when every pick was found, else what was wanted and what was offered.
static func missing(beats: Array[Dictionary]) -> String:
	for b in beats:
		if str(b["kind"]) == "missing":
			return "no option '%s' among %s" % [b["want"], b["options"]]
	return ""


## The fight a conversation ended in ("" if none).
static func combat_of(beats: Array[Dictionary]) -> String:
	return str(beats[-1].get("combat", "")) if not beats.is_empty() else ""


static func text(beats: Array[Dictionary]) -> String:
	var all := ""
	for b in beats:
		all += str(b.get("text", "")) + "\n"
	return all


## The encounter `location` would start for `id` now: the first entry whose condition holds.
static func encounter(st: StoryState, location: String, id: String) -> Dictionary:
	for e: Variant in Compendium.shared().get_entry("locations", location)["encounters"]:
		var enc := e as Dictionary
		if str(enc["id"]) == id and StoryConditions.check(str(enc.get("when", "")), st):
			return enc
	return {}


## Whether a monster entry with that name or id is in the encounter.
static func has_foe(enc: Dictionary, name_or_id: String) -> bool:
	for m: Variant in enc.get("monsters", []):
		var d := m as Dictionary
		if str(d.get("name", "")) == name_or_id or str(d["monster"]) == name_or_id:
			return true
	return false


## The 2024 DMG's XP for the encounter's foes.
static func xp(enc: Dictionary) -> int:
	var total := 0
	for m: Variant in enc.get("monsters", []):
		total += int(Compendium.shared().get_entry("monsters", str((m as Dictionary)["monster"])).get("xp", 0))
	return total


## The dialogue of the first entry for `npc` in `location` whose condition and hours hold ("" if nobody stands there).
static func standing(st: StoryState, location: String, npc: String) -> String:
	for n: Variant in Compendium.shared().get_entry("locations", location)["npcs"]:
		var e := n as Dictionary
		if str(e["npc"]) != npc or not StoryConditions.check(str(e.get("when", "")), st):
			continue
		var hours := e.get("hours", []) as Array
		if not hours.is_empty():
			var h := st.minute_of_day / 60
			var from := int(hours[0])
			var to := int(hours[1])
			var inside := (h >= from and h < to) if from < to else (h >= from or h < to)
			if not inside:
				continue
		return str(e["dialogue"])
	return ""


## Whether a prop (or a container) in `location` shows now.
static func shown(st: StoryState, location: String, id: String) -> bool:
	var loc := Compendium.shared().get_entry("locations", location)
	for list: String in ["props", "containers"]:
		for p: Variant in loc.get(list, []):
			if str((p as Dictionary)["id"]) == id:
				return StoryConditions.check(str((p as Dictionary).get("when", "")), st)
	return false
