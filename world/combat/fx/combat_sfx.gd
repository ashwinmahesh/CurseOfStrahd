class_name CombatSfx
extends RefCounted
## What a fight sounds like (art/audio.json "combat", docs/art/spell_effects.md). Sounds are picked the way the effects'
## looks are: a spell or ability by its family and flavour (SpellFx's cue), a blow by what struck and how hard it landed.
## SpellFx and its families call it at the moments their effects show (a cast, a missile leaving the hand, an impact, a
## jump's far end); the combat view calls `hit` when a weapon or claw lands. Only plays sounds: the encounter decides
## everything, and a sound with no recording is silent.
##
## Each moment names a list of effects in art/audio.json "sfx". An entry starting with "@" is the flavour's own sound
## for that moment ("@impact": fire's crackle on Fire Bolt, frost's shatter on Ray of Frost), so a family and a flavour
## layer: a blast's boom under the flavour's burst.

## How hard a blow lands: heavy from `share` of the target's Hit Point maximum, or from `at` damage; never under `least`.
const HEAVY := {"share": 0.25, "at": 15, "least": 5}

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(Audio.MANIFEST):
		var all := JSON.parse_string(FileAccess.get_file_as_string(Audio.MANIFEST)) as Dictionary
		_data = all.get("combat", {}) as Dictionary
	return _data


# --- Spells and abilities -----------------------------------------------------------------------------

## A spell or ability's effect begins (`cue` from SpellFx): its family's sound, or the plain spell sound for a family
## with none.
static func cast(cue: Dictionary) -> void:
	if not (data().get("families", {}) as Dictionary).has(str(cue.get("family", ""))) and not own(str(cue.get("key", ""))).has("cast"):
		Audio.sfx("spell")
		return
	_play(cue, "cast")


## A class ability switched on that has no effect of its own to show (Bladesong, Vow of Enmity): its own sound, if it
## has one. True when one played.
static func feature(key: String) -> bool:
	var ids := _list(own(key).get("cast", []))
	for id in ids:
		sound(id)
	return not ids.is_empty()


## A hero starts concentrating on a spell (`started`), or a blow breaks it.
static func concentration(started: bool) -> void:
	for id in _list((data().get("concentration", {}) as Dictionary).get("start" if started else "break", [])):
		sound(id)


## A spell's, feature's or monster action's own sounds (`keys`): its id's, else its kind's for an id with a choice in
## it ("wild_shape:wolf" plays wild_shape's).
static func own(key: String) -> Dictionary:
	var keys := data().get("keys", {}) as Dictionary
	if keys.has(key):
		return keys[key] as Dictionary
	return keys.get(key.get_slice(":", 0), {}) as Dictionary


## A missile leaves the caster's hand (a bolt, ray or beam; an arrow).
static func launch(cue: Dictionary) -> void:
	_play(cue, "launch")


## An effect lands or bursts: a missile on its target, a blast over its squares, a smite on the blow.
static func impact(cue: Dictionary) -> void:
	_play(cue, "impact")


## A jump's far end: the creature comes out of the mist (Misty Step, Dimension Door).
static func arrive(cue: Dictionary) -> void:
	_play(cue, "arrive")


## The effects one moment of `cue` plays: its spell's or ability's own (`keys`), else its family's, with "@" entries
## taken from its flavour.
static func ids_for(cue: Dictionary, moment: String) -> Array[String]:
	var mine := own(str(cue.get("key", "")))
	var fam := (data().get("families", {}) as Dictionary).get(str(cue.get("family", "")), {}) as Dictionary
	var flavour := (data().get("flavours", {}) as Dictionary).get(str(cue.get("flavour", "")), {}) as Dictionary
	var out: Array[String] = []
	for id in _list(mine.get(moment, fam.get(moment, []))):
		out.append_array(_list(flavour.get(id.substr(1), "")) if id.begins_with("@") else [id] as Array[String])
	return out


static func _play(cue: Dictionary, moment: String) -> void:
	for id in ids_for(cue, moment):
		sound(id)


## One effect: "<id>", or "<id>@<seconds>" to come in a moment after the others (a roar after the change of shape).
static func sound(entry: String) -> void:
	var id := entry.get_slice("@", 0)
	var after := float(entry.get_slice("@", 1)) if entry.contains("@") else 0.0
	var tree := Engine.get_main_loop() as SceneTree
	if after <= 0.0 or tree == null:
		Audio.sfx(id)
		return
	tree.create_timer(after).timeout.connect(func() -> void: Audio.sfx(id))


# --- Blows --------------------------------------------------------------------------------------------

## A weapon, claw or bite lands on `target` for `amount` (-1: the damage isn't known): the kind's light or heavy
## sound by how hard it landed, or its critical one.
static func hit(kind: String, amount: int, target: Combatant, critical: bool) -> void:
	for id in hit_ids(kind, amount, target.creature.max_hp() if target != null else 0, critical):
		Audio.sfx(id)


static func hit_ids(kind: String, amount: int, max_hp: int, critical: bool) -> Array[String]:
	var hits := data().get("hits", {}) as Dictionary
	var sounds := hits.get(kind, hits.get("blade", {})) as Dictionary
	var tier := "critical" if critical else ("heavy" if heavy(amount, max_hp) else "light")
	return _list(sounds.get(tier, []))


static func heavy(amount: int, max_hp: int) -> bool:
	if amount < int(HEAVY["least"]):
		return false
	return amount >= int(HEAVY["at"]) or (max_hp > 0 and float(amount) >= float(HEAVY["share"]) * float(max_hp))


## What struck, for its sound (an attack event's `action`): "blade" (slashing), "blunt" (bludgeoning), "point" (a
## melee pierce: a spear, a rapier, a bite) or "shot" (an arrow, a bolt or a throw).
static func hit_kind(attacker: Combatant, action: String) -> String:
	var type := ""
	var ranged := false
	if action.begins_with("weapon:") or action.begins_with("thrown:"):
		var w := Compendium.shared().item_data(action.get_slice(":", 1).get_slice("@", 0)).get("weapon", {}) as Dictionary
		type = str(w.get("damage_type", ""))
		ranged = action.begins_with("thrown:") or str(w.get("kind", "")).ends_with("ranged")
	elif action.begins_with("monster:") and attacker != null and attacker.creature is Monster:
		var aid := action.substr(8)
		for section: String in ["actions", "bonus_actions", "reactions"]:
			var list: Variant = (attacker.creature as Monster).data.get(section, [])
			for a: Variant in (list as Array if list is Array else []):
				if str((a as Dictionary).get("id", "")) == aid:
					var parts := (a as Dictionary).get("damage", []) as Array
					type = str((parts[0] as Dictionary).get("type", "")) if not parts.is_empty() else ""
					ranged = str((a as Dictionary).get("kind", "")) == "ranged"
	match type:
		"bludgeoning":
			return "blunt"
		"piercing":
			return "shot" if ranged else "point"
	return "shot" if ranged else "blade"


static func _list(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		for x: Variant in v:
			out.append(str(x))
	elif str(v) != "":
		out.append(str(v))
	return out
