class_name Banter
extends RefCounted
## Party banter while exploring (plan §5.4, §5.7): short exchanges in narrative/banter/*.dialogue, one node each,
## written with interjections so only the party members who are present speak. Each plays once per playthrough;
## the world asks for one now and then (on entering an area), and an exchange that would come out empty is skipped.
##
## Guests have lines of their own while they travel with the party (narrative/banter/guest_<id>.dialogue, owner
## 2026-10-12): the node's name says when one may play (GUEST_MOMENTS), and only while that guest is with the party.

## Which of a guest's nodes each moment draws on, in order: entering an area plays a line about where their own story
## stands before one about the place; a won fight and a long walk have their own.
const GUEST_MOMENTS := {"enter": ["quest_", "place_"], "fight": ["fight_"], "idle": ["idle_"]}
## The sentient blade speaks as a guest while carried (narrative/banter/guest_sunsword.dialogue).
const SUNSWORD := "sunsword"
const SUNSWORD_STASH := "idle_stash"

var _nodes: Array[String] = []      ## "banter/<file>:<node>"
var _guest_nodes: Array[String] = []   ## "banter/guest_<id>:<node>"
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
			(_guest_nodes if f.begins_with("guest_") else _nodes).append("%s:%s" % [df.key, node])


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


## A cosmetic chance (whether a moment gets a line at all; never a rules roll).
func roll(chance: float) -> bool:
	return _rng.randf() < chance


## An unplayed line of a guest who's with the party, for a moment of GUEST_MOMENTS ("enter", "fight", "idle"), or []
## if none suits. Marks it played. `only`: just that guest's (a word with them, GuestTalk).
func guest_next(st: StoryState, moment: String, only: String = "") -> Array[Dictionary]:
	for prefix: String in GUEST_MOMENTS.get(moment, []) as Array:
		var pool: Array[String] = []
		for ref in _guest_nodes:
			if bool(st.flags.get("_banter/" + ref, false)) or not ref.get_slice(":", 1).begins_with(prefix):
				continue
			var who := ref.get_slice(":", 0).trim_prefix("banter/guest_")
			if _with_party(st, who, ref.get_slice(":", 1)) and (only == "" or who == only):
				pool.append(ref)
		while not pool.is_empty():
			var ref := pool.pop_at(_rng.randi_range(0, pool.size() - 1)) as String
			var lines := _lines(ref, st)
			if not lines.is_empty():
				st.flags["_banter/" + ref] = true
				return lines
	return []


## Whether `id` has a guest's lines now: a story ally travelling with the party, or the Sunsword (NPC plan, Part D), the
## sentient blade, while somebody carries it. Its `idle_stash` lines play while it lies in the party's stash instead.
static func _with_party(st: StoryState, id: String, node: String) -> bool:
	if id != SUNSWORD:
		return id in st.guest_ids
	var carried := st.find_member("item:" + SUNSWORD) != null
	if node.begins_with(SUNSWORD_STASH):
		return not carried and st.party_has_item(SUNSWORD)
	return carried


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
