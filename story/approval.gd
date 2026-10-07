class_name Approval
extends RefCounted
## Companion approval (F3, docs/story/approval.md): each of the six roster companions keeps a score from -100 to 100
## for how they feel about the party's choices. Dialogue moves it with `approve` (only companions travelling with the
## party see the choice, so only they react), conditions read it (`approval.thistle >= close`), and the party screen
## shows it with what each of them remembers. The tiers open and close things: camp talks, the best endings of their
## personal quests, and romances.
##
## Saved in StoryState.approval: companion id -> {score: int, memories: [{delta, why, day}]}.

## The six roster companions (data/pregens with `roster: true`), in the order the party screen lists them.
const COMPANIONS: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille", "wren_featherfoot",
	"kip_smudgewick"]

const LOWEST := -100
const HIGHEST := 100

## From the top: each tier starts at `min`. A companion starts at 0, Neutral.
const TIERS: Array[Dictionary] = [
	{"id": "devoted", "name": "Devoted", "min": 50, "colour": "gilt_light",
		"says": "Would follow you into the castle and back out again."},
	{"id": "close", "name": "Close", "min": 25, "colour": "gilt",
		"says": "Trusts you with the things that matter most to them."},
	{"id": "warm", "name": "Warm", "min": 10, "colour": "bile",
		"says": "Glad to be travelling with you."},
	{"id": "neutral", "name": "Neutral", "min": -9, "colour": "parchment",
		"says": "Still making up their mind about you."},
	{"id": "doubtful", "name": "Doubtful", "min": -24, "colour": "rose",
		"says": "Has doubts about the way you do things."},
	{"id": "strained", "name": "Strained", "min": -49, "colour": "vampire_red",
		"says": "Won't follow you into what matters most to them until this is mended."},
	{"id": "estranged", "name": "Estranged", "min": LOWEST, "colour": "crimson",
		"says": "Still walks with you. For now."},
]

## Romances between the six (owner, 2026-10-07: approval includes romances; camp/romance_<pair>.dialogue): each pair's
## string flag is "spark", "courting", "together", or "over" when the party steered them apart. Thistle walks one at a
## time (each spark waits for the other to be unset or over).
const ROMANCES: Array[Dictionary] = [
	{"flag": "romance_thistle_wren", "pair": ["thistle", "wren_featherfoot"]},
	{"flag": "romance_godrick_thistle", "pair": ["godrick_pendlebrook", "thistle"]},
	{"flag": "romance_liriel_ratatoille", "pair": ["liriel_dawnsong", "ratatoille"]},
]
## How the party screen words each stage.
const ROMANCE_WORDS := {"spark": "Sweet on %s", "courting": "Courting %s", "together": "Together with %s"}

## A change this big (either way) is "greatly".
const GREAT := 5
## How many moments each companion remembers on the party screen.
const MEMORY := 8


# --- Reading --------------------------------------------------------------------------------------

static func is_companion(id: String) -> bool:
	return id in COMPANIONS


static func score(st: StoryState, id: String) -> int:
	return int((st.approval.get(id, {}) as Dictionary).get("score", 0))


## The tier a score falls in: {id, name, min, colour, says}.
static func tier_for(value: int) -> Dictionary:
	for t in TIERS:
		if value >= int(t["min"]):
			return t
	return TIERS[TIERS.size() - 1]


static func tier(st: StoryState, id: String) -> Dictionary:
	return tier_for(score(st, id))


## A tier's place from the bottom (estranged 0 .. devoted 6), or -1 for an unknown id.
static func rank(tier_id: String) -> int:
	for i in TIERS.size():
		if str(TIERS[i]["id"]) == tier_id:
			return TIERS.size() - 1 - i
	return -1


static func tier_ids() -> Array[String]:
	var out: Array[String] = []
	for t in TIERS:
		out.append(str(t["id"]))
	return out


## The moments a companion remembers, newest first: [{delta, why, day}].
static func memories(st: StoryState, id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var list := (st.approval.get(id, {}) as Dictionary).get("memories", []) as Array
	for i in range(list.size() - 1, -1, -1):
		out.append(list[i] as Dictionary)
	return out


## A companion's romance as it stands: {partner: id, stage: spark | courting | together}, or {} when there's none (or
## it's over).
static func romance(st: StoryState, id: String) -> Dictionary:
	for r in ROMANCES:
		var pair := r["pair"] as Array
		var stage := str(st.get_flag(str(r["flag"]), ""))
		if id in pair and ROMANCE_WORDS.has(stage):
			return {"partner": str(pair[1] if str(pair[0]) == id else pair[0]), "stage": stage}
	return {}


## "Courting Wren", for the party screen, or "".
static func romance_line(st: StoryState, id: String) -> String:
	var r := romance(st, id)
	if r.is_empty():
		return ""
	return str(ROMANCE_WORDS[str(r["stage"])]) % first_name(str(r["partner"]))


## A condition term `approval.<id> <op> <rhs>` (StoryConditions): rhs is a tier id (compared by rank, so `<= strained`
## means strained or worse) or a number (compared with the score). With no operator, Warm or better.
static func compare(st: StoryState, id: String, op: String, rhs: String) -> bool:
	if op == "":
		return rank(str(tier(st, id)["id"])) >= rank("warm")
	var r := rank(rhs)
	var a: float = rank(str(tier(st, id)["id"])) if r >= 0 else score(st, id)
	var b: float = r if r >= 0 else float(rhs)
	match op:
		"==":
			return a == b
		"!=":
			return a != b
		">=":
			return a >= b
		"<=":
			return a <= b
		">":
			return a > b
		"<":
			return a < b
	return false


# --- Changing -------------------------------------------------------------------------------------

## The companions who see a choice made: the six who are travelling with the party, alive (never a custom hero, even
## one who took a companion's name).
static func witnesses(st: StoryState) -> Array[String]:
	var out: Array[String] = []
	for ch in st.party:
		if ch.dead or not is_companion(ch.id):
			continue
		if StoryState.member_matches(ch, "name:" + ch.id):
			out.append(ch.id)
	return out


## Moves a companion's approval by `delta` and remembers why. Returns {id, delta, before, after, tier_before,
## tier_after}.
static func change(st: StoryState, id: String, delta: int, why: String = "") -> Dictionary:
	var entry := (st.approval.get(id, {"score": 0, "memories": []}) as Dictionary).duplicate(true)
	var before := int(entry.get("score", 0))
	var after := clampi(before + delta, LOWEST, HIGHEST)
	entry["score"] = after
	if why != "":
		var mem := entry.get("memories", []) as Array
		mem.append({"delta": delta, "why": why, "day": st.day})
		while mem.size() > MEMORY:
			mem.pop_front()
		entry["memories"] = mem
	st.approval[id] = entry
	return {"id": id, "delta": delta, "before": before, "after": after, "tier_before": str(tier_for(before)["id"]),
		"tier_after": str(tier_for(after)["id"])}


## A dialogue's `approve` (DialogueRunner): each [id, delta] pair moves that companion if they're here to see it.
## Returns the notice ("Godrick approves · Kip disapproves"), or "" if none of them were here.
static func react(st: StoryState, changes: Array, why: String = "") -> String:
	var here := witnesses(st)
	var results: Array[Dictionary] = []
	for c: Variant in changes:
		var pair := c as Array
		var id := str(pair[0])
		if id in here and int(pair[1]) != 0:
			results.append(change(st, id, int(pair[1]), why))
	return notice(results)


static func notice(results: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for r in results:
		var d := int(r["delta"])
		var verb := ("greatly " if absi(d) >= GREAT else "") + ("approves" if d > 0 else "disapproves")
		var line := "%s %s" % [first_name(str(r["id"])), verb]
		if str(r["tier_before"]) != str(r["tier_after"]):
			line += " (now %s)" % str(tier_for(int(r["after"]))["name"])
		parts.append(line)
	return " · ".join(parts)


static func first_name(id: String) -> String:
	return Compendium.shared().display_name("pregens", id).get_slice(" ", 0)


# --- Saving ---------------------------------------------------------------------------------------

## Only the six, with sane numbers: an older save has none, and a hand-edited one can't break the screen.
static func from_save(d: Variant) -> Dictionary:
	var out := {}
	if not d is Dictionary:
		return out
	for id: Variant in (d as Dictionary):
		if not is_companion(str(id)) or not (d as Dictionary)[id] is Dictionary:
			continue
		var e := (d as Dictionary)[id] as Dictionary
		var mem: Array = []
		for m: Variant in e.get("memories", []):
			if m is Dictionary:
				mem.append((m as Dictionary).duplicate())
		out[str(id)] = {"score": clampi(int(e.get("score", 0)), LOWEST, HIGHEST), "memories": mem}
	return out
