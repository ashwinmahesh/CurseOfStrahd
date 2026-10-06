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


func _init(kind_: String, reactor: String, trigger: String) -> void:
	id = _next
	_next += 1
	kind = kind_
	reactor_id = reactor
	trigger_id = trigger
