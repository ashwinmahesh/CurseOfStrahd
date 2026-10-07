class_name InCharacter
extends RefCounted
## Heroic Inspiration for playing in character (F15, docs/story/approval.md): a dialogue's `inspire <selector>` gives
## Heroic Inspiration to the party member the moment fits (name:thistle for a companion's own nature; background:,
## class:, species: or tag: so a custom hero earns it too; `party` for everyone, after a feast or a fellowship), the
## way the 2024 rules let a DM award it for acting true to a character. Someone who already has it passes it on (2024
## PHB): to the first party member in marching order who lacks it, since the moment can't stop to ask
## (docs/rules/deviations.md).


## Awards it. Returns the notice ("Thistle earns Heroic Inspiration: spoke her mind to the Baron"), or "" when nobody
## in the party fits or everyone already has it.
static func award(st: StoryState, selector: String, why: String = "") -> String:
	var reason := (": " + why) if why != "" else ""
	if selector == "party":
		return _award_party(st, reason)
	var who := _actor(st, selector)
	if who == null:
		return ""
	if not who.heroic_inspiration:
		who.heroic_inspiration = true
		return "%s earns Heroic Inspiration%s" % [_first(who), reason]
	for ch in st.party:
		if ch != who and not ch.dead and not ch.heroic_inspiration:
			ch.heroic_inspiration = true
			return "%s earns Heroic Inspiration%s, and already has it, so it passes to %s" % [_first(who), reason, _first(ch)]
	return ""


## `inspire party`: everyone living who lacks it ("Godrick, Thistle and Kip earn Heroic Inspiration: ...").
static func _award_party(st: StoryState, reason: String) -> String:
	var got: Array[String] = []
	for ch in st.party:
		if not ch.dead and not ch.heroic_inspiration:
			ch.heroic_inspiration = true
			got.append(_first(ch))
	if got.is_empty():
		return ""
	var names := got[0] if got.size() == 1 else "%s and %s" % [", ".join(got.slice(0, got.size() - 1)), got[got.size() - 1]]
	return "%s earn%s Heroic Inspiration%s" % [names, "s" if got.size() == 1 else "", reason]


## The first living party member the selector picks (StoryState.member_matches), in marching order.
static func _actor(st: StoryState, selector: String) -> Character:
	for ch in st.party:
		if not ch.dead and StoryState.member_matches(ch, selector):
			return ch
	return null


static func _first(ch: Character) -> String:
	return ch.name.get_slice(" ", 0)
