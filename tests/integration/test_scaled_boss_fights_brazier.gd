extends FightSeriesCase
## The iron knight of the brazier room (Dungeon Expansion Plan C4, castle_ravenloft_brazier_room): a boss fight, so the
## full-ability pregens (PartyAutopilot.full; the fight is in FightSeriesCase.BOSS_FIGHTS) win it about 3 in 8 over seeds
## 1-8 on Balanced at level 10, the tests holding 2 to 4. The book's two iron golems (252 Hit Points each) lose the party in
## about three rounds however few Hit Points they are given (two at 40-90 each: 1 to 2 wins in 8, nearly everyone down every
## time), so one golem wakes, from the west alcove, at 300 Hit Points; the other knight is armour. The fight is started by
## a conversation (a blow at the brazier, the hourglass or a knight), so its speakers step aside, and it can always be
## avoided. Every fight finishes. Docs: docs/story/boss_fights.md.
##
## Retuned once (2026-10-19): the combat-rule commits that landed in batch 5 with C4 made the test party stronger (the same
## 230 Hit Points went from 4 and 3 wins to 4 and 7, the alcove start above the band). On those rules 280 to 330 Hit Points
## hold 2 to 4 from both starts (brazier 3, 3, 3, 2, 2; alcove 4, 3, 3, 3, 3 at 280, 300, 310, 320, 330), so 300 sits in the
## middle of the plateau. On the older rules (origin/main 74213a42d) the same 300 reads off the band: the knight was tuned
## to the rules it will be played under.

const SEEDS: Array = [1, 2, 3, 4, 5, 6, 7, 8]

## The four at the brazier's west side (a blow at the brazier or the hourglass), and at the west knight's alcove (a blow at it).
const AT_THE_BRAZIER: Array[Vector2i] = [Vector2i(18, 10), Vector2i(18, 9), Vector2i(18, 11), Vector2i(17, 10)]
const AT_THE_KNIGHT: Array[Vector2i] = [Vector2i(16, 7), Vector2i(17, 7), Vector2i(15, 7), Vector2i(16, 8)]


func before_each() -> void:
	speakers_step_aside = true
	prepare = Callable()


## Wins over seeds 1-8 between `low` and `high`.
func _held(level: int, at: Array[Vector2i], low: int, high: int) -> void:
	var wins := await _series("castle_ravenloft_brazier_room", 12, level, "brazier_golems", SEEDS, ["brazier_golems_awake"], [], [], at)
	assert_true(wins >= low, "brazier_golems at level %d is won at least %d times in 8 (%d)" % [level, low, wins])
	assert_true(wins <= high, "brazier_golems at level %d is lost at least %d times in 8 (%d)" % [level, 8 - high, wins])


## The iron knight, one golem at 300 Hit Points, from the brazier: 3 in 8 on the rules as they stand in batch 5.
func test_the_iron_knight_at_level_10_from_the_brazier() -> void:
	await _held(10, AT_THE_BRAZIER, 2, 4)


## And with the four standing at the knight's alcove, having struck it: 3 in 8.
func test_the_iron_knight_at_level_10_from_its_alcove() -> void:
	await _held(10, AT_THE_KNIGHT, 2, 4)


## The wax image the glyph raises on the western stair's landing (brazier_wax_strahd): a one-hit illusion, so it has no
## band (the plan): every fight finishes and the first blow that lands melts it, so the party wins them all. The four stand
## on the glyph's squares.
const ON_THE_GLYPH: Array[Vector2i] = [Vector2i(8, 10), Vector2i(7, 10), Vector2i(8, 9), Vector2i(7, 9)]


func test_the_wax_image_melts_at_the_first_blow_every_time() -> void:
	var wins := await _series("castle_ravenloft_brazier_room", 12, 10, "brazier_wax_strahd", SEEDS, ["brazier_glyph_woken"], [], [], ON_THE_GLYPH)
	assert_eq(wins, 8, "a wax image with one Hit Point doesn't beat a party")
