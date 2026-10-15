class_name DrawnCreatures
extends RefCounted
## Every creature the board draws as a foe, a summon or a shape, with the size category it fights at, for the checks
## that a figure stands as big as the squares it holds (owner, 2026-10-14: "make sure every enemy sprite is sized
## correctly when laid out in the world"): each monster in data/monsters, each stat block a spell calls up at every
## option it offers (SummonBlocks.for_spell), and each shape a monster takes with art of its own (Strahd's bat, wolf
## and mist).

## How tall a figure is drawn (CombatToken heights, in squares: 1 unit = 5 ft) for each size category: a figure's
## tallest or widest view is about its drawn height (every sheet frames its biggest view to the cell), so this is
## how much of the board it covers. A Medium wolf is 0.8 and a Medium man 1.2 to 1.45; from Large up a figure covers
## at least 0.65 of its squares' width (a dire wolf 1.35 of its 2 x 2, Old Greytooth 2.0 of his 3 x 3) and up to about
## its whole width and more (an ogre 2.1, an elephant 2.8 of its 3 x 3); a Gargantuan one stands over all the rest (a
## roc 3.8).
const BANDS := {"tiny": [0.2, 0.8], "small": [0.45, 1.1], "medium": [0.6, 1.7], "large": [1.3, 2.8], "huge": [1.95, 4.0],
	"gargantuan": [3.2, 6.0]}
const SIZES: Array[String] = ["tiny", "small", "medium", "large", "huge", "gargantuan"]


## [{id, label, size, data}] for every creature drawn on its own stat block: `data` is the block (Monster data).
static func blocks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	var monsters := Compendium.shared().table("monsters")
	var ids: Array = monsters.keys()
	ids.sort()
	for id: String in ids:
		var d := monsters[id] as Dictionary
		_add(out, seen, d, str(d.get("name", id)))
	var spells := Compendium.shared().table("spells")
	var spell_ids: Array = spells.keys()
	spell_ids.sort()
	for sid: String in spell_ids:
		var options: Array = [""]
		var choice := (spells[sid] as Dictionary).get("choice", {}) as Dictionary
		options.append_array(choice.get("from", []) as Array)
		if sid == "find_familiar":
			options.append_array(SummonBlocks.CHAIN_FORMS)
		for opt: Variant in options:
			var block := SummonBlocks.for_spell(sid, 9, str(opt), {})
			if not block.is_empty():
				_add(out, seen, block, "%s (%s)" % [str(block.get("name", "")), sid])
	return out


static func _add(out: Array[Dictionary], seen: Dictionary, d: Dictionary, label: String) -> void:
	var key := "%s|%s|%s" % [str(d.get("id", "")), str(d.get("size", "medium")), CombatToken.monster_art(d)]
	if seen.has(key):
		return
	seen[key] = true
	out.append({"id": str(d.get("id", "")), "label": label, "size": str(d.get("size", "medium")), "data": d})


## [{id, label, size, art}] for every shape a monster changes into that's drawn with art of its own (a legendary
## form's `art`): its size is the shape's.
static func shapes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var monsters := Compendium.shared().table("monsters")
	for id: String in monsters:
		var forms := (monsters[id] as Dictionary).get("forms", {}) as Dictionary
		for s: Variant in forms.get("shapes", []):
			var sh := s as Dictionary
			if str(sh.get("art", "")) != "":
				out.append({"id": "%s/%s" % [id, sh.get("id", "")], "label": "%s as %s" % [id, sh.get("name", "")],
					"size": str(sh.get("size", (monsters[id] as Dictionary).get("size", "medium"))), "art": str(sh["art"])})
	return out


## The height `data`'s figure is drawn at on the board (CombatToken.height_of), as a combatant on an open field; 0
## for one with no sprite (drawn as a placeholder capsule as big as its squares).
static func drawn_height(data: Dictionary) -> float:
	var m := Monster.from_data(data)
	var c := Combatant.new(m, &"enemy", Vector2i.ZERO)
	if DirectionalSprite.frames_for(CombatToken.art_id(c)) == null:
		return 0.0
	return CombatToken.height_of(c)
