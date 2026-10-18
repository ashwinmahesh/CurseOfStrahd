extends TestCase
## The sarcophagi call to the party (Amber Temple Look Plan 6b): each vestige's prop has an `approach` and a `call`, and
## speaks first, once, as the leader comes within three squares and can see it, before anyone touches the amber. Not once
## the temple is sealed, the talk was had or its gift is taken. The first call of the game says how the voices reach
## them. The lines are one or two short sentences with no pitch (docs/story/drafts/amber-calls/).

const PLACES := ["amber_temple_faceless_god", "amber_temple_vault"]


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func _view(loc_id: String) -> LocationView:
	var v := LocationView.create(loc_id, GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


## Every beat of a dialogue node played straight through (these nodes have no menu).
func _play(st: StoryState, ref: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r := DialogueRunner.new(st, DiceRoller.new(3))
	assert_true(r.start(ref), "starts " + ref)
	var b := r.next()
	for i in 20:
		out.append(b)
		if str(b["kind"]) == "end":
			break
		b = r.next()
	return out


## The lines (with who speaks them) a call plays.
func _lines(beats: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b: Dictionary in beats:
		if str(b["kind"]) == "line":
			out.append(b)
	return out


func _vestige_props(loc_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Variant in (Compendium.shared().get_entry("locations", loc_id) as Dictionary).get("props", []):
		if str((p as Dictionary)["id"]).begins_with("sarc_") and str((p as Dictionary).get("dialogue", "")).begins_with("amber_temple/vestiges:"):
			out.append(p as Dictionary)
	return out


## All sixteen props call, from three squares, only while the temple is open and the talk is still to come.
func test_every_vestige_calls_from_its_prop() -> void:
	var count := 0
	for loc_id: String in PLACES:
		for p in _vestige_props(loc_id):
			var id := str(p["id"]).trim_prefix("sarc_")
			count += 1
			assert_eq(int(p.get("approach", 0)), 3, "%s calls from three squares" % id)
			assert_eq(str(p.get("call", "")), "amber_temple/vestiges:%s_call" % id, "%s's call is its own node" % id)
			var when := str(p.get("call_when", ""))
			assert_true("flag.amber_temple_sealed" in when and ("flag.vestige_%s_heard" % id) in when and ("gift:gift_of_%s" % id) in when,
				"%s calls only while the temple is open, unheard, and its gift untaken" % id)
	assert_eq(count, 16, "the ring has six and the hall of vestiges ten")


## One or two short sentences, in the vestige's own voice, no pitch and no game words.
func test_the_calls_are_short_and_make_no_pitch() -> void:
	var st := GameState.story
	for loc_id: String in PLACES:
		for p in _vestige_props(loc_id):
			var id := str(p["id"]).trim_prefix("sarc_")
			var lines := _lines(_play(st, str(p["call"])))
			var spoken := lines.filter(func(b: Dictionary) -> bool: return str(b["speaker_id"]) == "vestige_" + id)
			assert_eq(spoken.size(), 1, "%s speaks one call" % id)
			if spoken.is_empty():
				continue
			var text := str((spoken[0] as Dictionary)["text"])
			assert_true(text.split(" ", false).size() <= 28, "%s's call is at most 28 words (%d)" % [id, text.split(" ", false).size()])
			assert_false("—" in text, "%s's call has no em-dash" % id)
			for word: String in ["gift", "offer", "price", "level", "save", "check"]:
				assert_false(text.to_lower().contains(word), "%s's call doesn't say %s" % [id, word])
			st.flags.erase("amber_calls_begun")


## The first call of the game says how the voices reach the party, once; the next ones are only the voice.
func test_the_first_call_says_how_the_voices_reach_them() -> void:
	var st := GameState.story
	var first := _lines(_play(st, "amber_temple/vestiges:zantras_call"))
	assert_eq(first.size(), 2, "the first call has the Narrator's line and the voice")
	assert_eq(str((first[0] as Dictionary)["speaker_id"]), "narrator", "the Narrator first")
	assert_eq(str((first[1] as Dictionary)["speaker_id"]), "vestige_zantras", "then the voice")
	assert_true(bool(st.get_flag("amber_calls_begun", false)), "and it is said once")
	var second := _lines(_play(st, "amber_temple/vestiges:fekre_call"))
	assert_eq(second.size(), 1, "the next call is only the voice")
	assert_eq(str((second[0] as Dictionary)["speaker_id"]), "vestige_fekre", "Fekre's")


## A call fires once when the leader is within three squares and sees the block; the block is the one the talk is about.
func test_a_call_fires_once_as_the_party_comes_near() -> void:
	var v := _view("amber_temple_faceless_god")
	await get_tree().process_frame
	var asked: Array[String] = []
	v.dialogue_requested.connect(func(ref: String, _npc: String) -> void: asked.append(ref))
	var zantras := Vector2i(33, 6)
	v.leader().cell = zantras + Vector2i(0, 8)
	assert_false(LocationNpcs._check_calls(v), "far off, nothing calls")
	v.leader().cell = zantras + Vector2i(0, 3)
	assert_true(LocationNpcs._check_calls(v), "three squares off, Zantras calls")
	assert_eq(asked, ["amber_temple/vestiges:zantras_call"] as Array[String], "its own node")
	assert_eq(v.dialogue_prop, "sarc_zantras", "the talk is about its block (the amber flares, the camera leans)")
	assert_false(LocationNpcs._check_calls(v), "and only once")
	var props := GameState.story.loc_state(v.loc_id)["props"] as Dictionary
	assert_true(bool(props.get("call:sarc_zantras", false)), "kept in the place's own save")
	v.queue_free()


## The leader at `cell` in the ring of amber, with `setup` done first: did a call start, and whose?
func _call_at(cell: Vector2i, setup: Callable = Callable()) -> String:
	before_each()   # a game of its own each time
	if setup.is_valid():
		setup.call()
	var v := _view("amber_temple_faceless_god")
	var asked: Array[String] = []
	v.dialogue_requested.connect(func(ref: String, _npc: String) -> void: asked.append(ref))
	v.leader().cell = cell
	LocationNpcs._check_calls(v)
	v.queue_free()
	return asked[0] if not asked.is_empty() else ""


## No call once its talk was had, its gift is taken, or the temple is sealed (each with the call it would be without).
func test_no_call_once_heard_gifted_or_sealed() -> void:
	await get_tree().process_frame
	assert_eq(_call_at(Vector2i(38, 6)), "amber_temple/vestiges:fekre_call", "Fekre calls to a party beside it")
	assert_eq(_call_at(Vector2i(38, 6), func() -> void: GameState.story.set_flag("vestige_fekre_heard")), "",
		"not once Fekre was talked to")
	assert_eq(_call_at(Vector2i(38, 13)), "amber_temple/vestiges:taar_haak_call", "Taar Haak calls to a party three squares off")
	assert_eq(_call_at(Vector2i(38, 13), func() -> void: GameState.story.party[0].accept_dark_gift("gift_of_taar_haak")), "",
		"not once its gift is taken")
	assert_eq(_call_at(Vector2i(38, 15)), "amber_temple/vestiges:shami_amourae_call", "Shami-Amourae calls to a party three squares off")
	assert_eq(_call_at(Vector2i(38, 15), func() -> void: GameState.story.set_flag("amber_temple_sealed")), "",
		"not once the temple is sealed")
	assert_eq(_call_at(Vector2i(35, 14)), "", "and a party that is not near any block hears nothing")


## Walking is what starts it: the step's cell events (LocationWalk) ask the props as they ask the people.
func test_a_step_near_a_block_starts_its_call() -> void:
	var v := _view("amber_temple_faceless_god")
	await get_tree().process_frame
	var asked: Array[String] = []
	v.dialogue_requested.connect(func(ref: String, _npc: String) -> void: asked.append(ref))
	v.leader().cell = Vector2i(33, 9)   # three squares south of Zantras (33,6)
	LocationWalk._check_cell_events(v)   # (stepping into the ring says its name first)
	v.leader().cell = Vector2i(33, 9)
	assert_true(LocationWalk._check_cell_events(v), "the step stops the walk for the call")
	assert_eq(asked, ["amber_temple/vestiges:zantras_call"] as Array[String], "it is Zantras's")
	assert_eq(v.dialogue_prop, "sarc_zantras", "about its block")
	v.queue_free()
