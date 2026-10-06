class_name DialoguePathBot
extends RefCounted
## Test support (Phase 5 exit): plays a conversation toward a goal statement (`tarokka give <place>`, `join <npc>`),
## picking at every menu an enabled option from which the goal can still be reached by the files' jumps, and trying
## again with other dice when a check sends it the wrong way. `done` says whether the goal happened.

var trace: Array[String] = []
var _memo: Dictionary = {}
var _dist: Dictionary = {}
var _taken: Dictionary = {}


## "file/key:node" for a jump target written in `file_key`.
static func full_ref(ref: String, file_key: String) -> String:
	if ref == "" or ref == "END":
		return ref
	if ref.contains("/") and ref.contains(":"):
		return ref
	return "%s:%s" % [file_key, ref]


static func _split(ref: String) -> Array[String]:
	var i := ref.rfind(":")
	return [ref.substr(0, i), ref.substr(i + 1)]


static func _stmts(ref: String) -> Array:
	var parts := _split(ref)
	var f := DialogueFile.load_key(parts[0])
	if f == null:
		return []
	return f.nodes.get(parts[1], []) as Array


## Whether a statement satisfying `goal` can be reached from node `ref` (any branch, conditions ignored).
func reaches(ref: String, goal: Callable) -> bool:
	return _reaches(ref, goal, {})


func _reaches(ref: String, goal: Callable, seen: Dictionary) -> bool:
	if ref == "" or ref == "END" or seen.has(ref):
		return false
	if _memo.has(ref):
		return bool(_memo[ref])
	seen[ref] = true
	var file_key := _split(ref)[0]
	var hit := false
	for s: Variant in _stmts(ref):
		var st_ := s as Dictionary
		if bool(goal.call(st_)):
			hit = true
			break
		for k: String in ["ok", "fail", "to"]:
			var target := str(st_.get(k, ""))
			if target != "" and _reaches(full_ref(target, file_key), goal, seen):
				hit = true
				break
		if hit:
			break
	_memo[ref] = hit
	return hit


## Plays from `start_ref` until `done` holds (true) or every try ran out (false).
func play(st: StoryState, start_ref: String, goal: Callable, done: Callable, tries: int = 8) -> bool:
	for t in tries:
		_taken.clear()
		var r := DialogueRunner.new(st, DiceRoller.new(1000 + t))
		r.start(start_ref)
		for step in 400:
			if bool(done.call()):
				return true
			var b := r.next()
			var kind := str(b.get("kind", ""))
			if kind == "end" or r.finished and kind == "":
				break
			if kind == "options":
				var pick := _choose(r, goal)
				if pick < 0:
					trace.append("%s: no option leads on (%s)" % [start_ref, ", ".join((b["options"] as Array).map(func(o: Variant) -> String: return str((o as Dictionary)["text"])))])
					break
				trace.append("%s: %s" % [start_ref, str(((b["options"] as Array)[pick] as Dictionary)["text"])])
				r.choose(pick)
			elif kind == "pick_member":
				r.pick_member(0)
		if bool(done.call()):
			return true
	return false


## The enabled option that gets to the goal in the fewest steps; options already taken this run count as a step
## further, so the bot doesn't circle a menu.
func _choose(r: DialogueRunner, goal: Callable) -> int:
	var file_key := r.file.key if r.file != null else ""
	var best := -1
	var best_d := 1 << 30
	for i in r._options.size():
		var o := r._options[i] as Dictionary
		if not bool(o["enabled"]):
			continue
		for k: String in ["ok", "fail"]:
			var target := str(o.get(k, ""))
			if target == "":
				continue
			var d := distance(full_ref(target, file_key), goal)
			if d < 0:
				continue
			if _taken.has(str(o["text"])):
				d += 3
			if d < best_d:
				best_d = d
				best = i
	if best >= 0:
		_taken[str((r._options[best] as Dictionary)["text"])] = true
	return best


## Fewest node hops from `ref` to a node holding the goal (0 = it's here), or -1.
func distance(ref: String, goal: Callable) -> int:
	var key := ref
	if _dist.has(key):
		return int(_dist[key])
	var frontier: Array[String] = [ref]
	var seen := {ref: true}
	var d := 0
	while not frontier.is_empty() and d < 60:
		var next_frontier: Array[String] = []
		for node in frontier:
			var file_key := _split(node)[0]
			for s: Variant in _stmts(node):
				var st_ := s as Dictionary
				if bool(goal.call(st_)):
					_dist[key] = d
					return d
				for k: String in ["ok", "fail", "to"]:
					var t := str(st_.get(k, ""))
					if t == "" or t == "END":
						continue
					var full := full_ref(t, file_key)
					if not seen.has(full):
						seen[full] = true
						next_frontier.append(full)
		frontier = next_frontier
		d += 1
	_dist[key] = -1
	return -1
