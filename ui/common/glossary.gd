class_name Glossary
extends RefCounted
## U1, one glossary behind every rules word the UI shows (plan §5.6: rule terms open nested tooltips that can be
## pinned). data/glossary/terms.json lists the terms in our own words; conditions borrow their text from
## data/conditions, and the standard actions, weapon properties and masteries theirs from ActionCatalog, so each text
## lives in one place. `bbcode()` gilds the first mention of every term in a text as a link that TermText and TipCards
## open and pin.

const PATH := "res://data/glossary/terms.json"
## The colour of a gilded word.
const LINK := "gilt_light"
## A word that can start a Title Case name before a term without making the pair a name of its own ("When Concentration
## ends", "Your Speed"): sentence starts are allowed anyway, these are the common ones mid-sentence.
const LEADS := ["A", "An", "The", "Your", "Its", "Their", "Each", "Every", "No"]

static var _terms: Dictionary = {}
static var _order: Array[String] = []
## phrase -> term id, for every phrase a term matches.
static var _phrases: Dictionary = {}
static var _regex: RegEx = null


static func _ensure() -> void:
	if _regex != null:
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var list: Array = (parsed as Dictionary).get("terms", []) as Array if parsed is Dictionary else []
	var phrases: Array[String] = []
	for v: Variant in list:
		var e := (v as Dictionary).duplicate(true)
		var id := str(e["id"])
		_borrow(e)
		_terms[id] = e
		_order.append(id)
		for p: Variant in e.get("match", [str(e.get("name", id))]) as Array:
			_phrases[str(p)] = id
			phrases.append(str(p))
	# Longest first, so "Temporary Hit Points" wins over "Hit Points" and "spell attack roll" over "attack roll".
	phrases.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var alts: Array[String] = []
	for p in phrases:
		alts.append(_escape_pattern(p))
	_regex = RegEx.create_from_string("(?<![A-Za-z0-9_'’\\-])(%s)(?![A-Za-z0-9_\\-])" % "|".join(alts))


## Fills in a term's name and text from where they're kept (`from`).
static func _borrow(e: Dictionary) -> void:
	var from := str(e.get("from", ""))
	if from == "":
		return
	var key := from.get_slice(":", 1)
	var text := ""
	match from.get_slice(":", 0):
		"condition":
			var c := Compendium.shared().condition_data(key)
			if not e.has("name"):
				e["name"] = str(c.get("name", key.capitalize()))
			text = str(c.get("text", ""))
		"action":
			text = str(ActionCatalog.ACTION_TEXT.get(key, ""))
		"property":
			text = str(ActionCatalog.PROPERTY_TEXT.get(key, ""))
		"mastery":
			text = str(ActionCatalog.MASTERY_TEXT.get(key, ""))
	if not e.has("text"):
		e["text"] = text


static func _escape_pattern(s: String) -> String:
	var out := ""
	for ch in s:
		out += ("\\" + ch) if ch in ".^$*+?()[]{}|\\/" else ch
	return out


static func has(id: String) -> bool:
	_ensure()
	return _terms.has(id)


## A term: {id, name, kind, text, here?, see?}; empty if there's no such term.
static func entry(id: String) -> Dictionary:
	_ensure()
	return _terms.get(id, {}) as Dictionary


## Every term id, in the file's order.
static func ids() -> Array[String]:
	_ensure()
	return _order.duplicate()


## The term a word names ("Prone", "Bonus Action"), by its matches, its name or its id; "" if none.
static func id_for(word: String) -> String:
	_ensure()
	if _phrases.has(word):
		return str(_phrases[word])
	var low := word.to_lower()
	for id: String in _order:
		if id == low.replace(" ", "_") or str((_terms[id] as Dictionary).get("name", "")).to_lower() == low:
			return id
	return ""


## Text escaped for a RichTextLabel with BBCode on.
static func escape(text: String) -> String:
	return text.replace("[", "[lb]")


## A gilded link to `id`, showing `shown` (the term's name by default).
static func link(id: String, shown: String = "") -> String:
	var name := shown if shown != "" else str(entry(id).get("name", id))
	return "[color=#%s][url=term:%s]%s[/url][/color]" % [Look.color(LINK).to_html(false), id, escape(name)]


## `text` as BBCode with the first mention of each term gilded as a link; terms in `skip` (a card's own) stay plain.
static func bbcode(text: String, skip: Array = []) -> String:
	_ensure()
	var out := ""
	var at := 0
	var seen := {}
	for m: RegExMatch in _regex.search_all(text):
		var phrase := m.get_string(1)
		var id := str(_phrases.get(phrase, ""))
		var s := m.get_start(1)
		var e := m.get_end(1)
		if id == "" or id in skip or seen.has(id) or not _fits(text, s, e, id):
			continue
		seen[id] = true
		out += escape(text.substr(at, s - at)) + link(id, phrase)
		at = e
	return out + escape(text.substr(at))


## The terms `text` mentions, in order (what bbcode() would gild).
static func found(text: String) -> Array[String]:
	_ensure()
	var out: Array[String] = []
	for m: RegExMatch in _regex.search_all(text):
		var id := str(_phrases.get(m.get_string(1), ""))
		if id != "" and not id in out and _fits(text, m.get_start(1), m.get_end(1), id):
			out.append(id)
	return out


## Whether a match is the term rather than part of a longer name: a term limited to `after` needs one of those just
## before it, one with `unless_next` mustn't have one of those just after it ("Heavy armor"), and a Title Case match next to another capitalised word ("Cone of Cold", "Flaming Sphere", "Heavy
## Armor") belongs to that name instead.
static func _fits(text: String, s: int, e: int, id: String) -> bool:
	var after := (_terms[id] as Dictionary).get("after", []) as Array
	if not after.is_empty():
		var ok := false
		for a: Variant in after:
			var lead := str(a)
			if s >= lead.length() and text.substr(s - lead.length(), lead.length()) == lead:
				ok = true
		if not ok:
			return false
	for n: Variant in (_terms[id] as Dictionary).get("unless_next", []) as Array:
		if text.substr(e, str(n).length()) == str(n):
			return false
	var first := text.substr(s, 1)
	if first != first.to_upper() or first == first.to_lower():
		return true
	var rest := text.substr(e, 4)
	if rest.length() >= 2 and rest[0] == " " and _capital(rest[1]):
		return false
	if rest.begins_with(" of") and text.length() > e + 4 and text[e + 3] == " " and _capital(text.substr(e + 4, 1)):
		return false
	if s >= 2 and text[s - 1] == " ":
		var w_end := s - 1
		var w_start := w_end
		while w_start > 0 and text[w_start - 1] != " " and text[w_start - 1] != "\n":
			w_start -= 1
		var word := text.substr(w_start, w_end - w_start)
		if word != "" and _capital(word[0]) and word.is_valid_identifier() and not word in LEADS:
			# A capitalised word mid-sentence makes the pair a name; at the start of a sentence it's just a capital.
			var before := text.substr(0, w_start).strip_edges()
			if before != "" and not before[before.length() - 1] in [".", "!", "?", ":", ";", "(", "\"", "“"]:
				return false
	return true


static func _capital(ch: String) -> bool:
	return ch != "" and ch == ch.to_upper() and ch != ch.to_lower()
