class_name StoryState
extends RefCounted
## Everything about a playthrough's story and party that outlives a scene (plan §4.3 "single game state"): the
## party's characters, money and stash, story flags, quest stages, NPC attitudes, places visited, the codex, the
## Narrator's memory, milestone level-ups, game time, and each location's state (doors, loot, traps, fights).
## Pure data with to_dict()/from_dict(); GameState (core/) holds one and saves it.

var party: Array[Character] = []
## Roster members at camp: the rest of the company, out of the party for now (owner, 2026-10-06: the player swaps
## who travels, up to PARTY_CAP at once, outside fights and conversations). They don't speak in the story, and they
## don't level while they're away (owner, 2026-10-07): they keep their level, and when they rejoin, the player takes
## each level they missed in turn on the level-up screen (levels_waiting).
var bench: Array[Character] = []
## Index into party of the character leading in exploration and speaking in dialogue.
var leader: int = 0
var gold: float = 0.0
var stash: Array[Dictionary] = []          ## [{id, qty}] at safe places
var flags: Dictionary = {}
var quests: Dictionary = {}                ## quest id -> {stage, history: [stage ids]}
var attitudes: Dictionary = {}             ## npc id -> hostile | indifferent | friendly
var visited: Dictionary = {}               ## location or area id -> true
var codex: Array[String] = []              ## lore read (book props, letters)
var narrator: Dictionary = {}              ## trigger key -> {played: [variant indexes], last_minute, done}
var milestones: int = 0                    ## story milestones reached (milestone levelling)
var start_level: int = 1
var day: int = 1
var minute_of_day: int = 18 * 60           ## the party arrives at dusk
var location: String = ""
var positions: Array[Vector2i] = []        ## grid cells of party members in the current location
var location_states: Dictionary = {}      ## location id -> {doors: {id: "open"|"unlocked"}, looted: {}, traps: {id: state}, encounters: {}, props: {}}
## The result of the last check a dialogue or the world made (for `check.last`).
var last_check: bool = false
## Party members lost for good: [{name, id, how, day}] (the roll of honour in the party screen).
var fallen: Array[Dictionary] = []
## The playthrough's seed: it decides the Tarokka reading (and nothing that a die roll decides).
var playthrough_seed: int = 0
## Madam Eva's reading once drawn: {tome, symbol, sword, ally, enemy} -> card id (story/tarokka.gd).
var tarokka: Dictionary = {}
## Story allies travelling with the party (ADR 0010): the npc ids, and their creatures in the same order.
var guest_ids: Array[String] = []
var guests: Array[Creature] = []
## Merchants' stock as it stands: npc id -> {item id: quantity left} (only items with limited stock).
var shops: Dictionary = {}
## A journey interrupted by something on the road: {to: place id, at: place id the party had reached}.
var travel_resume: Dictionary = {}
## Miles travelled since the party's last Long Rest (Mist Walker, a Ravenloft Dark Gift).
var miles_since_long_rest: float = 0.0
## Playthrough options the owner can switch (plan §5.6): respec at Madam Eva.
var options: Dictionary = {"respec": true}
## Exploring spells still running: spell id -> {until: total minute, caster} (Light, Detect Magic, Speak with Dead).
var active_spells: Dictionary = {}


# --- Flags, quests, attitudes ---------------------------------------------------------------------

func get_flag(id: String, default: Variant = false) -> Variant:
	return flags.get(id, default)


func set_flag(id: String, value: Variant = true) -> void:
	flags[id] = value


func quest_stage(quest_id: String) -> String:
	return str((quests.get(quest_id, {}) as Dictionary).get("stage", ""))


## Moves a quest to `stage` (data/quests). Returns false if the quest or stage doesn't exist.
func set_quest_stage(quest_id: String, stage: String) -> bool:
	var q := Compendium.shared().get_entry("quests", quest_id)
	if q.is_empty():
		return false
	var ok := false
	for s: Variant in q.get("stages", []):
		if str((s as Dictionary)["id"]) == stage:
			ok = true
	if not ok:
		return false
	var entry := quests.get(quest_id, {"stage": "", "history": []}) as Dictionary
	entry["stage"] = stage
	var hist := entry.get("history", []) as Array
	if not stage in hist:
		hist.append(stage)
	entry["history"] = hist
	quests[quest_id] = entry
	return true


## The order of a quest's stages, for >= comparisons in conditions (-1 if not reached / unknown).
func quest_stage_index(quest_id: String, stage: String) -> int:
	var q := Compendium.shared().get_entry("quests", quest_id)
	var i := 0
	for s: Variant in q.get("stages", []):
		if str((s as Dictionary)["id"]) == stage:
			return i
		i += 1
	return -1


func attitude(npc_id: String) -> String:
	if attitudes.has(npc_id):
		return str(attitudes[npc_id])
	return str(Compendium.shared().get_entry("npcs", npc_id).get("attitude", "indifferent"))


# --- Party ----------------------------------------------------------------------------------------

func leader_character() -> Character:
	if party.is_empty():
		return null
	return party[clampi(leader, 0, party.size() - 1)]


## The first party member (in marching order) that matches a selector: class:x, species:x, background:x,
## tag:x, name:x, item:x.
func find_member(selector: String) -> Character:
	for ch in party:
		if member_matches(ch, selector):
			return ch
	return null


static func member_matches(ch: Character, selector: String) -> bool:
	var kind := selector.get_slice(":", 0)
	var value := selector.get_slice(":", 1)
	match kind:
		"class":
			return ch.class_level_of(value) > 0
		"species":
			return str(ch.build.get("species", "")) == value or ch.lineage == value
		"background":
			return str(ch.build.get("background", "")) == value
		"tag":
			var identity := ch.build.get("identity", {}) as Dictionary
			return value in (identity.get("tags", []) as Array)
		"name":
			# A custom hero never answers for a pregenerated companion it replaced or shares a name with.
			if bool((ch.build.get("appearance", {}) as Dictionary).get("custom", false)):
				return false
			return ch.id == value or ch.name.to_snake_case() == value
		"item":
			if ch.carries(value):
				return true
		"knows":
			# A spell the character can cast now (prepared, always prepared, or granted): a story beat that needs one.
			return ch.knows_spell(value)
	return false


func party_has_item(item_id: String) -> bool:
	if find_member("item:" + item_id) != null:
		return true
	for e in stash:
		if str(e["id"]) == item_id and int(e["qty"]) > 0:
			return true
	return false


## Gives an item to `ch` (or the stash if nobody's given).
func give_item(item_id: String, qty: int, ch: Character = null) -> void:
	if ch != null:
		ch.add_item(item_id, qty)
		return
	if MagicItems.GENERIC_SCROLLS.has(item_id):
		for i in qty:
			give_item(MagicItems.specific_scroll(item_id, "%d:stash:%d:%d" % [playthrough_seed, stash.size(), i], Compendium.shared()), 1)
		return
	for e in stash:
		if str(e["id"]) == item_id:
			e["qty"] = int(e["qty"]) + qty
			return
	stash.append({"id": item_id, "qty": qty})


## Moves one `item_id` from `ch`'s pack to the party stash (kept at safe places: inns, a home base).
func stash_put(item_id: String, ch: Character) -> bool:
	for e in ch.inventory:
		if str(e["id"]) == item_id and int(e["qty"]) > 0:
			if str(e.get("slot", "")) != "" and int(e["qty"]) <= 1:
				ch.unequip(str(e["slot"]))
			e["qty"] = int(e["qty"]) - 1
			if int(e["qty"]) <= 0:
				ch.inventory.erase(e)
			give_item(item_id, 1)
			return true
	return false


## Moves one `item_id` from the stash to `ch`.
func stash_take(item_id: String, ch: Character) -> bool:
	for e in stash:
		if str(e["id"]) == item_id and int(e["qty"]) > 0:
			e["qty"] = int(e["qty"]) - 1
			if int(e["qty"]) <= 0:
				stash.erase(e)
			ch.add_item(item_id, 1)
			return true
	return false


## Takes up to `qty` of an item from the party (stash last). Returns how many were taken.
func take_item(item_id: String, qty: int) -> int:
	var left := qty
	for ch in party:
		for e: Dictionary in ch.inventory.duplicate():
			if left <= 0:
				break
			if str(e["id"]) == item_id and int(e["qty"]) > 0:
				var n := mini(left, int(e["qty"]))
				e["qty"] = int(e["qty"]) - n
				left -= n
				if int(e["qty"]) <= 0 and str(e.get("slot", "")) == "":
					ch.inventory.erase(e)
	for e: Dictionary in stash.duplicate():
		if left <= 0:
			break
		if str(e["id"]) == item_id:
			var n2 := mini(left, int(e["qty"]))
			e["qty"] = int(e["qty"]) - n2
			left -= n2
			if int(e["qty"]) <= 0:
				stash.erase(e)
	return qty - left


## The highest level the campaign takes the party to (plan §10, Phase 5: 10 or 11 by the Amber Temple).
const LEVEL_CAP := 11


## Milestone levelling (plan §5.6): the level the party may reach now.
func target_level() -> int:
	return mini(LEVEL_CAP, start_level + milestones)


func can_level_up(ch: Character) -> bool:
	return ch.character_level() < target_level()


## How many levels `ch` has to take to reach the party's milestone: one level-up screen each, in order.
func levels_waiting(ch: Character) -> int:
	return maxi(0, target_level() - ch.character_level())


# --- The roster -----------------------------------------------------------------------------------

## Most characters travelling at once.
const PARTY_CAP := 4


## Everyone the player can choose from: the party, then those at camp.
func roster() -> Array[Character]:
	var out: Array[Character] = party.duplicate()
	out.append_array(bench)
	return out


## `incoming` (at camp) takes `outgoing`'s place in the party and marching order; `outgoing` goes to camp.
func swap_members(outgoing: Character, incoming: Character) -> bool:
	var i := party.find(outgoing)
	var j := bench.find(incoming)
	if i < 0 or j < 0 or incoming.dead:
		return false
	party[i] = incoming
	bench[j] = outgoing
	return true


## Someone at camp joins the party at the back, while there's room.
func bring_along(ch: Character) -> bool:
	var j := bench.find(ch)
	if j < 0 or party.size() >= PARTY_CAP or ch.dead:
		return false
	bench.remove_at(j)
	party.append(ch)
	return true


## A party member goes to camp; the party never goes below one.
func send_to_camp(ch: Character) -> bool:
	var i := party.find(ch)
	if i < 0 or party.size() <= 1:
		return false
	party.remove_at(i)
	if positions.size() > i:
		positions.remove_at(i)
	bench.append(ch)
	leader = clampi(leader, 0, party.size() - 1)
	return true


# --- Time -----------------------------------------------------------------------------------------

func total_minutes() -> int:
	return (day - 1) * 24 * 60 + minute_of_day


## A stretch of time worth showing passed (half an hour or more: a rest, a journey, a long wait).
signal time_passed(minutes: int)


func advance_minutes(minutes: int) -> void:
	if minutes >= 30:
		time_passed.emit(minutes)
	var start := total_minutes()
	minute_of_day += minutes
	while minute_of_day >= 24 * 60:
		minute_of_day -= 24 * 60
		day += 1
	for ch in party:
		ch.advance_minutes(minutes)
	# Story allies' spells and Concentration run out with the clock too.
	for g in guests:
		g.advance_minutes(minutes)
	_item_time(start, minutes)


## Magic items and the clock (ADR 0012): charges come back at dawn (or dusk), regeneration heals as time passes. The
## dice are seeded from the playthrough and the hour, so the same rest gives the same result.
func _item_time(start: int, minutes: int) -> void:
	if minutes <= 0:
		return
	var dice := DiceRoller.new(hash("%d:%d:items" % [playthrough_seed, start]))
	for t in range(start + 1, start + minutes + 1):
		var m := t % (24 * 60)
		if m == 6 * 60:
			for ch in party:
				for line in ch.on_dawn(dice):
					item_news.append(line)
		elif m == 18 * 60:
			for ch in party:
				ch.on_dusk(dice)
	for ch in party:
		ch.items_passage(minutes, dice)


## Things items did while time passed (charges back at dawn), for the world to show; drained by whoever shows them.
var item_news: Array[String] = []


## Whether an exploring spell is still running (`spell:light` in conditions).
func spell_active(spell_id: String) -> bool:
	return active_spells.has(spell_id) and int((active_spells[spell_id] as Dictionary)["until"]) > total_minutes()


func is_night() -> bool:
	return minute_of_day < 6 * 60 or minute_of_day >= 19 * 60


# --- Locations ------------------------------------------------------------------------------------

func loc_state(location_id: String) -> Dictionary:
	if not location_states.has(location_id):
		location_states[location_id] = {"doors": {}, "looted": {}, "traps": {}, "encounters": {}, "props": {}, "found": {}}
	return location_states[location_id] as Dictionary


## Madam Eva's respec: `ch` is replaced by `fresh` (built again at level 1), who keeps `ch`'s belongings and place in
## the line; milestones let them level back up.
func respec_member(ch: Character, fresh: Character) -> void:
	var i := party.find(ch)
	if i < 0:
		return
	fresh.inventory = ch.inventory.duplicate(true)
	fresh.refresh()
	fresh.finish_long_rest()
	fresh.id = ch.id
	party[i] = fresh


## Takes `ch` out of the party for good (a sacrifice, a death nobody undoes) and remembers them.
func lose_member(ch: Character, how: String) -> void:
	var i := party.find(ch)
	if i < 0:
		return
	ch.hp = 0
	ch.dead = true
	if ch.concentration != null:
		ch.concentration.end("died")
	party.remove_at(i)
	if positions.size() > i:
		positions.remove_at(i)
	leader = clampi(leader, 0, maxi(0, party.size() - 1))
	fallen.append({"name": ch.name, "id": ch.id, "how": how, "day": day})


# --- Shops (ADR 0010) -----------------------------------------------------------------------------

## What `npc_id` sells now: [{id, name, price, qty (-1 = always)}].
func shop_wares(npc_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var shop := Compendium.shared().get_entry("npcs", npc_id).get("shop", {}) as Dictionary
	var stock := shops.get(npc_id, {}) as Dictionary
	for e: Variant in shop.get("sells", []):
		var w := e as Dictionary
		var stock_id := str(w["id"])
		# A shop's "level 1 spell scroll" is a particular spell, the same one each visit this playthrough.
		var id := MagicItems.specific_scroll(stock_id, "%d:shop:%s" % [playthrough_seed, npc_id], Compendium.shared())
		var data := Compendium.shared().item_data(id)
		var qty := int(w.get("qty", -1))
		if qty >= 0:
			qty = int(stock.get(stock_id, qty))
		if qty == 0:
			continue
		var price := float(w["price"]) if w.has("price") else float(data.get("cost_gp", 0)) * float(shop.get("markup", 1.0))
		out.append({"id": id, "name": str(data.get("name", id)), "price": price, "qty": qty, "stock_id": stock_id})
	return out


## What `npc_id` pays for one `item_id`, or -1 if they don't buy that kind of thing.
func shop_offer(npc_id: String, item_id: String) -> float:
	var shop := Compendium.shared().get_entry("npcs", npc_id).get("shop", {}) as Dictionary
	var data := Compendium.shared().item_data(item_id)
	if data.is_empty() or str(data.get("category", "")) == "quest":
		return -1.0
	var buys := shop.get("buys", []) as Array
	if not buys.is_empty() and not str(data.get("category", "")) in buys:
		return -1.0
	return snappedf(float(data.get("cost_gp", 0)) * float(shop.get("sell_rate", 0.5)), 0.01)


## Buys one `item_id` from `npc_id` for `ch`. Returns "" or why not.
func shop_buy(npc_id: String, item_id: String, ch: Character) -> String:
	for w in shop_wares(npc_id):
		if str(w["id"]) != item_id:
			continue
		if gold < float(w["price"]):
			return "Not enough gold"
		gold -= float(w["price"])
		ch.add_item(item_id, 1)
		if int(w["qty"]) > 0:
			if not shops.has(npc_id):
				shops[npc_id] = {}
			(shops[npc_id] as Dictionary)[str(w.get("stock_id", item_id))] = int(w["qty"]) - 1
		return ""
	return "Not for sale"


## Sells one `item_id` from `ch` to `npc_id`. Returns "" or why not.
func shop_sell(npc_id: String, item_id: String, ch: Character) -> String:
	var offer := shop_offer(npc_id, item_id)
	if offer < 0.0:
		return "They don't buy that"
	for e in ch.inventory:
		if str(e["id"]) == item_id and int(e["qty"]) > 0:
			if str(e.get("slot", "")) != "" and int(e["qty"]) <= 1:
				ch.unequip(str(e["slot"]))
			e["qty"] = int(e["qty"]) - 1
			if int(e["qty"]) <= 0:
				ch.inventory.erase(e)
			gold += offer
			return ""
	return "Not carried"


# --- Guests (ADR 0010) ----------------------------------------------------------------------------

## The creature a story ally fights as: their guest_build stat block (or a pregen-style character at a set level).
static func make_guest(npc_id: String) -> Creature:
	var npc := Compendium.shared().get_entry("npcs", npc_id)
	if npc.is_empty():
		return null
	var gb := npc.get("guest_build", {}) as Dictionary
	var cr: Creature = null
	if gb.has("pregen"):
		var ch := Pregens.build(str(gb["pregen"]), int(gb.get("level", 1)))
		ch.finish_long_rest()
		cr = ch
	else:
		var data := Compendium.shared().monster_data(str(gb.get("monster", npc.get("monster", "commoner"))))
		if data.is_empty():
			return null
		cr = Monster.from_data(data)
	cr.name = str(npc.get("name", npc_id))
	cr.id = "guest_" + npc_id
	return cr


## Adds a story ally to the party's company. Returns false if they're already along or unknown.
func add_guest(npc_id: String) -> bool:
	if npc_id in guest_ids:
		return false
	var cr := StoryState.make_guest(npc_id)
	if cr == null:
		return false
	guest_ids.append(npc_id)
	guests.append(cr)
	return true


func remove_guest(npc_id: String) -> bool:
	var i := guest_ids.find(npc_id)
	if i < 0:
		return false
	guest_ids.remove_at(i)
	guests.remove_at(i)
	return true


func _guests_to_dict() -> Array:
	var out: Array = []
	for i in guest_ids.size():
		out.append({"npc": guest_ids[i], "state": guests[i].state_to_dict()})
	return out


# --- Saving ---------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var members: Array = []
	for ch in party:
		members.append(ch.to_dict())
	var pos: Array = []
	for p in positions:
		pos.append([p.x, p.y])
	var benched: Array = []
	for ch in bench:
		benched.append(ch.to_dict())
	return {"party": members, "bench": benched, "leader": leader, "gold": gold, "stash": stash.duplicate(true), "flags": flags.duplicate(true),
		"quests": quests.duplicate(true), "attitudes": attitudes.duplicate(true), "visited": visited.duplicate(true),
		"codex": codex.duplicate(), "narrator": narrator.duplicate(true), "milestones": milestones, "start_level": start_level,
		"day": day, "minute_of_day": minute_of_day, "location": location, "positions": pos,
		"location_states": location_states.duplicate(true), "last_check": last_check, "fallen": fallen.duplicate(true),
		"seed": playthrough_seed, "tarokka": tarokka.duplicate(), "guests": _guests_to_dict(), "shops": shops.duplicate(true),
		"travel_resume": travel_resume.duplicate(), "active_spells": active_spells.duplicate(true),
		"options": options.duplicate(), "miles_since_long_rest": miles_since_long_rest}


## A pregen loaded from a save wears its look as data/pregens has it now. The six on the roster borrowed other
## characters' art until their own was drawn, and a save made then kept the borrowed `art` (owner report 2026-10-07:
## Kip in Gunther Arasek's portrait, Thistle in Mirabel's). Only the look changes: the build, levels and choices stay
## as saved. A custom hero keeps the look the player made.
static func current_look(ch: Character) -> void:
	var app := (ch.build.get("appearance", {}) as Dictionary).duplicate()
	if bool(app.get("custom", false)):
		return
	var data := Compendium.shared().get_entry("pregens", ch.id)
	if data.is_empty():
		return
	var now := ((data.get("build", {}) as Dictionary).get("appearance", {}) as Dictionary)
	for key: String in ["art", "portrait"]:
		if now.has(key):
			app[key] = now[key]
		else:
			app.erase(key)
	ch.build["appearance"] = app


static func from_dict(d: Dictionary) -> StoryState:
	var st := StoryState.new()
	var saved := {}
	var loaded: Array[Creature] = []
	for m: Variant in d.get("party", []):
		var ch := Character.from_dict(m as Dictionary)
		if ch != null:
			st.party.append(ch)
			loaded.append(ch)
			saved[ch.id] = (m as Dictionary).get("state", {})
	Creature.relink_concentration(loaded, saved)
	for m: Variant in d.get("bench", []):
		var ch := Character.from_dict(m as Dictionary)
		if ch != null:
			st.bench.append(ch)
	for ch in st.roster():
		current_look(ch)
	st.leader = int(d.get("leader", 0))
	st.gold = float(d.get("gold", 0.0))
	for e: Variant in d.get("stash", []):
		st.stash.append((e as Dictionary).duplicate())
	st.flags = (d.get("flags", {}) as Dictionary).duplicate(true)
	st.quests = (d.get("quests", {}) as Dictionary).duplicate(true)
	st.attitudes = (d.get("attitudes", {}) as Dictionary).duplicate(true)
	st.visited = (d.get("visited", {}) as Dictionary).duplicate(true)
	for c: Variant in d.get("codex", []):
		st.codex.append(str(c))
	st.narrator = (d.get("narrator", {}) as Dictionary).duplicate(true)
	st.milestones = int(d.get("milestones", 0))
	st.start_level = int(d.get("start_level", 1))
	st.day = int(d.get("day", 1))
	st.minute_of_day = int(d.get("minute_of_day", 18 * 60))
	st.location = str(d.get("location", ""))
	for p: Variant in d.get("positions", []):
		var a := p as Array
		st.positions.append(Vector2i(int(a[0]), int(a[1])))
	st.location_states = (d.get("location_states", {}) as Dictionary).duplicate(true)
	st.last_check = bool(d.get("last_check", false))
	st.miles_since_long_rest = float(d.get("miles_since_long_rest", 0.0))
	for f: Variant in d.get("fallen", []):
		st.fallen.append((f as Dictionary).duplicate())
	st.playthrough_seed = int(d.get("seed", 0))
	st.tarokka = (d.get("tarokka", {}) as Dictionary).duplicate()
	st.shops = (d.get("shops", {}) as Dictionary).duplicate(true)
	st.travel_resume = (d.get("travel_resume", {}) as Dictionary).duplicate()
	st.active_spells = (d.get("active_spells", {}) as Dictionary).duplicate(true)
	st.options.merge(d.get("options", {}) as Dictionary, true)
	for g: Variant in d.get("guests", []):
		var gd := g as Dictionary
		var cr := StoryState.make_guest(str(gd["npc"]))
		if cr != null:
			cr.state_from_dict(gd.get("state", {}) as Dictionary)
			st.guest_ids.append(str(gd["npc"]))
			st.guests.append(cr)
	_upgrade_durst_spellbook(st)
	return st


## Saves from before found spellbooks listed their spells (owner, 2026-10-07): the Dursts' footlocker in Death House
## held a plain "spellbook". Swap it for the Dursts' book wherever it went: still in the footlocker, carried by
## someone who isn't a Wizard (a Wizard's own book stays theirs), or in the stash.
static func _upgrade_durst_spellbook(st: StoryState) -> void:
	var ls := st.location_states.get("death_house_dungeon_1", {}) as Dictionary
	if ls.is_empty():
		return
	var left := (ls.get("contents", {}) as Dictionary).get("durst_footlocker", {}) as Dictionary
	for it: Variant in left.get("items", []):
		if str((it as Dictionary)["id"]) == "spellbook":
			(it as Dictionary)["id"] = "durst_spellbook"
			return
	if left.is_empty() and not bool((ls.get("looted", {}) as Dictionary).get("durst_footlocker", false)):
		return
	if st.party_has_item("durst_spellbook"):
		return
	var everyone: Array[Character] = []
	everyone.append_array(st.party)
	everyone.append_array(st.bench)
	for ch in everyone:
		if ch.spellbook_class() != "":
			continue
		for e: Dictionary in ch.inventory:
			if str(e["id"]) == "spellbook" and int(e.get("qty", 1)) == 1:
				e["id"] = "durst_spellbook"
				return
	for e: Dictionary in st.stash:
		if str(e["id"]) == "spellbook" and int(e.get("qty", 1)) == 1:
			e["id"] = "durst_spellbook"
			return
