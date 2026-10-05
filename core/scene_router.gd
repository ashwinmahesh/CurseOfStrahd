extends Node
## Changes the active level and records it in GameState so a save knows where the party is.


func go_to(path: String) -> Error:
	var err := get_tree().change_scene_to_file(path)
	if err == OK:
		GameState.current_scene = path
		EventBus.scene_changed.emit(path)
	return err
