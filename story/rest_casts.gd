class_name RestCasts
extends RefCounted
## Spells a hero casts on itself as each Long Rest ends, when the player wants it (owner, 2026-10-07): Mage Armor, so
## nobody has to remember it each morning. The choice is per hero (Character.rest_casts: spell id -> on or off). Until
## the player sets it, it's on when the hero can cast the spell without a spell slot (Armor of Shadows, a feat's free
## casting) and off when it would cost one. A free casting is always used when there is one; otherwise the lowest
## spell slot that works. Mage Armor needs an unarmoured target, so a hero wearing armor skips it.

## The spells that can be set to cast after a Long Rest.
const SPELLS: Array[String] = ["mage_armor"]


## What `ch` could set to cast after a Long Rest: [{id, name, on, free, why}]; `why` says what stops it right now
## ("" when nothing does). Only spells `ch` can cast at all are listed.
static func choices(party: Array[Character], ch: Character, dice: DiceRoller) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if ch.dead:
		return out
	var options := FieldCasting.options(party, ch, dice)
	for id in SPELLS:
		for o in options:
			if str(o["id"]) != id:
				continue
			var free := bool(o["free"])
			out.append({"id": id, "name": str(o["name"]), "free": free, "on": wanted(ch, id, free), "why": _why(ch, id, o)})
	return out


## Whether `ch` casts `spell_id` after a Long Rest: the player's choice, else on only when it's free.
static func wanted(ch: Character, spell_id: String, free: bool) -> bool:
	return bool(ch.rest_casts.get(spell_id, free))


## Turns the choice on or off for `ch`.
static func set_wanted(ch: Character, spell_id: String, on: bool) -> void:
	ch.rest_casts[spell_id] = on


## After a Long Rest: each hero casts the spells it wants on itself (free castings first, else the lowest slot).
## Returns the lines to show, one per hero who cast or couldn't.
static func after_long_rest(party: Array[Character], dice: DiceRoller) -> Array[String]:
	var lines: Array[String] = []
	for ch in party:
		for choice in choices(party, ch, dice):
			if not bool(choice["on"]):
				continue
			var first := ch.name.get_slice(" ", 0)
			if str(choice["why"]) != "":
				lines.append("%s doesn't cast %s: %s." % [first, choice["name"], str(choice["why"]).to_lower()])
				continue
			var level := int(Compendium.shared().spell_data(str(choice["id"])).get("level", 1))
			var slots_before := ch.slots_used.duplicate()
			var me: Array[Character] = [ch]
			var res := FieldCasting.cast(party, ch, str(choice["id"]), level if bool(choice["free"]) else 0, me, dice)
			if not bool(res["ok"]):
				lines.append("%s doesn't cast %s: %s." % [first, choice["name"], str(res["text"]).to_lower()])
				continue
			var paid := ""
			for l in 9:
				if ch.slots_used[l] > slots_before[l]:
					paid = "a level %d spell slot" % (l + 1)
			lines.append("%s casts %s before setting off (%s)." % [first, choice["name"], paid if paid != "" else "free, no spell slot"])
	return lines


## What stops `ch` casting the spell after the rest: armor worn (Mage Armor), already under it, or the spell's own
## reason (no slots left).
static func _why(ch: Character, id: String, option: Dictionary) -> String:
	if id == "mage_armor" and not ch.equipped("armor").is_empty():
		return "Wearing armor"
	if ch.effects.any(func(fx: Effect) -> bool: return fx.source_id == id):
		return "Already under it"
	if not bool(option["legal"]):
		return str(option["reason"])
	return ""
