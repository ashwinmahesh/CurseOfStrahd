class_name CampTalk
extends RefCounted
## Camp conversations (docs/story/personal_quests.md): after a Long Rest a companion may ask for a word, the way a
## good table lets a character's own story breathe between sessions. Each node of narrative/camp/*.dialogue is one
## talk; its first statement is `if <condition>` (who is asking, and when), and the talk is offered once its
## condition holds, plays once per playthrough, and at most one per file (one per companion) is offered at a time.
## The rest screen shows them as buttons; choosing one starts the conversation.

const FOLDER := "camp"


## Talks that could start now: [{ref: "camp/<file>:<node>", label: "Ilse wants a word"}].
static func available(st: StoryState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(DialogueFile.ROOT + FOLDER)
	if dir == null:
		return out
	var files := Array(dir.get_files())
	files.sort()
	for f: String in files:
		if not f.ends_with(".dialogue"):
			continue
		var df := DialogueFile.load_key(FOLDER + "/" + f.get_basename())
		if df == null:
			continue
		for node in df.order:
			var ref := "%s:%s" % [df.key, node]
			if bool(st.flags.get("_camp/" + ref, false)):
				continue
			var cond := opening_condition(df, node)
			if cond == "" or not StoryConditions.check(cond, st):
				continue
			out.append({"ref": ref, "label": label_for(cond, st)})
			break
	return out


## Marks a talk as had, so it isn't offered again.
static func mark(st: StoryState, ref: String) -> void:
	st.flags["_camp/" + ref] = true


## The `if` condition a talk opens with, or "" if it doesn't open with one (then it's never offered).
static func opening_condition(df: DialogueFile, node: String) -> String:
	var list := df.nodes.get(node, []) as Array
	if list.is_empty():
		return ""
	var first := list[0] as Dictionary
	return str(first.get("cond", "")) if str(first.get("t", "")) == "if" else ""


## "<First name> wants a word", for the first `name:` in the condition who is in the party.
static func label_for(cond: String, st: StoryState) -> String:
	var re := RegEx.create_from_string("name:([a-z0-9_]+)")
	for m in re.search_all(cond):
		var who := st.find_member("name:" + m.get_string(1))
		if who != null:
			return "%s wants a word" % who.name.get_slice(" ", 0)
	return "Someone wants a word"
