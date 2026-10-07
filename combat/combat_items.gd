class_name CombatItems
extends RefCounted
## Magic items in a fight (ADR 0012, docs/contracts/magic_items.md): the Items tab of the hotbar (potions, scrolls,
## oils and every item power: a wand's Fireball, Boots of Speed clicked on, a Flame Tongue set ablaze), casting spells
## from items through the spell engine with the item's own DC or the wielder's, charges and daily uses, and the hooks
## the Encounter calls so weapons, armor and wondrous items do their part (extra damage on a hit, a Vorpal Sword's
## beheading, Adamantine Armor turning a Critical Hit into a hit, a Ring of Evasion, Gloves of Missile Snaring).
## Bespoke powers live in combat/item_specials.gd.

const TAB := "Items"

var _enc: WeakRef
var specials: ItemSpecials


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)
	specials = ItemSpecials.new(self)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func comp() -> Compendium:
	return Compendium.shared()


static func ch_of(c: Combatant) -> Character:
	return c.creature as Character if c != null and c.creature is Character else null


# --- What a creature carries -----------------------------------------------------------------------

## Each distinct item `c` carries: [{id, data, entry}] (entry: the first inventory entry with it).
func carried(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ch := ch_of(c)
	if ch == null:
		return out
	var seen := {}
	for e in ch.inventory:
		var iid := str(e["id"])
		if seen.has(iid) or int(e.get("qty", 0)) <= 0:
			continue
		seen[iid] = true
		var data := comp().item_data(iid)
		if not data.is_empty():
			out.append({"id": iid, "data": data, "entry": e})
	return out


## Items working for `c` right now (attuned, worn or held where they must be): [{id, data, entry}].
func active(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ch := ch_of(c)
	if ch == null:
		return out
	for it in carried(c):
		if ch.item_active(it["entry"] as Dictionary):
			out.append(it)
	return out


## Whether `c` has an active item with this id (or this template, for items built on a base weapon or armor).
func has_active(c: Combatant, item_or_template: String) -> bool:
	return not active_item(c, item_or_template).is_empty()


func active_item(c: Combatant, item_or_template: String) -> Dictionary:
	for it in active(c):
		var d := it["data"] as Dictionary
		if str(it["id"]) == item_or_template or str(d.get("template_id", "")) == item_or_template or str(d.get("variant_of", "")) == item_or_template:
			return it
	return {}


# --- Powers --------------------------------------------------------------------------------------

## Every power `c` could use from its items: [{item_id, data, entry, power}] (MagicItems.powers_of adds the implicit
## ones: drinking a potion, reading a scroll).
func powers(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it in carried(c):
		for p in MagicItems.powers_of(it["data"] as Dictionary):
			out.append({"item_id": it["id"], "data": it["data"], "entry": it["entry"], "power": p})
	# Powers an item left behind for a while (a Potion of Fire Breath's three breaths): kept on the Effect it made.
	for fx in c.creature.effects:
		if not fx.data.has("powers"):
			continue
		var data := comp().item_data(fx.source_id)
		for gp: Variant in fx.data["powers"]:
			out.append({"item_id": fx.source_id, "data": data, "entry": fx.data, "power": gp, "effect": fx})
	return out


func find_power(c: Combatant, item_id: String, power_id: String) -> Dictionary:
	for p in powers(c):
		if str(p["item_id"]) == item_id and str((p["power"] as Dictionary).get("id", "")) == power_id:
			return p
	return {}


## The spell a power casts (a spell id, or the item's own recipe "<item>__<recipe>"), "" for none.
static func power_spell(item_id: String, power: Dictionary) -> String:
	if power.has("spell"):
		return str(power["spell"])
	if power.has("recipe"):
		return "%s__%s" % [MagicItems.recipe_owner(item_id), power["recipe"]]
	return ""


## Charges a use costs at `level` (more for a higher level: a Wand of Fireballs' extra charges).
static func charge_cost(power: Dictionary, spell: Dictionary, level: int) -> int:
	var n := int(power.get("charges", 0))
	var base := int(power.get("level", spell.get("level", 0)))
	if level > base and power.has("upcast_charges"):
		n += int(power["upcast_charges"]) * (level - base)
	return n


## Levels a power can be used at with the charges left (lowest first; [] when it has no choice of level).
func level_choices(c: Combatant, item_id: String, power: Dictionary) -> Array[int]:
	var out: Array[int] = []
	if not power.has("upcast_charges"):
		return out
	var ch := ch_of(c)
	var spell := comp().spell_data(power_spell(item_id, power))
	var base := int(power.get("level", spell.get("level", 0)))
	var top := int(power.get("max_level", 9))
	for l in range(base, top + 1):
		if charge_cost(power, spell, l) <= ch.charges_left(item_id):
			out.append(l)
	return out


func _cost_why(c: Combatant, cost: String) -> String:
	var e := enc()
	match cost:
		"magic":
			var w := e._action_check(c)
			if w == "" and c.magic_action_used:
				w = "Only one Magic action this turn"
			if w == "" and c.surged and not c.action_available:
				w = "Action Surge's action can't be a Magic action"
			return w
		"action", "utilize":
			return e._action_check(c)
		"bonus":
			return e._bonus_check(c)
		"reaction":
			return "Used as a Reaction when it triggers"
		"attack":
			return e.features_attack_why(c)
		"free":
			return e._turn_check(c)
	return e._action_check(c)


func _pay(c: Combatant, cost: String) -> void:
	var e := enc()
	match cost:
		"magic":
			e.spend_action(c)
			c.magic_action_used = true
		"action", "utilize":
			e.spend_action(c)
		"bonus":
			c.bonus_available = false
		"reaction":
			c.reaction_available = false
		"attack":
			e.use_one_attack(c)


## "" if `c` can use `power` of the item now, else why not.
func power_why(c: Combatant, p: Dictionary, level: int = 0) -> String:
	var ch := ch_of(c)
	var data := p["data"] as Dictionary
	var power := p["power"] as Dictionary
	var iid := str(p["item_id"])
	if ch == null:
		return "Only characters use items"
	if MagicItems.is_magic(data) and enc().spells.specials.high.in_antimagic(c):
		return "Antimagic Field: the item's magic is suppressed"
	var req := str(power.get("requires", ""))
	if MagicItems.needs_attunement(data) and not iid in ch.attuned and req != "anyone":
		return "Needs attunement"
	# Worn items have to be worn (a cloak in a pack does nothing); held items are drawn as part of the use.
	if MagicItems.worn_slot(data) != "" and not ch.item_active(p["entry"] as Dictionary) and req != "anyone":
		return "Wear it first (%s)" % MagicItems.SLOT_NAMES.get(MagicItems.worn_slot(data), "")
	if req == "worn_or_held" and not ch.item_active(p["entry"] as Dictionary):
		return "Hold it first"
	if bool(power.get("combat", true)) == false:
		return "Outside combat only"
	var spell_id := power_spell(iid, power)
	var spell := comp().spell_data(spell_id) if spell_id != "" else {}
	if spell_id != "" and spell.is_empty():
		return "Not available yet (the spell arrives in a later build)"
	if not spell.is_empty() and not enc().spells.has_combat_rules(spell) and not power.has("custom"):
		return "No effect in a fight"
	var need := charge_cost(power, spell, maxi(level, int(power.get("level", spell.get("level", 0)))))
	if need > 0 and charges_of(p) < need:
		return "Not enough charges (%d left, needs %d)" % [charges_of(p), need]
	var uses := power.get("uses", {}) as Dictionary
	if power.has("bead") and use_count(p) <= 0:
		return "No bead of %s on the necklace" % str(power["bead"]).replace("_", " ")
	for gk: String in ["gem", "needs_gem"]:
		if power.has(gk) and int(((p["entry"] as Dictionary).get("gems", {}) as Dictionary).get(str(power[gk]), 0)) <= 0:
			return "No %s left in it" % str(power[gk]).replace("_", " ")
	if not uses.is_empty() and uses_spent(p) >= use_count(p):
		var cd := int(((p["entry"] as Dictionary).get("cooldowns", {}) as Dictionary).get(str(power["id"]), 0))
		if cd > 0:
			return "Ready again in %d day%s" % [cd, "" if cd == 1 else "s"]
		return "Used (comes back %s)" % _per_text(str(uses.get("per", "dawn")))
	var budget := int(power.get("budget_rounds", 0))
	if budget > 0 and int(((p["entry"] as Dictionary).get("budget_used", {}) as Dictionary).get(str(power["id"]), 0)) >= budget \
			and not toggled(c, iid, str(power["id"])):
		return "Its magic is spent until %s" % ("never" if str(power.get("budget_reset", "")) == "never" else "a Long Rest")
	if int(power.get("needs_charges", 0)) > charges_of(p) and not (bool(power.get("toggle", false)) and toggled(c, iid, str(power["id"]))):
		return "No charges left"
	if bool(power.get("scroll", false)):
		var sw := scroll_why(ch, spell)
		if sw != "":
			return sw
	if not spell.is_empty() and bool((spell.get("components", {}) as Dictionary).get("v", false)) and bool(power.get("scroll", false)):
		if c.creature.has_flag("speechless"):
			return "Can't speak"
		for cell in c.footprint():
			if enc().spells.zones.silenced(cell):
				return "Silence: can't read the scroll aloud"
	var custom_why := specials.why(c, p)
	if custom_why != "":
		return custom_why
	var cost := str(power.get("cost", "magic"))
	if spell.has("casting_time") and not power.has("cost"):
		var unit := str((spell["casting_time"] as Dictionary).get("unit", "action"))
		cost = "bonus" if unit == "bonus_action" else ("reaction" if unit == "reaction" else "magic")
	if bool(power.get("toggle", false)) and toggled(c, iid, str(power["id"])) and str(power.get("off_cost", "")) == "free":
		return enc()._turn_check(c)
	return _cost_why(c, cost)


## Charges left on the item behind a power.
static func charges_of(p: Dictionary) -> int:
	return int((p["entry"] as Dictionary).get("charges", 0))


static func uses_spent(p: Dictionary) -> int:
	return int(((p["entry"] as Dictionary).get("uses", {}) as Dictionary).get(_use_key(p), 0))


## Uses are counted per power, except prayer beads: each bead of a kind gives one use a day.
static func _use_key(p: Dictionary) -> String:
	var power := p["power"] as Dictionary
	return "bead:%s" % power["bead"] if power.has("bead") else str(power.get("id", ""))


## How many uses a power has: its `uses.count`, or the number of beads of its kind on a Necklace of Prayer Beads.
static func use_count(p: Dictionary) -> int:
	var power := p["power"] as Dictionary
	if power.has("bead"):
		return ((p["entry"] as Dictionary).get("beads", []) as Array).count(str(power["bead"]))
	return int((power.get("uses", {}) as Dictionary).get("count", 1))


static func spend_use(p: Dictionary) -> void:
	var entry := p["entry"] as Dictionary
	if not entry.has("uses"):
		entry["uses"] = {}
	var u := entry["uses"] as Dictionary
	var pid := _use_key(p)
	u[pid] = int(u.get(pid, 0)) + 1
	# "Once every N days" (Figurines of Wondrous Power): a countdown of dawns.
	var per := str(((p["power"] as Dictionary).get("uses", {}) as Dictionary).get("per", ""))
	if per.begins_with("dawns:"):
		if not entry.has("cooldowns"):
			entry["cooldowns"] = {}
		(entry["cooldowns"] as Dictionary)[pid] = int(per.substr(6))


static func _per_text(per: String) -> String:
	match per:
		"long":
			return "after a Long Rest"
		"short":
			return "after a Short or Long Rest"
		"never":
			return "never"
	return "at dawn"


## The action cost of using a power (spell powers default to the spell's casting time, as a Magic action).
static func power_cost(power: Dictionary, spell: Dictionary) -> String:
	if power.has("cost"):
		return str(power["cost"])
	if spell.has("casting_time"):
		var unit := str((spell["casting_time"] as Dictionary).get("unit", "action"))
		return "bonus" if unit == "bonus_action" else ("reaction" if unit == "reaction" else "magic")
	return "magic"


## Reading a Spell Scroll (2024 DMG): the spell must be on one of your classes' lists; one of a higher level than
## you can cast needs a check (made when you read it). "" or why not.
static func scroll_why(ch: Character, spell: Dictionary) -> String:
	for entry in ch.spellcasting:
		if str(entry.get("list", entry.get("class_id", ""))) in (spell.get("classes", []) as Array) or str(entry.get("class_id", "")) in (spell.get("classes", []) as Array):
			return ""
	return "Not on your class's spell list"


# --- The hotbar ----------------------------------------------------------------------------------

## Hotbar entries for every item power (ActionCatalog's Items tab). A spell power is kind "item_spell" (it targets
## like the spell and shows charge levels as pips); everything else is kind "item".
func list(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ch := ch_of(c)
	if ch == null:
		return out
	for p in powers(c):
		var power := p["power"] as Dictionary
		if not bool(power.get("combat", true)) or bool(power.get("hidden", false)):
			continue
		var data := p["data"] as Dictionary
		var iid := str(p["item_id"])
		var spell_id := power_spell(iid, power)
		var spell := comp().spell_data(spell_id) if spell_id != "" else {}
		var why := power_why(c, p)
		var cost := power_cost(power, spell)
		var label := str(data.get("name", iid))
		var pname := str(power.get("name", ""))
		if pname != "" and pname != label:
			label = "%s: %s" % [label, pname]
		if bool(power.get("toggle", false)) and toggled(c, iid, str(power["id"])):
			label = "✓ " + label
		var sub := _power_sub(c, p, spell)
		var targeting := str(power.get("targeting", ""))
		if targeting == "" and not spell.is_empty():
			targeting = ActionCatalog.spell_targeting(spell)
		if targeting == "":
			targeting = "none"
		var a := {"id": "item:%s:%s" % [iid, power.get("id", "use")], "tab": TAB, "label": label, "sub": sub,
			"cost": "action" if cost in ["magic", "utilize"] else cost, "legal": why == "", "reason": why,
			"targeting": targeting, "count": int(power.get("count", 1)), "repeat": false, "range": int(power.get("range", 0)), "spell_id": "", "slot": 0,
			"option_id": "", "kind": "item", "help": str(power.get("text", data.get("summary", ""))),
			"item_id": iid, "power_id": str(power.get("id", "use"))}
		if not spell.is_empty():
			a["kind"] = "item_spell"
			a["spell_id"] = spell_id
			a["slot"] = int(power.get("level", spell.get("level", 0)))
			a["range"] = enc().spells.range_ft(spell, c)
			var t := spell.get("targets", {}) as Dictionary
			a["count"] = int(t.get("count", 1))
			a["repeat"] = spell_id in ["magic_missile", "scorching_ray"]
			a["concentration"] = bool((spell.get("duration", {}) as Dictionary).get("concentration", false))
			a["levels"] = level_choices(c, iid, power)
			var nums := numbers(c, p, int(a["slot"]))
			a["dc"] = (nums["dc"] as Breakdown).total()
			a["attack_bonus"] = (nums["attack"] as Breakdown).total()
			var choice := spell.get("choice", {}) as Dictionary
			if not choice.is_empty():
				var opts_list: Array = []
				for v: Variant in choice.get("from", []):
					opts_list.append({"value": str(v), "label": str(v).replace("_", " ").capitalize()})
				a["choices"] = opts_list
				a["choice_label"] = str(choice.get("label", "Choose"))
				a["opts"] = {"choice": str((opts_list[0] as Dictionary)["value"])}
		var pchoice := power.get("choice", {}) as Dictionary
		if not pchoice.is_empty():
			var po: Array = []
			for v: Variant in pchoice.get("from", []):
				po.append({"value": str(v), "label": str(v).replace("_", " ").capitalize()})
			a["choices"] = po
			a["choice_label"] = str(pchoice.get("label", "Choose"))
			a["opts"] = {"choice": str((po[0] as Dictionary)["value"])}
		out.append(a)
	return out


func _power_sub(c: Combatant, p: Dictionary, spell: Dictionary) -> String:
	var ch := ch_of(c)
	var data := p["data"] as Dictionary
	var power := p["power"] as Dictionary
	var iid := str(p["item_id"])
	var bits: Array[String] = []
	if MagicItems.has_charges(data) and not p.has("effect"):
		bits.append("%d/%d charges" % [charges_of(p), MagicItems.max_charges(data, p["entry"] as Dictionary)])
	var uses := power.get("uses", {}) as Dictionary
	if not uses.is_empty():
		bits.append("%d/%d left" % [maxi(0, use_count(p) - uses_spent(p)), use_count(p)])
	if (MagicItems.is_consumable(data) or bool(power.get("consume", false))) and not p.has("effect"):
		var n := 0
		for e in ch.inventory:
			if str(e["id"]) == iid:
				n += int(e["qty"])
		bits.append("%d left" % n)
	if not spell.is_empty() and int(spell.get("level", 0)) > 0 and not str(spell.get("id", "")).contains(MagicItems.SEP):
		bits.append("Level %d" % int(power.get("level", spell.get("level", 0))))
	if str(power.get("sub", "")) != "":
		bits.append(str(power["sub"]))
	return " · ".join(bits)


## Carries out a hotbar item entry.
func perform(c: Combatant, action: Dictionary, targets: Array, point: Vector2, dir: Vector2, level: int, opts: Dictionary) -> CombatResult:
	var all_opts := (action.get("opts", {}) as Dictionary).duplicate()
	all_opts.merge(opts, true)
	return use(c, str(action.get("item_id", "")), str(action.get("power_id", "")), targets, point, dir, level, all_opts)


## Uses a power of an item `c` carries (the command, docs/contracts/magic_items.md): targets, a point or a direction as
## the power's spell wants them; `level` for a higher level paid with more charges.
func use(c: Combatant, item_id: String, power_id: String, targets: Array = [], point: Vector2 = Vector2.INF,
		dir: Vector2 = Vector2.ZERO, level: int = 0, opts: Dictionary = {}) -> CombatResult:
	var e := enc()
	var why := e._turn_check(c)
	if why != "":
		return CombatResult.fail(why)
	if not c.can_act():
		return CombatResult.fail("%s can't act" % c.name())
	var p := find_power(c, item_id, power_id)
	if p.is_empty():
		return CombatResult.fail("Not carried")
	why = power_why(c, p, level)
	if why != "":
		return CombatResult.fail(why)
	var power := p["power"] as Dictionary
	var spell_id := power_spell(item_id, power)
	var spell := comp().spell_data(spell_id) if spell_id != "" else {}
	var lvl := maxi(level, int(power.get("level", spell.get("level", 0))))
	var cost := power_cost(power, spell)
	if bool(power.get("toggle", false)):
		return toggle(c, p, opts)
	# A power that only works on its user (the Calimemnon Crystal's Invisibility).
	if bool(power.get("self_only", false)):
		targets = [c]
	var who: Combatant = targets[0] as Combatant if not targets.is_empty() and targets[0] is Combatant else c
	if power.has("custom"):
		var r0 := specials.use(c, p, targets, point, dir, lvl, opts)
		if r0.ok:
			_grant(c, who, p)
			_after_use(c, p, spell, lvl)
		return r0
	if spell.is_empty():
		return CombatResult.fail("Nothing to do")
	# A higher-level scroll may fail to cast (2024 DMG): spellcasting ability check against 10 + the spell's level.
	if bool(power.get("scroll", false)):
		var fail := scroll_check(c, spell)
		if fail != "":
			_pay(c, cost)
			_after_use(c, p, spell, lvl)
			return CombatResult.fail(fail)
	var nums := numbers(c, p, lvl)
	# Arcanist's Bestiary: creatures other than these save with Disadvantage.
	if power.has("disadvantage_unless"):
		opts = opts.duplicate()
		opts["dis_unless"] = power["disadvantage_unless"]
	var label := str(spell.get("name", "")) if str(spell.get("name", "")) == str(p["data"].get("name", item_id)) \
		else "%s (%s)" % [spell.get("name", ""), p["data"].get("name", item_id)]
	var r := cast(c, spell, lvl, targets, point, dir, nums, cost, opts, label)
	if r.ok:
		_grant(c, who, p)
		_after_use(c, p, spell, lvl)
	return r


## A power that leaves powers behind for a while (`grants`): an Effect on whoever used or drank it carries them.
func _grant(c: Combatant, who: Combatant, p: Dictionary) -> void:
	var power := p["power"] as Dictionary
	if not power.has("grants") or who == null:
		return
	var g := power["grants"] as Dictionary
	var data := p["data"] as Dictionary
	var fx := Effect.new(str(data.get("name", "")), &"item", str(p["item_id"]))
	fx.stack_key = "item_grant:%s" % p["item_id"]
	fx.caster_id = c.id
	if g.has("hours"):
		fx.lasting({"kind": "hours", "amount": int(g["hours"])})
	elif g.has("minutes"):
		fx.lasting({"kind": "minutes", "amount": int(g["minutes"])})
		fx.turn_owner_id = who.id
	fx.data["powers"] = (g.get("powers", []) as Array).duplicate(true)
	fx.data["id"] = str(p["item_id"])
	who.creature.add_effect(fx)


## Charges, daily uses and consumption after a power was used; an item whose last charge is spent may crumble.
func _after_use(c: Combatant, p: Dictionary, spell: Dictionary, level: int) -> void:
	var ch := ch_of(c)
	var data := p["data"] as Dictionary
	var power := p["power"] as Dictionary
	var iid := str(p["item_id"])
	var need := charge_cost(power, spell, level)
	var entry := p["entry"] as Dictionary
	if need > 0:
		entry["charges"] = maxi(0, int(entry.get("charges", 0)) - need)
		if int(entry["charges"]) <= 0:
			last_charge(c, iid, data)
	# Helm of Brilliance: the gem is spent.
	if power.has("gem"):
		var gems := entry.get("gems", {}) as Dictionary
		gems[str(power["gem"])] = maxi(0, int(gems.get(str(power["gem"]), 0)) - 1)
	if power.has("after"):
		specials.more.after_power(c, p)
	if power.has("uses"):
		spend_use(p)
		# A granted power used up ends what granted it (the potion's breath is spent).
		if p.has("effect") and bool(power.get("ends_effect", false)) and uses_spent(p) >= int((power["uses"] as Dictionary).get("count", 1)):
			c.creature.remove_effect(p["effect"] as Effect)
	if p.has("effect"):
		return
	if bool(power.get("consume", false)) or (MagicItems.is_consumable(data) and not MagicItems.has_charges(data) and not power.has("uses")):
		ch.remove_one(iid)
	ch.items_changed()


## The last charge is gone: some items crumble (2024 DMG: roll a d20, on a 1 it's destroyed), others lose their magic.
func last_charge(c: Combatant, item_id: String, data: Dictionary) -> void:
	var spec := MagicItems.charges(data)
	var rule := spec.get("last", {}) as Dictionary
	if rule.is_empty():
		return
	var e := enc()
	var roll := e.dice.roll_one(int(rule.get("die", 20)), "%s: last charge" % data.get("name", ""))
	if roll <= int(rule.get("on", 1)):
		var ch := ch_of(c)
		ch.unequip_item(item_id)
		ch.remove_one(item_id)
		var outcome := str(rule.get("result", "destroyed"))
		if outcome == "nonmagical" and data.has("base_item"):
			ch.add_item(str(data["base_item"]))
		e.log.add("info", "%s's %s %s (rolled %d)" % [c.name(), data.get("name", ""), str(rule.get("text", "crumbles to dust")), roll], c.id)


## A scroll of a higher level than the reader can cast: a check with their spellcasting ability, DC 10 + level. "" if it
## works, else what happened.
func scroll_check(c: Combatant, spell: Dictionary) -> String:
	var ch := ch_of(c)
	var level := int(spell.get("level", 0))
	var top := 0
	for l in range(1, 10):
		if ch.spell_slots()[l - 1] > 0:
			top = l
	if level <= top or level == 0:
		return ""
	var ab := StringName(str(ch.spellcasting[0].get("ability", "int"))) if not ch.spellcasting.is_empty() else &"int"
	var t := ch.roll_check(enc().dice, ab, 10 + level, [], [], "Reading a level %d scroll" % level)
	enc().log.add("roll", "%s reads a scroll beyond their skill: %s" % [c.name(), "it works" if t.success else "the words fade"], c.id, [t.describe()])
	return "" if t.success else "The spell fades from the scroll (failed the check, DC %d)" % (10 + level)


## The DC, attack bonus and modifier a power casts with: a fixed number from the item ("dc": 15), the wielder's own
## ("wielder", the best of their spellcasting), or a Spell Scroll's by level.
func numbers(c: Combatant, p: Dictionary, level: int) -> Dictionary:
	var power := p["power"] as Dictionary
	var data := p["data"] as Dictionary
	var item_name := str(data.get("name", ""))
	var best := _wielder_numbers(c)
	var dc := best["dc"] as Breakdown
	var atk := best["attack"] as Breakdown
	var dcv: Variant = power.get("dc", "wielder")
	if dcv is int or dcv is float:
		dc = Breakdown.new("Spell save DC").add(item_name, int(dcv))
	var av: Variant = power.get("attack", "wielder" if not (dcv is int or dcv is float) else int(dcv) - 8)
	if av is int or av is float:
		atk = Breakdown.new("Spell attack").add(item_name, int(av))
	# Spell Scroll (2024 DMG): save DC and attack bonus by the spell's level.
	if bool(power.get("scroll", false)):
		var lv := int(comp().spell_data(power_spell(str(p["item_id"]), power)).get("level", level))
		var sdc := int(MagicItems.SCROLL_DC[clampi(lv, 0, 9)])
		dc = Breakdown.new("Spell save DC").add("Spell Scroll", sdc)
		atk = Breakdown.new("Spell attack").add("Spell Scroll", sdc - 8)
	return {"dc": dc, "attack": atk, "mod": int(best["mod"]), "ability": best["ability"]}


## The wielder's best spellcasting numbers (a non-caster: 8 + Proficiency + their best mental modifier).
func _wielder_numbers(c: Combatant) -> Dictionary:
	var ch := ch_of(c)
	var best := {}
	for entry in ch.spellcasting:
		var n := enc().spells.numbers(c, {"class_id": str(entry["class_id"])})
		if best.is_empty() or (n["dc"] as Breakdown).total() > (best["dc"] as Breakdown).total():
			best = n
	if not best.is_empty():
		return best
	var ab: StringName = &"int"
	for a: StringName in [&"wis", &"cha"]:
		if ch.ability_mod(a) > ch.ability_mod(ab):
			ab = a
	return enc().spells.numbers(c, {"ability": str(ab)})


## Casts `spell` (a spell or an item recipe) from an item: the item's action cost, no slot, the given numbers.
## Mirrors SpellCaster.cast_with_numbers for the spell itself (targets, Concentration, areas, resolution).
func cast(c: Combatant, spell: Dictionary, level: int, targets: Array, point: Vector2, dir: Vector2, nums: Dictionary,
		cost: String, opts: Dictionary, label: String) -> CombatResult:
	var e := enc()
	var sp := e.spells
	# A duration rolled when it starts (Potion of Growth: 1d4 hours).
	var dur := spell.get("duration", {}) as Dictionary
	if dur.has("dice"):
		spell = spell.duplicate(true)
		(spell["duration"] as Dictionary)["amount"] = int(e.dice.roll_expr(str(dur["dice"]), "%s duration" % spell.get("name", ""))["total"])
	var check := sp._check_targets(c, spell, level, targets, point, opts)
	if str(check["why"]) != "":
		return CombatResult.fail(str(check["why"]))
	_pay(c, cost)
	var tgt := check["targets"] as Array[Combatant]
	if c.hidden and bool((spell.get("components", {}) as Dictionary).get("v", false)):
		e.reveal(c, "cast a spell aloud")
	sp.end_sanctuary(c, "cast a spell")
	sp.trigger_ends(c, "cast_spell")
	var conc: Concentration = null
	if bool((spell.get("duration", {}) as Dictionary).get("concentration", false)):
		conc = c.creature.begin_concentration(str(spell["id"]), str(spell["name"]))
		sp.zones.prune()
		sp._prune_sustained()
	var choice := SpellCaster.choice_of(spell, opts)
	e.log.add("spell", "%s uses %s%s" % [c.name(), label, (": " + choice.capitalize().replace("_", " ")) if choice != "" else ""], c.id,
		["Save DC %d · Attack %+d" % [(nums["dc"] as Breakdown).total(), (nums["attack"] as Breakdown).total()]])
	var cells: Array[Vector2i] = []
	if spell.has("area"):
		var d := dir
		if d == Vector2.ZERO and not tgt.is_empty():
			d = (e.center_of(tgt[0]) - e.center_of(c)).normalized()
		cells = sp.area_for(c, spell, point, d, level)
	e.events.append({"type": "spell", "caster": c.id, "spell": str(spell["id"]), "cells": cells,
		"targets": tgt.map(func(t: Combatant) -> String: return t.id)})
	var ctx := {"c": c, "s": spell, "slot": level, "nums": nums, "conc": conc, "opts": opts, "point": point, "cells": cells,
		"choice": choice, "direction": dir, "cell": check["cell"], "item": true}
	if opts.has("dis_unless") and not tgt.is_empty() and not str(tgt[0].creature.creature_type) in (opts["dis_unless"] as Array):
		ctx["save_disadvantage"] = [label]
	var r := CombatResult.new()
	sp._resolve(ctx, tgt, cells, r)
	sp._finish_concentration(ctx)
	sp.zones.prune()
	e._check_over()
	return e.then(r, func() -> CombatResult: return e.run_reaction_queue(r))


# --- Toggles (a Flame Tongue set ablaze, Boots of Speed clicked on) ---------------------------------

static func toggle_key(item_id: String, power_id: String) -> String:
	return "item:%s:%s" % [item_id, power_id]


func toggled(c: Combatant, item_id: String, power_id: String) -> bool:
	return toggle_effect(c, item_id, power_id) != null


func toggle_effect(c: Combatant, item_id: String, power_id: String) -> Effect:
	var key := toggle_key(item_id, power_id)
	for fx in c.creature.effects:
		if fx.stack_key == key:
			return fx
	return null


## Switches a toggle power on (an Effect with the power's modifiers, lasting its `minutes` or until switched off) or off.
func toggle(c: Combatant, p: Dictionary, opts: Dictionary = {}) -> CombatResult:
	var e := enc()
	var power := p["power"] as Dictionary
	var data := p["data"] as Dictionary
	var iid := str(p["item_id"])
	var pid := str(power["id"])
	var on := toggle_effect(c, iid, pid)
	if on != null:
		if str(power.get("off_cost", "")) != "free":
			_pay(c, power_cost(power, {}))
		c.creature.remove_effect(on)
		detach_light(c, toggle_key(iid, pid))
		e.log.add("info", "%s: %s ends" % [c.name(), power.get("name", data.get("name", ""))], c.id)
		e.events.append({"type": "condition", "id": c.id})
		return CombatResult.new()
	_pay(c, power_cost(power, {}))
	var fx := make_power_effect(c, iid, data, power)
	if opts.has("choice"):
		fx.data["choice"] = str(opts["choice"])
	c.creature.add_effect(fx)
	if power.has("custom_light"):
		var cl := power["custom_light"] as Dictionary
		attach_light(c, toggle_key(iid, pid), int(cl.get("bright", 0)), int(cl.get("dim", 0)), bool(cl.get("sunlight", false)))
		var key := toggle_key(iid, pid)
		var cid := c.id
		fx.on_end = func() -> void: detach_light_of(cid, key)
	specials.toggled_on(c, p, fx)
	_after_use(c, p, {}, 0)
	e.log.add("info", "%s: %s" % [c.name(), power.get("log", "%s %s" % [data.get("name", ""), power.get("name", "")])], c.id)
	e.events.append({"type": "condition", "id": c.id})
	return CombatResult.new()


## An Effect on the user from a power's `modifiers` (and `light`), keyed so the item's rules can find it.
static func make_power_effect(c: Combatant, item_id: String, data: Dictionary, power: Dictionary) -> Effect:
	var fx := Effect.new(str(power.get("name", data.get("name", ""))) if str(power.get("name", "")) != "" else str(data.get("name", "")), &"item", item_id)
	fx.stack_key = toggle_key(item_id, str(power.get("id", "")))
	fx.caster_id = c.id
	for cond: Variant in power.get("conditions_on", []):
		fx.conditions.append(StringName(str(cond)))
	for md: Variant in power.get("modifiers", []):
		var d := (md as Dictionary).duplicate(true)
		var w := d.get("when", {}) as Dictionary
		if str(w.get("item", "")) == "@self":
			w["item"] = item_id
		if d.has("items"):
			d["items"] = (d["items"] as Array).map(func(x: Variant) -> String: return item_id if str(x) == "@self" else str(x))
		fx.modifiers.append(Modifier.make(d, str(data.get("name", item_id)), &"item", item_id))
	if power.has("minutes"):
		fx.lasting({"kind": "minutes", "amount": int(power["minutes"])})
		fx.turn_owner_id = c.id
	elif power.has("hours"):
		fx.lasting({"kind": "hours", "amount": int(power["hours"])})
	elif power.has("rounds"):
		fx.lasting_rounds(int(power["rounds"]), c.id)
	fx.data["item_toggle"] = true
	return fx


# --- Light from items -----------------------------------------------------------------------------

## Light that follows `c` (a Flame Tongue ablaze, a Sun Blade's sunlight): a lingering light object keyed by `key`.
func attach_light(c: Combatant, key: String, bright: int, dim: int, sunlight: bool = false) -> FieldObject:
	var e := enc()
	detach_light(c, key)
	var o := FieldObject.new(FieldObject.Kind.ZONE, key, key)
	o.caster_id = c.id
	o.cell = c.cell
	o.rules = {"light": {"bright": bright, "dim": dim, "sunlight": sunlight}, "light_on": "target", "light_target": c.id, "item_light": key}
	o.rounds_left = 100000
	e.spells.zones.add(o, CombatResult.new())
	return o


func detach_light(c: Combatant, key: String) -> void:
	detach_light_of(c.id, key)


## The same by the creature's id (an Effect's on_end keeps the id, not the creature, so nothing holds itself).
func detach_light_of(cid: String, key: String) -> void:
	for o in enc().spells.zones.live():
		if o.caster_id == cid and str(o.rules.get("item_light", "")) == key:
			o.ended = true
	enc().spells.zones.prune()


## When a fight starts: drawn weapons and worn items that shed light light up (a Sun Blade, a Mace of Disruption, a
## Moon-Touched Sword in the dark).
func combat_started() -> void:
	var e := enc()
	# Toggles left on from an earlier fight (a Flame Tongue still ablaze) start each fight off.
	for c0 in e.combatants:
		for fx: Effect in c0.creature.effects.duplicate():
			if bool(fx.data.get("item_toggle", false)) and fx.ends == Effect.Ends.NEVER:
				c0.creature.remove_effect(fx)
	specials.combat_started()
	for c in e.combatants:
		for it in active(c):
			var data := it["data"] as Dictionary
			var l := data.get("light", {}) as Dictionary
			if str(l.get("when", "")) != "drawn":
				continue
			if bool(l.get("dark_only", false)) and e.ambient_light == "bright":
				continue
			attach_light(c, "light:%s" % it["id"], int(l.get("bright", 0)), int(l.get("dim", 0)), bool(l.get("sunlight", false)))


# --- Weapons and ammunition -----------------------------------------------------------------------

## The item and ammunition behind an attack option: [{id, data}] for those that are working (attuned if needed).
func attack_items(c: Combatant, option: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ch := ch_of(c)
	if ch == null or not option.has("profile"):
		return out
	var p := option["profile"] as WeaponProfile
	for iid: String in [p.item_id, p.ammo_id]:
		if iid == "" or iid == "unarmed_strike":
			continue
		var data := comp().item_data(iid)
		if data.is_empty() or (MagicItems.needs_attunement(data) and not iid in ch.attuned):
			continue
		out.append({"id": iid, "data": data})
	# Unarmed Strikes with magic wraps worn on the hands.
	if p.item_id == "unarmed_strike":
		for it in active(c):
			if (it["data"] as Dictionary).has("unarmed_rules"):
				out.append({"id": it["id"], "data": it["data"], "unarmed": true})
	return out


static func _rules(data: Dictionary, unarmed: bool = false) -> Dictionary:
	return (data.get("unarmed_rules" if unarmed else "weapon_rules", {}) as Dictionary)


## Whether a weapon rule's conditions hold: `vs` creature types, `while` a toggle is on, `nat20`/`crit` only.
func _rule_applies(c: Combatant, target: Combatant, iid: String, rule: Dictionary, st: Dictionary) -> bool:
	var vs := rule.get("vs", []) as Array
	if not vs.is_empty() and not str(target.creature.creature_type) in vs:
		return false
	if str(target.creature.creature_type) in (rule.get("not_vs", []) as Array):
		return false
	if rule.has("thrown") and bool(rule["thrown"]) != (str((st["option"] as Dictionary).get("kind", "")) == "thrown"):
		return false
	if rule.has("while") and not toggled(c, iid, str(rule["while"])):
		return false
	if bool(rule.get("nat20", false)) and not (st.has("t") and (st["t"] as D20Test).kept == 20):
		return false
	if bool(rule.get("crit", false)) and not bool(st.get("critical", false)):
		return false
	if rule.has("vs_marked") and str(c.get_meta(str(rule["vs_marked"]), "")) != target.id:
		return false
	if rule.has("ranged") and bool(rule["ranged"]) == bool((st["option"] as Dictionary).get("melee", true)):
		return false
	if rule.has("melee") and bool(rule["melee"]) != bool((st["option"] as Dictionary).get("melee", true)):
		return false
	if int(rule.get("spend_charge", 0)) > 0:
		var ch := ch_of(c)
		if ch == null or ch.charges_left(iid) < int(rule["spend_charge"]):
			return false
	return true


## Extra damage dice the attacker's weapon or ammunition adds on a hit (Flame Tongue's fire, Dragon Slayer against
## Dragons, a Sun Blade against Undead, Ammunition of Slaying's save...).
func hit_damage_dice(c: Combatant, target: Combatant, option: Dictionary, st: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it in attack_items(c, option):
		var data := it["data"] as Dictionary
		var rules := _rules(data, bool(it.get("unarmed", false)))
		for x: Variant in rules.get("extra", []):
			var rule := x as Dictionary
			if not _rule_applies(c, target, str(it["id"]), rule, st):
				continue
			var ty := str(rule.get("type", (option["profile"] as WeaponProfile).damage_type))
			out.append({"dice": str(rule.get("dice", "1d6")), "type": ty, "label": str(data.get("name", ""))})
			# Armed powers that fire once and cost charges (Staff of Power's Power Strike, Staff of Withering).
			if int(rule.get("spend_charge", 0)) > 0:
				var ch := ch_of(c)
				ch.spend_charges(str(it["id"]), int(rule["spend_charge"]))
				if ch.charges_left(str(it["id"])) <= 0:
					last_charge(c, str(it["id"]), data)
			if rule.has("ends_toggle"):
				var fx := toggle_effect(c, str(it["id"]), str(rule["ends_toggle"]))
				if fx != null:
					c.creature.remove_effect(fx)
		out.append_array(specials.hit_dice(c, target, option, st, it))
	return out


## After a hit: weapon riders (Giant Slayer's knockdown, Mace of Disruption, Sword of Wounding, a Vorpal Sword...) and
## ammunition that loses its magic.
func after_hit(c: Combatant, target: Combatant, option: Dictionary, dr: DamageResult, st: Dictionary, r: CombatResult) -> void:
	for it in attack_items(c, option):
		var data := it["data"] as Dictionary
		var rules := _rules(data, bool(it.get("unarmed", false)))
		for x: Variant in rules.get("on_hit", []):
			var rule := x as Dictionary
			if not _rule_applies(c, target, str(it["id"]), rule, st) or not target.is_alive():
				continue
			var with_id := data.duplicate()
			with_id["id"] = str(it["id"])
			_on_hit_rule(c, target, with_id, rule, r)
		specials.after_hit(c, target, option, dr, st, r, it)
	after_attack(c, target, option, true)


func after_miss(c: Combatant, target: Combatant, option: Dictionary, _r: CombatResult) -> void:
	after_attack(c, target, option, false)


## Any attack, hit or miss: a thrown weapon that returns to its wielder's hand (Dwarven Thrower, Hammer of
## Thunderbolts, a weapon with the `returns` rule) comes back.
func after_attack(c: Combatant, _target: Combatant, option: Dictionary, _hit: bool) -> void:
	var ch := ch_of(c)
	if ch == null or str(option.get("kind", "")) != "thrown":
		return
	var p := option["profile"] as WeaponProfile
	var data := comp().item_data(p.item_id)
	if bool(_rules(data).get("returns", false)) and (not MagicItems.needs_attunement(data) or p.item_id in ch.attuned):
		for e in ch.inventory:
			if str(e["id"]) == p.item_id:
				e["qty"] = int(e["qty"]) + 1
				enc().log.add("info", "%s flies back to %s's hand" % [data.get("name", ""), c.name()], c.id)
				return
		ch.add_item(p.item_id)


## One `on_hit` rule: a save against the item's DC with effects on a failure (and damage, half or none on a success).
func _on_hit_rule(c: Combatant, target: Combatant, data: Dictionary, rule: Dictionary, r: CombatResult) -> void:
	var e := enc()
	var label := str(data.get("name", ""))
	if rule.has("max_size") and Creature.SIZES.find(target.creature.size) > Creature.SIZES.find(StringName(str(rule["max_size"]))):
		return
	var failed := true
	if rule.has("save"):
		var ab := StringName(str(rule["save"]))
		var dc := int(rule.get("dc", 15))
		var t := target.creature.roll_save(e.dice, ab, dc, [], [], "%s save (%s)" % [Creature.ABILITY_SHORT[ab], label])
		failed = not t.success
		r.lines.append(e.log.add("roll", "%s %s the %s save against %s (DC %d)" % [target.name(), "fails" if failed else "makes", Creature.ABILITY_SHORT[ab], label, dc], target.id, [t.describe()]))
	# Giant's Bane, a Nine Lives Stealer: a failed save and the creature dies.
	if bool(rule.get("slay", false)):
		if failed:
			target.creature.hp = 0
			target.creature.dead = true
			r.lines.append(e.log.add("death", "%s is slain outright (%s)" % [target.name(), label], target.id))
			e.events.append({"type": "death", "id": target.id})
			e._check_over()
		return
	if rule.has("damage"):
		var dmg := rule["damage"] as Dictionary
		var rolled := e._roll_damage_dice(str(dmg.get("dice", "1d6")), false, 0, label)
		var amount := int(rolled["total"])
		if not failed:
			amount = amount / 2 if str(rule.get("save_success", "half")) == "half" else 0
		if amount > 0:
			var hurt := e.deal_damage(c, target, [{"amount": amount, "type": str(dmg.get("type", "force"))}], false, label, [str(rolled["text"])])
			# Rod of Lordly Might's Drain Life: the wielder regains half.
			if bool(rule.get("drain_half", false)) and hurt.final > 0:
				var healed := c.creature.heal(hurt.final / 2, label)
				e.log.add("heal", "%s regains %d Hit Points (%s)" % [c.name(), healed, label], c.id)
	# Staff of Withering: Disadvantage on Strength and Constitution checks and saves for 1 hour.
	if failed and target.is_alive() and str(rule.get("debuff", "")) == "withering":
		var wf := Effect.new(label, &"item", str(data.get("id", "")))
		wf.lasting({"kind": "hours", "amount": 1})
		wf.modifiers.append(Modifier.of("disadvantage", {"on": ["check:str", "check:con", "save:str", "save:con"]}, label, &"item"))
		target.creature.add_effect(wf)
		r.lines.append(e.log.add("condition", "%s withers: Disadvantage on Strength and Constitution checks and saves for 1 hour" % target.name(), target.id))
	if failed and target.is_alive():
		for x: Variant in rule.get("conditions", []):
			var cond := StringName(str(x))
			if rule.has("rounds") or rule.has("until"):
				var fx := Effect.new(label, &"item", str(data.get("id", "")))
				fx.caster_id = c.id
				fx.conditions.append(cond)
				if rule.has("rounds"):
					fx.lasting_rounds(int(rule["rounds"]), c.id)
				else:
					fx.ends = Effect.Ends.END_OF_TURN if str(rule["until"]) == "caster_turn_end" else Effect.Ends.START_OF_TURN
					fx.turn_owner_id = c.id
					fx.skip_turn_ends = e.own_turn_skip(c)
				if rule.has("repeat_save"):
					fx.repeat_save = {"ability": str(rule.get("repeat_save")), "dc": int(rule.get("dc", 15)), "when": "end"}
				target.creature.add_effect(fx)
			elif target.creature.add_condition(cond, label):
				pass
			r.lines.append(e.log.add("condition", "%s is %s (%s)" % [target.name(), str(cond).capitalize(), label], target.id))
			e.events.append({"type": "condition", "id": target.id})
		if rule.has("push"):
			e.forced_move(target, e.center_of(c), int(rule["push"]))
	# A Dagger of Venom's coating is used up by the hit.
	if rule.has("ends_toggle"):
		var fx := toggle_effect(c, str(data.get("id", "")), str(rule["ends_toggle"]))
		if fx != null:
			c.creature.remove_effect(fx)


## A hit an item turns into a Critical Hit (Namer's Needle).
func makes_crit(c: Combatant, target: Combatant, option: Dictionary, details: Array[String]) -> bool:
	return specials.fr.makes_crit(c, target, option, details)


## Critical Hits that armor turns into ordinary hits (Adamantine Armor; Armor of Invulnerability doesn't).
func crit_allowed(_c: Combatant, target: Combatant, critical: bool, details: Array[String]) -> bool:
	if not critical:
		return false
	for it in active(target):
		if bool(((it["data"] as Dictionary).get("armor_rules", {}) as Dictionary).get("no_crits", false)):
			details.append("%s turns the Critical Hit into a normal hit" % (it["data"] as Dictionary).get("name", ""))
			return false
	return true


## Before an attack roll: the target's armor and shield against this kind of attack (an Arrow-Catching Shield's +2 against
## ranged attacks) and reactions items offer (catching an arrow meant for an ally).
func before_roll(st: Dictionary) -> Array:
	var out: Array = []
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var option := st["option"] as Dictionary
	var ranged := not bool(option.get("melee", true))
	for it in active(target):
		var ar := ((it["data"] as Dictionary).get("armor_rules", {}) as Dictionary)
		if ranged and ar.has("ac_vs_ranged"):
			st["ac"] = int(st["ac"]) + int(ar["ac_vs_ranged"])
			enc().log.add("info", "%s: +%d AC against the ranged attack" % [(it["data"] as Dictionary).get("name", ""), int(ar["ac_vs_ranged"])], target.id)
	specials.before_roll(st, out)
	return out


## Ways an item cuts an attack's damage (Gloves of Missile Snaring).
func against_damage(st: Dictionary, total: Callable, cut: Callable, out: Array) -> void:
	specials.against_damage(st, total, cut, out)


## A magical effect about to land on `t` (spells and item powers): flags like "no_magic:paralyzed" (Ring of Free
## Action) strip what magic isn't allowed to do to the wearer.
func filter_magic_effect(t: Combatant, fxo: Effect) -> void:
	# Cloak of Arachnida: webs can't hold its wearer.
	if fxo.source_id == "web" and t.creature.has_flag("web_immune"):
		fxo.conditions.erase(&"restrained")
	for cond: StringName in fxo.conditions.duplicate():
		if t.creature.has_flag("no_magic:%s" % cond):
			fxo.conditions.erase(cond)
			enc().log.add("info", "%s can't be made %s by magic" % [t.name(), str(cond).capitalize()], t.id)
	if t.creature.has_flag("no_magic:speed"):
		for m: Modifier in fxo.modifiers.duplicate():
			var v: Variant = m.data.get("value", 0)
			var slows := (m.stat == &"speed" and (v is int or v is float) and int(v) < 0) \
				or m.stat == &"speed_cap" \
				or (m.stat == &"speed_percent" and (v is int or v is float) and int(v) < 100) \
				or (m.stat == &"speed_set" and str(m.data.get("kind", "walk")) == "walk" and (v is int or v is float) and int(v) == 0)
			if slows:
				fxo.modifiers.erase(m)


## Rod of Absorption, Staff of the Magi: a spell aimed at one creature alone (no area) is soaked up with a Reaction.
## True if the spell was absorbed (it does nothing).
func absorbs_spell(ctx: Dictionary, tgt: Array[Combatant], _cells: Array[Vector2i], r: CombatResult) -> bool:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	if tgt.size() != 1 or s.has("area") or bool(ctx.get("item", false)) or int(ctx.get("slot", 0)) <= 0:
		return false
	var t := tgt[0]
	if t == c or not enc().spells.can_react(t) or ch_of(t) == null:
		return false
	return specials.absorb(c, t, ctx, r)


## Ring of Spell Turning: `t` saved against a spell of level 7 or lower, so it has no effect on `t`. If it was aimed at
## `t` alone (no area), a Reaction turns it back: its caster saves against their own spell. True if handled.
func turns_spell(c: Combatant, t: Combatant, ctx: Dictionary, victims: Array[Combatant], r: CombatResult) -> bool:
	if not t.creature.has_flag("spell_turning") or int(ctx.get("slot", 0)) > 7 or bool(ctx.get("turned", false)):
		return false
	var e := enc()
	var s := ctx["s"] as Dictionary
	r.lines.append(e.log.add("info", "%s's Ring of Spell Turning: %s has no effect" % [t.name(), s.get("name", "")], t.id))
	if victims.size() == 1 and not s.has("area") and c != t and e.spells.can_react(t) and c.is_alive() \
			and e._reaction_decision(t, "spell_turning") != "never":
		t.reaction_available = false
		var back := ctx.duplicate()
		back["turned"] = true
		r.lines.append(e.log.add("reaction", "%s turns %s back on %s" % [t.name(), s.get("name", ""), c.name()], t.id))
		var only: Array[Combatant] = [c]
		e.spells._save_spell(back, only, r)
	return true


## Damage about to be dealt (changes `parts` in place): immunities items give against particular spells.
func adjust_incoming(source: Combatant, target: Combatant, parts: Array, label: String) -> void:
	for p: Variant in parts:
		var d := p as Dictionary
		# A Vorpal Sword cuts through Resistance to Slashing damage.
		if str(d.get("item", "")) != "":
			var w := comp().item_data(str(d["item"]))
			if str(d.get("type", "")) in (_rules(w).get("ignore_resistance", []) as Array):
				d["ignore_resistance"] = true
				d["ignore_source"] = str(w.get("name", ""))
		# Shield of Missile Attraction: Resistance to damage from Ranged weapons.
		if bool(d.get("ranged_weapon", false)):
			for it in active(target):
				if bool(((it["data"] as Dictionary).get("armor_rules", {}) as Dictionary).get("resist_ranged_weapons", false)):
					d["resisted_by"] = str((it["data"] as Dictionary).get("name", ""))
	specials.adjust_incoming(source, target, parts, label)


## After damage landed on `target`.
func on_damaged(source: Combatant, target: Combatant, amount: int, parts: Array) -> void:
	if target == null or target.creature == null:
		return
	specials.on_damaged(source, target, amount, parts)


## Before a D20 Test: Advantage items give (Wand of Binding's Assisted Escape spends a charge for it).
func before_d20(c: Combatant, kind: D20Test.Kind, keys: Array[String]) -> Array[String]:
	return specials.before_d20(c, kind, keys)


## After a D20 Test: items that turn a failure (Ring of Evasion, a Luck Blade's reroll).
func after_d20(c: Combatant, t: D20Test, keys: Array[String]) -> void:
	specials.after_d20(c, t, keys)


# --- Turns and the start of a fight --------------------------------------------------------------

## Lantern of Revealing (Invisible creatures in its Bright Light can be seen), Robe of Eyes (its wearer sees them).
func reveals_invisible(a: Combatant, b: Combatant) -> bool:
	var e := enc()
	if a.creature.has_flag("sees_invisible") and e.distance(a, b) <= 120:
		return true
	for o in e.living():
		if o.creature.has_flag("lantern_of_revealing") and e.distance(o, b) <= 30:
			return true
	return false


## "" if `c` may attack `target` with `option`; otherwise what stops it (a Cube of Force's barrier, a Scroll of
## Protection's ward against the attacker's kind).
func attack_blocked(c: Combatant, target: Combatant, option: Dictionary) -> String:
	if target.creature.has_flag("cube_everything"):
		return "A Cube of Force barrier is in the way"
	if bool(option.get("melee", true)) and target.creature.has_flag("cube_living"):
		return "A Cube of Force barrier keeps living things out"
	if not bool(option.get("melee", true)) and target.creature.has_flag("cube_objects"):
		return "A Cube of Force barrier stops missiles"
	if target.creature.has_flag("protection_from:%s" % c.creature.creature_type):
		return "%s's Scroll of Protection keeps %ss away" % [target.name(), c.creature.creature_type]
	return ""


## "" if a spell from `c` can reach `t`; otherwise what stops it.
func spell_blocked(c: Combatant, t: Combatant) -> String:
	if c == t:
		return ""
	if t.creature.has_flag("cube_spells") or t.creature.has_flag("cube_everything"):
		return "A Cube of Force barrier keeps spells out"
	if t.creature.has_flag("protection_from:%s" % c.creature.creature_type):
		return "A Scroll of Protection keeps the caster's kind away"
	return ""


## Dwarven Plate: when something moves its wearer against its will along the ground, a Reaction shortens it by 10 ft.
func forced_move_feet(target: Combatant, feet: int) -> int:
	for it in active(target):
		var cut := int(((it["data"] as Dictionary).get("armor_rules", {}) as Dictionary).get("forced_move_reduction", 0))
		if cut > 0 and enc().spells.can_react(target) and enc()._reaction_decision(target, "dwarven_plate") != "never" and feet > 0:
			target.reaction_available = false
			enc().log.add("reaction", "%s plants their feet in Dwarven Plate (%d ft less)" % [target.name(), mini(cut, feet)], target.id)
			return maxi(0, feet - cut)
	return feet


## Extra Initiative from items (Sword of Kas: + 1d10 while drawn).
func initiative_bonus(c: Combatant) -> int:
	if c.creature.has_flag("kas_initiative") and has_active(c, "sword_of_kas"):
		return enc().dice.roll_one(10, "Sword of Kas")
	return 0


## Extra healing on a healing spell `c` casts (Moon Sickle: 1d4 while held).
func healing_bonus(c: Combatant, _ctx: Dictionary) -> int:
	for it in active(c):
		if "moon_sickle" in (((it["data"] as Dictionary).get("weapon_rules", {}) as Dictionary).get("special", []) as Array):
			return enc().dice.roll_one(4, "Moon Sickle")
	return 0


## Advantage on Initiative from items (a Weapon of Warning covers its wielder's allies within 30 ft).
func initiative_advantage(c: Combatant) -> Array[String]:
	return specials.initiative_advantage(c)


## Creatures items keep from being surprised.
func surprise_filter(ids: Array) -> Array:
	return specials.surprise_filter(ids)


func turn_start(c: Combatant) -> void:
	_count_budgets(c)
	specials.turn_start(c)


## Toggles with a limited running time (Boots of Speed's 10 minutes, Winged Boots' 4 hours): a round used each turn.
func _count_budgets(c: Combatant) -> void:
	for p in powers(c):
		var power := p["power"] as Dictionary
		var budget := int(power.get("budget_rounds", 0))
		if budget <= 0 or not toggled(c, str(p["item_id"]), str(power["id"])):
			continue
		var entry := p["entry"] as Dictionary
		if not entry.has("budget_used"):
			entry["budget_used"] = {}
		var used := entry["budget_used"] as Dictionary
		var pid := str(power["id"])
		used[pid] = int(used.get(pid, 0)) + 1
		if int(used[pid]) >= budget:
			c.creature.remove_effect(toggle_effect(c, str(p["item_id"]), pid))
			enc().log.add("info", "%s's %s is spent for now" % [c.name(), (p["data"] as Dictionary).get("name", "")], c.id)


func turn_end(c: Combatant) -> void:
	specials.turn_end(c)
