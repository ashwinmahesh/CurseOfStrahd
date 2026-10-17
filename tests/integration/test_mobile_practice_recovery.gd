extends TestCase

var previous: String


func before_each() -> void:
	previous = MobilePracticeRecovery.path
	MobilePracticeRecovery.path = "user://practice_recovery_test_%d.json" % OS.get_process_id()


func after_each() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(MobilePracticeRecovery.path + suffix)
	MobilePracticeRecovery.path = previous
	MobilePracticeRecovery.pending = {}


func test_practice_recovery_is_separate_from_campaign_and_finishes_durably() -> void:
	var campaign := GameState.to_dict()
	var slot := SaveSystem.current_slot
	var setup := SkirmishSetup.new()
	setup.add_hero(Pregens.build("godrick_pendlebrook", 5))
	setup.add_foe("zombie")
	var errors: Array[String] = []
	var e := setup.build(DiceRoller.new(56), errors)
	assert_true(errors.is_empty())
	var journal := CombatJournal.begin(e)
	journal.append(e, "start", {"surprised": []})
	assert_eq(MobilePracticeRecovery.write(journal, setup), OK)
	assert_true(MobilePracticeRecovery.request())
	var saved := MobilePracticeRecovery.take()
	assert_eq(str(saved["kind"]), "skirmish")
	assert_true(MobilePracticeRecovery.take().is_empty())
	var copied := SkirmishSetup.from_dict(saved["setup"] as Dictionary)
	assert_eq(copied.party.size(), 1)
	assert_eq(copied.foes.size(), 1)
	var continuation := CombatJournal.new()
	continuation.data = saved["journal"]
	var restored := continuation.restore(DiceRoller.new(2))
	assert_eq(restored.state, Encounter.State.ACTIVE)
	assert_eq(SaveSystem.current_slot, slot)
	assert_eq(GameState.story.to_dict(), campaign["story"])
	assert_eq(MobilePracticeRecovery.finish(), OK)
	assert_true(MobilePracticeRecovery.read().is_empty())
	assert_false(MobilePracticeRecovery.request())
	if restored.pending != null:
		restored.pending.continuation = Callable()
		restored.pending = null
