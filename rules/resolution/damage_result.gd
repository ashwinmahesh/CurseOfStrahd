class_name DamageResult
extends RefCounted
## What happened when a creature took damage (2024 PHB "Damage and Healing"): Immunity, Resistance and
## Vulnerability, Temporary Hit Points absorbed, dropping to 0, instant death, death save failures and the
## Concentration save it forced.

var source: String = ""
var type: StringName = &""
var raw: int = 0
var final: int = 0
var absorbed_by_temp: int = 0
var hp_lost: int = 0
var notes: Array[String] = []
var critical: bool = false
var dropped_to_zero: bool = false
var died: bool = false
var instant_death: bool = false
var death_save_failures: int = 0
var concentration_dc: int = 0
var concentration_save: D20Test = null
var concentration_broken: bool = false


func describe(target_name: String = "") -> String:
	var who := target_name if target_name != "" else "Target"
	var text := "%s takes %d %s damage" % [who, final, str(type).capitalize()]
	if raw != final:
		text += " (%d before %s)" % [raw, ", ".join(notes)]
	if absorbed_by_temp > 0:
		text += ", %d absorbed by Temporary Hit Points" % absorbed_by_temp
	if instant_death:
		text += ", and dies from massive damage"
	elif died:
		text += ", and dies"
	elif dropped_to_zero:
		text += ", and drops to 0 Hit Points"
	elif death_save_failures > 0:
		text += ", suffering %d Death Saving Throw failure%s" % [death_save_failures, "" if death_save_failures == 1 else "s"]
	if concentration_save != null:
		text += ". " + concentration_save.describe()
		if concentration_broken:
			text += ": Concentration lost"
	return text
