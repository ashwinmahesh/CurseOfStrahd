class_name Difficulty
extends RefCounted
## How hard a playthrough is (F1, docs/plans/difficulty.md): Story, Balanced, Tactician or Honour, kept in the save as
## StoryState.options["difficulty"]. No mode touches the dice math (plan §5.3: attack bonuses, AC, save DCs and damage
## dice stay the 2024 numbers) except Baldur's Gate 3's +2s, which the owner asked for (2026-10-07): the party's
## attack rolls and saving throws on Story, and enemies' attack rolls and DCs on Tactician and Honour. A mode also moves
## enemy Hit Points within what their Hit Dice could roll, sets how the enemy AI fights (AiBrain reads `tactics`), and
## switches a few optional rules. Balanced was the game as it played before the modes, so older saves are Balanced;
## since 2026-10-13 its casters also cast their best spell when it beats the weapon (owner). Every change shows in a
## Breakdown under the mode's name ("Tactician +2").
##
## A fight is set up with prepare() before it starts; a fight resumed from a round-start save only needs arm().

const DEFAULT := "balanced"
const IDS: Array[String] = ["story", "balanced", "tactician", "honour"]

## A boss, for Honour's "bosses at full strength": legendary actions, or Challenge Rating 5 and up.
const BOSS_CR := 5.0
## The game's named bosses (G3): monster id -> {title} or {names: {name: title}}. The boss bar shows them, and what a boss
## deals is multiplied by boss_damage (the other bosses are the foes with legendary actions: boss_entry).
const BOSSES := "res://narrative/combat/bosses.json"
static var _bosses: Dictionary = {}

## Each mode's rules.
##   hp:            enemy Hit Points as a share of what the fight gives them, kept inside the Hit Dice range.
##   party_bonus:   added to the party's attack rolls (weapons and spells) and saving throws.
##   enemy_bonus:   added to enemies' attack rolls (weapons and spells) and the DCs of their spells and actions.
##   tactics:       kind (spread blows, no killing blow), standard (as before the modes), sharp (focus fire on the
##                  hurt and on healers and casters, and move to flank), ruthless (sharp, and cruel foes strike heroes
##                  at 0 HP).
##   spells:        enemy spellcasters weigh every harmful spell of their list (AiSpells) and cast the best when it
##                  beats their weapon (owner, 2026-10-13: every foe with spells uses them when that's its best
##                  option, on Balanced too); off, only a spellcaster's few (an escape, Phantasmal Killer, Magic
##                  Missile).
##   kit:           armed humanoid foes carry a Potion of Healing (drunk when Bloodied), casters a scroll of their
##                  strongest spell; what isn't used is looted.
##   morale:        when its side breaks, a foe that isn't mindless or a boss flees the field.
##   full_bosses:   a fight's lighter version of a boss (for a lower-level party) is put back to its stat block.
##   boss_damage:   what a boss's damage to the other side is multiplied by (owner, 2026-10-19: bosses hit about 25%
##                  harder; Story, the mode for the tale, keeps the book's numbers). Who counts is boss_entry.
##   spared:        a party member who would die is left Unconscious and Stable instead.
##   safe_rests:    Long Rests in risky places are never interrupted.
##   one_save:      the playthrough keeps a single save (built by the saves lane).
##   switchable:    can be picked in Settings mid-game (Honour only at a new game).
const MODES := {
	"story": {"name": "Story", "hp": 0.75, "party_bonus": 2, "enemy_bonus": 0, "tactics": "kind", "spells": false, "kit": false, "morale": false, "full_bosses": false,
		"boss_damage": 1.0, "spared": true, "safe_rests": true, "one_save": false, "switchable": true,
		"tagline": "For the tale",
		"summary": "Foes are frailer and spread their blows around, your party gets +2 to attacks and saves, and nobody dies for good."},
	"balanced": {"name": "Balanced", "hp": 1.0, "party_bonus": 0, "enemy_bonus": 0, "tactics": "standard", "spells": true, "kit": false, "morale": false,
		"full_bosses": false, "boss_damage": 1.25, "spared": false, "safe_rests": false, "one_save": false, "switchable": true,
		"tagline": "The book as written",
		"summary": "Foes at their stat block, fighting the way the book has them."},
	"tactician": {"name": "Tactician", "hp": 1.2, "party_bonus": 0, "enemy_bonus": 2, "tactics": "sharp", "spells": true, "kit": true, "morale": true,
		"full_bosses": false, "boss_damage": 1.25, "spared": false, "safe_rests": false, "one_save": false, "switchable": true,
		"tagline": "For a hard fight",
		"summary": "Tougher, sharper foes (+2 to hit and to their DCs) who gang up on the hurt, go for your healers, drink their potions and run when beaten."},
	"honour": {"name": "Honour", "hp": 1.2, "party_bonus": 0, "enemy_bonus": 2, "tactics": "ruthless", "spells": true, "kit": true, "morale": true, "full_bosses": true,
		"boss_damage": 1.25, "spared": false, "safe_rests": false, "one_save": true, "switchable": false,
		"tagline": "One life, one save",
		"summary": "Tactician with no mercy: bosses at full strength, cruel foes finish the fallen, and one save."},
}

var id: String = DEFAULT
var name: String = ""
var tagline: String = ""
var summary: String = ""
var hp_scale: float = 1.0
var party_bonus: int = 0
var enemy_bonus: int = 0
var tactics: String = "standard"
var spells: bool = false
var kit: bool = false
var morale: bool = false
var full_bosses: bool = false
var boss_damage: float = 1.0
var spared: bool = false
var safe_rests: bool = false
var one_save: bool = false
var switchable: bool = true


## The mode `mode_id` (an unknown id is Balanced).
static func named(mode_id: String) -> Difficulty:
	var key := mode_id if MODES.has(mode_id) else DEFAULT
	var m := MODES[key] as Dictionary
	var d := Difficulty.new()
	d.id = key
	d.name = str(m["name"])
	d.tagline = str(m["tagline"])
	d.summary = str(m["summary"])
	d.hp_scale = float(m["hp"])
	d.party_bonus = int(m["party_bonus"])
	d.enemy_bonus = int(m["enemy_bonus"])
	d.tactics = str(m["tactics"])
	d.spells = bool(m["spells"])
	d.kit = bool(m["kit"])
	d.morale = bool(m["morale"])
	d.full_bosses = bool(m["full_bosses"])
	d.boss_damage = float(m["boss_damage"])
	d.spared = bool(m["spared"])
	d.safe_rests = bool(m["safe_rests"])
	d.one_save = bool(m["one_save"])
	d.switchable = bool(m["switchable"])
	return d


## The mode a playthrough's options hold (StoryState.options; none set is Balanced).
static func of_options(options: Dictionary) -> Difficulty:
	return named(str(options.get("difficulty", DEFAULT)))


## Whether Settings may switch a playthrough from `from` to `to` mid-game: Story, Balanced and Tactician change freely;
## Honour is only chosen for a new game. Leaving Honour is allowed and is for good (switch_warning says so).
static func can_switch(from: String, to: String) -> bool:
	return MODES.has(to) and to != from and bool((MODES[to] as Dictionary)["switchable"])


## What the player is told before a switch that can't be undone ("" when there's nothing to warn about).
static func switch_warning(from: String, to: String) -> String:
	if from == "honour" and to != "honour":
		return "This playthrough stops being an Honour run, for good."
	return ""


## What this mode changes, a line each (the New game page's tip, and the Settings row).
func describe() -> Array[String]:
	var out: Array[String] = []
	if is_equal_approx(hp_scale, 1.0):
		out.append("Enemy Hit Points: their stat block's.")
	else:
		out.append("Enemy Hit Points: %d%% %s, within what their Hit Dice could roll." % [
			absi(roundi((hp_scale - 1.0) * 100.0)), "fewer" if hp_scale < 1.0 else "more"])
	if party_bonus != 0:
		out.append("+%d to your attack rolls and saving throws." % party_bonus)
	if enemy_bonus != 0:
		out.append("+%d to enemies' attack rolls and the DCs of their spells and abilities." % enemy_bonus)
	match tactics:
		"kind":
			out.append("Enemies spread their attacks around and don't chase the killing blow.")
		"standard":
			out.append("Enemies fight as the book has them.")
		_:
			out.append("Enemies gang up on the hurt and go for your healers and spellcasters first.")
	if spells:
		out.append("Enemy spellcasters cast from their whole spell list when a spell beats their weapon.")
	if tactics == "ruthless":
		out.append("Cruel foes strike a hero who has fallen to 0 Hit Points.")
	if kit:
		out.append("Armed foes carry a Potion of Healing and drink it when Bloodied; casters carry a spell scroll. You loot what they don't use.")
	if morale:
		out.append("When their side breaks, foes flee the fight, except mindless things and bosses.")
	if full_bosses:
		out.append("Bosses always come at full strength.")
	if not is_equal_approx(boss_damage, 1.0):
		out.append("Bosses hit %d%% harder." % roundi((boss_damage - 1.0) * 100.0))
	if spared:
		out.append("Nobody in your party dies for good: a hero who would die is left Unconscious and Stable.")
	if safe_rests:
		out.append("Long Rests are never interrupted.")
	if one_save:
		out.append("One save, which the game keeps for you.")
	out.append("Can be changed later in Settings." if switchable else "Chosen only when starting a new game.")
	return out


## Whether `m` counts as a boss: legendary actions, or Challenge Rating 5 and up.
static func is_boss(m: Monster) -> bool:
	return m.data.has("legendary_actions") or float(m.data.get("cr", 0)) >= BOSS_CR


## narrative/combat/bosses.json, read once.
static func boss_data() -> Dictionary:
	if _bosses.is_empty():
		_bosses = JSON.parse_string(FileAccess.get_file_as_string(BOSSES)) as Dictionary
	return _bosses


## What makes `c` one of the game's bosses: {"title": ...} (the title may be ""), or {} for any other creature. Listed in
## bosses.json by monster id or by the name a fight gives it, or any foe with legendary actions; only foes count, so a
## boss's helpers (a flesh golem, a wraith, spawn) aren't, unlike is_boss's wider net of Challenge Rating 5 and up.
static func boss_entry(c: Combatant) -> Dictionary:
	if c.side != &"enemy" or not c.creature is Monster:
		return {}
	var m := c.creature as Monster
	var spec := ((boss_data().get("bosses", {}) as Dictionary).get(str(m.data.get("id", "")), {}) as Dictionary)
	if spec.has("names"):
		var names := spec["names"] as Dictionary
		if names.has(c.name()):
			return {"title": str(names[c.name()])}
	elif not spec.is_empty():
		return {"title": str(spec.get("title", ""))}
	if not (m.data.get("legendary_actions", {}) as Dictionary).is_empty():
		return {"title": ""}
	return {}


## What `source`'s damage to `target` is multiplied by: boss_damage when `source` is one of the game's bosses (boss_entry)
## and `target` is on the other side; 1 for anyone else, a boss's own minions and the party. Where it's used:
## EncounterDamage.deal_damage.
func damage_factor(source: Combatant, target: Combatant) -> float:
	if is_equal_approx(boss_damage, 1.0) or source == null or target == null or source.side == target.side:
		return 1.0
	return boss_damage if not boss_entry(source).is_empty() else 1.0


## The lowest and highest Hit Points `m`'s Hit Dice could roll (x and y); its average twice when it has no dice.
static func hit_dice_range(m: Monster) -> Vector2i:
	var hp := m.data.get("hp", {}) as Dictionary
	var avg := int(hp.get("average", m.hp_max_base))
	var expr := str(hp.get("dice", ""))
	if expr == "":
		return Vector2i(avg, avg)
	var p := DiceRoller.parse_expr(expr)
	var lo := int(p["count"]) + int(p["modifier"])
	var hi := int(p["count"]) * int(p["sides"]) + int(p["modifier"])
	return Vector2i(maxi(1, mini(lo, avg)), maxi(hi, avg))


## The Hit Point maximum this mode gives `m`, whose fight gives it `base` (its stat block's average, or the fight's
## tuned number): hp_scale of it, never outside its Hit Dice range. Honour starts a boss from at least its average.
func monster_hp(m: Monster, base: int) -> int:
	var from := base
	if full_bosses and is_boss(m):
		from = maxi(base, int((m.data.get("hp", {}) as Dictionary).get("average", base)))
	if is_equal_approx(hp_scale, 1.0) and from == base:
		return base
	var span := hit_dice_range(m)
	var want := roundi(float(from) * hp_scale)
	# A fight tuned above the stat block's dice keeps its own number as the ceiling (and below it, as the floor).
	return clampi(want, mini(span.x, from), maxi(span.y, from))


# --- Setting a fight up -------------------------------------------------------------------------------------------

## Sets up a fight before it starts: each enemy's Hit Points, what armed foes carry, and the party's rules (arm()).
func prepare(e: Encounter) -> void:
	for c in e.combatants:
		if c.side == &"enemy" and c.creature is Monster:
			toughen(c)
			if kit:
				equip(c)
	arm(e)


## The rules the fight reads as it goes (also after resuming a fight from its round-start save), and the party's
## bonus for this mode.
func arm(e: Encounter) -> void:
	e.difficulty = self
	for c in e.combatants:
		if c.side in [&"party", &"guest"]:
			c.creature.spared_from_death = spared
			fit_party(c.creature)


## Puts this mode's bonus on a party member (Story's +2 to attack rolls and saving throws), and takes off any other
## mode's. It stays between fights, so saves outside a fight get it too; Settings calls this after a switch.
func fit_party(cr: Creature) -> void:
	for fx: Effect in cr.effects.duplicate():
		if fx.source_id == "difficulty":
			cr.remove_effect(fx)
	if party_bonus == 0:
		return
	var fx2 := Effect.new(name, &"feature", "difficulty")
	for stat: String in ["attack", "spell_attack"]:
		fx2 = fx2.with_modifier(stat, {"value": party_bonus})
	fx2 = fx2.with_modifier("save", {"ability": "all", "value": party_bonus})
	fx2.ends = Effect.Ends.NEVER
	cr.add_effect(fx2)


## This mode's numbers for an enemy, as one effect under the mode's name: its Hit Points, and Tactician's +2 to its
## attack rolls and DCs. They show in its Breakdowns ("Stat block (17d8+68) 144, Tactician +29"). Before a fight it
## starts unhurt; one joining mid-fight keeps what it came with, moved by the same number (a werewolf risen from a
## cursed hero has 10).
func toughen(c: Combatant, fresh: bool = true) -> void:
	var m := c.creature as Monster
	if m == null or m.effects.any(func(fx: Effect) -> bool: return fx.source_id == "difficulty"):
		return
	var base := m.hp_max_base
	if full_bosses and is_boss(m):
		var avg := int((m.data.get("hp", {}) as Dictionary).get("average", base))
		if avg > base:
			m.hp_max_base = avg   # its stat block, not the fight's lighter version
			base = avg
	var want := monster_hp(m, base)
	var fx := Effect.new(name, &"feature", "difficulty")
	if want != base:
		fx = fx.with_modifier("hp_max", {"value": want - base})
	if enemy_bonus != 0:
		for stat: String in ["attack", "spell_attack", "spell_dc"]:
			fx = fx.with_modifier(stat, {"value": enemy_bonus})
	if not fx.modifiers.is_empty():
		fx.ends = Effect.Ends.NEVER
		m.add_effect(fx)
	m.hp = m.max_hp() if fresh else clampi(m.hp + want - base, mini(1, m.hp), m.max_hp())


## What foes carry: armed humanoids (a stat block with gear) a Potion of Healing, casters a scroll of their strongest
## spell that harms or hinders (combat/ai/ai_spells.gd).
func equip(c: Combatant) -> void:
	var m := c.creature as Monster
	if m == null:
		return
	if m.creature_type == &"humanoid" and m.data.has("gear"):
		c.set_meta("potions", 1)
	var scroll := AiSpells.scroll_pick(m)
	if scroll != "":
		c.set_meta("scroll", scroll)
