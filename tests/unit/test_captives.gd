extends TestCase
## Spare or capture (F13): a broken side's Bloodied talkers surrender (combat/ai/ai_tactics.gd), the fight ends when
## every foe is down, fled or surrendered, and the captives are dealt with in a conversation after it
## (story/captives.gd, narrative/captives/).

var _encounters: Array[Encounter] = []


## Four `monster`s against Ilse, two of them already dead and the first Bloodied: [first, second].
func _broken(monster: String, mode: String = "balanced") -> Array[Combatant]:
	var e := TestCombat.encounter(["........................", "........................", "........................"], 4)
	TestCombat.hero(e, "ilse_varga", Vector2i(1, 1))
	var out: Array[Combatant] = []
	for i in 4:
		out.append(TestCombat.foe(e, monster, Vector2i(6 + i, 1)))
	_encounters.append(e)
	Difficulty.named(mode).arm(e)
	TestCombat.start_with(e, out[0])
	for dead: Combatant in [out[2], out[3]]:
		dead.creature.hp = 0
		dead.creature.dead = true
	out[0].creature.hp = out[0].creature.max_hp() / 2 - 1
	return out


func _enc(c: Combatant) -> Encounter:
	for e in _encounters:
		if c in e.combatants:
			return e
	return null


func test_a_bloodied_bandit_whose_side_broke_surrenders() -> void:
	var f := _broken("bandit")
	var e := _enc(f[0])
	e.run_ai_turn()
	assert_eq(str(e.ai.last_plan.get("kind", "")), "surrender")
	assert_true(f[0].creature.has_flag("surrendered"))
	assert_false(f[0].can_act(), "it stops fighting")
	assert_eq(f[0].speed(), 0, "and can't move")
	assert_true(e.log.texts().any(func(t: String) -> bool: return "surrenders" in t))
	assert_eq(e.state, Encounter.State.ACTIVE, "one bandit still fights")


func test_only_talkers_surrender() -> void:
	for id: String in ["wolf", "zombie", "vampire_spawn"]:
		var f := _broken(id)
		_enc(f[0]).run_ai_turn()
		assert_false(f[0].creature.has_flag("surrendered"), "%s doesn't surrender" % id)
	assert_true(AiTactics.can_surrender(TestCombat.foe(TestCombat.open_field(), "cultist", Vector2i.ZERO)))
	assert_false(AiTactics.can_surrender(TestCombat.foe(TestCombat.open_field(), "izek_strazni", Vector2i.ZERO)), "a boss fights on")
	var ruxandra := TestCombat.monster("druid")
	ruxandra.name = "Mother Ruxandra"
	assert_false(AiTactics.can_surrender(TestCombat.open_field().add(ruxandra, &"enemy", Vector2i.ZERO)), "a named story character's fate is the story's")
	assert_true(AiTactics.can_surrender(TestCombat.foe(TestCombat.open_field(), "druid", Vector2i.ZERO)), "a druid of her circle can give up")


func test_a_whole_side_giving_up_ends_the_fight() -> void:
	var f := _broken("bandit")
	var e := _enc(f[0])
	AiTactics.surrender(e, f[1])
	assert_eq(e.state, Encounter.State.ACTIVE)
	e.run_ai_turn()
	assert_eq(e.state, Encounter.State.OVER, "the last one surrendered")
	assert_eq(e.outcome, "victory")
	var taken := Captives.taken(e)
	assert_eq(taken.size(), 2)
	assert_eq(Captives.conversation(taken, "road_ambush"), "captives/plain:start", "bandits on a road: the plain talk")
	assert_eq(Captives.conversation(taken, "tser_pool_brawl"), "captives/vistani:start", "the Tser Pool fight has its own")


func test_the_conversation_follows_the_leading_captive() -> void:
	var f := _broken("mongrelfolk")
	var e := _enc(f[0])
	AiTactics.surrender(e, f[1])
	AiTactics.surrender(e, f[0])
	assert_eq(Captives.conversation(Captives.taken(e), "some_fight"), "captives/belview:start")
	assert_eq(Captives.conversation([], "tser_pool_brawl"), "", "no captives, no conversation")


func test_cutting_down_a_surrendered_foe_is_counted() -> void:
	var f := _broken("bandit")
	var e := _enc(f[0])
	AiTactics.surrender(e, f[0])
	f[0].creature.take_damage(100, &"slashing")
	assert_eq(Captives.slain_after_surrender(e), 1)
	e.outcome = "victory"
	assert_true(Captives.taken(e).is_empty(), "the dead aren't captives")


func test_each_fights_captives_get_fresh_checks() -> void:
	var st := StoryState.new()
	st.flags["_failed/captives/plain:choose:Promise them their lives for the truth."] = true
	st.flags["_failed/vallaki/baron:start:Flatter him."] = true
	Captives.forget_spent(st)
	assert_false(st.flags.has("_failed/captives/plain:choose:Promise them their lives for the truth."))
	assert_true(st.flags.has("_failed/vallaki/baron:start:Flatter him."), "other conversations keep theirs")


## Plays `ref` choosing the option whose text starts with `pick` at every menu.
func _talk(st: StoryState, ref: String, pick: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r := DialogueRunner.new(st, DiceRoller.new(3))
	assert_true(r.start(ref), "starts " + ref)
	var b := r.next()
	for i in 60:
		out.append(b)
		if str(b["kind"]) == "end":
			break
		if str(b["kind"]) == "options":
			var opts := b["options"] as Array
			var at := 0
			for j in opts.size():
				if str((opts[j] as Dictionary)["text"]).begins_with(pick):
					at = j
			b = r.choose(at)
		else:
			b = r.next()
	return out


func test_every_captive_conversation_lets_them_go_or_kills_them() -> void:
	for kind: String in ["plain", "vistani", "wachter", "vallaki_watch", "wardens", "belview"]:
		for pick: String in ["Let them go.", "Kill them."]:
			var st := StoryState.new()
			st.party.append(Pregens.build("godrick_pendlebrook", 3))
			var beats := _talk(st, "captives/%s:start" % kind, pick)
			assert_eq(str(beats[-1]["kind"]), "end", "%s ends after %s" % [kind, pick])
			var score := Approval.score(st, "godrick_pendlebrook")
			if pick == "Kill them.":
				assert_true(score < 0, "%s: Godrick hates a killed prisoner (%d)" % [kind, score])
			else:
				assert_true(score >= 0, "%s: letting them go never costs Godrick's regard (%d)" % [kind, score])


func test_the_watch_pays_for_prisoners_in_vallaki() -> void:
	var st := StoryState.new()
	st.party.append(Pregens.build("kip_smudgewick", 3))
	st.location = "vallaki"
	_talk(st, "captives/wachter:start", "Hand them to the Baron's watch.")
	assert_eq(st.gold, 15.0)
	var away := StoryState.new()
	away.party.append(Pregens.build("kip_smudgewick", 3))
	away.location = "tser_pool"
	var beats := _talk(away, "captives/plain:start", "Hand them")
	assert_eq(away.gold, 0.0, "no watch to hand them to on the road")
	assert_eq(str(beats[-1]["kind"]), "end")
