class_name TouchOutline
extends Node
## Mobile tap acknowledgement, owned by the location/token so leaving the scene cleans it up.
## Each target has its own half-second deadline; tapping it again renews that deadline.

const DURATION := 0.5
var remaining := DURATION
var pieces: Array[Dictionary] = []


static func flash(target: Node3D, see_through: bool = false) -> void:
	if not MobileDevice.enabled() or not is_instance_valid(target) or not target.is_visible_in_tree():
		return
	var existing := target.get_node_or_null("TouchOutline") as TouchOutline
	if existing != null:
		existing.remaining = DURATION
		return
	var effect := TouchOutline.new()
	effect.name = "TouchOutline"
	effect.process_mode = Node.PROCESS_MODE_ALWAYS
	effect.pieces = FoundOutline.apply(target, see_through)
	target.add_child(effect)


static func at(view: LocationView, cell: Vector2i) -> void:
	if not MobileDevice.enabled() or view == null:
		return
	var thing := view.thing_at(cell)
	var party := view.members.any(func(member: Combatant) -> bool: return member.cell == cell)
	if thing.is_empty() and not party:
		return
	for entry: Array in view.call("_pickables"):
		if entry[1] as Vector2i == cell:
			var node := entry[0] as Node3D
			if node is CombatToken:
				var token := node as CombatToken
				node = token._lying if token._lying != null and token._lying.visible else token.body
			flash(node)
	if str(thing.get("kind", "")) == "trap":
		for node: Node3D in view.trap_marks.get(str(thing["id"]), []):
			flash(node)


func _process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0:
		FoundOutline.remove(pieces)
		queue_free()
	else:
		FoundOutline.refit(pieces)


func _exit_tree() -> void:
	FoundOutline.remove(pieces)
