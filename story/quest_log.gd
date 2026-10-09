class_name QuestLog
extends RefCounted
## The quest journal (plan §5.5): every quest the party has started, with the journal text of each stage reached,
## in order, its current objectives, and whether it ended.


## [{id, name, summary, entries: [text], objectives: [text], hint, status: active|success|failure}]: active first,
## each part in the order the quests last moved (oldest first, so the HUD's newest objective is the last open one),
## never the dictionary's order: a save writes its keys sorted, so after a load that was alphabetical (Storyline QA,
## 2026-10-08). `hint` is the current stage's what-to-do-next, for an open quest only.
static func journal(st: StoryState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for qid: String in st.quests:
		var q := Compendium.shared().get_entry("quests", qid)
		if q.is_empty():
			continue
		var entry := st.quests[qid] as Dictionary
		var hist := entry.get("history", []) as Array
		var entries: Array[String] = []
		var objectives: Array[String] = []
		var status := "active"
		var hint := ""   # what to do next (the stage's `hint`): the journal shows it only when asked
		for s: Variant in q.get("stages", []):
			var stage := s as Dictionary
			if str(stage["id"]) in hist:
				entries.append(Tarokka.fill(str(stage["journal"]), st))
			if str(stage["id"]) == str(entry.get("stage", "")):
				for o: Variant in stage.get("objectives", []):
					objectives.append(Tarokka.fill(str(o), st))
				hint = Tarokka.fill(str(stage.get("hint", "")), st)
				if str(stage.get("ends", "")) != "":
					status = str(stage["ends"])
		out.append({"id": qid, "name": str(q["name"]), "summary": str(q.get("summary", "")), "entries": entries,
			"objectives": objectives, "hint": hint if status == "active" else "", "status": status,
			"_at": float(entry.get("at", 0))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_open := str(a["status"]) == "active"
		if a_open != (str(b["status"]) == "active"):
			return a_open
		if float(a["_at"]) != float(b["_at"]):
			return float(a["_at"]) < float(b["_at"])
		return str(a["id"]) < str(b["id"]))
	for q in out:
		q.erase("_at")
	return out
