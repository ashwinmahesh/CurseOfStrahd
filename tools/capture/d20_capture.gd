extends Node
## The big d20 for captures (docs/ui/d20_roll.md), in the Village of Barovia: a conversation's Persuasion check that
## lands on 17, a natural 20 and a natural 1, a roll with Advantage, the panel show_roll puts up for an overworld check
## and a hero's saving throw, and the throw itself frame by frame (cropped to the panel: <out>_seq_NNN.png, 30 a second).
## make capture SCENE=res://tools/capture/d20_capture.tscn NAME=d20 FRAMES=30

const DIALOGUE := """
~ start
Ismark: The gate guard won't let us through without the burgomaster's word.
* [Persuasion DC 14] We carry Ismark's word. Open the gate. -> yes | yes
* Leave. -> END

~ yes
Ismark: Then let us see what he says.
-> END
"""

## The throw's frames: this part of the screen, this many a second, for this long.
const SEQ_RECT := Rect2i(360, 0, 880, 420)
const SEQ_FPS := 30
const SEQ_SECONDS := 2.2

var root: Node


func _ready() -> void:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "village_of_barovia"
	for c in Cutscenes.all():   # no arrival picture in the way
		Cutscenes.mark_played(str(c["id"]), GameState.story)
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "capture/d20"))
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _shoot(tool: Node, path: String, frames: int = 10) -> void:
	await tool.call("wait_frames", frames)
	tool.call("_shot", path)


## Opens the conversation, rolls its check on a die that shows `natural`, and returns the dialogue. The conversation
## opens without motion (its options come up at once); `moving` lets the die move.
func _check(tool: Node, natural: int, moving: bool = false) -> DialogueUI:
	UiMotion.reduced = true
	var hud := root.get("hud") as ExploreHud
	hud.close_narration()
	root.call("start_dialogue", "capture/d20:start", "")
	var d := root.get("dialogue") as DialogueUI
	for i in 6:
		if not d.options_shown.is_empty():
			break
		d.call("_advance")
		await tool.call("wait_frames", 2)
	Dice.reseed(TestChars.seed_for_d20(natural))
	UiMotion.reduced = not moving
	d.call("_choose", 0)
	return d


func _close(tool: Node, d: DialogueUI) -> void:
	d.queue_free()
	root.set("dialogue", null)
	(root.get("hud") as CanvasLayer).visible = true
	await tool.call("wait_frames", 4)


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 20)
	var d := await _check(tool, 17)
	await _shoot(tool, out + "_1_check.png", 40)
	await _close(tool, d)
	d = await _check(tool, 20)
	await _shoot(tool, out + "_2_natural_20.png", 40)
	await _close(tool, d)
	# From here the die moves, stepped by hand.
	UiMotion._checked = true
	UiMotion.reduced = false
	await _shown(tool, out + "_4_advantage.png", {"kind": "check", "natural": 15, "rolls": [6, 15], "total": 19, "target": 15,
		"success": true, "who": "Thistle", "label": "Sleight of Hand", "advantage": true,
		"parts": [{"label": "Dex modifier", "value": 3}, {"label": "Proficiency", "value": 2}, {"label": "Thieves' Tools", "value": -1}]})
	await _shown(tool, out + "_5_save.png", {"kind": "save", "natural": 12, "rolls": [12], "total": 15, "target": 15,
		"success": true, "who": "Liriel Dawnsong", "label": "Dexterity saving throw",
		"parts": [{"label": "Dex modifier", "value": 3}]})
	await _shown(tool, out + "_6_death_save.png", {"kind": "death_save", "natural": 20, "rolls": [20], "total": 20, "target": 10,
		"success": true, "critical": true, "who": "Godrick Pendlebrook", "label": "Death saving throw",
		"verdict": "Back on his feet"})
	# The throw, frame by frame, in a conversation.
	d = await _check(tool, 17, true)
	for i in 60:
		if d.d20 != null:
			break
		await tool.call("wait_frames", 1)
	for i in int(SEQ_SECONDS * SEQ_FPS):
		d.d20.seek(float(i) / SEQ_FPS)
		await tool.call("wait_frames", 2)
		var img := tool.get_viewport().get_texture().get_image()
		img.get_region(SEQ_RECT).save_png(out + "_seq_%03d.png" % i)
	await _close(tool, d)
	# Last: a failed check closes its option for good (the owner's rule), so the conversation can't roll it again.
	d = await _check(tool, 1)
	await _shoot(tool, out + "_3_natural_1.png", 40)
	await _close(tool, d)


## A roll through show_roll, at rest, shot.
func _shown(tool: Node, path: String, roll: Dictionary) -> void:
	UiMotion.reduced = false
	DiceRoll.show_roll(root, roll)
	var panel := root.find_child("DiceRoll", true, false) as DiceRoll
	panel.seek(2.4)
	await _shoot(tool, path, 12)
	panel.get_parent().queue_free()
	await tool.call("wait_frames", 3)
