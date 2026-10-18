extends TestCase
## Found spellbooks hold spells a Wizard can learn (Ashwin, 2026-10-18: "If we find spellbooks as loot, they should
## always have spells wizards can learn", after a blank one in a warden's chest at the Amber Temple). Every book with
## `spells` lists only Wizard spells that are in play, levels 1 to 9, none twice, none above what a Wizard a couple of
## levels past the place can prepare; every spellbook the story hands out, and any random treasure can roll, has
## spells in it; and a Wizard copies them from the inventory (tests/integration/test_spellbook_copy.gd shows the card).


## A spellbook: anything listing `spells`, the PHB's blank Spellbook, and the magic items that are spellbooks. The Arcane
## Grimoires aren't: they are Wizards' Spellcasting Focuses (tests/integration/test_arcane_grimoire.gd).
func _is_spellbook(id: String) -> bool:
	var data := Compendium.shared().item_data(id)
	return data.has("spells") or id == "spellbook" or id.ends_with("_spellbook") or id == "tome_of_the_stilled_tongue"


## Why `id`'s spells aren't all learnable by a Wizard, or "".
func _problem(id: String, max_level: int = 9) -> String:
	var spells := Compendium.shared().item_data(id).get("spells", []) as Array
	if spells.is_empty():
		return "%s holds no spells" % id
	var seen := {}
	for sp: Variant in spells:
		var sid := str(sp)
		if seen.has(sid):
			return "%s lists %s twice" % [id, sid]
		seen[sid] = true
		var s := Compendium.shared().spell_data(sid)
		if s.is_empty() or not Compendium.playable(s):
			return "%s: %s isn't a spell in play" % [id, sid]
		if not "wizard" in (s.get("classes", []) as Array):
			return "%s: %s isn't a Wizard spell" % [id, sid]
		var lv := int(s.get("level", 0))
		if lv < 1 or lv > 9:
			return "%s: %s is level %d, which no Wizard copies into a book" % [id, sid, lv]
		if lv > max_level:
			return "%s: %s is level %d, beyond a Wizard's reach where it's found" % [id, sid, lv]
	return ""


## Every spellbook the story hands out: id -> the place's treasure level (0 for a gift, whose level isn't known here).
func _placed_books() -> Dictionary:
	var out := {}
	for loc: Dictionary in Compendium.shared().all("locations"):
		if str(loc["id"]).begins_with("test_"):
			continue
		var found := {}
		_walk(loc, found)
		for id: String in found:
			if _is_spellbook(id):
				out[id] = Treasure.level_for(str(loc["id"]))
	for path in _dialogues("res://narrative"):
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			var l := line.strip_edges()
			if l.begins_with("give ") and _is_spellbook(l.get_slice(" ", 1)):
				out[l.get_slice(" ", 1)] = int(out.get(l.get_slice(" ", 1), 0))
	return out


func _walk(v: Variant, out: Dictionary) -> void:
	if v is Dictionary:
		var d := v as Dictionary
		if d.get("item", null) is String:
			out[str(d["item"])] = true
		for k: Variant in d:
			if str(k) == "items" and d[k] is Array:
				for it: Variant in d[k]:
					if it is Dictionary:
						out[str((it as Dictionary).get("id", ""))] = true
			elif d[k] is Dictionary or d[k] is Array:
				_walk(d[k], out)
	elif v is Array:
		for e: Variant in v:
			_walk(e, out)


func _dialogues(dir: String) -> Array[String]:
	var out: Array[String] = []
	var da := DirAccess.open(dir)
	for f in da.get_files():
		if f.ends_with(".dialogue"):
			out.append(dir.path_join(f))
	for sub in da.get_directories():
		out.append_array(_dialogues(dir.path_join(sub)))
	return out


func test_every_book_with_spells_holds_spells_a_wizard_can_learn() -> void:
	var n := 0
	for folder: String in ["items", "magic_items"]:
		for d: Dictionary in Compendium.shared().all(folder):
			if d.has("spells"):
				n += 1
				assert_eq(_problem(str(d["id"])), "")
	assert_true(n >= 3, "the Dursts', the warden's and the Enduring Spellbook (%d)" % n)


func test_every_spellbook_found_as_loot_has_spells_for_its_place() -> void:
	var placed := _placed_books()
	for id: String in ["durst_spellbook", "amber_warden_spellbook"]:
		assert_true(placed.has(id), "%s is found somewhere" % id)
	assert_false(placed.has("arcane_grimoire_plus_2"), "Dobre's grimoire is a focus, not a spellbook")
	assert_false(placed.has("spellbook"), "no blank spellbook is loot (the Amber Temple warden's chest had one)")
	for id: String in placed:
		var lvl := int(placed[id])
		# A Wizard two levels past the place can prepare spells of level (L + 3) / 2, at most 9.
		assert_eq(_problem(id, clampi((lvl + 3) / 2, 1, 9) if lvl > 0 else 9), "")


func test_random_treasure_never_gives_an_empty_spellbook() -> void:
	Treasure.reset()
	for r: String in Treasure.pools():
		for th: String in Treasure.pools()[r]:
			for e: Dictionary in Treasure.pools()[r][th]:
				var id := str(e["id"])
				if id != "spell_scroll" and _is_spellbook(id):
					assert_eq(_problem(id), "", "%s can be rolled" % id)
	var rng := DiceRoller.new(17)
	for level: int in [1, 3, 5, 7, 9, 10]:
		for i in 80:
			for it: Dictionary in [Treasure.roll_item(rng, level), RoadSpoils.find(rng, level, i % 2 == 0)]:
				var id2 := str(it.get("id", ""))
				if id2 != "" and _is_spellbook(id2):
					assert_eq(_problem(id2), "", "a roll gave %s" % id2)


func test_a_wizard_copies_a_found_books_spells() -> void:
	var rat := Pregens.build("ratatoille", 10)
	for sid: Variant in Compendium.shared().item_data("amber_warden_spellbook")["spells"]:
		var why := rat.copy_spell_problem(str(sid))
		assert_true(why == "" or why == "Already in the spellbook", "%s: %s" % [sid, why])
		rat.copy_spell(str(sid))
		assert_true(str(sid) in (rat.spellcasting_entry("wizard")["spellbook"] as Array), "%s is in his book" % sid)


func test_an_older_save_gets_the_wardens_book() -> void:
	# A save from before 2026-10-18 that opened the warden's chest and left the blank book in it.
	var st := StoryState.new()
	st.party.append(Pregens.build("godrick_pendlebrook", 10))
	st.loc_state("amber_temple_faceless_god")
	st.location_states["amber_temple_faceless_god"]["contents"] = {"warden_cell_chest": {"items": [{"id": "spellbook", "qty": 1},
		{"id": "ink", "qty": 1}]}}
	var back := StoryState.from_dict(st.to_dict())
	var left := ((back.location_states["amber_temple_faceless_god"] as Dictionary)["contents"] as Dictionary)["warden_cell_chest"] as Dictionary
	assert_eq(str(((left["items"] as Array)[0] as Dictionary)["id"]), "amber_warden_spellbook")
	# One that took it: a non-Wizard's blank book was the warden's.
	var took := StoryState.new()
	took.party.append(Pregens.build("godrick_pendlebrook", 10))
	took.party.append(Pregens.build("ratatoille", 10))
	took.party[0].add_item("spellbook", 1)
	took.loc_state("amber_temple_faceless_god")
	(took.location_states["amber_temple_faceless_god"]["looted"] as Dictionary)["warden_cell_chest"] = true
	var back2 := StoryState.from_dict(took.to_dict())
	assert_true(back2.party[0].carries("amber_warden_spellbook"))
	assert_true(back2.party[1].carries("spellbook"), "Ratatouille's own book stays his")
