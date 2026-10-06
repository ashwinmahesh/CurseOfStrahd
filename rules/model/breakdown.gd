class_name Breakdown
extends RefCounted
## A number together with where every part of it came from, so the UI can explain it
## (plan §5.6 "Every number explains itself"): "AC 17 = Chain Mail 16 + Defense 1".

var label: String
## {label: String, value: int}. Order is display order.
var parts: Array[Dictionary] = []
## Qualifiers that aren't numbers, e.g. "Advantage (Remarkable Athlete)", "Disadvantage (Chain Mail)".
var notes: Array[String] = []
## A floor the total can't go below (Barkskin), with its source.
var floor_value: int = -1000000
var floor_label: String = ""
## A value that replaces the sum entirely (Speed 0 while Grappled), with its source.
var override_value: int = -1000000
var override_label: String = ""


func _init(label_: String = "") -> void:
	label = label_


func add(part_label: String, value: int) -> Breakdown:
	parts.append({"label": part_label, "value": value})
	return self


func add_nonzero(part_label: String, value: int) -> Breakdown:
	if value != 0:
		add(part_label, value)
	return self


func note(text: String) -> Breakdown:
	if not text in notes:
		notes.append(text)
	return self


func set_floor(value: int, source: String) -> void:
	if value > floor_value:
		floor_value = value
		floor_label = source


func set_override(value: int, source: String) -> void:
	override_value = value
	override_label = source


func sum() -> int:
	var t := 0
	for p in parts:
		t += int(p["value"])
	return t


func total() -> int:
	if override_value != -1000000:
		return override_value
	return maxi(sum(), floor_value)


func value_of(part_label: String) -> int:
	var t := 0
	for p in parts:
		if str(p["label"]) == part_label:
			t += int(p["value"])
	return t


func has_part(part_label: String) -> bool:
	for p in parts:
		if str(p["label"]) == part_label:
			return true
	return false


## "AC 17 = Chain Mail 16 + Defense 1". Signed parts after the first; floors and overrides explained.
func describe() -> String:
	var text := "%s %d" % [label, total()] if label != "" else str(total())
	if override_value != -1000000:
		return "%s (%s)" % [text, override_label]
	var terms: Array[String] = []
	for i in parts.size():
		var p := parts[i]
		var v := int(p["value"])
		if i == 0:
			terms.append("%s %d" % [p["label"], v])
		else:
			terms.append("%s %s %d" % ["+" if v >= 0 else "-", p["label"], absi(v)])
	if not terms.is_empty():
		text += " = " + " ".join(terms)
	if floor_value > sum():
		text += " (raised to %d by %s)" % [floor_value, floor_label]
	if not notes.is_empty():
		text += "; " + ", ".join(notes)
	return text


## Signed short form for bonuses: "+5".
func signed() -> String:
	var t := total()
	return ("+%d" % t) if t >= 0 else str(t)
