extends TestCase
## Hover cards for items wait longer (Ashwin, 2026-10-28: "hover previews on items should appear 0.75 seconds later than
## now"): TipCards.open_delay adds ITEM_EXTRA_DELAY to an item's card, whether the pointer is fresh or moving along a row,
## and leaves every other card's delay as it was. An item's card is the `_item_card` function of LootWindow or the sheet.


func _item() -> Dictionary:
	return Compendium.shared().item_data("potion_of_healing")


func test_an_items_card_waits_longer_than_other_cards() -> void:
	var item_src := {"key": "tip:1", "tip": LootWindow._item_tip(_item())}
	assert_true(is_equal_approx(TipCards.open_delay(item_src, false), TipCards.OPEN_DELAY + 0.75), "a fresh pointer: 0.75 s more")
	assert_true(is_equal_approx(TipCards.open_delay(item_src, true), TipCards.WARM_DELAY + 0.75), "moving along a row: 0.75 s more too")
	var other := {"key": "tip:2", "tip": func() -> Control: return Control.new()}
	assert_eq(TipCards.open_delay(other, false), TipCards.OPEN_DELAY, "any other card as before")
	assert_eq(TipCards.open_delay(other, true), TipCards.WARM_DELAY)
	assert_eq(TipCards.open_delay({"key": "term:flanking", "term": "flanking"}, false), TipCards.TERM_DELAY, "a gilded word as before")


func test_both_item_cards_are_marked_and_still_make_their_card() -> void:
	var data := _item()
	var from_loot := LootWindow._item_tip(data)
	assert_eq(from_loot.get_method(), TipCards.ITEM_CARD)
	var sheet := CharacterSheetScreen.new()
	var from_sheet := sheet._item_tip(data)
	assert_eq(from_sheet.get_method(), TipCards.ITEM_CARD, "the character sheet's items too")
	for tip: Callable in [from_loot, from_sheet]:
		var card := tip.call() as Control
		assert_true(card != null, "the card is made")
		if card != null:
			assert_true(card.find_children("*", "Label", true, false).any(func(l: Node) -> bool: return str((l as Label).text).contains(str(data["name"]))),
				"and names the item")
			card.free()
	sheet.free()
