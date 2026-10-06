class_name CombatResult
extends RefCounted
## What an encounter command did. `ok` false means nothing happened and `reason` says why ("Bonus Action
## already used"). `pending` is set when the command paused for a player's reaction choice (plan §5.3: the
## player is asked for every reaction unless they set a rule); answer it with Encounter.answer_reaction().

var ok: bool = true
var reason: String = ""
var pending: ReactionRequest = null
var hit: bool = false
var critical: bool = false
var damage: int = 0
var killed: Array[String] = []
var lines: Array[Dictionary] = []


static func fail(why: String) -> CombatResult:
	var r := CombatResult.new()
	r.ok = false
	r.reason = why
	return r


func is_paused() -> bool:
	return pending != null
