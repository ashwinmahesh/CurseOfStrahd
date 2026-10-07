extends TestCase
## A save made while the roster's heroes still borrowed other characters' art (owner report 2026-10-07: Kip shown as
## Gunther Arasek, Thistle as Mirabel) loads with each hero's current sprite and portrait, and nothing else about them
## changes (StoryState.current_look).


func _round_trip(st: StoryState) -> StoryState:
	return StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)


func _subclass(ch: Character) -> String:
	for lv: Variant in ch.build.get("levels", []) as Array:
		for k: String in ((lv as Dictionary).get("choices", {}) as Dictionary):
			if k.ends_with("_subclass"):
				return str(((lv as Dictionary)["choices"] as Dictionary)[k])
	return ""


func test_a_borrowed_look_in_an_old_save_gives_way_to_the_heros_own_art() -> void:
	var st := StoryState.new()
	var looks := {"kip_smudgewick": "gunther_arasek", "thistle": "mirabel", "godrick_pendlebrook": ""}
	for id: String in looks:
		var ch := Pregens.build(id, 4)
		if str(looks[id]) != "":
			ch.build["appearance"] = {"art": looks[id]}
		st.party.append(ch)
	st.bench.append(Pregens.build("liriel_dawnsong", 4))
	(st.bench[0] as Character).build["appearance"] = {"art": "hedda_ironvow"}
	var before := {}
	for ch in st.roster():
		before[ch.id] = [ch.character_level(), _subclass(ch), ch.hp]
	var loaded := _round_trip(st)
	for ch in loaded.roster():
		assert_eq(CombatToken.art_for(ch), ch.id, "%s wears its own sprite" % ch.name)
		assert_eq(DialogueRunner.portrait_of(ch), ch.id, "%s speaks with its own portrait" % ch.name)
		assert_eq([ch.character_level(), _subclass(ch), ch.hp], before[ch.id], "%s's build is as saved" % ch.name)


func test_a_custom_hero_keeps_the_look_the_player_made() -> void:
	var st := StoryState.new()
	var ch := Pregens.build("thistle", 1)
	ch.id = "hero"
	ch.build["appearance"] = HeroLook.default_appearance("female", "ranger")
	var app := (ch.build["appearance"] as Dictionary).duplicate(true)
	st.party.append(ch)
	var loaded := _round_trip(st)
	assert_eq((loaded.party[0] as Character).build["appearance"], app)
