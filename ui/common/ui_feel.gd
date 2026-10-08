extends Node
## How the interface feels to use (autoload UiFeel): it holds the rules-card layer (TipCards, U1), ticks softly when
## the pointer comes onto a button (A4), puts a quill to the page when the journal gains an entry or the codex a book
## (A4), runs the tweens of screens that are closing (UiMotion.dismiss, G9), which outlive the screens themselves, and
## holds the controller's navigation of every screen (PadNav, U6).

## The softest gap between two hover ticks, so sweeping across a list doesn't rattle.
const TICK_GAP := 0.06
## How often the journal is checked for new entries.
const JOURNAL_EVERY := 0.4

var cards: TipCards
var pad: PadNav
var _last_hover: Control = null
var _tick_cool := 0.0
var _journal_cool := 0.0
var _journal_story: Object = null
var _journal_count := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cards = TipCards.new()
	add_child(cards)
	pad = PadNav.new()
	add_child(pad)
	EventBus.game_loaded.connect(func(_slot: String) -> void: _journal_count = -1)
	# Pinned cards belong to what you were reading: leaving for another scene (the title, a new game) clears them.
	EventBus.scene_changed.connect(func(_path: String) -> void: cards.clear())


func _process(delta: float) -> void:
	_tick_cool = maxf(0.0, _tick_cool - delta)
	var vp := get_viewport()
	var hovered := vp.gui_get_hovered_control() if vp != null else null
	if hovered != _last_hover:
		_last_hover = hovered
		var b := hovered as BaseButton
		if b != null and not b.disabled and _tick_cool <= 0.0:
			Audio.sfx("hover", 0.08)
			_tick_cool = TICK_GAP
	_journal_cool -= delta
	if _journal_cool <= 0.0:
		_journal_cool = JOURNAL_EVERY
		_watch_journal()


## A quill stroke when the journal gains an entry (a quest begins or moves on) or the codex a book. A save loaded or a
## new story only resets the count.
func _watch_journal() -> void:
	var st := GameState.story
	if st == null:
		return
	var n := st.codex.size()
	for q: Variant in st.quests.values():
		n += ((q as Dictionary).get("history", []) as Array).size()
	if st != _journal_story or _journal_count < 0:
		_journal_story = st
	elif n > _journal_count:
		Audio.sfx("quill", 0.04)
	_journal_count = n
