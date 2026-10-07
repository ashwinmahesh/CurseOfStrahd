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
var continuation: Callable
## Optional multi-selection for triggered effects; a decision need not spend a Reaction.
var target_choices: Array[Dictionary] = []
var selected_ids: Array[String] = []
var spends_reaction: bool = true
var min_targets: int = 0
var max_targets: int = 0
var validate_selected: Callable


func selection_error() -> String:
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
