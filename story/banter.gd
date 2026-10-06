class_name Banter
extends RefCounted
## Party banter while exploring (plan §5.4, §5.7): short exchanges in narrative/banter/*.dialogue, one node each,
## written with interjections so only the party members who are present speak. Each plays once per playthrough;
## the world asks for one now and then (on entering an area), and an exchange that would come out empty is skipped.

var _nodes: Array[String] = []      ## "banter/<file>:<node>"
## Cosmetic randomness for which exchange plays (never a rules roll).
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 11) -> void:
	_rng.seed = seed_value
	var dir := DirAccess.open(DialogueFile.ROOT + "banter")
	if dir == null:
		return
	for f in dir.get_files():
		if not f.ends_with(".dialogue"):
			continue
		var df := DialogueFile.load_key("banter/" + f.get_basename())
		if df == null:
			continue
		for node in df.order:
			_nodes.append("%s:%s" % [df.key, node])


## The lines of an unplayed exchange that suits the party now ([{name, text, narrator, portrait}]), or [] if none.
## Marks it played.
func next(st: StoryState, region: String = "") -> Array[Dictionary]:
	var pool: Array[String] = []
	for ref in _nodes:
		if bool(st.flags.get("_banter/" + ref, false)):
			continue
		if region != "" and not ref.begins_with("banter/" + region) and not ref.begins_with("banter/party"):
			continue
		pool.append(ref)
	while not pool.is_empty():
		var ref := pool.pop_at(_rng.randi_range(0, pool.size() - 1)) as String
		var lines := _lines(ref, st)
		if not lines.is_empty():
			st.flags["_banter/" + ref] = true
			return lines
	return []


static func _lines(ref: String, st: StoryState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	if not r.start(ref):
		return out
	for i in 40:
		var b := r.next()
		match str(b["kind"]):
			"line":
				out.append({"name": str(b["name"]), "text": str(b["text"]), "narrator": bool(b["narrator"]), "portrait": str(b["portrait"]),
					"speaker_id": str(b["speaker_id"]), "party": bool(b["party"])})
			"end":
				break
			"options", "check":
				return []
	return out
