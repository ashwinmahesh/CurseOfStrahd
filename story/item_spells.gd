class_name ItemSpells
extends RefCounted
## The spells an item gives its bearer, listed on the character sheet's Spells tab and cast from there outside a fight
## (Ashwin, 2026-10-19). A spell counts while the item that casts it is working: worn or held where it must be, attuned
## where it asks (Character.item_active), so taking the item off takes its spells off the list. Each is marked with what
## it costs (an item's charges, a daily use, or nothing: at will) and what is left.
##
## Nothing here casts by itself: FieldItems.use does (the same call the inventory's item card makes), so charges, daily
## uses, the item's own DC and what a spell leaves behind behave as they do there. This file only decides what is listed
## and what can be cast outside a fight, and says why not when it can't.

const FIGHT_ONLY := "Only in a fight"
## Spells that also work in a fight but are worth casting while exploring: an item's Light lights the lantern (FieldItems.use
## hands the world the spell's id as the `effect`).
const EXPLORING: Array[String] = ["light", "dancing_lights", "continual_flame", "daylight"]


## Every spell the items `ch` has working give, item by item in the order they are carried:
## {item_id, power_id, spell_id, name, item_name, item_charges ("7/10 charges" or ""), level, kind (at_will, charges, uses),
##  usage ("At will", "7/10 charges", "1/1 left"), cost ("1 charge", "once a day", "at will"), cost_note ("+1 per level above
##  1st, up to 4th" or ""), recharge ("at dawn" for a daily use, else ""),
##  left (charges or uses left, -1 at will), levels (the levels the charges reach, [] when there is no choice),
##  level_costs ({level: charges}), dc, attack, save, attacks, count, self_only, others_only, needs_target,
##  choices, choice_labels, targets (the dead a revival can reach, when it is one), legal, reason}.
## `legal` is whether it can be cast now; `reason` says why not ("Only in a fight" for a spell with nothing to do outside one).
static func entries(st: StoryState, ch: Character, dice: DiceRoller) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var e := FieldCasting._board(st.party, ch, dice, 5, st.guests)
	var c := e.get_c(ch.id)
	if c == null:
		return out
	for p in e.items.powers(c):
		var o := _entry(st, ch, e, c, p)
		if not o.is_empty():
			out.append(o)
	return out


## The entry for one power of one item in `list` (entries()), or {}.
static func find(list: Array[Dictionary], item_id: String, power_id: String) -> Dictionary:
	for o in list:
		if str(o["item_id"]) == item_id and str(o["power_id"]) == power_id:
			return o
	return {}


## Whether the item behind power `p` is working for `ch`: worn, held or equipped where it must be and attuned where it asks
## (Character.item_active). A weapon in the second weapon set counts too: the game takes it in hand to use its power
## (CombatItems.power_why).
static func working(ch: Character, p: Dictionary) -> bool:
	if ch.item_active(p["entry"] as Dictionary):
		return true
	var iid := str(p["item_id"])
	var data := p["data"] as Dictionary
	return Gear.is_weapon(data) and ch.weapon_set_of(iid) == 2 and (not MagicItems.needs_attunement(data) or iid in ch.attuned)


static func _entry(st: StoryState, ch: Character, e: Encounter, c: Combatant, p: Dictionary) -> Dictionary:
	var power := p["power"] as Dictionary
	var data := p["data"] as Dictionary
	var iid := str(p["item_id"])
	# Real spells of an item that stays with its bearer: not what a scroll or potion casts once and is gone, not an effect
	# an item names for itself (a recipe), not a power the game uses on its own (hidden), not one a potion left behind.
	var spell_id := str(power.get("spell", ""))
	if p.has("effect") or spell_id == "" or bool(power.get("hidden", false)) or bool(power.get("scroll", false)) \
			or bool(power.get("consume", false)) or MagicItems.is_consumable(data):
		return {}
	var spell := Compendium.shared().spell_data(spell_id)
	if spell.is_empty() or not working(ch, p):
		return {}
	# A Necklace of Prayer Beads casts what its beads hold: none of that kind, no spell.
	if power.has("bead") and CombatItems.use_count(p) <= 0:
		return {}
	var entry := p["entry"] as Dictionary
	var level := int(power.get("level", spell.get("level", 0)))
	var tgt := spell.get("targets", {}) as Dictionary
	var tkind := str(tgt.get("kind", ""))
	# Mass Cure Wounds heals up to six creatures in a sphere: the party, chosen on the sheet like "N of us".
	var group_heal := tkind == "area" and spell.has("heal")
	var o := {"item_id": iid, "power_id": str(power.get("id", "")), "spell_id": spell_id, "name": str(spell.get("name", spell_id)),
		"item_name": MagicItems.display_name(data, entry), "item_charges": "", "level": level,
		"count": 6 if group_heal else int(tgt.get("count", 1)), "others_only": bool(tgt.get("other", false)),
		"self_only": tkind == "self" or bool(power.get("self_only", false)),
		"needs_target": (tkind in ["creature", "ally"] or group_heal) and not bool(power.get("self_only", false)) and not spell_id in EXPLORING,
		"save": spell.has("save"), "attacks": spell.has("attack"), "levels": [], "level_costs": {}, "choices": [],
		"choice_labels": {}, "recharge": "", "cost_note": ""}
	# What it costs and what is left.
	var cost := CombatItems.charge_cost(power, spell, level)
	var uses := power.get("uses", {}) as Dictionary
	if MagicItems.has_charges(data):
		o["item_charges"] = "%d/%d charges" % [CombatItems.charges_of(p), MagicItems.max_charges(data, entry)]
	if power.has("bead") or not uses.is_empty():
		var total := CombatItems.use_count(p)
		var left := maxi(0, total - CombatItems.uses_spent(p))
		var per := str(uses.get("per", "dawn"))
		o["kind"] = "uses"
		o["left"] = left
		o["usage"] = "%d/%d left" % [left, total]
		o["cost"] = ("once a day" if total == 1 else "%d a day" % total) if per == "dawn" else "%d use%s" % [total, "" if total == 1 else "s"]
		o["recharge"] = CombatItems._per_text(per)
	elif cost > 0:
		o["kind"] = "charges"
		o["need"] = cost
		o["left"] = CombatItems.charges_of(p)
		o["usage"] = str(o["item_charges"])
		o["cost"] = "%d charge%s" % [cost, "" if cost == 1 else "s"]
		if power.has("upcast_charges"):
			o["cost_note"] = "+%d per level above %s, up to %s" % [int(power["upcast_charges"]), ActionCatalog._ordinal(level),
				ActionCatalog._ordinal(int(power.get("max_level", 9)))]
		var levels := e.items.level_choices(c, iid, power)
		if levels.size() > 1:
			o["levels"] = levels
			for l in levels:
				(o["level_costs"] as Dictionary)[l] = CombatItems.charge_cost(power, spell, l)
	else:
		o["kind"] = "at_will"
		o["left"] = -1
		o["usage"] = "At will"
		o["cost"] = "at will"
	# What the spell asks for as it is cast.
	var sc := spell.get("choice", {}) as Dictionary
	if str(sc.get("kind", "")) == "option":
		o["choices"] = (sc.get("from", []) as Array).duplicate()
		o["choice_labels"] = sc.get("labels", {})
	var nums := e.items.numbers(c, p, level)
	o["dc"] = (nums["dc"] as Breakdown).total()
	o["attack"] = (nums["attack"] as Breakdown).total()
	# Why not, if not: a spell with no use outside a fight first, then the hero, then the item (charges, uses, the dead).
	var why := FieldItems._field_why(e, c, p)
	var outside := outside_why(e, power, spell)
	if FieldCasting.REVIVAL.has(spell_id):
		o["needs_target"] = true
		o["targets"] = FieldCasting.revivable(st, spell_id)
		if why == "" and (o["targets"] as Array).is_empty():
			var dead := st.party.filter(func(m: Character) -> bool: return m.dead)
			why = FieldCasting.revive_why(st, spell_id, dead[0] as Character) if not dead.is_empty() else "Nobody in the party is dead"
	var reason := outside
	if reason == "" and not c.can_act():
		reason = "%s can't act" % ch.name.get_slice(" ", 0)
	if reason == "":
		reason = why
	o["reason"] = reason
	o["legal"] = reason == ""
	return o


## "" if the spell can be cast outside a fight, else why not: healing and help for the party (FieldCasting.helpful), a
## spell with nothing to do in a fight (Detect Magic, Scrying), Light and the like, a revival, or any a power marks `field`.
static func outside_why(e: Encounter, power: Dictionary, spell: Dictionary) -> String:
	var sid := str(spell.get("id", ""))
	if bool(power.get("field", false)) or FieldCasting.helpful(spell) or FieldCasting.REVIVAL.has(sid) or sid in EXPLORING:
		return ""
	if not e.spells.has_combat_rules(spell) and not sid in FieldCasting.EXPLORING_TOO:
		return ""
	return FIGHT_ONLY


## Casts the spell of `power_id` of `item_id` from `ch`'s items outside a fight, on `targets` (party members or story allies;
## the dead a revival brings back; none for a spell on its caster), at `level` (0: the lowest; more is paid in charges) and
## with `choice` (what the spell asks for). Returns FieldItems.use's {ok, text, lines, effect}; `effect` names what the world
## applies where the party stands (a Wand of Magic Detection's Detect Magic).
static func cast(st: StoryState, ch: Character, item_id: String, power_id: String, targets: Array, level: int, choice: String,
		dice: DiceRoller) -> Dictionary:
	var o := find(entries(st, ch, DiceRoller.new(0)), item_id, power_id)
	if o.is_empty():
		return {"ok": false, "text": "That item isn't working for %s now: it has to be worn or held, and attuned where it asks" % ch.name.get_slice(" ", 0),
			"lines": []}
	if not bool(o["legal"]):
		return {"ok": false, "text": str(o["reason"]), "lines": []}
	var opts := {}
	if level > 0:
		opts["level"] = level
	if choice != "":
		opts["choice"] = choice
	if not targets.is_empty():
		opts["field_targets"] = targets
	var target: Creature = targets[0] as Creature if not targets.is_empty() else ch
	return FieldItems.use(st, ch, item_id, power_id, target, dice, opts)
