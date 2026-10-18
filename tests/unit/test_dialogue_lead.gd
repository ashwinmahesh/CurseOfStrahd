extends TestCase
## The `lead <npc> to <where>` statement (docs/contracts/dialogue.md, docs/story/leads_and_guests.md): how it parses, that
## the game's conversations stop at it while bots and tools without a map count it as followed, that it keeps check.last
## honest, and that every lead the story has names a real person and a real place.

const FIXTURE := """
~ start
Ismark: Follow me.
lead ismark to well
if check.last
set followed
else
set stayed
endif
-> END

~ square
lead ismark to 10,27
-> END

~ elsewhere
lead ismark to test_lead_b:far
-> END
"""


func before_each() -> void:
	var f := DialogueFile.parse(FIXTURE, "test/lead_unit")
	assert_true(f.errors.is_empty(), str(f.errors))
	DialogueFile.register(f)


func _story() -> StoryState:
	var st := StoryState.new()
	st.party.append(TestChars.pregen("hedda_ironvow", 1))
	return st


## Every narrative file's key ("village_of_barovia/ismark").
func _keys(sub: String = "") -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(DialogueFile.ROOT + sub)
	if d == null:
		return out
	for dir in d.get_directories():
		out.append_array(_keys(sub + dir + "/"))
	for f in d.get_files():
		if f.ends_with(".dialogue"):
			out.append(sub + f.get_basename())
	return out


func test_it_parses_a_spot_a_square_and_a_place() -> void:
	var f := DialogueFile.load_key("test/lead_unit")
	var lead_of := func(node: String) -> Dictionary:
		for s: Dictionary in f.nodes[node]:
			if str(s["t"]) == "lead":
				return s
		return {}
	assert_eq(str((lead_of.call("start") as Dictionary).get("to", "")), "well")
	assert_eq(str((lead_of.call("start") as Dictionary).get("npc", "")), "ismark")
	assert_eq(str((lead_of.call("square") as Dictionary).get("to", "")), "10,27")
	assert_eq(str((lead_of.call("elsewhere") as Dictionary).get("to", "")), "test_lead_b:far")


func test_without_a_map_the_party_just_went() -> void:
	var st := _story()
	st.last_check = false
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start("test/lead_unit:start"))
	var kinds: Array[String] = []
	for i in 10:
		var b := r.next()
		kinds.append(str(b["kind"]))
		if str(b["kind"]) == "end":
			break
	assert_false("lead" in kinds, "no lead beat for a runner with no map")
	assert_true(bool(st.get_flag("followed", false)), "the branch for a party that went")
	assert_false(bool(st.get_flag("stayed", false)))


func test_the_game_stops_at_a_lead_and_check_last_follows_the_answer() -> void:
	for went: bool in [true, false]:
		var st := _story()
		var r := DialogueRunner.new(st, DiceRoller.new(1))
		r.offer_leads = true
		assert_true(r.start("test/lead_unit:start"))
		var b := r.next()   # Ismark's line
		assert_eq(str(b["kind"]), "line")
		b = r.next()
		assert_eq(str(b["kind"]), "lead", "the conversation stops for the walk")
		assert_eq(str(b["npc"]), "ismark")
		assert_eq(str(b["to"]), "well")
		st.last_check = went   # what the game root does once the walk (or the refusal) is over
		var end := r.next()
		assert_eq(str(end["kind"]), "end")
		assert_eq(bool(st.get_flag("followed", false)), went)
		assert_eq(bool(st.get_flag("stayed", false)), not went)


func test_every_lead_in_the_story_names_a_real_person_and_place() -> void:
	var seen := 0
	for key in _keys():
		var f := DialogueFile.load_key(key)
		if f == null:
			continue
		for node: String in f.nodes:
			for s: Dictionary in f.nodes[node]:
				if str(s["t"]) != "lead":
					continue
				seen += 1
				var where := "%s:%s" % [key, node]
				assert_true(Compendium.shared().has("npcs", str(s["npc"])), "%s: %s is no one" % [where, s["npc"]])
				var to := str(s["to"])
				var place := to.get_slice(":", 0)
				var ok := to.contains(",") or Compendium.shared().has("locations", place)
				if not ok:
					for loc_id: String in (Compendium.shared().tables["locations"] as Dictionary):
						var loc := Compendium.shared().get_entry("locations", loc_id)
						for list: String in ["doors", "props", "containers", "exits", "areas"]:
							for t: Variant in loc.get(list, []):
								if str((t as Dictionary).get("id", "")) == to:
									ok = true
				assert_true(ok, "%s: `lead %s to %s` names no place" % [where, s["npc"], to])
	assert_true(seen >= 5, "the story's leads (Adrian, Lupu, Parriwimple, Zuleika, Bluto) are all there: %d" % seen)
