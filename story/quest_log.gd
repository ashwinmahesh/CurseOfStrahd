class_name QuestLog
extends RefCounted
## The quest journal (plan §5.5): every quest the party has started, with the journal text of each stage reached,
## in order, its current objectives, and whether it ended.


## [{id, name, summary, entries: [text], objectives: [text], hint, status: active|success|failure, kind: main|other,
## tracked, at}]: active first, each part in the order the quests last moved (oldest first, so the HUD's newest
## objective is the last open one), never the dictionary's order: a save writes its keys sorted, so after a load that
## was alphabetical (Storyline QA, 2026-10-08). `hint` is the current stage's what-to-do-next, for an open quest only.
## `kind` is the journal tab it's under; `tracked` is true for the open quest the party follows (track); `at` is when
## it last moved.
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
			"kind": kind(qid), "tracked": status == "active" and bool(entry.get("tracked", false)),
			"at": float(entry.get("at", 0))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_open := str(a["status"]) == "active"
		if a_open != (str(b["status"]) == "active"):
			return a_open
		if float(a["at"]) != float(b["at"]):
			return float(a["at"]) < float(b["at"])
		return str(a["id"]) < str(b["id"]))
	return out


## The journal tab a quest is under: "main" for the story's spine (the quest's `kind`), "other" for side quests and
## the companions' own.
static func kind(quest_id: String) -> String:
	return "main" if str(Compendium.shared().get_entry("quests", quest_id).get("kind", "")) == "main" else "other"


## The quest the party follows (the journal's Track): the HUD shows its objective. "" when none is, or it's over.
static func tracked(st: StoryState) -> String:
	for q in journal(st):
		if bool(q["tracked"]):
			return str(q["id"])
	return ""


## Follows `quest_id` (only one at a time; "" follows none, and the HUD goes back to the newest open quest). The mark
## lives in the quest's own entry, so it's saved with the story.
static func track(st: StoryState, quest_id: String) -> void:
	for qid: String in st.quests:
		(st.quests[qid] as Dictionary).erase("tracked")
	if st.quests.has(quest_id):
		(st.quests[quest_id] as Dictionary)["tracked"] = true
