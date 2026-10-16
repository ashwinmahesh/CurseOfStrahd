class_name GuidancePrompt
extends CanvasLayer
## Guidance before a skill check outside a fight (GuidanceOffer): who's about to try what, a line for each party member
## who could cast it (with the spell it would end, if they're concentrating on one), a way to roll without it, and the
## casters' rule for next time (Ask me, Cast it without asking, Don't offer it). The mouse, the keys (1-9 pick a caster,
## Esc rolls without it) and the pad (A picks, B rolls without it, left and right turn the rule) all answer it. It sits
## over the place, the conversation or the shop until it's answered; the check is rolled once it is.

## The caster picked (an index into the offer's casters, -1 for nobody) and the rule they keep from now on ("" when
## the player left it alone, so a caster on Automatic who was offered too keeps it).
signal answered(index: int, rule: String)

## Over a conversation (20) and the shop (31), under the loading card (40).
const LAYER := 34
const WIDTH := 660.0
const RULE_NAMES := {"ask": "Ask me", "auto": "Cast it without asking", "never": "Don't offer it"}

var offer: Dictionary = {}
var rule := "ask"
## The player turned the rule.
var rule_turned := false
## The casters' buttons, in the offer's order.
var choices: Array[Button] = []
var decline_button: Button
var rule_button: Button
var _done := false


## Shows the prompt for offer `o` over `host`; `then(index, rule)` runs once it's answered.
static func ask(host: Node, o: Dictionary, then: Callable) -> GuidancePrompt:
	var p := GuidancePrompt.new()
	p.offer = o
	p.answered.connect(then, CONNECT_ONE_SHOT)
	host.add_child(p)
	return p


func _init() -> void:
	name = "GuidancePrompt"
	layer = LAYER


func _ready() -> void:
	var casters := offer.get("casters", []) as Array
	var who := offer["who"] as Creature
	var box := MobilePage.build(self, "Guidance", func() -> void: _answer(-1)) if MobileDevice.enabled() else UiKit.screen_frame(self, "Guidance", Vector2(WIDTH, 180.0 + 54.0 * (casters.size() + 1)))
	_rename_escape()
	var dc := int(offer.get("dc", 0))
	var about := UiKit.label("%s is about to try %s%s." % [who.name.get_slice(" ", 0), GuidanceOffer.skill_name(offer["skill"] as StringName),
		" (DC %d)" % dc if dc > 0 else ""], 19, "vellum", WIDTH - 72.0)
	box.add_child(about)
	box.add_child(UiKit.label("Cast Guidance first? The caster touches them, and they add 1d4 to the roll.", 15, "parchment",
		WIDTH - 72.0))
	for i in casters.size():
		var e := casters[i] as Dictionary
		var caster := e["caster"] as Creature
		var ends := str(e["ends"])
		var idx := i
		var b := UiKit.button("%d. %s casts Guidance%s" % [i + 1, caster.name.get_slice(" ", 0),
			" (ends %s)" % ends if ends != "" else ": +1d4"], func() -> void: _answer(idx), 17)
		b.name = "Caster%d" % i
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiParts.icon_on_button(b, "spell", GuidanceOffer.SPELL, 26)
		if ends != "":
			b.tooltip_text = "%s is concentrating on %s. Casting Guidance ends it." % [caster.name.get_slice(" ", 0), ends]
		if i == 0:
			b.set_meta(&"pad_first", true)
		box.add_child(b)
		choices.append(b)
	decline_button = UiKit.button("Roll without Guidance", func() -> void: _answer(-1), 17)
	decline_button.name = "Decline"
	decline_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(decline_button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(UiParts.caption("Next time", 14))
	rule_button = UiKit.button("", func() -> void: turn_rule(1), 15)
	rule_button.name = "Rule"
	rule_button.tooltip_text = "For %s from now on. It can be changed again on the Reactions tab in a fight." % _caster_names()
	rule_button.set_meta(&"pad_adjust", turn_rule)   # the pad's left and right turn it (PadNav)
	row.add_child(rule_button)
	box.add_child(row)
	_show_rule()
	if MobileDevice.enabled():
		(box.get_parent() as ScrollContainer).horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		MobileUi.fit(box)
	if not choices.is_empty():
		choices[0].grab_focus.call_deferred()


## "Hedda and Liriel": the offered casters, whom the rule is for.
func _caster_names() -> String:
	var names: Array[String] = []
	for e: Variant in offer.get("casters", []):
		names.append(((e as Dictionary)["caster"] as Creature).name.get_slice(" ", 0))
	if names.size() < 2:
		return "".join(names)
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names.back()]


## The rule shown steps forward (1) or back (-1): Ask me, Cast it without asking, Don't offer it.
func turn_rule(step: int) -> void:
	var at := GuidanceOffer.RULES.find(rule)
	rule = GuidanceOffer.RULES[posmod(at + step, GuidanceOffer.RULES.size())]
	rule_turned = true
	_show_rule()


func _show_rule() -> void:
	rule_button.text = "‹  %s  ›" % RULE_NAMES[rule]


## The frame's note under its border says what Escape does here.
func _rename_escape() -> void:
	for l: Node in find_children("*", "Label", true, false):
		if (l as Label).text in ["Esc: close", PadGlyphs.words("Esc: close", "{b}: close")]:
			PadGlyphs.hint(l, "Esc: roll without it", "{b}: roll without it")


## Answers once: who casts it (-1: nobody) and the rule from now on. Then the prompt goes.
func _answer(index: int) -> void:
	if _done:
		return
	_done = true
	answered.emit(index, rule if rule_turned else "")
	UiMotion.dismiss(self)


## Whether it's still waiting for an answer.
func open() -> bool:
	return not _done


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed(&"combat_cancel"):
		get_viewport().set_input_as_handled()
		_answer(-1)
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.physical_keycode >= KEY_1 and k.physical_keycode <= KEY_9 \
			and int(k.physical_keycode - KEY_1) < choices.size():
		get_viewport().set_input_as_handled()
		_answer(int(k.physical_keycode - KEY_1))
		return
	# Nothing behind it moves while it's up: no walking, no menus, no talk going on.
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
