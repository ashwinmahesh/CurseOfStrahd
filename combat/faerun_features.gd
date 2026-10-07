class_name FaerunFeatures
extends RefCounted
## Options from Heroes of Faerûn and Arcana Unleashed in a fight that need their own code (the rest are data recipes:
## FeatureRecipes, TriggeredFeatures). The origin feats: Arcane Artist, Arcane Overload, Arcane Undertaker, Portal
## Jumper, Cult of the Dragon Initiate, Emerald Enclave Fledgling, Harper Agent, Lords' Alliance Agent, Purple Dragon
## Rook, Spellfire Spark, Tyro of the Gauntlet and Zhentarim Ruffian; the general feats Abjuration, Divination,
## Evocation and Necromancy Adept, Cold Caster, Dragonscarred, Fairy Trickster, Harper Teamwork, Lordly Resolve,
## Order's Resilience, Purple Dragon Commandant, Spell Subterfuge, Spellfire Adept, Street Justice and Zhentarim Tactics.
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
	if feat(c, "dragonscarred") and str(c.get_meta("dragonscarred_turn", "")) == _turn_key():
		out.append(_entry("dragons_terror_bonus", "Dragon's Terror (Bonus Action)", "Wis DC %d · 30 ft" % _terror_dc(c), "bonus",
			_first(e._bonus_check(c), ""), "enemy",
			"Dragonscarred: you dealt damage this turn, so Dragon's Terror takes a Bonus Action.", 30))
	if feat(c, "spell_subterfuge") and str(c.get_meta("shrouding_window", "")) == _turn_key():
		out.append(_entry("shrouding_spells", "Shrouding Spells", "Dash and Hide", "bonus",
			_first(e._bonus_check(c), _res_why(c, "shrouding_spells")), "none",
			"Bonus Action after your spell: Dash and Hide together.", 0))
	if feat(c, "fairy_trickster") and ch.resource_left("flustering_strike") > 0:
		var fs_armed := str(c.get_meta("flustering_armed", "")) == _turn_key()
		out.append(_entry("flustering_strike", "Flustering Strike" + (" (armed)" if fs_armed else ""), "Wis DC %d" % _feat_dc(c, "fairy_trickster"),
			"free", _first(tw, "Already armed" if fs_armed else ""), "none",
			"Arm it: your next hit this turn forces a Wisdom save or the target has Disadvantage on saving throws until the end of your next turn."))
	if feat(c, "purple_dragon_commandant"):
		out.append(_entry("commandant_rally", "Rallying Command", "2d6 + %d Temporary HP" % _increased_mod(c, "purple_dragon_commandant"), "bonus",
			_first(e._bonus_check(c), _res_why(c, "commandant_rally")), "ally",
			"Bonus Action: an ally you can see within 30 ft gains 2d6 + %d Temporary Hit Points." % _increased_mod(c, "purple_dragon_commandant"), 30))
	if feat(c, "lordly_resolve"):
		var lr := _entry("lordly_resolve", "Lordly Resolve", "up to 3 allies · 1 min", "bonus",
			_first(e._bonus_check(c), _res_why(c, "lordly_resolve")), "multi",
			"Bonus Action: up to three creatures within 60 ft who can see you stand up (spending a Reaction) and can't be Charmed, Frightened or possessed for 1 minute.", 60)
		lr["count"] = 3
		out.append(lr)
	if feat(c, "emerald_enclave_fledgling") and str(c.get_meta("tag_team_window", "")) == _turn_key():
		out.append(_entry("tag_team", "Tag Team", "swap with an ally", "free", tw, "ally",
			"As part of your Help: trade places with a willing ally within 5 ft who isn't Incapacitated. Neither of you provokes Opportunity Attacks.", 5))


## A multi-target action hands its picks in `targets`; the hotbar's single pick comes as `t`.
var targets_in: Array = []


func _targets_of(t: Combatant) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for x: Variant in targets_in:
		if x is Combatant and not out.has(x as Combatant):
			out.append(x as Combatant)
	if out.is_empty() and t != null:
		out.append(t)
	return out


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
		"dragons_terror_bonus":
			if str(c.get_meta("dragonscarred_turn", "")) != _turn_key():
				return CombatResult.fail("Deal damage this turn first")
			return _dragons_terror(c, t, true)
		"shrouding_spells":
			return _shrouding_spells(c)
		"flustering_strike":
			if ch.resource_left("flustering_strike") <= 0:
				return CombatResult.fail("None left")
			c.set_meta("flustering_armed", _turn_key())
			_log("info", "%s readies a Flustering Strike" % c.name(), c)
		"commandant_rally":
			return _commandant_rally(c, t)
		"lordly_resolve":
			return _lordly_resolve(c, _targets_of(t))
		"tag_team":
			return _tag_team(c, t)
		_:
			return CombatResult.fail("Not available")
	return CombatResult.new()


# --- Cult of the Dragon Initiate --------------------------------------------------------------------------

func _terror_dc(c: Combatant) -> int:
	return 8 + c.creature.ability_mod(&"wis") + c.creature.proficiency_bonus()


func _dragons_terror(c: Combatant, t: Combatant, bonus: bool = false) -> CombatResult:
	var e := enc()
	if t == null or t == c or e.distance(c, t) > 30 or not e.can_see(c, t):
		return CombatResult.fail("Choose a creature you can see within 30 ft")
	if c.magic_action_used and not bonus:
		return CombatResult.fail("Only one Magic action this turn")
	if c.id in (t.get_meta("dragons_terror_immune", []) as Array):
		return CombatResult.fail("%s has already shaken off your Dragon's Terror" % t.name())
	var why := e._bonus_check(c) if bonus else e._action_check(c)
	if why != "":
		return CombatResult.fail(why)
	if bonus:
		c.bonus_available = false
		c.remove_meta("dragonscarred_turn")
	else:
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
	# Bound by id, not by a closure over the combatants, so a fear still running at the end of a fight frees cleanly.
	fx.on_end = _terror_ended.bind(c.id, t.id)
	if t.creature.add_effect(fx):
		_log("condition", "%s is Frightened of %s (Dragon's Terror)" % [t.name(), c.name()], t, [sv.describe()])
		e.events.append({"type": "condition", "id": t.id})
	else:
		_terror_immune(c, t)
	return CombatResult.new()


func _terror_ended(caster_id: String, target_id: String) -> void:
	var e := enc()
	if e == null:
		return
	var c := e.get_c(caster_id)
	var t := e.get_c(target_id)
	if c != null and t != null:
		_terror_immune(c, t)


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


func after_help(c: Combatant, enemy: Combatant) -> void:
	if feat(c, "emerald_enclave_fledgling"):
		c.set_meta("tag_team_window", _turn_key())
	# Harper Teamwork: the distracted enemy also has Disadvantage on its next save before the helper's next turn.
	if feat(c, "harper_teamwork") and enemy != null:
		var fx := Effect.new("Harper Teamwork", &"feature", "harper_teamwork").with_modifier("disadvantage", {"on": "save:all"})
		fx.caster_id = c.id
		fx.ends = Effect.Ends.START_OF_TURN
		fx.turn_owner_id = c.id
		fx.consume_on = ["save:all"]
		enemy.creature.add_effect(fx)


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

func after_cast(c: Combatant, s: Dictionary, slot: int, free: bool = false) -> void:
	var ch := _ch(c)
	if ch == null:
		return
	var school := str(s.get("school", ""))
	if feat(c, "arcane_artist") and school == "illusion" and ch.resource_left("arcane_artist") > 0:
		c.set_meta("arcane_artist_window", _turn_key())
	# The rest need a spell slot spent on a levelled spell.
	if free or slot <= 0 or int(s.get("level", 0)) <= 0:
		return
	if school == "abjuration" and feat(c, "abjuration_adept"):
		_abjuration_ward(c, slot)
	if school == "divination" and feat(c, "divination_adept") and ch.resource_left("divination_adept") < ch.resource_max("divination_adept"):
		ch.restore_resource("divination_adept", 1)
		_log("info", "%s's Divination Adept is ready again" % c.name(), c)
	if school == "necromancy" and feat(c, "necromancy_adept") and allowed(c, "necromancy_adept_benefit") and c.creature.hp < c.creature.max_hp():
		var rolled := _spend_hit_dice(ch, 2, "Necromancy Adept")
		if rolled > 0:
			var got := c.creature.heal(rolled + slot, "Necromancy Adept")
			_log("heal", "%s draws on its own life force: +%d Hit Points (Necromancy Adept)" % [c.name(), got], c)
			enc().events.append({"type": "heal", "id": c.id, "amount": got})
	if feat(c, "spell_subterfuge") and str((s.get("casting_time", {}) as Dictionary).get("unit", "")) == "action" and ch.resource_left("shrouding_spells") > 0:
		c.set_meta("shrouding_window", _turn_key())


## Abjuration Adept: twice the slot level in Temporary Hit Points for the most hurt of the caster and its allies
## within 30 ft that it can see.
func _abjuration_ward(c: Combatant, slot: int) -> void:
	var e := enc()
	var best := c
	for a in e.allies_of(c):
		if not a.is_alive() or a.creature.hp <= 0 or e.distance(c, a) > 30 or not e.can_see(c, a):
			continue
		if float(a.creature.hp) / maxf(1.0, a.creature.max_hp()) < float(best.creature.hp) / maxf(1.0, best.creature.max_hp()):
			best = a
	if best.creature.add_temp_hp(2 * slot, "Abjuration Adept"):
		_log("heal", "%s gains %d Temporary Hit Points (Abjuration Adept)" % [best.name(), 2 * slot], best)


## Rolls up to `n` unused Hit Dice (largest first), spending them; their total, without the Constitution modifier.
func _spend_hit_dice(ch: Character, n: int, label: String) -> int:
	var total := 0
	for i in n:
		var pool := ch.hit_dice()
		var best := 0
		for die: String in pool:
			var entry := pool[die] as Dictionary
			if int(entry["spent"]) < int(entry["total"]) and int(die) > best:
				best = int(die)
		if best == 0:
			break
		ch.hit_dice_spent[str(best)] = int(ch.hit_dice_spent.get(str(best), 0)) + 1
		total += enc().dice.roll_one(best, label)
	return total


func _feat_dc(c: Combatant, feat_id: String) -> int:
	return 8 + _increased_mod(c, feat_id) + c.creature.proficiency_bonus()


## The modifier of the ability a general feat increased (the feat's own pick).
func _increased_mod(c: Combatant, feat_id: String) -> int:
	var ch := _ch(c)
	if ch == null:
		return 0
	for f in ch.feats_taken:
		if str(f["id"]) == feat_id:
			var picks := ch.picks_for("%s.abilities" % str(f["key"]))
			if not picks.is_empty():
				return c.creature.ability_mod(StringName(picks[0]))
	return 0


## Arcane Overload: once armed this turn, an Evocation spell's damage roll gains the Proficiency Bonus. Evocation
## Adept (an Evocation spell) and Spellfire Adept (a spell dealing Radiant): once per turn, up to two Hit Dice.
func spell_damage_bonus(ctx: Dictionary, bonus: Breakdown) -> int:
	var c := ctx["c"] as Combatant
	var ch := _ch(c)
	if ch == null:
		return 0
	var s := ctx["s"] as Dictionary
	var total := 0
	for pair: Array in [["evocation_adept", "evocation_adept_benefit", "Evocation Adept"], ["spellfire_adept", "spellfire_adept_benefit", "Spellfire Adept"]]:
		if not feat(c, str(pair[0])) or not allowed(c, str(pair[1])):
			continue
		var fits := str(s.get("school", "")) == "evocation" if str(pair[0]) == "evocation_adept" \
			else (s.get("damage", []) as Array).any(func(d: Variant) -> bool: return str((d as Dictionary).get("type", "")) == "radiant")
		if not fits or not _once_per_turn(c, str(pair[0]) + "_turn"):
			continue
		var hd := _spend_hit_dice(ch, 2, str(pair[2]))
		if hd > 0:
			bonus.add("%s (Hit Dice)" % pair[2], hd)
			total += hd
	return total + _overload(c, ch, s, bonus)


func _overload(c: Combatant, ch: Character, s: Dictionary, bonus: Breakdown) -> int:
	if str(c.get_meta("arcane_overload_armed", "")) != _turn_key():
		return 0
	if str(s.get("school", "")) != "evocation" or ch.resource_left("arcane_overload") <= 0:
		return 0
	ch.spend_resource("arcane_overload")
	c.remove_meta("arcane_overload_armed")
	var pb := ch.proficiency_bonus()
	bonus.add("Arcane Overload", pb)
	return pb


# --- Attacks and damage: Lords' Alliance Agent, Spellfire Spark, Zhentarim Ruffian -------------------------

## Inspiring Strike: once per turn, a Critical Hit on a creature inspires an ally within 30 ft who sees or hears you.
func after_hit(c: Combatant, target: Combatant, critical: bool) -> void:
	if target != null and str(c.get_meta("flustering_armed", "")) == _turn_key() and _ch(c).resource_left("flustering_strike") > 0:
		_flustering_strike(c, target)
	if not critical or target == null or not feat(c, "lords_alliance_agent"):
		return
	var e := enc()
	var who := _uninspired_allies(c, 30, func(a: Combatant) -> bool: return e.spells.can_see_or_hear(a, c))
	if who.is_empty() or not _once_per_turn(c, "inspiring_strike_turn"):
		return
	_inspire(c, who[0], "Inspiring Strike")


## Reassert Honor: an enemy the holder can see hurts an ally beside it; the holder's next attack on that enemy has
## Advantage until the end of its next turn.
func after_damage(source: Combatant, target: Combatant, amount: int, parts: Array = []) -> void:
	var e := enc()
	if source == null or amount <= 0 or source == target:
		return
	# Dragonscarred: damage dealt on its own turn opens Dragon's Terror as a Bonus Action.
	if e.current() == source and feat(source, "dragonscarred"):
		source.set_meta("dragonscarred_turn", _turn_key())
	# Cold Caster: once per turn, a hit dealing Cold takes 1d4 off the target's next save before the caster's next
	# turn ends.
	var hit := str(e.hit_context.get("attacker", "")) == source.id and str(e.hit_context.get("target", "")) == target.id
	if hit and feat(source, "cold_caster") and parts.any(func(p: Variant) -> bool: return str((p as Dictionary).get("type", "")) == "cold" and int((p as Dictionary).get("amount", 0)) > 0) \
			and _once_per_turn(source, "cold_caster_turn"):
		var fx := Effect.new("Frostbite (Cold Caster)", &"feature", "cold_caster").with_modifier("penalty_die", {"dice": "1d4", "on": ["save:all"]})
		fx.caster_id = source.id
		fx.ends = Effect.Ends.END_OF_TURN
		fx.turn_owner_id = source.id
		fx.skip_turn_ends = e.own_turn_skip(source)
		fx.consume_on = ["save:all"]
		target.creature.add_effect(fx)
		_log("info", "%s is chilled: −1d4 on its next save (Cold Caster)" % target.name(), target)
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


# --- General feats ------------------------------------------------------------------------------------------

func _flustering_strike(c: Combatant, t: Combatant) -> void:
	var e := enc()
	_ch(c).spend_resource("flustering_strike")
	c.remove_meta("flustering_armed")
	var sv := t.creature.roll_save(e.dice, &"wis", _feat_dc(c, "fairy_trickster"), [], [], "Wisdom save vs Flustering Strike (%s)" % t.name())
	if sv.success:
		_log("info", "%s keeps its composure (Flustering Strike)" % t.name(), t, [sv.describe()])
		return
	var fx := Effect.new("Flustered", &"feature", "flustering_strike").with_modifier("disadvantage", {"on": "save:all"})
	fx.caster_id = c.id
	fx.ends = Effect.Ends.END_OF_TURN
	fx.turn_owner_id = c.id
	fx.skip_turn_ends = e.own_turn_skip(c)
	if t.creature.add_effect(fx):
		_log("condition", "%s is flustered: Disadvantage on saves (Flustering Strike)" % t.name(), t, [sv.describe()])


func _shrouding_spells(c: Combatant) -> CombatResult:
	var e := enc()
	if str(c.get_meta("shrouding_window", "")) != _turn_key() or _ch(c).resource_left("shrouding_spells") <= 0:
		return CombatResult.fail("Cast a spell with an action and a slot first")
	var why := e._bonus_check(c)
	if why != "":
		return CombatResult.fail(why)
	_ch(c).spend_resource("shrouding_spells")
	c.remove_meta("shrouding_window")
	c.bonus_available = false
	c.movement_left += c.speed()
	_log("info", "%s wraps itself in its spell's afterglow: Dash (Shrouding Spells)" % c.name(), c)
	var spotter := e.hide_blocker(c)
	if spotter != "":
		_log("info", "%s can't hide here (%s)" % [c.name(), spotter], c)
		return CombatResult.new()
	var t := c.creature.roll_check(e.dice, &"stealth", 15)
	if t.success:
		c.hidden = true
		c.stealth_total = t.total
		c.creature.add_condition(&"invisible", "Hidden")
		_log("info", "%s hides (Stealth %d)" % [c.name(), t.total], c, [t.describe()])
	else:
		_log("info", "%s fails to hide (Stealth %d vs DC 15)" % [c.name(), t.total], c, [t.describe()])
	return CombatResult.new()


## Sneaky Casting: a hidden caster stays hidden through a Verbal spell this turn; the end of its turn checks cover.
func sneaky_casting(c: Combatant) -> bool:
	if not feat(c, "spell_subterfuge"):
		return false
	c.set_meta("sneaky_cast_turn", _turn_key())
	return true


func turn_end(c: Combatant) -> void:
	if c.hidden and str(c.get_meta("sneaky_cast_turn", "")) == _turn_key():
		enc()._check_still_hidden(c)


func _commandant_rally(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	if t == null or not c.allied_with(t) or e.distance(c, t) > 30 or not e.can_see(c, t):
		return CombatResult.fail("Choose an ally you can see within 30 ft")
	var why := e._bonus_check(c)
	if why != "":
		return CombatResult.fail(why)
	if _ch(c).resource_left("commandant_rally") <= 0:
		return CombatResult.fail("None left")
	_ch(c).spend_resource("commandant_rally")
	c.bonus_available = false
	var amount := int(e.dice.roll_expr("2d6", "Rallying Command")["total"]) + _increased_mod(c, "purple_dragon_commandant")
	if t.creature.add_temp_hp(maxi(1, amount), "Rallying Command"):
		_log("heal", "%s rallies %s: %d Temporary Hit Points" % [c.name(), t.name(), maxi(1, amount)], c)
	else:
		_log("info", "%s rallies %s, who already has as many Temporary Hit Points" % [c.name(), t.name()], c)
	return CombatResult.new()


func _lordly_resolve(c: Combatant, picked: Array[Combatant]) -> CombatResult:
	var e := enc()
	if picked.is_empty() or picked.size() > 3:
		return CombatResult.fail("Choose up to three creatures within 60 ft who can see you")
	for t in picked:
		if e.distance(c, t) > 60 or not e.can_see(t, c):
			return CombatResult.fail("%s must be within 60 ft and see you" % t.name())
	var why := e._bonus_check(c)
	if why != "":
		return CombatResult.fail(why)
	if _ch(c).resource_left("lordly_resolve") <= 0:
		return CombatResult.fail("None left")
	_ch(c).spend_resource("lordly_resolve")
	c.bonus_available = false
	_log("info", "%s steadies the line (Lordly Resolve)" % c.name(), c)
	for t in picked:
		if t.creature.has_condition(&"prone") and e.spells.can_react(t) and t.speed() > 0:
			t.reaction_available = false
			t.creature.remove_condition(&"prone")
			_log("move", "%s gets back on its feet (Lordly Resolve)" % t.name(), t)
		var fx := Effect.new("Lordly Resolve", &"feature", "lordly_resolve").with_modifier("condition_immunity", {"value": "charmed"}) \
			.with_modifier("condition_immunity", {"value": "frightened"}).with_modifier("flag", {"value": "no_possession"}) \
			.with_modifier("advantage", {"on": ["save_vs:charmed", "save_vs:frightened"]})
		fx.caster_id = c.id
		fx.lasting({"kind": "minutes", "amount": 1})
		fx.turn_owner_id = c.id
		fx.data["ends_if_caster_incapacitated"] = true
		t.creature.add_effect(fx)
	return CombatResult.new()


## Lordly Resolve ends when its giver is Incapacitated; checked as each turn starts.
func turn_start(_c: Combatant) -> void:
	var e := enc()
	for t in e.combatants:
		for fx: Effect in t.creature.effects.duplicate():
			if not bool(fx.data.get("ends_if_caster_incapacitated", false)):
				continue
			var giver := e.get_c(fx.caster_id)
			if giver == null or not giver.can_act():
				t.creature.remove_effect(fx)


## Harper Teamwork: a holder's successful save ends its Frightened or Paralyzed; the same ends on an ally.
func after_save_ended(c: Combatant, fx: Effect) -> void:
	var e := enc()
	if not feat(c, "harper_teamwork"):
		return
	for cond: StringName in [&"frightened", &"paralyzed"]:
		if not cond in fx.conditions:
			continue
		for a in e.allies_of(c):
			if a == c or e.distance(c, a) > 30 or not e.can_see(c, a) or not a.creature.has_condition(cond):
				continue
			e.spells.cure(a, cond)
			_log("heal", "%s's courage frees %s: no longer %s (Harper Teamwork)" % [c.name(), a.name(), String(cond).capitalize()], c)
			e.events.append({"type": "condition", "id": a.id})
			return


## Faerie Trod Trotter: after Disengage on its own turn, no extra cost for Difficult Terrain until the turn ends.
func after_disengage(c: Combatant) -> void:
	if not feat(c, "fairy_trickster"):
		return
	var fx := Effect.new("Faerie Trod Trotter", &"feature", "faerie_trod_trotter").with_modifier("flag", {"value": "ignore_difficult_terrain"})
	fx.ends = Effect.Ends.END_OF_TURN
	fx.turn_owner_id = c.id
	c.creature.add_effect(fx)


## Divination Adept (Automatic only: a roll can't wait for a choice): Disadvantage on an enemy's save against the
## holder's own spell. Order's Resilience: Advantage on Strength saves beside an ally.
func before_d20(c: Combatant, kind: D20Test.Kind, keys: Array[String]) -> Dictionary:
	var e := enc()
	var out := {}
	if kind != D20Test.Kind.SAVING_THROW:
		return out
	for h in e.combatants:
		var hc := _ch(h)
		if hc == null or not feat(h, "divination_adept") or not ("save_vs:spell:" + h.id) in keys or not h.hostile_to(c):
			continue
		if str(h.reaction_rules.get("divination_adept_benefit", "never")) != "auto" or hc.resource_left("divination_adept") <= 0:
			continue
		if not e.spells.can_react(h) or e.distance(h, c) > 60 or not e.can_see(h, c):
			continue
		hc.spend_resource("divination_adept")
		h.reaction_available = false
		_log("reaction", "%s foresees %s faltering (Divination Adept)" % [h.name(), c.name()], h)
		out["disadvantage"] = ["Divination Adept"]
		break
	if "save:str" in keys and c.can_act():
		for h2 in e.combatants:
			if not feat(h2, "orders_resilience") or not h2.can_act() or not h2.allied_with(c):
				continue
			var partner := h2 != c and e.distance(h2, c) <= 5
			if h2 == c:
				partner = e.allies_of(c).any(func(a: Combatant) -> bool: return a != c and a.can_act() and e.distance(a, c) <= 5)
			if partner:
				out["advantage"] = ["Order's Resilience"]
				break
	return out


## Street Justice's Headlock: allies have Advantage against a creature the holder is grappling.
func attack_advantage(c: Combatant, target: Combatant) -> Array[String]:
	var out: Array[String] = []
	var e := enc()
	# `grapples` maps a grappled creature to its grappler.
	if target == null or not e.grapples.has(target.id):
		return out
	var grappler := e.get_c(str(e.grapples[target.id]))
	if grappler != null and grappler != c and feat(grappler, "street_justice") and grappler.allied_with(c):
		out.append("Headlock (%s)" % grappler.name())
	return out


## Zhentarim Tactics: a melee hit from a creature within 5 ft earns an Opportunity Attack back.
func queue_damage_reactions(source: Combatant, target: Combatant) -> void:
	var e := enc()
	if source == null or target == null or not feat(target, "zhentarim_tactics") or not bool(e.hit_context.get("melee", false)):
		return
	if str(e.hit_context.get("attacker", "")) != source.id or e.distance(target, source) > 5 or not e.spells.can_react(target):
		return
	if e.best_melee_option(target, source).is_empty():
		return
	e.reaction_queue.append({"kind": "fr_zhentarim_tactics", "reactor": target.id, "trigger": source.id})


func queued_ok(q: Dictionary, reactor: Combatant) -> bool:
	var e := enc()
	if str(q["kind"]) == "fr_zhentarim_tactics":
		var t := e.get_c(str(q["trigger"]))
		return e.spells.can_react(reactor) and t != null and t.is_alive() and e.distance(reactor, t) <= 5
	return false


func fire_queued(q: Dictionary, reactor: Combatant, trigger: Combatant) -> CombatResult:
	if str(q["kind"]) == "fr_zhentarim_tactics":
		return enc()._opportunity_attack(reactor, trigger)
	return CombatResult.new()


func queued_text(kind: String) -> Array:
	if kind == "fr_zhentarim_tactics":
		return ["Reaction: Zhentarim Tactics?", "%s hit %s in melee. Answer with an Opportunity Attack?", "Reaction"]
	return ["Reaction?", "%s / %s", "Reaction"]

