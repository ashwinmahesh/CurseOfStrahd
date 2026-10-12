class_name CheckAids
extends RefCounted
## What a character can spend after failing an ability check outside a fight (2024 PHB): Heroic Inspiration rerolls
## the d20 and keeps the new roll; Tactical Mind (Fighter 2) spends a use of Second Wind to add 1d10, and the use
## isn't spent if the check still fails; Dark One's Own Luck (Fiend 6) adds 1d10, once a roll, unless its rule is Off.
## Offered by conversations after a failed check (the player decides).

## Dark One's Own Luck: its resource, and its rule's key in Character.reaction_rules (Ask / Automatic / Off).
const OWN_LUCK := "dark_ones_own_luck"
## Helpful Friend (Familiar Friend) works before a check instead (`before_check`), so it never reopens a failed one.


## [{id, label}] for a failed check `test` by `ch`.
static func options(ch: Character, test: D20Test) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if ch == null or test == null or test.success:
		return out
	if ch.heroic_inspiration:
		out.append({"id": "heroic_inspiration", "label": "Heroic Inspiration: reroll the d20"})
	# Lucky Foot: a natural 1 rolled again (the charm is used up).
	if test.kept == 1 and not test.auto_failed and ch.inventory.any(func(e: Dictionary) -> bool: return str(e["id"]) == "lucky_foot" and int(e.get("qty", 0)) > 0):
		out.append({"id": "lucky_foot", "label": "Lucky Foot: reroll the natural 1 (the charm is used up)"})
	if _has_feature(ch, "tactical_mind") and ch.resource_left("second_wind") > 0:
		out.append({"id": "tactical_mind", "label": "Tactical Mind: add 1d10 (a Second Wind use, kept if it still fails)"})
	if own_luck_ready(ch, test):
		out.append({"id": OWN_LUCK, "label": "Dark One's Own Luck: add 1d10 (%d left)" % ch.resource_left(OWN_LUCK)})
	return out


## Whether Dark One's Own Luck could go on failed roll `test`: a use left, 1d10 could still turn it, not used on this
## roll already, and its rule isn't Off.
static func own_luck_ready(ch: Character, test: D20Test) -> bool:
	return ch != null and test != null and not test.success and _has_feature(ch, OWN_LUCK) and ch.resource_left(OWN_LUCK) > 0 \
		and test.target - test.total <= 10 and not test.extra_label.contains("Dark One's Own Luck") \
		and str(ch.reaction_rules.get(OWN_LUCK, "ask")) != "never"


## A save outside a fight that goes off at once (a trap, a pit's edge): nobody can be asked mid-fall, so Dark One's Own
## Luck is used only when its rule is Automatic. True when it was.
static func own_luck_on_save(cr: Creature, test: D20Test, dice: DiceRoller) -> bool:
	var ch := cr as Character if cr is Character else null
	if ch == null or str(ch.reaction_rules.get(OWN_LUCK, "ask")) != "auto" or not own_luck_ready(ch, test):
		return false
	apply(OWN_LUCK, ch, test, dice)
	return true


## Applies aid `id` to `test` (in place) and returns it.
static func apply(id: String, ch: Character, test: D20Test, dice: DiceRoller) -> D20Test:
	match id:
		"heroic_inspiration":
			if ch.heroic_inspiration:
				ch.heroic_inspiration = false
				var n := dice.d20("Heroic Inspiration reroll (%s)" % ch.name)
				test.set_natural(n, "Heroic Inspiration")
		"lucky_foot":
			if test.kept == 1:
				ch.remove_one("lucky_foot")
				test.set_natural(dice.d20("Lucky Foot (%s)" % ch.name), "Lucky Foot")
		OWN_LUCK:
			if own_luck_ready(ch, test):
				ch.spend_resource(OWN_LUCK)
				test.add_bonus(int(dice.roll_expr("1d10", "Dark One's Own Luck (%s)" % ch.name)["total"]), "Dark One's Own Luck")
		"tactical_mind":
			if ch.resource_left("second_wind") > 0:
				var r := int(dice.roll_expr("1d10", "Tactical Mind (%s)" % ch.name)["total"])
				test.add_bonus(r, "Tactical Mind")
				if test.success:
					ch.spend_resource("second_wind")
	return test


## Cantrips that only did tricks help a skill check outside fights instead (Ashwin's answer to the spell audit,
## 2026-10-12; docs/rules/deviations.md): a character who knows one works a little magic into the attempt.
const CANTRIP_AIDS := {"druidcraft": ["nature"], "elementalism": ["survival"], "mending": ["investigation"],
	"message": ["stealth"], "minor_illusion": ["deception"], "prestidigitation": ["performance"],
	"thaumaturgy": ["intimidation"]}


## Advantage sources for a check `cr` is about to make outside a fight with `skill`: a cantrip that helps it
## (CANTRIP_AIDS), and Helpful Friend (Familiar Friend) when the skill is one it's proficient in and a use is left,
## spending the use; its familiar is taken to be at its side.
static func before_check(cr: Creature, skill: StringName) -> Array[String]:
	var out: Array[String] = []
	var ch := cr as Character if cr is Character else null
	if ch == null:
		return out
	for spell_id: String in CANTRIP_AIDS:
		if str(skill) in (CANTRIP_AIDS[spell_id] as Array) and ch.knows_spell(spell_id):
			out.append(Compendium.shared().display_name("spells", spell_id))
	if ch.resource_left("helpful_friend") <= 0 or not Abilities.SKILLS.has(skill) or ch.skill_rank(skill) < 1:
		return out
	if not ch.feats_taken.any(func(f: Dictionary) -> bool: return str(f["id"]) == "familiar_friend"):
		return out
	ch.spend_resource("helpful_friend")
	out.append("Helpful Friend")
	return out


static func _has_feature(ch: Character, feature_id: String) -> bool:
	for f in ch.features:
		if str(f.get("id", "")) == feature_id:
			return true
	return false
