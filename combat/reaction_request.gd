class_name ReactionRequest
extends RefCounted
## A Reaction a player-controlled creature could take right now (Opportunity Attack, Shield, Uncanny Dodge),
## waiting for the player's answer. The encounter is paused until Encounter.answer_reaction() is called; the
## continuation then finishes whatever triggered it (the move, the attack) and may pause again.

static var _next: int = 1

var id: int
## opportunity_attack, shield, uncanny_dodge, ...
var kind: String
var reactor_id: String
var trigger_id: String
## Plain-language prompt: what happened, what the reaction would change, what it costs.
var title: String = ""
var text: String = ""
var cost: String = "Reaction"
## A short line the prompt shows in red under its title, for what mustn't be missed (owner, 2026-10-13: a Critical Hit
## on Divine Smite's prompt, which doubles its dice). "" for none.
var callout: String = ""
var continuation: Callable
## Optional multi-selection for triggered effects; a decision need not spend a Reaction.
var target_choices: Array[Dictionary] = []
var selected_ids: Array[String] = []
var spends_reaction: bool = true
var min_targets: int = 0
var max_targets: int = 0
var validate_selected: Callable
## A pool of points to divide among the listed creatures (Preserve Life): `pool` is how many there are in all, and
## `amounts` (id -> points) what each creature is given so far. Each `target_choices` entry's "room" is the most it can
## take. Nothing happens until the player confirms, and the points left over are lost; a prompt with no pool is 0.
var pool: int = 0
var amounts: Dictionary = {}


## The listed option with this id ({} if none). The options of a prompt listing several Reactions (Reactions.CHOICE)
## also carry the `text` and `cost` it shows while that one is picked.
func choice(choice_id: String) -> Dictionary:
	for t in target_choices:
		if str(t["id"]) == choice_id:
			return t
	return {}


## Points of the pool handed out so far.
func shared() -> int:
	var total := 0
	for id: Variant in amounts:
		total += int(amounts[id])
	return total


## Points of the pool still to give.
func unspent() -> int:
	return pool - shared()


## What's wrong with how the pool is divided, in words for the prompt ("" when it can be confirmed).
func pool_error() -> String:
	for t in target_choices:
		var give := int(amounts.get(str(t["id"]), 0))
		if give < 0 or give > int(t.get("room", 0)):
			return "%s can regain at most %d" % [t.get("name", "They"), int(t.get("room", 0))]
	if shared() > pool:
		return "Only %d Hit Points to share" % pool
	if shared() <= 0:
		return "Give someone at least 1 Hit Point"
	return ""


func selection_error() -> String:
	if pool > 0:
		var why := pool_error()
		if why != "":
			return why
	if selected_ids.size() < min_targets or (max_targets > 0 and selected_ids.size() > max_targets):
		return "Choose exactly %d option%s" % [min_targets, "" if min_targets == 1 else "s"]
	if max_targets > 0:
		var seen: Array[String] = []
		for selected in selected_ids:
			if selected in seen or not target_choices.any(func(t: Dictionary) -> bool: return str(t["id"]) == selected):
				return "Choose a listed option"
			seen.append(selected)
	if validate_selected.is_valid():
		return str(validate_selected.call(selected_ids))
	return ""


func _init(kind_: String, reactor: String, trigger: String) -> void:
	id = _next
	_next += 1
	kind = kind_
	reactor_id = reactor
	trigger_id = trigger
