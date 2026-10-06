class_name Formula
extends RefCounted
## Evaluates the small value expressions data uses (docs/contracts/modifiers.md):
## 3, "pb", "2*class_level+mod:int", "level/2", "-2*exhaustion".
## Terms: integer, pb, level, class_level, slot_level, exhaustion, mod:<ability>, score:<ability>,
## each optionally scaled as N*term or term/N (rounded down). The caller supplies the term values.


static func evaluate(value: Variant, ctx: Dictionary) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	var s := str(value).replace(" ", "")
	if s == "":
		return 0
	var total := 0
	var sign := 1
	var start := 0
	if s.begins_with("-"):
		sign = -1
		start = 1
	var term := ""
	for i in range(start, s.length() + 1):
		var c := s[i] if i < s.length() else "+"
		if c == "+" or c == "-":
			total += sign * _term(term, ctx)
			sign = 1 if c == "+" else -1
			term = ""
		else:
			term += c
	return total


## True if the value is a formula string (not a plain number), so the UI can show "2 × level".
static func is_formula(value: Variant) -> bool:
	return value is String and not (value as String).is_valid_int()


static func _term(t: String, ctx: Dictionary) -> int:
	var body := t
	var mult := 1
	var div := 1
	var star := body.find("*")
	if star >= 0:
		mult = int(body.substr(0, star))
		body = body.substr(star + 1)
	var slash := body.find("/")
	if slash >= 0:
		div = maxi(1, int(body.substr(slash + 1)))
		body = body.substr(0, slash)
	var base := 0
	if body.is_valid_int():
		base = int(body)
	elif ctx.has(body):
		base = int(ctx[body])
	else:
		push_error("Formula term '%s' has no value (in '%s')" % [body, t])
	return floori(float(mult * base) / div)
