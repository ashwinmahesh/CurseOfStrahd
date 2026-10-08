class_name Captives
extends RefCounted
## Foes who gave up (F13, docs/plans/captives.md): those left at a won fight's end who surrendered (AiTactics) or were
## knocked out (lane 2's knock-out rule, the "knocked_out" flag). The party deals with them in a conversation right
## after the fight (narrative/captives/<kind>.dialogue): question them, let them go, hand them over where there's a
## watch, or kill them, and the companions react. Which conversation depends on the fight, then on who leads them.

## Fights whose captives have their own conversation: encounter id -> kind.
const BY_FIGHT := {
	"tser_pool_brawl": "vistani", "tser_pool_ambush": "vistani",
	"wachter_cellar_cult": "wachter", "festival_coup": "wachter",
	"festival_loyalists": "vallaki_watch", "festival_izek_rampage": "vallaki_watch", "izek_duel": "vallaki_watch",
	"izek_confrontation": "vallaki_watch",
	"winery_occupation": "wardens", "cellar_dig": "wardens", "wardens_camp_fight": "wardens", "summit_ritual": "wardens",
	"wards_cells": "belview", "bride_defends": "belview",
}
## Otherwise by the leading captive's stat block: monster id -> kind. Anyone else gets the plain conversation.
const BY_MONSTER := {"mongrelfolk": "belview", "druid": "wardens", "berserker": "wardens", "cultist": "wachter"}

## What the companions think of a foe cut down after it threw down its weapons (once a fight).
const CRUELTY := [["godrick_pendlebrook", -4], ["liriel_dawnsong", -3], ["wren_featherfoot", -4], ["thistle", -2]]
const CRUELTY_WHY := "You cut down a foe who had thrown down their weapons"


## Whether `c` is a captive: surrendered, or knocked out (still at 1 Hit Point or more) and one who could talk and give
## up (AiTactics.can_surrender: a knocked-out wolf or boss is left where it lies).
static func gave_up(c: Combatant) -> bool:
	if not c.is_alive():
		return false
	if c.creature.has_flag("surrendered"):
		return true
	return c.creature.has_flag("knocked_out") and c.creature.hp > 0 and AiTactics.can_surrender(c)


## The captives a won fight leaves: its foes who gave up, the strongest first.
static func taken(e: Encounter) -> Array[Combatant]:
	var out: Array[Combatant] = []
	if e.outcome != "victory":
		return out
	for c in e.combatants:
		if c.side == &"enemy" and not e.legendary.departed.has(c.id) and gave_up(c):
			out.append(c)
	out.sort_custom(func(a: Combatant, b: Combatant) -> bool: return _cr(a) > _cr(b))
	return out


## How many foes the party killed after they surrendered.
static func slain_after_surrender(e: Encounter) -> int:
	var n := 0
	for c in e.combatants:
		if c.side == &"enemy" and c.creature.dead and c.creature.has_flag("surrendered"):
			n += 1
	return n


## The conversation for these captives after the fight `encounter_id`: "captives/<kind>:start".
static func conversation(captives: Array[Combatant], encounter_id: String) -> String:
	if captives.is_empty():
		return ""
	var kind := str(BY_FIGHT.get(encounter_id, ""))
	if kind == "":
		var lead := captives[0].creature as Monster if captives[0].creature is Monster else null
		kind = str(BY_MONSTER.get(str(lead.data.get("id", "")) if lead != null else "", "plain"))
	return "captives/%s:start" % kind


## A failed Persuasion or Intimidation is spent for good (owner rule, 2026-10-06), but every fight's captives are new
## people: what failed with the last ones doesn't carry over to these. Forgets the captives' spent checks.
static func forget_spent(st: StoryState) -> void:
	for k: Variant in st.flags.keys():
		if str(k).begins_with("_failed/captives/"):
			st.flags.erase(k)


static func _cr(c: Combatant) -> float:
	return float((c.creature as Monster).data.get("cr", 0)) if c.creature is Monster else 0.0
