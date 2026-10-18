extends TestCase
## Settings, Game, Attunement (a house option, Ashwin 2026-10-17): "Three at most" is the book's rule and the default;
## "Unlimited" drops attunement altogether. No limit of three, no "by a Wizard", and a magic item takes effect whenever
## it is worn, held or equipped. The choice is kept in the settings file (GameSettings) and told to the rules library
## (MagicItems.attunement_off); a save never holds it.

## Four items worn in four places that each need attunement: a Cloak of Protection (+1 AC), a Ring of Protection (+1 AC),
## an Amulet of Health (Constitution 19) and a Headband of Intellect (Intelligence 19).
const FOUR: Array[String] = ["cloak_of_protection", "ring_of_protection", "amulet_of_health", "headband_of_intellect"]


func after_each() -> void:
	GameSettings.set_unlimited_attunement(false)
	GameState.reset()


func _wearer() -> Character:
	var ch := TestChars.pregen("ilse_varga", 5)
	for id in FOUR:
		ch.add_item(id)
	return ch


func test_it_is_off_by_default_and_the_choice_reaches_the_rules() -> void:
	assert_false(GameSettings.unlimited_attunement(), "off")
	assert_false(MagicItems.attunement_off)
	GameSettings.set_unlimited_attunement(true)
	assert_true(GameSettings.unlimited_attunement())
	assert_true(MagicItems.attunement_off)
	var ring := Compendium.shared().item_data("ring_of_protection")
	assert_false(MagicItems.needs_attunement(ring), "no attunement needed with the option")
	assert_true(MagicItems.asks_attunement(ring), "though the item still asks for it in the book")
	GameSettings.set_unlimited_attunement(false)
	assert_true(MagicItems.needs_attunement(ring))


func test_three_at_most_is_the_rule_without_the_option() -> void:
	var ch := _wearer()
	for i in 3:
		assert_true(ch.attune(FOUR[i]), FOUR[i])
	assert_eq(ch.attune_blocker(FOUR[3]), "Already attuned to three items")
	assert_false(ch.attune(FOUR[3]))


func test_with_the_option_every_worn_item_works_unattuned() -> void:
	GameSettings.set_unlimited_attunement(true)
	var ch := _wearer()
	var ac := ch.ac_value()
	var con := ch.ability_score(&"con")
	for id in FOUR:
		assert_true(ch.wear(id), id)
	assert_true(ch.attuned.is_empty(), "nobody attuned to anything")
	assert_eq(ch.ac_value(), ac + 2, "the cloak's and the ring's +1")
	assert_eq(ch.ability_score(&"int"), 19, "the headband")
	assert_true(ch.ability_score(&"con") >= 19 and ch.ability_score(&"con") >= con, "the amulet")
	for id in FOUR:
		assert_true(ch.item_active(ch.entry_of(id)), "%s is working" % id)
	assert_eq(ch.attune_blocker("ring_of_protection"), "Doesn't need attunement")


func test_an_item_must_still_be_worn_to_work() -> void:
	GameSettings.set_unlimited_attunement(true)
	var ch := _wearer()
	var ac := ch.ac_value()
	assert_eq(ch.ac_value(), ac, "in the pack, nothing happens")
	assert_false(ch.item_active(ch.entry_of("cloak_of_protection")))
	ch.wear("cloak_of_protection")
	assert_eq(ch.ac_value(), ac + 1)
	ch.unequip_item("cloak_of_protection")
	assert_eq(ch.ac_value(), ac, "and again when it comes off")


func test_flipping_the_option_changes_what_is_working_at_once() -> void:
	var ch := _wearer()
	ch.wear("cloak_of_protection")
	var ac := ch.ac_value()
	GameSettings.set_unlimited_attunement(true)
	assert_eq(ch.ac_value(), ac + 1, "worn and unattuned, it works the moment the option is on")
	GameSettings.set_unlimited_attunement(false)
	assert_eq(ch.ac_value(), ac, "and stops when it is off again")


func test_while_attuned_bonuses_need_the_item_in_use_not_just_in_the_pack() -> void:
	# The Berserker Axe's extra Hit Points are "while attuned" and need no slot; without attunement they go with the axe in hand.
	var ch := TestChars.pregen("ilse_varga", 5)
	ch.add_item("berserker_axe__greataxe")
	var plain := ch.max_hp()
	GameSettings.set_unlimited_attunement(true)
	assert_eq(ch.max_hp(), plain, "in the pack, unattuned")
	assert_true(ch.equip("berserker_axe__greataxe", "main_hand"))
	assert_eq(ch.max_hp(), plain + ch.character_level(), "in hand it grants its Hit Points")
	GameSettings.set_unlimited_attunement(false)
	assert_eq(ch.max_hp(), plain, "attunement is the book's again, and this one never attuned")


func test_requirements_go_with_attunement() -> void:
	var staff := "staff_of_power__quarterstaff"
	var ch := TestChars.pregen("ilse_varga", 5)   # a Fighter, not a Sorcerer, Warlock or Wizard
	ch.add_item(staff)
	assert_true(ch.attune_blocker(staff).begins_with("Requires attunement"), ch.attune_blocker(staff))
	GameSettings.set_unlimited_attunement(true)
	assert_eq(ch.attune_blocker(staff), "Doesn't need attunement")
	assert_true(ch.equip(staff, "main_hand"))
	assert_true(ch.item_active(ch.entry_of(staff)), "a Fighter can hold it, and it works")


func test_taking_up_a_disguised_item_shows_what_it_is_and_a_curse_does_not_bind() -> void:
	GameSettings.set_unlimited_attunement(true)
	var ch := TestChars.pregen("ilse_varga", 5)
	var armor := "armor_of_vulnerability_slashing__plate_armor"
	ch.add_item(armor)
	assert_true(MagicItems.is_disguised(Compendium.shared().item_data(armor), ch.entry_of(armor)), "passes for Slashing Resistance")
	assert_true(ch.equip(armor, "armor"))
	assert_false(MagicItems.is_disguised(Compendium.shared().item_data(armor), ch.entry_of(armor)), "wearing it shows it")
	assert_eq(ch.take_off_blocker(armor), "", "nothing holds a curse on without attunement")
	assert_eq(ch.part_blocker(armor), "")
