class_name Recap
extends RefCounted
## "Previously in Barovia" (Q3, docs/ui/saves.md): a game saved a while ago (SaveSystem.RECAP_AFTER) opens with the
## Narrator's box holding a short recap: the Narrator's opening and where the party is (narrative/narrator/recap
## .dialogue, spoken when recorded), the road ahead (the objectives of the quests that moved most recently) and the
## party's last big choice (the newest moment a companion remembers, story/approval.gd). SaveSystem says when one
## is due and calls show_on once the story game has arrived.

## Tests turn it on for a game inside their own scene; otherwise only the game itself shows one (as with autosaves).
static var always := false
## How many objectives the road ahead names.
const GOALS := 2


## Shows the recap in the story game `root` (world/game_root.gd) when a load made one due; anywhere else, nothing.
static func show_on(root: Node) -> void:
	var hud := root.get("hud") as ExploreHud if "hud" in root else null
	var st := root.get("st") as StoryState if "st" in root else null
	var narrator := root.get("narrator") as Narrator if "narrator" in root else null
	if hud == null or st == null or narrator == null or not (always or root.get_tree().current_scene == root):
		return
	if not SaveSystem.take_recap():
		return
	var beats := lines(st, narrator)
	var text: Array[String] = []
	for b in beats:
		text.append(str(b["text"]))
	hud.narrate("\n".join(text))
	# The Narrator speaks what's recorded (the opening and the place), one line after another (ADR 0013).
	hud.hold_narration(VoiceOver.say_all(beats))


## The recap as the Narrator's line beats ({speaker_id, text}): the opening, where the party is, the road ahead and
## the last big choice, each left out when there's nothing to say.
static func lines(st: StoryState, narrator: Narrator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var open := narrator.line("recap:open", st)
	out.append(_beat(open if open != "" else "Previously, in Barovia."))
	var loc := Compendium.shared().get_entry("locations", st.location)
	var where := narrator.line("recap:where:%s" % str(loc.get("region", "")), st) if not loc.is_empty() else ""
	if where == "" and not loc.is_empty():
		where = "You are at %s." % str(loc.get("name", st.location))
	if where != "":
		out.append(_beat(where))
	var goals := road_ahead(st)
	if not goals.is_empty():
		out.append(_beat("Ahead of you:\n%s" % "\n".join(goals.map(func(g: String) -> String: return "◆ " + g))))
	var choice := last_choice(st)
	if choice != "":
		out.append(_beat("Not long ago, %s." % (choice.left(1).to_lower() + choice.substr(1) if choice.begins_with("You ")
			else choice).trim_suffix(".")))
	return out


## The objectives of the quests still open, from the ones that moved most recently (the quest's "at"), at most GOALS.
## An objective offered as another's alternative ("Or ...") isn't named on its own.
static func road_ahead(st: StoryState) -> Array[String]:
	var open: Array[Dictionary] = []
	for id: String in st.quests:
		var entry := st.quests[id] as Dictionary
		var stage := _stage(id, str(entry.get("stage", "")))
		if stage.is_empty() or str(stage.get("ends", "")) != "":
			continue
		open.append({"at": int(entry.get("at", 0)), "objectives": stage.get("objectives", [])})
	open.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at"]) > int(b["at"]))
	var out: Array[String] = []
	for q in open:
		for o: Variant in q["objectives"]:
			var goal := str(o)
			if out.size() < GOALS and not goal.begins_with("Or ") and not goal in out:
				out.append(goal)
	return out


## The newest moment any travelling companion remembers (its "why", "You laid Rose and Thorn to rest"), or "".
static func last_choice(st: StoryState) -> String:
	var best := ""
	var day := -1
	for id: String in Approval.COMPANIONS:
		var mem := Approval.memories(st, id)
		if not mem.is_empty() and int(mem[0].get("day", 0)) > day:
			day = int(mem[0].get("day", 0))
			best = str(mem[0].get("why", ""))
	return best


static func _stage(quest_id: String, stage_id: String) -> Dictionary:
	for s: Variant in Compendium.shared().get_entry("quests", quest_id).get("stages", []):
		if str((s as Dictionary).get("id", "")) == stage_id:
			return s as Dictionary
	return {}


static func _beat(text: String) -> Dictionary:
	return {"speaker_id": VoiceOver.NARRATOR, "text": text}
