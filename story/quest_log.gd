class_name QuestLog
extends RefCounted
## The quest journal (plan §5.5): every quest the party has started, with the journal text of each stage reached,
## in order, its current objectives, and whether it ended.


## [{id, name, summary, entries: [text], objectives: [text], status: active|success|failure}], active first.
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
		for s: Variant in q.get("stages", []):
			var stage := s as Dictionary
			if str(stage["id"]) in hist:
				entries.append(Tarokka.fill(str(stage["journal"]), st))
			if str(stage["id"]) == str(entry.get("stage", "")):
				for o: Variant in stage.get("objectives", []):
					objectives.append(Tarokka.fill(str(o), st))
				if str(stage.get("ends", "")) != "":
					status = str(stage["ends"])
		out.append({"id": qid, "name": str(q["name"]), "summary": str(q.get("summary", "")), "entries": entries,
			"objectives": objectives, "status": status})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (str(a["status"]) == "active") and (str(b["status"]) != "active"))
	return out
