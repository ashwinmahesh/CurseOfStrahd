class_name Crime
extends RefCounted
## Stealing and crime (F8, and the town watch from F2; docs/rules/stealth.md): who owns what, what a pocket holds, what
## a crime costs, and which towns keep a watch. The story side only: witnesses and the scene are LocationCrime's.
##
## A crime somebody saw lowers the victim's attitude a step (friendly, indifferent, hostile) and, where a town keeps a
## watch, adds an offence to `crime_<region>` (an int flag the watch's dialogue reads: it fines the party, can be
## talked round, or fights). A crime nobody saw costs nothing.

## The towns that keep a watch: region -> the guard who answers a crime there. A location can opt out with
## `"watch": ""` (the Vistani camp, outside Vallaki's walls) or name another guard.
const WATCH := {"vallaki": "vallaki_guard", "krezk": "krezk_guard"}
## Tags of people nobody can pick a pocket from: the dead, spirits, things that aren't people, and Strahd's own.
const NO_POCKETS: Array[String] = ["undead", "ghost", "vestige", "spirit", "construct", "vampire", "vampire_spawn",
	"fiend", "bride_of_strahd", "companions"]
## Coins in a pocket by who carries them (the first tag that matches), else DEFAULT_PURSE.
const PURSES := {"noble": "2d10", "burgomaster": "2d10", "merchant": "2d6", "artisan": "2d6", "vintner": "2d6",
	"guard": "1d6", "soldier": "1d6", "knight": "1d6", "vistani": "1d8", "child": "0"}
const DEFAULT_PURSE := "1d4"
const ATTITUDES: Array[String] = ["hostile", "indifferent", "friendly"]


## The guard who answers a crime in `location` (its `watch`, else its region's), or "" where nobody keeps watch.
static func watch_for(location: Dictionary) -> String:
	if location.has("watch"):
		return str(location["watch"])
	return str(WATCH.get(str(location.get("region", "")), ""))


## The flag that counts a town's unpaid offences.
static func flag_for(region: String) -> String:
	return "crime_" + region


## Who owns a container or prop (its `owner`, an npc id), or "".
static func owner_of(spec: Dictionary) -> String:
	return str(spec.get("owner", ""))


## Records a crime somebody saw against `victim` (an npc id, may be ""): the victim thinks less of the party, and in a
## town with a watch the offence counts. Returns the town's offences now (0 where there's no watch).
static func offence(st: StoryState, location: Dictionary, victim: String) -> int:
	if victim != "":
		lower_attitude(st, victim)
	if watch_for(location) == "":
		return 0
	var flag := flag_for(str(location.get("region", "")))
	var n := int(st.get_flag(flag, 0)) + 1
	st.set_flag(flag, n)
	return n


## One step down: friendly to indifferent, indifferent to hostile.
static func lower_attitude(st: StoryState, npc_id: String) -> void:
	var i := ATTITUDES.find(st.attitude(npc_id))
	st.attitudes[npc_id] = ATTITUDES[maxi(0, i - 1)] if i >= 0 else "hostile"


## Why `npc_id`'s pocket can't be picked ("" if it can): the dead and the inhuman have none, an enemy won't let anyone
## that close, and a pocket already picked is empty.
static func why_no_pocket(st: StoryState, npc_id: String, picked: bool) -> String:
	var npc := Compendium.shared().get_entry("npcs", npc_id)
	for tag: Variant in npc.get("tags", []):
		if str(tag) in NO_POCKETS:
			return "Nothing to pick"
	if npc.has("pockets") and npc["pockets"] is bool and not bool(npc["pockets"]):
		return "Nothing to pick"
	if st.attitude(npc_id) == "hostile":
		return "Won't let you that close"
	if picked:
		return "Already picked"
	return ""


## What `npc_id`'s pocket holds: {gold, items: [{id, qty}]}. Coins by who they are (PURSES), and any `pockets` items
## their data names.
static func pocket(npc_id: String, dice: DiceRoller) -> Dictionary:
	var npc := Compendium.shared().get_entry("npcs", npc_id)
	var purse := DEFAULT_PURSE
	for tag: Variant in npc.get("tags", []):
		if PURSES.has(str(tag)):
			purse = str(PURSES[str(tag)])
			break
	var gold := 0 if purse == "0" else int(dice.roll_expr(purse, "Pocket (%s)" % npc.get("name", npc_id))["total"])
	var items: Array = []
	if npc.get("pockets", []) is Array:
		items = (npc.get("pockets", []) as Array).duplicate(true)
	return {"gold": gold, "items": items}


## The gold value of loot taken: coins plus each item's price.
static func value_of(items: Array, gold: float) -> float:
	var total := gold
	for it: Variant in items:
		var d := it as Dictionary
		total += float(Compendium.shared().item_data(str(d["id"])).get("cost_gp", 0)) * int(d.get("qty", 1))
	return total
