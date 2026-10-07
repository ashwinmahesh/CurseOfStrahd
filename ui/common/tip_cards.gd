class_name TipCards
extends CanvasLayer
## U1's hover-and-pin layer, above every screen and HUD (plan §5.6: every number explains itself, and rule terms open
## nested tooltips that can be pinned, as in Baldur's Gate 3). Resting the pointer on a control with a rich tooltip
## (UiParts' drawn, tipped and tip-button controls, or any control with a "tip_card" meta Callable) or on a gilded
## word (TermText) opens a TipCard beside it. At first the card is a plain tooltip that the pointer passes through, so
## sweeping down a list reads one row after another; resting a moment longer settles it, and then the pointer can cross
## onto it to rest on the gilded words inside, which open further cards beside it, a chain as deep as you like. The
## chain closes once the pointer has left it and its source. Clicking a gilded word, middle-clicking, or the pin in a
## card's top edge pins a card: it stays open, wherever it's dragged, until its cross or a right-click closes it.
## UiFeel makes one at start; `current` is it.

static var current: TipCards = null

## Seconds the pointer rests before a card opens: on a control, on a gilded word, and on the next control while a
## card was just showing (moving along a row of values reads one after another, as tooltips do).
const OPEN_DELAY := 0.45
const TERM_DELAY := 0.3
const WARM_DELAY := 0.12
## How long a settled card waits for the pointer to come back after it leaves (crossing the gap from a word to its
## card), how long one that hasn't settled waits, and how long the pointer rests on the source to settle it.
const GRACE := 0.3
const QUICK := 0.05
const SETTLE := 0.6
const MAX_PINS := 6
const EDGE := 8.0

## Every open card, oldest first; pinned ones included.
var cards: Array[TipCard] = []
## Freezes the pointer's part: cards open and close only when asked (captures, whose window has no pointer of its own).
var hold := false

var _pending: Dictionary = {}
var _pending_for := 0.0
var _warm := 0.0
var _last_mouse := Vector2.ZERO


func _init() -> void:
	name = "TipCards"
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _process(delta: float) -> void:
	var vp := get_viewport()
	if vp == null or hold:
		return
	var mouse := vp.get_mouse_position()
	var hovered := vp.gui_get_hovered_control()
	var under := _card_under(hovered, mouse)
	var src := source_at(hovered)
	_warm = maxf(0.0, _warm - delta)
	# Forget cards whose source went away (a screen rebuilt or closed under them).
	for c: TipCard in cards.duplicate():
		if not c.pinned and (c.source == null or not is_instance_valid(c.source) or not c.source.is_visible_in_tree()):
			_close(c)
	# Keep alive the card under the pointer, the card of what the pointer rests on, and the cards that led to them.
	var alive := {}
	_mark(under, alive)
	var showing := _card_for(src)
	_mark(showing, alive)
	var heading := _heading_to_card(mouse)
	for c: TipCard in cards.duplicate():
		if not is_instance_valid(c) or not c in cards:
			continue
		if c.pinned or alive.has(c):
			c.away = 0.0
			if not c.settled:
				c.settling(c.settle_t + delta, SETTLE)
			continue
		# A pointer on its way across to a settled card keeps it, so the controls it passes over don't replace it.
		if heading == c and c.settled:
			continue
		c.away += delta
		if c.away > (GRACE if c.settled else QUICK):
			_close(c)
	_last_mouse = mouse
	# Open the card of what the pointer rests on, once it has rested long enough.
	if src.is_empty() or showing != null:
		_pending = {}
		_pending_for = 0.0
		return
	if heading != null and heading != under:
		return
	if _pending.get("key", "") != src["key"] or _pending.get("control") != src["control"]:
		_pending = src
		_pending_for = 0.0
	_pending_for += delta
	var need := TERM_DELAY if str(src.get("term", "")) != "" else OPEN_DELAY
	if _warm > 0.0 and under == null:
		need = WARM_DELAY
	if _pending_for >= need:
		open_card(src, mouse)
		_pending = {}


## A middle-click on what a card was opened from pins that card (a click on the card itself is the card's own).
func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_MIDDLE:
		return
	var vp := get_viewport()
	var hovered := vp.gui_get_hovered_control()
	if _card_under(hovered, vp.get_mouse_position()) != null:
		return
	var showing := _card_for(source_at(hovered))
	if showing != null:
		toggle_pin(showing)
		vp.set_input_as_handled()


## What the pointer rests on, from the hovered control up: a gilded word, or the nearest control with a rich tooltip
## ({key, control, term} or {key, control, tip}); {} for nothing. Inside a card only gilded words count.
static func source_at(hovered: Control) -> Dictionary:
	var n: Node = hovered
	while n != null and n is Control:
		var tt := n as TermText
		if tt != null and tt.hovered_term != "":
			return {"key": "term:" + tt.hovered_term, "control": tt, "term": tt.hovered_term}
		if n is TipCard:
			return {}
		var tip := tip_of(n as Control)
		if tip.is_valid():
			return {"key": "tip:%d" % n.get_instance_id(), "control": n, "tip": tip}
		n = n.get_parent()
	return {}


## A control's rich tooltip: the tip of UiParts' drawn, tipped and tip-button controls, or a "tip_card" meta Callable
## on any control (returning the card's content).
static func tip_of(c: Control) -> Callable:
	if c is UiParts.Drawn:
		return (c as UiParts.Drawn).tip
	if c is UiParts.Tipped:
		return (c as UiParts.Tipped).tip
	if c is UiParts.TipButton:
		return (c as UiParts.TipButton).tip
	if c.has_meta(&"tip_card"):
		return c.get_meta(&"tip_card") as Callable
	return Callable()


## Opens the card for `src` (from source_at) beside `at`; `parent` is the card holding the gilded word, if any.
## Cards outside that chain that aren't pinned close.
func open_card(src: Dictionary, at: Vector2, parent: TipCard = null) -> TipCard:
	var term := str(src.get("term", ""))
	var content: Control = null
	if term != "":
		if not Glossary.has(term):
			return null
		content = TipCard.term_content(term)
	else:
		var tip := src.get("tip", Callable()) as Callable
		content = tip.call() as Control if tip.is_valid() else null
	if content == null:
		return null
	if parent == null:
		parent = _card_holding(src.get("control") as Control)
	for c: TipCard in cards.duplicate():
		if not c.pinned and not _leads_to(c, parent):
			_close(c)
	var card := TipCard.new()
	card.setup(content, str(src["key"]), src.get("control") as Control, parent, term)
	card.pin_pressed.connect(func(k: TipCard) -> void: toggle_pin(k))
	card.close_pressed.connect(func(k: TipCard) -> void:
		Audio.sfx("unpin")
		_close(k))
	card.raised.connect(func(k: TipCard) -> void: move_child(k, -1))
	add_child(card)
	cards.append(card)
	_place(card, at, parent)
	if UiMotion.on():
		card.modulate.a = 0.0
		UiMotion.soon(card, func() -> void: UiMotion.tween_for(card).tween_property(card, "modulate:a", 1.0, 0.12), 1)
	card.resized.connect(func() -> void: _clamp(card))
	if parent == null:
		_warm = GRACE + 0.2
	return card


## Opens and pins the card of a gilded word that was clicked (or pins the one already showing for it).
func pin_term(term: String, from: Control) -> TipCard:
	for c in cards:
		if c.term == term and c.source == from and not c.pinned:
			toggle_pin(c)
			return c
	var card := open_card({"key": "term:" + term, "control": from, "term": term}, get_viewport().get_mouse_position())
	if card != null:
		toggle_pin(card)
	return card


func toggle_pin(card: TipCard) -> void:
	if card.pinned:
		Audio.sfx("unpin")
		_close(card)
		return
	Audio.sfx("pin")
	card.set_pinned(true)
	move_child(card, -1)
	var pins := cards.filter(func(c: TipCard) -> bool: return c.pinned)
	if pins.size() > MAX_PINS:
		_close(pins[0] as TipCard)


## Closes every card, pinned ones too (leaving the game for the title, a test cleaning up).
func clear() -> void:
	for c: TipCard in cards.duplicate():
		_close(c)


func pinned_count() -> int:
	return cards.filter(func(c: TipCard) -> bool: return c.pinned).size()


func _close(card: TipCard) -> void:
	cards.erase(card)
	for c: TipCard in cards.duplicate():
		if c.parent_card == card:
			if c.pinned:
				c.parent_card = null
			else:
				_close(c)
	if is_instance_valid(card):
		card.queue_free()


func _card_for(src: Dictionary) -> TipCard:
	if src.is_empty():
		return null
	for c in cards:
		if not c.pinned and c.key == str(src["key"]) and c.source == src.get("control"):
			return c
	return null


## The card the pointer is over: the hovered control's card, else the topmost card under the pointer.
func _card_under(hovered: Control, mouse: Vector2) -> TipCard:
	var n: Node = hovered
	while n != null:
		if n is TipCard:
			return n as TipCard
		n = n.get_parent()
	for i in range(cards.size() - 1, -1, -1):
		if cards[i].settled and cards[i].get_global_rect().has_point(mouse):
			return cards[i]
	return null


## The card a control sits in, if it sits in one.
func _card_holding(c: Control) -> TipCard:
	var n: Node = c
	while n != null:
		if n is TipCard:
			return n as TipCard
		n = n.get_parent()
	return null


static func _mark(card: TipCard, into: Dictionary) -> void:
	var c := card
	while c != null:
		into[c] = true
		c = c.parent_card


## Whether `c` is `target` or opened it, card by card.
static func _leads_to(c: TipCard, target: TipCard) -> bool:
	var t := target
	while t != null:
		if t == c:
			return true
		t = t.parent_card
	return false


## The unpinned card the pointer is moving toward (it got closer this frame), or null.
func _heading_to_card(mouse: Vector2) -> TipCard:
	if mouse.distance_to(_last_mouse) < 0.5:
		return null
	for i in range(cards.size() - 1, -1, -1):
		var c := cards[i]
		if c.pinned or not c.settled:
			continue
		var r := c.get_global_rect()
		if _gap(r, mouse) < _gap(r, _last_mouse) - 0.25:
			return c
	return null


static func _gap(r: Rect2, p: Vector2) -> float:
	var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return q.distance_to(p)


## Beside the pointer for a control's card; to the side of its parent card for a gilded word's.
func _place(card: TipCard, at: Vector2, parent: TipCard) -> void:
	var vp := get_viewport().get_visible_rect().size
	card.fit_height(vp.y - EDGE * 2.0)
	card.reset_size()
	var s := card.size
	var pos := at + Vector2(20, 22)
	if parent != null and is_instance_valid(parent):
		var pr := parent.get_global_rect()
		pos = Vector2(pr.end.x + 6.0, at.y - 30.0)
		if pos.x + s.x > vp.x - EDGE:
			pos.x = pr.position.x - s.x - 6.0
	elif pos.x + s.x > vp.x - EDGE:
		pos.x = at.x - s.x - 14.0
	if pos.y + s.y > vp.y - EDGE and parent == null and at.y - s.y - 14.0 >= EDGE:
		pos.y = at.y - s.y - 14.0
	card.position = pos
	_clamp(card)


## Keeps a card wholly on screen, scrolling its content when it's taller than the screen.
func _clamp(card: TipCard) -> void:
	if not is_instance_valid(card) or not card.is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	card.fit_height(vp.y - EDGE * 2.0)
	var p := card.position
	p.x = clampf(p.x, EDGE, maxf(EDGE, vp.x - card.size.x - EDGE))
	p.y = clampf(p.y, EDGE, maxf(EDGE, vp.y - card.size.y - EDGE))
	card.position = p
