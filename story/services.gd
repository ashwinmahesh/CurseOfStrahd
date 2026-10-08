class_name Services
extends RefCounted
## Services people sell (F14): a temple's spells and an inn's rooms, listed in an NPC's `services` and bought on the
## services screen. Each kind is defined here; the NPC's data picks which they offer and may set its own price. Prices
## follow the seller's attitude like a shop's (Trade.buy_price).
##
## Temple spells use the 2024 PHB's spellcasting-service prices (level 1: 50 gp, level 2: 200 gp, level 3: 300 gp,
## levels 4 and 5: 2,000 gp), plus a material the spell uses up. St. Andral's keeps scrolls of the spells Father
## Lucian can't cast himself and reads them for the party (owner, 2026-10-07): Raise Dead, for its fee and the 500 gp
## diamond. A hero raised comes back with 1 Hit Point and -4 on D20 Tests for 10 days (owner's call; the book's
## penalty shrinks by 1 with each Long Rest instead, docs/rules/deviations.md), if they died within the last 10 days.
## When each hero died is noted as the clock moves on (note_deaths), in the flags.
##
## A room is booked for the night (the `_room` flag): the party sleeps on the rest screen as usual, and a Long Rest
## there under a booked roof gives the room's comforts on waking (after_long_rest). Better rooms are our addition:
## the 2024 rules give a night's lodging no effect.

const KINDS := {
	"cure_wounds": {"name": "Cure Wounds", "for": "hurt", "price": 50.0, "spell": "cure_wounds", "heal": "2d8",
		"text": "Heals one hero 2d8 plus the reader's Wisdom modifier."},
	"lesser_restoration": {"name": "Lesser Restoration", "for": "afflicted", "price": 200.0, "spell": "lesser_restoration",
		"text": "Ends one of these on a hero: Paralyzed, Blinded, Poisoned or Deafened."},
	"remove_curse": {"name": "Remove Curse", "for": "cursed", "price": 300.0, "spell": "remove_curse",
		"text": "Ends every curse on a hero, and breaks their Attunement to a cursed item so they can put it down."},
	"raise_dead": {"name": "Raise Dead", "for": "dead", "price": 2000.0, "spell": "raise_dead", "material": 500.0,
		"text": "Brings back a hero who died within the last 10 days, with 1 Hit Point and -4 on D20 Tests for 10 days. The spell uses up a 500 gp diamond, which the church supplies."},
	"room_modest": {"name": "A room upstairs", "for": "party", "each": 0.5, "comfort": 1,
		"text": "A bed each behind a door that locks. Sleep here, and everyone wakes with temporary Hit Points equal to their level."},
	"room_wealthy": {"name": "The best room, with a hot bath", "for": "party", "each": 2.0, "comfort": 2,
		"text": "Clean linen, a fire and a copper bath. Sleep here, and everyone wakes with temporary Hit Points equal to twice their level and one more level of Exhaustion gone."},
}
## How long a hero can be dead and still be raised, and how long the ordeal lasts, in minutes (10 days).
const RAISE_LIMIT := 10 * 24 * 60
const ORDEAL := 10 * 24 * 60
const ORDEAL_PENALTY := -4
## Lesser Restoration ends the first of these a hero has.
const RESTORABLE: Array[StringName] = [&"paralyzed", &"blinded", &"poisoned", &"deafened"]


## What `npc_id` offers: [{id, name, text, price (for one hero, or each), for, each, scroll}], prices after attitude.
static func offered(st: StoryState, npc_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Variant in Compendium.shared().get_entry("npcs", npc_id).get("services", []):
		var s := e as Dictionary
		var kind := KINDS.get(str(s["id"]), {}) as Dictionary
		if kind.is_empty() or not StoryConditions.check(str(s.get("if", "")), st):
			continue
		var line := kind.duplicate()
		line["id"] = str(s["id"])
		line["scroll"] = bool(s.get("scroll", false))
		if kind.has("each"):
			line["each"] = Trade.buy_price(st, npc_id, float(s.get("price", kind["each"])))
			line["price"] = snappedf(float(line["each"]) * st.party.size(), 0.01)
		else:
			line["price"] = Trade.buy_price(st, npc_id, float(s.get("price", kind["price"])))
		line["material"] = float(kind.get("material", 0.0))
		out.append(line)
	return out


## The whole cost of a service line: the fee and any material the spell uses up.
static func cost(line: Dictionary) -> float:
	return float(line["price"]) + float(line.get("material", 0.0))


## Why `line` can't be bought for `ch` now ("" if it can). Rooms are for the whole party and ignore `ch`.
static func why_not(st: StoryState, line: Dictionary, ch: Character) -> String:
	var who := ch.name.get_slice(" ", 0) if ch != null else ""
	match str(line["for"]):
		"hurt":
			if ch.dead:
				return "%s is dead" % who
			if ch.hp >= ch.max_hp():
				return "%s isn't hurt" % who
		"afflicted":
			if ch.dead:
				return "%s is dead" % who
			if _restorable(ch) == &"":
				return "%s has nothing it ends" % who
		"cursed":
			if ch.dead:
				return "%s is dead" % who
			if curses(ch).is_empty() and cursed_items(ch).is_empty():
				return "%s bears no curse" % who
		"dead":
			if not ch.dead:
				return "%s is alive" % who
			if dead_for(st, ch) > RAISE_LIMIT:
				return "%s has been dead more than 10 days" % who
		"party":
			if booked(st) == str(line["id"]):
				return "Already yours for tonight"
	if st.gold < cost(line):
		return "Not enough gold"
	return ""


## Buys `line` for `ch` (the whole party for a room) and does it. Returns what happened, or "" if it couldn't be
## done (why_not says why).
static func buy(st: StoryState, npc_id: String, line: Dictionary, ch: Character, dice: DiceRoller) -> String:
	if why_not(st, line, ch) != "":
		return ""
	st.gold -= cost(line)
	var reader := Compendium.shared().display_name("npcs", npc_id)
	var who := ch.name.get_slice(" ", 0) if ch != null else ""
	var said := ""
	match str(line["id"]):
		"cure_wounds":
			var roll := dice.roll_expr(str(line["heal"]), "Cure Wounds (%s)" % reader)
			var mod := _reader_wis(npc_id)
			var healed := ch.heal(int(roll["total"]) + mod, "Cure Wounds")
			said = "%s heals %s for %d (%s %d %s %d)." % [reader, who, healed, line["heal"], int(roll["total"]), "+" if mod >= 0 else "-", absi(mod)]
		"lesser_restoration":
			var cond := _restorable(ch)
			cure(ch, cond)
			said = "%s is no longer %s." % [who, str(cond).capitalize()]
		"remove_curse":
			var n := 0
			for fx in curses(ch):
				ch.remove_effect(fx)
				n += 1
			var items: Array[String] = []
			for id in cursed_items(ch):
				ch.entry_of(id)["curse_lifted"] = true
				ch.end_attunement(id)
				items.append(Compendium.shared().display_name("items", id))
			said = "The curse lifts from %s." % who if n > 0 else "%s is free of %s's hold." % [who, ", ".join(items)]
			if n > 0 and not items.is_empty():
				said += " %s can put down %s." % [who, ", ".join(items)]
		"raise_dead":
			raise(st, ch)
			st.advance_minutes(60)
			said = "%s reads the scroll over %s for an hour, and the diamond crumbles to dust. %s breathes again." % [reader, who, who]
		_:
			st.set_flag("_room", {"id": str(line["id"]), "location": st.location, "day": st.day})
			said = "%s is yours for the night. Take a Long Rest to sleep in it." % str(line["name"])
	return said


## Raise Dead on `ch`: back with 1 Hit Point, poison gone, and -4 on D20 Tests for 10 days.
static func raise(st: StoryState, ch: Character) -> void:
	ch.dead = false
	ch.hp = 0
	ch.death_successes = 0
	ch.death_failures = 0
	ch.heal(1, "Raise Dead")
	if ch.has_condition(&"poisoned"):
		cure(ch, &"poisoned")
	var fx := Effect.new("Back from the dead", &"spell", "raise_dead").with_modifier("d20", {"value": ORDEAL_PENALTY})
	fx.ends = Effect.Ends.MINUTES
	fx.minutes_left = ORDEAL
	ch.add_effect(fx)
	st.flags.erase(_died_key(ch))


## Ends a condition however it was given: as a plain condition or by an effect (as Lesser Restoration does in a fight).
static func cure(cr: Creature, cond: StringName) -> void:
	cr.remove_condition(cond)
	for fx: Effect in cr.effects.duplicate():
		if cond in fx.conditions:
			if str(fx.data.get("primary_condition", "")) == str(cond) or (fx.modifiers.is_empty() and fx.conditions.size() == 1):
				cr.remove_effect(fx)
			else:
				fx.conditions.erase(cond)
	cr._after_conditions_changed()


static func _restorable(ch: Character) -> StringName:
	for c in RESTORABLE:
		if ch.has_condition(c):
			return c
	return &""


## The curses on `ch` (Bestow Curse, a lycanthrope's bite), as Remove Curse finds them in a fight.
static func curses(ch: Character) -> Array[Effect]:
	var out: Array[Effect] = []
	for fx: Effect in ch.effects:
		if fx.source_id == "bestow_curse" or fx.modifiers.any(func(m: Modifier) -> bool: return m.text("value").begins_with("curse:")):
			out.append(fx)
	return out


## Cursed items `ch` is attuned to and can't let go of.
static func cursed_items(ch: Character) -> Array[String]:
	var out: Array[String] = []
	for id in ch.attuned:
		if ch.end_attunement_blocker(id) != "" and MagicItems.is_cursed(Compendium.shared().item_data(id)):
			out.append(id)
	return out


static func _reader_wis(npc_id: String) -> int:
	var mon := Compendium.shared().monster_data(str(Compendium.shared().get_entry("npcs", npc_id).get("monster", "commoner")))
	return floori((int((mon.get("abilities", {}) as Dictionary).get("wis", 10)) - 10) / 2.0)


# --- When the party's dead died ------------------------------------------------------------------

static func _died_key(ch: Character) -> String:
	return "_died/" + ch.id


## Notes the time for any dead party member not yet noted (StoryState.advance_minutes calls this with the time before
## the clock moved, so a death in a fight is noted at about the time it happened).
static func note_deaths(st: StoryState, at: int) -> void:
	for ch in st.party:
		if ch.dead and not st.flags.has(_died_key(ch)):
			st.flags[_died_key(ch)] = at
		elif not ch.dead and st.flags.has(_died_key(ch)):
			st.flags.erase(_died_key(ch))


## Minutes since `ch` died (0 if alive or just now).
static func dead_for(st: StoryState, ch: Character) -> int:
	if not ch.dead:
		return 0
	note_deaths(st, st.total_minutes())
	return st.total_minutes() - int(st.flags.get(_died_key(ch), st.total_minutes()))


# --- Rooms ---------------------------------------------------------------------------------------

## The room booked for tonight here ("" if none): a booking lasts until the morning after the day it was made.
static func booked(st: StoryState) -> String:
	var b := st.flags.get("_room", {}) as Dictionary
	if b.is_empty() or str(b.get("location", "")) != st.location:
		return ""
	var day := int(b.get("day", 0))
	if st.day == day or (st.day == day + 1 and st.minute_of_day < 10 * 60):
		return str(b.get("id", ""))
	return ""


## After a Long Rest: a room booked here gives its comforts and is used up. Returns what it gave ("" if no room).
static func after_long_rest(st: StoryState) -> String:
	var id := booked(st)
	st.flags.erase("_room")
	if id == "":
		return ""
	var kind := KINDS.get(id, {}) as Dictionary
	var comfort := int(kind.get("comfort", 0))
	for ch in st.party:
		if ch.dead:
			continue
		ch.add_temp_hp(ch.character_level() * comfort, str(kind["name"]))
		if comfort >= 2 and ch.exhaustion > 0:
			ch.exhaustion -= 1
	return "%s: everyone wakes with temporary Hit Points%s." % [kind["name"], " and one more level of Exhaustion gone" if comfort >= 2 else ""]
