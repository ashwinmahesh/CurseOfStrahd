extends TestCase
## The sidequests lane's quests (every `### Name (`id`, ...)` in docs/story/side_quests.md) stay finishable as the rest
## of the game moves: every stage is set by a dialogue line or a fight, every place a quest uses is on the travel map or
## through an exit from one, every reward is a real item, and every open stage's hint names one of them or a place
## on the travel map.

const STOP := ["the", "of", "and", "on", "in", "to", "at", "by", "under", "from", "with", "into", "back", "down", "up"]


func _quest_ids() -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.new()
	re.compile("(?m)^### [^\\n]*?\\(`([a-z_]+)`")
	for m in re.search_all(FileAccess.get_file_as_string("res://docs/story/side_quests.md")):
		out.append(m.get_string(1))
	return out


func _dialogue_texts(dir: String, out: Dictionary) -> void:
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".dialogue"):
			out[dir.path_join(f)] = FileAccess.get_file_as_string(dir.path_join(f))
	for sub in d.get_directories():
		_dialogue_texts(dir.path_join(sub), out)


func _json_dir(dir: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in DirAccess.open(dir).get_files():
		if f.ends_with(".json"):
			out.append(JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f))) as Dictionary)
	return out


func _words(text: String) -> Array[String]:
	var out: Array[String] = []
	for w in text.replace("'s", "").to_lower().split(" ", false):
		var s := w.strip_edges().trim_suffix(".").trim_suffix(",").trim_suffix(":").trim_prefix("(").trim_suffix(")")
		if s.length() >= 4 and not s in STOP:
			out.append(s)
	return out


func test_every_side_quest_can_be_finished() -> void:
	var ids := _quest_ids()
	assert_true(ids.size() >= 40, "found the lane's quests in the doc (%d)" % ids.size())
	var texts := {}
	_dialogue_texts("res://narrative", texts)
	var locs := {}
	for d in _json_dir("res://data/locations"):
		locs[str(d["id"])] = d
	# The travel map's places, and everything reachable from them through exits.
	var reach := {}
	var names := {}
	var todo: Array = []
	for t in _json_dir("res://data/travel"):
		for p: Variant in t.get("places", []):
			var place := p as Dictionary
			todo.append(str(place["location"]))
			names[str(place["location"])] = str(place["name"])
	while not todo.is_empty():
		var l := str(todo.pop_back())
		if reach.has(l) or not locs.has(l):
			continue
		reach[l] = true
		for x: Variant in (locs[l] as Dictionary).get("exits", []):
			var to := str((x as Dictionary).get("to", ""))
			if to != "" and to != "travel":
				todo.append(to)
	var c := Compendium.shared()
	for qid in ids:
		var q := c.get_entry("quests", qid)
		assert_false(q.is_empty(), "%s is a quest" % qid)
		if q.is_empty():
			continue
		# Which dialogue files move it, and which stages they set.
		var files: Array[String] = []
		var set_stages := {}
		var re := RegEx.new()
		re.compile("(?m)^\\s*quest\\s+" + qid + "\\s+([a-z_0-9]+)")
		for path: String in texts:
			var found := re.search_all(texts[path])
			if not found.is_empty():
				files.append(path.trim_prefix("res://narrative/").trim_suffix(".dialogue"))
				for m in found:
					set_stages[m.get_string(1)] = true
		var places := {}
		for lid: String in locs:
			var d := locs[lid] as Dictionary
			for list: String in ["npcs", "props", "containers"]:
				for x: Variant in d.get(list, []):
					var ref := str((x as Dictionary).get("dialogue", ""))
					if ref.get_slice(":", 0) in files:
						places[lid] = true
			for e: Variant in d.get("encounters", []):
				var mv := (e as Dictionary).get("quest", {}) as Dictionary
				if str(mv.get("id", "")) == qid:
					set_stages[str(mv["stage"])] = true
					places[lid] = true
		assert_false(places.is_empty(), "%s happens somewhere" % qid)
		for s: Variant in q["stages"]:
			var stage := s as Dictionary
			assert_true(set_stages.has(str(stage["id"])), "%s: stage %s is set by a line or a fight" % [qid, stage["id"]])
		var known: Array[String] = []
		for other: String in names:
			known.append_array(_words(str(names[other])))
		for lid: String in places:
			assert_true(reach.has(lid), "%s: %s is on the travel map or through an exit from it" % [qid, lid])
			var d := locs[lid] as Dictionary
			known.append_array(_words(str(d.get("name", ""))))
			for a: Variant in d.get("areas", []):
				known.append_array(_words(str((a as Dictionary).get("name", ""))))
		for s: Variant in q["stages"]:
			var stage := s as Dictionary
			if str(stage.get("ends", "")) != "":
				continue
			var hint := _words(str(stage.get("hint", "")))
			assert_true(hint.any(func(w: String) -> bool: return w in known),
				"%s: the hint for %s names a place (%s)" % [qid, stage["id"], stage.get("hint", "")])
		# Rewards: every item a quest's lines give is a real item.
		var give := RegEx.new()
		give.compile("(?m)^\\s*give\\s+([a-z_0-9]+)")
		for f in files:
			for m in give.search_all(texts["res://narrative/" + f + ".dialogue"]):
				var item := m.get_string(1)
				assert_true(not c.get_entry("magic_items", item).is_empty() or not c.get_entry("items", item).is_empty()
					or item.begins_with("spell_scroll__"), "%s: %s is an item" % [qid, item])
