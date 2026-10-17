extends Node
## Real conversation art/layout with prepared lines; offscreen mobile profiles, not native iOS E2E.

func capture_shots(tool: Node, out: String) -> void:
	DialogueFile.register(DialogueFile.parse("~ start\nIreena [sad]: My father is three days dead. The mist presses against the windows, and I fear what waits outside.\nPlayer: We will help you. Tell us what happened.\nNarrator: She turns toward the fire, searching for the words.\n-> END\n", "capture/mobile_busts"))
	var state := StoryState.new()
	state.party.append(Pregens.build("godrick_pendlebrook", 3))
	var dialogue := DialogueUI.new()
	add_child(dialogue)
	dialogue.play(DialogueRunner.new(state, DiceRoller.new(2)), "capture/mobile_busts:start")
	for beat: String in ["npc", "party", "narrator"]:
		await tool.call("wait_frames", 12)
		tool.call("_shot", out + "_" + beat + ".png")
		if beat != "narrator":
			dialogue._advance()
	dialogue._show({"kind": "options", "options": [
		{"text": "Ask about her father and the village.", "label": "", "check": {}},
		{"text": "Offer to escort her to safety.", "label": "Persuasion", "check": {"who": "Godrick", "bonus": 5, "chance": 0.65}},
		{"text": "Leave and return when she is ready.", "label": "", "check": {}}]})
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_choices.png")
	dialogue.toggle_history()
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_history.png")
