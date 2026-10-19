class_name Ruin
extends RefCounted
## A place that has fallen into ruin (catalog place_looks `ruin`; the vault's Natural Maps Plan, N7): the walls drawn
## there stand broken, not whole. `ruin` is how far, from 0 (the place is whole) to 1 (well fallen); `true` means 1.


## How far the place whose look is `look` has fallen into ruin (0 to 1).
static func amount(look: Dictionary) -> float:
	var v: Variant = look.get("ruin", 0.0)
	if v is bool:
		return 1.0 if bool(v) else 0.0
	return clampf(float(v), 0.0, 1.0)


## The stone a ruin's walls are laid in: the coursed stone the kit's yard walls use.
static func stone() -> Material:
	var s := Look.cel_textured(TownBuilder.STONE)
	return s if s != null else Look.cel("stone")
