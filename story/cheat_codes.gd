class_name CheatCodes
extends RefCounted
## Item cheat codes (owner, 2026-10-08: every item and magic item gets a six-digit hex code; typing it gives that hero
## the item, as often as they like). The pause menu's Cheat codes page (CheatCodesPage) takes the codes, and
## Cheat Codes.md in the vault lists them (tools/data/cheat_codes.py, `make cheat-codes`, which does the same sums).
## A code is the first six hex digits of sha256("cheat:<item id>"), so it stays the same whatever items are added. Two
## ids that share a code are settled in id order: the first keeps it, the next hashes "cheat:<id>#1" (then #2...). Every
## item file takes part, playable or not, so switching a book on later moves no one's code. Only playable items answer.
## An item built on a base (a +1 Weapon, a Spell Scroll) has one code, and the player picks the base when giving it.

const FOLDERS: Array[String] = ["items", "magic_items"]
const SALT := "cheat:"
const LENGTH := 6
## What a template's base is called on the page, by its `template.on`.
const BASE_WORDS := {"weapon": "Weapon", "armor": "Armor", "shield": "Shield", "ammunition": "Ammunition",
	"weapon_or_ammunition": "Weapon or ammunition", "spell": "Spell"}

## code -> item id, and item id -> code, built once from the item files.
static var _by_code: Dictionary = {}
static var _by_id: Dictionary = {}


## Forget the codes (tests that add items).
static func reset() -> void:
	_by_code = {}
	_by_id = {}


## The code sha256 gives `item_id` on its `n`th try.
static func hash_code(item_id: String, n: int = 0) -> String:
	var key := SALT + item_id if n == 0 else "%s%s#%d" % [SALT, item_id, n]
	return key.sha256_text().substr(0, LENGTH).to_upper()


## Codes for `ids`, clashes settled in id order: {id: code}.
static func assign(ids: Array[String]) -> Dictionary:
	var sorted := ids.duplicate()
	sorted.sort()
	var taken := {}
	var out := {}
	for id: String in sorted:
		var n := 0
		var code := hash_code(id, n)
		while taken.has(code):
			n += 1
			code = hash_code(id, n)
		taken[code] = id
		out[id] = code
	return out


static func _build() -> void:
	if not _by_id.is_empty():
		return
	var ids: Array[String] = []
	for folder in FOLDERS:
		for id: Variant in Compendium.shared().table(folder):
			ids.append(str(id))
	_by_id = assign(ids)
	for id: String in _by_id:
		_by_code[_by_id[id]] = id


## What the player typed as a code: hex digits only, upper case ("#3a 9b-02" is "3A9B02").
static func normalise(text: String) -> String:
	var out := ""
	for c: String in text.to_upper():
		if c in "0123456789ABCDEF":
			out += c
	return out


## An item's code ("" for an id no item file has).
static func code_of(item_id: String) -> String:
	_build()
	return str(_by_id.get(item_id, ""))


## The playable item a code names, or "".
static func item_for(code: String) -> String:
	_build()
	var id := str(_by_code.get(normalise(code), ""))
	if id == "" or not Compendium.playable(entry(id)):
		return ""
	return id


static func entry(item_id: String) -> Dictionary:
	var comp := Compendium.shared()
	var d := comp.get_entry("items", item_id)
	return d if not d.is_empty() else comp.get_entry("magic_items", item_id)


## Every playable item and its code, by name: [{code, id, name, magic}].
static func entries() -> Array[Dictionary]:
	_build()
	var out: Array[Dictionary] = []
	for folder in FOLDERS:
		for d in Compendium.shared().all_playable(folder):
			out.append({"code": code_of(str(d["id"])), "id": str(d["id"]), "name": str(d.get("name", d["id"])),
				"magic": folder == "magic_items"})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["name"]) < str(b["name"]))
	return out


# --- Items built on a base ----------------------------------------------------------------------------

## The finished items a code's item can be, for the player to pick from: "<template>__<base>" for each base it fits,
## by name (spell scrolls by spell level, then name); [] for an item that isn't built on a base.
static func choices(item_id: String) -> Array[String]:
	var t := entry(item_id)
	var out: Array[String] = []
	if not MagicItems.is_template(t):
		return out
	var comp := Compendium.shared()
	if str((t["template"] as Dictionary).get("on", "")) == "spell":
		var spells := comp.all_playable("spells")
		spells.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var la := int(a.get("level", 0))
			var lb := int(b.get("level", 0))
			return la < lb if la != lb else str(a.get("name", "")) < str(b.get("name", "")))
		for s in spells:
			out.append(item_id + MagicItems.SEP + str(s["id"]))
		return out
	var bases := comp.template_bases(item_id)
	bases.sort_custom(func(a: String, b: String) -> bool:
		return comp.display_name("items", a) < comp.display_name("items", b))
	for b in bases:
		out.append(item_id + MagicItems.SEP + b)
	return out


## The base picked first: the template's own `default`, else the first choice; "" for a plain item.
static func default_choice(item_id: String) -> String:
	var options := choices(item_id)
	if options.is_empty():
		return ""
	var d := item_id + MagicItems.SEP + str((entry(item_id)["template"] as Dictionary).get("default", ""))
	return d if d in options else options[0]


## What the page asks the player to pick ("Weapon", "Spell"); "" for a plain item.
static func base_word(item_id: String) -> String:
	var t := entry(item_id)
	if not MagicItems.is_template(t):
		return ""
	return str(BASE_WORDS.get(str((t["template"] as Dictionary).get("on", "weapon")), "Base"))


## A choice as the picker lists it: the base's name, or the scroll's spell and level.
static func choice_name(variant_id: String) -> String:
	var comp := Compendium.shared()
	var base := variant_id.get_slice(MagicItems.SEP, 1)
	var spell := comp.get_entry("spells", base)
	if variant_id.begins_with("spell_scroll" + MagicItems.SEP) and not spell.is_empty():
		var lvl := int(spell.get("level", 0))
		return "%s (%s)" % [spell.get("name", base), "cantrip" if lvl == 0 else "level %d" % lvl]
	return comp.display_name("items", base)


# --- Giving ---------------------------------------------------------------------------------------------

## How many one use of a code gives: a bundle of ammunition (20 Arrows), else one.
static func quantity(item_id: String) -> int:
	var d := Compendium.shared().item_data(item_id)
	return maxi(1, int(d.get("bundle", 1))) if bool(d.get("stackable", false)) else 1


## Gives `ch` the item (`item_id` may be a finished "<template>__<base>"), already identified, since the player named
## it. Returns how many were given, or 0 if there's no such item.
static func give(ch: Character, item_id: String) -> int:
	var d := Compendium.shared().item_data(item_id)
	if ch == null or d.is_empty() or MagicItems.is_template(d):
		return 0
	var qty := quantity(item_id)
	var magic := MagicItems.is_magic(d)
	ch.add_item(item_id, qty, {"identified": true} if magic else {})
	# A stack keeps no state of its own when it's added to, so the stack itself is marked.
	if magic and bool(d.get("stackable", false)):
		ch.entry_of(item_id)["identified"] = true
	return qty
