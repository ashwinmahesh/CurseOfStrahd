class_name AllyVisitAnswer
extends RefCounted
## Test support (ally visits, docs/regions/strahd_presence.md): how the story bot answers a conversation an ally's visit
## started (a letter, a courier's word, a meeting on the road; data/visits/). The visit is the character reaching for the
## party, not a branch of the story the bot is walking, so the bot leaves by the way out the conversation gives it and
## never opens a menu of errands or starts a fight. That exit is an option that ends the conversation (`-> END`), else
## one whose node asks nothing more and starts no fight, shop or journey. An option with a skill check is never the
## exit (it may fail, and a failed social option is spent).

## Statements that open something the bot's walk didn't ask for.
const NOT_AN_EXIT: Array[String] = ["combat", "move", "end_game", "shop", "services", "respec", "sacrifice", "dark_gift"]


## The index in `opts` (a menu beat's options) of the option to leave by, or -1 when the menu has none. The last
## option of the best kind: the exit is listed last, and one that ends outright beats one that says a last word first.
static func exit_option(runner: DialogueRunner, opts: Array) -> int:
	var targets := runner.get("_options") as Array
	var best := -1
	var best_rank := 2
	for i in opts.size():
		if not bool((opts[i] as Dictionary).get("enabled", true)) or i >= targets.size():
			continue
		var t := targets[i] as Dictionary
		if not (t["check"] as Dictionary).is_empty():
			continue
		var to := str(t["ok"])
		var rank := 2
		if to == "END" or to == "":
			rank = 0
		elif leaves(runner.file.key, to):
			rank = 1
		if rank < 2 and rank <= best_rank:
			best = i
			best_rank = rank
	return best


## Whether going to `ref` (written in the file `file_key`) ends the conversation without another menu, a fight, a shop
## or a journey on the way. Every branch of a jump or a check has to.
static func leaves(file_key: String, ref: String, path: Dictionary = {}) -> bool:
	if ref == "END" or ref == "":
		return true
	var full := DialoguePathBot.full_ref(ref, file_key)
	if path.has(full):
		return false
	var cut := full.rfind(":")
	var f := DialogueFile.load_key(full.substr(0, cut))
	var node := full.substr(cut + 1)
	if f == null or not f.nodes.has(node):
		return false
	var here := path.duplicate()
	here[full] = true
	for s: Dictionary in (f.nodes[node] as Array):
		var kind := str(s["t"])
		if kind == "option" or kind in NOT_AN_EXIT:
			return false
		var onward: Array[String] = []
		if kind == "jump":
			onward.append(str(s["to"]))
		elif kind == "check":
			onward.append(str(s["ok"]))
			onward.append(str(s["fail"]))
		for to: String in onward:
			if to != "" and not leaves(f.key, to, here):
				return false
	return true
