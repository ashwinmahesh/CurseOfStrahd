# Magic item data (data/magic_items → rules/equipment/magic_items.gd, combat/combat_items.gd)

ADR 0012. Schema: `data/schemas/item.schema.json`. Text and summaries are our own words.

## The item

| key | meaning |
|---|---|
| `magic.rarity` | common, uncommon, rare, very_rare, legendary, artifact |
| `magic.attunement` | (attuning and ending it are instant in the game, owner house rule 2026-10-07, docs/rules/deviations.md; three at most, or none at all with Settings, Game, Attunement: `MagicItems.attunement_off`, which makes `needs_attunement` false for every item and leaves `asks_attunement`, the item's own word, alone) `true`, or the requirement in words ("by a Wizard", "by a Spellcaster", "by a Cleric, Druid, or Paladin"); classes, "spellcaster" and species are checked, alignment isn't tracked |
| `magic.charges` | `max` (number or dice), `start`, `regain` (dice or "all"), `when` (dawn, dusk, long, short, never), `last` ({die, on, result: destroyed / nonmagical, text}: what happens when the last charge goes) |
| `magic.cursed`, `magic.curse` | a curse (attunement can't end until Remove Curse lifts it; `curse` is shown once attuned) |
| `appears_as` | the item it passes for until identified or attuned to (Potion of Poison, Dust of Sneezing and Choking) |
| `disguise` | `{name, summary, text}` it shows until identified or attuned to, when it imitates no real item (Armor of Vulnerability as "{base} of Slashing Resistance") |
| `worn` | head, eyes, neck, cloak, robe, wrists, hands, belt, feet, ring (two), ioun (any number) |
| `held` | works only in a hand (default for wands, rods and staffs) |
| `consumable` | used up by its power (default for potions and scrolls) |
| `theme`, `variant_of`, `treasure` | random tables: arcana / armaments / implements / relics; one roll per `variant_of` group; `treasure.random: false` keeps it off them |
| `template` | built on a mundane base: `on` (weapon, armor, shield, ammunition, weapon_or_ammunition, spell), `kinds`, `items`, `exclude`, `damage_types`, `properties`, `name` ("+1 {base}"), `default`, `weapon_patch` / `armor_patch` (`properties_add`, `properties_remove`, or a key set to null to remove it), `weight_mult`. Ids are `<template>__<base>`; a reward or a container naming only the template ("give dragon_slayer") gets it on its `default` base, its only base, or a shield (`MagicItems.concrete`, in `Character.add_item` and `carries`). |
| `icon`, `icon_fallback` | icon key; a template's fallback icon is its default base's, and the finished item uses its base's |
| `focus` | "arcane", "druidic" or "holy": the item is a spellcasting focus of that kind (`Gear.focus_kind`; it goes in the doll's focus slot, `Gear.carry_slot`). A caster whose classes' `spellcasting.focus` names the kind has it to hand when it is in the focus slot or a hand (`Character.focus_item`, `has_focus`); others don't gain it. A held one (the Holy Symbol of Ravenkind) works from the focus slot as from a hand |
| `modifiers` | as in docs/contracts/modifiers.md, plus `attuned_only` / `carried` (work without being worn or held), `requires_worn` (other items worn too), `requires_gem` (Helm of Brilliance), and `when.item` / `when.ammo: "@self"` (this weapon's or ammunition's attacks only), `when.base_item` |
| `weapon_rules` | `extra`: [{dice, type, vs (creature types), not_vs, while (a toggle power on), nat20, crit, thrown, melee, vs_marked, spend_charge, ends_toggle}]; `on_hit`: [{save, dc, damage, save_success, conditions, rounds, until, repeat_save, push, max_size, slay, drain_half, debuff, ends_toggle, while, vs, melee}]; `returns` (thrown weapons fly back); `ignore_resistance` (types); `special` (ids for code: vorpal, sharpness, wounding, life_stealing, nine_lives, disruption, smiting, berserker, oathbow, warning, striking, displacement, missile_snaring, blackrazor, wave, ...) |
| `armor_rules` | `no_crits` (Adamantine), `no_training` (Elven Chain), `ac_vs_ranged`, `catch_arrows`, `attract_missiles`, `resist_ranged_weapons`, `forced_move_reduction` |
| `container` | `capacity_lb`, `weightless`, `extradimensional` (two of them meeting tear open), `only` (categories), `devours` |
| `light` | `{bright, dim, when, toggle, dark_only, sunlight}`: light the item sheds in a fight while it's working; `when` "drawn" (lit when a fight starts with the item equipped and working, and burning to its end: a Sun Blade), "held" (lit while it is equipped and working, out when it is put away: a Flame Tongue) or "toggle" (as "held" while the item's toggle `toggle` is on: the Rod of Lordly Might's `form_blade`). `CombatItems.sync_held_lights` does it at a fight's start, each turn's start and when weapon sets are swapped |
| `travel` | `speed_mult` for journeys |
| `artifact.properties` | how many random properties of each kind to roll when it's made |
| `sentience` | a sentient item's mind (text for now) |

## Powers (`powers`)

A potion with `effects` gets an implicit "Drink" power (Bonus Action, itself or a creature within 5 ft, its `effects`
for its `duration`); a Spell Scroll an implicit "Read"; an Ioun Stone (`worn: "ioun"`) "Toss into orbit" (Magic action) and "Stow orbiting stones" (Utilize action), three orbiting at most (`MagicItems.IOUN_MAX`).

| key | meaning |
|---|---|
| `id`, `name`, `text`, `sub` | |
| `cost` | magic (a Magic action), action, utilize, bonus, reaction, attack (one attack of the Attack action), free; a spell power defaults to the spell's casting time |
| `charges`, `upcast_charges`, `max_level` | charges spent; more per level above the spell's (a Wand of Fireballs' level pips) |
| `uses` | `{count, per}`: per dawn, long, short, never, or `dawns:N` (once every N days, counted down at each dawn) |
| `spell` / `recipe`, `level` | the spell it casts, or the item's recipe `<item>__<recipe>`; at this level |
| `dc`, `attack` | a number, or "wielder" (the best of the user's spellcasting) |
| `consume` | the item is used up |
| `toggle`, `off_cost`, `minutes` / `hours` / `rounds`, `modifiers`, `conditions_on`, `custom_light`, `budget_rounds`, `budget_reset`, `needs_charges` | an on/off power (Flame Tongue, Boots of Speed): an Effect on the user while on |
| `grants` | `{powers, hours / minutes}`: powers the user keeps for a while (Potion of Fire Breath) |
| `custom`, `params` | bespoke code |
| `gem`, `needs_gem`, `bead` | Helm of Brilliance gems; Necklace of Prayer Beads beads (each bead one use a day) |
| `after` | code run after use (Horn of Blasting may explode) |
| `field`, `combat`, `hidden`, `requires` | usable outside fights; not in fights; not on the hotbar (used automatically: Ring of Evasion, Luck Blade); `anyone` (no attunement or wearing needed) |
| `choice` | a pick the player makes (Cube of Force's face, Defender's bonus) |

## Commands and hooks

- `encounter.items.use(c, item_id, power_id, targets, point, direction, level, opts)` uses a power in a fight; the
  hotbar lists `items.list(c)` (kind `item`, or `item_spell` for powers that target like spells). The spells an item the hero
  is working gives (`CombatItems.on_spells_tab`: `gives_spell` and `working`, the same test as the character sheet, and a spell
  with combat rules) are on the **Spells** tab, one slot each by the spell's name under its level, what it has left
  and the item on the second line ("7/10 · Staff of Fire", a daily use "1/1 · ...", "at will · ...") and what a casting costs in the tooltip;
  a hero with none of their own gets the tab for them (`ActionCatalog.tabs_for`). Everything else, and an item's spells
  while it is not worn, held or attuned (greyed, with the reason), stay on the Items tab.
- `FieldItems.options(party, ch, item_id, dice)` / `FieldItems.use(st, ch, item_id, power_id, target, dice, opts)` use
  one outside a fight (the inventory's item card).
- `ItemSpells.entries(st, ch, dice)` / `ItemSpells.cast(st, ch, item_id, power_id, targets, level, choice, dice)` (story/item_spells.gd)
  are the character sheet's Spells tab: every `spell` power of an item that is working for `ch` (`Character.item_active`:
  worn or held where it must be, attuned where it asks; a weapon in the second set counts), marked with the item and its
  charges, daily uses or "At will". A spell can be cast there if its power is `field`, or it is healing or help for the
  party (`FieldCasting.helpful`), a revival, Light and its kind, or has nothing to do in a fight; any other says "Only in a
  fight". Casting is `FieldItems.use` (`opts.field_targets` aims it at several creatures at once), so charges, uses and DCs
  are the item card's. A power that is only for its wielder (the rings and boots that cast on "yourself") says `self_only`.
- `Character`: `wear`, `equip`, `attune`, `end_attunement`, `item_active(entry)`, `charges_left`, `spend_charges`,
  `on_dawn`, `on_dusk`, `items_passage`, `put_in` / `take_out` / `contents_of`, `remove_one` (returns the state to pass
  to `add_item(id, qty, state)`).
- `Treasure.placed(st, loc_id)` rolls (once) and returns a location's random magic items by container.
- Identifying: `MagicItems.is_disguised` / `shown_data` / `display_name(item, entry)` (what the player sees),
  `Character.identify(item_id)`; `identified` on the entry. The item card offers Identify; the Rest screen offers
  studying one item per character through a Short Rest.
- In the world: `FieldItems.use` returns an `effect` the inventory hands to `LocationView.apply_spell_effect` (a Wand of
  Secrets' "secrets", a wand's Detect Magic); lock openers are on `LocationView.actions_to_unlock` ("chime",
  "mystery_key"), and Gloves of Thievery's `lockpick_plus_5` flag is in `_pick_bonus`.
- Encounter hooks (combat/combat_items.gd): `hit_damage_dice`, `after_hit`, `after_miss`, `before_roll`,
  `against_damage`, `adjust_incoming`, `on_damaged`, `before_d20`, `after_d20`, `crit_allowed`, `attack_blocked`,
  `spell_blocked`, `absorbs_spell`, `turns_spell`, `filter_magic_effect`, `reveals_invisible`, `initiative_advantage`,
  `initiative_bonus`, `surprise_filter`, `healing_bonus`, `turn_start`, `turn_end`, `combat_started`, `makes_crit`
  (a hit turned into a Critical Hit: Namer's Needle).
- Heroes of Faerûn and Arcana Unleashed items live in combat/faerun_items.gd (`ItemSpecials.fr`): custom powers named
  `fr_<id>` (and `after: "fr_<id>"`), the weapon specials `mage_breaker`, `namers_needle`, `dispelling`, `goading`, the
  Keyholes daggers' second try (an after-miss offer), the Staffs of Skulls' and Martialist's before-roll offers, and
  Dissuader's push (`after_step`, called as any creature takes a step). A power's `count` is how many creatures a
  multi-target power picks. Batch 9c adds: `disadvantage_unless` (creature types that save normally against a
  power's spell), a modifier `value` of `"@pick"` (the choice saved on the item's inventory entry by an `fr_set_pick`
  field power), `fr_` field powers (`FaerunItems.field_use`, through `FieldItems.use`), `FaerunItems.thimble` in trap
  damage, `puppet_voice` in Verbal component checks, `banded` beside Sculpt Spells and `after_spell_hit` after a spell
  attack hits. Batch 9d adds `while_on` (another power of the item that must be on: the Nightingale's songs) and
  `self_only` (the power's spell targets its user).
- The relics of Curse of Strahd (combat/item_powers.gd, docs/story/castle_artifacts.md): the weapon specials
  `crumbles_on_vampire` (Saint Markovia's Thighbone: marked when it hits a vampire, gone when the fight ends through
  `CombatItems.fight_over`) and `vampiric_strike` (the Gulthias Staff: an armed hit heals by the damage and calls a
  Wisdom save); `ItemPowers.refresh_auras`, which SpellZones.refresh_auras calls as creatures move (the Icon of
  Ravenloft's protection from fiends and undead within 30 ft of whoever carries it); `attack_blocked` and
  `spell_blocked` also keep lesser blights from the staff's attuned bearer; the modifier stat `turn_dc`
  (docs/contracts/modifiers.md); and the field power `icon_augury` (story/field_items.gd).
