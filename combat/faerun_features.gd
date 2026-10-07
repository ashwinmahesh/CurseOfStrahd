class_name FaerunFeatures
extends RefCounted
## Options from Heroes of Faerûn and Arcana Unleashed in a fight that need their own code (the rest are data recipes:
## FeatureRecipes, TriggeredFeatures). The origin feats: Arcane Artist, Arcane Overload, Arcane Undertaker, Portal
## Jumper, Cult of the Dragon Initiate, Emerald Enclave Fledgling, Harper Agent, Lords' Alliance Agent, Purple Dragon
## Rook, Spellfire Spark, Tyro of the Gauntlet and Zhentarim Ruffian.
## FeatureActions lists the actions here ("feat:fr:<id>"); the encounter, the attack pipeline, the spell caster and
## the damage path call the hooks below, each next to the matching RavenloftFeatures hook.
## A benefit with `"policy": "auto"` in its data acts on its own unless its owner turns it Off in the class tab
## (Reactions.configurable_policies).

var _enc: WeakRef

## Combatants whose side rolls Initiative with Advantage this fight (Family First), by side.
var _family_first: Dictionary = {}

## Every non-class-specific PHB language, Draconic first (Dragon's Tongue).
const DRAGON_TONGUE := ["draconic", "common_sign_language", "dwarvish", "elvish", "giant", "gnomish", "goblin",
	"halfling", "orc", "abyssal", "celestial", "deep_speech", "infernal", "primordial", "sylvan", "undercommon"]


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func feat(c: Combatant, feat_id: String) -> bool:
	return c != null and enc().features.has_feat(c, feat_id)


static func _ch(c: Combatant) -> Character:
	return c.creature as Character if c != null and c.creature is Character else null


func _entry(id: String, label: String, sub: String, cost: String, why: String, targeting: String, help: String, rng: int = 0) -> Dictionary:
	return {"id": "feat:fr:" + id, "label": label, "sub": sub, "cost": cost, "why": why, "targeting": targeting, "help": help, "range": rng}


static func _first(a: String, b: String) -> String:
	return a if a != "" else b


func _res_why(c: Combatant, res: String) -> String:
	var ch := _ch(c)
	return "" if ch != null and ch.resource_left(res) > 0 else "None left"


## A benefit marked `"policy"`: on unless its owner turned it Off.
static func allowed(c: Combatant, id: String) -> bool:
	return str(c.reaction_rules.get(id, "auto")) != "never"


func _turn_key() -> String:
	return "%d:%d" % [enc().round_no, enc().turn_index]


## Once per turn (anyone's turn): true the first time, false after.
func _once_per_turn(c: Combatant, key: String) -> bool:
	if str(c.get_meta(key, "")) == _turn_key():
		return false
	c.set_meta(key, _turn_key())
	return true


func _log(kind: String, text: String, who: Combatant, details: Array = []) -> void:
	enc().log.add(kind, text, who.id if who != null else "", details)


## Heroic Inspiration for `t` from `giver`'s feature; false when it already has some (nothing to give).
func _inspire(giver: Combatant, t: Combatant, label: String) -> bool:
	var ch := _ch(t)
	if ch == null or ch.heroic_inspiration:
		return false
	ch.heroic_inspiration = true
	_log("info", "%s gains Heroic Inspiration (%s, from %s)" % [t.name(), label, giver.name()], t)
	return true


## Allies of `c` (not `c`) within `feet` that perceive it and lack Heroic Inspiration, nearest first.
func _uninspired_allies(c: Combatant, feet: int, perceive: Callable) -> Array[Combatant]:
	var e := enc()
	var out: Array[Combatant] = []
	for a in e.allies_of(c):
		var ch := _ch(a)
		if a == c or ch == null or ch.heroic_inspiration or not a.is_alive() or a.creature.hp <= 0 or e.distance(c, a) > feet:
			continue
		if perceive.call(a):
			out.append(a)
	out.sort_custom(func(x: Combatant, y: Combatant) -> bool: return e.distance(c, x) < e.distance(c, y))
	return out


# --- Hotbar actions -----------------------------------------------------------------------------------------

func list(c: Combatant, out: Array[Dictionary], aw: String, _bw: String) -> void:
	var ch := _ch(c)
	if ch == null:
		return
	var e := enc()
	var tw := e._turn_check(c)
	if feat(c, "arcane_artist") and str(c.get_meta("arcane_artist_window", "")) == _turn_key():
		out.append(_entry("arcane_artist", "Arcane Artist: inspire", "Heroic Inspiration · 30 ft", "free",
			_first(tw, _res_why(c, "arcane_artist")), "ally",
			"You just cast an Illusion spell: give Heroic Inspiration to an ally within 30 ft who can see you. Once per Long Rest.", 30))
	if feat(c, "arcane_overload") and ch.resource_left("arcane_overload") > 0:
		var armed := str(c.get_meta("arcane_overload_armed", "")) == _turn_key()
		out.append(_entry("arcane_overload", "Arcane Overload" + (" (armed)" if armed else ""), "+%d to an Evocation spell" % ch.proficiency_bonus(),
			"free", _first(tw, "Already armed" if armed else ""), "none",
			"Arm it: the next Evocation spell you cast this turn adds your Proficiency Bonus to one of its damage rolls, spending the use. Once per Long Rest."))
	if feat(c, "portal_jumper"):
		var pw := _first(tw, _res_why(c, "portal_step"))
		if pw == "" and str(c.get_meta("portal_step_turn", "")) == _turn_key():
			pw = "Once per turn"
		if pw == "" and c.movement_left < 15:
			pw = "Needs 15 ft of movement"
		out.append(_entry("portal_step", "Portal Step", "teleport 15 ft", "free", pw, "point",
			"Spend 15 ft of movement to teleport to an empty space you can see within 15 ft. Once per turn; Proficiency Bonus times per Long Rest.", 15))
	if feat(c, "cult_of_the_dragon_initiate"):
		out.append(_entry("dragons_terror", "Dragon's Terror", "Wis DC %d · 30 ft" % _terror_dc(c), "action",
			_first(aw, "Only one Magic action this turn" if c.magic_action_used else ""), "enemy",
			"Magic action: a creature you can see within 30 ft makes a Wisdom save or is Frightened of you until the end of your next turn. Once it succeeds or the fear ends, it's immune for the rest of the fight.", 30))
	if feat(c, "emerald_enclave_fledgling") and str(c.get_meta("tag_team_window", "")) == _turn_key():
		out.append(_entry("tag_team", "Tag Team", "swap with an ally", "free", tw, "ally",
			"As part of your Help: trade places with a willing ally within 5 ft who isn't Incapacitated. Neither of you provokes Opportunity Attacks.", 5))


func perform(c: Combatant, id: String, t: Combatant, cell: Vector2i, _point: Vector2) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	match id:
		"arcane_artist":
			if str(c.get_meta("arcane_artist_window", "")) != _turn_key() or ch.resource_left("arcane_artist") <= 0:
				return CombatResult.fail("Cast an Illusion spell first")
			if t == null or t == c or not c.allied_with(t) or e.distance(c, t) > 30 or not e.can_see(t, c):
				return CombatResult.fail("Choose an ally within 30 ft who can see you")
			if _ch(t) == null or _ch(t).heroic_inspiration:
				return CombatResult.fail("%s already has Heroic Inspiration" % t.name())
			ch.spend_resource("arcane_artist")
			c.remove_meta("arcane_artist_window")
			_inspire(c, t, "Arcane Artist")
		"arcane_overload":
			if ch.resource_left("arcane_overload") <= 0:
				return CombatResult.fail("None left")
			c.set_meta("arcane_overload_armed", _turn_key())
			_log("info", "%s gathers power for an Evocation spell (Arcane Overload)" % c.name(), c)
		"portal_step":
			if ch.resource_left("portal_step") <= 0 or c.movement_left < 15 or str(c.get_meta("portal_step_turn", "")) == _turn_key():
				return CombatResult.fail("Not now")
			if cell.x < 0 or not e.grid.in_bounds(cell) or not e.can_see_space(c, cell):
				return CombatResult.fail("Choose an empty space you can see within 15 ft")
			var r := e.feature_actions._teleport(c, cell, 15)
			if not r.ok:
				return r
			ch.spend_resource("portal_step")
			c.movement_left -= 15
			c.set_meta("portal_step_turn", _turn_key())
			return r
		"dragons_terror":
			return _dragons_terror(c, t)
		"tag_team":
			return _tag_team(c, t)
		_:
			return CombatResult.fail("Not available")
	return CombatResult.new()


# --- Cult of the Dragon Initiate --------------------------------------------------------------------------

func _terror_dc(c: Combatant) -> int:
	return 8 + c.creature.ability_mod(&"wis") + c.creature.proficiency_bonus()


func _dragons_terror(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	if t == null or t == c or e.distance(c, t) > 30 or not e.can_see(c, t):
		return CombatResult.fail("Choose a creature you can see within 30 ft")
	if c.magic_action_used:
		return CombatResult.fail("Only one Magic action this turn")
	if c.id in (t.get_meta("dragons_terror_immune", []) as Array):
		return CombatResult.fail("%s has already shaken off your Dragon's Terror" % t.name())
	var why := e._action_check(c)
	if why != "":
		return CombatResult.fail(why)
	e.spend_action(c)
	c.magic_action_used = true
	var sv := t.creature.roll_save(e.dice, &"wis", _terror_dc(c), [], [], "Wisdom save vs Dragon's Terror (%s)" % t.name(),
		["save_vs:frightened", "save_vs:magic"])
	if sv.success:
		_log("info", "%s stands firm against %s's Dragon's Terror" % [t.name(), c.name()], t, [sv.describe()])
		_terror_immune(c, t)
		return CombatResult.new()
	var fx := Effect.new("Dragon's Terror", &"feature", "dragons_terror").with_condition(&"frightened")
	fx.caster_id = c.id
	fx.ends = Effect.Ends.END_OF_TURN
	fx.turn_owner_id = c.id
	fx.skip_turn_ends = e.own_turn_skip(c)
	fx.on_end = func() -> void: _terror_immune(c, t)
	if t.creature.add_effect(fx):
		_log("condition", "%s is Frightened of %s (Dragon's Terror)" % [t.name(), c.name()], t, [sv.describe()])
		e.events.append({"type": "condition", "id": t.id})
	else:
		_terror_immune(c, t)
	return CombatResult.new()


func _terror_immune(c: Combatant, t: Combatant) -> void:
	var immune := (t.get_meta("dragons_terror_immune", []) as Array).duplicate()
	if not c.id in immune:
		immune.append(c.id)
	t.set_meta("dragons_terror_immune", immune)


## Inspired by Fear: a creature just became Frightened of a holder (any feature or spell, the holder as its source).
func effect_added(cr: Creature, fx: Effect) -> void:
	if not &"frightened" in fx.conditions or fx.caster_id == "" or fx.caster_id == cr.id:
		return
	var c := enc().get_c(fx.caster_id)
	var ch := _ch(c)
	if ch == null or not feat(c, "cult_of_the_dragon_initiate") or ch.heroic_inspiration or ch.resource_left("inspired_by_fear") <= 0:
		return
	ch.spend_resource("inspired_by_fear")
	_inspire(c, c, "Inspired by Fear")


# --- Emerald Enclave Fledgling, Harper Agent, Arcane Undertaker ---------------------------------------------

## How far Help can reach its enemy: 30 ft for a Harper Agent the enemy can see or hear (Distracting Melody).
func help_reach(c: Combatant, enemy: Combatant) -> int:
	if feat(c, "harper_agent") and enemy != null and enc().spells.can_see_or_hear(enemy, c):
		return 30
	return 5


func after_help(c: Combatant) -> void:
	if feat(c, "emerald_enclave_fledgling"):
		c.set_meta("tag_team_window", _turn_key())


func _tag_team(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	if str(c.get_meta("tag_team_window", "")) != _turn_key():
		return CombatResult.fail("Take the Help action first")
	if t == null or t == c or not c.allied_with(t) or e.distance(c, t) > 5 or not t.can_act():
		return CombatResult.fail("Choose a willing ally within 5 ft who isn't Incapacitated")
	if not e.space_available(t.cell, c.size_cells, [c, t]) or not e.space_available(c.cell, t.size_cells, [c, t]):
		return CombatResult.fail("You can't fit in each other's spaces")
	c.remove_meta("tag_team_window")
	var a := c.cell
	var b := t.cell
	c.cell = b
	t.cell = a
	c.clear_run()
	t.clear_run()
	e.events.append({"type": "move", "id": c.id, "from": a, "to": b, "forced": false})
	e.events.append({"type": "move", "id": t.id, "from": b, "to": a, "forced": false})
	e.spells.zones.on_moved(c, a)
	e.spells.zones.on_moved(t, b)
	_log("move", "%s and %s trade places (Tag Team)" % [c.name(), t.name()], c)
	return CombatResult.new()


## Understanding of Death: Heroic Inspiration after Help stabilizes a dying creature.
func after_stabilize(c: Combatant) -> void:
	var ch := _ch(c)
	if ch == null or not feat(c, "arcane_undertaker") or ch.heroic_inspiration or ch.resource_left("understanding_of_death") <= 0:
		return
	ch.spend_resource("understanding_of_death")
	_inspire(c, c, "Understanding of Death")


# --- Spells: Arcane Artist, Arcane Overload ----------------------------------------------------------------

func after_cast(c: Combatant, s: Dictionary, _slot: int) -> void:
	if feat(c, "arcane_artist") and str(s.get("school", "")) == "illusion" and _ch(c).resource_left("arcane_artist") > 0:
		c.set_meta("arcane_artist_window", _turn_key())


## Arcane Overload: once armed this turn, an Evocation spell's damage roll gains the Proficiency Bonus.
func spell_damage_bonus(ctx: Dictionary, bonus: Breakdown) -> int:
	var c := ctx["c"] as Combatant
	var ch := _ch(c)
	if ch == null or str(c.get_meta("arcane_overload_armed", "")) != _turn_key():
		return 0
	if str((ctx["s"] as Dictionary).get("school", "")) != "evocation" or ch.resource_left("arcane_overload") <= 0:
		return 0
	ch.spend_resource("arcane_overload")
	c.remove_meta("arcane_overload_armed")
	var pb := ch.proficiency_bonus()
	bonus.add("Arcane Overload", pb)
	return pb


# --- Attacks and damage: Lords' Alliance Agent, Spellfire Spark, Zhentarim Ruffian -------------------------

## Inspiring Strike: once per turn, a Critical Hit on a creature inspires an ally within 30 ft who sees or hears you.
func after_hit(c: Combatant, target: Combatant, critical: bool) -> void:
	if not critical or target == null or not feat(c, "lords_alliance_agent"):
		return
	var e := enc()
	var who := _uninspired_allies(c, 30, func(a: Combatant) -> bool: return e.spells.can_see_or_hear(a, c))
	if who.is_empty() or not _once_per_turn(c, "inspiring_strike_turn"):
		return
	_inspire(c, who[0], "Inspiring Strike")


## Reassert Honor: an enemy the holder can see hurts an ally beside it; the holder's next attack on that enemy has
## Advantage until the end of its next turn.
func after_damage(source: Combatant, target: Combatant, amount: int) -> void:
	var e := enc()
	if source == null or amount <= 0 or source == target:
		return
	for h in e.combatants:
		if h == target or not h.is_alive() or not feat(h, "lords_alliance_agent") or not h.allied_with(target):
			continue
		if not h.hostile_to(source) or e.distance(h, target) > 5 or not e.can_see(h, source):
			continue
		e.add_mark({"kind": "advantage_against", "target": source.id, "attacker": h.id, "source": "Reassert Honor",
			"expires_owner": h.id, "expires_phase": "end", "skip": e.own_turn_skip(h), "consume": true})
		_log("info", "%s will make %s answer for that (Reassert Honor: Advantage on the next attack)" % [h.name(), source.name()], h)


## Magic Absorption (Spellfire Spark): once per turn, 1d4 off damage from a spell or a magical monster action while
## not Incapacitated.
func adjust_incoming(_source: Combatant, target: Combatant, parts: Array) -> void:
	if not feat(target, "spellfire_spark") or not target.can_act():
		return
	var spell_part: Dictionary = {}
	for p: Variant in parts:
		var part := p as Dictionary
		if (bool(part.get("spell", false)) or bool(part.get("magic", false))) and int(part["amount"]) > 0:
			spell_part = p as Dictionary
			break
	if spell_part.is_empty() or not _once_per_turn(target, "magic_absorption_turn"):
		return
	var cut := enc().dice.roll_one(4, "Magic Absorption")
	spell_part["amount"] = maxi(0, int(spell_part["amount"]) - cut)
	_log("info", "%s soaks up %d of the spell's damage (Magic Absorption)" % [target.name(), cut], target)


## Exploit Opening: an Opportunity Attack's damage dice are rolled twice, keeping the better roll.
func exploit_opening(c: Combatant, opts: Dictionary) -> bool:
	return bool(opts.get("opportunity", false)) and feat(c, "zhentarim_ruffian")


# --- Initiative: Family First, Rallying Cry ------------------------------------------------------------------

## Before anyone rolls: a Zhentarim Ruffian may spend Heroic Inspiration for its side's Advantage on Initiative.
func before_initiative() -> void:
	_family_first.clear()
	for c in enc().combatants:
		var ch := _ch(c)
		if ch == null or not ch.heroic_inspiration or not feat(c, "zhentarim_ruffian") or not allowed(c, "family_first"):
			continue
		if _family_first.has(str(c.side)):
			continue
		ch.heroic_inspiration = false
		_family_first[str(c.side)] = c.name()
		_log("info", "%s spends Heroic Inspiration: the whole side rolls Initiative with Advantage (Family First)" % c.name(), c)


func initiative_advantage(c: Combatant) -> Array[String]:
	var out: Array[String] = []
	for side: String in _family_first:
		var holder := str(_family_first[side])
		if side == str(c.side) or (side == "party" and c.side == &"guest") or (side == "guest" and c.side == &"party"):
			out.append("Family First (%s)" % holder)
	return out


## Rallying Cry (Purple Dragon Rook): on rolling Initiative, Heroic Inspiration for up to Proficiency Bonus allies
## within 30 ft that the Rook can see. Once per Long Rest.
func initiative_rolled() -> void:
	var e := enc()
	for c in e.combatants:
		var ch := _ch(c)
		if ch == null or not feat(c, "purple_dragon_rook") or not c.can_act() or ch.resource_left("rook_rallying_cry") <= 0:
			continue
		if not allowed(c, "rook_rallying_cry"):
			continue
		var who := _uninspired_allies(c, 30, func(a: Combatant) -> bool: return e.can_see(c, a))
		if who.is_empty():
			continue
		ch.spend_resource("rook_rallying_cry")
		_log("info", "%s raises a rallying cry" % c.name(), c)
		for a: Combatant in who.slice(0, ch.proficiency_bonus()):
			_inspire(c, a, "Rallying Cry")


# --- Tyro of the Gauntlet -----------------------------------------------------------------------------------

## Stand as One: a holder within 5 ft of `target` (not itself) spends its Reaction so the push or pull fails.
func blocks_forced_move(target: Combatant) -> bool:
	var e := enc()
	if not target.can_act():
		return false
	for h in e.combatants:
		if h == target or not feat(h, "tyro_of_the_gauntlet") or not h.allied_with(target) or e.distance(h, target) > 5:
			continue
		if not e.spells.can_react(h) or not allowed(h, "stand_as_one"):
			continue
		h.reaction_available = false
		_log("reaction", "%s braces %s: no push or pull (Stand as One)" % [h.name(), target.name()], h)
		return true
	return false


## Gauntlet Vigilant: after taking the Ready action, the next attack against the holder before its next turn
## starts has Disadvantage.
func after_ready(c: Combatant) -> void:
	if not feat(c, "tyro_of_the_gauntlet"):
		return
	var fx := Effect.new("Gauntlet Vigilant", &"feature", "gauntlet_vigilant").with_modifier("attacked_with", {"value": "disadvantage"})
	fx.caster_id = c.id
	fx.ends = Effect.Ends.START_OF_TURN
	fx.turn_owner_id = c.id
	fx.consume_when_attacked = true
	c.creature.add_effect(fx)
	_log("info", "%s stays on guard (Gauntlet Vigilant)" % c.name(), c)
