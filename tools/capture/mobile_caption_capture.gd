extends Node
## Representative caption states, shared by approved offscreen captures and the native iOS gallery.


func capture_shots(tool: Node, out: String) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var view := CutsceneView.new()
	layer.add_child(view)
	view.show_image("res://art/ui/title_backdrop.png")
	view.show_caption(true)
	view.caption("Narrator", "Mist covers the road ahead. A distant bell breaks the silence.")
	await tool.call("wait_frames", 18)
	tool.call("_shot", out + "_short.png")
	view.caption("Ireena Kolyana", "Mist covers the road ahead. Behind the gates, a lonely village waits in the shadow of Castle Ravenloft. You hear a distant bell, and the slow creak of a sign over the inn door.")
	await tool.call("wait_frames", 18)
	tool.call("_shot", out + "_speaker.png")
	view.caption("Narrator", "A lantern sways beside the gate. Its light catches the wet stones, and for a moment you can see the road climbing toward the castle. ".repeat(12) + "At last, the gate opens.")
	await tool.call("wait_frames", 18)
	tool.call("_shot", out + "_long.png")
	if view._mobile_scroll != null:
		view._mobile_scroll.scroll_vertical = roundi(view._mobile_scroll.get_v_scroll_bar().max_value)
		await tool.call("wait_frames", 12)
		tool.call("_shot", out + "_scrolled.png")
	view.set_paused(true)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_paused.png")
	layer.queue_free()
