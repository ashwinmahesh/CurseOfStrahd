extends Node
## Guidance offered before a skill check (ui/common/guidance_prompt.gd) for captures, in the Village of Barovia: the
## prompt over a conversation's Persuasion check (Liriel keeping Bless, which it would end), the check rolled with
## Hedda's d4 on the big d20, and the prompt over the place before a Search.
## make capture SCENE=res://tools/capture/guidance_capture.tscn NAME=guidance FRAMES=30

const DIALOGUE := """
~ start
Ismark: The gate guard won't let us through without the burgomaster's word.
* [Persuasion DC 14] We carry Ismark's word. Open the gate. -> yes | yes
* Leave. -> END

~ yes
Ismark: Then let us see what he says.
-> END
"""

var root: Node


func _ready() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "hedda_ironvow", "liriel_dawnsong", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	var liriel := GameState.story.party[2]
	liriel.begin_concentration("bless", "Bless")
	GameState.story.location = "village_of_barovia"
	for c in Cutscenes.all():   # no arrival picture in the way
		Cutscenes.mark_played(str(c["id"]), GameState.story)
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "capture/guidance"))
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _shoot(tool: Node, path: String, frames: int = 10) -> void:
	await tool.call("wait_frames", frames)
	tool.call("_shot", path)


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 20)
	UiMotion.reduced = true
	var hud := root.get("hud") as ExploreHud
	hud.close_narration()
	root.call("start_dialogue", "capture/guidance:start", "")
	var d := root.get("dialogue") as DialogueUI
	for i in 6:
		if not d.options_shown.is_empty():
			break
		d.call("_advance")
		await tool.call("wait_frames", 2)
	d.call("_choose", 0)
	await _shoot(tool, out + "_1_conversation.png", 20)
	if d.guidance != null:
		d.guidance.choices[0].pressed.emit()
	await _shoot(tool, out + "_2_rolled.png", 50)
	d.queue_free()
	root.set("dialogue", null)
	hud.visible = true
	await tool.call("wait_frames", 6)
	(root.get("view") as LocationView).search()
	await _shoot(tool, out + "_3_search.png", 20)
	var p := root.get("guidance") as GuidancePrompt
	if p != null:
		p.decline_button.pressed.emit()
	await tool.call("wait_frames", 10)
