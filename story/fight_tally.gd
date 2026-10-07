class_name FightTally
extends RefCounted
## What each creature did in one fight, read from the encounter's combat log once it's over (N1's results, N8's run
## stats): damage dealt and taken, kills, Critical Hits, natural 20s and 1s, hits and misses, falls and deaths. The
## log holds every roll's full line (D20Test.describe) and every hit with its source, so nothing in the rules has
## to count for it.

const KEYS: Array[String] = ["damage_dealt", "damage_taken", "kills", "crits", "nat20", "nat1", "hits", "misses", "downs",
	"died"]


## {combatant id: {name, side, damage_dealt, damage_taken, kills, crits, nat20, nat1, hits, misses, downs, died}}.
## A kill goes to whoever dealt the blow that killed (the last hit logged before the death).
static func tally(e: Encounter) -> Dictionary:
	var out := {}
	var by_name := {}
	for c in e.combatants:
		by_name[c.name()] = c.id
		var row := {"name": c.name(), "side": str(c.side)}
		for k in KEYS:
			row[k] = 0
		out[c.id] = row
	var last_hitter := ""
	for en in e.log.entries:
		var kind := str(en["kind"])
		var actor := str(en["actor"])
		var details := en["details"] as Array
		for d: Variant in details:
			var r := read_roll(str(d))
			var who := str(by_name.get(str(r.get("roller", "")), ""))
			if who == "":
				continue
			var row := out[who] as Dictionary
			match int(r["natural"]):
				20:
					row["nat20"] = int(row["nat20"]) + 1
				1:
					row["nat1"] = int(row["nat1"]) + 1
			match str(r["outcome"]):
				"critical hit":
					row["crits"] = int(row["crits"]) + 1
					row["hits"] = int(row["hits"]) + 1
				"hit":
					row["hits"] = int(row["hits"]) + 1
				"miss":
					row["misses"] = int(row["misses"]) + 1
		match kind:
			"hit":
				last_hitter = actor
				var taken := read_taken(details)
				var target := str(by_name.get(str(taken.get("name", "")), ""))
				var amount := int(taken.get("amount", 0))
				if amount <= 0:
					continue
				if out.has(actor) and actor != target:
					out[actor]["damage_dealt"] = int(out[actor]["damage_dealt"]) + amount
				if out.has(target):
					out[target]["damage_taken"] = int(out[target]["damage_taken"]) + amount
			"death":
				var text := str(en["text"])
				if not out.has(actor):
					continue
				if text.ends_with("falls unconscious"):
					out[actor]["downs"] = int(out[actor]["downs"]) + 1
				elif not text.contains(" changes into ") and out.has(last_hitter) and last_hitter != actor:
					out[last_hitter]["kills"] = int(out[last_hitter]["kills"]) + 1
	for c in e.combatants:
		if c.creature.dead and not e.legendary.departed.has(c.id):
			out[c.id]["died"] = 1
	return out


## One d20 line from the log ("Wren → Zombie 4 (Spear): d20 6 + 5 = 11 vs AC 8, hit", "Dexterity save vs Sacred Flame
## (Zombie 4): d20 16 - 2 = 14 vs DC 13, success", "...: d20 adv [Pack Tactics] (13, 1) + 4 = ..."): {roller (a
## name), natural (the d20 kept), outcome ("critical hit", "hit", "miss", "success", "failure")}; {} for other lines.
static func read_roll(line: String) -> Dictionary:
	var at := line.find(": d20 ")
	if at < 0:
		return {}
	var head := line.substr(0, at)
	var roller := ""
	var arrow := head.find(" → ")
	if arrow >= 0:
		roller = head.substr(0, arrow)
	elif head.ends_with(")") and head.rfind("(") >= 0:
		roller = head.substr(head.rfind("(") + 1, head.length() - head.rfind("(") - 2)
	if roller == "":
		return {}
	var rest := line.substr(at + 6)
	var natural := 0
	if rest.begins_with("adv") or rest.begins_with("dis"):
		var open := rest.find("(")
		var close := rest.find(")", open)
		if open < 0 or close < 0:
			return {}
		var pair := rest.substr(open + 1, close - open - 1).split(",")
		if pair.size() != 2:
			return {}
		var a := pair[0].strip_edges().to_int()
		var b := pair[1].strip_edges().to_int()
		natural = maxi(a, b) if rest.begins_with("adv") else mini(a, b)
	else:
		natural = rest.get_slice(" ", 0).to_int()
	var outcome := ""
	var comma := line.rfind(", ")
	if comma >= 0:
		outcome = line.substr(comma + 2).get_slice(" (", 0).strip_edges()
	return {"roller": roller, "natural": natural, "outcome": outcome}


## Who took how much from a hit's detail lines ("Zombie 4 takes 11 Piercing damage, and dies"): {name, amount}.
static func read_taken(details: Array) -> Dictionary:
	for i in range(details.size() - 1, -1, -1):
		var line := str(details[i])
		var at := line.find(" takes ")
		if at <= 0:
			continue
		var amount := line.substr(at + 7).get_slice(" ", 0)
		if amount.is_valid_int():
			return {"name": line.substr(0, at), "amount": amount.to_int()}
	return {}


## The rows for one side ("party" includes guests), in the order they joined the fight.
static func side_rows(e: Encounter, t: Dictionary, side: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in e.combatants:
		var s := str(c.side)
		if s == side or (side == "party" and s == "guest"):
			out.append(t[c.id] as Dictionary)
	return out
