class_name RoadSpoils
extends RefCounted
## What a random encounter on the road leaves (Ashwin, 2026-10-09: every random encounter gives a proportionate
## reward; gold, potions, gems, spell scrolls, magic items, armour). Pure logic: game_root hands the result to the
## loot window, a fight's with its spoils and a meeting's once its conversation ends.
##
## A fight: for each foe, coins by its Challenge Rating after the 2024 DMG's individual treasure (what the foes and the
## road's earlier victims left), one find in step with the party's level (a healing potion, a gem or a spell scroll),
## and a chance of a magic item that grows with how hard the fight was for this party. A meeting with no fight: a
## smaller purse and one find. Rolled from the playthrough's seed and the encounter's key, so an encounter gives the
## same reward however often it's reloaded.

## A healing potion by the party's level: [up to level, item id].
const POTIONS := [[4, "potion_of_healing"], [10, "potion_of_healing_greater"], [16, "potion_of_healing_superior"],
	[20, "potion_of_healing_supreme"]]
## Gems by the party's level: [up to level, item id, how many].
const GEMS := [[4, "onyx", 1], [10, "pearl", 1], [16, "diamond", 2], [20, "diamond", 4]]
## The 2024 DMG's XP budget per character for a Moderate encounter, levels 1 to 20: a fight that spends it all is as
## hard as an ordinary day's main fight.
const MODERATE_XP := [75, 150, 225, 375, 750, 900, 1100, 1400, 1600, 1900, 2400, 3000, 3400, 3800, 4300, 4800, 5600,
	6400, 7600, 9000]


## A fight's reward: {gold, items: [{id, qty, ...}]}. `monsters` are the encounter's entries ({monster, ...}).
static func for_fight(st: StoryState, monsters: Array, key: String) -> Dictionary:
	var rng := _rng(st, "fight", key)
	var level := party_level(st)
	var gold := 0
	var xp := 0
	for m: Variant in monsters:
		var data := Compendium.shared().get_entry("monsters", str((m as Dictionary).get("monster", "")))
		gold += coins_for_cr(rng, float(data.get("cr", 0)))
		xp += int(data.get("xp", 0))
	var items: Array[Dictionary] = [find(rng, level, false)]
	# How hard it was: the foes' XP against the party's Moderate budget. An easy fight still has a small chance.
	var budget := float(MODERATE_XP[clampi(level, 1, 20) - 1] * maxi(1, st.party.size()))
	var chance := clampf(0.1 + 0.3 * float(xp) / budget, 0.1, 0.75)
	if rng.roll_one(100, "Road spoils: a magic item") <= roundi(chance * 100.0):
		var it := Treasure.roll_item(rng, level)
		if not it.is_empty():
			items.append(it)
	return {"gold": maxi(gold, 1), "items": items}


## A meeting on the road with no fight: {gold, items}.
static func for_event(st: StoryState, key: String) -> Dictionary:
	var rng := _rng(st, "event", key)
	var level := party_level(st)
	var gold := _dice(rng, 2, 6) * level
	var items: Array[Dictionary] = [find(rng, level, true)]
	if rng.roll_one(100, "Road spoils: a magic item") <= 10:
		var it := Treasure.roll_item(rng, level)
		if not it.is_empty():
			items.append(it)
	return {"gold": gold, "items": items}


## Coins one foe leaves by its Challenge Rating (the 2024 DMG's individual treasure, platinum counted as 10 gp).
static func coins_for_cr(rng: DiceRoller, cr: float) -> int:
	if cr <= 4.0:
		return _dice(rng, 3, 6)
	if cr <= 10.0:
		return _dice(rng, 2, 8) * 10
	if cr <= 16.0:
		return _dice(rng, 2, 10) * 100
	return _dice(rng, 2, 8) * 1000


## One find for a party of `level`: a healing potion, a gem or a spell scroll (a meeting's are a little smaller).
static func find(rng: DiceRoller, level: int, small: bool) -> Dictionary:
	var pick := rng.roll_one(10, "Road spoils: what")
	if pick <= 4:
		for p: Array in POTIONS:
			if level <= int(p[0]):
				return {"id": str(p[1]), "qty": 1 if small else 1 + int(rng.roll_one(3, "Road spoils: potions") == 3)}
	if pick <= 7:
		for g: Array in GEMS:
			if level <= int(g[0]):
				return {"id": str(g[1]), "qty": int(g[2])}
	var lvl := clampi(int(level / 3.0) if small else int((level + 1) / 2.0), 1, 6)
	return {"id": Treasure.scroll_of_level(rng, lvl), "qty": 1}


## The party's level for rewards: the average of its members' levels, rounded.
static func party_level(st: StoryState) -> int:
	if st.party.is_empty():
		return 1
	var total := 0
	for ch in st.party:
		total += ch.character_level()
	return clampi(roundi(float(total) / st.party.size()), 1, 20)


static func _dice(rng: DiceRoller, count: int, sides: int) -> int:
	var total := 0
	for r in rng.roll(sides, count, "Road spoils: coins"):
		total += r
	return total


static func _rng(st: StoryState, kind: String, key: String) -> DiceRoller:
	return DiceRoller.new(hash("%d:road_spoils:%s:%s" % [st.playthrough_seed, kind, key]))
