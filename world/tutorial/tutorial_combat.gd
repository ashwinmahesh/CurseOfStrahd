class_name TutorialCombat
extends Node3D
## A real encounter with a private party, observed only after actions have been presented.

signal objective_met(feedback: String)
signal menu_requested
signal sheet_requested(who: Character)

const LESSON_IDS: Array[String] = ["combat_orientation", "combat_move", "combat_attack", "combat_bonus", "combat_end_turn", "combat_reaction", "combat_cantrip", "combat_heal", "combat_concentration", "combat_practice"]
const ROWS: Array[String] = ["############", "#..........#", "#..........#", "#..........#", "#..........#", "#..........#", "#..........#", "############"]

var view: CombatView
var e: Encounter
var hero: Combatant
var partner: Combatant
var opponent: Combatant
var board: ArenaBoard
var rig: CameraRig
var completed := false
var lesson_id := "combat_orientation"
var _roller: DiceRoller
var _hero_turns := 0
var _reaction_seen := false
var _reaction_answered := false
var _log_seen := 0
var _starting_hp := 0
var _starting_slots := 0
var _starting_wind := 0
var _finishing := false


func configure(id: String, roller: DiceRoller) -> void:
	assert(not is_inside_tree())
	assert(id in LESSON_IDS)
	lesson_id = id
	_roller = roller


func _ready() -> void:
	InputActions.ensure()
	if _roller == null:
		_roller = DiceRoller.new(73)
	e = Encounter.new(CombatGrid.from_rows(ROWS), _roller)
	e.title = "A lesson at the roadside shrine"
	e.ambient_light = "bright"
	var magic := lesson_id in ["combat_cantrip", "combat_heal", "combat_concentration"]
	var ch := Pregens.build("liriel_dawnsong" if magic else "ilse_varga", 1)
	ch.finish_long_rest()
	ch.heroic_inspiration = false
	hero = e.add(ch, &"party", Vector2i(3, 3))
	if lesson_id == "combat_bonus":
		ch.hp = maxi(1, ch.max_hp() - 8)
	_starting_hp = ch.hp
	_starting_slots = ch.slots_left(1)
	_starting_wind = ch.resource_left("second_wind")
	if lesson_id in ["combat_heal", "combat_practice"]:
		var friend := Pregens.build("ilse_varga" if magic else "liriel_dawnsong", 1)
		friend.finish_long_rest()
		friend.heroic_inspiration = false
		if lesson_id == "combat_heal":
			friend.hp = maxi(1, friend.max_hp() - 9)
		partner = e.add(friend, &"party", Vector2i(3, 4))
		if lesson_id == "combat_heal":
			_starting_hp = friend.hp
	var mon := Monster.from_data(Compendium.shared().monster_data("bandit"))
	mon.name = "Sparring partner"
	var adjacent := lesson_id in ["combat_attack", "combat_reaction"]
	opponent = e.add(mon, &"enemy", Vector2i(4, 3) if adjacent else Vector2i(8, 3))
	CombatArena.build_environment(self)
	board = ArenaBoard.build(e.grid, "shrine_yard")
	add_child(board)
	var tokens := {}
	for c in e.combatants:
		var token := CombatToken.create(c)
		token.position = board.cell_center(c.cell, c.size_cells)
		token.face(Vector2(1, 0) if c.side == &"party" else Vector2(-1, 0), false)
		add_child(token)
		tokens[c.id] = token
	rig = CameraRig.new()
	add_child(rig)
	rig.distance = 11.0
	rig.camera.current = true
	rig.camera.add_child(Look.make_post_process())
	view = CombatView.new()
	view.opponent_turn = _opponent_turn
	view.command_filter = allows_command
	view.events_presented.connect(_presented)
	view.menu_requested.connect(func() -> void: menu_requested.emit())
	view.sheet_requested.connect(func(who: Character) -> void: sheet_requested.emit(who))
	add_child(view)
	view.begin(e, board, rig, tokens)
	view.hud.coach_guided = is_guided()
	view.hud.coach_action_id = _guided_action_id()
	view.hud.set_tab(ActionCatalog.SPELLS if magic else (view.catalog.class_tab(hero) if lesson_id == "combat_bonus" else ActionCatalog.COMMON))
	rig.snap_to_target()


func _opponent_turn(c: Combatant) -> CombatResult:
	if lesson_id == "combat_practice":
		return e.run_ai_turn()
	if lesson_id == "combat_reaction" and not _reaction_answered:
		var reach := e.reachable_for(c)
		var away := c.cell
		for cell: Vector2i in reach:
			if bool((reach[cell] as Dictionary).get("occupied", false)):
				continue
			if e.grid.distance_ft(hero.cell, hero.size_cells, cell, c.size_cells) > hero.reach_ft():
				away = cell
				break
		if away != c.cell:
			var moved := e.move(c, away)
			if e.pending != null and e.pending.kind == "opportunity_attack" and e.pending.reactor_id == hero.id:
				_reaction_seen = true
			return e.then(moved, _finish_opponent.bind(c))
	return e.then(e.dodge(c), _finish_opponent.bind(c))


func _finish_opponent(c: Combatant) -> CombatResult:
	if not _finishing and e.state == Encounter.State.ACTIVE and e.current() == c:
		return e.end_turn()
	return CombatResult.new()


func _exit_tree() -> void:
	_finishing = true
	if is_instance_valid(view):
		view.set("_closed", true)
		view.input_locked = true
		view.opponent_turn = Callable()
		view.command_filter = Callable()
	if e != null and e.pending != null:
		e.pending.continuation = Callable()
		e.pending = null


## A miss or a successful enemy save still teaches the action.
func _presented(events: Array[Dictionary]) -> void:
	if _finishing or completed or not is_inside_tree():
		return
	var ch := hero.creature as Character
	var healed_ally := false
	var ally_healing := 0
	var self_healing := 0
	for event in events:
		if str(event.get("type", "")) == "heal":
			if partner != null and str(event.get("id", "")) == partner.id:
				ally_healing += maxi(0, int(event.get("amount", 0)))
			if str(event.get("id", "")) == hero.id:
				self_healing += maxi(0, int(event.get("amount", 0)))
	for event in events:
		var kind := str(event.get("type", ""))
		if kind == "turn" and str(event.get("id", "")) == hero.id:
			_hero_turns += 1
			if _hero_turns == 1:
				view.hud.set_tab(ActionCatalog.SPELLS if lesson_id in ["combat_cantrip", "combat_heal", "combat_concentration"] else (view.catalog.class_tab(hero) if lesson_id == "combat_bonus" else ActionCatalog.COMMON))
		if lesson_id == "combat_move" and kind == "move" and str(event.get("id", "")) == hero.id and not bool(event.get("forced", false)) and not bool(event.get("undo", false)):
			_complete("You moved using your movement allowance. %d ft remain; your Action is %s." % [hero.movement_left, "still available" if hero.action_available else "already spent"])
		elif lesson_id == "combat_attack" and kind == "attack" and str(event.get("attacker", "")) == hero.id and not str(event.get("action", "")).begins_with("spell:"):
			_complete(("Your attack hit." if bool(event.get("hit", false)) else "Your attack missed. That is a valid outcome, not a mistake.") + " " + _last_roll() + " Open the combat log for the full calculation.")
		elif lesson_id == "combat_bonus" and kind == "ability" and str(event.get("by", "")) == hero.id and str(event.get("key", "")) == "second_wind" and not hero.bonus_available and ch.resource_left("second_wind") < _starting_wind:
			_complete("Second Wind restored %d HP and spent one use and your Bonus Action. It did not spend your Action." % self_healing)
		elif lesson_id == "combat_cantrip" and kind == "spell" and str(event.get("caster", "")) == hero.id and str(event.get("spell", "")) == "sacred_flame":
			_complete("Sacred Flame asked the target to make a Dexterity saving throw. The log shows whether it avoided the damage. Your level-1 slots remain %d; a cantrip costs no spell slot." % ch.slots_left(1))
		elif lesson_id == "combat_heal" and kind == "spell" and str(event.get("caster", "")) == hero.id and str(event.get("spell", "")) in ["cure_wounds", "healing_word"]:
			healed_ally = partner != null and partner.id in event.get("targets", [])
		elif lesson_id == "combat_concentration" and kind == "spell" and str(event.get("caster", "")) == hero.id and str(event.get("spell", "")) == "bless" and ch.concentration != null:
			_complete("Bless is active, and Liriel is concentrating on it. A slot was spent; %d level-1 slots remain. Taking damage can force a Constitution save to keep the spell." % ch.slots_left(1))
		elif lesson_id == "combat_practice" and kind == "over" and str(event.get("outcome", "")) == "victory":
			_complete("You won the practice battle using the same rules and controls as the campaign. Your campaign party and supplies are unchanged.")
	if lesson_id == "combat_heal" and healed_ally and ally_healing > 0 and ch.slots_left(1) < _starting_slots:
		_complete("Ilse recovered %d HP. Liriel spent a level-1 spell slot: %d remain. Cure Wounds uses an Action; Healing Word uses a Bonus Action." % [ally_healing, ch.slots_left(1)])
	if lesson_id == "combat_end_turn" and _hero_turns >= 2:
		_complete("The sparring partner took a turn and yours began again. Your movement, Action, Bonus Action and Reaction have refreshed. Limited abilities and spell slots need rest instead.")
	if lesson_id == "combat_reaction" and _reaction_seen:
		for i in range(_log_seen, e.log.entries.size()):
			var entry := e.log.entries[i]
			if str(entry.get("kind", "")) == "reaction" and str(entry.get("actor", "")) == hero.id and (str(entry.get("text", "")).contains("uses its Reaction") or str(entry.get("text", "")).contains("holds its Reaction")):
				_reaction_answered = true
				_complete("You answered a real Opportunity Attack prompt. " + str(entry["text"]) + ". Reactions are optional; a spent Reaction returns when your next turn starts.")
	_log_seen = e.log.entries.size()


func _last_roll() -> String:
	for i in range(e.log.entries.size() - 1, -1, -1):
		var entry := e.log.entries[i]
		if str(entry.get("kind", "")) in ["hit", "miss"] and str(entry.get("text", "")).begins_with(hero.name()) and str(entry.get("text", "")).contains("vs AC"):
			return str(entry["text"])
	return ""


func _complete(feedback: String) -> void:
	if completed or _finishing or not is_inside_tree():
		return
	completed = true
	objective_met.emit(feedback)


func _cell_rect(cell: Vector2i) -> Rect2:
	if rig == null or board == null:
		return Rect2()
	var center := board.cell_center(cell)
	if rig.camera.is_position_behind(center):
		return Rect2()
	var points: Array[Vector3] = [center + Vector3(-0.45, 0.05, -0.45), center + Vector3(0.45, 0.05, -0.45), center + Vector3(0.45, 1.5, 0.45), center + Vector3(-0.45, 1.5, 0.45)]
	var rect := Rect2(rig.camera.unproject_position(points[0]), Vector2.ZERO)
	for point in points:
		rect = rect.expand(rig.camera.unproject_position(point))
	return rect.grow(8.0).intersection(get_viewport().get_visible_rect())


func anchor_rect() -> Rect2:
	if view == null or view.hud == null:
		return Rect2()
	if lesson_id == "combat_reaction" and view.hud.prompt_open():
		return view.hud.coach_anchor("reaction")
	if e.current() != null and e.current().is_player_controlled() and e.current() != hero and lesson_id != "combat_practice":
		return view.hud.coach_anchor("end_turn")
	if completed:
		return view.hud.coach_anchor("log")
	if lesson_id == "combat_move":
		return _cell_rect(Vector2i(4, 3))
	if view.mode == CombatView.Mode.TARGET:
		return _cell_rect(partner.cell if lesson_id == "combat_heal" and partner != null else (hero.cell if lesson_id == "combat_concentration" else opponent.cell))
	var key := str(description().get("anchor", ""))
	var action := {"combat_attack": "attack:weapon:greatsword", "combat_bonus": "second_wind", "combat_cantrip": "spell:sacred_flame", "combat_heal": "spell:cure_wounds", "combat_concentration": "spell:bless"}
	return view.hud.coach_anchor(key, str(action.get(lesson_id, "")))


func description() -> Dictionary:
	var lessons := {
		"combat_orientation": {
			"read_only": true,
			"title": "Your first combat turn",
			"body": "Combat pauses for decisions. The portraits across the top show initiative: the order rolled to decide who acts. The active hero is the character whose turn you control.",
			"objective": "Find your hero, their HP and the turn order, then continue.",
			"details": "HP means Hit Points: how much harm a creature can take. AC means Armor Class: the number most attacks must meet to hit. The hotbar shows actions; its shapes track your Action, Bonus Action and Reaction. Movement is separate. Party members next to each other in initiative may share a turn if that setting is enabled. You control every party member.",
			"anchor": "turn_order"
		},
		"combat_move": {
			"title": "Move before you strike",
			"body": "One square is 5 feet. Move to an empty space to get closer, take cover or leave room for a friend. You can split movement before and after an Action.",
			"objective": "Move Ilse to the highlighted square.",
			"details": "Point at the ground to preview a route, then confirm it. On a controller, move the battlefield cursor and confirm. Watch the movement allowance change. Difficult terrain costs more movement. Moving out of an enemy's melee reach can provoke an Opportunity Attack; Disengage prevents most of these attacks.",
			"anchor": "movement"
		},
		"combat_attack": {
			"title": "A d20 decides whether you hit",
			"body": "Choose Greatsword from the Common actions, then select the sparring partner beside Ilse. The game rolls a twenty-sided die, adds the attack bonus, and compares the result with the target's AC.",
			"objective": "Make one weapon attack. A hit or a miss completes the lesson.",
			"details": "An attack total equal to or above AC normally hits. A natural 1 misses and a natural 20 is a critical hit. Damage is a separate roll: it reduces HP. The attack spends your Action; it does not spend your remaining movement. Advantage rolls two d20s and keeps the higher; Disadvantage keeps the lower. The log explains the actual roll and modifiers.",
			"anchor": "action"
		},
		"combat_bonus": {
			"title": "A Bonus Action has its own job",
			"body": "Ilse begins this exercise wounded. Her fighter ability Second Wind can restore HP with a Bonus Action. It also has a limited number of uses.",
			"objective": "Use the highlighted Second Wind ability.",
			"details": "A Bonus Action is not a second unrestricted Action. You need an ability or spell that specifically uses one. Second Wind rolls healing through the usual rules and uses one of its charges. You can still take your ordinary Action afterward. You do not have to spend every resource before ending a turn.",
			"anchor": "action"
		},
		"combat_end_turn": {
			"title": "Pass the turn",
			"body": "When you are finished, end your turn. The sparring partner will take a harmless turn, then control returns to you. No decision here has a time limit.",
			"objective": "Use End Turn and confirm if asked about an unused Action.",
			"details": "Movement, your Action, Bonus Action and Reaction refresh when your next turn begins. Spell slots and limited abilities do not all return each turn. The turn order helps you see who acts next. In this exercise the partner Dodges instead of attacking.",
			"anchor": "end_turn"
		},
		"combat_reaction": {
			"title": "React outside your turn",
			"body": "The partner will move away from Ilse without Disengaging. Leaving her melee reach gives her an optional Opportunity Attack using her Reaction.",
			"objective": "End Ilse's turn if needed, then choose whether to take the Opportunity Attack.",
			"details": "Answer the real reaction prompt. Either choice completes this exercise. If you use the Reaction, it is unavailable until your next turn starts. Other abilities can use a Reaction too, so saving it can be sensible. Forced movement and teleportation usually do not provoke. Keep this prompt on Ask while learning.",
			"anchor": "end_turn"
		},
		"combat_cantrip": {
			"title": "A cantrip and a saving throw",
			"body": "Liriel is a cleric. Sacred Flame is a cantrip: she can cast it without spending a spell slot. Its target makes a Dexterity saving throw instead of Liriel rolling to hit AC.",
			"objective": "Select Sacred Flame in Spells and cast it on the sparring partner.",
			"details": "A saving throw is the target's attempt to resist danger: d20 plus its relevant save bonus against a Difficulty Class, or DC. Sacred Flame deals damage only when that save fails. A successful enemy save still completes the lesson. Other spells can use attack rolls; their tooltips explain which. A cantrip still spends its listed Action or Bonus Action.",
			"anchor": "action"
		},
		"combat_heal": {
			"title": "Spend a spell slot to heal",
			"body": "Ilse is wounded. On Liriel's turn, choose Cure Wounds from Spells and target Ilse beside her. The healing and spell-slot cost use the same rules as the campaign.",
			"objective": "Have Liriel cast Cure Wounds on Ilse. If Ilse acts first, end her turn.",
			"details": "Cure Wounds uses an Action and requires touch range. Healing Word works at range and uses a Bonus Action. Both spend a level-1 spell slot. Spell level describes a spell's power; it is different from character level. You can spend only one spell slot on a spell during a turn. You also control Ilse: if it is her turn, end it to continue with Liriel.",
			"anchor": "action"
		},
		"combat_concentration": {
			"title": "Keep one spell going",
			"body": "Bless improves attack rolls and saving throws while Liriel concentrates. Select Bless, choose Liriel as a target, then confirm the selected targets. You may choose fewer than the spell's maximum.",
			"objective": "Cast Bless and begin concentrating on it.",
			"details": "You can concentrate on only one spell at a time. Starting another concentration spell ends the first; taking damage can force a Constitution saving throw to keep it. Being Incapacitated ends concentration. It does not use a new Action every turn. Bless adds a d4 to eligible rolls while it lasts; it does not guarantee success.",
			"anchor": "action"
		},
		"combat_practice": {
			"free_practice": true,
			"title": "Put it together",
			"body": "Guide Ilse and Liriel through a small practice battle. This partner now uses the normal enemy AI. Move, attack, cast or heal, and end each hero's turn when ready.",
			"objective": "Win the practice battle. Retry from the tutorial menu if the party falls.",
			"details": "Read range, HP and available resources before choosing. Use cantrips when saving spell slots; use healing when it helps. At zero HP a hero can fall Unconscious and make death saves: healing can bring them back. The log, tooltips and character sheets explain outcomes. You can repeat any lesson, and none of these practice results affect your campaign.",
			"anchor": "party"
		}
	}
	return (lessons[lesson_id] as Dictionary).duplicate(true)


func _process(_delta: float) -> void:
	if lesson_id == "combat_orientation" and not completed and view != null and view.mode == CombatView.Mode.IDLE:
		_complete("Find your portrait, movement allowance, and Action, Bonus Action and Reaction indicators. Continue when you are ready to try them.")


func is_guided() -> bool:
	return lesson_id != "combat_practice"


func _guided_action_id() -> String:
	return str({"combat_attack": "attack:weapon:greatsword", "combat_bonus": "second_wind", "combat_cantrip": "spell:sacred_flame", "combat_heal": "spell:cure_wounds", "combat_concentration": "spell:bless"}.get(lesson_id, ""))


func _guided_target() -> Combatant:
	if lesson_id == "combat_heal":
		return partner
	if lesson_id == "combat_concentration":
		return hero
	return opponent


func guide_state() -> Dictionary:
	var state := {"guided": is_guided(), "step": "wait", "hint": "Watch the result.", "rects": [] as Array[Rect2], "coach_action": ""}
	if not is_guided() or view == null or view.hud == null:
		return state
	if completed:
		state["step"] = "complete"
		return state
	if view.mode == CombatView.Mode.PROMPT:
		state["step"] = "reaction"
		state["hint"] = "Choose Use Reaction or Skip. Either answer is valid."
		state["rects"] = view.hud.coach_rects("reaction_choices")
		return state
	if view.mode == CombatView.Mode.BUSY or e.current() == null:
		return state
	if e.current() != hero or lesson_id in ["combat_end_turn", "combat_reaction"]:
		var checking := view.hud.confirm_open()
		state["step"] = "end_confirm" if checking else "end_turn"
		state["hint"] = "Confirm End turn. Unused actions are allowed." if checking else "Choose End Turn, or press {combat_end_turn}."
		state["hint_pad"] = "Confirm with {a}." if checking else "Use {@combat_end_turn} to end the turn."
		state["rects"] = view.hud.coach_rects("end_confirm" if checking else "end_turn")
		return state
	if lesson_id == "combat_orientation":
		state["step"] = "observe"
		return state
	if lesson_id == "combat_move":
		state["step"] = "move"
		state["hint"] = "Click the highlighted square, or confirm the controller cursor there."
		state["hint_pad"] = "The cursor starts on the highlighted square. Confirm with {@combat_confirm}."
		(state["rects"] as Array[Rect2]).append(_cell_rect(Vector2i(4, 3)))
		return state
	if view.mode == CombatView.Mode.TARGET:
		if lesson_id == "combat_concentration" and hero in view.picked:
			state["step"] = "confirm_spell"
			state["hint"] = "Liriel is selected. Confirm the spell to cast Bless on her."
			state["coach_action"] = "confirm_bless"
			state["hint_pad"] = "Confirm with {a}, or use {@combat_end_turn} to cast with the selected target."
		else:
			state["step"] = "target"
			state["hint"] = "Choose the highlighted target: %s." % _guided_target().name()
			state["hint_pad"] = "Choose the highlighted target with {@combat_confirm}."
			(state["rects"] as Array[Rect2]).append(_cell_rect(_guided_target().cell))
		return state
	state["step"] = "menu" if view.hud.menu_open() else "action"
	state["hint"] = "Choose the highlighted option." if view.hud.menu_open() else "Choose the highlighted hotbar action."
	state["hint_pad"] = "Use {@combat_use_slot} for the highlighted hotbar action." if not view.hud.menu_open() else "Choose the highlighted option with {a}."
	state["rects"] = view.hud.coach_rects("action", _guided_action_id())
	return state


func confirm_guided_cast() -> void:
	if str(guide_state()["step"]) == "confirm_spell":
		view.confirm_early()


func allows_command(command: String, data: Dictionary = {}) -> bool:
	if not is_guided():
		return true
	if view == null or view.input_locked or not view.can_process():
		return false
	var step := str(guide_state()["step"])
	if command == "input":
		return _guided_input(data["event"] as InputEvent, step)
	if completed or _finishing:
		return false
	match command:
		"choose", "perform":
			if step not in ["action", "menu", "target", "confirm_spell"]:
				return false
			if command == "choose" and step not in ["action", "menu"]:
				return false
			var action := data.get("action", {}) as Dictionary
			if str(action.get("id", "")) != _guided_action_id() or action.has("policy"):
				return false
			var canonical := view.catalog.find(hero, _guided_action_id())
			if canonical.is_empty() or str(action.get("kind", "")) != str(canonical["kind"]):
				return false
			if int(data.get("level", 0)) not in [0, 1]:
				return false
			if command == "perform":
				var targets := data.get("targets", []) as Array
				return targets.is_empty() if lesson_id == "combat_bonus" else targets.size() == 1 and targets[0] == _guided_target()
			return true
		"board":
			if step == "move":
				return data.get("cell", Vector2i(-1, -1)) == Vector2i(4, 3)
			return step == "target" and data.get("target") == _guided_target()
		"target":
			return step == "target" and data.get("target") == _guided_target()
		"confirm_spell":
			return step == "confirm_spell"
		"end_turn":
			return step in ["end_turn", "end_confirm"]
		"reaction":
			return step == "reaction"
	return false


func _guided_input(event: InputEvent, step: String) -> bool:
	if event is InputEventMouseMotion or event is InputEventJoypadMotion:
		return true
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if event.is_action_pressed(&"pause_menu") or event.is_action_pressed(&"combat_cancel"):
		return true
	if step in ["menu", "reaction", "end_confirm"]:
		for action: StringName in [&"ui_accept", &"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev"]:
			if event.is_action(action):
				return true
	if event.is_action_pressed(&"combat_confirm"):
		return step in ["move", "target", "confirm_spell", "end_confirm", "reaction"]
	if event.is_action_pressed(&"combat_end_turn"):
		return step in ["end_turn", "end_confirm", "confirm_spell"]
	if step in ["action", "menu"]:
		if event.is_action_pressed(&"combat_use_slot"):
			return true
		for index in 10:
			if event.is_action_pressed(StringName("combat_slot_%d" % (index + 1))):
				return true
	return false
