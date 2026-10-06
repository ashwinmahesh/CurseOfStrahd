class_name ChoiceOption
extends RefCounted
## One option of a Choice. Unavailable options stay visible with the reason (plan §5.6 "Explain, don't
## hide"); legal but weak ones carry a soft warning and are never blocked.

var id: String
var label: String
var summary: String = ""
var legal: bool = true
## Why it can't be picked: "Requires Strength 13", "You already know this spell".
var reason: String = ""
## Soft warning: "You're already proficient in Athletics (Background: Soldier)".
var warning: String = ""
## A pick that has to stay for now (a swap chance's limit is used up); `reason` says why.
var locked: bool = false
var tags: Array[String] = []
var data: Dictionary = {}


static func make(id_: String, label_: String, summary_: String = "") -> ChoiceOption:
	var o := ChoiceOption.new()
	o.id = id_
	o.label = label_
	o.summary = summary_
	return o


func block(why: String) -> ChoiceOption:
	legal = false
	reason = why
	return self


func lock(why: String) -> ChoiceOption:
	locked = true
	reason = why
	return self


func warn(why: String) -> ChoiceOption:
	warning = why
	return self


func to_dict() -> Dictionary:
	return {"id": id, "label": label, "summary": summary, "legal": legal, "reason": reason, "warning": warning,
		"locked": locked}
