class_name CombatLog
extends RefCounted
## The combat log (plan §5.3 "visible dice and math"): one readable line per thing that happened, each with the
## full calculation as detail lines the HUD shows when the line is opened.

## {round, actor, kind, text, details: Array[String]}. kind: roll, hit, miss, damage, heal, condition, spell,
## move, turn, reaction, death, info, warn, narr.
var entries: Array[Dictionary] = []
var round_no: int = 0


func add(kind: String, text: String, actor: String = "", details: Array = []) -> Dictionary:
	var d: Array[String] = []
	for x: Variant in details:
		d.append(str(x))
	var e := {"round": round_no, "actor": actor, "kind": kind, "text": text, "details": d}
	entries.append(e)
	return e


func last(n: int = 1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(maxi(0, entries.size() - n), entries.size()):
		out.append(entries[i])
	return out


func texts() -> Array[String]:
	var out: Array[String] = []
	for e in entries:
		out.append(str(e["text"]))
	return out


func dump() -> String:
	var lines: Array[String] = []
	for e in entries:
		lines.append("[R%d] %s" % [int(e["round"]), e["text"]])
		for d: String in e["details"]:
			lines.append("        " + d)
	return "\n".join(lines)
