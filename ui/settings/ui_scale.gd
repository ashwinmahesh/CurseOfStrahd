class_name UiScale
extends RefCounted
## The interface and text sizes the player picks in Settings (Improvement Ideas U4: for a 1080p screen or the couch).
##
## Interface size is the window's content_scale_factor while a game is on screen, so the HUD, the combat HUD,
## conversations, the Narrator's box and rules cards all grow or shrink together, crisply, and every click still lands
## where it's drawn. A full screen (a framed screen, the pause menu) draws at its design size while it's open: those
## already fill the 1600x900 canvas, and a bigger interface shrinks the canvas by the same share, so they'd spill
## (tests/integration/test_layout.gd checks the play screen at the largest size). The title screen is never scaled.
##
## Text size grows the reading text where it wraps and scrolls: conversations, the Narrator's box and the journal.

static var _playing: Array[Node] = []
static var _full: Array[Node] = []


## While `node` is in the tree, the player's interface size applies (the game root).
static func playing(node: Node) -> void:
	_hold(_playing, node)


## While `layer` is in the tree, the interface draws at its design size (UiKit.screen_frame, the pause menu).
static func full_screen(layer: Node) -> void:
	_hold(_full, layer)


static func _hold(list: Array[Node], node: Node) -> void:
	if node in list:
		return
	list.append(node)
	node.tree_exiting.connect(func() -> void:
		list.erase(node)
		apply(), CONNECT_ONE_SHOT)
	apply()


## The interface's scale right now.
static func factor() -> float:
	return GameSettings.ui_scale() if not _playing.is_empty() and _full.is_empty() else 1.0


## Sets the window to factor() (after the player changes the size, or a screen opens or closes).
static func apply() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var f := factor()
	if not is_equal_approx(tree.root.content_scale_factor, f):
		tree.root.content_scale_factor = f


## A reading text's font size at the player's text size.
static func text(size: int) -> int:
	return roundi(size * GameSettings.text_scale())
