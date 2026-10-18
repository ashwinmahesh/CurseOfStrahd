extends Node


func capture_shots(tool: Node, out: String) -> void:
	var view := CombatView.new()
	view.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(view)
	view.e = TestCombat.open_field()
	TestCombat.hero(view.e, "godrick_pendlebrook", Vector2i(2, 2))
	TestCombat.foe(view.e, "zombie", Vector2i(8, 6))
	view.recovery = CombatJournal.begin(view.e)
	var fail_write := [true]
	view.recovery_writer = func() -> Error: return ERR_FILE_CANT_WRITE if bool(fail_write[0]) else OK
	view._record_command("start", {"surprised": []})
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_storage_retry.png")
	fail_write[0] = false
	view.recovery_retry.emit()
	view.queue_free()
