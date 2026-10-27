extends Node
## Isolated mobile pages, with the real inventory and combat catalog. No player saves or settings are modified.
## --points=834x1194 (with matching --size) exercises portrait or resized iPad logical geometry offscreen.

var inventory: InventoryScreen


func close_screen() -> void:
	if is_instance_valid(inventory):
		inventory.queue_free()


func capture_shots(tool: Node, out: String) -> void:
	InputActions.ensure()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--points="):
			var dimensions := argument.get_slice("=", 1).split("x")
			MobileDevice.test_size = Vector2(float(dimensions[0]), float(dimensions[1]))
			MobileDevice.test_safe = Rect2(Vector2(8, 24), MobileDevice.test_size - Vector2(16, 48))
			MobileDevice.current.configure()
	if "--main-integration-only" in OS.get_cmdline_user_args():
		await _main_integrations(tool, out)
		return
	var state := StoryState.new()
	for id: String in ["godrick_pendlebrook", "thistle", "liriel_dawnsong", "ratatoille"]:
		state.party.append(Pregens.build(id, 5))
	state.party[0].add_item("potion_of_healing", 4)
	state.gold = 42
	inventory = InventoryScreen.new()
	add_child(inventory)
	inventory.open(self, state, 0)
	for section: String in ["Bag", "Equipment", "Details"]:
		inventory.mobile.section = section if section != "Details" else "Bag"
		inventory.mobile.detail = section == "Details"
		inventory.selected = "potion_of_healing" if section == "Details" else ""
		inventory._draw()
		await tool.call("wait_frames", 12)
		tool.call("_shot", out + "_" + section.to_lower() + ".png")
	close_screen()
	await tool.call("wait_frames", 2)
	var encounter := TestCombat.open_field()
	var actor := TestCombat.hero(encounter, "godrick_pendlebrook", Vector2i(2, 2), 5)
	TestCombat.foe(encounter, "zombie", Vector2i(6, 2))
	TestCombat.start_with(encounter, actor)
	var catalog := ActionCatalog.new(encounter)
	var actions := MobileActions.new()
	add_child(actions)
	actions.open(catalog, actor)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_actions.png")
	for action in catalog.actions_for(actor):
		if str(action["id"]) == "dodge":
			actions.inspect(action)
			break
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_review.png")

	actions.queue_free()
	await tool.call("wait_frames", 2)
	var hud := CombatHud.new()
	add_child(hud)
	hud.build(encounter, catalog)
	hud.refresh()
	hud.show_tooltip("Zombie · preview", ["Attack with your longsword", "Use Confirm to commit"], [], Vector2.ZERO)
	hud.show_odds(0.65, "8–15", "", Vector2.ZERO)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_battle_hud.png")
	var req := ReactionRequest.new("shield", actor.id, "foe")
	req.title = "Reaction: protect your companion?"
	req.text = "A zombie attacks your companion. Choose who receives your protection before confirming."
	req.cost = "Reaction"
	req.min_targets = 1
	req.max_targets = 1
	for n in 5:
		req.target_choices.append({"id": str(n), "label": "Companion %d · within reach" % n})
	hud.show_prompt(req)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_reaction.png")
	hud.queue_free()
	await tool.call("wait_frames", 2)
	var pause := PauseMenu.new()
	add_child(pause)
	pause.open(self, state, 0)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_menu.png")
	pause._show_settings("Game")
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_settings.png")
	pause.queue_free()
	await tool.call("wait_frames", 2)
	var exploration := ExploreHud.new()
	add_child(exploration)
	exploration.build(state)
	exploration.refresh("Village of Barovia", true, false, false)
	exploration.narrate("Mist curls around the village houses. A light burns in the tavern window, and the sound of quiet conversation reaches the road.")
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_exploration.png")
	exploration.mobile.menu()
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_exploration_menu.png")
	exploration.queue_free()
	await tool.call("wait_frames", 2)
	var conversation := DialogueUI.new()
	add_child(conversation)
	conversation.busts.party_speaker("godrick_pendlebrook")
	conversation.busts.line({"portrait": "ireena", "party": false, "narrator": false}, "godrick_pendlebrook")
	conversation._show({"kind": "line", "name": "Ireena", "speaker_id": "ireena", "portrait": "ireena", "party": false, "narrator": false,
		"text": "Outside, the mist presses against the windows. We should leave before nightfall."})
	conversation._show({"kind": "options", "options": [
		{"text": "Ask about the strange mist around the village.", "label": "", "check": {}},
		{"text": "Offer to help the villagers.", "label": "Persuasion", "check": {"who": "Godrick", "bonus": 5, "chance": 0.65}},
		{"text": "Leave the inn and explore the village.", "label": "", "check": {}}]})
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_conversation.png")
	conversation.queue_free()
	await tool.call("wait_frames", 2)
	var sheet := CharacterSheetScreen.new()
	add_child(sheet)
	sheet.open(self, state, 0)
	sheet.mobile_section = "Abilities"
	sheet._draw()
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_character.png")
	for section: String in ["Overview", "Spells"]:
		sheet.mobile_section = section
		sheet._draw()
		await tool.call("wait_frames", 12)
		tool.call("_shot", out + "_character_" + section.to_lower() + ".png")
	sheet.queue_free()
	await tool.call("wait_frames", 2)
	var creator := CreationScreen.new()
	add_child(creator)
	creator.open_with([])
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_creator.png")
	for step: int in [2, 5]:
		creator.step = step
		creator._draw()
		await tool.call("wait_frames", 12)
		tool.call("_shot", out + ("_creator_abilities.png" if step == 2 else "_creator_appearance.png"))
	creator.queue_free()
	await tool.call("wait_frames", 2)
	var codes := CheatCodesPage.open_on(self, state)
	codes.type_code(CheatCodes.code_of("weapon_plus_1"))
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_item_codes.png")
	UiFeel.touch._show_selection(codes._pick)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_item_code_choices.png")
	UiFeel.touch._close_selection()
	codes.queue_free()
	await tool.call("wait_frames", 2)
	var prior_dir := SaveSystem.save_dir
	SaveSystem.save_dir = "user://mobile_capture_saves/"
	var saves := SavesScreen.open_on(self, SavesScreen.Mode.LOAD, Callable())
	saves._tab = "Chapters"
	saves._fill()
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_saves.png")
	saves._question({"location": "Village of Barovia", "day": 12, "party": "Godrick, Thistle and Liriel"}, "Import save?", "An adventure shared from a computer.", "Import creates a new local save.", "Import", func() -> void: pass)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_import.png")
	saves.queue_free()
	SaveSystem.save_dir = prior_dir
	await tool.call("wait_frames", 2)
	var lifecycle := MobileLifecycle.new()
	add_child(lifecycle)
	lifecycle.suspend()
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_resume.png")
	lifecycle.resume_play()
	lifecycle.queue_free()
	await tool.call("wait_frames", 2)
	await _remaining_pages(tool, out)


func _remaining_pages(tool: Node, out: String) -> void:
	var state := StoryState.from_dict(AtomicJson.read("res://tests/saves/v2_amber_temple.json")["story"] as Dictionary)
	state.party[0].hp = 1
	for quest: Dictionary in Compendium.shared().all("quests"):
		state.set_quest_stage(str(quest["id"]), str((quest["stages"][0] as Dictionary)["id"]))
	state.codex.append("tome_of_strahd")
	Bestiary.learn(state, "zombie")
	var loot := LootWindow.new()
	add_child(loot)
	loot.show_loot(state, "mobile_capture", [{"id": "potion_of_healing", "qty": 3}, {"id": "longsword", "qty": 2}], 300, null)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_loot.png")
	loot.queue_free()
	await tool.call("wait_frames", 2)
	var services := ServicesScreen.new()
	add_child(services)
	services.open_for(self, state, "father_lucian")
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_services.png")
	services._mobile_confirm(Services.offered(state, "father_lucian")[0])
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_purchase.png")
	services.queue_free()
	await tool.call("wait_frames", 2)
	var prepare := PrepareScreen.new()
	add_child(prepare)
	prepare.open(self, state, 0)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_prepare.png")
	for choice: ChoiceWidget in prepare.find_children("*", "ChoiceWidget", true, false):
		if not choice.choice.options.is_empty():
			choice._mobile_inspect(choice.choice.options[0].id)
			await tool.call("wait_frames", 12)
			tool.call("_shot", out + "_spell_details.png")
			break
	prepare.queue_free()
	await tool.call("wait_frames", 2)
	var party := PartyScreen.new()
	add_child(party)
	party.open(self, state, 0)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_party.png")
	party.mobile_section = "Companions"
	party._draw()
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_companions.png")
	party.queue_free()
	await tool.call("wait_frames", 2)
	var roster := RosterScreen.new()
	add_child(roster)
	roster.open(self, state, 0)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_roster.png")
	roster.queue_free()
	await tool.call("wait_frames", 2)
	var wait := WaitScreen.new()
	add_child(wait)
	wait.build(self, state, "")
	wait.set_hours(24)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_wait.png")
	wait.queue_free()
	await tool.call("wait_frames", 2)
	var journal := JournalScreen.new()
	add_child(journal)
	journal.open(self, state, 0)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_journal.png")
	for quest in QuestLog.journal(state):
		journal._mobile_read(str(quest["id"]))
		await tool.call("wait_frames", 12)
		tool.call("_shot", out + "_quest.png")
		break
	journal.queue_free()

	await tool.call("wait_frames", 2)
	var travel := TravelScreen.new()
	add_child(travel)
	state.visited["village_of_barovia"] = true
	travel.open_map(state, "village_of_barovia", true)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_map.png")
	for place in Travel.known(state):
		if not Travel.route("village_of_barovia", str(place["id"]), state).is_empty():
			travel.select(str(place["id"]))
			await tool.call("wait_frames", 12)
			tool.call("_shot", out + "_route.png")
			break
	travel.queue_free()


## Focused rebase evidence; the normal 36-view native fixture contract stays unchanged.
func _main_integrations(tool: Node, out: String) -> void:
	var encounter := TestCombat.open_field(8)
	var caster := TestCombat.caster_with(encounter, ["bless"], Vector2i(2, 2))
	TestCombat.punching_bag(encounter, Vector2i(6, 2))
	TestCombat.start_with(encounter, caster)
	encounter.spells.cast(caster, "bless", 1, [caster])
	var hud := CombatHud.new()
	add_child(hud)
	hud.build(encounter, ActionCatalog.new(encounter))
	hud.confirm_drop_concentration("Stop concentrating on Bless?")
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_concentration_confirm.png")
	hud.queue_free()
	await tool.call("wait_frames", 2)
	var conversation := DialogueUI.new()
	add_child(conversation)
	conversation.busts.party_speaker("godrick_pendlebrook")
	conversation.busts.line({"portrait": "ireena", "party": false, "narrator": false}, "godrick_pendlebrook")
	conversation._show({"kind": "line", "name": "Ireena", "speaker_id": "ireena", "portrait": "ireena",
		"party": false, "narrator": false, "text": "We can still turn back."})
	conversation._show({"kind": "options", "options": [
		{"text": "Refuse the task.", "label": "", "check": {}, "ends": ["A Knight, More or Less"]},
		{"text": "Keep looking.", "label": "", "check": {}}]})
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_quest_consequence.png")
	conversation.queue_free()
	await tool.call("wait_frames", 2)
	var state := StoryState.new()
	state.party.append(Pregens.build("kip_smudgewick", 10))
	var prepare := PrepareScreen.new()
	prepare.rest_kind = "short_rest"
	add_child(prepare)
	prepare.open(self, state, 0)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_rest_change.png")
	prepare.queue_free()
	await tool.call("wait_frames", 2)
	state.set_quest_stage("death_house", "plea")
	state.set_quest_stage("the_priests_son", "doru_destroyed")
	state.set_quest_stage("escort_ireena", "asked")
	state.set_quest_stage("the_oat_thief", "rumored")
	var journal := JournalScreen.new()
	journal.quest_tab = "Other"
	journal.status_filter = "failure"
	add_child(journal)
	journal.open(self, state, 0)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_journal_filters.png")
	journal.queue_free()
	await tool.call("wait_frames", 2)
