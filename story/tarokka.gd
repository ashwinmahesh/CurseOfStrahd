class_name Tarokka
extends RefCounted
## Madam Eva's reading (plan §5.5, ADR 0010): five cards drawn once per playthrough from the playthrough's seed.
## Three come from the common deck (where the Tome of Strahd, the Holy Symbol of Ravenkind and the Sunsword lie), two
## from the high deck (the destined ally, and where Strahd waits in his castle). The deck and what each card means in
## each place of the reading are data (data/tarokka/); this only shuffles, draws and looks things up.

const TREASURES: Array[String] = ["tome", "symbol", "sword"]
const SLOTS: Array[String] = ["tome", "symbol", "sword", "ally", "enemy"]
const SLOT_NAMES := {"tome": "The Tome of Strahd", "symbol": "The Holy Symbol of Ravenkind", "sword": "The Sunsword",
	"ally": "The ally", "enemy": "The enemy"}


## {card id: card} for the whole deck.
static func deck() -> Dictionary:
	var out := {}
	for c: Variant in Compendium.shared().get_entry("tarokka", "cards").get("cards", []):
		out[str((c as Dictionary)["id"])] = c
	return out


static func card(card_id: String) -> Dictionary:
	return deck().get(card_id, {}) as Dictionary


## What `card_id` means in `slot` of the reading: {place, region, verse, hint} for the treasures, {npc, region, where,
## verse, hint} for the ally, {room, verse, hint} for the enemy.
static func outcome(slot: String, card_id: String) -> Dictionary:
	var table := Compendium.shared().get_entry("tarokka", "outcomes").get(slot, {}) as Dictionary
	return table.get(card_id, {}) as Dictionary


## The reading for `seed_value`: {tome, symbol, sword, ally, enemy} -> card id. Same seed, same reading.
static func draw(seed_value: int) -> Dictionary:
	var common: Array[String] = []
	var high: Array[String] = []
	for id: String in deck():
		if str((deck()[id] as Dictionary)["deck"]) == "high":
			high.append(id)
		else:
			common.append(id)
	common.sort()
	high.sort()
	# Cosmetic-free: the reading is campaign structure, so it has its own RNG on the playthrough seed rather than
	# the dice (which would make it depend on every roll before it).
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_shuffle(common, rng)
	_shuffle(high, rng)
	if common.size() < 3 or high.size() < 2:
		return {}
	return {"tome": common[0], "symbol": common[1], "sword": common[2], "ally": high[0], "enemy": high[1]}


static func _shuffle(list: Array[String], rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := list[i]
		list[i] = list[j]
		list[j] = t


## Draws the party's reading if it hasn't been drawn yet. Returns the reading.
static func ensure_drawn(st: StoryState) -> Dictionary:
	if st.tarokka.is_empty():
		st.tarokka = draw(st.playthrough_seed)
	return st.tarokka


## A field of the party's reading: `tarokka.sword` (the card id), `tarokka.sword.region`, `tarokka.ally.npc` ...
static func field(st: StoryState, path: String) -> String:
	var parts := path.split(".")
	if parts.is_empty() or not st.tarokka.has(parts[0]):
		return ""
	var card_id := str(st.tarokka[parts[0]])
	if parts.size() == 1:
		return card_id
	if parts[1] == "card":
		return str(card(card_id).get("name", card_id))
	return str(outcome(parts[0], card_id).get(parts[1], ""))


## Replaces {tarokka.<slot>.<field>} in quest and journal text with the party's reading.
static func fill(text: String, st: StoryState) -> String:
	if not text.contains("{tarokka."):
		return text
	var out := text
	for slot in SLOTS:
		for f: String in ["hint", "region", "place", "npc", "where", "room", "card"]:
			var key := "{tarokka.%s.%s}" % [slot, f]
			if out.contains(key):
				out = out.replace(key, field(st, "%s.%s" % [slot, f]))
	return out
