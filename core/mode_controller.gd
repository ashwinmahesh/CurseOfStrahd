extends Node
## Owns which play mode is active and which transitions are legal (plan §4.3). Systems that need
## to react (combat start rolls initiative, etc.) listen to EventBus.mode_changed.

enum Mode { EXPLORATION, DIALOGUE, COMBAT, REST, TRAVEL, CUTSCENE }

## Legal transitions. Cutscenes can interrupt anything and return anywhere.
const TRANSITIONS := {
	Mode.EXPLORATION: [Mode.DIALOGUE, Mode.COMBAT, Mode.REST, Mode.TRAVEL, Mode.CUTSCENE],
	Mode.DIALOGUE: [Mode.EXPLORATION, Mode.COMBAT, Mode.CUTSCENE],
	Mode.COMBAT: [Mode.EXPLORATION, Mode.DIALOGUE, Mode.CUTSCENE],
	Mode.REST: [Mode.EXPLORATION, Mode.COMBAT, Mode.CUTSCENE],
	Mode.TRAVEL: [Mode.EXPLORATION, Mode.COMBAT, Mode.CUTSCENE],
	Mode.CUTSCENE: [Mode.EXPLORATION, Mode.DIALOGUE, Mode.COMBAT, Mode.REST, Mode.TRAVEL],
}

var mode: Mode = Mode.EXPLORATION


func can_enter(next: Mode) -> bool:
	return next in (TRANSITIONS[mode] as Array)


func enter(next: Mode) -> bool:
	if next == mode:
		return true
	if not can_enter(next):
		push_warning("Illegal mode change %s -> %s" % [Mode.keys()[mode], Mode.keys()[next]])
		return false
	var old := mode
	mode = next
	EventBus.mode_changed.emit(old, next)
	return true


func force(next: Mode) -> void:
	mode = next
