class_name TestChars
extends RefCounted
## Builders for tests: pregenerated characters at any level, bare dummies with set Hit Points, seeds that
## make the next d20 come up a chosen number, and an "auto-pick" that fills every choice with the first
## legal options (to prove every class and subclass can be built and levelled without dead ends).


## A pregenerated character levelled to `level` by its level plan.
static func pregen(id: String, level: int = 1) -> Character:
	var errors: Array[String] = []
	var ch := Pregens.build(id, level, errors)
	assert(ch != null, "pregen %s: %s" % [id, errors])
	return ch


## A plain humanoid with `hp` Hit Points and all scores 10 (Con can be set). Monsters die at 0 HP;
## pass death_saves = true to make it behave like a character.
static func dummy(hp: int, death_saves: bool = false, extra: Dictionary = {}) -> Monster:
	var data := {"id": "dummy", "name": "Dummy", "size": "medium", "type": "humanoid", "ac": 12,
		"hp": {"average": hp, "dice": "1"}, "speed": {"walk": 30},
		"abilities": {"str": 10, "dex": 10, "con": int(extra.get("con", 10)), "int": 10, "wis": 10, "cha": 10},
		"cr": 1, "actions": []}
	for k: String in extra:
		if k != "con":
			data[k] = extra[k]
	var m := Monster.from_data(data)
	m.uses_death_saves = death_saves
	return m


## The first seed whose first d20 roll equals `value` (deterministic search).
static func seed_for_d20(value: int) -> int:
	for s in range(1, 5000):
		var d := DiceRoller.new(s)
		if d.d20() == value:
			return s
	assert(false, "no seed gives %d" % value)
	return 0


## Fills incomplete choices one at a time with legal picks (preferring options without warnings),
## re-reading the choices after each pick because one pick can change another's options.
## `get_pending` returns Array[Choice]; `choose(key, picks)` stores picks. Returns keys it couldn't fill.
static func auto_pick(get_pending: Callable, choose: Callable) -> Array[String]:
	var stuck: Array[String] = []
	var tried := {}
	for guard in 200:
		var pending := get_pending.call() as Array[Choice]
		var c: Choice = null
		for p in pending:
			if not tried.has(p.key):
				c = p
				break
		if c == null:
			break
		tried[c.key] = true
		var picks: Array = c.picks.duplicate()
		var good: Array[String] = []
		var weak: Array[String] = []
		for o in c.options:
			if o.legal and not o.id in picks:
				if o.warning == "":
					good.append(o.id)
				else:
					weak.append(o.id)
		var pool: Array[String] = good + weak
		if c.kind == "ability_increase":
			while picks.size() < c.count and not pool.is_empty():
				picks.append(pool[0])
				if picks.count(pool[0]) >= c.per_ability:
					pool.pop_front()
		else:
			for id in pool:
				if picks.size() >= c.count:
					break
				picks.append(id)
		if picks.size() < c.count:
			stuck.append("%s (%d of %d)" % [c.key, picks.size(), c.count])
		choose.call(c.key, picks)
	return stuck


## A character built and levelled to `level` in one class, with chosen picks for any choice whose key ends with a
## key of `picks` ("fighter_subclass": ["battle_master"], "combat_superiority": ["trip_attack", ...]); the rest is
## filled with the first legal options.
static func custom(class_id: String, species: String, level: int, picks: Dictionary = {}, background: String = "soldier") -> Character:
	var b := CharacterBuilder.new()
	b.set_class(class_id)
	b.set_background(background)
	b.set_species(species)
	b.set_name("Test %s" % class_id.capitalize())
	b.apply_recommended_scores()
	_apply_picks(b.pending_choices, b.choose, picks)
	auto_pick(b.pending_choices, b.choose)
	var ch := b.build_character()
	assert(ch != null, "custom %s %s: %s" % [class_id, species, b.errors()])
	while ch.character_level() < level:
		var up := LevelUpController.new(ch)
		up.choose_class(class_id)
		up.take_fixed_hit_points()
		_apply_picks(up.pending_choices, up.choose, picks)
		auto_pick(up.pending_choices, up.choose)
		assert(up.confirm(), str(up.errors()))
	ch.finish_long_rest()
	return ch


static func _apply_picks(get_pending: Callable, choose: Callable, picks: Dictionary) -> void:
	for guard in 6:
		var did := false
		for c in get_pending.call() as Array[Choice]:
			for k: String in picks:
				if c.key.ends_with(k) and c.picks.is_empty():
					choose.call(c.key, picks[k])
					did = true
		if not did:
			return
