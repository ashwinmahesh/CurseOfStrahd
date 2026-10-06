class_name LayerFade
extends RefCounted
## Fades everything on a CanvasLayer in or out, since a CanvasLayer has no modulate of its own: the exploring and
## combat HUDs crossfade when a fight starts and ends instead of snapping (owner 2026-10-06). It fades the layer's
## direct children that are showing at full opacity; one that keeps its own alpha (a banner mid-fade) is left alone.


## Fades `layer` in (`show`) or out over `seconds` after `delay`, on a tween bound to `host` so it stops with it.
## Fading in shows the layer first; fading out hides it at the end and puts its children back at full opacity, so a
## later plain `visible = true` shows it whole. A new fade on the same layer replaces one still running.
static func fade(host: Node, layer: CanvasLayer, show: bool, seconds: float, delay: float = 0.0) -> Tween:
	_settle(layer)
	var items: Array[CanvasItem] = []
	for ch: Node in layer.get_children():
		var ci := ch as CanvasItem
		if ci != null and ci.visible and is_equal_approx(ci.modulate.a, 1.0):
			items.append(ci)
	if show:
		layer.visible = true
	var tw := host.create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	for ci in items:
		if show:
			ci.modulate.a = 0.0
		tw.tween_property(ci, "modulate:a", 1.0 if show else 0.0, seconds).set_delay(delay)
	if items.is_empty():
		tw.tween_interval(seconds + delay)
	tw.chain().tween_callback(func() -> void:
		if not show:
			layer.visible = false
		for ci in items:
			if is_instance_valid(ci):
				ci.modulate.a = 1.0
		layer.remove_meta(&"layer_fade"))
	layer.set_meta(&"layer_fade", {"tween": tw, "items": items})
	return tw


## Stops a fade still running on `layer`, leaving its children at full opacity.
static func _settle(layer: CanvasLayer) -> void:
	if not layer.has_meta(&"layer_fade"):
		return
	var running := layer.get_meta(&"layer_fade") as Dictionary
	var tw := running["tween"] as Tween
	if tw != null and tw.is_valid():
		tw.kill()
	for ci: CanvasItem in running["items"]:
		if is_instance_valid(ci):
			ci.modulate.a = 1.0
	layer.remove_meta(&"layer_fade")
