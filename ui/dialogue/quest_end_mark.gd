class_name QuestEndMark
extends Control
## The broken seal on a dialogue option that closes a quest (`[ends:<quest>]`, docs/contracts/dialogue.md): a ring of wax
## in the journal's Failed rose with a crack through it. Drawn in code, so it needs no art; DialogueUI hangs one at the
## right edge of such an option and says "Ends <quest>" in its tooltip and under the menu.

const SIZE := 18.0


func _init() -> void:
	name = "EndsMark"
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Pinned to the middle of the button's right edge.
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -SIZE - 8.0
	offset_right = -8.0
	offset_top = -SIZE / 2.0
	offset_bottom = SIZE / 2.0


func _draw() -> void:
	var rose := Look.color("rose")
	var c := Vector2(SIZE, SIZE) / 2.0
	var r := SIZE / 2.0 - 2.0
	draw_arc(c, r, 0.0, TAU, 24, rose, 2.0, true)
	draw_circle(c, r - 3.0, Color(rose, 0.25))
	# The crack, a zigzag from the top of the seal to its lower edge, drawn over the wax in the dark.
	var crack := PackedVector2Array([c + Vector2(1.5, -r), c + Vector2(-1.5, -r * 0.4), c + Vector2(2.0, 0.0),
		c + Vector2(-1.0, r * 0.45), c + Vector2(1.0, r)])
	draw_polyline(crack, Look.color("void"), 3.0, true)
	draw_polyline(crack, rose, 1.2, true)
