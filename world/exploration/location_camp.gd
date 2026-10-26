class_name LocationCamp
extends Node
## The party's camp on the map (F16, lane 24; docs/story/camp.md). A Long Rest wherever the place's own rest is risky
## (CampSite.makes_camp: the wild, a town's streets, a house, a dungeon) pitches it near the party, on the place's own
## map, so its weather, light, music and visitors stay the place's: the fire and its pieces among the place's props,
## the party, the companions waiting at camp and the story's guests round the fire, a mark over anyone who wants a
## word, and the camp's bar (CampBar). Walking up to someone starts the talk they want to have (CampTalk; one each in
## the evening and one in the morning), or the Narrator says what they're doing. Sleeping is the Long Rest (LongRest),
## and Strahd may come in the night; the morning offers the change of prepared spells; breaking camp packs it away and
## the party falls in behind its leader again. The camp goes with the place: leaving it, or anything that builds the
## place again, ends it. Indoors (CampSite.setting) there's no tent, and in town or indoors the Narrator and the
## night's visitors are the setting's own.

const NAME := "Camp"
## The mark over someone who wants a word: the talk icon (a speech bubble).
const MARK_ICON := preload("res://art/ui/icons/talk.png")
## How big the camp's flame burns (a place's watch fire's), and how brightly its light glows against a watch fire's.
const FLAME := 0.6
const GLOW := 0.55

var view: LocationView
var root: Node
var center := Vector2i(-1, -1)
var rule := "risky"
## Where the camp is (CampSite.setting: wild, town or indoors): its pieces, the Narrator's lines and the night's visitors.
var setting := CampSite.WILD
## The night is over: it's morning at camp.
var slept := false
## Who has had their word this evening (once slept, this morning): character id -> true.
var had: Dictionary = {}
## Everyone at the fire: character id -> {character: Creature, token: CombatToken, cell: Vector2i,
## kind: "party" | "bench" | "guest", npc: the guest's npc id}.
var people: Dictionary = {}
## The talks waiting, by who asks (CampSite.talks): character id -> talk ref.
var talks: Dictionary = {}
## PrepareScreen.snapshot() as the night's rest ended: what the morning's change of prepared spells counts from.
var prepared_before: Dictionary = {}
var bar: CampBar
var _props: Array[String] = []
var _taken: Dictionary = {}
var _marks: Dictionary = {}          ## character id -> the mark over them
var _bench_tokens: Array[CombatToken] = []
var _roster_seen := ""
var _mode_seen := -1
## The Narrator's lines still to say, one after another as the box clears.
var _queue: Array[String] = []
var _flame: Node3D = null
var _struck := false


## The camp in `view_`, or null.
static func of(view_: Node) -> LocationCamp:
	return view_.get_node_or_null(NAME) as LocationCamp if view_ != null else null


## Makes camp near the party (a Long Rest where the place's rest is risky; `rule_` the rest's rule, safe or risky).
## Returns the camp, or null when no square the party can walk to will take a fire (the caller rests where the party
## stands, and says so).
static func pitch(view_: LocationView, root_: Node, rule_: String) -> LocationCamp:
	var existing := of(view_)
	if existing != null:
		return existing
	if view_ == null or view_.members.is_empty() or view_.in_combat:
		return null
	var taken := CampSite.things_at(view_.loc)
	for shown in view_._npc_shown:
		taken[shown["cell"] as Vector2i] = true
	var c := CampSite.find_center(view_.grid, view_.leader().cell, taken, _head_count(view_))
	if c.x < 0:
		return null
	var camp := LocationCamp.new()
	camp.name = NAME
	camp.view = view_
	camp.root = root_
	camp.rule = rule_
	camp.center = c
	camp.setting = CampSite.setting(view_.loc)
	camp._taken = taken
	view_.add_child(camp)
	camp._build()
	return camp


static func _head_count(view_: LocationView) -> int:
	return view_.st.party.size() + CampSite.company(view_.st).size() + view_.st.guests.size()


func _build() -> void:
	if view.planning:
		LocationPlan.stop(view)   # no rounds by the fire
	view._queue.clear()
	var lay := _layout()
	for p: Dictionary in lay["props"]:
		if setting != CampSite.WILD and str(p["kind"]) == "examine":
			p["say"] = "examine:%s:%s" % [p["id"], setting]   # the fire's light on walls or shutters, not on trees
		(view.loc.get_or_add("props", []) as Array).append(p)
		_props.append(str(p["id"]))
		view.prop_nodes[str(p["id"])] = LocationBuilder._prop_node(view, p)
	_light_fire()
	_seat(lay["seats"] as Array[Vector2i], lay["cook"] as Vector2i)
	bar = CampBar.new()
	bar.camp = self
	add_child(bar)
	_say_keys(CampSite.keys_for("camp:pitch", setting))
	_refresh_talks()


## The camp's pieces and seats round the fire (CampSite.layout): a tent only out of doors.
func _layout() -> Dictionary:
	return CampSite.layout(view.grid, center, _taken, _head_count(view), _cook_here(), setting != CampSite.INDOORS)


## Whether Ratatouille is at camp to cook (travelling or waiting there).
func _cook_here() -> bool:
	var everyone: Array[Character] = view.st.party.duplicate()
	everyone.append_array(CampSite.company(view.st))
	for ch in everyone:
		if ch.id == CampSite.COOK_ID and not ch.dead:
			return true
	return false


## The fire burning, with its light, as a place's own watch fire burns (LocationBuilder._flame; Atmosphere dresses the
## light as it joins): taller than the stone ring's own small flame.
func _light_fire() -> void:
	if not view.prop_nodes.has("camp_fire"):
		return
	_flame = LocationBuilder._flame(view, center, FLAME)
	# A cooking fire, not a watch fire: it lights the faces round it without blooming across the snow.
	for l in _flame.find_children("*", "CandleFlicker", true, false):
		(l as CandleFlicker).base_energy *= GLOW


# --- Who sits where ----------------------------------------------------------------------------------------------

## Seats everyone round the fire: the cook at the pot, then the party, the companions waiting at camp and the guests
## on the seats in order; each faces the fire. Figures for the companions at camp are the camp's own.
func _seat(seats: Array[Vector2i], cook: Vector2i) -> void:
	for t in _bench_tokens:
		if is_instance_valid(t):
			t.queue_free()
	_bench_tokens.clear()
	people.clear()
	view.st.camp_company = CampSite.company(view.st)
	var spots := seats.duplicate()
	var next := func(ch_id: String) -> Vector2i:
		if ch_id == CampSite.COOK_ID and cook.x >= 0:
			return cook
		if spots.is_empty():
			return view.leader().cell
		return spots.pop_front() as Vector2i
	for m in view.members:
		if m.creature.dead:
			continue   # the dead aren't up by the fire: no seat, and nobody to talk to
		var cell := next.call(m.id) as Vector2i
		_place(m, cell)
		people[m.id] = {"character": m.creature, "token": view.tokens[m.id], "cell": cell, "kind": "party"}
	for ch in view.st.camp_company:
		var cell2 := next.call(ch.id) as Vector2i
		var cb := Combatant.new(ch, &"party", cell2)
		var tok := CombatToken.create(cb)
		tok.position = view.board.cell_center(cell2)
		view.add_child(tok)
		tok.face(Vector2(center - cell2), false)
		_bench_tokens.append(tok)
		people[ch.id] = {"character": ch, "token": tok, "cell": cell2, "kind": "bench"}
	for i in view.guest_members.size():
		var g := view.guest_members[i]
		if LocationParty.is_follower(g):
			continue
		var cell3 := next.call(g.id) as Vector2i
		_place(g, cell3)
		var npc := view.st.guest_ids[view.st.guests.find(g.creature)] if view.st.guests.has(g.creature) else ""
		people[g.id] = {"character": g.creature, "token": view.tokens[g.id], "cell": cell3, "kind": "guest", "npc": npc}
	view._save_positions()
	_roster_seen = _roster_key()


func _place(m: Combatant, cell: Vector2i) -> void:
	m.cell = cell
	var tok := view.tokens.get(m.id, null) as CombatToken
	if tok == null:
		return
	tok.position = view.board.cell_center(cell)
	tok.face(Vector2(center - cell), false)


## Who's in the party, at camp and travelling with it, to notice a change (the roster screen, someone joining).
func _roster_key() -> String:
	var ids: Array[String] = []
	for ch in view.st.party:
		ids.append(ch.id)
	ids.append("|")
	for ch in view.st.bench:
		ids.append(ch.id + ("+" if ch.dead else ""))
	ids.append("|")
	ids.append_array(view.st.guest_ids)
	return ",".join(ids)


# --- What happens at camp ----------------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _struck or view == null or not is_instance_valid(view):
		return
	for t in _bench_tokens:
		if is_instance_valid(t):
			t.visible = not view.in_combat   # those at camp don't fight: they keep back from it
	for mark: Variant in _marks.values():
		if is_instance_valid(mark):
			(mark as Node3D).visible = not view.in_combat   # no asking for a word in the middle of a fight
	if view.in_combat:
		return
	if _roster_key() != _roster_seen:
		var lay := _layout()
		_seat(lay["seats"] as Array[Vector2i], lay["cook"] as Vector2i)
		_refresh_talks()
	var mode := int(ModeController.mode)
	if mode != _mode_seen:
		_mode_seen = mode
		if ModeController.mode == ModeController.Mode.EXPLORATION:
			_refresh_talks()   # a talk's choices, or the night, may have opened another
	_say_next()


## Looks again at who wants a word, and marks them.
func _refresh_talks() -> void:
	talks = CampSite.talks(view.st, had)
	for id: String in _marks.keys():
		var mark: Variant = _marks[id]
		var keep: bool = is_instance_valid(mark) and talks.has(id) and people.has(id) \
			and (people[id] as Dictionary)["token"] == (mark as Node).get_parent()
		if not keep:
			if is_instance_valid(mark):
				(mark as Node).queue_free()
			_marks.erase(id)
	for id: String in talks:
		if _marks.has(id) or not people.has(id):
			continue
		var tok := (people[id] as Dictionary)["token"] as CombatToken
		if tok == null or not is_instance_valid(tok):
			continue
		_marks[id] = _mark(tok)


## Takes every mark down. Those over the party and the guests hang on the view's own figures, which outlive the camp;
## the word itself waits, and its mark comes back at the next camp (CampSite.talks).
func _clear_marks() -> void:
	for mark: Variant in _marks.values():
		if is_instance_valid(mark):
			(mark as Node).queue_free()
	_marks.clear()


## The speech bubble over someone who wants a word (the talk icon, with a dark rim and an ellipsis in it), bobbing
## gently over their head.
func _mark(tok: CombatToken) -> Node3D:
	var mark := Node3D.new()
	mark.name = "WantsAWord"
	var top := CombatToken.height_of(tok.combatant) + 0.55
	mark.position = Vector3(0, top, 0)
	for layer: Array in [[0.0056, "void", 11], [0.0045, "parchment", 12]]:
		var sp := Sprite3D.new()
		sp.texture = MARK_ICON
		sp.pixel_size = float(layer[0])
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.no_depth_test = true
		sp.render_priority = int(layer[2])
		sp.modulate = Look.color(str(layer[1]))
		mark.add_child(sp)
	var dots := Label3D.new()
	dots.text = "…"
	dots.font_size = 56
	dots.pixel_size = 0.005
	dots.position = Vector3(0, 0.04, 0)
	dots.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dots.no_depth_test = true
	dots.render_priority = 13
	dots.modulate = Look.color("void")
	dots.outline_size = 0
	mark.add_child(dots)
	tok.add_child(mark)
	var bob := mark.create_tween().set_loops()
	bob.tween_property(mark, "position:y", top + 0.08, 0.7).set_trans(Tween.TRANS_SINE)
	bob.tween_property(mark, "position:y", top, 0.7).set_trans(Tween.TRANS_SINE)
	return mark


## Who is at camp on `cell` (not the leader, who is the one walking about): their id, or "".
func who_at(cell: Vector2i) -> String:
	var lead := view.leader()
	for id: String in people:
		var tok := (people[id] as Dictionary)["token"] as CombatToken
		if tok != null and is_instance_valid(tok) and tok.combatant.cell == cell and (lead == null or id != lead.id):
			return id
	return ""


## [figure, square] for each companion waiting at camp, for the mouse and the controller to point at (the party's
## and the guests' figures are the view's own).
func pickables() -> Array:
	var out: Array = []
	for t in _bench_tokens:
		if is_instance_valid(t) and t.visible:
			out.append([t, t.combatant.cell])
	return out


## A first name for the hover hint and the menu.
func first_name(id: String) -> String:
	var p := people.get(id, {}) as Dictionary
	return str((p["character"] as Creature).name).get_slice(" ", 0) if not p.is_empty() else ""


## The hover hint over someone at camp.
func label_for(id: String) -> String:
	return "%s wants a word" % first_name(id) if talks.has(id) else "Talk to %s" % first_name(id)


## Someone at camp asked over: the talk they want, if they have one, else what they're about.
func talk(id: String) -> void:
	if not people.has(id):
		return
	var p := people[id] as Dictionary
	var tok := p["token"] as CombatToken
	var lead := view.leader()
	if tok != null and lead != null:
		tok.face(Vector2(lead.cell - (p["cell"] as Vector2i)), false)
	var ref := str(talks.get(id, ""))
	if ref != "":
		CampTalk.mark(view.st, ref)
		had[id] = true
		_refresh_talks()
		view.dialogue_requested.emit(ref, "")
		return
	var guest := str(p["kind"]) == "guest"
	var who := str(p.get("npc", "")) if guest else id
	var text := ""
	for key in CampSite.idle_keys(who, guest, setting):
		if text != "":
			break
		var actor: Character = p["character"] as Character if p["character"] is Character else null
		text = view.narrator.line(key, view.st, actor, {"target": first_name(id)}) if view.narrator != null else ""
	if text == "":
		text = "%s sits by the fire." % first_name(id)
	view.narration.emit(text)


# --- The night and the morning ---------------------------------------------------------------------------------------

## Why the party can't sleep now (RestRules: the 16 hours since the last Long Rest), or "".
func sleep_refusal() -> String:
	if slept:
		return "Everyone has slept."
	var why := RestRules.long_rest_refusals(view.st)
	return " ".join(why)


## Sleeps the night by the fire: the Long Rest (LongRest.take), and whatever the night brings (night).
func sleep() -> void:
	if slept or view.in_combat or sleep_refusal() != "":
		return
	Audio.sfx("rest")
	night(LongRest.take(view.st, rule, Dice.roller))


## How the night at camp goes on from `res` (LongRest.take, or LongRest.resume once what broke it is over: game root
## `_sleep_again`). Whatever comes at the camp comes before the rest's benefits (the owner, 2026-10-13): something out
## of the dark (_night_visitors), or Strahd's visit that may come to blows (game root `visit_after_rest`); once it's
## over the party sleeps on by itself. With nothing to fight, or foes still about afterwards, nobody sleeps again (a
## Short Rest's benefits) and the party can try again later. A full night brings the morning, with the Narrator's
## lines for the night, a dream, and perhaps Strahd.
func night(res: Dictionary) -> void:
	match str(res.get("how", "")):
		LongRest.DARK:
			if not _night_visitors():
				_queue.append(str(LongRest.restless(view.st)["text"]))
			_refresh_root()
			return
		LongRest.STRAHD:
			_refresh_root()
			view.narration.emit(str(res["text"]))
			_visit_after(int(res["minutes"]))
			return
		LongRest.RESTLESS:
			_refresh_root()
			_queue.append(str(res["text"]))
			return
		LongRest.SLEPT:
			pass
		_:
			return
	slept = true
	had.clear()
	prepared_before = PrepareScreen.snapshot(view.st)
	view.st.morning["prepared"] = prepared_before
	_queue.append(str(res["text"]))
	for line: String in res["lines"]:
		_queue.append(line)
	var region := str(view.loc.get("region", ""))
	_say_keys(CampSite.night_keys(view.loc_id, region, setting))
	_say_keys(["dream:" + region])
	_say_keys(CampSite.keys_for("camp:morning", setting))
	_refresh_root()
	_refresh_talks()
	_visit_after(int(res["minutes"]))   # Strahd may come in the night (ADR 0014)


## The campaign's chance at the night just slept (or the visit that broke it): game root `visit_after_rest`.
func _visit_after(minutes: int) -> void:
	if root != null and root.has_method("visit_after_rest"):
		root.call_deferred("visit_after_rest", minutes)


## The night interrupted at camp: what comes out of the dark (CampSite.night_fight) falls on the camp, where everyone
## lies, before the rest's benefits. Once it's beaten the party sleeps on (game root `_sleep_again`). False if nothing
## came (the night just wasn't restful).
func _night_visitors() -> bool:
	var spec := CampSite.night_fight(view.grid, center, night_taken(), str(view.loc.get("region", "")), view.st.target_level(),
		Dice.roller, setting)
	if spec.is_empty():
		return false
	view.narration.emit(str(spec["text"]))
	return view.start_custom_encounter(spec)


## The squares the night's visitors can't come out of: the place's things and people, the camp's pieces and everyone
## at the fire. They may come out of an area a fight starts in (the camp keeps out of those): in a house that's often
## the only dark there is.
func night_taken() -> Dictionary:
	var taken := CampSite.things_at(view.loc, false)
	for shown in view._npc_shown:
		taken[shown["cell"] as Vector2i] = true
	for id in _props:
		var node := view.prop_nodes.get(id, null) as Node3D
		if node != null:
			taken[view.grid.cell_at(node.global_position)] = true
	for m: Combatant in view.members + view.guest_members:
		taken[m.cell] = true
	return taken


## Whether the camp's bar offers a change of prepared spells now: the morning's (as the rest screen offers it), or
## before the night the spells a Long Rest lets you change, any time outside a fight.
func can_prepare() -> bool:
	if view == null or view.in_combat:
		return false
	if slept:
		return not PrepareScreen.preparable(view.st).is_empty()
	return not PrepareScreen.preparable(view.st, PrepareScreen.ANYTIME).is_empty()


## What the camp's button says: "Change prepared spells" before the night, and after it all that the morning lets the party
## change ("Change prepared spells and Fiendish Resilience").
func prepare_label() -> String:
	if view == null or not slept:
		return "Change prepared spells"
	var names := PrepareScreen.change_names(view.st)
	return "Change %s" % PrepareScreen.change_words(names) if not names.is_empty() else "Change prepared spells"


## The morning's change of prepared spells (as the rest screen offers it), counted from the list the night ended with;
## before the night, the spells a Long Rest lets you change, as many as you like (PrepareScreen ANYTIME).
func prepare() -> void:
	if not can_prepare():
		return
	var ps := PrepareScreen.new()
	if slept:
		ps.earlier = prepared_before
	else:
		ps.rest_kind = PrepareScreen.ANYTIME
	bar.add_child(ps)
	ps.open(root, view.st, 0)


## Packs the camp away: its pieces and light go, the companions at camp with them, and the party falls in round its
## leader to walk on.
func strike() -> void:
	if _struck:
		return
	_struck = true
	var props := view.loc.get("props", []) as Array
	for i in range(props.size() - 1, -1, -1):
		if bool((props[i] as Dictionary).get("camp", false)):
			props.remove_at(i)
	for id in _props:
		var node := view.prop_nodes.get(id, null) as Node
		if node != null and is_instance_valid(node):
			node.queue_free()
		view.prop_nodes.erase(id)
	if _flame != null and is_instance_valid(_flame):
		_flame.queue_free()
	_clear_marks()
	for t in _bench_tokens:
		if is_instance_valid(t):
			t.queue_free()
	_bench_tokens.clear()
	view.st.camp_company.clear()
	# The party gathers on its leader, the guests behind, ready to walk on.
	var lead := view.leader()
	if lead != null:
		var cells := LocationParty._cells_around(view, lead.cell, view.members.size())
		for i in range(1, view.members.size()):
			_place(view.members[i], cells[i])
		view._save_positions()
		view.place_guests()
	_queue.clear()
	var lead_ch := lead.creature as Character if lead != null else null
	var said := ""
	for key in CampSite.keys_for("camp:strike", setting):
		if said == "" and view.narrator != null:
			said = view.narrator.line(key, view.st, lead_ch)
	if said != "":
		view.narration.emit(said)
	queue_free()


func _exit_tree() -> void:
	_clear_marks()
	if view != null and is_instance_valid(view) and view.st != null and of(view) == self:
		view.st.camp_company.clear()


## Queues the first of `keys` the Narrator has a line for.
func _say_keys(keys: Array[String]) -> void:
	if view.narrator == null:
		return
	var lead := view.leader()
	for key in keys:
		var text := view.narrator.line(key, view.st, lead.creature as Character if lead != null else null)
		if text != "":
			_queue.append(text)
			return


## Says the next queued line once the Narrator's box is clear and the party is simply exploring.
func _say_next() -> void:
	if _queue.is_empty() or root == null or ModeController.mode != ModeController.Mode.EXPLORATION:
		return
	var hud := root.get("hud") as ExploreHud if "hud" in root else null
	if hud == null:
		view.narration.emit(_queue.pop_front())
		return
	if hud.narration_showing() or root.get("screen") != null:
		return
	hud.narrate(_queue.pop_front())


func _refresh_root() -> void:
	if root != null and root.has_method("_refresh"):
		root.call("_refresh")
