extends Node
## The UI kit's own shots (U1 rules cards, G9 motion): the sheet's tooltips as cards with gilded rules words, a card
## opened from a word inside another and a pinned one; the Features tab's gilded summaries; and frames from the middle
## of a screen opening, the journal turning a page, a screen closing, Tarokka cards flipping and Hit Points rolling.
## make capture SCENE=res://tools/capture/ui_kit_capture.tscn NAME=uikit/after FRAMES=10 ARGS=--motion

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]

var root: Node


func _ready() -> void:
	Compendium.shared().tables["locations"]["sheet_hall"] = {"id": "sheet_hall", "name": "Sheet Hall", "region": "test",
		"summary": "", "map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	for id in PARTY:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "sheet_hall"
	GameState.story.gold = 42.0
	GameState.story.set_quest_stage("death_house", "plea")
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _shoot(tool: Node, path: String, frames: int = 8) -> void:
	await tool.call("wait_frames", frames)
	tool.call("_shot", path)


func capture_shots(tool: Node, out: String) -> void:
	var cards := TipCards.current
	cards.hold = true
	var party := GameState.story.party
	var hedda := party[2]
	hedda.hp = int(hedda.max_hp() / 2.0) - 3
	party[3].add_condition(&"poisoned", "Ghoul claws")
	# The same three tooltips as the old capture, now cards: Armor Class, Religion and Spirit Guardians.
	root.call("open_screen", "sheet", 2)
	await tool.call("wait_frames", 20)
	var screen := root.get("screen") as Node
	var anchor: Control = null
	for n in screen.find_children("*", "", true, false):
		if n is UiParts.Tipped and anchor == null:
			anchor = n as Control
	var spell := Compendium.shared().spell_data("spirit_guardians")
	var samples: Array[Callable] = [
		func() -> Control: return UiParts.breakdown_tip(hedda.armor_class(), "Armor Class"),
		func() -> Control: return UiParts.breakdown_tip(hedda.skill_bonus(&"religion"), "Religion", hedda.skill_bonus(&"religion").signed(), "Proficient."),
		func() -> Control: return UiParts.rules_tip(str(spell["name"]), "Level 3 Conjuration", str(spell.get("text", spell["summary"])),
			[["Casting time", "Action"], ["Range", "Self"], ["Duration", "Concentration, up to 10 minutes"]])]
	var at: Array[Vector2] = [Vector2(60, 330), Vector2(390, 330), Vector2(860, 300)]
	var opened: Array[TipCard] = []
	for i in samples.size():
		# Chained to the one before only so that opening it doesn't close that one; each is placed where the old shot had it.
		var c := cards.open_card({"key": "tip:%d" % i, "control": anchor, "tip": samples[i]}, at[i],
			null if opened.is_empty() else opened.back())
		c.position = at[i]
		opened.append(c)
	await _shoot(tool, "%s_tooltips.png" % out, 20)
	cards.clear()
	# A spell's card, the card of a gilded word inside it beside it, and a condition pinned at the top left.
	var sg := cards.open_card({"key": "tip:sg", "control": anchor, "tip": samples[2]}, Vector2(380, 170))
	await tool.call("wait_frames", 4)
	var conc := _text_with(sg, "concentration")
	var inner := cards.open_card({"key": "term:concentration", "control": conc, "term": "concentration"},
		conc.get_global_rect().position + Vector2(0, 14))
	await tool.call("wait_frames", 4)
	var inc := _text_with(inner, "incapacitated")
	cards.open_card({"key": "term:incapacitated", "control": inc, "term": "incapacitated"},
		inc.get_global_rect().position + Vector2(0, 40))
	var deepest := cards.cards.back() as TipCard
	var pinned := cards.open_card({"key": "term:prone", "control": anchor, "term": "prone"}, Vector2(60, 560), deepest)
	cards.toggle_pin(pinned)
	pinned.position = Vector2(40, 600)
	for c in cards.cards:
		c.settle()
	await _shoot(tool, "%s_cards.png" % out, 20)
	cards.clear()
	root.call("close_screen")
	await tool.call("wait_frames", 20)
	# The Features tab: summaries with their rules words gilded in place.
	root.call("open_screen", "sheet", 1)
	(root.get("screen") as CharacterSheetScreen).show_tab("Features")
	await _shoot(tool, "%s_features.png" % out, 30)
	root.call("close_screen")
	await tool.call("wait_frames", 20)
	# Motion: the journal rising into place, turning to the Codex, and sinking away.
	root.call("open_screen", "journal", 0)
	await _shoot(tool, "%s_open_mid.png" % out, 5)
	await _shoot(tool, "%s_open_done.png" % out, 24)
	var codex := _button(root.get("screen") as Node, "Codex")
	codex.pressed.emit()
	await _shoot(tool, "%s_page_mid.png" % out, 7)
	await _shoot(tool, "%s_page_done.png" % out, 30)
	root.call("close_screen")
	await _shoot(tool, "%s_close_mid.png" % out, 4)
	await tool.call("wait_frames", 30)
	await _tarokka(tool, out)
	await _hit_points(tool, out)


func _text_with(card: TipCard, term: String) -> TermText:
	for t in card.find_children("*", "TermText", true, false):
		if (t as TermText).text.contains("term:%s]" % term):
			return t as TermText
	return null


func _button(n: Node, text: String) -> Button:
	for b in n.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b as Button
	return null


## Three Tarokka cards dealt one after another: the first face up, the second mid-turn, the third still showing its back.
func _tarokka(tool: Node, out: String) -> void:
	var layer := _stage()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	row.position = Vector2(520, 300)
	layer.add_child(row)
	var dlg := DialogueUI.new()
	var ids: Array[String] = ["seer", "swords_3", "mists"]
	for i in ids.size():
		var card := dlg.call("_tarokka_card", ids[i], ["tome", "symbol", "sword"][i]) as Control
		row.add_child(card)
		UiMotion.flip_in(card, 0.15 + 0.45 * i)
	dlg.free()
	await _shoot(tool, "%s_tarokka.png" % out, 34)
	layer.queue_free()


## Hit Points rolling: Godrick's bar draining after a blow, Liriel's filling after healing.
func _hit_points(tool: Node, out: String) -> void:
	var layer := _stage()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.position = Vector2(560, 360)
	layer.add_child(box)
	var hurt := GameState.story.party[0]
	var healed := GameState.story.party[1]
	hurt.hp = hurt.max_hp()
	healed.hp = 4
	# What the screen showed before...
	UiParts.hp_bar(hurt, 480.0, 28.0).free()
	UiParts.hp_bar(healed, 480.0, 28.0).free()
	hurt.hp = 9
	healed.hp = healed.max_hp() - 2
	for ch: Character in [hurt, healed]:
		box.add_child(UiKit.label(ch.name, 16, "gilt_light"))
		box.add_child(UiParts.hp_bar(ch, 480.0, 28.0))
	await _shoot(tool, "%s_hp_roll.png" % out, 14)
	layer.queue_free()


func _stage() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(Look.color("void"), 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	return layer
