extends Node
## Global signals that let systems talk without referencing each other (plan §4.3).
## Add a signal here only when two lanes need it; document it in docs/contracts/events.md.

signal mode_changed(old_mode: int, new_mode: int)
signal roll_made(entry: Dictionary)
signal leader_changed(index: int)
signal location_entered(location_id: String)
signal flag_changed(flag: String, value: Variant)
signal game_saved(slot: String)
signal game_loaded(slot: String)
signal scene_changed(path: String)
