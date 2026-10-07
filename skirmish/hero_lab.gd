class_name HeroLab
extends RefCounted
## The Character Lab's rules side (Skirmish, N1): heroes at any level from 1 to 20, levelled with sensible picks
## filled in, and given any item. Pure logic over CharacterBuilder and LevelUpController; the Lab screen
## (ui/skirmish/character_lab.gd) shows it, and the player can still take any level by hand on the level-up screen.

const MAX_LEVEL := LevelUpController.MAX_LEVEL
## Books whose options the automatic picks prefer, in order: the 2024 core rules first, so an auto-levelled Fighter
## becomes a Champion rather than whichever subclass sorts first.
const PREFERRED_BOOKS: Array[String] = ["PHB2024", "SRD5.2", "BR2024"]


## A pregen at `level`: its level plan as far as the plan goes (the campaign's cap), then levels in its first class
## with the picks filled in. Rested and ready.
static func pregen(id: String, level: int, errors: Array[String] = []) -> Character:
	var ch := Pregens.build(id, mini(level, plan_top(id)), errors)
	if ch == null:
		return null
	if ch.character_level() < level and not ch.class_order.is_empty():
		level_to(ch, level, ch.class_order[0], errors)
	ch.finish_long_rest()
	return ch


## The highest level a pregen's level plan reaches.
static func plan_top(id: String) -> int:
	var top := 1
	for step: Variant in Compendium.shared().get_entry("pregens", id).get("level_plan", []):
		top = maxi(top, int((step as Dictionary)["level"]))
	return top


## A new hero of `class_id` at `level`: the class's recommended ability scores, background and skills, a Human
## unless `species` says otherwise, every other choice filled in. For quick tests of a class; the creator makes the
## rest.
static func quick_hero(class_id: String, level: int, species: String = "human", hero_name: String = "") -> Character:
	var b := CharacterBuilder.new()
	b.set_class(class_id)
	var rec := Compendium.shared().class_data(class_id).get("recommended", {}) as Dictionary
	b.set_background(str(rec.get("background", "soldier")))
	b.set_species(species)
	b.set_name(hero_name if hero_name != "" else "Lab %s" % Compendium.shared().display_name("classes", class_id))
	b.apply_recommended_scores()
	fill_choices(b.pending_choices, b.choose, func() -> Character: return b.preview())
	var ch := b.build_character()
	if ch == null:
		return null
	level_to(ch, level, class_id)
	ch.finish_long_rest()
	return ch


## Levels `ch` up in `class_id` until it reaches `level` (fixed Hit Points each level). False if a level wouldn't
## confirm; `errors` says why.
static func level_to(ch: Character, level: int, class_id: String, errors: Array[String] = []) -> bool:
	while ch.character_level() < mini(level, MAX_LEVEL):
		if not level_once(ch, class_id, errors):
			return false
	return true


## One level in `class_id` (or the character's first class when it can't take that one), picks filled in.
static func level_once(ch: Character, class_id: String, errors: Array[String] = []) -> bool:
	var up := LevelUpController.new(ch)
	if not up.choose_class(class_id):
		if ch.class_order.is_empty() or not up.choose_class(ch.class_order[0]):
			errors.append("%s can't take a level in %s" % [ch.name, class_id])
			return false
	up.take_fixed_hit_points()
	fill_choices(up.pending_choices, up.choose, up.preview)
	if not up.confirm():
		errors.append("%s level %d: %s" % [ch.name, ch.character_level() + 1, ", ".join(up.errors())])
		return false
	return true


## Fills incomplete choices one at a time, re-reading them after each pick since one pick changes another's
## options. Legal options without warnings come first, the core books' before others; ability increases go to the
## highest scores; the Ability Score Improvement feat is taken where a feat is offered. `get_pending` returns
## Array[Choice], `choose(key, picks)` stores them, `preview` returns the character as it stands. Returns the keys
## it couldn't fill.
static func fill_choices(get_pending: Callable, choose: Callable, preview: Callable) -> Array[String]:
	var stuck: Array[String] = []
	var tried := {}
	for guard in 200:
		var c: Choice = null
		for p in get_pending.call() as Array[Choice]:
			if not tried.has(p.key):
				c = p
				break
		if c == null:
			break
		tried[c.key] = true
		var picks: Array = c.picks.duplicate()
		var pool := _ranked(c, preview.call() as Character)
		if c.kind == "ability_increase":
			while picks.size() < c.count and not pool.is_empty():
				picks.append(pool[0])
				if picks.count(pool[0]) >= c.per_ability:
					pool.pop_front()
		else:
			for id in pool:
				if picks.size() >= c.count:
					break
				if not id in picks:
					picks.append(id)
		if picks.size() < c.count:
			stuck.append("%s (%d of %d)" % [c.key, picks.size(), c.count])
		choose.call(c.key, picks)
	return stuck


## A choice's legal options, best first.
static func _ranked(c: Choice, ch: Character) -> Array[String]:
	var scored: Array[Array] = []
	for i in c.options.size():
		var o := c.options[i]
		if not o.legal or o.locked:
			continue
		var score := float(i)
		if o.warning != "":
			score += 10000.0
		var book := _book_of(c.kind, o.id)
		if book != "" and not book in PREFERRED_BOOKS:
			score += 1000.0
		if c.kind == "ability_increase" and ch != null:
			# Highest score first; an odd score first among equals (its next point raises the modifier).
			var s := ch.ability_score(StringName(o.id)) if ch.has_method("ability_score") else 10
			score = -float(s) * 10.0 - float(s % 2) * 5.0 + float(i) * 0.01
			if s >= c.max_score:
				continue
		elif o.id == "ability_score_improvement":
			score = -1.0
		scored.append([score, o.id])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out: Array[String] = []
	for s in scored:
		out.append(str(s[1]))
	return out


## The book an option comes from ("PHB2024", "FRHoF"), or "" when the kind has no data entries.
static func _book_of(kind: String, id: String) -> String:
	var folder := {"subclass": "subclasses", "feat": "feats", "fighting_style": "feats", "cantrip": "spells", "spell": "spells",
		"spellbook": "spells"}.get(kind, "") as String
	if folder == "":
		return ""
	var src: Variant = Compendium.shared().get_entry(folder, id).get("source", {})
	return str((src as Dictionary).get("book", "")) if src is Dictionary else ""


# --- Items ----------------------------------------------------------------------------------------

## Every item a hero can be given, by name: the mundane gear, every magic item, and each template (a +1 weapon, a
## Flame Tongue) once, put on a base when given (`give`). Spell Scrolls come as the particular scrolls the data has.
static func all_items() -> Array[Dictionary]:
	var comp := Compendium.shared()
	var out: Array[Dictionary] = []
	for d in comp.all("items"):
		if str(d.get("category", "")) != "quest":
			out.append(d)
	for d in comp.all("magic_items"):
		if str((d.get("template", {}) as Dictionary).get("on", "")) != "spell":
			out.append(d)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("name", "")) < str(b.get("name", "")))
	return out


## The item id `item_id` becomes when given to `ch`: a template goes on the base the hero holds or wears in its slot
## when it fits there, else on its first base ("flame_tongue__longsword"); anything else stays as it is.
static func given_id(ch: Character, item_id: String) -> String:
	var comp := Compendium.shared()
	var t := comp.get_entry("magic_items", item_id)
	if not MagicItems.is_template(t):
		return item_id
	var bases := comp.template_bases(item_id)
	if bases.is_empty():
		return ""
	for slot: String in ["main_hand", "armor", "off_hand"]:
		var held := ch.equipped(slot)
		var base := MagicItems.base_id(held) if not held.is_empty() else ""
		if base in bases:
			return item_id + MagicItems.SEP + base
	return item_id + MagicItems.SEP + bases[0]


## Gives `ch` one item (a template on a base, `given_id`): a weapon goes in hand, armor and a shield are put on, a
## worn magic item is worn, and one that needs attunement is attuned when a place is free (2024: three at most).
## Returns what happened, for the screen.
static func give(ch: Character, item_id: String) -> String:
	var id := given_id(ch, item_id)
	var data := Compendium.shared().item_data(id)
	if id == "" or data.is_empty():
		return "Nothing fits %s" % item_id
	var qty := 20 if str(data.get("category", "")) == "ammunition" else 1
	ch.add_item(id, qty)
	var note := "%s gets %s" % [ch.name.get_slice(" ", 0), str(data.get("name", id))]
	var slot := equip_slot(data)
	if slot != "" and ch.equip(id, slot):
		note += ", worn" if slot == "armor" else (", on the arm" if slot == "off_hand" else ", in hand")
	elif MagicItems.worn_slot(data) != "" and ch.wear(id):
		note += ", worn"
	if MagicItems.needs_attunement(data):
		var why := ch.attune_blocker(id)
		if why == "" and ch.attune(id):
			note += ", attuned"
		elif why != "":
			note += " (not attuned: %s)" % why
	ch.items_changed()
	return note


## The hand or body slot an item goes in when given ("armor", "main_hand", "off_hand"), or "" for anything carried
## or worn elsewhere.
static func equip_slot(data: Dictionary) -> String:
	match str(data.get("category", "")):
		"armor":
			return "armor"
		"shield":
			return "off_hand"
		"weapon":
			return "main_hand"
	return ""
