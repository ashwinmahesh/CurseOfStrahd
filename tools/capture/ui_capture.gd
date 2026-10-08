extends Node
## Every party screen for captures: the four pregens at level 5 with some wear on them (a Bloodied cleric, a spent
## Second Wind and spell slot, Shield of Faith, Poisoned), then the sheet's tabs, party, inventory, level up, rests,
## spell preparation (after a rest and after an item's Long Rest), journal, loot, shop, pause menu and character creation,
## one shot each, plus sample tooltips, the sheet for a level 7 warlock, monk and druid, and creating a character from the
## party screen (UI_ONLY=create), Madam Eva's rebuild (UI_ONLY=rebuild) a sheet opened in a fight (UI_ONLY=fight_sheet) and busts before and after they face each other (UI_ONLY=busts).
## make capture SCENE=res://tools/capture/ui_capture.tscn NAME=ui FRAMES=10 [UI_ONLY=party,loot] (env: only those)

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]
## [character index, tab]
const SHEET_SHOTS := [[2, "Actions"], [0, "Actions"], [2, "Spells"], [3, "Spells"], [1, "Features"], [0, "Equipment"],
	[0, "Effects"], [3, "Notes"]]

var root: Node
var _only: Array[String] = []


func _ready() -> void:
	for s in OS.get_environment("UI_ONLY").split(",", false):
		_only.append(s.strip_edges())
	Compendium.shared().tables["locations"]["sheet_hall"] = {"id": "sheet_hall", "name": "Sheet Hall", "region": "test",
		"summary": "", "map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	for id in PARTY:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "sheet_hall"
	GameState.story.gold = 42.0
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _wants(what: String) -> bool:
	return _only.is_empty() or what in _only


func _shoot(tool: Node, path: String) -> void:
	await tool.call("wait_frames", 8)
	tool.call("_shot", path)


func capture_shots(tool: Node, out: String) -> void:
	var party := GameState.story.party
	var ilse := party[0]
	var hedda := party[2]
	var silvain := party[3]
	hedda.hp = int(hedda.max_hp() / 2.0) - 3
	ilse.spend_resource("second_wind")
	ilse.add_temp_hp(5, "Capture")
	var me: Array[Character] = [ilse]
	FieldCasting.cast(party, hedda, "shield_of_faith", 1, me, DiceRoller.new(3))
	silvain.expend_slot(1)
	silvain.add_condition(&"poisoned", "Ghoul claws")
	silvain.build["notes"] = "Ireena trusts Ismark, not us. The burgomaster's letter was signed in a hand Silvain didn't know."
	var st := GameState.story
	st.set_quest_stage("death_house", "plea")
	st.set_quest_stage("death_house", "secret_stair")
	st.set_quest_stage("escort_ireena", str(((Compendium.shared().get_entry("quests", "escort_ireena")["stages"] as Array)[0] as Dictionary)["id"]))
	if st.codex.is_empty():
		for loc in Compendium.shared().all("locations"):
			for p: Variant in loc.get("props", []):
				if str((p as Dictionary).get("kind", "")) == "book" and st.codex.size() < 2:
					st.codex.append(str((p as Dictionary).get("codex", (p as Dictionary)["id"])))
	if _wants("sheet"):
		var n := 1
		for s: Variant in SHEET_SHOTS:
			var shot := s as Array
			root.call("open_screen", "sheet", int(shot[0]))
			(root.get("screen") as CharacterSheetScreen).show_tab(str(shot[1]))
			await _shoot(tool, "%s_sheet_%d_%s_%s.png" % [out, n, party[int(shot[0])].name.get_slice(" ", 0).to_lower(), str(shot[1]).to_lower()])
			n += 1
		root.call("close_screen")
	if _wants("tooltips"):
		await _tooltips(tool, out)
	for kind: String in ["party", "inventory", "journal", "rest", "menu"]:
		if _wants(kind):
			root.call("open_screen", kind, 0)
			if kind == "inventory":
				(root.get("screen") as InventoryScreen).selected = "greatsword"
				root.get("screen").call("_draw")
			await _shoot(tool, "%s_%s.png" % [out, kind])
			root.call("close_screen")
	if _wants("spellbook"):
		# A found spellbook (the Dursts'): its spells, and the party's Wizard copying them.
		GameState.story.party[0].add_item("durst_spellbook", 1)
		GameState.story.gold = maxf(GameState.story.gold, 120.0)
		root.call("open_screen", "inventory", 0)
		(root.get("screen") as InventoryScreen).selected = "durst_spellbook"
		root.get("screen").call("_draw")
		await _shoot(tool, "%s_spellbook.png" % out)
		root.call("close_screen")
	if _wants("roster"):
		# Tamsin waits at camp and is picked to swap in: the screen shows whose place she can take.
		var tamsin := GameState.story.party[1]
		GameState.story.send_to_camp(tamsin)
		root.call("open_screen", "roster", 0)
		var rs := root.get("screen") as RosterScreen
		rs.set("_picked", tamsin)
		rs.call("_draw")
		await _shoot(tool, "%s_roster.png" % out)
		root.call("close_screen")
		GameState.story.bring_along(tamsin)
	if _wants("prepare"):
		var ps := PrepareScreen.new()
		add_child(ps)
		ps.open(root, GameState.story, 0)
		await _shoot(tool, "%s_prepare.png" % out)
		ps.free()
		# After a Long Rest Silvain has swapped Fire Bolt for another cantrip: the Wizard's one swap is used.
		var before := PrepareScreen.snapshot(GameState.story)
		var cantrips := silvain.choice("wizard.cantrips")
		ChoiceOptions.populate(cantrips, silvain)
		for o in cantrips.options:
			if o.legal and not o.id in cantrips.picks:
				var picks: Array = cantrips.picks.duplicate()
				picks[0] = o.id
				(silvain.build["choices"] as Dictionary)["wizard.cantrips"] = picks
				silvain.refresh()
				break
		var ps2 := PrepareScreen.new()
		ps2.earlier = before
		add_child(ps2)
		ps2.open(root, GameState.story, 0)
		await tool.call("wait_frames", 4)
		for sc in ps2.find_children("*", "ScrollContainer", true, false):
			(sc as ScrollContainer).scroll_vertical = 100000
		await _shoot(tool, "%s_prepare_swapped.png" % out)
		ps2.queue_free()
	if _wants("item_rest"):
		# Daern's Instant Fortress gives a Long Rest from the inventory, which then offers Change prepared spells.
		ilse.add_item("daerns_instant_fortress")
		root.call("open_screen", "inventory", 0)
		var inv := root.get("screen") as InventoryScreen
		inv.selected = "daerns_instant_fortress"
		inv.call("_use_power", "fortress", {})
		await tool.call("wait_frames", 150)   # the "8 hours later" fade
		await _shoot(tool, "%s_item_rest.png" % out)
		inv.call("_open_prepare")
		await tool.call("wait_frames", 4)
		# Ratatoille's cantrips, the Wizard's one Long Rest swap.
		for l in inv.find_children("*", "Label", true, false):
			if (l as Label).text.contains("Wizard cantrips") or (l as Label).text.contains("Wizard Cantrips"):
				for sc in inv.find_children("*", "ScrollContainer", true, false):
					var scroll := sc as ScrollContainer
					scroll.scroll_vertical = int((l as Label).global_position.y - scroll.global_position.y) - 60
		await _shoot(tool, "%s_item_rest_prepare.png" % out)
		# Below it, his High Elf cantrip (Prestidigitation until he swaps it).
		for sc in inv.find_children("*", "ScrollContainer", true, false):
			(sc as ScrollContainer).scroll_vertical = 100000
		await _shoot(tool, "%s_item_rest_high_elf.png" % out)
		root.call("close_screen")
	if _wants("level_up"):
		GameState.story.milestones = 10
		root.call("open_screen", "level_up", 2)
		await _shoot(tool, "%s_level_up.png" % out)
		root.call("close_screen")
	if _wants("level_up_fighter"):
		# Ilse's Fighter 6: her Fighting Style may change though the level brings no new one.
		GameState.story.milestones = 10
		root.call("open_screen", "level_up", 0)
		await tool.call("wait_frames", 4)
		var screen := root.get("screen") as Node
		for l in screen.find_children("*", "Label", true, false):
			if (l as Label).text.contains("Choices"):
				for sc in screen.find_children("*", "ScrollContainer", true, false):
					var scroll := sc as ScrollContainer
					scroll.scroll_vertical = int((l as Label).global_position.y - scroll.global_position.y) - 8
		await _shoot(tool, "%s_level_up_fighter.png" % out)
		root.call("close_screen")
	if _wants("loot"):
		var lw := LootWindow.new()
		add_child(lw)
		lw.show_loot(GameState.story, "chest", [{"id": "potion_of_healing", "qty": 2}, {"id": "dagger", "qty": 1},
			{"id": "rope", "qty": 1}, {"id": "torch", "qty": 5}], 25.0, null)
		await _shoot(tool, "%s_loot.png" % out)
		lw.queue_free()
	if _wants("shop"):
		root.call("open_shop", "blinsky")
		await _shoot(tool, "%s_shop.png" % out)
		for c in root.get_children():
			if c is ShopScreen:
				c.queue_free()
	if _wants("creation"):
		var cs := CreationScreen.new()
		add_child(cs)
		var starting: Array[Dictionary] = []
		for ch in party:
			starting.append(ch.build.duplicate(true))
		cs.open_with(starting)
		for step: int in [0, 2, 3, 6, 7]:
			cs.step = step
			cs.call("_draw")
			await _shoot(tool, "%s_creation_%d.png" % [out, step])
		cs.queue_free()
	if _wants("rebuild"):
		# Madam Eva's rebuild of a prebuilt hero: every equipment option with its gold, and the look they keep.
		var rb := CreationScreen.new()
		add_child(rb)
		var start: Array[Dictionary] = [CreationScreen.rebuild_start(party[2])]
		rb.open_with(start, 1)
		rb.b().set_class("wizard")
		rb.b().set_background("acolyte")
		for step: int in [CharacterBuilder.Step.EQUIPMENT, CharacterBuilder.Step.APPEARANCE]:
			rb.step = step
			rb.call("_draw")
			await _shoot(tool, "%s_rebuild_%d.png" % [out, step])
		rb.queue_free()
	if _wants("classes"):
		# Level 7 in other classes: Pact Magic, Focus Points, a druid's long feature list.
		for extra: Array in [["warlock", "Actions"], ["warlock", "Spells"], ["monk", "Actions"], ["druid", "Features"]]:
			party[1] = TestChars.custom(str(extra[0]), "human", 7)
			root.call("open_screen", "sheet", 1)
			(root.get("screen") as CharacterSheetScreen).show_tab(str(extra[1]))
			await _shoot(tool, "%s_sheet_%s_%s.png" % [out, extra[0], str(extra[1]).to_lower()])
		root.call("close_screen")
	if _wants("dialogue"):
		# A conversation with many options (Doru's has seven or more): the box grows upward and scrolls past 45%.
		for n_opts: int in [8, 16]:
			var d := DialogueUI.new()
			add_child(d)
			await tool.call("wait_frames", 2)
			(d.get("_name") as Label).text = "Doru"
			(d.get("_text") as RichTextLabel).text = ("The boy in the cellar presses his face to the bars. \"Please. I'm so hungry. Let me out, and I'll tell you anything.\"")
			var opts: Array = []
			for i in n_opts:
				var check := {} if i % 3 != 1 else {"who": "Hedda Ironvow", "bonus": 5, "chance": 0.65}
				opts.append({"text": "Option %d: %s" % [i + 1, ["Ask about his father.", "Persuade him to wait for the priest.", "Ask what he's eaten.", "Say nothing and back away slowly from the bars.", "Insight: is he lying?"][i % 5]],
					"label": "[Insight]" if i % 3 == 1 else "", "check": check, "enabled": i != 5, "reason": "Needs a holy symbol"})
			d.call("_show_options", opts)
			await _shoot(tool, "%s_dialogue_%d_options.png" % [out, n_opts])
			d.queue_free()
			await tool.call("wait_frames", 2)
	if _wants("create"):
		await _create_shots(tool, out)
	if _wants("fight_sheet"):
		await _fight_sheet_shots(tool, out)
	if _wants("busts"):
		await _bust_shots(tool, out)
	# Last: the Long Rest fades to black for a while.
	if _wants("rest"):
		root.call("open_screen", "rest", 0)
		(root.get("screen") as RestScreen).call("_finish_short")
		(root.get("screen") as RestScreen).call("_long_rest", "safe")
		await _shoot(tool, "%s_rest_after.png" % out)
		root.call("close_screen")


## A fight with one rat, then a hero's character sheet opened from their portrait: view only (owner, 2026-10-08).
func _fight_sheet_shots(tool: Node, out: String) -> void:
	Compendium.shared().tables["locations"]["sheet_ward"] = {"id": "sheet_ward", "name": "Sheet Ward", "region": "test",
		"summary": "", "map": {"rows": ["##########", "#........#", "#........#", "#........#", "##########"], "light": "dim"},
		"spawns": {"default": [2, 2]}, "encounters": [{"id": "rat", "trigger": "manual", "monsters": [{"monster": "rat", "cell": [8, 3]}]}]}
	root.call("enter_location", "sheet_ward", "default")
	await tool.call("wait_frames", 4)
	var view := root.get("view") as LocationView
	if not view.start_encounter("rat"):
		return
	await tool.call("wait_frames", 4)
	var cv := view.combat_view
	await _shoot(tool, "%s_fight_sheet_1_hud.png" % out)
	cv.hud.sheet_requested.emit(cv.e.combatants.filter(func(c: Combatant) -> bool: return c.creature is Character)[1].id)
	await _shoot(tool, "%s_fight_sheet_2_actions.png" % out)
	(root.get("screen") as CharacterSheetScreen).show_tab("Spells")
	await _shoot(tool, "%s_fight_sheet_3_spells.png" % out)
	root.call("close_screen")
	cv.finished.emit("victory")
	await tool.call("wait_frames", 4)


## Busts facing each other (owner, 2026-10-08): Thistle (drawn facing left) speaking with Ireena (drawn facing right),
## first as drawn (before), then mirrored to face each other (after), then Ireena turned away by a Narrator cue.
func _bust_shots(tool: Node, out: String) -> void:
	var st := GameState.story
	var thistle := st.party[2]
	st.party.erase(thistle)
	st.party.insert(0, thistle)   # she leads, so she speaks for the party on the left
	DialogueFile.register(DialogueFile.parse("~ cap\nIreena [sad]: My father is three days dead, and the ground is too hard to bury him.\n"
		+ "Narrator [away]: She turns to the window, where the mist presses against the glass.\n-> END\n", "capture/busts"))
	for shot: Array in [[false, "1_before"], [true, "2_after"]]:
		DialogueBusts.mirror = bool(shot[0])
		var d := DialogueUI.new()
		add_child(d)
		await tool.call("wait_frames", 2)
		d.play(DialogueRunner.new(st, DiceRoller.new(2)), "capture/busts:cap")
		await _shoot(tool, "%s_busts_%s.png" % [out, shot[1]])
		if bool(shot[0]):
			d.call("_advance")
			await _shoot(tool, "%s_busts_3_away.png" % out)
		d.queue_free()
		await tool.call("wait_frames", 2)
	DialogueBusts.mirror = true
	st.party.erase(thistle)
	st.party.insert(2, thistle)


## Creating a character from the party screen (owner, 2026-10-07): the party at level 5 with Ratatoille and the
## starting hero at camp; the creator with the hero's portrait worn, the new character's Review, the party screen with
## her four level-ups waiting, her level-up screen, and the create option once four custom characters are made.
func _create_shots(tool: Node, out: String) -> void:
	var st := GameState.story
	st.milestones = 4
	st.send_to_camp(st.party[st.party.size() - 1])
	var vasha := TestChars.custom("fighter", "human", 5)
	vasha.name = "Vasha Dunmere"
	vasha.build["name"] = "Vasha Dunmere"
	vasha.build["appearance"] = HeroLook.default_appearance("female", "fighter")
	vasha.id = "vasha_dunmere"
	st.bench.append(vasha)
	root.call("open_screen", "party", 0)
	await _shoot(tool, "%s_create_1_party.png" % out)
	root.call("open_screen", "create", 0)
	var cs := root.get("screen") as CreationScreen
	var b := cs.b()
	b.set_class("ranger")
	b.set_background("guide")
	b.set_species("elf")
	TestChars.auto_pick(func() -> Array[Choice]: return b.pending_choices(),
		func(key: String, chosen: Array) -> void: b.choose(key, chosen))
	b.set_name("Mira Vell")
	cs.call("_suit_outfit")
	var app := (b.build["appearance"] as Dictionary).duplicate()
	app.merge({"head": "elfin", "hair": "wavy", "hair_colour": "auburn", "skin": "olive"}, true)
	b.set_appearance(HeroLook.settle(app))
	cs.step = CharacterBuilder.Step.APPEARANCE
	cs.set("_appearance_tab", "Portrait & voice")
	cs.call("_draw")
	await _shoot(tool, "%s_create_2_portraits.png" % out)
	cs.set("_appearance_tab", "Body")
	cs.call("_draw")
	await _shoot(tool, "%s_create_3_appearance.png" % out)
	cs.confirmed[0] = true
	cs.step = CharacterBuilder.Step.REVIEW
	cs.call("_draw")
	await _shoot(tool, "%s_create_4_review.png" % out)
	cs.call("_finish")
	await tool.call("wait_frames", 2)
	await _shoot(tool, "%s_create_5_joined.png" % out)
	root.call("open_screen", "level_up", st.party.size() - 1)
	await _shoot(tool, "%s_create_6_level_up.png" % out)
	for n: Array in [["Oskar Brann", "hero_02", "rogue"], ["Dorota Kask", "hero_03", "wizard"]]:
		var ch := TestChars.custom(str(n[2]), "human", 1)
		ch.name = str(n[0])
		ch.build["name"] = str(n[0])
		var look := HeroLook.default_appearance("female", str(n[2]))
		look["portrait"] = str(n[1])
		look["art"] = str(n[1])
		ch.build["appearance"] = look
		ch.id = ""
		st.recruit(ch)
	root.call("open_screen", "party", 0)
	await _shoot(tool, "%s_create_7_four_made.png" % out)
	root.call("close_screen")


## Tooltips as the engine shows them (the theme's tooltip panel around each custom tooltip), over the sheet.
func _tooltips(tool: Node, out: String) -> void:
	var hedda := GameState.story.party[2]
	root.call("open_screen", "sheet", 2)
	var tips := CanvasLayer.new()
	tips.layer = 100
	add_child(tips)
	var spell := Compendium.shared().spell_data("spirit_guardians")
	var samples: Array[Control] = [UiParts.breakdown_tip(hedda.armor_class(), "Armor Class"),
		UiParts.breakdown_tip(hedda.skill_bonus(&"religion"), "Religion", hedda.skill_bonus(&"religion").signed(), "Proficient."),
		UiParts.rules_tip(str(spell["name"]), "Level 3 Conjuration", str(spell.get("text", spell["summary"])),
			[["Casting time", "Action"], ["Range", "Self"], ["Duration", "Concentration, up to 10 minutes"]])]
	var x := 60.0
	for t in samples:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", ThemeDB.get_default_theme().get_stylebox("panel", "TooltipPanel"))
		p.add_child(t)
		p.position = Vector2(x, 330)
		tips.add_child(p)
		x += 470.0 if t != samples[0] else 330.0
	await _shoot(tool, "%s_tooltips.png" % out)
	tips.queue_free()
	root.call("close_screen")
