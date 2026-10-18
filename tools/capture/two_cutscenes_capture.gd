extends Node
## The Tome of Strahd's reading and Escher's mirror for captures (docs/ui/cutscenes.md, owner's todo 2026-10-18), each
## before and after: the Tome read through from the inventory (before: its text card and nothing else, with the pictures
## held back; after: the four pictures with their captions, the longest one, and the world when they close) and Escher's
## first meeting (before: the conversation with no picture; after: the tall mirror behind him showing the empty chair).
## make capture SCENE=res://tools/capture/two_cutscenes_capture.tscn NAME=two-cutscenes FRAMES=30 [ARGS="--size=1512x982"]

const TOME_SHOTS: Array[String] = ["tome_conqueror", "tome_brothers", "tome_wedding", "tome_wall"]

var root: Node


func _ready() -> void:
	GameState.reset()
	for id: String in ["silvain_aster", "ilse_varga", "liriel_dawnsong", "hedda_ironvow"]:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.party[0].add_item("tome_of_strahd")
	GameState.story.location = "village_of_barovia"
	for c in Cutscenes.all():   # no arrival picture in the way
		if not str(c["id"]) in TOME_SHOTS and str(c["id"]) != "escher_mirror":
			Cutscenes.mark_played(str(c["id"]), GameState.story)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _shoot(tool: Node, path: String, frames: int = 12) -> void:
	await tool.call("wait_frames", frames)
	tool.call("_shot", path)


## Holds a cutscene's pictures back (every take needs a flag nobody sets), so the scene plays as it did before.
func _hold_back(id: String) -> Dictionary:
	var c := Cutscenes.get_cutscene(id)
	var saved := (c["images"] as Array).duplicate(true)
	for take: Variant in c["images"]:
		(take as Dictionary)["when"] = "flag.capture_never_set"
	return {"id": id, "images": saved}


func _release(held: Dictionary) -> void:
	Cutscenes.get_cutscene(str(held["id"]))["images"] = held["images"]


func _read_tome(tool: Node, out: String, shot_name: String) -> void:
	root.call("open_screen", "inventory", 0)
	await tool.call("wait_frames", 6)
	var inv := root.get("screen") as InventoryScreen
	inv.selected = "tome_of_strahd"
	inv._draw()
	await _shoot(tool, "%s_%s_inventory.png" % [out, shot_name])
	inv._use_power("read", {})
	await tool.call("wait_frames", 150)   # "3 hours later" fades over it first (GameRoot._on_time_passed, about 2 s)


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 20)
	UiMotion.reduced = true
	(root.get("hud") as ExploreHud).close_narration()
	var st := GameState.story
	# --- The Tome: before (the reading's card, no pictures) ---
	var held := _hold_back("tome_conqueror")
	await _read_tome(tool, out, "tome_before")
	await _shoot(tool, "%s_tome_before_read.png" % out, 4)
	_release(held)
	root.call("close_screen")
	st.codex.erase("tome_of_strahd")
	st.flags.erase("tome_of_strahd_read")
	st.flags.erase("strahd_knows_tome_read")
	await tool.call("wait_frames", 6)
	# --- The Tome: after (four pictures, three captions each) ---
	await _read_tome(tool, out, "tome_after")
	var player := root.get("screen") as CutscenePlayer
	var n := 0
	while player != null and not player.done and root.get("screen") == player:
		var long_one := player.scene_id == "tome_wedding" and player.index == 1
		if player.index == 0 or long_one:
			n += 1
			await _shoot(tool, "%s_tome_after_%d_%s_%d.png" % [out, n, player.scene_id, player.index + 1], 14)
		player.advance()
		await tool.call("wait_frames", 3)
	await _shoot(tool, "%s_tome_after_world.png" % out, 70)   # the reading's own words, after the weather's
	# --- Escher: before (no picture) and after ---
	var held_mirror := _hold_back("escher_mirror")
	root.call("start_dialogue", "castle_ravenloft/spires_escher:start", "escher")
	await _escher_shot(tool, out + "_escher_before.png")
	_release(held_mirror)
	st.flags.erase("escher_met")
	root.call("start_dialogue", "castle_ravenloft/spires_escher:start", "escher")
	await _escher_shot(tool, out + "_escher_after.png")


## The first line of the conversation: its picture (if any) under the Narrator's line.
func _escher_shot(tool: Node, path: String) -> void:
	var d := root.get("dialogue") as DialogueUI
	await _shoot(tool, path, 40)
	d.queue_free()
	root.set("dialogue", null)
	(root.get("hud") as ExploreHud).visible = true
	await tool.call("wait_frames", 6)
