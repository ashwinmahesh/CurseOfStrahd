class_name MobilePracticeRecovery
extends RefCounted
## Practice battles have their own continuation file, never a campaign or Honour save slot.

static var path := "user://mobile_practice_recovery.json"
static var pending: Dictionary = {}


static func read() -> Dictionary:
	var data := AtomicJson.read(path)
	if int(data.get("version", 0)) != 1 or not CombatJournal.valid(data.get("journal")):
		return {}
	if str(data.get("kind", "")) not in ["arena", "skirmish"] or not data.get("setup") is Dictionary:
		return {}
	return data


static func write(journal: CombatJournal, setup: SkirmishSetup) -> Error:
	return AtomicJson.write(path, {"version": 1, "kind": "skirmish" if setup != null else "arena",
		"setup": setup.to_dict() if setup != null else {}, "journal": journal.data})


static func request() -> bool:
	pending = read()
	return not pending.is_empty()


static func take() -> Dictionary:
	var saved := pending
	pending = {}
	return saved


static func finish() -> Error:
	# A durable completion marker prevents an old backup being offered after a normal finish.
	return AtomicJson.write(path, {"version": 1, "completed": true})
